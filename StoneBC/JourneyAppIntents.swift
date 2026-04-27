//
//  JourneyAppIntents.swift
//  StoneBC
//
//  System shortcuts for journey-critical actions.
//

import AppIntents
import Foundation

enum JourneyShortcutDestination: String, AppEnum {
    case journeyConsole
    case offlineReadiness
    case rallyRadio
    case recording

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Journey Destination")

    static var caseDisplayRepresentations: [JourneyShortcutDestination: DisplayRepresentation] = [
        .journeyConsole: DisplayRepresentation(title: "Journey Console"),
        .offlineReadiness: DisplayRepresentation(title: "Offline Readiness"),
        .rallyRadio: DisplayRepresentation(title: "Rally Radio"),
        .recording: DisplayRepresentation(title: "Recording")
    ]
}

struct OpenJourneyDestinationIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Journey Tool"
    static var description = IntentDescription("Open a journey-critical StoneBC tool.")
    static var openAppWhenRun = true

    @Parameter(title: "Destination")
    var destination: JourneyShortcutDestination

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$destination)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(destination.rawValue, forKey: "pendingJourneyShortcutDestination")
        return .result()
    }
}

struct JourneyCheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "Journey Check In"
    static var description = IntentDescription("Confirm you are OK and refresh the local journey check-in timer.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        EmergencySafetyService.shared.checkIn()
        return .result(dialog: "Checked in for the current journey.")
    }
}

struct StartJourneyIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Journey"
    static var description = IntentDescription("Open StoneBC to start or review a local journey.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(JourneyShortcutDestination.journeyConsole.rawValue, forKey: "pendingJourneyShortcutDestination")
        return .result()
    }
}

struct CaptureJourneyHazardIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture Journey Hazard"
    static var description = IntentDescription("Open StoneBC so you can capture a hazard or field note.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set("hazard", forKey: "pendingJourneyCaptureMode")
        return .result()
    }
}

struct StoneBCJourneyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartJourneyIntent(),
            phrases: [
                "Start a journey in \(.applicationName)",
                "Open Journey Console in \(.applicationName)"
            ],
            shortTitle: "Start Journey",
            systemImageName: "map.fill"
        )
        AppShortcut(
            intent: JourneyCheckInIntent(),
            phrases: [
                "Check in with \(.applicationName)",
                "Journey check in with \(.applicationName)"
            ],
            shortTitle: "Check In",
            systemImageName: "checkmark.seal.fill"
        )
        AppShortcut(
            intent: OpenJourneyDestinationIntent(),
            phrases: [
                "Open \(\.$destination) in \(.applicationName)"
            ],
            shortTitle: "Open Journey Tool",
            systemImageName: "square.grid.2x2"
        )
        AppShortcut(
            intent: CaptureJourneyHazardIntent(),
            phrases: [
                "Capture a hazard in \(.applicationName)"
            ],
            shortTitle: "Capture Hazard",
            systemImageName: "exclamationmark.triangle.fill"
        )
    }
}
