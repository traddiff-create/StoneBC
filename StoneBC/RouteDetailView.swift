//
//  RouteDetailView.swift
//  StoneBC
//
//  Route detail with stats grid, elevation profile, and map preview
//

import SwiftUI
import Charts
import MapKit

struct RouteDetailView: View {
    let route: Route
    @State private var showFullMap = false
    @State private var gpxFileURL: URL?
    @State private var routeDeviceBundleURL: URL?
    @State private var routeTCXURL: URL?
    @State private var routeFITURL: URL?
    @State private var routeKMLURL: URL?
    @State private var showShareCard = false
    @State private var showRouteRecording = false
    @State private var providerMessage: String?
    @State private var detailMode: RouteDetailMode = .overview
    @State private var ridePreferences: RouteRidePreferences
    @State private var recordingMode: RouteRecordingMode
    @State private var isPreparing = false
    @State private var isCachedOffline = false
    @State private var offlineStorageSize = ""
    @State private var cachedRouteEntry: OfflineRouteStorage.CachedRouteEntry?
    @State private var tileSources: [OfflineTileSource] = []
    @State private var selectedTileSource: OfflineTileSource?
    @State private var tilePackInfo: OfflineTilePackInfo?
    @State private var tileDownloadProgress: OfflineTileDownloadProgress?
    @State private var tileDownloadTask: Task<Void, Never>?
    @State private var isDownloadingTiles = false
    @State private var tileDownloadError: String?
    @State private var stravaSegments: [StravaSegment] = []
    @State private var trailClosures: [TrailClosure] = []
    @State private var isFavorite = false
    @State private var isTimeTrial = false
    private var networkStatus = NetworkStatusService.shared

