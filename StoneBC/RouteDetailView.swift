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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BCSpacing.lg) {
                // Header
                headerSection

                // Stats Grid
                statsGrid

                // Elevation Profile
                elevationProfile

                // Map Preview
                mapPreview

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
                Task {
                    await OfflineMapService.shared.warmTiles(for: route)
                    await OfflineMapService.shared.generateSnapshot(for: route)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 12))
                        .foregroundColor(BCColors.brandBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Prepare for Offline")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Cache map tiles for this route")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(BCSpacing.sm)
                .background(BCColors.cardBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
