//
//  WatchRidePulseModel.swift
//  StoneBCWatch
//

import Foundation
import UserNotifications
import WatchConnectivity
import WatchKit
import WidgetKit

@MainActor
final class WatchRidePulseModel: NSObject, ObservableObject {
    @Published private(set) var snapshot: RidePulseSnapshot?
    @Published private(set) var isReachable = false
    @Published private(set) var pendingCommandCount = 0
    @Published private(set) var lastCommandStatus: String?

    private let store: RidePulseStore
    private let commandQueue: RidePulseCommandQueue
    private let encoder = JSONEncoder()
    private var didStart = false

    init(store: RidePulseStore = .shared, commandQueue: RidePulseCommandQueue = .watchPending) {
        self.store = store
        self.commandQueue = commandQueue
        self.snapshot = Self.launchSnapshot() ?? store.loadSnapshot()
        self.pendingCommandCount = commandQueue.load().count
        super.init()
    }

    private static func launchSnapshot() -> RidePulseSnapshot? {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-stonebc-watch-ui-stale-pulse") else { return nil }

        let updatedAt = Date().addingTimeInterval(-(RidePulseConstants.staleAfter + 60))
        return RidePulseSnapshot(
            routeId: "ui-test-route",
            routeName: "UI Test Route",
            rideState: .recording,
            updatedAt: updatedAt,
            effectiveStartedAt: updatedAt.addingTimeInterval(-1_800),
            pausedAt: nil,
            speedMPH: 9.4,
            distanceTraveledMiles: 3.2,
            distanceRemainingMiles: 5.7,
            progressPercent: 0.36,
            nextCueText: "Turn right",
            nextCueDistanceMeters: 240,
            isOffRoute: false,
            isCriticalOffRoute: false,
            safetyState: .active,
            powerMode: .balanced,
            phoneBatteryLevel: 0.82,
            phoneLowPowerModeEnabled: false,
            lastKnownCoordinate: RidePulseCoordinate(latitude: 44.0805, longitude: -103.2310),
            activeJournalId: "ui-test-journal",
            activeJournalName: "UI Test Expedition",
            activeJournalDayNumber: 1,
            checkInDeadline: Date().addingTimeInterval(1_200)
        )
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        requestNotificationAuthorization()

        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        isReachable = session.isReachable
        retryPendingCommands(session: session)
    }

    func isStale(now: Date = Date()) -> Bool {
        store.isStale(snapshot, now: now)
    }

    func sendCheckIn() {
        enqueueAndSend(
            WatchRideCommand(
                kind: .checkIn,
                coordinate: snapshot?.lastKnownCoordinate,
                journalId: snapshot?.activeJournalId,
                journalDayNumber: snapshot?.activeJournalDayNumber
            ),
            queuedMessage: "Check-in queued",
            sentMessage: "Check-in sent"
        )
    }

    func sendJournalText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        enqueueAndSend(
            WatchRideCommand(
                kind: .journalText,
                text: trimmed,
                coordinate: snapshot?.lastKnownCoordinate,
                journalId: snapshot?.activeJournalId,
                journalDayNumber: snapshot?.activeJournalDayNumber
            ),
            queuedMessage: "Note queued",
            sentMessage: "Note sent"
        )
    }

    func sendEmergencyHandoff() {
        enqueueAndSend(
            WatchRideCommand(
                kind: .openEmergencyHandoff,
                coordinate: snapshot?.lastKnownCoordinate,
                journalId: snapshot?.activeJournalId,
                journalDayNumber: snapshot?.activeJournalDayNumber
            ),
            queuedMessage: "SOS handoff queued",
            sentMessage: "SOS handoff sent"
        )
    }

    private func receiveSnapshot(_ snapshot: RidePulseSnapshot) {
        self.snapshot = snapshot
        store.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: RidePulseConstants.widgetKind)
        retryPendingCommands()
    }

    private func receiveEvent(_ event: RidePulseEvent) {
        if WKExtension.shared().applicationState == .active {
            WKInterfaceDevice.current().play(.notification)
        } else {
            scheduleNotification(for: event)
        }
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleNotification(for event: RidePulseEvent) {
        let content = UNMutableNotificationContent()
        content.title = event.notificationTitle
        content.body = event.notificationBody
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "stonebc-watch-\(event.rawValue)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func enqueueAndSend(_ command: WatchRideCommand, queuedMessage: String, sentMessage: String) {
        commandQueue.enqueue(command)
        pendingCommandCount = commandQueue.load().count
        lastCommandStatus = queuedMessage
        retryPendingCommands(sentMessage: sentMessage)
    }

    private func retryPendingCommands(session: WCSession = .default, sentMessage: String? = nil) {
        guard WCSession.isSupported() else {
            pendingCommandCount = commandQueue.load().count
            return
        }

        let pending = commandQueue.load()
        let sentIds = Set(pending.compactMap { command -> String? in
            transfer(command, session: session) ? command.id : nil
        })

        commandQueue.remove(ids: sentIds)
        pendingCommandCount = commandQueue.load().count

        if !sentIds.isEmpty {
            lastCommandStatus = sentMessage ?? "\(sentIds.count) queued action sent"
            WKInterfaceDevice.current().play(.success)
        }
    }

    private func transfer(_ command: WatchRideCommand, session: WCSession) -> Bool {
        guard session.activationState == .activated,
              let data = try? encoder.encode(command) else {
            return false
        }

        session.transferUserInfo([
            RidePulseConstants.commandUserInfoKey: data
        ])
        return true
    }
}

extension WatchRidePulseModel: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.retryPendingCommands(session: session)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.retryPendingCommands(session: session)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[RidePulseConstants.snapshotContextKey] as? Data,
              let snapshot = try? JSONDecoder().decode(RidePulseSnapshot.self, from: data) else {
            return
        }

        Task { @MainActor in
            self.receiveSnapshot(snapshot)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[RidePulseConstants.eventUserInfoKey] as? Data,
              let event = try? JSONDecoder().decode(RidePulseEvent.self, from: data) else {
            return
        }

        Task { @MainActor in
            self.receiveEvent(event)
        }
    }
}
