//
//  RouteRecordingView.swift
//  StoneBC
//
//  Immersive GPS recording view. Adopts the same six-zone glance-first
//  architecture as `RouteNavigationView` but without a pre-loaded `Route`:
//
//    A  16 pt Header         ● RECORDING pulse (or ⏸ PAUSED / ■ STOPPED)
//    F  flex  Map            3D follow, user track drawn as solid blue line
//    B  180 pt Speed + compass
//    C  48 pt  Recorded distance + ascent summary
//    D  80 pt  Sensor strip  elevation · gradient · avg speed
//    E  40 pt  PAUSED banner (conditional)
//    Bottom 56 pt controls   audio · pause/resume · STOP
//

import SwiftUI
import MapKit
import CoreLocation

struct RouteRecordingView: View {
    let route: Route?
    let routeId: String?
    let routeName: String?
    let recordingMode: RouteRecordingMode
    let ridePreferences: RouteRidePreferences

    @State private var locationService = LocationService()
    @State private var altimeterService = AltimeterService()
    @State private var audioService = NavigationAudioService()
    @State private var recording: RideSession
    @State private var workoutService = WorkoutService()
    @State private var activityManager = RideActivityManager()
    @State private var safetyService = EmergencySafetyService.shared

    @State private var mapRegion = Self.defaultMapRegion
    @State private var isFollowingUser = true
    @State private var showStopConfirm = false
    @State private var showSaveSheet = false
    @State private var showEnduranceLock = false
    @State private var powerMode: RidePowerMode = .endurance
    @State private var pulsePhase = false
    @State private var lastCameraUpdateAt: Date = .distantPast
    @State private var lastCameraLocation: CLLocation?
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(
        route: Route? = nil,
        routeId: String? = nil,
        routeName: String? = nil,
        recordingMode: RouteRecordingMode = .free,
        ridePreferences: RouteRidePreferences? = nil
    ) {
        self.route = route
        self.routeId = route?.id ?? routeId
        self.routeName = route?.name ?? routeName
        self.recordingMode = route == nil && recordingMode == .follow ? .free : recordingMode
        self.ridePreferences = ridePreferences ?? RouteRidePreferences.load(route: route)

        if recordingMode == .follow, let route {
            self._recording = State(initialValue: RideSession(route: route))
        } else {
            self._recording = State(initialValue: RideSession(mode: .freeRecording))
        }
    }

    private var splitDelta: Double? {
        guard let rid = routeId, recording.elapsedSeconds > 0, recording.distanceMiles > 0 else { return nil }
        let progress = recording.progressPercent > 0 ? recording.progressPercent : min(recording.distanceMiles / max(route?.distanceMiles ?? recording.distanceMiles, 0.1), 1)
        return TimeTrialService.shared.splitDelta(routeId: rid, currentSeconds: recording.elapsedSeconds, progressPercent: progress)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerStrip
            if let delta = splitDelta {
                splitDeltaBanner(delta)
            }
            navigationMap
            speedTile
            recordedSummaryTile
            sensorStrip
            if recording.state == .paused {
                pausedBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if safetyService.checkInState == .overdue, ridePreferences.enabledOverlays.contains(.safetyCheckIn) {
                checkInBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            bottomControlBar
        }
        .background(BCColors.navPanel)
        .ignoresSafeArea(edges: .top)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.25), value: recording.state)
        .overlay {
            if showEnduranceLock {
                enduranceLockOverlay
                    .transition(.opacity)
            }
        }
        .onAppear(perform: startRecording)
        .onDisappear(perform: stopServices)
        .onChange(of: locationService.locationUpdateCount) { _, _ in
            onLocationTick()
        }
        .onChange(of: scenePhase) { _, newPhase in
            locationService.setInterfaceActive(newPhase == .active)
        }
        .confirmationDialog(
            "Stop recording?",
            isPresented: $showStopConfirm,
            titleVisibility: .visible
        ) {
            Button("Stop & Save", role: .destructive) { finishRecording() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(recording.formattedDistance) in \(recording.formattedElapsed)")
        }
        .sheet(isPresented: $showSaveSheet) {
            RecordingSaveSheet(
                recording: recording,
                workoutService: workoutService,
                routeId: routeId,
                initialRouteName: routeName,
                sourceRoute: route,
                recordingMode: recordingMode
            ) {
                dismiss()
            }
        }
    }

