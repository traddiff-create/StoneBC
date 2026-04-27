//
//  Journey.swift
//  StoneBC
//
//  Local-first expedition journey models.
//

import Foundation

enum JourneyPowerProfile: String, Codable, CaseIterable, Identifiable {
    case highDetail
    case balanced
    case endurance
    case checkInOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .highDetail: "High Detail"
        case .balanced: "Balanced"
        case .endurance: "Endurance"
        case .checkInOnly: "Check-In Only"
        }
    }

    var subtitle: String {
        switch self {
        case .highDetail: "Best GPS detail for short exposed sections"
        case .balanced: "Default mix of accuracy and battery life"
        case .endurance: "Long-day tracking with lower sensor cadence"
        case .checkInOnly: "Manual status points for maximum battery"
        }
    }

    var ridePowerMode: RidePowerMode {
        switch self {
        case .highDetail: .highDetail
        case .balanced: .balanced
        case .endurance, .checkInOnly: .endurance
        }
    }
}

enum JourneyReadinessState: String, Codable {
    case ready
    case warning
    case blocked

    var label: String {
        switch self {
        case .ready: "Ready"
        case .warning: "Check"
        case .blocked: "Blocked"
        }
    }
}

struct JourneyCheckInPolicy: Codable, Hashable {
    var intervalMinutes: Int
    var localNotificationsEnabled: Bool

    static let `default` = JourneyCheckInPolicy(
        intervalMinutes: 30,
        localNotificationsEnabled: true
    )
}

struct JourneyReadinessItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let detail: String
    let state: JourneyReadinessState
    let icon: String
}

struct JourneyReadiness: Codable, Hashable {
    let routeId: String?
    let generatedAt: Date
    let items: [JourneyReadinessItem]

    var readyCount: Int { items.filter { $0.state == .ready }.count }
    var blockerCount: Int { items.filter { $0.state == .blocked }.count }
    var warningCount: Int { items.filter { $0.state == .warning }.count }

    var score: Int {
        guard !items.isEmpty else { return 0 }
        let raw = Double(readyCount) / Double(items.count) * 100
        return Int(raw.rounded())
    }

    var statusLabel: String {
        if blockerCount > 0 { return "Needs attention" }
        if warningCount > 0 { return "Mostly ready" }
        return "Ready"
    }
}

struct JourneyDayReview: Codable, Identifiable, Hashable {
    let id: String
    let createdAt: Date
    var dayNumber: Int?
    var routeId: String?
    var rideId: String?
    var summary: String
    var hazards: String
    var waterNotes: String
    var resupplyNotes: String

    init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        dayNumber: Int? = nil,
        routeId: String? = nil,
        rideId: String? = nil,
        summary: String = "",
        hazards: String = "",
        waterNotes: String = "",
        resupplyNotes: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.dayNumber = dayNumber
        self.routeId = routeId
        self.rideId = rideId
        self.summary = summary
        self.hazards = hazards
        self.waterNotes = waterNotes
        self.resupplyNotes = resupplyNotes
    }
}

struct JourneySession: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var routeId: String?
    var routeName: String?
    var guideId: String?
    var guideName: String?
    var journalId: String?
    var journalName: String?
    var startedAt: Date
    var powerProfile: JourneyPowerProfile
    var checkInPolicy: JourneyCheckInPolicy
    var lastKnownLatitude: Double?
    var lastKnownLongitude: Double?
    var lastKnownLocationAt: Date?
    var dayReviews: [JourneyDayReview]

    init(
        id: String = UUID().uuidString,
        title: String,
        routeId: String? = nil,
        routeName: String? = nil,
        guideId: String? = nil,
        guideName: String? = nil,
        journalId: String? = nil,
        journalName: String? = nil,
        startedAt: Date = Date(),
        powerProfile: JourneyPowerProfile = .endurance,
        checkInPolicy: JourneyCheckInPolicy = .default,
        dayReviews: [JourneyDayReview] = []
    ) {
        self.id = id
        self.title = title
        self.routeId = routeId
        self.routeName = routeName
        self.guideId = guideId
        self.guideName = guideName
        self.journalId = journalId
        self.journalName = journalName
        self.startedAt = startedAt
        self.powerProfile = powerProfile
        self.checkInPolicy = checkInPolicy
        self.dayReviews = dayReviews
    }
}
