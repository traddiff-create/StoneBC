//
//  RoutesView.swift
//  StoneBC
//
//  Route browser with shared list/map filters
//

import SwiftUI
import MapKit

struct RoutesView: View {
    @Environment(AppState.self) var appState
    @State private var selectedDifficulty: String?
    @State private var selectedCategory: String?
    @State private var sortOption: RouteSortOption = .distance
    @State private var browseMode: RouteBrowseMode = .list
    @State private var selectedMapRoute: Route?
    @State private var routeMapPosition: MapCameraPosition = .automatic
    @State private var showImport = false

    enum RouteSortOption: String, CaseIterable {
        case distance = "Distance"
        case location = "Nearest"
        case elevation = "Elevation"
        case difficulty = "Difficulty"
        case name = "A-Z"
    }

    enum RouteBrowseMode: String, CaseIterable, Identifiable {
        case list = "List"
        case map = "Map"

        var id: String { rawValue }
    }

    private var routes: [Route] { appState.allRoutes }

    private var filteredRoutes: [Route] {
        let filtered = routes.filter { route in
            if let diff = selectedDifficulty, route.difficulty != diff {
                return false
            }
            if let cat = selectedCategory, route.category != cat {
                return false
            }
            return true
        }

        switch sortOption {
        case .distance:
            return filtered.sorted { $0.distanceMiles < $1.distanceMiles }
        case .location:
            return filtered
        case .elevation:
            return filtered.sorted { $0.elevationGainFeet > $1.elevationGainFeet }
        case .difficulty:
            let order = ["easy": 0, "moderate": 1, "hard": 2, "expert": 3]
            return filtered.sorted { (order[$0.difficulty] ?? 0) < (order[$1.difficulty] ?? 0) }
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private var availableDifficulties: [String] {
        Array(Set(routes.map(\.difficulty))).sorted { lhs, rhs in
            let lhsIndex = Route.allDifficulties.firstIndex(of: lhs) ?? Int.max
            let rhsIndex = Route.allDifficulties.firstIndex(of: rhs) ?? Int.max
            return lhsIndex < rhsIndex
        }
    }

    private var availableCategories: [String] {
        Array(Set(routes.map(\.category))).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            routeFilters
            sortAndModeBar

            if filteredRoutes.isEmpty {
                emptyState
            } else {
                switch browseMode {
                case .list:
                    routeList
                case .map:
                    routeMapBrowser
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("ROUTES")
                        .font(.bcSectionTitle)
                        .tracking(2)
                    Text("\(filteredRoutes.count) routes")
                        .font(.bcMicro)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Routes. \(filteredRoutes.count) routes.")
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    NavigationLink(destination: RouteExplorerView()) {
                        Image(systemName: "map")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .accessibilityLabel("Route Explorer - view all routes on topo map")

                    Button {
                        showImport = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .accessibilityLabel("Import route or ride files")
                }
            }
        }
        .sheet(isPresented: $showImport) {
            GPXImportView()
        }
        .onChange(of: filteredRoutes.map(\.id)) { _, routeIds in
            if let selectedMapRoute, !routeIds.contains(selectedMapRoute.id) {
                self.selectedMapRoute = filteredRoutes.first
            }
        }
    }

    private var routeFilters: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BCSpacing.xs) {
                    FilterChip(title: "All", count: routes.count, isSelected: selectedDifficulty == nil) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedDifficulty = nil
                        }
                    }
                    ForEach(availableDifficulties, id: \.self) { diff in
                        FilterChip(
                            title: diff.capitalized,
                            count: routes.filter { $0.difficulty == diff }.count,
                            isSelected: selectedDifficulty == diff
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedDifficulty = selectedDifficulty == diff ? nil : diff
                            }
                        }
                    }
                }
                .padding(.horizontal, BCSpacing.md)
                .padding(.vertical, 10)
            }
            .background(BCColors.background)
            .accessibilityIdentifier("routesDifficultyFilter")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BCSpacing.xs) {
                    FilterChip(title: "All", isSelected: selectedCategory == nil) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = nil
                        }
                    }
                    ForEach(availableCategories, id: \.self) { cat in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        } label: {
                            CategoryBadge(category: cat)
                                .opacity(selectedCategory == cat ? 1.0 : 0.55)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Category \(cat)")
                        .accessibilityAddTraits(selectedCategory == cat ? .isSelected : [])
                    }
                }
                .padding(.horizontal, BCSpacing.md)
                .padding(.vertical, 8)
            }
            .background(BCColors.instrumentInset)
            .accessibilityIdentifier("routesCategoryFilter")
        }
    }

    private var sortAndModeBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                ForEach(RouteSortOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation(.spring(response: 0.3)) { sortOption = option }
                    } label: {
                        Text(option.rawValue)
                            .font(.system(size: 10, weight: sortOption == option ? .bold : .semibold, design: .monospaced))
                            .foregroundColor(sortOption == option ? .white : BCColors.cockpitMutedText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(sortOption == option ? BCColors.brandBlue : BCColors.instrumentPanel)
                            .overlay {
                                Rectangle()
                                    .stroke(sortOption == option ? Color.white.opacity(0.2) : BCColors.hairline, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("\(filteredRoutes.count) routes")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Picker("Browse mode", selection: $browseMode) {
                ForEach(RouteBrowseMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Route browse mode")
        }
        .padding(.horizontal, BCSpacing.md)
        .padding(.vertical, 8)
        .background(BCColors.background)
    }

    private var routeList: some View {
        ScrollView {
            LazyVStack(spacing: BCSpacing.sm) {
                let imported = filteredRoutes.filter(\.isImported)
                if !imported.isEmpty {
                    sectionHeader("MY ROUTES")

                    ForEach(imported) { route in
                        NavigationLink(destination: RouteDetailView(route: route)) {
                            RouteCard(route: route)
                                .overlay(alignment: .topTrailing) {
                                    RIDRBadge(text: "Imported", color: BCColors.brandGreen)
                                        .padding(8)
                                }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                appState.removeImportedRoute(id: route.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    sectionHeader("BLACK HILLS ROUTES")
                        .padding(.top, BCSpacing.sm)
                }

                let bundled = filteredRoutes.filter { !$0.isImported }
                ForEach(Array(bundled.enumerated()), id: \.element.id) { index, route in
                    NavigationLink(destination: RouteDetailView(route: route)) {
                        RouteCard(route: route)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, BCSpacing.md)
            .padding(.top, BCSpacing.sm)
            .accessibilityIdentifier("routesList")
        }
    }

    private var routeMapBrowser: some View {
        ZStack(alignment: .bottom) {
            Map(position: $routeMapPosition) {
                ForEach(filteredRoutes) { route in
                    let isSelected = selectedMapRoute?.id == route.id
                    MapPolyline(coordinates: route.clTrackpoints)
                        .stroke(BCColors.difficultyColor(route.difficulty), lineWidth: isSelected ? 5 : 2.5)

                    if let first = route.clTrackpoints.first {
                        Annotation(route.name, coordinate: first) {
                            RouteMapPin(route: route, isSelected: isSelected) {
                                withAnimation(.spring(response: 0.25)) {
                                    selectedMapRoute = selectedMapRoute?.id == route.id ? nil : route
                                }
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .accessibilityIdentifier("routesMap")

            if let selectedMapRoute {
                NavigationLink(destination: RouteDetailView(route: selectedMapRoute)) {
                    RouteMapSelectionCard(route: selectedMapRoute)
                }
                .buttonStyle(.plain)
                .padding(BCSpacing.md)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: BCSpacing.md) {
            Spacer().frame(height: 80)
            Image(systemName: "bicycle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No routes found")
                .font(.bcPrimaryText)
            Text("TRY A DIFFERENT FILTER")
                .font(.bcLabel)
                .tracking(2)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No routes found. Try a different filter.")
        .accessibilityIdentifier("routesEmptyState")
    }

    private func sectionHeader(_ title: String) -> some View {
        BCSectionHeader(title, icon: title == "MY ROUTES" ? "tray.full" : "map")
        .padding(.top, BCSpacing.xs)
    }
}

// MARK: - Route Card
struct RouteCard: View {
    let route: Route

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(route.region.uppercased())
                        .font(.bcInstrumentLabel)
                        .tracking(1)
                        .foregroundColor(BCColors.cockpitMutedText)

                    Text(route.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(BCColors.primaryText)
                        .lineLimit(2)
                }

                Spacer()

                DifficultyBadge(difficulty: route.difficulty)
            }

            Text(route.description)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(BCColors.secondaryText)
                .lineLimit(2)

            BCHairline()

            HStack(spacing: 12) {
                routeStat(icon: "arrow.left.arrow.right", value: route.formattedDistance, label: "Distance")
                routeStat(icon: "arrow.up.right", value: route.formattedElevation, label: "Gain")
                if let condition = RouteConditionReporter.shared.latestCondition(for: route.id) {
                    TrailConditionBadge(condition: condition)
                }

                Spacer()

                CategoryBadge(category: route.category)
            }
        }
        .bcInstrumentCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(route.name). \(route.difficulty) \(route.category). \(route.formattedDistance), \(route.formattedElevation) gain.")
        .accessibilityHint("Double tap to view route details")
    }

    private func routeStat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(BCColors.cockpitMutedText)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.bcCaption)
                    .foregroundColor(BCColors.primaryText)
                    .lineLimit(1)
                Text(label.uppercased())
                    .font(.bcInstrumentLabel)
                    .tracking(0.6)
                    .foregroundColor(BCColors.cockpitMutedText)
            }
        }
    }
}

private struct RouteMapSelectionCard: View {
    let route: Route

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BCColors.primaryText)
                    .lineLimit(1)
                Text("\(route.formattedDistance) · \(route.formattedElevation) · \(route.region)")
                    .font(.bcCaption)
                    .foregroundColor(BCColors.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            DifficultyBadge(difficulty: route.difficulty)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .bcInstrumentCard()
    }
}

#Preview {
    NavigationStack {
        RoutesView()
    }
    .environment(AppState())
}
