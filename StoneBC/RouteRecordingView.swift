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
    @State private var locationService = LocationService()
    @State private var altimeterService = AltimeterService()
    @State private var audioService = NavigationAudioService()
    @State private var recording = RecordingService()

    @State private var position: MapCameraPosition = .automatic
    @State private var isFollowingUser = true
    @State private var showStopConfirm = false
    @State private var showSaveSheet = false
    @State private var pulsePhase = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            headerStrip
            navigationMap
            speedTile
            recordedSummaryTile
            sensorStrip
            if recording.state == .paused {
                pausedBanner
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
        .onAppear(perform: startRecording)
        .onDisappear(perform: stopServices)
        .onChange(of: locationService.userLocation?.latitude, onLocationTick)
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
            RecordingSaveSheet(recording: recording) {
                dismiss()
            }
        }
    }

    // MARK: - Zone A · Header

    private var headerStrip: some View {
        ZStack {
            HStack(spacing: 6) {
                Circle()
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

    private var topSafeAreaInset: CGFloat {
        UIApplication.shared
            .connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.top ?? 0
    }

    // MARK: - Zone F · Map + recorded track polyline

    private var navigationMap: some View {
        Map(position: $position) {
            // Live track so far
            if recording.trackpoints.count >= 2 {
                MapPolyline(coordinates: recording.trackpoints.map { $0.coordinate })
                    .stroke(BCColors.brandBlue, lineWidth: 4)
            }

            if let userLoc = locationService.userLocation {
                Annotation("You", coordinate: userLoc) {
                    ZStack {
                        Circle()
                            .fill(BCColors.brandBlue.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Circle()
                            .fill(recording.state == .paused ? BCColors.navAlertAmber : .red)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
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
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 1)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(.red)
                .offset(y: -32)

            Image(systemName: "arrow.up")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(BCColors.brandGreen)
                .rotationEffect(.degrees(locationService.heading))
                .animation(.easeInOut(duration: 0.3), value: locationService.heading)
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
                value: ascentFormatter.string(from: NSNumber(value: Int(altimeterService.fusedAltitudeFeet))) ?? "0",
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

    // MARK: - Bottom control bar

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
                togglePause()
            } label: {
                Image(systemName: recording.state == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 44)
                    .background(
                        recording.state == .paused ? BCColors.brandGreen : BCColors.navAlertAmber,
                        in: Capsule()
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

    // MARK: - Lifecycle / ticks

    private func startRecording() {
        locationService.requestPermission()
        locationService.startTracking()
        altimeterService.start()
        audioService.reset()

        recording.onAutoPause = { [audioService] in
            audioService.announcePaused()
        }
        recording.onAutoResume = { [audioService] in
            audioService.announceResumed()
        }
        recording.start()
    }

    private func stopServices() {
        locationService.stopTracking()
        altimeterService.stop()
        recording.stop()
    }

    private func togglePause() {
        switch recording.state {
        case .recording: recording.pause()
        case .paused:    recording.resume()
        default: break
        }
    }

    private func finishRecording() {
        recording.stop()
        if recording.isSaveable {
            showSaveSheet = true
        } else {
            dismiss()
        }
    }

    private func recenterOnUser() {
        guard let loc = locationService.userLocation else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            position = .camera(MapCamera(
                centerCoordinate: loc,
                distance: 1500,
                heading: locationService.heading,
                pitch: 45
            ))
        }
    }

    private func onLocationTick(_ oldLat: Double?, _ newLat: Double?) {
        guard let loc = locationService.userLocation else { return }

        if let cl = locationService.locationHistory.last {
            recording.ingestLocation(cl)
        }

        if isFollowingUser {
            withAnimation(.easeInOut(duration: 0.5)) {
                position = .camera(MapCamera(
                    centerCoordinate: loc,
                    distance: 1500,
                    heading: locationService.heading,
                    pitch: 45
                ))
            }
        }
    }
}

// MARK: - Save sheet

struct RecordingSaveSheet: View {
    let recording: RecordingService
    let onDone: () -> Void

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
    @Environment(\.dismiss) var sheetDismiss

    private let categories = ["road", "gravel", "fatbike", "trail"]
    private let difficulties = ["easy", "moderate", "hard", "expert"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Summary") {
                    LabeledContent("Distance", value: recording.formattedDistance)
                    LabeledContent("Time", value: recording.formattedElapsed)
                    LabeledContent("Climb", value: "\(Int(recording.totalAscentFeet)) ft")
                    LabeledContent("Avg speed", value: String(format: "%.1f mph", recording.avgSpeedMPH))
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
            .navigationTitle("Save Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Discard", role: .destructive) {
                        sheetDismiss()
                        onDone()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        performSave()
                        if submitToCoop {
                            Task { await submitRouteToCoop() }
                        } else {
                            sheetDismiss()
                            onDone()
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
        }
    }

    private func performSave() {
        let name = routeName.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Recorded Ride"
            : routeName

        if saveToHistory {
            RideHistoryService.shared.recordRide(
                routeId: UUID().uuidString,
                routeName: name,
                category: category,
                distanceMiles: recording.distanceMiles,
                elapsedSeconds: recording.elapsedSeconds,
                movingSeconds: recording.movingSeconds,
                elevationGainFeet: recording.totalAscentFeet,
                avgSpeedMPH: recording.avgSpeedMPH,
                maxSpeedMPH: recording.maxSpeedMPH
            )
        }

        if saveAsRoute, recording.isSaveable, let first = recording.trackpoints.first {
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
                    latitude: first.coordinate.latitude,
                    longitude: first.coordinate.longitude
                ),
                trackpoints: recording.routeTrackpointTriples,
                isImported: true
            )
            UserRouteStore.shared.save(route)
        }
    }

    @MainActor
    private func submitRouteToCoop() async {
        isSubmitting = true
        let name = routeName.trimmingCharacters(in: .whitespaces).isEmpty ? "Recorded Ride" : routeName
        let gpxString = RideExportService.exportGPX(
            routeName: name,
            locations: recording.trackpoints,
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
