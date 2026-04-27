//
//  TourGuideDetailView.swift
//  StoneBC
//
//  Native tour guide planning and ride companion
//

import SwiftUI
import MapKit

struct TourGuideDetailView: View {
    let guide: TourGuide

    @Environment(AppState.self) private var appState
    @State private var selectedDay: Int
    @State private var selectedMode: TourGuideMode = .plan
    @State private var enabledOverlays: Set<TourGuideOverlay>
    @State private var collapsedSections: Set<TourGuideSection> = []
    @State private var mapLayer: TourGuideMapLayer = .standard
    @State private var isSavingOffline = false
    @State private var isCurrentRouteSavedOffline = false
    @State private var offlineStatusText = "Not saved"

    init(guide: TourGuide) {
        self.guide = guide
        self._selectedDay = State(initialValue: guide.days.first?.dayNumber ?? 1)
        self._enabledOverlays = State(initialValue: guide.defaultEnabledOverlays)
    }

    private var currentDay: TourDay? {
        guide.days.first { $0.dayNumber == selectedDay }
    }

    private var currentRoute: Route? {
        currentDay?.resolvedRoute(in: appState.allRoutes)
    }

    private var enabledSections: Set<TourGuideSection> {
        guide.defaultEnabledSections
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: BCSpacing.lg, pinnedViews: [.sectionHeaders]) {
                headerSection

                DisclaimerBannerView()

                modePicker

                Section {
                    selectedModeContent
                } header: {
                    dayPickerHeader
                }
            }
            .padding(BCSpacing.md)
        }
        .background(BCColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(guide.name.uppercased())
                    .font(.bcSectionTitle)
                    .tracking(2)
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                }
                .accessibilityLabel("Share guide")
            }
        }
        .onAppear {
            loadPreferencesForSelectedDay()
            Task { await refreshOfflineState() }
        }
        .onChange(of: selectedDay) { _, _ in
            loadPreferencesForSelectedDay()
            Task { await refreshOfflineState() }
        }
        .onChange(of: mapLayer) { _, _ in
            saveMapLayer()
        }
    }

    @ViewBuilder
    private var selectedModeContent: some View {
        if let day = currentDay {
            switch selectedMode {
            case .plan:
                planContent(day)
            case .ride:
                rideContent(day)
            case .journal:
                journalContent(day)
            }
        } else {
            emptyDayState
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: guide.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(guide.type == .event ? BCColors.brandBlue : BCColors.brandGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(guide.type.displayName.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .tracking(1)
                            .foregroundColor(guide.type == .event ? BCColors.brandBlue : BCColors.brandGreen)
                        Text(guide.region)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Text(guide.name)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(guide.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Text(guide.description)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .lineSpacing(4)

            HStack(spacing: 8) {
                DifficultyBadge(difficulty: guide.difficulty)
                CategoryBadge(category: guide.category)
                if let gearProfile = guide.gearProfile {
                    Text(gearProfile.replacingOccurrences(of: "-", with: " ").uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(BCColors.brandAmber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(BCColors.brandAmber.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 10) {
                guideStat(icon: "calendar.badge.clock", value: "\(guide.totalDays) day\(guide.totalDays == 1 ? "" : "s")")
                guideStat(icon: "arrow.left.arrow.right", value: String(format: "%.0f mi", guide.totalMiles))
                guideStat(icon: "arrow.up.right", value: formatElevation(guide.totalElevation))
                Spacer()
            }

            if let date = guide.eventDate {
                Label(date, systemImage: "calendar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(BCColors.brandBlue)
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(guide.name), \(guide.type.displayName), \(guide.difficulty), \(guide.category), \(guide.totalDays) days, \(String(format: "%.0f", guide.totalMiles)) miles")
    }

    private var modePicker: some View {
        Picker("Guide mode", selection: $selectedMode) {
            ForEach(TourGuideMode.allCases) { mode in
                Label(mode.label, systemImage: mode.systemImage)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Guide mode")
    }

    // MARK: - Day Picker

    private var dayPickerHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(guide.days) { day in
                    dayButton(day)
                }
            }
            .padding(.horizontal, BCSpacing.md)
            .padding(.vertical, 8)
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Day picker")
    }

    private func dayButton(_ day: TourDay) -> some View {
        let isSelected = selectedDay == day.dayNumber
        return Button {
            withAnimation(.spring(response: 0.25)) {
                selectedDay = day.dayNumber
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("DAY \(day.dayNumber)")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                    if day.resolvedRoute(in: appState.allRoutes) != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                    }
                }

                Text(day.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(String(format: "%.0f mi", day.totalMiles))
                    if day.elevationGain > 0 {
                        Text(formatElevation(day.elevationGain))
                    }
                    if let time = day.startTime {
                        Text(time)
                    }
                }
                .font(.system(size: 9))
                .lineLimit(1)
            }
            .frame(width: 150, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(isSelected ? BCColors.brandBlue : BCColors.cardBackground)
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Day \(day.dayNumber), \(day.name), \(String(format: "%.0f", day.totalMiles)) miles")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Modes

    private func planContent(_ day: TourDay) -> some View {
        VStack(alignment: .leading, spacing: BCSpacing.lg) {
            if enabledSections.contains(.map) {
                mapSection(day: day, height: 280)
            }

            if enabledSections.contains(.overview) {
                dayOverview(day)
            }

            guideActions

            if enabledSections.contains(.weather), let route = currentRoute {
                RouteWeatherSection(route: route)
            }

            if enabledSections.contains(.stops) {
                collapsibleSection(.stops, title: "STOPS") {
                    stopsTimeline(day, stops: day.stops)
                }
            }

            if enabledSections.contains(.checklist), let checklist = guide.checklist, !checklist.isEmpty {
                RideChecklistView(guideId: guide.id, items: checklist)
            }

            if enabledSections.contains(.safety), hasSafetyContent {
                collapsibleSection(.safety, title: "SAFETY") {
                    safetySection
                }
            }

            if enabledSections.contains(.notes) {
                collapsibleSection(.notes, title: "TOUR NOTES") {
                    notesSection
                }
            }
        }
    }

    private func rideContent(_ day: TourDay) -> some View {
        VStack(alignment: .leading, spacing: BCSpacing.lg) {
            if enabledSections.contains(.map) {
                mapSection(day: day, height: 420)
            }

            rideOverlayPanel

            guideActions

            dayOverview(day)

            if enabledOverlays.contains(.weather), let route = currentRoute {
                RouteWeatherSection(route: route)
            }

            if enabledOverlays.contains(.safety), hasSafetyContent {
                safetySection
            }

            let stops = visibleStopsForCurrentOverlays(day)
            if !stops.isEmpty {
                stopsTimeline(day, stops: stops)
            }
        }
    }

    private func journalContent(_ day: TourDay) -> some View {
        VStack(alignment: .leading, spacing: BCSpacing.lg) {
            guideActions

            if enabledSections.contains(.checklist), let checklist = guide.checklist, !checklist.isEmpty {
                RideChecklistView(guideId: guide.id, items: checklist)
            }

            VStack(alignment: .leading, spacing: BCSpacing.sm) {
                Text("JOURNAL TOOLS")
                    .font(.bcSectionTitle)
                    .tracking(1)
                    .foregroundColor(.secondary)

                NavigationLink(destination: ExpeditionListView()) {
                    toolRow(
                        icon: "book.pages.fill",
                        iconColor: BCColors.brandBlue,
                        title: "Follow My Expedition",
                        subtitle: "Create an offline field log for \(guide.name)",
                        trailing: "chevron.right"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: PackingListView(tripId: guide.id)) {
                    toolRow(
                        icon: "bag.fill",
                        iconColor: BCColors.brandAmber,
                        title: "Pack List",
                        subtitle: packListSubtitle,
                        trailing: "chevron.right"
                    )
                }
                .buttonStyle(.plain)

                if let gpxURL = day.gpxURL {
                    ShareLink(item: gpxURL) {
                        toolRow(
                            icon: "doc.badge.arrow.up",
                            iconColor: BCColors.brandGreen,
                            title: "Share Day GPX",
                            subtitle: day.name,
                            trailing: "square.and.arrow.up"
                        )
                    }
                }
            }
            .padding(BCSpacing.md)
            .background(BCColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if enabledSections.contains(.notes) {
                notesSection
            }
        }
    }

    // MARK: - Map

    private func mapSection(day: TourDay, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DAY MAP")
                    .font(.bcSectionTitle)
                    .tracking(1)
                    .foregroundColor(.secondary)

                Spacer()

                if currentRoute == nil {
                    Text("NO ROUTE LINK")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(.orange)
                }
            }

            Picker("Map layer", selection: $mapLayer) {
                ForEach(TourGuideMapLayer.allCases) { layer in
                    Text(layer.label).tag(layer)
                }
            }
            .pickerStyle(.segmented)
            .font(.system(size: 11))
            .accessibilityLabel("Map layer")

            TourGuideDayMapView(
                day: day,
                route: currentRoute,
                enabledOverlays: enabledOverlays,
                mapLayer: mapLayer,
                isSavedOffline: isCurrentRouteSavedOffline
            )
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .id("\(guide.id)-\(day.dayNumber)-\(currentRoute?.id ?? "fallback")-\(mapLayer.rawValue)")
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private var guideActions: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            Text("GUIDE ACTIONS")
                .font(.bcSectionTitle)
                .tracking(1)
                .foregroundColor(.secondary)

            NavigationLink(destination: JourneyConsoleView(route: currentRoute, guide: guide)) {
                toolRow(
                    icon: "map.fill",
                    iconColor: BCColors.brandBlue,
                    title: "Journey Console",
                    subtitle: "Day readiness, safety, power, and camp review",
                    trailing: "chevron.right"
                )
            }
            .buttonStyle(.plain)

            if let route = currentRoute {
                NavigationLink(destination: RouteNavigationView(route: route)) {
                    toolRow(
                        icon: "location.fill",
                        iconColor: BCColors.brandGreen,
                        title: "Start Ride",
                        subtitle: route.name,
                        trailing: "chevron.right"
                    )
                }
                .buttonStyle(.plain)
            } else {
                toolRow(
                    icon: "location.slash",
                    iconColor: .secondary,
                    title: "Start Ride",
                    subtitle: "Linked route unavailable",
                    trailing: nil
                )
                .opacity(0.65)
            }

            Button {
                saveCurrentRouteOffline()
            } label: {
                toolRow(
                    icon: isCurrentRouteSavedOffline ? "checkmark.circle.fill" : "arrow.down.circle",
                    iconColor: isCurrentRouteSavedOffline ? BCColors.brandGreen : BCColors.brandBlue,
                    title: isCurrentRouteSavedOffline ? "Saved Offline" : "Save Offline",
                    subtitle: isSavingOffline ? "Preparing route..." : offlineStatusText,
                    trailing: isSavingOffline ? nil : "icloud.and.arrow.down"
                )
            }
            .buttonStyle(.plain)
            .disabled(currentRoute == nil || isSavingOffline)

            NavigationLink(destination: PackingListView(tripId: guide.id)) {
                toolRow(
                    icon: "bag.fill",
                    iconColor: BCColors.brandAmber,
                    title: "Open Pack List",
                    subtitle: packListSubtitle,
                    trailing: "chevron.right"
                )
            }
            .buttonStyle(.plain)

            NavigationLink(destination: ExpeditionListView()) {
                toolRow(
                    icon: "book.pages.fill",
                    iconColor: BCColors.brandBlue,
                    title: "Follow My Expedition",
                    subtitle: guide.name,
                    trailing: "chevron.right"
                )
            }
            .buttonStyle(.plain)

            ShareLink(item: shareText) {
                toolRow(
                    icon: "square.and.arrow.up",
                    iconColor: BCColors.brandGreen,
                    title: "Share Guide",
                    subtitle: "\(guide.totalDays) days · \(String(format: "%.0f", guide.totalMiles)) mi",
                    trailing: "square.and.arrow.up"
                )
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func toolRow(icon: String, iconColor: Color, title: String, subtitle: String, trailing: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isSavingOffline && title == "Save Offline" {
                ProgressView()
                    .scaleEffect(0.75)
            } else if let trailing {
                Image(systemName: trailing)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(BCSpacing.sm)
        .background(BCColors.overlayLight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }

    // MARK: - Ride Overlays

    private var rideOverlayPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RIDE OVERLAYS")
                    .font(.bcSectionTitle)
                    .tracking(1)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Reset") {
                    enabledOverlays = guide.defaultEnabledOverlays
                    saveEnabledOverlays()
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(BCColors.brandBlue)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(TourGuideOverlay.allCases) { overlay in
                    overlayToggle(overlay)
                }
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func overlayToggle(_ overlay: TourGuideOverlay) -> some View {
        let isEnabled = enabledOverlays.contains(overlay)
        return Button {
            if isEnabled {
                enabledOverlays.remove(overlay)
            } else {
                enabledOverlays.insert(overlay)
            }
            saveEnabledOverlays()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: overlay.systemImage)
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
        .accessibilityHint(isEnabled ? "Double tap to hide this overlay" : "Double tap to show this overlay")
    }

    // MARK: - Day Overview

    private func dayOverview(_ day: TourDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DAY \(day.dayNumber)")
                    .font(.bcSectionTitle)
                    .tracking(1)
                    .foregroundColor(.secondary)
                Spacer()
                if let route = currentRoute {
                    Text(route.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(BCColors.brandBlue)
                        .lineLimit(1)
                }
            }

            Text(day.name)
                .font(.system(size: 18, weight: .semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                if let time = day.startTime {
                    detailTile(icon: "clock", label: "Start", value: time)
                }
                detailTile(icon: "mappin", label: "Location", value: day.startLocation)
                detailTile(icon: "arrow.left.arrow.right", label: "Distance", value: String(format: "%.1f mi", day.totalMiles))
                detailTile(icon: "arrow.up.right", label: "Elevation", value: formatElevation(day.elevationGain))
                if let duration = day.estimatedDuration {
                    detailTile(icon: "timer", label: "Duration", value: duration)
                }
                if let finish = day.finishLocation {
                    detailTile(icon: "flag.checkered", label: "Finish", value: finish)
                }
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func detailTile(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(BCColors.brandBlue)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(BCSpacing.sm)
        .background(BCColors.overlayLight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Stops

    private func stopsTimeline(_ day: TourDay, stops: [TourStop]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(stopColor(stop.type))
                            .frame(width: 12, height: 12)
                        if index < stops.count - 1 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 12)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(stop.name)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            if let mile = stop.mileMarker {
                                Text(String(format: "mi %.1f", mile))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }

                        if let desc = stop.description {
                            Text(desc)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                        }

                        if let beer = stop.beer {
                            Label(beer, systemImage: "mug")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.bottom, index < stops.count - 1 ? 16 : 0)
                }
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Notes + Safety

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(guide.notes, id: \.self) { note in
                noteRow(icon: "info.circle", color: BCColors.brandBlue, text: note)
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(safetyItems, id: \.self) { note in
                noteRow(icon: "exclamationmark.triangle", color: .orange, text: note)
            }

            if enabledOverlays.contains(.cellCoverage), let route = currentRoute {
                NavigationLink(destination: CellCoverageView(route: route)) {
                    toolRow(
                        icon: "antenna.radiowaves.left.and.right",
                        iconColor: .orange,
                        title: "Cell Coverage",
                        subtitle: "Route signal and dead zones",
                        trailing: "chevron.right"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func noteRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineSpacing(3)
        }
    }

    private func collapsibleSection<Content: View>(
        _ section: TourGuideSection,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.25)) {
                    if collapsedSections.contains(section) {
                        collapsedSections.remove(section)
                    } else {
                        collapsedSections.insert(section)
                    }
                    saveCollapsedSections()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.bcSectionTitle)
                        .tracking(1)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: collapsedSections.contains(section) ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityHint(collapsedSections.contains(section) ? "Double tap to expand section" : "Double tap to collapse section")

            if !collapsedSections.contains(section) {
                content()
            }
        }
    }

    // MARK: - State

    private func saveCurrentRouteOffline() {
        guard let route = currentRoute else { return }
        isSavingOffline = true
        offlineStatusText = "Preparing route..."

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

            if let weather = await WeatherService.shared.weather(for: route.clStartCoordinate) {
                await OfflineRouteStorage.shared.cacheWeather(weather, routeId: route.id)
            }

            let size = await OfflineRouteStorage.shared.formattedCacheSize()
            await MainActor.run {
                isSavingOffline = false
                isCurrentRouteSavedOffline = true
                offlineStatusText = "Route, preview, and weather cached · \(size)"
            }
        }
    }

    private func refreshOfflineState() async {
        guard let route = currentRoute else {
            await MainActor.run {
                isCurrentRouteSavedOffline = false
                offlineStatusText = "Linked route unavailable"
            }
            return
        }

        let isCached = await OfflineRouteStorage.shared.isCached(routeId: route.id)
        let size = await OfflineRouteStorage.shared.formattedCacheSize()
        await MainActor.run {
            isCurrentRouteSavedOffline = isCached
            offlineStatusText = isCached ? "Available offline · \(size)" : "Cache route data, preview, weather, and tile status"
        }
    }

    private func loadPreferencesForSelectedDay() {
        if let data = UserDefaults.standard.data(forKey: overlayStorageKey),
           let decoded = try? JSONDecoder().decode(Set<TourGuideOverlay>.self, from: data) {
            enabledOverlays = decoded
        } else {
            enabledOverlays = guide.defaultEnabledOverlays
        }

        if let data = UserDefaults.standard.data(forKey: collapsedStorageKey),
           let decoded = try? JSONDecoder().decode(Set<TourGuideSection>.self, from: data) {
            collapsedSections = decoded
        } else {
            collapsedSections = []
        }

        if let rawValue = UserDefaults.standard.string(forKey: mapLayerStorageKey),
           let storedLayer = TourGuideMapLayer(rawValue: rawValue) {
            mapLayer = storedLayer
        } else {
            mapLayer = .standard
        }
    }

    private func saveEnabledOverlays() {
        if let data = try? JSONEncoder().encode(enabledOverlays) {
            UserDefaults.standard.set(data, forKey: overlayStorageKey)
        }
    }

    private func saveCollapsedSections() {
        if let data = try? JSONEncoder().encode(collapsedSections) {
            UserDefaults.standard.set(data, forKey: collapsedStorageKey)
        }
    }

    private func saveMapLayer() {
        UserDefaults.standard.set(mapLayer.rawValue, forKey: mapLayerStorageKey)
    }

    private var overlayStorageKey: String {
        "tourGuide.\(guide.id).day.\(selectedDay).overlays"
    }

    private var collapsedStorageKey: String {
        "tourGuide.\(guide.id).day.\(selectedDay).collapsedSections"
    }

    private var mapLayerStorageKey: String {
        "tourGuide.\(guide.id).day.\(selectedDay).mapLayer"
    }

    // MARK: - Helpers

    private var shareText: String {
        [
            guide.name,
            guide.subtitle,
            "\(guide.totalDays) days · \(String(format: "%.0f", guide.totalMiles)) mi · \(formatElevation(guide.totalElevation))",
            guide.description
        ].joined(separator: "\n")
    }

    private var packListSubtitle: String {
        if let gearProfile = guide.gearProfile {
            return gearProfile.replacingOccurrences(of: "-", with: " ").capitalized
        }
        return "Bikepacking gear checklist"
    }

    private var safetyItems: [String] {
        let guideSafety = guide.safetyNotes ?? []
        let stopSafety = guide.days
            .flatMap(\.stops)
            .filter { $0.type == .safety || $0.searchableTags.contains("safety") }
            .compactMap(\.description)
        return guideSafety + stopSafety
    }

    private var hasSafetyContent: Bool {
        !safetyItems.isEmpty || (enabledOverlays.contains(.cellCoverage) && currentRoute != nil)
    }

    private func visibleStopsForCurrentOverlays(_ day: TourDay) -> [TourStop] {
        day.stops.filter { stop in
            if enabledOverlays.contains(.stops) {
                return true
            }
            if enabledOverlays.contains(.sag), stop.type == .sag || stop.type == .resupply || stop.searchableTags.contains("resupply") {
                return true
            }
            if enabledOverlays.contains(.breweries), stop.type == .brewery || stop.beer != nil {
                return true
            }
            if enabledOverlays.contains(.water), stop.type == .water || stop.searchableTags.contains("water") {
                return true
            }
            if enabledOverlays.contains(.safety), stop.type == .safety || stop.searchableTags.contains("safety") {
                return true
            }
            return false
        }
    }

    private var emptyDayState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("Day unavailable")
                .font(.system(size: 14, weight: .medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BCSpacing.xl)
    }

    private func guideStat(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(BCColors.brandBlue)
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.primary)
    }

    private func stopColor(_ type: TourStop.StopType) -> Color {
        switch type {
        case .start: .green
        case .finish: .red
        case .sag, .resupply: .orange
        case .brewery: .brown
        case .trailhead, .camp: BCColors.brandGreen
        case .pointOfInterest: BCColors.brandBlue
        case .water: .cyan
        case .safety: .red
        }
    }

    private func formatElevation(_ feet: Int) -> String {
        if feet >= 1000 {
            return String(format: "%.1fk ft", Double(feet) / 1000)
        }
        return "\(feet) ft"
    }
}

private enum TourGuideMode: String, CaseIterable, Identifiable {
    case plan
    case ride
    case journal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plan: "Plan"
        case .ride: "Ride"
        case .journal: "Journal"
        }
    }

    var systemImage: String {
        switch self {
        case .plan: "list.bullet.rectangle"
        case .ride: "location.fill"
        case .journal: "book.pages"
        }
    }
}

private enum TourGuideMapLayer: String, CaseIterable, Identifiable {
    case standard
    case hybrid
    case imagery

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: "Standard"
        case .hybrid: "Hybrid"
        case .imagery: "Satellite"
        }
    }
}

private struct TourGuideDayMapView: View {
    let day: TourDay
    let route: Route?
    let enabledOverlays: Set<TourGuideOverlay>
    let mapLayer: TourGuideMapLayer
    let isSavedOffline: Bool

    @State private var position: MapCameraPosition

    init(
        day: TourDay,
        route: Route?,
        enabledOverlays: Set<TourGuideOverlay>,
        mapLayer: TourGuideMapLayer,
        isSavedOffline: Bool
    ) {
        self.day = day
        self.route = route
        self.enabledOverlays = enabledOverlays
        self.mapLayer = mapLayer
        self.isSavedOffline = isSavedOffline
        self._position = State(initialValue: .region(Self.boundingRegion(for: Self.routeCoordinates(day: day, route: route))))
    }

    var body: some View {
        styledMap
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    if enabledOverlays.contains(.offlineStatus) {
                        mapStatusPill(
                            icon: isSavedOffline ? "checkmark.circle.fill" : "icloud.and.arrow.down",
                            text: isSavedOffline ? "Offline ready" : "Not saved",
                            color: isSavedOffline ? BCColors.brandGreen : .orange
                        )
                    }

                    if route == nil {
                        mapStatusPill(icon: "exclamationmark.triangle", text: "Fallback map", color: .orange)
                    }
                }
                .padding(10)
            }
            .accessibilityLabel("Map for \(day.name)")
    }

    @ViewBuilder
    private var styledMap: some View {
        switch mapLayer {
        case .standard:
            mapContent.mapStyle(.standard(elevation: .realistic))
        case .hybrid:
            mapContent.mapStyle(.hybrid(elevation: .realistic))
        case .imagery:
            mapContent.mapStyle(.imagery(elevation: .realistic))
        }
    }

    private var mapContent: some View {
        Map(position: $position) {
            let coordinates = Self.routeCoordinates(day: day, route: route)
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(BCColors.brandBlue, lineWidth: 4)
            }

            if let first = coordinates.first {
                Annotation("Start", coordinate: first) {
                    mapDot(color: .green, icon: "play.fill")
                }
            }

            if let last = coordinates.last, coordinates.count > 1 {
                Annotation("Finish", coordinate: last) {
                    mapDot(color: .red, icon: "flag.fill")
                }
            }

            ForEach(visibleStops) { stop in
                if let coordinate = stop.clCoordinate {
                    Annotation(stop.name, coordinate: coordinate) {
                        stopPin(stop)
                    }
                }
            }

            if enabledOverlays.contains(.mileMarkers) {
                ForEach(mileMarkers) { marker in
                    Annotation("Mile \(marker.mile)", coordinate: marker.coordinate) {
                        Text("\(marker.mile)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(BCColors.navPanel.opacity(0.85))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var visibleStops: [TourStop] {
        day.stops.filter { stop in
            if enabledOverlays.contains(.stops) {
                return true
            }
            if enabledOverlays.contains(.sag), stop.type == .sag || stop.type == .resupply || stop.searchableTags.contains("resupply") {
                return true
            }
            if enabledOverlays.contains(.breweries), stop.type == .brewery || stop.beer != nil {
                return true
            }
            if enabledOverlays.contains(.water), stop.type == .water || stop.searchableTags.contains("water") {
                return true
            }
            if enabledOverlays.contains(.safety), stop.type == .safety || stop.searchableTags.contains("safety") {
                return true
            }
            return false
        }
    }

    private var mileMarkers: [TourMileMarker] {
        guard let route, route.distanceMiles >= 5 else { return [] }
        let coordinates = route.clTrackpoints
        guard coordinates.count > 2 else { return [] }

        let step = route.distanceMiles > 35 ? 10 : 5
        return stride(from: step, through: Int(route.distanceMiles), by: step).compactMap { mile in
            let ratio = min(Double(mile) / max(route.distanceMiles, 1), 1)
            let index = min(Int(ratio * Double(coordinates.count - 1)), coordinates.count - 1)
            return TourMileMarker(mile: mile, coordinate: coordinates[index])
        }
    }

    private func stopPin(_ stop: TourStop) -> some View {
        Image(systemName: stopIcon(stop))
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(stopColor(stop.type))
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(radius: 2)
            .accessibilityLabel(stop.name)
    }

    private func mapDot(color: Color, icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(color)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
    }

    private func mapStatusPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .foregroundColor(color)
        .clipShape(Capsule())
    }

    private func stopIcon(_ stop: TourStop) -> String {
        switch stop.type {
        case .start: "play.fill"
        case .finish: "flag.fill"
        case .sag, .resupply: "cross.case.fill"
        case .brewery: "mug.fill"
        case .trailhead: "figure.hiking"
        case .pointOfInterest: "star.fill"
        case .water: "drop.fill"
        case .camp: "tent.fill"
        case .safety: "exclamationmark.triangle.fill"
        }
    }

    private func stopColor(_ type: TourStop.StopType) -> Color {
        switch type {
        case .start: .green
        case .finish: .red
        case .sag, .resupply: .orange
        case .brewery: .brown
        case .trailhead, .camp: BCColors.brandGreen
        case .pointOfInterest: BCColors.brandBlue
        case .water: .cyan
        case .safety: .red
        }
    }

    private static func routeCoordinates(day: TourDay, route: Route?) -> [CLLocationCoordinate2D] {
        if let route {
            return route.clTrackpoints
        }

        if let trackpoints = day.trackpoints {
            let coordinates = trackpoints.compactMap { point -> CLLocationCoordinate2D? in
                guard point.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: point[0], longitude: point[1])
            }
            if !coordinates.isEmpty {
                return coordinates
            }
        }

        let stopCoordinates = day.stops.compactMap(\.clCoordinate)
        if !stopCoordinates.isEmpty {
            return stopCoordinates
        }

        if let start = day.clStartCoordinate {
            return [start]
        }

        return [CLLocationCoordinate2D(latitude: 44.0805, longitude: -103.2310)]
    }

    private static func boundingRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let first = coordinates.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 44.0805, longitude: -103.2310),
                span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
            )
        }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.35, 0.02),
            longitudeDelta: max((maxLon - minLon) * 1.35, 0.02)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

private struct TourMileMarker: Identifiable {
    var id: Int { mile }
    let mile: Int
    let coordinate: CLLocationCoordinate2D
}

extension TourGuide: Hashable {
    static func == (lhs: TourGuide, rhs: TourGuide) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