    // MARK: - Zone A · Header

    private var headerStrip: some View {
        ZStack {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(recording.state == .paused ? BCColors.navAlertAmber : .red)
                    .frame(width: 8, height: 8)
                    .opacity(recording.state == .recording
                             ? (pulsePhase ? 0.4 : 1.0)
                             : 1.0)
                Text("\(statusLabel) · \(recording.formattedElapsed)")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Button {
                    showStopConfirm = true
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 44, height: 16)
                        .contentShape(Rectangle())
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 16)
        .padding(.top, topSafeAreaInset)
        .background(BCColors.navPanel)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulsePhase = true
            }
        }
    }

    private var statusLabel: String {
        switch recording.state {
        case .recording: return "RECORDING"
        case .paused:    return "PAUSED"
        case .stopped:   return "STOPPED"
        case .idle:      return "READY"
        }
    }

    private func splitDeltaBanner(_ delta: Double) -> some View {
        let isAhead = delta < 0
        let abs = Swift.abs(delta)
        let mins = Int(abs) / 60
        let secs = Int(abs) % 60
        let label = mins > 0 ? "\(mins):\(String(format: "%02d", secs))" : "\(secs)s"
        return HStack(spacing: 6) {
            Image(systemName: "stopwatch")
                .font(.system(size: 10))
            Text(isAhead ? "-\(label)" : "+\(label)")
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
            Text(isAhead ? "AHEAD OF PB" : "BEHIND PB")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(isAhead ? Color.green.opacity(0.85) : Color.red.opacity(0.85))
    }

    private var topSafeAreaInset: CGFloat {
        UIApplication.shared
            .connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.top ?? 0
    }

    // MARK: - Zone F · Map + recorded track polyline

    private var navigationMap: some View {
        OfflineCapableMapView(
            region: $mapRegion,
            isFollowingUser: $isFollowingUser,
            routePolyline: mapRoutePolyline,
            breadcrumb: mapBreadcrumb,
            routeColor: UIColor(BCColors.brandBlue),
            showsEndpointPins: false
        )
        .overlay(alignment: .bottomTrailing) {
            if !isFollowingUser {
                Button {
                    isFollowingUser = true
                    recenterOnUser()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Rectangle())
                }
                .padding(16)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFollowingUser)
    }

    private var mapRoutePolyline: [CLLocationCoordinate2D] {
        if recordingMode == .follow, let route, ridePreferences.enabledOverlays.contains(.routeLine) {
            return route.clTrackpoints
        }
        return recording.trackpoints.map(\.coordinate)
    }

    private var mapBreadcrumb: [CLLocationCoordinate2D] {
        guard recordingMode == .follow, ridePreferences.enabledOverlays.contains(.breadcrumbs) else { return [] }
        return recording.trackpoints.map(\.coordinate)
    }

    private static var defaultMapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 44.0805, longitude: -103.2310),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    }

    // MARK: - Zone B · Speed + compass

    private var speedTile: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                Text(formattedSpeed)
                    .font(.system(size: 150, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("mph · \(recording.formattedElapsed)")
                    .font(.system(size: 18, weight: .medium))
                    .tracking(2)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, -8)
                Spacer(minLength: 0)
            }
            .padding(.leading, 24)

            Spacer(minLength: 0)

            ambientCompass
                .padding(.trailing, 24)
        }
        .bcNavTile(height: 180)
    }

    private var formattedSpeed: String {
        if locationService.speedMPH < 2 {
            return String(format: "%.1f", locationService.speedMPH)
        }
        return String(Int(locationService.speedMPH.rounded()))
    }

    private var ambientCompass: some View {
        ZStack {
            Rectangle()
                .stroke(.white.opacity(0.2), lineWidth: 1)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(.red)
                .offset(y: -32)

            Image(systemName: "arrow.up")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(BCColors.brandGreen)
                .rotationEffect(.degrees(locationService.navigationHeading))
                .animation(.easeInOut(duration: 0.3), value: locationService.navigationHeading)
        }
        .frame(width: 72, height: 72)
    }

    // MARK: - Zone C · Recorded distance + ascent summary

    private var recordedSummaryTile: some View {
        HStack(spacing: 24) {
            HStack(spacing: 6) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                Text(recording.formattedDistance)
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

            Divider().frame(height: 16).background(Color.white.opacity(0.2))

            HStack(spacing: 6) {
                Image(systemName: "mountain.2")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(ascentFormatter.string(from: NSNumber(value: Int(recording.totalAscentFeet))) ?? "0") ft")
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

            Spacer()

            Text("RECORDED")
                .font(.system(size: 10, weight: .medium))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 16)
        .bcNavTile(height: 48)
    }

    private let ascentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    // MARK: - Zone D · Sensor strip

    private var sensorStrip: some View {
        HStack(spacing: 0) {
            sensorTile(
                value: altitudeValue,
                label: "FT",
                valueColor: .white
            )
            Divider().frame(width: 1).background(Color.white.opacity(0.1))

            sensorTile(
                value: gradientString,
                label: "GRADE",
                valueColor: gradientColor
            )
            Divider().frame(width: 1).background(Color.white.opacity(0.1))

            sensorTile(
                value: String(format: "%.1f", recording.avgSpeedMPH),
                label: "AVG",
                valueColor: .white
            )
        }
        .bcNavTile(height: 80)
    }

    private func sensorTile(value: String, label: String, valueColor: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private var gradient: Double {
        let speed = locationService.speedMPH
        guard speed > 1 else { return 0 }
        return (altimeterService.climbRateFeetPerMin / (speed * 88.0)) * 100
    }

    private var gradientString: String {
        let g = gradient
        if g == 0 { return "0%" }
        let sign = g > 0 ? "+" : ""
        return "\(sign)\(Int(g.rounded()))%"
    }

    private var gradientColor: Color {
        let g = gradient
        if g > 8 { return .red }
        if g > 3 { return BCColors.brandAmber }
        if g < -3 { return BCColors.brandGreen }
        return .white
    }

    private var altitudeValue: String {
        guard let feet = altimeterService.bestAltitudeFeet else { return "--" }
        return ascentFormatter.string(from: NSNumber(value: Int(feet))) ?? "\(Int(feet))"
    }

    // MARK: - Zone E · PAUSED banner

    private var pausedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "pause.fill")
                .font(.system(size: 16, weight: .semibold))
            Text("PAUSED · Tap ▶ to resume")
                .font(.system(size: 14, weight: .semibold))
                .tracking(1)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(BCColors.navAlertAmber.opacity(0.85))
    }

    private var checkInBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.system(size: 16, weight: .semibold))
            Text("CHECK IN · OVERDUE")
                .font(.system(size: 14, weight: .semibold))
                .tracking(1)
            Spacer()
            Button {
                safetyService.checkIn()
            } label: {
                Text("I'M OK")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Color.white.opacity(0.18), in: Rectangle())
            }
            if let smsURL = safetyService.emergencySMSURL {
                Link(destination: smsURL) {
                    Text("SOS")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(BCColors.navAlertRed, in: Rectangle())
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(BCColors.navAlertAmber.opacity(0.9))
    }

    // MARK: - Bottom control bar

    private var bottomControlBar: some View {
        HStack(spacing: 12) {
            Button {
                showEnduranceLock = true
            } label: {
                Image(systemName: "battery.100")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08), in: Rectangle())
            }

            Button {
                audioService.isEnabled.toggle()
            } label: {
                Image(systemName: audioService.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(audioService.isEnabled ? .white : .orange)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08), in: Rectangle())
            }

            Spacer()

            Button {
                togglePause()
            } label: {
                Image(systemName: recording.state == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 44)
                    .background(
                        recording.state == .paused ? BCColors.brandGreen : BCColors.navAlertAmber,
                        in: Rectangle()
                    )
            }

            Spacer()

            Button {
                showStopConfirm = true
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 44)
                    .background(Color.red.opacity(0.9), in: Rectangle())
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .padding(.bottom, bottomSafeAreaInset)
        .background(BCColors.navPanel)
    }

    private var enduranceLockOverlay: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Text("ENDURANCE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Button {
                        showEnduranceLock = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.08), in: Rectangle())
                    }
                }

                Spacer()

                VStack(spacing: 0) {
                    Text(formattedSpeed)
                        .font(.system(size: 112, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Text("mph")
                        .font(.system(size: 16, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.45))
                }

                HStack(spacing: 0) {
                    enduranceStat(value: recording.formattedDistance, label: "DIST")
                    enduranceStat(value: recording.formattedElapsed, label: "TIME")
                    enduranceStat(value: String(format: "%.1f", recording.avgSpeedMPH), label: "AVG")
                }

                Text("Lock iPhone for all-day tracking")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Text("Best battery: skip radio, downloads, and live refreshes")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(.top, topSafeAreaInset + 12)
            .padding(.horizontal, 20)
            .padding(.bottom, bottomSafeAreaInset + 24)
        }
    }

    private func enduranceStat(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomSafeAreaInset: CGFloat {
        UIApplication.shared
            .connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.bottom ?? 0
    }

    // MARK: - Lifecycle / ticks

    private func startRecording() {
        locationService.onFirstAltitude = { [altimeterService] gpsAltitude in
            altimeterService.calibrateWithGPS(altitudeMeters: gpsAltitude)
        }
        // Feed barometer-fused altitude into the ride engine so freerides
        // record honest ascent, not GPS-only inflation.
        recording.altitudeProvider = { [altimeterService] in
            altimeterService.fusedAltitudeMeters
        }
        locationService.requestPermission()
        locationService.startTracking(
            mode: .ride,
            powerMode: powerMode,
            wantsHeadingUpdates: powerMode.usesHeadingUpdates
        )
        altimeterService.start()
        audioService.configure(for: powerMode)
        audioService.reset()

        recording.onAutoPause = { [audioService] in
            audioService.announcePaused()
        }
        recording.onAutoResume = { [audioService] in
            audioService.announceResumed()
        }
        recording.start()
        if ridePreferences.enabledOverlays.contains(.safetyCheckIn) {
            safetyService.startCheckInTimer(routeName: routeName ?? recordingMode.label)
        }
        activityManager.startActivity(
            routeName: routeName ?? recordingMode.label,
            distanceMiles: route?.distanceMiles ?? 0,
            category: route?.category ?? "recording"
        )

        if workoutService.isAvailable {
            Task {
                await workoutService.requestAuthorization()
                await workoutService.startWorkout(routeName: routeName ?? "Ride")
            }
        }
    }

    private func stopServices() {
        locationService.stopTracking()
        altimeterService.stop()
        safetyService.stopCheckInTimer()
        if let effectiveStart = recording.effectiveStartedAt {
            activityManager.endActivity(
                finalDistance: recording.distanceMiles,
                rideStartedAt: effectiveStart,
                pausedAt: recording.pausedAt
            )
        }
        recording.stop()
        workoutService.cancelWorkout()
    }

    private func togglePause() {
        switch recording.state {
        case .recording:
            recording.pause()
            locationService.setRideStationary(true)
        case .paused:
            recording.resume()
            locationService.setRideStationary(false)
        default: break
        }
    }

    private func finishRecording() {
        recording.stop()
        if let effectiveStart = recording.effectiveStartedAt {
            activityManager.endActivity(
                finalDistance: recording.distanceMiles,
                rideStartedAt: effectiveStart,
                pausedAt: recording.pausedAt
            )
        }
        if recording.isSaveable {
            showSaveSheet = true
        } else {
            dismiss()
        }
    }

    private func recenterOnUser() {
        guard let loc = locationService.userLocation else { return }
        let current = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
        lastCameraLocation = current
        lastCameraUpdateAt = Date()
        withAnimation(.easeInOut(duration: 0.4)) {
            mapRegion = MKCoordinateRegion(
                center: loc,
                span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            )
        }
    }

    private func onLocationTick() {
        guard let loc = locationService.userLocation else { return }

        if let cl = locationService.lastLocation {
            altimeterService.recalibrateIfPossible(
                gpsAltitudeMeters: cl.altitude,
                verticalAccuracy: cl.verticalAccuracy
            )
            recording.ingestLocation(cl)
            locationService.setRideStationary(recording.state == .paused)
            workoutService.addRouteData([cl], powerMode: powerMode)
        }

        if let effectiveStart = recording.effectiveStartedAt {
            activityManager.updateActivity(
                speedMPH: locationService.speedMPH,
                distanceTraveled: recording.distanceMiles,
                distanceRemaining: 0,
                rideStartedAt: effectiveStart,
                pausedAt: recording.pausedAt,
                progress: 0,
                isOffRoute: false,
                heading: locationService.navigationHeading,
                powerMode: powerMode
            )
        }

        updateCameraIfNeeded(centeredOn: loc)
    }

    private func updateCameraIfNeeded(centeredOn coordinate: CLLocationCoordinate2D) {
        guard isFollowingUser, scenePhase == .active, !showEnduranceLock else { return }

        let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distance = lastCameraLocation.map { current.distance(from: $0) } ?? .greatestFiniteMagnitude
        let elapsed = Date().timeIntervalSince(lastCameraUpdateAt)

        guard elapsed >= powerMode.mapCameraMinInterval
                || distance >= powerMode.mapCameraMinDistanceMeters else {
            return
        }

        lastCameraLocation = current
        lastCameraUpdateAt = Date()
        withAnimation(.easeInOut(duration: 0.5)) {
            mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
            )
        }
    }
}

