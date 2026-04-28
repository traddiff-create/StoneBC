//
//  RidePulsePublisher.swift
//  StoneBC
//

#if os(iOS)
import CoreLocation
import Foundation
import UIKit
import WatchConnectivity

@MainActor
protocol RidePulsePublishing: AnyObject {
    func start()
    func publish(snapshot: RidePulseSnapshot, force: Bool, events: [RidePulseEvent])
}

@MainActor
final class RidePulsePublisher: NSObject, RidePulsePublishing {
    static let shared = RidePulsePublisher()

    private var session: WCSession?
    private var lastPublishedAt: Date?
    private var lastPublishedDistanceMiles: Double = 0
    private let encoder = JSONEncoder()

    override private init() {
        super.init()
    }

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil {
            session.delegate = self
        }
        if session.activationState == .notActivated {
            session.activate()
        }
        self.session = session
        Task {
            await RidePulseCommandProcessor.shared.retryPending()
        }
    }

    func publish(snapshot: RidePulseSnapshot, force: Bool = false, events: [RidePulseEvent] = []) {
        start()
        guard let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled else {
            return
        }

        let shouldForce = force || !events.isEmpty
        guard RidePulseThrottle.shouldPublish(
            snapshot: snapshot,
            lastPublishedAt: lastPublishedAt,
            lastPublishedDistanceMiles: lastPublishedDistanceMiles,
            force: shouldForce
        ) else {
            return
        }

        guard let snapshotData = try? encoder.encode(snapshot) else { return }

        do {
            try session.updateApplicationContext([
                RidePulseConstants.snapshotContextKey: snapshotData
            ])
            lastPublishedAt = snapshot.updatedAt
            lastPublishedDistanceMiles = snapshot.distanceTraveledMiles
        } catch {
            return
        }

        for event in events {
            guard let eventData = try? encoder.encode(event) else { continue }
            session.transferUserInfo([
                RidePulseConstants.eventUserInfoKey: eventData
            ])
        }

        Task {
            await RidePulseCommandProcessor.shared.retryPending()
        }
    }
}

extension RidePulsePublisher: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[RidePulseConstants.commandUserInfoKey] as? Data,
              let command = try? JSONDecoder().decode(WatchRideCommand.self, from: data) else {
            return
        }

        Task { @MainActor in
            await RidePulseCommandProcessor.shared.receive(command)
        }
    }
}

@MainActor
final class RidePulseCommandProcessor {
    static let shared = RidePulseCommandProcessor()

    private let defaults: UserDefaults
    private let pendingQueue: RidePulseCommandQueue

    init(
        defaults: UserDefaults = .standard,
        pendingQueue: RidePulseCommandQueue = .phonePending
    ) {
        self.defaults = defaults
        self.pendingQueue = pendingQueue
    }

    func receive(_ command: WatchRideCommand) async {
        if isProcessed(command.id) {
            pendingQueue.remove(ids: Set([command.id]))
            return
        }

        if await apply(command) {
            markProcessed(command.id)
            pendingQueue.remove(ids: Set([command.id]))
        } else {
            pendingQueue.enqueue(command)
        }
    }

    func retryPending() async {
        let commands = pendingQueue.load()
        var handledIds = Set<String>()

        for command in commands {
            if isProcessed(command.id) {
                handledIds.insert(command.id)
            } else if await apply(command) {
                markProcessed(command.id)
                handledIds.insert(command.id)
            }
        }

        pendingQueue.remove(ids: handledIds)
    }

    private func apply(_ command: WatchRideCommand) async -> Bool {
        switch command.kind {
        case .checkIn:
            EmergencySafetyService.shared.checkIn()
            return true
        case .openEmergencyHandoff:
            defaults.set(Date().timeIntervalSince1970, forKey: "pendingWatchEmergencyHandoffAt")
            if UIApplication.shared.applicationState == .active {
                EmergencySafetyService.shared.openEmergencySOSSettings()
            }
            return true
        case .journalText:
            return await appendJournalEntry(from: command)
        }
    }

    private func appendJournalEntry(from command: WatchRideCommand) async -> Bool {
        guard let text = command.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              var journal = RidePulseJournalContextProvider.loadActiveJournal(preferredId: command.journalId) else {
            return false
        }

        let dayNumber = command.journalDayNumber ?? journal.activeDayNumber
        guard let dayIndex = journal.days.firstIndex(where: { $0.dayNumber == dayNumber }) else {
            return false
        }

        let coordinate = command.coordinate.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let entry = JournalEntry(
            text: text,
            momentKind: .reflection,
            source: .iphone,
            coordinate: coordinate
        )

        journal.days[dayIndex].entries.append(entry)
        await ExpeditionStorage.shared.save(journal)
        return true
    }

    private func isProcessed(_ id: String) -> Bool {
        processedIds().contains(id)
    }

    private func markProcessed(_ id: String) {
        var ids = processedIds().filter { $0 != id }
        ids.append(id)
        if ids.count > 200 {
            ids.removeFirst(ids.count - 200)
        }
        defaults.set(ids, forKey: RidePulseConstants.processedCommandIdsKey)
    }

    private func processedIds() -> [String] {
        defaults.stringArray(forKey: RidePulseConstants.processedCommandIdsKey) ?? []
    }
}

struct RidePulseJournalContext {
    let id: String
    let name: String
    let dayNumber: Int
}

enum RidePulseJournalContextProvider {
    static func current() -> RidePulseJournalContext? {
        guard let journal = loadActiveJournal(preferredId: nil) else { return nil }
        return RidePulseJournalContext(
            id: journal.id,
            name: journal.name,
            dayNumber: journal.activeDayNumber
        )
    }

    static func loadActiveJournal(preferredId: String?) -> ExpeditionJournal? {
        if let preferredId {
            guard let journal = loadJournal(id: preferredId),
                  journal.status == .active else {
                return nil
            }
            return journal
        }

        return listJournals()
            .filter { $0.status == .active }
            .sorted { $0.startDate > $1.startDate }
            .first
    }

    private static func listJournals() -> [ExpeditionJournal] {
        let root = expeditionsDirectory()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return contents.compactMap { directory in
            loadJournal(at: directory.appendingPathComponent("journal.json"))
        }
    }

    private static func loadJournal(id: String) -> ExpeditionJournal? {
        loadJournal(at: expeditionsDirectory().appendingPathComponent(id).appendingPathComponent("journal.json"))
    }

    private static func loadJournal(at url: URL) -> ExpeditionJournal? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ExpeditionJournal.self, from: data)
    }

    private static func expeditionsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Expeditions", isDirectory: true)
    }
}
#endif
