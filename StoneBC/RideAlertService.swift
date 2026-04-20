//
//  RideAlertService.swift
//  StoneBC
//
//  Signature beep alerts for time- and distance-based ride milestones —
//  "eat every 45 min", "drink every 20 min", "lube chain every 50 mi".
//  Uses iOS built-in SystemSoundIDs so it works fully offline (airplane mode)
//  without bundled audio assets. Persists user-edited alerts in UserDefaults.
//

import Foundation
import AudioToolbox

@Observable
class RideAlertService {
    static let shared = RideAlertService()

    enum AlertKind: String, Codable, CaseIterable, Identifiable {
        case time
        case distance
        var id: String { rawValue }
        var label: String {
            switch self {
            case .time: "Time"
            case .distance: "Distance"
            }
        }
    }

    enum SignatureSound: String, Codable, CaseIterable, Identifiable {
        case chime, bell, tock
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
        // iOS built-in sound IDs (AudioToolbox / SystemSoundID)
        var systemSoundID: SystemSoundID {
            switch self {
            case .chime: return 1013 // sms-received1 (Tritone)
            case .bell:  return 1322 // Bell
            case .tock:  return 1306 // Tock
            }
        }
    }

    struct Alert: Codable, Identifiable, Equatable {
        var id: UUID
        var label: String
        var kind: AlertKind
        var intervalMinutes: Int
        var intervalMiles: Double
        var sound: SignatureSound
        var enabled: Bool
    }

    private(set) var alerts: [Alert] = []
    private let storageKey = "rideAlerts.v1"

    // Per-session state — reset on startSession()
    private var sessionActive = false
    private var nextDistanceThreshold: [UUID: Double] = [:]
    private var nextTimeThreshold: [UUID: TimeInterval] = [:]

    private init() {
        load()
        if alerts.isEmpty {
            alerts = Self.defaultAlerts
            save()
        }
    }

    static let defaultAlerts: [Alert] = [
        Alert(id: UUID(), label: "Eat",        kind: .time,     intervalMinutes: 45, intervalMiles: 10, sound: .chime, enabled: false),
        Alert(id: UUID(), label: "Drink",      kind: .time,     intervalMinutes: 20, intervalMiles: 5,  sound: .tock,  enabled: false),
        Alert(id: UUID(), label: "Lube chain", kind: .distance, intervalMinutes: 60, intervalMiles: 50, sound: .bell,  enabled: false),
    ]

    // MARK: - Session lifecycle

    func startSession() {
        sessionActive = true
        nextDistanceThreshold.removeAll()
        nextTimeThreshold.removeAll()
        for a in alerts where a.enabled {
            switch a.kind {
            case .time:
                nextTimeThreshold[a.id] = TimeInterval(a.intervalMinutes * 60)
            case .distance:
                nextDistanceThreshold[a.id] = a.intervalMiles
            }
        }
    }

    func endSession() {
        sessionActive = false
        nextDistanceThreshold.removeAll()
        nextTimeThreshold.removeAll()
    }

    /// Call on every GPS tick during an active ride.
    func tick(elapsedSeconds: TimeInterval, distanceMiles: Double) {
        guard sessionActive else { return }
        for a in alerts where a.enabled {
            switch a.kind {
            case .time:
                guard let next = nextTimeThreshold[a.id] else { continue }
                if elapsedSeconds >= next {
                    fire(a)
                    nextTimeThreshold[a.id] = next + TimeInterval(a.intervalMinutes * 60)
                }
            case .distance:
                guard let next = nextDistanceThreshold[a.id] else { continue }
                if distanceMiles >= next {
                    fire(a)
                    nextDistanceThreshold[a.id] = next + a.intervalMiles
                }
            }
        }
    }

    /// True if any alert is currently enabled — used to show indicator dots in UI.
    var hasEnabledAlerts: Bool { alerts.contains { $0.enabled } }

    // MARK: - Editing

    func update(_ alert: Alert) {
        guard let idx = alerts.firstIndex(where: { $0.id == alert.id }) else { return }
        alerts[idx] = alert
        save()
    }

    func toggle(_ id: UUID) {
        guard let idx = alerts.firstIndex(where: { $0.id == id }) else { return }
        alerts[idx].enabled.toggle()
        save()
    }

    @discardableResult
    func add() -> Alert {
        let new = Alert(
            id: UUID(),
            label: "Reminder",
            kind: .time,
            intervalMinutes: 30,
            intervalMiles: 10,
            sound: .chime,
            enabled: true
        )
        alerts.append(new)
        save()
        return new
    }

    func delete(_ id: UUID) {
        alerts.removeAll { $0.id == id }
        save()
    }

    /// Preview a sound from the settings UI.
    func preview(_ sound: SignatureSound) {
        AudioServicesPlaySystemSound(sound.systemSoundID)
    }

    // MARK: - Private

    private func fire(_ alert: Alert) {
        AudioServicesPlaySystemSound(alert.sound.systemSoundID)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Alert].self, from: data) else { return }
        alerts = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(alerts) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
