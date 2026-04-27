//
//  RouteNavigationView.swift
//  StoneBC
//
//  Glance-first active-ride navigation. Six stacked panels above a full-bleed 3D map:
//    A  32 pt  Header       — back chevron + route name
//    B 180 pt  Speed hero   — big integer mph, subscript mph · elapsed, ambient compass
//    C  48 pt  Progress     — mini elevation profile filled by distance ridden
//    D  80 pt  Sensor strip — elevation · gradient · avg speed
//    E  40 pt  Off-route    — conditional amber / red banner
//    F  flex   Map          — 3D follow, two floating pills (audio, END RIDE)
//

import SwiftUI
import MapKit
import CoreLocation

struct RouteNavigationView: View {
    let route: Route
    let ridePreferences: RouteRidePreferences

    @State private var coordinator: RideRecordingCoordinator
    private var networkStatus = NetworkStatusService.shared
    @State private var mapRegion: MKCoordinateRegion
    @State private var tilePackInfo: OfflineTilePackInfo?
    @State private var isFollowingUser = true
    @State private var showEndConfirm = false
    @State private var saveSnapshot: RideRecordingSnapshot?
    @State private var showConditionReport = false
    @State private var shouldShowConditionReportAfterSave = false
    @State private var showEnduranceLock = false
    @State private var powerMode: RidePowerMode = .balanced
    @State private var breadcrumbs: [CLLocationCoordinate2D] = []
    @State private var pulsePhase = false
    @State private var lastCameraUpdateAt: Date = .distantPast
    @State private var lastCameraLocation: CLLocation?
    @State private var weather: RouteWeather?
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private var locationService: LocationService { coordinator.locationService }
    private var altimeterService: AltimeterService { coordinator.altimeterService }
    private var audioService: NavigationAudioService { coordinator.audioService }
    private var safetyService: EmergencySafetyService { coordinator.safetyService }
    private var session: RideSession { coordinator.recording }
    private var routeGuidance: RouteGuidance? {
        RouteGuidanceResolver.guidance(for: route, guides: appState.guides)
    }

    init(route: Route, ridePreferences: RouteRidePreferences? = nil) {
        self.route = route
        self.ridePreferences = ridePreferences ?? RouteRidePreferences.load(route: route)
        self._coordinator = State(initialValue: RideRecordingCoordinator(
            route: route,
            recordingMode: .follow,
            ridePreferences: ridePreferences
        ))
        self._mapRegion = State(initialValue: Self.initialMapRegion(for: route))
    }

