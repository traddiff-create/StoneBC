//
//  RidePulse.swift
//  StoneBC
//

import Foundation

enum RidePulseConstants {
    static let appGroupIdentifier = "group.com.traddiff.StoneBC.watch"
    static let staleAfter: TimeInterval = 15 * 60
    static let widgetKind = "StoneBCRidePulse"
    static let snapshotContextKey = "ridePulseSnapshot"
    static let eventUserInfoKey = "ridePulseEvent"
    static let commandUserInfoKey = "ridePulseCommand"
    static let watchPendingCommandQueueKey = "ridePulse.pendingWatchCommands.v1"
    static let phonePendingCommandQueueKey = "ridePulse.pendingPhoneCommands.v1"
    static let processedCommandIdsKey = "ridePulse.processedCommandIds.v1"
}

struct RidePulseCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

struct RidePulseSnapshot: Codable, Equatable {
    enum RideState: String, Codable {
        case idle
        case ready
        case recording
        case paused
        case stopped
        case ended
        case discarded
    }

    enum SafetyState: String, Codable {
        case inactive
        case active
        case overdue
    }

    enum PowerMode: String, Codable {
        case highDetail
        case balanced
        case endurance
    }

    let routeId: String?
    let routeName: String
    let rideState: RideState
    let updatedAt: Date
    let effectiveStartedAt: Date?
    let pausedAt: Date?
    let speedMPH: Double
    let distanceTraveledMiles: Double
    let distanceRemainingMiles: Double
    let progressPercent: Double
    let nextCueText: String?
    let nextCueDistanceMeters: Double?
    let isOffRoute: Bool
    let isCriticalOffRoute: Bool
    let safetyState: SafetyState
    let powerMode: PowerMode
    let phoneBatteryLevel: Double?
    let phoneLowPowerModeEnabled: Bool
    var lastKnownCoordinate: RidePulseCoordinate? = nil
    var activeJournalId: String? = nil
    var activeJournalName: String? = nil
    var activeJournalDayNumber: Int? = nil
    var checkInDeadline: Date? = nil

    var clampedProgress: Double {
        min(max(progressPercent, 0), 1)
    }

    func isStale(now: Date = Date()) -> Bool {
        now.timeIntervalSince(updatedAt) >= RidePulseConstants.staleAfter
    }
}

struct WatchRideCommand: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case checkIn
        case journalText
        case openEmergencyHandoff
    }

    let id: String
    let kind: Kind
    let createdAt: Date
    let text: String?
    let coordinate: RidePulseCoordinate?
    let journalId: String?
    let journalDayNumber: Int?

    init(
        id: String = UUID().uuidString,
        kind: Kind,
        createdAt: Date = Date(),
        text: String? = nil,
        coordinate: RidePulseCoordinate? = nil,
        journalId: String? = nil,
        journalDayNumber: Int? = nil
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.text = text
        self.coordinate = coordinate
        self.journalId = journalId
        self.journalDayNumber = journalDayNumber
    }
}

struct RidePulseCommandQueue {
    static let watchPending = RidePulseCommandQueue(key: RidePulseConstants.watchPendingCommandQueueKey)
    static let phonePending = RidePulseCommandQueue(key: RidePulseConstants.phonePendingCommandQueueKey, defaults: .standard)

    private let key: String
    private let defaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(key: String, defaults: UserDefaults? = UserDefaults(suiteName: RidePulseConstants.appGroupIdentifier)) {
        self.key = key
        self.defaults = defaults ?? .standard
    }

    func load() -> [WatchRideCommand] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? decoder.decode([WatchRideCommand].self, from: data)) ?? []
    }

    func enqueue(_ command: WatchRideCommand) {
        var commands = load()
        guard !commands.contains(where: { $0.id == command.id }) else { return }
        commands.append(command)
        save(commands)
    }

    func remove(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        save(load().filter { !ids.contains($0.id) })
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

    private func save(_ commands: [WatchRideCommand]) {
        guard let data = try? encoder.encode(commands) else { return }
        defaults.set(data, forKey: key)
    }
}

enum RidePulseEvent: String, Codable, Equatable {
    case offRoute
    case criticalOffRoute
    case safetyCheckInOverdue
    case rideEnded

    var notificationTitle: String {
        switch self {
        case .offRoute:
            return "Off route"
        case .criticalOffRoute:
            return "Far off route"
        case .safetyCheckInOverdue:
            return "Check-in overdue"
        case .rideEnded:
            return "Ride ended"
        }
    }

    var notificationBody: String {
        switch self {
        case .offRoute:
            return "StoneBC ride pulse changed to off route."
        case .criticalOffRoute:
            return "StoneBC ride pulse changed to far off route."
        case .safetyCheckInOverdue:
            return "Confirm you are OK in StoneBC."
        case .rideEnded:
            return "StoneBC ride pulse stopped."
        }
    }
}

struct RidePulseCadence: Equatable {
    let minimumInterval: TimeInterval
    let minimumDistanceMeters: Double

    static func cadence(for powerMode: RidePulseSnapshot.PowerMode) -> RidePulseCadence {
        switch powerMode {
        case .highDetail:
            return RidePulseCadence(minimumInterval: 60, minimumDistanceMeters: 160)
        case .balanced:
            return RidePulseCadence(minimumInterval: 120, minimumDistanceMeters: 400)
        case .endurance:
            return RidePulseCadence(minimumInterval: 300, minimumDistanceMeters: 800)
        }
    }
}

enum RidePulseThrottle {
    static func shouldPublish(
        snapshot: RidePulseSnapshot,
        lastPublishedAt: Date?,
        lastPublishedDistanceMiles: Double,
        force: Bool
    ) -> Bool {
        if force { return true }
        guard let lastPublishedAt else { return true }

        let cadence = RidePulseCadence.cadence(for: snapshot.powerMode)
        let elapsed = snapshot.updatedAt.timeIntervalSince(lastPublishedAt)
        let distanceMeters = max(0, snapshot.distanceTraveledMiles - lastPublishedDistanceMiles) * 1609.344

        return elapsed >= cadence.minimumInterval || distanceMeters >= cadence.minimumDistanceMeters
    }
}

struct RidePulseStore {
    static let shared = RidePulseStore()

    private let snapshotKey = "ridePulse.snapshot.v1"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let defaults: UserDefaults

    init(defaults: UserDefaults? = UserDefaults(suiteName: RidePulseConstants.appGroupIdentifier)) {
        self.defaults = defaults ?? .standard
    }

    func loadSnapshot() -> RidePulseSnapshot? {
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? decoder.decode(RidePulseSnapshot.self, from: data)
    }

    func save(_ snapshot: RidePulseSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    func clear() {
        defaults.removeObject(forKey: snapshotKey)
    }

    func isStale(_ snapshot: RidePulseSnapshot?, now: Date = Date()) -> Bool {
        guard let snapshot else { return true }
        return snapshot.isStale(now: now)
    }
}
