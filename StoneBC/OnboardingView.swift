//
//  OnboardingView.swift
//  StoneBC
//
//  RIDR-styled first-run tour and guided permission deck.
//

import SwiftUI

struct OnboardingView: View {
    private static let introPages: [OnboardingIntroPage] = [
        OnboardingIntroPage(
            id: "WELCOME",
            reference: "REF 0001",
            icon: "bicycle",
            color: BCColors.signalPrimary,
            title: "STONEBC",
            subtitle: "HANDLEBAR INSTRUMENT",
            body: "A dark-first ride console for routes, recording, field notes, radio, and local-first Black Hills riding.",
            metrics: [
                OnboardingMetric(label: "ROUTES", value: "56", unit: "FILES", role: .power),
                OnboardingMetric(label: "MODE", value: "DARK", unit: "RIDR", role: .neutral),
                OnboardingMetric(label: "DATA", value: "LOCAL", unit: "FIRST", role: .ok)
            ]
        ),
        OnboardingIntroPage(
            id: "ROUTE LOG",
            reference: "REF 0002",
            icon: "map",
            color: BCColors.signalMoss,
            title: "ROUTE LOG",
            subtitle: "BLACK HILLS / PLAINS / BADLANDS",
            body: "Browse curated road, gravel, fatbike, touring, and trail routes with elevation, difficulty, imports, exports, and offline-ready files.",
            metrics: [
                OnboardingMetric(label: "IMPORT", value: "GPX", unit: "FIT", role: .neutral),
                OnboardingMetric(label: "EXPORT", value: "TCX", unit: "ZIP", role: .neutral),
                OnboardingMetric(label: "MAP", value: "OFF", unit: "LINE", role: .ok)
            ]
        ),
        OnboardingIntroPage(
            id: "RIDE COCKPIT",
            reference: "REF 0003",
            icon: "gauge.with.dots.needle.50percent",
            color: BCColors.signalLume,
            title: "RIDE COCKPIT",
            subtitle: "RECORD / NAVIGATE / SAVE",
            body: "Start a free ride or follow a route. Speed, distance, elapsed time, climb, alerts, and Live Activity updates stay built for quick reads.",
            metrics: [
                OnboardingMetric(label: "SPEED", value: "LIVE", unit: "GPS", role: .primary),
                OnboardingMetric(label: "AUDIO", value: "CUES", unit: "ON", role: .neutral),
                OnboardingMetric(label: "SAVE", value: "RIDE", unit: "LOG", role: .power)
            ]
        ),
        OnboardingIntroPage(
            id: "FIELD KIT",
            reference: "REF 0004",
            icon: "wrench.and.screwdriver",
            color: BCColors.signalWarn,
            title: "FIELD KIT",
            subtitle: "RADIO / JOURNAL / SAFETY",
            body: "Use Rally Radio, expedition field logs, camera capture, audio notes, share cards, Health workouts, and local notifications when the route demands it.",
            metrics: [
                OnboardingMetric(label: "RADIO", value: "PTT", unit: "PEER", role: .heart),
                OnboardingMetric(label: "MEDIA", value: "FIELD", unit: "LOG", role: .warning),
                OnboardingMetric(label: "HEALTH", value: "SYNC", unit: "OPT", role: .neutral)
            ]
        )
    ]

    private static let permissionKinds = OnboardingPermissionKind.allCases

    @State private var currentPage = 0
    @State private var permissionService = PermissionService.shared
    var onComplete: () -> Void

    private var permissionIntroIndex: Int { Self.introPages.count }
    private var permissionStartIndex: Int { permissionIntroIndex + 1 }
    private var pageCount: Int { Self.introPages.count + Self.permissionKinds.count + 2 }
    private var lastIndex: Int { pageCount - 1 }
    private var permissionCompletionCount: Int {
        Self.permissionKinds.filter { $0.state(in: permissionService).isSatisfied }.count
    }

