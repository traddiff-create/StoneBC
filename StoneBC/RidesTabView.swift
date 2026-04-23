import SwiftUI

struct RidesTabView: View {
    @State private var history = RideHistoryService.shared
    @State private var journalService = RideJournalService.shared
    @State private var timeTrialService = TimeTrialService.shared
    @State private var segment = 0
    @State private var historyFilter = 0  // 0=All, 1=This Year, 2=This Month, 3=This Week
    @State private var categoryFilter: String? = nil
    @State private var sortOrder = 0  // 0=Newest, 1=Oldest, 2=Longest, 3=Highest Climb, 4=Fastest
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BCSpacing.lg) {
                    seasonSummaryStrip
                    segmentPicker

                    switch segment {
                    case 0: historySection
                    case 1: RideStatsView()
                    case 2: journalsSection
                    default: timeTrialsSection
                    }
                }
                .padding(BCSpacing.md)
            }
            .background(BCColors.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search rides")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("RIDES")
                        .font(.bcSectionTitle)
                        .tracking(2)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if segment == 0 {
                        Menu {
                            Picker("Sort", selection: $sortOrder) {
                                Label("Newest First", systemImage: "arrow.down.circle").tag(0)
                                Label("Oldest First", systemImage: "arrow.up.circle").tag(1)
                                Label("Longest", systemImage: "arrow.right.to.line").tag(2)
                                Label("Highest Climb", systemImage: "mountain.2").tag(3)
                                Label("Fastest", systemImage: "speedometer").tag(4)
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 14))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Season Summary

    private var seasonSummaryStrip: some View {
        let summary = history.seasonSummary
        return HStack(spacing: 0) {
            summaryCell(value: summary.formattedMiles, label: "Miles")
            Divider().frame(height: 30)
            summaryCell(value: "\(summary.rideCount)", label: "Rides")
            Divider().frame(height: 30)
            summaryCell(value: summary.formattedElevation, label: "Elevation")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func summaryCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Segment Picker

    private var segmentPicker: some View {
        Picker("Segment", selection: $segment) {
            Text("History").tag(0)
            Text("Stats").tag(1)
            Text("Journals").tag(2)
            Text("Time Trials").tag(3)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - History

    private var filteredRides: [CompletedRide] {
        let now = Date()
        let calendar = Calendar.current

        var base = history.rides

        // Time filter
        switch historyFilter {
        case 1:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
            base = base.filter { $0.completedAt >= start }
        case 2:
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            base = base.filter { $0.completedAt >= start }
        case 3:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            base = base.filter { $0.completedAt >= start }
        default: break
        }

        // Category filter
        if let cat = categoryFilter {
            base = base.filter { $0.category.lowercased() == cat.lowercased() }
        }

        // Search
        if !searchText.isEmpty {
            base = base.filter { $0.routeName.localizedCaseInsensitiveContains(searchText) }
        }

        // Sort
        switch sortOrder {
        case 1: base.sort { $0.completedAt < $1.completedAt }
        case 2: base.sort { $0.distanceMiles > $1.distanceMiles }
        case 3: base.sort { $0.elevationGainFeet > $1.elevationGainFeet }
        case 4: base.sort { $0.avgSpeedMPH > $1.avgSpeedMPH }
        default: break // already newest-first from RideHistoryService
        }

        return base
    }

    private var historySection: some View {
        VStack(spacing: BCSpacing.sm) {
            timeFilterChipsRow
            categoryFilterChipsRow

            if filteredRides.isEmpty {
                emptyState(
                    icon: "bicycle",
                    title: history.rides.isEmpty ? "No rides yet" : "No rides match",
                    subtitle: history.rides.isEmpty ? "Complete a ride to see it here" : "Try adjusting your filters"
                )
            } else {
                ForEach(filteredRides) { ride in
                    NavigationLink(destination: RideDetailView(ride: ride)) {
                        rideRow(ride)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var timeFilterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([(0, "All Time"), (1, "This Year"), (2, "This Month"), (3, "This Week")], id: \.0) { tag, label in
                    FilterChip(title: label, isSelected: historyFilter == tag) {
                        historyFilter = tag
                    }
                }
            }
        }
    }

    private var categoryFilterChipsRow: some View {
        let categories = Array(Set(history.rides.map { $0.category })).sorted()
        guard !categories.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", isSelected: categoryFilter == nil) {
                        categoryFilter = nil
                    }
                    ForEach(categories, id: \.self) { cat in
                        FilterChip(title: cat.capitalized, isSelected: categoryFilter == cat) {
                            categoryFilter = (categoryFilter == cat) ? nil : cat
                        }
                    }
                }
            }
        )
    }

    private func rideRow(_ ride: CompletedRide) -> some View {
        HStack(spacing: 12) {
            if let trackpoints = ride.gpxTrackpoints, trackpoints.count >= 2 {
                RideMiniMapView(trackpoints: trackpoints)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "bicycle")
                    .font(.system(size: 22))
                    .foregroundColor(BCColors.brandBlue.opacity(0.7))
                    .frame(width: 56, height: 56)
                    .background(BCColors.brandBlue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(ride.routeName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Text(ride.formattedDate)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(ride.formattedDistance)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Text(ride.formattedTime)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            if ride.isTimeTrial {
                Image(systemName: "stopwatch")
                    .font(.system(size: 12))
                    .foregroundColor(BCColors.brandBlue)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(BCColors.tertiaryText)
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Journals

    private var journalsSection: some View {
        VStack(spacing: BCSpacing.sm) {
            if journalService.journals.isEmpty {
                emptyState(
                    icon: "book",
                    title: "No journals yet",
                    subtitle: "Write about a recent ride to get started"
                )
            } else {
                ForEach(journalService.journals) { journal in
                    NavigationLink(destination: RideJournalDetailView(journal: journal)) {
                        journalRow(journal)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func journalRow(_ journal: RideJournal) -> some View {
        HStack(spacing: 12) {
            if let mood = journal.mood {
                Text(mood.emoji)
                    .font(.system(size: 22))
            } else {
                Image(systemName: "book.pages")
                    .font(.system(size: 16))
                    .foregroundColor(BCColors.brandBlue)
                    .frame(width: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(journal.routeName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Text(journal.date, style: .date)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if journal.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(BCColors.tertiaryText)
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Time Trials

    private var timeTrialsSection: some View {
        VStack(spacing: BCSpacing.sm) {
            if timeTrialService.presets.isEmpty {
                emptyState(
                    icon: "stopwatch",
                    title: "No time trial routes",
                    subtitle: "Open a route and tap ⋯ to set it as a time trial"
                )
            } else {
                ForEach(timeTrialService.presets) { preset in
                    NavigationLink(destination: TimeTrialLeaderboardView(preset: preset)) {
                        timeTrialRow(preset)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func timeTrialRow(_ preset: TimeTrialPreset) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 16))
                .foregroundColor(BCColors.brandBlue)
                .frame(width: 32, height: 32)
                .background(BCColors.brandBlue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(preset.routeName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Text("\(preset.attempts.count) attempts")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let pb = preset.personalBestSeconds {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTime(pb))
                        .font(.system(size: 14, weight: .bold))
                    Text("Best")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(BCColors.tertiaryText)
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            Text(title)
                .font(.system(size: 15, weight: .medium))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func formatTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    RidesTabView()
}