    var body: some View {
        ZStack {
            if coordinator.lifecycleState == .preflighting || coordinator.lifecycleState == .ready {
                RecordingPreflightView(coordinator: coordinator) {
                    coordinator.discardRecording()
                    dismiss()
                }
            } else {
                VStack(spacing: 0) {
                    headerStrip       // A — slim, 16 pt + safe area
                    ZStack(alignment: .topTrailing) {
                        navigationMap     // F — hero, fills flex space
                        offlinePill       // OFFLINE indicator — top-right of map
                            .padding(.top, 8)
                            .padding(.trailing, 12)
                    }
                    speedTile         // B — 180 pt
                    progressTile      // C — 48 pt
                    if let routeGuidance {
                        guidedStopTile(routeGuidance)
                    }
                    sensorStrip       // D — 80 pt
                    if session.isOffRoute, ridePreferences.enabledOverlays.contains(.offRouteAlerts) {
                        offRouteBanner // E — 40 pt, conditional
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if safetyService.checkInState == .overdue, ridePreferences.enabledOverlays.contains(.safetyCheckIn) {
                        checkInBanner
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    bottomControlBar  // Audio + END RIDE — 56 pt, thumb-reachable
                }
            }
        }
        .background(BCColors.navPanel)
        .ignoresSafeArea(edges: .top)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.25), value: session.isOffRoute)
        .animation(.easeInOut(duration: 0.25), value: session.isCriticallyOffRoute)
        .overlay {
            if showEnduranceLock {
                enduranceLockOverlay
                    .transition(.opacity)
            }
        }
        .onAppear(perform: startRide)
        .task { await loadWeather() }
        .onDisappear(perform: stopServices)
        .onChange(of: locationService.locationUpdateCount) { _, _ in
            onLocationTick()
        }
        .onChange(of: scenePhase) { _, newPhase in
            locationService.setInterfaceActive(newPhase == .active)
        }
        .confirmationDialog(
            "End this ride?",
            isPresented: $showEndConfirm,
            titleVisibility: .visible
        ) {
            Button("End Ride", role: .destructive, action: endRide)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(session.formattedDistance) in \(session.formattedElapsedTime)")
        }
        .sheet(isPresented: $showConditionReport) {
            ConditionReportSheet(routeId: route.id, routeName: route.name) {
                dismiss()
            }
        }
        .sheet(item: $saveSnapshot) { snapshot in
            RecordingSaveSheet(
                snapshot: snapshot,
                routeId: route.id,
                initialRouteName: route.name,
                sourceRoute: route,
                recordingMode: .follow,
                onDiscard: {
                    shouldShowConditionReportAfterSave = false
                    coordinator.discardRecording()
                },
                onSaveWorkout: {
                    await coordinator.finishWorkoutAfterSave()
                    EmergencySafetyService.shared.lastKnownLocation = nil
                }
            ) {
                if shouldShowConditionReportAfterSave {
                    showConditionReport = true
                } else {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Zone A · Header (slim — chevron + compact route name)

    private var headerStrip: some View {
        ZStack {
            Text(route.name.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Button {
                    showEndConfirm = true
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
    }

    // Safe-area inset captured once so the first tile spans up under the clock.
    private var topSafeAreaInset: CGFloat {
        UIApplication.shared
            .connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.top ?? 0
    }

    // MARK: - Zone B · Speed + ambient compass

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
                Text("mph · \(session.formattedElapsedTime)")
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

            // Red north tick at 12 o'clock (ring is fixed north-up)
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(.red)
                .offset(y: -32)

            // Green direction-of-travel arrow — rotates with heading
            Image(systemName: "arrow.up")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(BCColors.brandGreen)
                .rotationEffect(.degrees(locationService.navigationHeading))
                .animation(.easeInOut(duration: 0.3), value: locationService.navigationHeading)
        }
        .frame(width: 72, height: 72)
    }

    // MARK: - Zone C · Progress + elevation profile

    private var progressTile: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .leading) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        ElevationShape(elevations: route.elevations)
                            .stroke(.white.opacity(0.4), lineWidth: 1.5)

                        ElevationShape(elevations: route.elevations)
                            .stroke(.white, lineWidth: 2)
                            .mask(alignment: .leading) {
                                Rectangle()
                                    .frame(width: max(0, proxy.size.width * session.progressPercent))
                            }
                    }
                }
            }
            .frame(height: 20)
            .padding(.horizontal, 16)
            .padding(.top, 6)

            HStack {
                Text(String(format: "%.1f mi", session.distanceTraveledMiles))
                Spacer()
                Text(String(format: "%.1f mi left", session.distanceRemainingMiles))
            }
            .font(.system(size: 13, weight: .medium))
            .tracking(1)
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .bcNavTile(height: 48)
    }

    private func guidedStopTile(_ guidance: RouteGuidance) -> some View {
        let stopProgress = RouteGuidanceResolver.progress(for: guidance, routeProgress: session.progressPercent)
        let focusStop = stopProgress.nextStop ?? stopProgress.currentStop
        let title = stopProgress.nextStop == nil ? "GUIDED STOPS COMPLETE" : "NEXT GUIDED STOP"
        let detail = guidedStopDetail(stopProgress, totalStops: guidance.stops.count)

        return HStack(spacing: 12) {
            Image(systemName: focusStop?.icon ?? "mappin.and.ellipse")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(guidedStopColor(focusStop?.type), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.45))

                Text(focusStop?.name ?? guidance.dayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                guidedStopProgressDots(guidance: guidance, routeProgress: stopProgress.routeProgress)
            }

            Spacer(minLength: 0)

            Text(detail)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .bcNavTile(height: 64)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(guidedStopAccessibilityLabel(stopProgress, guidance: guidance))
    }

    private func guidedStopProgressDots(guidance: RouteGuidance, routeProgress: Double) -> some View {
        HStack(spacing: 4) {
            ForEach(guidance.stops) { stop in
                Rectangle()
                    .fill(stop.progress <= routeProgress + 0.0001 ? BCColors.brandGreen : Color.white.opacity(0.18))
                    .frame(width: 18, height: 3)
            }
        }
    }

    private func guidedStopDetail(_ progress: RouteGuidanceProgress, totalStops: Int) -> String {
        if let remaining = progress.remainingMilesToNext {
            return "\(String(format: "%.1f", remaining)) mi\n\(progress.completedCount)/\(totalStops)"
        }
        return "\(progress.completedCount)/\(totalStops)\nDONE"
    }