// MARK: - Save sheet

struct RecordingSaveSheet: View {
    let recording: RideSession
    let workoutService: WorkoutService
    var routeId: String? = nil
    var initialRouteName: String? = nil
    var sourceRoute: Route? = nil
    var recordingMode: RouteRecordingMode = .free
    let onDone: () -> Void

    @Environment(AppState.self) var appState
    @State private var saveToHistory = true
    @State private var saveAsRoute = false
    @State private var routeName = ""
    @State private var category = "gravel"
    @State private var difficulty = "moderate"
    @State private var region = "Recorded"
    @State private var submitToCoop = false
    @State private var submitterEmail = ""
    @State private var submitDescription = ""
    @State private var isSubmitting = false
    @State private var submitResult: String?
    @State private var showJournalPrompt = false
    @State private var savedRideId: String? = nil
    @State private var didApplyDefaults = false
    @Environment(\.dismiss) var sheetDismiss

    private let categories = ["road", "gravel", "fatbike", "trail"]
    private let difficulties = ["easy", "moderate", "hard", "expert"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Review") {
                    recordingReviewMap
                    LabeledContent("Mode", value: recordingMode.label)
                }

                Section("Summary") {
                    LabeledContent("Distance", value: recording.formattedDistance)
                    LabeledContent("Time", value: recording.formattedElapsed)
                    LabeledContent("Climb", value: "\(Int(recording.totalAscentFeet)) ft")
                    LabeledContent("Avg speed", value: String(format: "%.1f mph", recording.avgSpeedMPH))
                }

