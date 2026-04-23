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
    @State private var showShareCard = false
    @State private var isPreparing = false
    @State private var isCachedOffline = false
    @State private var stravaSegments: [StravaSegment] = []
    @State private var trailClosures: [TrailClosure] = []
    @State private var isFavorite = false
    @State private var isTimeTrial = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BCSpacing.lg) {
                // Header
                headerSection

                // Disclaimer
                DisclaimerBannerView()

                // Stats Grid
                statsGrid

                // Elevation Profile
                elevationProfile

                // Weather
                RouteWeatherSection(route: route)

                // Trail Conditions + Closures
                trailIntelligenceSection

                // Strava Segments
                if StravaService.shared.isConfigured {
                    stravaSection
                }

                // Map Preview
                mapPreview

                // gpx.studio interactive map
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

                // Offline & Coverage tools
                offlineToolsSection

                // Description
                descriptionSection
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
                        if let gpxFileURL {
                            ShareLink(item: gpxFileURL) {
                                Label("Export GPX File", systemImage: "doc")
                            }
                        }
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

                    NavigationLink(destination: RouteNavigationView(route: route)) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                    }
                    .accessibilityLabel("Navigate route")
                }
            }
        }
        .task {
            let gpx = GPXService.exportGPX(route)
            gpxFileURL = GPXService.writeToTempFile(gpx, name: route.name)
            isCachedOffline = await OfflineRouteStorage.shared.isCached(routeId: route.id)
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

    // MARK: - Offline & Coverage Tools
    private var offlineToolsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RIDE TOOLS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                NavigationLink(destination: CellCoverageView(route: route)) {
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cell Coverage")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                            Text("See dead zones on route")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(BCSpacing.sm)
                    .background(BCColors.cardBackground.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            // Prepare for Offline button
            Button {
                isPreparing = true
                Task {
                    // Cache route data + snapshot + tile warming in parallel
                    await OfflineRouteStorage.shared.cacheRoute(route)
                    await OfflineMapService.shared.warmTiles(for: route)
                    _ = await OfflineMapService.shared.generateSnapshot(for: route)

                    // Cache current weather if available
                    if let weather = await WeatherService.shared.weather(for: route.clStartCoordinate) {
                        await OfflineRouteStorage.shared.cacheWeather(weather, routeId: route.id)
                    }

                    isPreparing = false
                    isCachedOffline = true
                }
            } label: {
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
                        Text(isCachedOffline ? "Saved for Offline" : "Prepare for Offline")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        Text(isCachedOffline ? "Route, map, and weather cached" : "Cache route data and map tiles")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
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
            .buttonStyle(.plain)
            .disabled(isPreparing)
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