    private func guidedStopAccessibilityLabel(_ progress: RouteGuidanceProgress, guidance: RouteGuidance) -> String {
        if let nextStop = progress.nextStop, let remaining = progress.remainingMilesToNext {
            return "Next guided stop, \(nextStop.name), \(String(format: "%.1f", remaining)) miles ahead. \(progress.completedCount) of \(guidance.stops.count) stops complete."
        }
        if let currentStop = progress.currentStop {
            return "Guided stops complete at \(currentStop.name). \(progress.completedCount) of \(guidance.stops.count) stops complete."
        }
        return "Guided stops for \(guidance.dayName)"
    }

    private func guidedStopColor(_ type: TourStop.StopType?) -> Color {
        switch type {
        case .start: BCColors.brandGreen
        case .finish: .red
        case .sag, .resupply: .orange
        case .brewery: .brown
        case .trailhead, .camp: BCColors.brandGreen
        case .pointOfInterest: BCColors.brandBlue
        case .water: .cyan
        case .safety: .red
        case nil: BCColors.brandBlue
        }
    }

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
                value: String(format: "%.1f", locationService.averageSpeedMPH),
                label: "AVG",
                valueColor: .white
            )
            Divider().frame(width: 1).background(Color.white.opacity(0.1))

            SunsetPillView(weather: weather, style: .sensorTile)
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

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    private var altitudeValue: String {
        guard let feet = altimeterService.bestAltitudeFeet else { return "--" }
        return numberFormatter.string(from: NSNumber(value: Int(feet))) ?? "\(Int(feet))"
    }

    // MARK: - Zone E · Off-route banner

    /// Small pill overlay on the navigation map. Shows when the rider is
    /// offline AND/OR outside the bundled tile pack region — both states
    /// degrade the live basemap, but the polyline + breadcrumb + cue sheet
    /// keep working.
    private var offlinePill: some View {
        Group {
            if ridePreferences.enabledOverlays.contains(.offlineStatus), let label = offlinePillLabel {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 11, weight: .semibold))
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.2)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Rectangle()
                        .fill(Color.black.opacity(0.7))
                )
                .overlay(
                    Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: offlinePillLabel)
    }

    private var offlinePillLabel: String? {
        let userCoord = locationService.userLocation
        let outsideRegion = userCoord.map { coord in
            if let tilePackInfo {
                return !tilePackInfo.bounds.contains(coord)
            }
            return !OfflineTileCoverage.contains(coordinate: coord)
        } ?? false

        switch (networkStatus.isOnline, outsideRegion) {
        case (false, false): return "OFFLINE"
        case (false, true):  return "OFFLINE · NO TILES"
        case (true, true):   return "OUT OF TILE PACK"
        case (true, false):  return nil
        }
    }

    private var offRouteBanner: some View {
        let isCritical = session.isCriticallyOffRoute
        let fill = isCritical ? BCColors.navAlertRed : BCColors.navAlertAmber.opacity(0.85)
        let icon = isCritical ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"
        let title = isCritical ? "FAR OFF" : "OFF ROUTE"

        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text("\(title) · \(formattedOffRouteDistance)")
                .font(.system(size: 14, weight: .semibold))
                .tracking(1)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(fill)
        .opacity(isCritical && pulsePhase ? 0.6 : (isCritical ? 0.85 : 1.0))
        .onAppear {
            if isCritical {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    pulsePhase = true
                }
            } else {
                pulsePhase = false
            }
        }
        .onChange(of: session.isCriticallyOffRoute) { _, nowCritical in
            if nowCritical {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    pulsePhase = true
                }
            } else {
                pulsePhase = false
            }
        }
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

    private var formattedOffRouteDistance: String {
        let meters = session.distanceFromRouteMeters
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    }

    // MARK: - Zone F · Map + floating controls

    private var navigationMap: some View {
        OfflineCapableMapView(
            region: $mapRegion,
            isFollowingUser: $isFollowingUser,
            routePolyline: ridePreferences.enabledOverlays.contains(.routeLine) ? route.clTrackpoints : [],
            breadcrumb: ridePreferences.enabledOverlays.contains(.breadcrumbs) ? breadcrumbs : [],
            routeColor: UIColor(BCColors.brandBlue),
            tilePack: tilePackInfo
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

    // MARK: - Bottom control bar (audio + END RIDE)

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
                showEndConfirm = true
            } label: {
                Text("END RIDE")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 44)
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
                    enduranceStat(value: session.formattedDistance, label: "DIST")
                    enduranceStat(value: session.formattedElapsedTime, label: "TIME")
                    enduranceStat(value: String(format: "%.1f", locationService.averageSpeedMPH), label: "AVG")
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

    private static func initialMapRegion(for route: Route) -> MKCoordinateRegion {
        let coords = route.clTrackpoints
        guard let first = coords.first else {
            return MKCoordinateRegion(
                center: route.clStartCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coord in coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.3, 0.02),
                longitudeDelta: max((maxLon - minLon) * 1.3, 0.02)
            )
        )
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

    // MARK: - Lifecycle

    private func startRide() {
        guard route.isNavigable else {
            dismiss()
            return
        }
        coordinator.powerMode = powerMode
        coordinator.startPreflight()
        Task {
            tilePackInfo = await OfflineTilePackManager.shared.installedPack(forRouteId: route.id)
        }
    }

    private func stopServices() {
        coordinator.handleDisappear()
    }

    private func loadWeather() async {
        weather = await WeatherService.shared.weather(for: route.clStartCoordinate)
    }

    private func endRide() {
        audioService.announceRideComplete(
            distance: session.distanceTraveledMiles,
            time: session.formattedElapsedTime
        )

        coordinator.freezeForSave()
        guard let snapshot = coordinator.frozenSnapshot else { return }
        shouldShowConditionReportAfterSave = true
        saveSnapshot = snapshot
    }

    // MARK: - GPS tick — audio cues, breadcrumb, Live Activity update, camera follow

    private func onLocationTick() {
        coordinator.refreshPreflightStatus()
        guard coordinator.lifecycleState == .recording else { return }
        guard let loc = locationService.userLocation else { return }

        coordinator.handleLocationTick()
        EmergencySafetyService.shared.updateLocation(loc)

        // Breadcrumb display is sparser than the saved track in endurance mode.
        if let last = breadcrumbs.last {
            let lastCL = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let currentCL = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
            if currentCL.distance(from: lastCL) > powerMode.breadcrumbDistanceMeters {
                breadcrumbs.append(loc)
            }
        } else {
            breadcrumbs.append(loc)
        }
        if breadcrumbs.count > RideTuning.maxInMemoryTrackpoints {
            breadcrumbs.removeFirst(breadcrumbs.count - RideTuning.maxInMemoryTrackpoints)
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

// MARK: - Elevation profile shape

private struct ElevationShape: Shape {
    let elevations: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard elevations.count >= 2 else { return path }

        let minE = elevations.min() ?? 0
        let maxE = elevations.max() ?? 1
        let range = max(maxE - minE, 1)
        let paddedMin = minE - range * 0.1
        let paddedRange = range * 1.2

        for (i, e) in elevations.enumerated() {
            let x = CGFloat(i) / CGFloat(max(elevations.count - 1, 1)) * rect.width
            let y = CGFloat(1 - (e - paddedMin) / paddedRange) * rect.height
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

// MARK: - Condition Report Sheet (unchanged post-ride flow)

struct ConditionReportSheet: View {
    let routeId: String
    let routeName: String
    let onDismiss: () -> Void

    @State private var selectedCondition: RideCondition?
    @State private var note = ""
    @Environment(\.dismiss) var sheetDismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("How was the trail?")
                    .font(.system(size: 18, weight: .semibold))

                Text(routeName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(RideCondition.allCases, id: \.self) { condition in
                        Button {
                            selectedCondition = condition
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: condition.icon)
                                    .font(.system(size: 20))
                                Text(condition.label)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedCondition == condition
                                        ? Color.accentColor.opacity(0.2)
                                        : Color(UIColor.tertiarySystemBackground))
                            .clipShape(Rectangle())
                            .overlay(
                                Rectangle()
                                    .stroke(selectedCondition == condition ? Color.accentColor : .clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                TextField("Add a note (optional)", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                Spacer()
            }
            .padding()
            .navigationTitle("Trail Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") {
                        sheetDismiss()
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        if let condition = selectedCondition {
                            RouteConditionReporter.shared.submitReport(
                                routeId: routeId,
                                condition: condition,
                                note: note.isEmpty ? nil : note
                            )
                        }
                        sheetDismiss()
                        onDismiss()
                    }
                    .disabled(selectedCondition == nil)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        RouteNavigationView(route: .preview)
    }
    .environment(AppState())
}
