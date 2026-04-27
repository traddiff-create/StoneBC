//
//  JourneyConsoleView.swift
//  StoneBC
//
//  Expedition-grade mission console for route, guide, recording, and journal flows.
//

import SwiftUI
import CoreLocation

struct JourneyConsoleView: View {
    let route: Route?
    let guide: TourGuide?
    let journal: ExpeditionJournal?

    @State private var store = JourneyStore.shared
    @State private var permissions = PermissionService.shared
    @State private var safety = EmergencySafetyService.shared
    @State private var network = NetworkStatusService.shared
    @State private var readiness: JourneyReadiness?
    @State private var selectedPowerProfile: JourneyPowerProfile = .endurance
    @State private var reviewSummary = ""
    @State private var reviewHazards = ""
    @State private var reviewWater = ""
    @State private var reviewResupply = ""
    @State private var reviewSaved = false

    init(route: Route? = nil, guide: TourGuide? = nil, journal: ExpeditionJournal? = nil) {
        self.route = route
        self.guide = guide
        self.journal = journal
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BCSpacing.lg) {
                headerCard
                missionStatusSection
                readinessSection
                powerSection
                safetySection
                campReviewSection
            }
            .padding(BCSpacing.md)
        }
        .background(BCColors.background)
        .navigationTitle("Journey Console")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            selectedPowerProfile = store.activeSession?.powerProfile ?? .endurance
            await permissions.refreshPermissionStates()
            readiness = await JourneyReadinessService.evaluate(route: route, guide: guide, journal: journal)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MISSION")
                        .font(.bcSectionTitle)
                        .tracking(1)
                        .foregroundStyle(BCColors.secondaryText)
                    Text(journeyTitle)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(BCColors.primaryText)
                        .lineLimit(2)
                }
                Spacer()
                BCIconTile(icon: "map.fill", color: BCColors.brandGreen, size: 44)
            }

            HStack(spacing: BCSpacing.sm) {
                statusPill(
                    label: network.isOnline ? "ONLINE" : "OFFLINE",
                    icon: network.isOnline ? "wifi" : "wifi.slash",
                    color: network.isOnline ? BCColors.brandGreen : BCColors.brandAmber
                )
                statusPill(
                    label: permissions.locationStatus == .authorizedAlways ? "ALWAYS GPS" : "ACTIVE GPS",
                    icon: "location.fill",
                    color: permissions.locationGranted ? BCColors.brandBlue : BCColors.danger
                )
                if ProcessInfo.processInfo.isLowPowerModeEnabled {
                    statusPill(label: "LOW POWER", icon: "battery.25", color: BCColors.brandAmber)
                }
            }

            Button {
                store.startJourney(title: journeyTitle, route: route, guide: guide, journal: journal)
                store.updatePowerProfile(selectedPowerProfile)
                if let coordinate = safety.lastKnownLocation {
                    store.updateLastKnownLocation(coordinate)
                }
            } label: {
                BCPrimaryAction(
                    title: store.activeSession == nil ? "Start Journey" : "Refresh Active Journey",
                    subtitle: "Store local mission state for offline use",
                    icon: "flag.checkered",
                    color: BCColors.brandBlue
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
        .bcInstrumentCard()
    }

    private var missionStatusSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            BCSectionHeader("MISSION STATUS", icon: "list.bullet.clipboard")

            journeyRow("Route", value: route?.name ?? store.activeSession?.routeName ?? "Scout or check-in mode", icon: "point.topleft.down.to.point.bottomright.curvepath")
            journeyRow("Guide", value: guide?.name ?? store.activeSession?.guideName ?? "No guide linked", icon: "book")
            journeyRow("Journal", value: journal?.name ?? store.activeSession?.journalName ?? "No journal linked", icon: "book.pages")
            journeyRow("Last GPS", value: safety.emergencyLocationText, icon: "location")
            journeyRow("Rally Radio", value: "Use nearby peer radio when service drops", icon: "antenna.radiowaves.left.and.right")
        }
        .bcInstrumentCard()
    }

    @ViewBuilder
    private var readinessSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            HStack {
                BCSectionHeader("OFFLINE READINESS", icon: "checklist")
                Spacer()
                if let readiness {
                    Text("\(readiness.score)%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(readiness.blockerCount > 0 ? BCColors.danger : BCColors.brandGreen)
                }
            }

            if let readiness {
                ForEach(readiness.items) { item in
                    readinessRow(item)
                }
            } else {
                ProgressView("Checking mission readiness")
                    .font(.bcCaption)
            }
        }
        .bcInstrumentCard()
    }

    private var powerSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            BCSectionHeader("POWER PROFILE", icon: "battery.100")

            Picker("Power profile", selection: $selectedPowerProfile) {
                ForEach(JourneyPowerProfile.allCases) { profile in
                    Text(profile.label).tag(profile)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedPowerProfile) { _, newValue in
                store.updatePowerProfile(newValue)
            }

            Text(selectedPowerProfile.subtitle)
                .font(.bcCaption)
                .foregroundStyle(BCColors.secondaryText)
        }
        .bcInstrumentCard()
    }

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            BCSectionHeader("SAFETY", icon: "shield.lefthalf.filled")

            if permissions.locationStatus != .authorizedAlways {
                Button {
                    permissions.requestAlwaysLocation()
                } label: {
                    toolRow(
                        icon: "location.badge.plus",
                        color: BCColors.brandAmber,
                        title: "Enable Journey Background Tracking",
                        subtitle: "Upgrade to Always Location for remote days",
                        trailing: "arrow.up.forward"
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                safety.checkIn()
                safety.scheduleCheckInNotification()
            } label: {
                toolRow(
                    icon: "checkmark.seal.fill",
                    color: BCColors.brandGreen,
                    title: "Check In Now",
                    subtitle: safety.formattedCheckInRemaining.isEmpty ? "Starts local check-in timing when a ride begins" : safety.formattedCheckInRemaining,
                    trailing: "bell"
                )
            }
            .buttonStyle(.plain)

            if let smsURL = safety.emergencySMSURL {
                Link(destination: smsURL) {
                    toolRow(
                        icon: "message.fill",
                        color: BCColors.danger,
                        title: "Text Emergency Contact",
                        subtitle: "Opens Messages with last known GPS",
                        trailing: "chevron.right"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .bcInstrumentCard()
    }

    private var campReviewSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            BCSectionHeader("CAMP REVIEW", icon: "tent")

            TextField("Day summary", text: $reviewSummary, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
            TextField("Hazards, closures, exposure", text: $reviewHazards, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
            TextField("Water notes", text: $reviewWater, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
            TextField("Resupply notes", text: $reviewResupply, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)

            Button {
                let review = JourneyDayReview(
                    routeId: route?.id,
                    summary: reviewSummary,
                    hazards: reviewHazards,
                    waterNotes: reviewWater,
                    resupplyNotes: reviewResupply
                )
                if store.activeSession == nil {
                    store.startJourney(title: journeyTitle, route: route, guide: guide, journal: journal)
                }
                store.addDayReview(review)
                reviewSaved = true
            } label: {
                BCPrimaryAction(
                    title: reviewSaved ? "Review Saved" : "Save Camp Review",
                    subtitle: "Local-only field notes for the journey",
                    icon: reviewSaved ? "checkmark.circle.fill" : "square.and.pencil",
                    color: reviewSaved ? BCColors.brandGreen : BCColors.brandBlue
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
        .bcInstrumentCard()
    }

    private var journeyTitle: String {
        route?.name ?? guide?.name ?? journal?.name ?? store.activeSession?.title ?? "Remote Journey"
    }

    private func statusPill(label: String, icon: String, color: Color) -> some View {
        Label(label, systemImage: icon)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.7)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }

    private func journeyRow(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(BCColors.brandBlue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(BCColors.secondaryText)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BCColors.primaryText)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func readinessRow(_ item: JourneyReadinessItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .foregroundStyle(color(for: item.state))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                Text(item.detail)
                    .font(.bcCaption)
                    .foregroundStyle(BCColors.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
            Text(item.state.label)
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color(for: item.state).opacity(0.12), in: Capsule())
                .foregroundStyle(color(for: item.state))
        }
        .padding(.vertical, 5)
    }

    private func toolRow(icon: String, color: Color, title: String, subtitle: String, trailing: String?) -> some View {
        HStack(spacing: 12) {
            BCIconTile(icon: icon, color: color, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BCColors.primaryText)
                Text(subtitle)
                    .font(.bcCaption)
                    .foregroundStyle(BCColors.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
            if let trailing {
                Image(systemName: trailing)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BCColors.secondaryText)
            }
        }
        .padding(.vertical, 6)
    }

    private func color(for state: JourneyReadinessState) -> Color {
        switch state {
        case .ready: BCColors.brandGreen
        case .warning: BCColors.brandAmber
        case .blocked: BCColors.danger
        }
    }
}