                Section("Export") {
                    ShareLink(item: exportGPXText) {
                        Label("Export GPX", systemImage: "doc.badge.arrow.up")
                    }
                }

                Section {
                    Toggle("Save to My Rides", isOn: $saveToHistory)
                } footer: {
                    Text("Appears in your season summary and ride history.")
                }

                Section {
                    Toggle("Also save as Route", isOn: $saveAsRoute)
                    if saveAsRoute {
                        TextField("Route name", text: $routeName)

                        Picker("Category", selection: $category) {
                            ForEach(categories, id: \.self) { c in
                                Text(c.capitalized).tag(c)
                            }
                        }
                        Picker("Difficulty", selection: $difficulty) {
                            ForEach(difficulties, id: \.self) { d in
                                Text(d.capitalized).tag(d)
                            }
                        }
                        TextField("Region", text: $region)
                    }
                } footer: {
                    Text("Route templates can be navigated again later. Stored on this device.")
                }

                Section {
                    Toggle("Submit to Co-op", isOn: $submitToCoop)
                    if submitToCoop {
                        TextField("Your email", text: $submitterEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Description (optional)", text: $submitDescription, axis: .vertical)
                            .lineLimit(3, reservesSpace: false)
                        if let result = submitResult {
                            Label(result, systemImage: result.hasPrefix("✓") ? "checkmark.circle.fill" : "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(result.hasPrefix("✓") ? BCColors.brandGreen : .red)
                        }
                    }
                } footer: {
                    Text("Share your ride with the co-op. Submissions are reviewed by the SBC team before appearing in the app.")
                }
            }
            .navigationTitle("Review Ride")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                applyInitialDefaultsIfNeeded()
                if submitterEmail.isEmpty, let email = appState.memberEmail {
                    submitterEmail = email
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Discard", role: .destructive) {
                        workoutService.cancelWorkout()
                        sheetDismiss()
                        onDone()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let rideId = performSave()
                        savedRideId = rideId
                        let endDate = recording.lastLocation?.timestamp ?? Date()
                        let events = recording.pauseEvents.map { (date: $0.date, isPause: $0.kind == .pause) }
                        Task { await workoutService.endWorkout(endDate: endDate, pauseEvents: events) }
                        if submitToCoop {
                            Task { await submitRouteToCoop() }
                        } else {
                            sheetDismiss()
                            if rideId != nil && saveToHistory {
                                showJournalPrompt = true
                            } else {
                                onDone()
                            }
                        }
                    }
                    .disabled(
                        (saveAsRoute && routeName.trimmingCharacters(in: .whitespaces).isEmpty) ||
                        (submitToCoop && submitterEmail.trimmingCharacters(in: .whitespaces).isEmpty) ||
                        isSubmitting
                    )
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showJournalPrompt, onDismiss: onDone) {
                if let rId = savedRideId {
                    JournalPromptSheet(rideId: rId, routeName: routeNameForSave, distanceMiles: recording.distanceMiles, elapsedSeconds: recording.elapsedSeconds)
                }
            }
        }
    }

    private var recordingReviewMap: some View {
        let coordinates = recording.trackpoints.map(\.coordinate)
        return Map {
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(BCColors.brandBlue, lineWidth: 4)
            }

            if let first = coordinates.first {
                Annotation("Start", coordinate: first) {
                    Rectangle()
                        .fill(.green)
                        .frame(width: 12, height: 12)
                        .overlay(Rectangle().stroke(.white, lineWidth: 2))
                }
            }

            if let last = coordinates.last, coordinates.count > 1 {
                Annotation("Finish", coordinate: last) {
                    Rectangle()
                        .fill(.red)
                        .frame(width: 12, height: 12)
                        .overlay(Rectangle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(height: 180)
        .clipShape(Rectangle())
        .allowsHitTesting(false)
    }

    private var exportGPXText: String {
        RideExportService.exportGPX(
            routeName: routeNameForSave,
            locations: recording.exportLocations,
            startTime: recording.startedAt ?? Date()
        )
    }

    private var routeNameForSave: String {
        let trimmed = routeName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return trimmed
        }
        if let initialRouteName {
            return initialRouteName
        }
        switch recordingMode {
        case .free: return "Recorded Ride"
        case .follow: return sourceRoute?.name ?? "Followed Route"
        case .scout: return "Scouted Route"
        }
    }

    private func applyInitialDefaultsIfNeeded() {
        guard !didApplyDefaults else { return }
        didApplyDefaults = true

        if routeName.isEmpty {
            routeName = routeNameForSave
        }
        if let sourceRoute {
            category = sourceRoute.category
            difficulty = sourceRoute.difficulty
            region = sourceRoute.region
        }
        if recordingMode == .scout {
            saveAsRoute = true
            submitToCoop = true
        } else if recordingMode == .follow {
            saveAsRoute = false
        }
    }

    @discardableResult
    private func performSave() -> String? {
        let name = routeNameForSave

        var savedRideId: String? = nil

        if saveToHistory {
            let rideId = RideHistoryService.shared.recordRide(
                routeId: routeId ?? UUID().uuidString,
                routeName: name,
                category: category,
                distanceMiles: recording.distanceMiles,
                elapsedSeconds: recording.elapsedSeconds,
                movingSeconds: recording.movingSeconds,
                elevationGainFeet: recording.totalAscentFeet,
                avgSpeedMPH: recording.avgSpeedMPH,
                maxSpeedMPH: recording.maxSpeedMPH,
                gpxTrackpoints: recording.isSaveable ? recording.routeTrackpointTriples : nil
            )
            savedRideId = rideId

            if let rid = routeId {
                let isNewPB = TimeTrialService.shared.recordAttempt(
                    rideId: rideId,
                    routeId: rid,
                    seconds: recording.elapsedSeconds,
                    distanceMiles: recording.distanceMiles
                )
                _ = isNewPB
            }
        }

        let routeTrackpoints = recording.routeTrackpointTriples
        if saveAsRoute, routeTrackpoints.count >= 2, let first = routeTrackpoints.first {
            let route = Route(
                id: UUID().uuidString,
                name: name,
                difficulty: difficulty,
                category: category,
                distanceMiles: recording.distanceMiles,
                elevationGainFeet: Int(recording.totalAscentFeet),
                region: region.isEmpty ? "Recorded" : region,
                description: "Recorded on \(Date().formatted(date: .abbreviated, time: .omitted))",
                startCoordinate: Route.Coordinate(
                    latitude: first[0],
                    longitude: first[1]
                ),
                trackpoints: routeTrackpoints,
                isImported: true
            )
            appState.addImportedRoute(route)
        }

        return savedRideId
    }

    @MainActor
    private func submitRouteToCoop() async {
        isSubmitting = true
        let name = routeNameForSave
        let gpxString = RideExportService.exportGPX(
            routeName: name,
            locations: recording.exportLocations,
            startTime: recording.startedAt ?? Date()
        )
        let result = await RouteSubmissionService.submit(
            name: name,
            description: submitDescription,
            difficulty: difficulty,
            category: category,
            email: submitterEmail,
            gpxData: Data(gpxString.utf8)
        )
        isSubmitting = false
        switch result {
        case .success:
            submitResult = "✓ Submitted! We'll review and notify you."
            try? await Task.sleep(for: .seconds(2))
            sheetDismiss()
            onDone()
        case .failure(let error):
            submitResult = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        RouteRecordingView()
    }
}