    init(route: Route) {
        self.route = route
        let preferences = RouteRidePreferences.load(route: route)
        self._ridePreferences = State(initialValue: preferences)
        self._recordingMode = State(initialValue: preferences.defaultRecordingMode == .free ? .follow : preferences.defaultRecordingMode)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BCSpacing.lg) {
                headerSection

                detailModePicker
                detailModeContent
            }
            .padding(BCSpacing.md)
        }
        .background(BCColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(route.name.uppercased())
                    .font(.bcSectionTitle)
                    .tracking(2)
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        EventNotificationService.shared.toggleFavorite(routeId: route.id)
                        isFavorite.toggle()
                    } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(isFavorite ? .red : .primary)
                    }
                    .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                    Menu {
                        if let routeDeviceBundleURL {
                            ShareLink(item: routeDeviceBundleURL) {
                                Label("Share Device Bundle", systemImage: "shippingbox")
                            }
                        }
                        if let gpxFileURL {
                            ShareLink(item: gpxFileURL) {
                                Label("Export GPX File", systemImage: "doc")
                            }
                        }
                        if let routeTCXURL {
                            ShareLink(item: routeTCXURL) {
                                Label("Export TCX Course", systemImage: "doc.badge.gearshape")
                            }
                        }
                        if let routeFITURL {
                            ShareLink(item: routeFITURL) {
                                Label("Export FIT Course", systemImage: "doc.zipper")
                            }
                        }
                        if let routeKMLURL {
                            ShareLink(item: routeKMLURL) {
                                Label("Export KML", systemImage: "map")
                            }
                        }
                        Divider()
                        Button {
                            Task { await sendRoute(to: .garmin) }
                        } label: {
                            Label("Send to Garmin", systemImage: ConnectedRouteProvider.garmin.icon)
                        }
                        Button {
                            Task { await sendRoute(to: .wahoo) }
                        } label: {
                            Label("Send to Wahoo", systemImage: ConnectedRouteProvider.wahoo.icon)
                        }
                        Button {
                            Task { await sendRoute(to: .rideWithGPS) }
                        } label: {
                            Label("Send to Ride with GPS", systemImage: ConnectedRouteProvider.rideWithGPS.icon)
                        }
                        Divider()
                        Button {
                            showShareCard = true
                        } label: {
                            Label("Share as Image", systemImage: "photo")
                        }
                        Divider()
                        Button {
                            if isTimeTrial {
                                TimeTrialService.shared.removePreset(routeId: route.id)
                            } else {
                                TimeTrialService.shared.addPreset(routeId: route.id, routeName: route.name)
                            }
                            isTimeTrial.toggle()
                        } label: {
                            Label(
                                isTimeTrial ? "Remove Time Trial" : "Set as Time Trial",
                                systemImage: isTimeTrial ? "stopwatch.fill" : "stopwatch"
                            )
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                    }
                    .accessibilityLabel("Share route")

                    NavigationLink(destination: RouteNavigationView(route: route, ridePreferences: ridePreferences)) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                    }
                    .accessibilityLabel("Navigate route")
                }
            }
        }
        .task {
            routeDeviceBundleURL = RouteInterchangeService.writeRouteExport(route: route, format: .deviceBundle)
            gpxFileURL = RouteInterchangeService.writeRouteExport(route: route, format: .gpxTrack)
            routeTCXURL = RouteInterchangeService.writeRouteExport(route: route, format: .tcxCourse)
            routeFITURL = RouteInterchangeService.writeRouteExport(route: route, format: .fitCourse)
            routeKMLURL = RouteInterchangeService.writeRouteExport(route: route, format: .kml)
            await refreshOfflineState()
            isFavorite = EventNotificationService.shared.isFavorite(routeId: route.id)
            isTimeTrial = TimeTrialService.shared.isPreset(routeId: route.id)

            // Load USFS closures
            trailClosures = await USFSService.shared.closuresAffecting(route: route)

            // Load Strava segments if authenticated
            if StravaService.shared.isAuthenticated {
                stravaSegments = await StravaService.shared.segments(
                    near: route.clStartCoordinate,
                    routeId: route.id
                )
            }
        }
        .sheet(isPresented: $showShareCard) {
            ShareCardSheet(route: route)
        }
        .alert("Route Share", isPresented: Binding(
            get: { providerMessage != nil },
            set: { if !$0 { providerMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(providerMessage ?? "")
        }
        .fullScreenCover(isPresented: $showRouteRecording) {
            RouteRecordingView(route: route, recordingMode: recordingMode)
        }
        .onDisappear {
            tileDownloadTask?.cancel()
        }
        .fullScreenCover(isPresented: $showFullMap) {
            NavigationStack {
                RouteMapView(focusedRoute: route)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") {
                                showFullMap = false
                            }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var detailModeContent: some View {
        switch detailMode {
        case .overview:
            overviewContent
        case .prep:
            prepContent
        case .ride:
            rideContent
        case .history:
            historyContent
        }
    }

    private var detailModePicker: some View {
        Picker("Route section", selection: $detailMode) {
            ForEach(RouteDetailMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Route section")
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: BCSpacing.lg) {
            DisclaimerBannerView()
            statsGrid
            elevationProfile
            mapPreview
            descriptionSection

            if let gpxURL = route.gpxURL {
                VStack(alignment: .leading, spacing: 8) {
                    Text("INTERACTIVE MAP")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.secondary)

                    GPXStudioMapView(
                        gpxURL: gpxURL,
                        centerLat: route.startCoordinate.latitude,
                        centerLon: route.startCoordinate.longitude
                    )
                    .frame(height: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                gpxStudioLink
                forkRouteButton
            }
        }
    }

    private var prepContent: some View {
        VStack(alignment: .leading, spacing: BCSpacing.lg) {
            routeReadinessSection
            RouteWeatherSection(route: route)
            trailIntelligenceSection
            offlineToolsSection
            prepNotesSection
        }
    }

    private var rideContent: some View {
        VStack(alignment: .leading, spacing: BCSpacing.lg) {
            rideActionsSection
            rideOverlaySection
            mapPreview
            if StravaService.shared.isConfigured {
                stravaSection
            }
        }
    }

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: BCSpacing.lg) {
            routeHistorySection
            routeShareSection
            if StravaService.shared.isConfigured {
                stravaSection
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(route.name)
                .font(.system(size: 24, weight: .semibold))

            HStack(spacing: 8) {
                DifficultyBadge(difficulty: route.difficulty)
                CategoryBadge(category: route.category)
                Spacer()
                Text(route.region)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(route.name). \(route.difficulty) \(route.category) in \(route.region).")
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(icon: "arrow.left.arrow.right", label: "Distance", value: route.formattedDistance)
                StatCard(icon: "arrow.up.right", label: "Elevation Gain", value: route.formattedElevation)
            }
            HStack(spacing: 12) {
                StatCard(icon: "mountain.2", label: "Elevation Range", value: route.elevationRange)
                StatCard(icon: "point.topleft.down.to.point.bottomright.curvepath", label: "Trackpoints", value: "\(route.trackpoints.count)")
            }
        }
    }

    // MARK: - Elevation Profile
    private var elevationProfile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ELEVATION PROFILE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            let elevations = route.elevations
            if elevations.count > 2 {
                Chart {
                    ForEach(Array(elevations.enumerated()), id: \.offset) { index, elevation in
                        let distancePercent = Double(index) / Double(max(elevations.count - 1, 1))
                        let distanceMiles = distancePercent * route.distanceMiles

                        AreaMark(
                            x: .value("Distance", distanceMiles),
                            y: .value("Elevation", elevation * 3.28084) // meters to feet
                        )
                        .foregroundStyle(
                            .linearGradient(
                                colors: [BCColors.brandGreen.opacity(0.3), BCColors.brandGreen.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Distance", distanceMiles),
                            y: .value("Elevation", elevation * 3.28084)
                        )
                        .foregroundStyle(BCColors.brandGreen)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .chartXAxisLabel("Miles")
                .chartYAxisLabel("Feet")
                .frame(height: 160)
                .accessibilityLabel("Elevation profile chart showing elevation changes over \(route.formattedDistance)")
            } else {
                Text("Elevation data not available")
                    .font(.bcSecondaryText)
                    .foregroundColor(.secondary)
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Map Preview
    private var mapPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ROUTE MAP")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    showFullMap = true
                } label: {
                    Text("FULL MAP")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(BCColors.brandBlue)
                }
            }

            Map {
                MapPolyline(coordinates: route.clTrackpoints)
                    .stroke(BCColors.brandBlue, lineWidth: 3)

                if let first = route.clTrackpoints.first {
                    Annotation("Start", coordinate: first) {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }

                if let last = route.clTrackpoints.last, route.clTrackpoints.count > 1 {
                    Annotation("End", coordinate: last) {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .allowsHitTesting(false)
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Readiness

    private var routeReadinessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ROUTE READINESS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(readinessCompleteCount)/\(readinessRows.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(readinessCompleteCount == readinessRows.count ? BCColors.brandGreen : BCColors.brandBlue)
                    .monospacedDigit()
            }

            ForEach(readinessRows) { row in
                readinessRow(row)
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var readinessRows: [RouteReadinessRow] {
        [
            RouteReadinessRow(
                id: "route",
                title: "Route Data",
                subtitle: route.isNavigable ? "\(route.clTrackpoints.count) trackpoints available" : "Trackpoints missing",
                isReady: route.isNavigable,
                icon: "point.topleft.down.to.point.bottomright.curvepath"
            ),
            RouteReadinessRow(
                id: "offline",
                title: "Offline Route",
                subtitle: isCachedOffline ? "Route data and preview cached" : "Save route for no-service riding",
                isReady: isCachedOffline,
                icon: "arrow.down.circle"
            ),
            RouteReadinessRow(
                id: "tiles",
                title: "Offline Tiles",
                subtitle: tilePackInfo.map { "\($0.source.name) · \($0.formattedSize)" } ?? "Download a map pack for this route",
                isReady: tilePackInfo != nil || cachedRouteEntry?.tilesAvailable == true,
                icon: "map"
            ),
            RouteReadinessRow(
                id: "weather",
                title: "Weather Cache",
                subtitle: cachedRouteEntry?.hasWeather == true ? "Weather saved with offline route" : "Open Prep or save offline to refresh weather",
                isReady: cachedRouteEntry?.hasWeather == true,
                icon: "cloud.sun"
            ),
            RouteReadinessRow(
                id: "cues",
                title: "Cue Sheet",
                subtitle: route.cuePoints.isEmpty ? "Turn prompts will be generated from route shape" : "\(route.cuePoints.count) cue points",
                isReady: route.isNavigable,
                icon: "arrow.turn.up.right"
            ),
            RouteReadinessRow(
                id: "cell",
                title: "Cell Coverage",
                subtitle: "Coverage tool available before departure",
                isReady: true,
                icon: "antenna.radiowaves.left.and.right"
            )
        ]
    }

    private var readinessCompleteCount: Int {
        readinessRows.filter(\.isReady).count
    }

    private func readinessRow(_ row: RouteReadinessRow) -> some View {
        HStack(spacing: 10) {
            Image(systemName: row.isReady ? "checkmark.circle.fill" : row.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(row.isReady ? BCColors.brandGreen : .orange)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Text(row.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(BCSpacing.sm)
        .background(BCColors.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.title), \(row.isReady ? "ready" : "not ready"), \(row.subtitle)")
    }

    private var prepNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PREP NOTES")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            let notes = route.rideDefaults?.prepNotes ?? defaultPrepNotes
            ForEach(notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 11))
                        .foregroundColor(BCColors.brandBlue)
                        .padding(.top, 1)
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .lineSpacing(3)
                }
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var defaultPrepNotes: [String] {
        [
            "Save this route offline before heading into low-service areas.",
            "Check weather, trail conditions, and cell coverage before starting.",
            "Confirm your recording mode and ride overlays before departure."
        ]
    }

    // MARK: - Ride Setup

    private var rideActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RIDE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            NavigationLink(destination: JourneyConsoleView(route: route)) {
                toolRow(
                    icon: "map.fill",
                    iconColor: BCColors.brandBlue,
                    title: "Journey Console",
                    subtitle: "Offline readiness, safety, power, and camp review",
                    trailing: "chevron.right"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: RouteNavigationView(route: route, ridePreferences: ridePreferences)) {
                toolRow(
                    icon: "location.fill",
                    iconColor: BCColors.brandGreen,
                    title: "Start Navigation",
                    subtitle: "Follow route with selected overlays",
                    trailing: "chevron.right"
                )
            }
            .buttonStyle(.plain)

            Picker("Recording mode", selection: $recordingMode) {
                ForEach([RouteRecordingMode.follow, .scout], id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: recordingMode) { _, newMode in
                ridePreferences.defaultRecordingMode = newMode
                saveRidePreferences()
            }
            .accessibilityLabel("Recording mode")

            Button {
                showRouteRecording = true
            } label: {
                toolRow(
                    icon: recordingMode.icon,
                    iconColor: recordingMode == .scout ? BCColors.brandAmber : BCColors.brandBlue,
                    title: "Record \(recordingMode.label)",
                    subtitle: recordingMode.subtitle,
                    trailing: "record.circle"
                )
            }
            .buttonStyle(.plain)
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var rideOverlaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RIDE OVERLAYS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Reset") {
                    ridePreferences.enabledOverlays = route.defaultRideOverlays
                    saveRidePreferences()
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(BCColors.brandBlue)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(RouteRideOverlay.allCases) { overlay in
                    overlayToggle(overlay)
                }
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func overlayToggle(_ overlay: RouteRideOverlay) -> some View {
        let isEnabled = ridePreferences.enabledOverlays.contains(overlay)
        return Button {
            if isEnabled {
                ridePreferences.enabledOverlays.remove(overlay)
            } else {
                ridePreferences.enabledOverlays.insert(overlay)
            }
            saveRidePreferences()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: overlay.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(overlay.label)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(isEnabled ? BCColors.brandBlue : BCColors.overlayLight)
            .foregroundColor(isEnabled ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(overlay.label) overlay")
        .accessibilityAddTraits(isEnabled ? .isSelected : [])
    }

    private func saveRidePreferences() {
        ridePreferences.save(routeId: route.id)
    }

    @MainActor
    private func sendRoute(to provider: ConnectedRouteProvider) async {
        let result = await RouteProviderManager.shared.push(route: route, to: provider)
        switch result {
        case .success(let push):
            providerMessage = push.message
        case .failure(let error):
            providerMessage = error.localizedDescription
        }
    }

    // MARK: - History

    private var routeHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RIDE HISTORY")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            let rides = RideHistoryService.shared.rides.filter { $0.routeId == route.id }
            if rides.isEmpty {
                Text("No rides recorded on this route yet.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(BCSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BCColors.cardBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(rides.prefix(5)) { ride in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ride.formattedDate)
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(ride.formattedDistance) · \(ride.formattedTime) · \(String(format: "%.1f mph", ride.avgSpeedMPH))")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if ride.isTimeTrial {
                            Image(systemName: "stopwatch.fill")
                                .foregroundColor(BCColors.brandAmber)
                        }
                    }
                    .padding(BCSpacing.sm)
                    .background(BCColors.cardBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var routeShareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SHARE + PRESETS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            if let routeDeviceBundleURL {
                ShareLink(item: routeDeviceBundleURL) {
                    toolRow(
                        icon: "shippingbox",
                        iconColor: BCColors.brandGreen,
                        title: "Share Device Bundle",
                        subtitle: "GPX, TCX, FIT, KML, and README",
                        trailing: "square.and.arrow.up"
                    )
                }
            }

            if let gpxFileURL {
                ShareLink(item: gpxFileURL) {
                    toolRow(
                        icon: "doc",
                        iconColor: BCColors.brandBlue,
                        title: "Choose Format: GPX",
                        subtitle: "Track file for broad app compatibility",
                        trailing: "square.and.arrow.up"
                    )
                }
            }

            HStack(spacing: 8) {
                if let routeTCXURL {
                    ShareLink(item: routeTCXURL) {
                        formatChip(title: "TCX", icon: "doc.badge.gearshape")
                    }
                }
                if let routeFITURL {
                    ShareLink(item: routeFITURL) {
                        formatChip(title: "FIT", icon: "doc.zipper")
                    }
                }
                if let routeKMLURL {
                    ShareLink(item: routeKMLURL) {
                        formatChip(title: "KML", icon: "map")
                    }
                }
            }

            VStack(spacing: 1) {
                providerRow(provider: .garmin)
                providerRow(provider: .wahoo)
                providerRow(provider: .rideWithGPS)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Button {
                showShareCard = true
            } label: {
                toolRow(
                    icon: "photo",
                    iconColor: BCColors.brandBlue,
                    title: "Share as Image",
                    subtitle: "Create a route card for this route",
                    trailing: "square.and.arrow.up"
                )
            }
            .buttonStyle(.plain)

            Button {
                if isTimeTrial {
                    TimeTrialService.shared.removePreset(routeId: route.id)
                } else {
                    TimeTrialService.shared.addPreset(routeId: route.id, routeName: route.name)
                }
                isTimeTrial.toggle()
            } label: {
                toolRow(
                    icon: isTimeTrial ? "stopwatch.fill" : "stopwatch",
                    iconColor: BCColors.brandAmber,
                    title: isTimeTrial ? "Remove Time Trial" : "Set as Time Trial",
                    subtitle: "Compare future attempts against your best time",
                    trailing: nil
                )
            }
            .buttonStyle(.plain)
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatChip(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(BCColors.brandBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(BCColors.brandBlue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func providerRow(provider: ConnectedRouteProvider) -> some View {
        Button {
            Task { await sendRoute(to: provider) }
        } label: {
            toolRow(
                icon: provider.icon,
                iconColor: BCColors.brandAmber,
                title: "Send to \(provider.displayName)",
                subtitle: "Uses provider API when connected; export bundle stays available offline",
                trailing: "arrow.up.right"
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Offline & Coverage Tools
    private var offlineToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RIDE TOOLS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            NavigationLink(destination: CellCoverageView(route: route)) {
                toolRow(
                    icon: "antenna.radiowaves.left.and.right",
                    iconColor: .orange,
                    title: "Cell Coverage",
                    subtitle: "See dead zones on route",
                    trailing: "chevron.right"
                )
            }
            .buttonStyle(.plain)

            Button {
                isPreparing = true
                Task {
                    let snapshot = await OfflineMapService.shared.generateSnapshot(for: route)
                    let alreadyHasSnapshot = await OfflineMapService.shared.hasSnapshot(for: route.id)
                    let hasSnapshot = snapshot != nil || alreadyHasSnapshot
                    let tilesAvailable = OfflineTileCoverage.contains(route: route)
                    await OfflineRouteStorage.shared.cacheRoute(
                        route,
                        hasSnapshot: hasSnapshot,
                        tilesAvailable: tilesAvailable
                    )

                    // Cache current weather if available
                    if let weather = await WeatherService.shared.weather(for: route.clStartCoordinate) {
                        await OfflineRouteStorage.shared.cacheWeather(weather, routeId: route.id)
                    }

                    isPreparing = false
                    isCachedOffline = true
                    offlineStorageSize = await OfflineRouteStorage.shared.formattedCacheSize()
                }
            } label: {
                offlineRouteCacheRow
            }
            .buttonStyle(.plain)
            .disabled(isPreparing)

            tileDownloadSection
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var offlineRouteCacheRow: some View {
        HStack(spacing: 8) {
            if isPreparing {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: isCachedOffline ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 12))
                    .foregroundColor(isCachedOffline ? BCColors.brandGreen : BCColors.brandBlue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(isCachedOffline ? "Route Saved Offline" : "Save Route Offline")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                Text(isCachedOffline ? "Route data, preview, and weather cached · \(offlineStorageSize)" : "Cache route data, preview, and weather")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if !isPreparing {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(BCSpacing.sm)
        .background(BCColors.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var tileDownloadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if tileSources.count > 1 {
                Picker("Tile Source", selection: Binding(
                    get: { selectedTileSource?.id ?? "" },
                    set: { id in selectedTileSource = tileSources.first { $0.id == id } }
                )) {
                    ForEach(tileSources) { source in
                        Text(source.name).tag(source.id)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 12))
            }

            if let tilePackInfo {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(BCColors.brandGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Offline Tiles Installed")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        Text("\(tilePackInfo.source.name) · \(tilePackInfo.formattedSize) · \(tilePackInfo.tileCount) tiles")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("Delete") {
                        deleteTilePack()
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.red)
                }
                .padding(BCSpacing.sm)
                .background(BCColors.cardBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if isDownloadingTiles {
                tileProgressRow
            } else {
                Button {
                    startTileDownload()
                } label: {
                    toolRow(
                        icon: tileDownloadIcon,
                        iconColor: tileDownloadColor,
                        title: "Download Tiles for Offline",
                        subtitle: tileDownloadSubtitle,
                        trailing: tileSources.isEmpty || !networkStatus.isOnline ? nil : "arrow.down.circle"
                    )
                }
                .buttonStyle(.plain)
                .disabled(tileSources.isEmpty || !networkStatus.isOnline)
            }

            if let selectedTileSource {
                Text("\(selectedTileSource.attribution) · \(selectedTileSource.licenseNotes)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            if let tileDownloadError {
                Text(tileDownloadError)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.red)
            }
        }
    }

    private var tileProgressRow: some View {
        HStack(spacing: 8) {
            ProgressView(value: tileDownloadProgress?.fractionCompleted ?? 0)
                .frame(width: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text("Downloading Offline Tiles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                Text(tileProgressText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Cancel") {
                tileDownloadTask?.cancel()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.red)
        }
        .padding(BCSpacing.sm)
        .background(BCColors.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var tileProgressText: String {
        guard let tileDownloadProgress else { return "Preparing..." }
        return "\(tileDownloadProgress.completedTiles)/\(tileDownloadProgress.totalTiles) tiles · \(tileDownloadProgress.formattedBytes)"
    }

    private var tileDownloadIcon: String {
        if tileSources.isEmpty { return "lock.slash" }
        return networkStatus.isOnline ? "map" : "wifi.slash"
    }

    private var tileDownloadColor: Color {
        if tileSources.isEmpty || !networkStatus.isOnline { return .secondary }
        return BCColors.brandBlue
    }

    private var tileDownloadSubtitle: String {
        if tileSources.isEmpty {
            return "No approved tile source configured"
        }
        if !networkStatus.isOnline {
            return "Connect to the internet to download map tiles"
        }
        let sourceName = selectedTileSource?.name ?? "approved source"
        return "Opt-in local map pack from \(sourceName)"
    }

    private func toolRow(icon: String, iconColor: Color, title: String, subtitle: String, trailing: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if let trailing {
                Image(systemName: trailing)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(BCSpacing.sm)
        .background(BCColors.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @MainActor
    private func refreshOfflineState() async {
        let offlineIndex = await OfflineRouteStorage.shared.loadIndex()
        cachedRouteEntry = offlineIndex.first { $0.routeId == route.id }
        isCachedOffline = cachedRouteEntry != nil
        offlineStorageSize = await OfflineRouteStorage.shared.formattedCacheSize()
        tileSources = await OfflineTilePackManager.shared.approvedSources()
        tilePackInfo = await OfflineTilePackManager.shared.installedPack(forRouteId: route.id)

        if let tilePackInfo {
            selectedTileSource = tileSources.first { $0.id == tilePackInfo.sourceId } ?? tilePackInfo.source
        } else if selectedTileSource == nil {
            selectedTileSource = tileSources.first
        }
    }

    private func startTileDownload() {
        guard let selectedTileSource else { return }
        tileDownloadTask?.cancel()
        isDownloadingTiles = true
        tileDownloadError = nil
        tileDownloadProgress = OfflineTileDownloadProgress(completedTiles: 0, totalTiles: 1, bytesDownloaded: 0)

        tileDownloadTask = Task {
            do {
                let info = try await OfflineTilePackManager.shared.downloadPack(
                    for: route,
                    source: selectedTileSource
                ) { progress in
                    await MainActor.run {
                        tileDownloadProgress = progress
                    }
                }
                await MainActor.run {
                    tilePackInfo = info
                    isDownloadingTiles = false
                    tileDownloadProgress = nil
                    tileDownloadTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    isDownloadingTiles = false
                    tileDownloadProgress = nil
                    tileDownloadTask = nil
                    tileDownloadError = "Tile download canceled."
                }
            } catch {
                await MainActor.run {
                    isDownloadingTiles = false
                    tileDownloadProgress = nil
                    tileDownloadTask = nil
                    tileDownloadError = error.localizedDescription
                }
            }
        }
    }

    private func deleteTilePack() {
        guard let tilePackInfo else { return }
        Task {
            await OfflineTilePackManager.shared.deletePack(
                routeId: route.id,
                sourceId: tilePackInfo.sourceId
            )
            await MainActor.run {
                self.tilePackInfo = nil
                self.tileDownloadError = nil
            }
        }
    }

    // MARK: - gpx.studio Link
    @Environment(\.openURL) private var openURL

    private var gpxStudioLink: some View {
        Button {
            let gpxFileURL = route.gpxURL ?? ""
            if let url = URL(string: "https://gpx.studio?state=%7B%22urls%22%3A%5B%22\(gpxFileURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? gpxFileURL)%22%5D%7D") {
                openURL(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "map.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(BCColors.brandBlue)
                Text("Open in gpx.studio")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(BCColors.brandBlue)
                Spacer()
                Text("Interactive map, elevation, slope analysis")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundColor(BCColors.tertiaryText)
            }
            .padding(BCSpacing.md)
            .background(BCColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var forkRouteButton: some View {
        Button {
            let lat = route.startCoordinate.latitude
            let lon = route.startCoordinate.longitude
            if let url = URL(string: "https://gpx.studio/app#12/\(lat)/\(lon)") {
                openURL(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 16))
                    .foregroundColor(BCColors.brandGreen)
                Text("Fork & Build")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(BCColors.brandGreen)
                Spacer()
                Text("Edit this route or build a variant")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundColor(BCColors.tertiaryText)
            }
            .padding(BCSpacing.md)
            .background(BCColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Trail Intelligence

    private var trailIntelligenceSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            // Closures banner
            if !trailClosures.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TRAIL CLOSURE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.red)
                        ForEach(trailClosures) { closure in
                            Text("\(closure.trailName): \(closure.status)")
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                        }
                    }
                    Spacer()
                    Text("USFS")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(BCSpacing.sm)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Crowdsourced condition
            if let condition = RouteConditionReporter.shared.latestCondition(for: route.id) {
                HStack(spacing: 8) {
                    Image(systemName: condition.icon)
                        .foregroundColor(condition.badgeColor == "green" ? .green : condition.badgeColor == "red" ? .red : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TRAIL CONDITION")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.secondary)
                        Text(condition.displayLabel)
                            .font(.system(size: 13, weight: .medium))
                        if let date = condition.lastReportDate {
                            Text("\(condition.reportCount) reports · last \(date, style: .relative) ago")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(BCSpacing.sm)
                .background(BCColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Strava Segments

    private var stravaSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            HStack {
                Text("STRAVA SEGMENTS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)
                Spacer()
                if StravaService.shared.isAuthenticated {
                    Text(StravaService.shared.athleteName ?? "Connected")
                        .font(.system(size: 9))
                        .foregroundColor(BCColors.brandGreen)
                }
            }

            if stravaSegments.isEmpty {
                Text("Connect Strava to see nearby segments")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(BCSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BCColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(stravaSegments.prefix(5)) { segment in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(segment.name)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                Text(segment.formattedDistance)
                                Text(segment.formattedGrade)
                                if !segment.climbCategoryLabel.isEmpty {
                                    Text(segment.climbCategoryLabel)
                                        .foregroundColor(.orange)
                                }
                            }
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(BCSpacing.sm)
                    .background(BCColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Description
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ABOUT THIS ROUTE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            Text(route.description)
                .font(.system(size: 14, weight: .regular))
                .lineSpacing(4)
                .foregroundColor(.primary)
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private enum RouteDetailMode: String, CaseIterable, Identifiable {
    case overview
    case prep
    case ride
    case history

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: "Overview"
        case .prep: "Prep"
        case .ride: "Ride"
        case .history: "History"
        }
    }
}

private struct RouteReadinessRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let isReady: Bool
    let icon: String
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(BCColors.brandBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Share Card Sheet
struct ShareCardSheet: View {
    let route: Route
    @State private var cardImage: UIImage?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: BCSpacing.lg) {
                RouteShareCardView(route: route)
                    .padding(BCSpacing.md)

                if let image = cardImage {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview(route.name, image: Image(uiImage: image))) {
                        Label("Share Image", systemImage: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(BCColors.brandBlue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                cardImage = RouteShareCardView(route: route).renderImage()
            }
        }
    }

}

#Preview {
    NavigationStack {
        RouteDetailView(route: .preview)
    }
}
