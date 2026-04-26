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

    @State private var locationService = LocationService()
    @State private var altimeterService = AltimeterService()
    @State private var audioService = NavigationAudioService()
    @State private var workoutService = WorkoutService()
    @State private var activityManager = RideActivityManager()
    @State private var session: RideSession
    private var networkStatus = NetworkStatusService.shared
    @State private var mapRegion: MKCoordinateRegion
    @State private var tilePackInfo: OfflineTilePackInfo?
    @State private var isFollowingUser = true
    @State private var showEndConfirm = false
    @State private var showConditionReport = false
    @State private var wasOffRoute = false
    @State private var breadcrumbs: [CLLocationCoordinate2D] = []
    @State private var precomputedTurns: [TurnPoint] = []
    @State private var pulsePhase = false
    @Environment(\.dismiss) var dismiss

    init(route: Route) {
        self.route = route
        self._session = State(initialValue: RideSession(route: route))
        self._mapRegion = State(initialValue: Self.initialMapRegion(for: route))
    }

    var body: some View {
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
            sensorStrip       // D — 80 pt
            if session.isOffRoute {
                offRouteBanner // E — 40 pt, conditional
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            bottomControlBar  // Audio + END RIDE — 56 pt, thumb-reachable
        }
        .background(BCColors.navPanel)
        .ignoresSafeArea(edges: .top)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.25), value: session.isOffRoute)
        .animation(.easeInOut(duration: 0.25), value: session.isCriticallyOffRoute)
        .onAppear(perform: startRide)
        .task { await requestWorkoutAuthorization() }
        .onDisappear(perform: stopServices)
        .onChange(of: locationService.locationUpdateCount) { _, _ in
            onLocationTick()
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
            Circle()
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

    // MARK: - Zone D · Sensor strip

    private var sensorStrip: some View {
        HStack(spacing: 0) {
            sensorTile(
                value: String(format: "%@", numberFormatter.string(from: NSNumber(value: Int(altimeterService.fusedAltitudeFeet))) ?? "0"),
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

    // MARK: - Zone E · Off-route banner

    /// Small pill overlay on the navigation map. Shows when the rider is
    /// offline AND/OR outside the bundled tile pack region — both states
    /// degrade the live basemap, but the polyline + breadcrumb + cue sheet
    /// keep working.
    private var offlinePill: some View {
        Group {
            if let label = offlinePillLabel {
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
                    Capsule()
                        .fill(Color.black.opacity(0.7))
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5)
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
            routePolyline: route.clTrackpoints,
            breadcrumb: breadcrumbs,
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
                        .background(.ultraThinMaterial, in: Circle())
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
                audioService.isEnabled.toggle()
            } label: {
                Image(systemName: audioService.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(audioService.isEnabled ? .white : .orange)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08), in: Circle())
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
                    .background(Color.red.opacity(0.9), in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .padding(.bottom, bottomSafeAreaInset)
        .background(BCColors.navPanel)
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
        locationService.onFirstAltitude = { [altimeterService] gpsAltitude in
            altimeterService.calibrateWithGPS(altitudeMeters: gpsAltitude)
        }
        // Feed barometer-fused altitude into the ride engine so ascent math
        // beats GPS-only inflation in canyons.
        session.altitudeProvider = { [altimeterService] in
            altimeterService.fusedAltitudeMeters
        }
        locationService.requestPermission()
        locationService.startTracking(mode: .ride)
        altimeterService.start()
        audioService.reset()
        session.start()

        precomputedTurns = RouteAnalysisService.analyzeTurns(for: route)
        activityManager.startActivity(
            routeName: route.name,
            distanceMiles: route.distanceMiles,
            category: route.category
        )
        Task {
            tilePackInfo = await OfflineTilePackManager.shared.installedPack(forRouteId: route.id)
        }
    }

    private func stopServices() {
        locationService.stopTracking()
        altimeterService.stop()
        session.stop()
    }

    private func requestWorkoutAuthorization() async {
        guard workoutService.isAvailable else { return }
        await workoutService.requestAuthorization()
        if workoutService.isAuthorized {
            await workoutService.startWorkout(routeName: route.name)
        }
    }

    private func endRide() {
        audioService.announceRideComplete(
            distance: session.distanceTraveledMiles,
            time: session.formattedElapsedTime
        )
        let effectiveStart = session.effectiveStartedAt ?? Date()
        activityManager.endActivity(
            finalDistance: session.distanceTraveledMiles,
            rideStartedAt: effectiveStart,
            pausedAt: session.pausedAt
        )
        let endDate = session.lastLocation?.timestamp ?? Date()
        let events = session.pauseEvents.map { (date: $0.date, isPause: $0.kind == .pause) }
        Task {
            await workoutService.endWorkout(endDate: endDate, pauseEvents: events)
        }
        RideHistoryService.shared.recordRide(
            routeId: route.id,
            routeName: route.name,
            category: route.category,
            distanceMiles: session.distanceTraveledMiles,
            elapsedSeconds: session.elapsedSeconds,
            movingSeconds: session.movingSeconds,
            elevationGainFeet: Double(altimeterService.totalAscentFeet),
            avgSpeedMPH: locationService.averageSpeedMPH,
            maxSpeedMPH: locationService.maxSpeedMPH
        )
        EmergencySafetyService.shared.lastKnownLocation = nil
        stopServices()
        showConditionReport = true
    }

    // MARK: - GPS tick — audio cues, breadcrumb, Live Activity update, camera follow

    private func onLocationTick() {
        guard let loc = locationService.userLocation else { return }

        if let location = locationService.lastLocation {
            // Drift correction — feed tight-vertical-accuracy GPS samples into
            // the barometer baseline so fused altitude doesn't drift over a
            // long climb.
            altimeterService.recalibrateIfPossible(
                gpsAltitudeMeters: location.altitude,
                verticalAccuracy: location.verticalAccuracy
            )
            session.updateLocation(location)
        } else {
            session.updateLocation(loc, speed: locationService.speedMPS)
        }
        EmergencySafetyService.shared.updateLocation(loc)

        // Breadcrumb every ~10 m
        if let last = breadcrumbs.last {
            let lastCL = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let currentCL = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
            if currentCL.distance(from: lastCL) > 10 {
                breadcrumbs.append(loc)
            }
        } else {
            breadcrumbs.append(loc)
        }

        // Off-route audio (tiered logic lives in session)
        if session.isOffRoute {
            if !wasOffRoute || session.isCriticallyOffRoute {
                audioService.announceOffRoute(distanceMeters: session.distanceFromRouteMeters)
                wasOffRoute = true
            }
        } else if wasOffRoute {
            audioService.announceBackOnRoute()
            wasOffRoute = false
        }

        // Milestone audio
        audioService.checkMilestone(
            distanceMiles: session.distanceTraveledMiles,
            totalMiles: route.distanceMiles
        )

        // Live Activity — the widget renders the timer via `Text(timerInterval:
        // ..., pauseTime:)` keyed off `effectiveStartedAt`, so we don't push
        // every-second updates. Throttle inside the manager. Force a push
        // whenever the off-route flag flips so the banner doesn't lag.
        let offRouteFlipped = (session.isOffRoute != wasOffRoute)
        if let effectiveStart = session.effectiveStartedAt {
            activityManager.updateActivity(
                speedMPH: locationService.speedMPH,
                distanceTraveled: session.distanceTraveledMiles,
                distanceRemaining: session.distanceRemainingMiles,
                rideStartedAt: effectiveStart,
                pausedAt: session.pausedAt,
                progress: session.progressPercent,
                isOffRoute: session.isOffRoute,
                heading: locationService.navigationHeading,
                force: offRouteFlipped
            )
        }

        // HealthKit GPS feed every ~5 breadcrumbs
        if workoutService.isRecording && breadcrumbs.count % 5 == 0 {
            let recent = Array(locationService.locationHistory.suffix(5))
            workoutService.addRouteData(recent)
        }

        // Turn announcement (pre-computed)
        if let nextTurn = RouteAnalysisService.nextTurn(
            from: session.closestTrackpointIndex,
            in: precomputedTurns
        ) {
            let dist = RouteAnalysisService.distanceToTurn(
                from: session.closestTrackpointIndex,
                to: nextTurn,
                trackpoints: route.clTrackpoints
            )
            if dist < 200 && dist > 10 {
                audioService.announceTurn(direction: nextTurn.direction, distanceAhead: dist)
            }
        }

        // Camera follow
        if isFollowingUser {
            withAnimation(.easeInOut(duration: 0.5)) {
                mapRegion = MKCoordinateRegion(
                    center: loc,
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                )
            }
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
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
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
}
