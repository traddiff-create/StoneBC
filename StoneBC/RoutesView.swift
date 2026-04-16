//
//  RoutesView.swift
//  StoneBC
//
//  Route list with difficulty and category filter chips
//

import SwiftUI

struct RoutesView: View {
    @Environment(AppState.self) var appState
    @State private var selectedDifficulty: String?
    @State private var selectedCategory: String?
    @State private var sortOption: RouteSortOption = .distance
    @State private var appeared = false
    @State private var showImport = false

    enum RouteSortOption: String, CaseIterable {
        case distance = "Distance"
        case location = "Nearest"
        case elevation = "Elevation"
        case difficulty = "Difficulty"
        case name = "A–Z"
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
            return filtered // already sorted by distance from RC in routes.json
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
        Array(Set(routes.map { $0.difficulty }))
            .sorted { Route.allDifficulties.firstIndex(of: $0) ?? 0 < Route.allDifficulties.firstIndex(of: $1) ?? 0 }
    }

    private var availableCategories: [String] {
        Array(Set(routes.map { $0.category })).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Difficulty filter
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

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BCSpacing.xs) {
                    ForEach(availableCategories, id: \.self) { cat in
                        CategoryBadge(category: cat)
                            .opacity(selectedCategory == cat ? 1.0 : 0.5)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCategory = selectedCategory == cat ? nil : cat
                                }
                            }
                    }
                }
                .padding(.horizontal, BCSpacing.md)
                .padding(.vertical, 8)
            }
            .background(BCColors.cardBackground)
            .accessibilityIdentifier("routesCategoryFilter")

            // Sort bar
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                ForEach(RouteSortOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation(.spring(response: 0.3)) { sortOption = option }
                    } label: {
                        Text(option.rawValue)
                            .font(.system(size: 10, weight: sortOption == option ? .bold : .medium))
                            .foregroundColor(sortOption == option ? .white : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(sortOption == option ? BCColors.brandBlue : BCColors.cardBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("\(filteredRoutes.count) routes")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, BCSpacing.md)
            .padding(.vertical, 6)
            .background(BCColors.background)

            // Route list
            ScrollView {
                if filteredRoutes.isEmpty {
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
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No routes found. Try a different filter.")
                    .accessibilityIdentifier("routesEmptyState")
                } else {
                    LazyVStack(spacing: BCSpacing.sm) {
                        // Imported routes section
                        let imported = filteredRoutes.filter { $0.isImported }
                        if !imported.isEmpty {
                            HStack {
                                Text("MY ROUTES")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(1)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.top, BCSpacing.xs)

                            ForEach(imported) { route in
                                NavigationLink(destination: RouteDetailView(route: route)) {
                                    RouteCard(route: route)
                                        .overlay(alignment: .topTrailing) {
                                            Text("IMPORTED")
                                                .font(.system(size: 7, weight: .bold))
                                                .tracking(0.5)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(BCColors.brandGreen.opacity(0.2))
                                                .foregroundColor(BCColors.brandGreen)
                                                .clipShape(Capsule())
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

                            HStack {
                                Text("BLACK HILLS ROUTES")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(1)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.top, BCSpacing.sm)
                        }

                        // Bundled routes
                        let bundled = filteredRoutes.filter { !$0.isImported }
                        ForEach(Array(bundled.enumerated()), id: \.element.id) { index, route in
                            NavigationLink(destination: RouteDetailView(route: route)) {
                                RouteCard(route: route)
                            }
                            .buttonStyle(.plain)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(Double(min(index, 15)) * 0.03),
                                value: appeared
                            )
                        }
                    }
                    .padding(.horizontal, BCSpacing.md)
                    .padding(.top, BCSpacing.sm)
                    .accessibilityIdentifier("routesList")
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
                    .accessibilityLabel("Route Explorer — view all routes on topo map")

                    Button {
                        showImport = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .accessibilityLabel("Import GPX route")
                }
            }
        }
        .sheet(isPresented: $showImport) {
            GPXImportView()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            appeared = true
        }
    }
}

// MARK: - Route Card
struct RouteCard: View {
    let route: Route

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    Text(route.region)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                }

                Spacer()

                DifficultyBadge(difficulty: route.difficulty)
            }

            // Description
            Text(route.description)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(2)

            // Stats + condition badge
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10))
                    Text(route.formattedDistance)
                        .font(.bcCaption)
                }
                .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10))
                    Text(route.formattedElevation)
                        .font(.bcCaption)
                }
                .foregroundColor(.secondary)

                // Trail condition badge (crowdsourced)
                if let condition = RouteConditionReporter.shared.latestCondition(for: route.id) {
                    TrailConditionBadge(condition: condition)
                }

                Spacer()

                CategoryBadge(category: route.category)
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(route.name). \(route.difficulty) \(route.category). \(route.formattedDistance), \(route.formattedElevation) gain.")
        .accessibilityHint("Double tap to view route details")
    }
}

#Preview {
    NavigationStack {
        RoutesView()
    }
    .environment(AppState())
}
