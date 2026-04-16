//
//  RouteExplorerView.swift
//  StoneBC
//
//  Top-down topo/satellite view of ALL routes for finding connections
//  between rides. Shows start/end points and highlights nearby endpoints.
//

import SwiftUI
import MapKit
import CoreLocation

struct RouteExplorerView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedRoute: Route?
    @State private var mapStyle: ExplorerMapStyle = .hybrid
    @State private var showConnections = true
    @State private var showLabels = true
    @State private var searchText = ""
    @State private var searchResults: [RouteSearchResult] = []
    @State private var showSearch = false

    private var routes: [Route] { appState.allRoutes }

    // Pairs of route endpoints within 2 miles of each other
    private var nearbyConnections: [(RouteEndpoint, RouteEndpoint)] {
        guard showConnections else { return [] }
        let endpoints = routes.flatMap { route -> [RouteEndpoint] in
            var pts: [RouteEndpoint] = []
            if let first = route.clTrackpoints.first {
                pts.append(RouteEndpoint(routeId: route.id, routeName: route.name, coordinate: first, isStart: true))
            }
            if let last = route.clTrackpoints.last, route.clTrackpoints.count > 1 {
                pts.append(RouteEndpoint(routeId: route.id, routeName: route.name, coordinate: last, isStart: false))
            }
            return pts
        }

        var pairs: [(RouteEndpoint, RouteEndpoint)] = []
        for i in 0..<endpoints.count {
            for j in (i + 1)..<endpoints.count {
                guard endpoints[i].routeId != endpoints[j].routeId else { continue }
                let d = distance(endpoints[i].coordinate, endpoints[j].coordinate)
                if d < 3218 { // 2 miles in meters
                    pairs.append((endpoints[i], endpoints[j]))
                }
            }
        }
        return pairs
    }

    // Distinct colors per route
    private let routePalette: [Color] = [
        .blue, .red, .orange, .purple, .cyan, .pink,
        .mint, .indigo, .brown, .teal, .yellow, .green,
        Color(red: 0.8, green: 0.2, blue: 0.5),
        Color(red: 0.2, green: 0.6, blue: 0.8),
        Color(red: 0.9, green: 0.5, blue: 0.1),
        Color(red: 0.4, green: 0.2, blue: 0.8),
        Color(red: 0.1, green: 0.8, blue: 0.5),
        Color(red: 0.7, green: 0.1, blue: 0.3),
    ]

    private func colorForRoute(_ index: Int) -> Color {
        routePalette[index % routePalette.count]
    }

    var body: some View {
        ZStack {
            Map(position: $position) {
                // All route polylines with distinct colors
                ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                    let color = colorForRoute(index)
                    let isSelected = selectedRoute?.id == route.id
                    let lineWidth: CGFloat = isSelected ? 5 : 3

                    MapPolyline(coordinates: route.clTrackpoints)
                        .stroke(color.opacity(isSelected ? 1.0 : 0.8), lineWidth: lineWidth)

                    // Start pin (green dot)
                    if let first = route.clTrackpoints.first {
                        Annotation("", coordinate: first, anchor: .center) {
                            EndpointDot(color: .green, size: isSelected ? 14 : 10) {
                                selectedRoute = selectedRoute?.id == route.id ? nil : route
                            }
                        }
                    }

                    // End pin (red dot)
                    if let last = route.clTrackpoints.last, route.clTrackpoints.count > 1 {
                        Annotation("", coordinate: last, anchor: .center) {
                            EndpointDot(color: .red, size: isSelected ? 14 : 10) {
                                selectedRoute = selectedRoute?.id == route.id ? nil : route
                            }
                        }
                    }

                    // Route name label at midpoint
                    if showLabels, route.clTrackpoints.count > 2 {
                        let mid = route.clTrackpoints[route.clTrackpoints.count / 2]
                        Annotation("", coordinate: mid, anchor: .bottom) {
                            Text(route.name)
                                .font(.system(size: isSelected ? 11 : 8, weight: isSelected ? .bold : .medium))
                                .foregroundColor(color)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .opacity(isSelected ? 1 : 0.7)
                        }
                    }
                }

                // Connection lines (dashed) between nearby endpoints
                ForEach(Array(nearbyConnections.enumerated()), id: \.offset) { _, pair in
                    MapPolyline(coordinates: [pair.0.coordinate, pair.1.coordinate])
                        .stroke(.white, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }
            }
            .mapStyle(mapStyle.mapKitStyle)

            // Controls overlay
            VStack {
                // Top toolbar
                HStack(spacing: 12) {
                    // Map style picker
                    Menu {
                        ForEach(ExplorerMapStyle.allCases, id: \.self) { style in
                            Button {
                                withAnimation { mapStyle = style }
                            } label: {
                                Label(style.label, systemImage: style.icon)
                            }
                        }
                    } label: {
                        Image(systemName: mapStyle.icon)
                            .font(.system(size: 14, weight: .medium))
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    // Toggle connections
                    Button {
                        withAnimation { showConnections.toggle() }
                    } label: {
                        Image(systemName: showConnections ? "link" : "link.badge.plus")
                            .font(.system(size: 14, weight: .medium))
                            .padding(10)
                            .background(showConnections ? BCColors.brandGreen.opacity(0.8) : Color.clear)
                            .background(.ultraThinMaterial)
                            .foregroundColor(showConnections ? .white : .primary)
                            .clipShape(Circle())
                    }

                    // Toggle labels
                    Button {
                        withAnimation { showLabels.toggle() }
                    } label: {
                        Image(systemName: showLabels ? "tag.fill" : "tag")
                            .font(.system(size: 14, weight: .medium))
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    // Search
                    Button {
                        withAnimation { showSearch.toggle() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .padding(10)
                            .background(showSearch ? BCColors.brandBlue.opacity(0.8) : Color.clear)
                            .background(.ultraThinMaterial)
                            .foregroundColor(showSearch ? .white : .primary)
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Reset view
                    Button {
                        withAnimation { position = .automatic }
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .medium))
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, BCSpacing.md)
                .padding(.top, BCSpacing.sm)

                // Search overlay
                if showSearch {
                    VStack(spacing: 6) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            TextField("Search routes...", text: $searchText)
                                .font(.system(size: 13))
                                .textFieldStyle(.plain)
                                .onChange(of: searchText) {
                                    Task {
                                        if searchText.count >= 2 {
                                            searchResults = await RouteIndexService.shared.search(query: searchText)
                                        } else {
                                            searchResults = []
                                        }
                                    }
                                }
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                    searchResults = []
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        if !searchResults.isEmpty {
                            ScrollView {
                                VStack(spacing: 2) {
                                    ForEach(searchResults) { result in
                                        Button {
                                            // Find and select the matching route
                                            if let route = routes.first(where: { $0.id == result.routeId }) {
                                                selectedRoute = route
                                                showSearch = false
                                                searchText = ""
                                                searchResults = []
                                                // Zoom to route
                                                if let first = route.clTrackpoints.first {
                                                    withAnimation {
                                                        position = .camera(MapCamera(centerCoordinate: first, distance: 50000))
                                                    }
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(result.name)
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(.primary)
                                                    Text("\(result.category) · \(result.formattedDistance) · \(result.difficulty)")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                            }
                                            .padding(8)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, BCSpacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Connection count badge
                if showConnections && !nearbyConnections.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                        Text("\(nearbyConnections.count) potential connections (<2 mi apart)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 4)
                }

                // Selected route card
                if let selected = selectedRoute {
                    selectedCard(selected)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, BCSpacing.md)
                        .padding(.bottom, BCSpacing.sm)
                }

                // Legend
                legendBar
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("ROUTE EXPLORER")
                        .font(.bcSectionTitle)
                        .tracking(2)
                    Text("\(routes.count) routes")
                        .font(.bcMicro)
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            // Build search index on first load
            await RouteIndexService.shared.buildIndex(from: routes)
        }
    }

    // MARK: - Selected Route Card

    private func selectedCard(_ route: Route) -> some View {
        let idx = routes.firstIndex(where: { $0.id == route.id }) ?? 0

        return HStack {
            Circle()
                .fill(colorForRoute(idx))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(route.name)
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 8) {
                    Text(route.formattedDistance)
                        .font(.bcCaption)
                    Text(route.formattedElevation)
                        .font(.bcCaption)
                    DifficultyBadge(difficulty: route.difficulty)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            // Nearby routes count
            let nearby = nearbyConnections.filter { $0.0.routeId == route.id || $0.1.routeId == route.id }
            if !nearby.isEmpty {
                VStack(spacing: 2) {
                    Text("\(nearby.count)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(BCColors.brandGreen)
                    Text("LINKS")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(1)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(BCSpacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Legend

    private var legendBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("Start")
                    .font(.system(size: 9, weight: .medium))
            }
            HStack(spacing: 4) {
                Circle().fill(.red).frame(width: 8, height: 8)
                Text("End")
                    .font(.system(size: 9, weight: .medium))
            }
            if showConnections {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(.white)
                        .frame(width: 16, height: 2)
                    Text("Connection")
                        .font(.system(size: 9, weight: .medium))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.bottom, BCSpacing.sm)
    }

    // MARK: - Helpers

    private func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}

// MARK: - Supporting Types

struct RouteEndpoint {
    let routeId: String
    let routeName: String
    let coordinate: CLLocationCoordinate2D
    let isStart: Bool
}

struct EndpointDot: View {
    let color: Color
    let size: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(radius: 2)
        }
    }
}

enum ExplorerMapStyle: CaseIterable {
    case hybrid
    case imagery
    case standard

    var label: String {
        switch self {
        case .hybrid: return "Hybrid"
        case .imagery: return "Satellite"
        case .standard: return "Standard"
        }
    }

    var icon: String {
        switch self {
        case .hybrid: return "map"
        case .imagery: return "globe.americas"
        case .standard: return "map.fill"
        }
    }

    var mapKitStyle: MapStyle {
        switch self {
        case .hybrid: return .hybrid(elevation: .realistic)
        case .imagery: return .imagery(elevation: .realistic)
        case .standard: return .standard(elevation: .realistic)
        }
    }
}

#Preview {
    NavigationStack {
        RouteExplorerView()
    }
    .environment(AppState())
}
