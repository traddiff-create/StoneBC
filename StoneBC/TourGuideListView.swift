//
//  TourGuideListView.swift
//  StoneBC
//
//  Browse available tour guides
//

import SwiftUI

struct TourGuideListView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedType: TourGuide.GuideType?
    @State private var selectedDifficulty: String?
    @State private var selectedCategory: String?

    private var filteredGuides: [TourGuide] {
        appState.guides.filter { guide in
            if let selectedType, guide.type != selectedType {
                return false
            }
            if let selectedDifficulty, guide.difficulty != selectedDifficulty {
                return false
            }
            if let selectedCategory, guide.category != selectedCategory {
                return false
            }
            return true
        }
    }

    private var availableTypes: [TourGuide.GuideType] {
        Array(Set(appState.guides.map(\.type))).sorted { $0.displayName < $1.displayName }
    }

    private var availableDifficulties: [String] {
        Array(Set(appState.guides.map(\.difficulty))).sorted { lhs, rhs in
            let lhsIndex = Route.allDifficulties.firstIndex(of: lhs) ?? Int.max
            let rhsIndex = Route.allDifficulties.firstIndex(of: rhs) ?? Int.max
            return lhsIndex < rhsIndex
        }
    }

    private var availableCategories: [String] {
        Array(Set(appState.guides.map(\.category))).sorted()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: BCSpacing.md, pinnedViews: []) {
                filterSection

                if filteredGuides.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredGuides) { guide in
                        NavigationLink(destination: TourGuideDetailView(guide: guide)) {
                            guideCard(guide)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(BCSpacing.md)
        }
        .background(BCColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("TOUR GUIDES")
                    .font(.bcSectionTitle)
                    .tracking(2)
            }
        }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            filterRow(title: "TYPE") {
                FilterChip(title: "All", count: appState.guides.count, isSelected: selectedType == nil) {
                    selectedType = nil
                }
                ForEach(availableTypes, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        count: appState.guides.filter { $0.type == type }.count,
                        isSelected: selectedType == type
                    ) {
                        selectedType = selectedType == type ? nil : type
                    }
                }
            }

            filterRow(title: "DIFFICULTY") {
                FilterChip(title: "All", isSelected: selectedDifficulty == nil) {
                    selectedDifficulty = nil
                }
                ForEach(availableDifficulties, id: \.self) { difficulty in
                    FilterChip(
                        title: difficulty.capitalized,
                        isSelected: selectedDifficulty == difficulty
                    ) {
                        selectedDifficulty = selectedDifficulty == difficulty ? nil : difficulty
                    }
                }
            }

            filterRow(title: "CATEGORY") {
                FilterChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(availableCategories, id: \.self) { category in
                    FilterChip(
                        title: category.capitalized,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
        }
    }

    private func filterRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.bcSectionTitle)
                .tracking(1)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    content()
                }
            }
        }
    }

    private func guideCard(_ guide: TourGuide) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: guide.type.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(guide.type == .event ? BCColors.brandBlue : BCColors.brandGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(guide.type.displayName.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundColor(guide.type == .event ? BCColors.brandBlue : BCColors.brandGreen)
                        Text(guide.region)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Text(guide.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(guide.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(BCColors.tertiaryText)
                    .padding(.top, 4)
            }

            HStack(spacing: 8) {
                DifficultyBadge(difficulty: guide.difficulty)
                CategoryBadge(category: guide.category)
                if let date = guide.eventDate {
                    Label(date, systemImage: "calendar")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(BCColors.brandBlue)
                        .lineLimit(1)
                }
            }

            Text(guide.description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(3)
                .lineLimit(3)

            HStack(spacing: 10) {
                statPill(icon: "calendar.badge.clock", value: "\(guide.totalDays)", label: guide.totalDays == 1 ? "day" : "days")
                statPill(icon: "arrow.left.arrow.right", value: String(format: "%.0f", guide.totalMiles), label: "mi")
                statPill(icon: "arrow.up.right", value: formatElevation(guide.totalElevation), label: "ft")
            }

            if !guide.days.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(guide.days) { day in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("DAY \(day.dayNumber)")
                                    .font(.system(size: 8, weight: .bold))
                                    .tracking(0.8)
                                    .foregroundColor(.secondary)
                                Text(day.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                Text("\(String(format: "%.0f", day.totalMiles)) mi")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 106, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(BCColors.overlayLight)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(guide.name), \(guide.type.displayName), \(guide.difficulty), \(guide.category), \(guide.totalDays) days, \(String(format: "%.0f", guide.totalMiles)) miles")
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(BCColors.brandBlue)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(BCColors.overlayLight)
        .clipShape(Capsule())
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "map")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No guides match these filters")
                .font(.system(size: 14, weight: .medium))
            Button("Clear Filters") {
                selectedType = nil
                selectedDifficulty = nil
                selectedCategory = nil
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(BCColors.brandBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BCSpacing.xl)
    }

    private func formatElevation(_ feet: Int) -> String {
        if feet >= 1000 {
            return String(format: "%.1fk", Double(feet) / 1000)
        }
        return "\(feet)"
    }
}