    var body: some View {
        ZStack {
            BCColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                RIDRStatusHeader(
                    left: "STONEBC · ONBOARD",
                    right: "CARD \(currentPage + 1)/\(pageCount)"
                )
                .padding(.horizontal, BCSpacing.md)
                .padding(.top, BCSpacing.sm)

                TabView(selection: $currentPage) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        page(for: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.24), value: currentPage)

                bottomControls
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await permissionService.refreshPermissionStates()
        }
        .onChange(of: currentPage) { _, _ in
            Task {
                await permissionService.refreshPermissionStates()
            }
        }
    }

    @ViewBuilder
    private func page(for index: Int) -> some View {
        if index < Self.introPages.count {
            RIDRIntroOnboardingPage(page: Self.introPages[index])
        } else if index == permissionIntroIndex {
            permissionCheckPage
        } else if index < lastIndex {
            let permissionIndex = index - permissionStartIndex
            RIDRPermissionOnboardingPage(
                kind: Self.permissionKinds[permissionIndex],
                service: permissionService
            )
        } else {
            readyPage
        }
    }

    private var permissionCheckPage: some View {
        RIDROnboardingShell(reference: "REF 0005", status: "CHECKLIST", statusColor: BCColors.signalWarn) {
            VStack(alignment: .leading, spacing: BCSpacing.lg) {
                RIDRPageTitle(
                    icon: "checklist",
                    color: BCColors.signalWarn,
                    title: "PERMISSION CHECK",
                    subtitle: "ENABLE ONLY WHAT YOU USE",
                    copy: "StoneBC asks through guided cards. No permission is requested until you press its control."
                )

                RIDRMetricTile(
                    label: "Checks",
                    value: "\(permissionCompletionCount)/\(Self.permissionKinds.count)",
                    unit: "READY",
                    role: permissionCompletionCount == Self.permissionKinds.count ? .ok : .warning,
                    activeTicks: permissionCompletionCount * 2
                )

                VStack(spacing: 0) {
                    ForEach(Self.permissionKinds) { kind in
                        RIDRPermissionStatusRow(kind: kind, service: permissionService)
                        if kind.id != Self.permissionKinds.last?.id {
                            BCHairline()
                        }
                    }
                }
                .background(BCColors.caseSub)
                .overlay { RIDRCaseFrame() }
            }
        }
    }

    private var readyPage: some View {
        RIDROnboardingShell(reference: "REF READY", status: "GO", statusColor: BCColors.signalOK) {
            VStack(alignment: .leading, spacing: BCSpacing.lg) {
                RIDRPageTitle(
                    icon: "checkmark.square",
                    color: BCColors.signalOK,
                    title: "READY",
                    subtitle: "START THE RIDE LOG",
                    copy: "The cockpit is configured. You can revisit this tour from More at any time."
                )

                RIDRMetricTile(
                    label: "Status",
                    value: "\(permissionCompletionCount)/\(Self.permissionKinds.count)",
                    unit: "CHECKS",
                    role: permissionCompletionCount == Self.permissionKinds.count ? .ok : .warning,
                    activeTicks: permissionCompletionCount * 2
                )

                RIDRCompactPermissionGrid(kinds: Self.permissionKinds, service: permissionService)

                Button {
                    onComplete()
                } label: {
                    RIDRButton(
                        title: "ENTER APP",
                        systemImage: "arrow.right.square",
                        subtitle: "Open StoneBC",
                        role: .power
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Enter StoneBC")
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: BCSpacing.sm) {
            HStack(spacing: 4) {
                ForEach(0..<pageCount, id: \.self) { page in
                    Rectangle()
                        .fill(page == currentPage ? BCColors.signalPrimary : BCColors.caseShadow)
                        .frame(width: page == currentPage ? 18 : 6, height: 6)
                }
            }
            .frame(height: 14)
            .accessibilityHidden(true)

            HStack(spacing: BCSpacing.md) {
                if currentPage < lastIndex {
                    Button {
                        withAnimation { currentPage = lastIndex }
                    } label: {
                        Text("SKIP TO READY")
                            .font(.ridrMicro)
                            .tracking(1.8)
                            .foregroundColor(BCColors.caseSteelMid)
                            .frame(width: 140, height: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Skip to ready")

                    Spacer(minLength: BCSpacing.md)

                    Button {
                        withAnimation {
                            currentPage = min(currentPage + 1, lastIndex)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("NEXT")
                                .font(.ridrMicro)
                                .tracking(1.8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(BCColors.signalPrimary)
                        .frame(width: 82, height: 44, alignment: .trailing)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next onboarding card")
                }
            }
            .padding(.horizontal, BCSpacing.lg)
        }
        .padding(.top, BCSpacing.sm)
        .padding(.bottom, BCSpacing.md)
        .background(BCColors.caseInk)
        .overlay(alignment: .top) { BCHairline() }
    }
}

private struct OnboardingIntroPage: Identifiable {
    let id: String
    let reference: String
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let body: String
    let metrics: [OnboardingMetric]
}

private struct OnboardingMetric: Identifiable {
    var id: String { label }
    let label: String
    let value: String
    let unit: String
    let role: RIDRMetricRole
}

private enum OnboardingPermissionKind: String, CaseIterable, Identifiable {
    case location
    case motion
    case microphone
    case localNetwork
    case camera
    case photos
    case health
    case notifications

    var id: String { rawValue }

    var reference: String {
        switch self {
        case .location: "PERM 01"
        case .motion: "PERM 02"
        case .microphone: "PERM 03"
        case .localNetwork: "PERM 04"
        case .camera: "PERM 05"
        case .photos: "PERM 06"
        case .health: "PERM 07"
        case .notifications: "PERM 08"
        }
    }

    var icon: String {
        switch self {
        case .location: "location.fill"
        case .motion: "gauge.with.dots.needle.33percent"
        case .microphone: "waveform.badge.mic"
        case .localNetwork: "antenna.radiowaves.left.and.right"
        case .camera: "camera.fill"
        case .photos: "photo.badge.plus"
        case .health: "heart.fill"
        case .notifications: "bell.badge.fill"
        }
    }

    var color: Color {
        switch self {
        case .location, .localNetwork: BCColors.signalPrimary
        case .motion, .notifications: BCColors.signalWarn
        case .microphone, .health: BCColors.signalAlert
        case .camera: BCColors.signalMoss
        case .photos: BCColors.signalOK
        }
    }

    var title: String {
        switch self {
        case .location: "LOCATION"
        case .motion: "MOTION"
        case .microphone: "MICROPHONE"
        case .localNetwork: "LOCAL NETWORK"
        case .camera: "CAMERA"
        case .photos: "PHOTOS"
        case .health: "APPLE HEALTH"
        case .notifications: "NOTIFICATIONS"
        }
    }

    var subtitle: String {
        switch self {
        case .location: "GPS NAVIGATION AND RECORDING"
        case .motion: "ALTIMETER AND CLIMB DATA"
        case .microphone: "RALLY RADIO PUSH TO TALK"
        case .localNetwork: "PEER DISCOVERY FOR RADIO"
        case .camera: "EXPEDITION FIELD CAPTURE"
        case .photos: "SAVE SHARE CARDS"
        case .health: "WORKOUT READ AND WRITE"
        case .notifications: "ROUTE AND EVENT ALERTS"
        }
    }

    var body: String {
        switch self {
        case .location:
            "Follow routes, record rides, show progress, and keep navigation alive during active rides. Location stays on device unless you export it."
        case .motion:
            "Use the barometer and motion sensors for altitude, climb rate, grade, and ride cockpit elevation data."
        case .microphone:
            "Rally Radio only records while push to talk is active. Audio is sent peer to peer and is not stored by StoneBC."
        case .localNetwork:
            "Rally Radio discovers nearby riders over the local network. This probe starts discovery briefly, then shuts it down."
        case .camera:
            "Capture expedition photos directly from the field log when documenting a ride or multi-day route."
        case .photos:
            "Save ride cards and expedition images to Photos with add-only access. StoneBC does not need full library browsing."
        case .health:
            "Save completed rides as cycling workouts and read cycling workouts for ride history when Health is available."
        case .notifications:
            "Use local notifications for favorited route events and ride-window reminders. No push server is involved."
        }
    }

    var buttonTitle: String {
        switch self {
        case .location: "ENABLE LOCATION"
        case .motion: "ENABLE MOTION"
        case .microphone: "ENABLE MIC"
        case .localNetwork: "PROBE NETWORK"
        case .camera: "ENABLE CAMERA"
        case .photos: "ENABLE PHOTOS"
        case .health: "CONNECT HEALTH"
        case .notifications: "ENABLE ALERTS"
        }
    }

    func state(in service: PermissionService) -> OnboardingPermissionState {
        switch self {
        case .location:
            if service.locationGranted { return .enabled }
            return service.locationDenied ? .denied : .standby
        case .motion:
            if !service.motionAvailable { return .unavailable }
            return service.motionGranted ? .enabled : .standby
        case .microphone:
            if service.microphoneGranted { return .enabled }
            return service.microphoneDenied ? .denied : .standby
        case .localNetwork:
            if service.localNetworkProbeActive { return .active }
            return service.localNetworkRequested ? .requested : .standby
        case .camera:
            if service.cameraGranted { return .enabled }
            return service.cameraDenied ? .denied : .standby
        case .photos:
            if service.photosAddOnlyGranted { return .enabled }
            return service.photosAddOnlyDenied ? .denied : .standby
        case .health:
            if !service.healthKitAvailable { return .unavailable }
            return service.healthKitAuthorized ? .enabled : .standby
        case .notifications:
            if service.notificationsGranted { return .enabled }
            return service.notificationsDenied ? .denied : .standby
        }
    }

    func request(using service: PermissionService) {
        switch self {
        case .location:
            service.requestLocation()
        case .motion:
            service.requestMotion()
        case .microphone:
            service.requestMicrophone()
        case .localNetwork:
            service.requestLocalNetworkProbe()
        case .camera:
            service.requestCamera()
        case .photos:
            service.requestPhotosAddOnly()
        case .health:
            Task { await service.requestHealthKit() }
        case .notifications:
            Task { await service.requestNotifications() }
        }
    }
}

private enum OnboardingPermissionState: Equatable {
    case standby
    case active
    case requested
    case enabled
    case denied
    case unavailable

    var label: String {
        switch self {
        case .standby: "STANDBY"
        case .active: "PROBING"
        case .requested: "CHECKED"
        case .enabled: "ENABLED"
        case .denied: "DENIED"
        case .unavailable: "N/A"
        }
    }

    var color: Color {
        switch self {
        case .standby: BCColors.caseSteelMid
        case .active: BCColors.signalWarn
        case .requested, .enabled: BCColors.signalOK
        case .denied: BCColors.signalAlert
        case .unavailable: BCColors.caseShadow
        }
    }

    var isSatisfied: Bool {
        switch self {
        case .requested, .enabled, .unavailable: true
        case .standby, .active, .denied: false
        }
    }

    var disablesAction: Bool {
        switch self {
        case .active, .requested, .enabled, .denied, .unavailable: true
        case .standby: false
        }
    }

    var buttonTitle: String? {
        switch self {
        case .standby: nil
        case .active: "PROBING"
        case .requested: "CHECKED"
        case .enabled: "ENABLED"
        case .denied: "SETTINGS REQUIRED"
        case .unavailable: "UNAVAILABLE"
        }
    }
}

private struct RIDRIntroOnboardingPage: View {
    let page: OnboardingIntroPage

    var body: some View {
        RIDROnboardingShell(reference: page.reference, status: page.id, statusColor: page.color) {
            VStack(alignment: .leading, spacing: BCSpacing.lg) {
                RIDRPageTitle(
                    icon: page.icon,
                    color: page.color,
                    title: page.title,
                    subtitle: page.subtitle,
                    copy: page.body
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BCSpacing.sm) {
                    ForEach(page.metrics) { metric in
                        RIDRMetricTile(
                            label: metric.label,
                            value: metric.value,
                            unit: metric.unit,
                            role: metric.role,
                            isPrimary: metric.role == .primary,
                            activeTicks: metric.role == .primary ? 12 : 0
                        )
                    }
                }

                RIDRTickRow(count: 29, majorEvery: 4, activeCount: 8, activeColor: page.color)
            }
        }
    }
}

private struct RIDRPermissionOnboardingPage: View {
    let kind: OnboardingPermissionKind
    let service: PermissionService

    private var state: OnboardingPermissionState {
        kind.state(in: service)
    }

    var body: some View {
        RIDROnboardingShell(reference: kind.reference, status: state.label, statusColor: state.color) {
            VStack(alignment: .leading, spacing: BCSpacing.lg) {
                RIDRPageTitle(
                    icon: kind.icon,
                    color: kind.color,
                    title: kind.title,
                    subtitle: kind.subtitle,
                    copy: kind.body
                )

                HStack(spacing: BCSpacing.sm) {
                    RIDRMetricTile(
                        label: "Status",
                        value: state.label,
                        unit: kind.reference,
                        role: state == .enabled || state == .requested ? .ok : .neutral,
                        activeTicks: state.isSatisfied ? 12 : 0
                    )

                    RIDRMetricTile(
                        label: "Mode",
                        value: "OPT",
                        unit: "IN",
                        role: .neutral
                    )
                }

                Button {
                    kind.request(using: service)
                } label: {
                    RIDRButton(
                        title: state.buttonTitle ?? kind.buttonTitle,
                        systemImage: kind.icon,
                        subtitle: kind.subtitle.capitalized,
                        role: state == .denied ? .heart : kind.buttonRole,
                        foreground: state.disablesAction ? BCColors.caseBrushed : nil
                    )
                    .opacity(state.disablesAction ? 0.64 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(state.disablesAction)
                .accessibilityLabel("\(kind.title), \(state.label)")

                PermissionNote(state: state)
            }
        }
    }
}

private extension OnboardingPermissionKind {
    var buttonRole: RIDRMetricRole {
        switch self {
        case .location, .localNetwork: .power
        case .motion, .notifications: .warning
        case .microphone, .health: .heart
        case .camera, .photos: .ok
        }
    }
}

private struct RIDRPermissionStatusRow: View {
    let kind: OnboardingPermissionKind
    let service: PermissionService

    private var state: OnboardingPermissionState {
        kind.state(in: service)
    }

    var body: some View {
        HStack(spacing: BCSpacing.sm) {
            RIDRIconTile(icon: kind.icon, color: kind.color, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(kind.title)
                    .font(.ridrHeading)
                    .tracking(0.8)
                    .foregroundColor(BCColors.caseBrushed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(kind.subtitle)
                    .font(.ridrMicro)
                    .tracking(1.6)
                    .foregroundColor(BCColors.caseSteelMid)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
            }

            Spacer(minLength: BCSpacing.sm)

            RIDRBadge(text: state.label, color: state.color)
        }
        .padding(.horizontal, BCSpacing.md)
        .padding(.vertical, BCSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.title), \(state.label)")
    }
}

private struct RIDRCompactPermissionGrid: View {
    let kinds: [OnboardingPermissionKind]
    let service: PermissionService

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: BCSpacing.sm) {
            ForEach(kinds) { kind in
                let state = kind.state(in: service)
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(state.color)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title)
                            .font(.ridrMicro)
                            .tracking(1.4)
                            .foregroundColor(BCColors.caseBrushed)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        Text(state.label)
                            .font(.ridrMicro)
                            .tracking(1.4)
                            .foregroundColor(state.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(minHeight: 44)
                .background(BCColors.caseSub)
                .overlay { RIDRCaseFrame() }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(kind.title), \(state.label)")
            }
        }
    }
}

private struct PermissionNote: View {
    let state: OnboardingPermissionState

    var body: some View {
        Text(note)
            .font(.ridrBodySmall)
            .foregroundColor(BCColors.caseSteelMid)
            .lineSpacing(3)
            .padding(BCSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BCColors.caseSub)
            .overlay { RIDRCaseFrame() }
            .accessibilityLabel(note)
    }

    private var note: String {
        switch state {
        case .standby:
            "Press the control above to open the system prompt for this capability."
        case .active:
            "The local network probe is active. It will stop automatically."
        case .requested:
            "The local network prompt path has been checked. Radio will still request access again if iOS needs it."
        case .enabled:
            "This capability is enabled for StoneBC."
        case .denied:
            "iOS denied this capability. Change it later in Settings if you need the feature."
        case .unavailable:
            "This capability is not available on this device."
        }
    }
}

private struct RIDRPageTitle: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let copy: String

    var bodyContent: some View {
        VStack(alignment: .leading, spacing: BCSpacing.md) {
            HStack(alignment: .top, spacing: BCSpacing.md) {
                RIDRIconTile(icon: icon, color: color, size: 72)

                VStack(alignment: .leading, spacing: BCSpacing.xs) {
                    Text(subtitle)
                        .font(.ridrMicro)
                        .tracking(2.2)
                        .foregroundColor(BCColors.caseSteelMid)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                    Text(title)
                        .font(.ridrDisplayMD)
                        .foregroundColor(BCColors.caseBrushed)
                        .lineLimit(2)
                        .minimumScaleFactor(0.56)
                }
            }

            Text(copy)
                .font(.ridrBody)
                .foregroundColor(BCColors.caseSteelMid)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    var body: some View {
        bodyContent
    }
}

private struct RIDROnboardingShell<Content: View>: View {
    let reference: String
    let status: String
    let statusColor: Color
    let content: Content

    init(
        reference: String,
        status: String = "STONEBC",
        statusColor: Color = BCColors.caseSteelMid,
        @ViewBuilder content: () -> Content
    ) {
        self.reference = reference
        self.status = status
        self.statusColor = statusColor
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: BCSpacing.lg) {
                    HStack {
                        RIDRBadge(text: reference, color: BCColors.caseSteelMid)
                        Spacer(minLength: BCSpacing.md)
                        RIDRBadge(text: status, color: statusColor)
                    }

                    content
                }
                .padding(BCSpacing.lg)
                .frame(maxWidth: .infinity, minHeight: max(proxy.size.height - 24, 0), alignment: .center)
                .background(BCColors.caseDial)
                .overlay { RIDRCaseFrame(showScrews: true) }
                .padding(.horizontal, BCSpacing.md)
                .padding(.vertical, BCSpacing.sm)
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview {
    OnboardingView {}
}
