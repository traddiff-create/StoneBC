//
//  RouteMapView.swift
//  StoneBC
//
//  MapKit view with MapPolyline for routes, start/end pins, filter panel
//

import SwiftUI
import MapKit

struct RouteMapView: View {
    var focusedRoute: Route?

    @Environment(AppState.self) var appState
    private var routes: [Route] { appState.allRoutes }
    @State private var selectedRoute: Route?
    @State private var position: MapCameraPosition = .automatic
    @State private var offlineRegion: MKCoordinateRegion
    @State private var tilePackInfo: OfflineTilePackInfo?
    @State private var offlineMapFollowsUser = false
    @State private var filterCategory: String?
    @State private var filterDifficulty: String?
    @State private var showFilters = false

    init(focusedRoute: Route? = nil) {
        self.focusedRoute = focusedRoute
        self._offlineRegion = State(initialValue: Self.initialRegion(for: focusedRoute))
    }

    private var filteredRoutes: [Route] {
        if let focused = focusedRoute {
            return [focused]
        }
        return routes.filter { route in
            if let cat = filterCategory, route.category != cat {
                return false
            }
            if let diff = filterDifficulty, route.difficulty != diff {
                return false
            }
            return true
        }
    }

    private var categories: [String] {
        Array(Set(routes.map { $0.category })).sorted()
    }

    private var difficulties: [String] {
        Array(Set(routes.map { $0.difficulty }))
            .sorted { Route.allDifficulties.firstIndex(of: $0) ?? 0 < Route.allDifficulties.firstIndex(of: $1) ?? 0 }
    }

    private func routeColor(_ route: Route) -> Color {
        if selectedRoute?.id == route.id {
            return BCColors.brandBlue
        }
        return BCColors.difficultyColor(route.difficulty)
    }

    private func routeUIColor(_ route: Route) -> UIColor {
        UIColor(BCColors.difficultyColor(route.difficulty))
    }

    var body: some View {
        ZStack {
            if let focusedRoute {
                OfflineCapableMapView(
                    region: $offlineRegion,
                    isFollowingUser: $offlineMapFollowsUser,
                    routePolyline: focusedRoute.clTrackpoints,
                    routeColor: routeUIColor(focusedRoute),
                    tilePack: tilePackInfo
                )
                .task(id: focusedRoute.id) {
                    tilePackInfo = await OfflineTilePackManager.shared.installedPack(forRouteId: focusedRoute.id)
                }
            } else {
                // Map
                Map(position: $position) {
                    ForEach(filteredRoutes) { route in
                        MapPolyline(coordinates: route.clTrackpoints)
                            .stroke(routeColor(route), lineWidth: selectedRoute?.id == route.id ? 4 : 2.5)

                        // Start pin
                        if let first = route.clTrackpoints.first {
                            Annotation(route.name, coordinate: first) {
                                RouteMapPin(route: route, isSelected: selectedRoute?.id == route.id) {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedRoute = selectedRoute?.id == route.id ? nil : route
                                    }
                                }
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
            }

            // Controls overlay
            VStack {
                Spacer()

                // Selected route info card
                if let selected = selectedRoute {
                    selectedRouteCard(selected)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, BCSpacing.md)
                        .padding(.bottom, BCSpacing.sm)
                }

                // Bottom panel
                VStack(spacing: 0) {
                    // Toggle button
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showFilters.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: showFilters ? "chevron.down" : "chevron.up")
                            Text("\(filteredRoutes.count) ROUTES")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1)
                            if filterCategory != nil || filterDifficulty != nil {
                                Text("(filtered)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                    }
                    .accessibilityLabel(showFilters ? "Hide filters, \(filteredRoutes.count) routes" : "Show filters, \(filteredRoutes.count) routes")
                    .accessibilityIdentifier("mapFilterToggle")

                    if showFilters {
                        mapFilterPanel
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(focusedRoute?.name.uppercased() ?? "ROUTE MAP")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
            }
        }
    }

    private static func initialRegion(for route: Route?) -> MKCoordinateRegion {
        guard let route else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 44.0805, longitude: -103.2310),
                span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
            )
        }
        return boundingRegion(for: route.clTrackpoints, padding: 1.3)
    }

    private static func boundingRegion(for coords: [CLLocationCoordinate2D], padding: Double) -> MKCoordinateRegion {
        guard let first = coords.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 44.0805, longitude: -103.2310),
                span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
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

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * padding, 0.01),
            longitudeDelta: max((maxLon - minLon) * padding, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Selected Route Card
    private func selectedRouteCard(_ route: Route) -> some View {
        NavigationLink(destination: RouteDetailView(route: route)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    HStack(spacing: 8) {
                        Text(route.formattedDistance)
                            .font(.bcCaption)
                        Text(route.formattedElevation)
                            .font(.bcCaption)
                    }
                    .foregroundColor(.secondary)
                }

                Spacer()

                DifficultyBadge(difficulty: route.difficulty)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(BCColors.tertiaryText)
            }
            .padding(BCSpacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filter Panel
    private var mapFilterPanel: some View {
        VStack(spacing: 16) {
            // Category filter
            VStack(alignment: .leading, spacing: 8) {
                Text("CATEGORY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: filterCategory == nil) {
                            filterCategory = nil
                        }
                        ForEach(categories, id: \.self) { cat in
                            FilterChip(
                                title: cat.capitalized,
                                isSelected: filterCategory == cat
                            ) {
                                filterCategory = filterCategory == cat ? nil : cat
                            }
                        }
                    }
                }
            }

            // Difficulty filter
            VStack(alignment: .leading, spacing: 8) {
                Text("DIFFICULTY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: filterDifficulty == nil) {
                            filterDifficulty = nil
                        }
                        ForEach(difficulties, id: \.self) { diff in
                            FilterChip(
                                title: diff.capitalized,
                                isSelected: filterDifficulty == diff
                            ) {
                                filterDifficulty = filterDifficulty == diff ? nil : diff
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Route Map Pin
struct RouteMapPin: View {
    let route: Route
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(BCColors.difficultyColor(route.difficulty))
                        .frame(width: isSelected ? 32 : 24, height: isSelected ? 32 : 24)

                    Image(systemName: "bicycle")
                        .font(.system(size: isSelected ? 14 : 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(radius: 2)

                Triangle()
                    .fill(BCColors.difficultyColor(route.difficulty))
                    .frame(width: 8, height: 5)
            }
        }
        .accessibilityLabel("\(route.name), \(route.difficulty) \(route.category)")
        .accessibilityHint("Double tap to select route")
        .animation(.spring(response: 0.2), value: isSelected)
    }
}

// MARK: - Triangle Shape
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    NavigationStack {
        RouteMapView()
    }
    .environment(AppState())
}
