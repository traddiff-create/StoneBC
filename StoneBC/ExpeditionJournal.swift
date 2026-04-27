//
//  ExpeditionJournal.swift
//  StoneBC
//
//  Lewis & Clark-style expedition journal — core data models.
//  One leader curates; all riders contribute media.
//

import Foundation
import CoreLocation

// MARK: - Journal

struct ExpeditionJournal: Codable, Identifiable {
    let id: String                          // "8over7-2026-05-15"
    let guideId: String                     // ties to TourGuide
    let name: String                        // "8 Over 7 — May 2026"
    let leaderName: String
    var status: JournalStatus
    var trackingMode: ExpeditionTrackingMode? = .balanced
    let startDate: Date
    var endDate: Date?
    var days: [JournalDay]
    var contributions: [MediaContribution]
    var coverPhotoId: String?

    var activeDayNumber: Int {
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return min(max(daysSinceStart + 1, 1), days.count)
    }

    var totalEntries: Int {
        days.reduce(0) { $0 + $1.entries.count }
    }

    var totalPhotos: Int {
        days.reduce(0) { $0 + $1.entries.filter { $0.mediaType == .photo }.count }
    }

    var pendingContributions: Int {
        contributions.filter { !$0.approved && !$0.rejected }.count
    }
}

enum JournalStatus: String, Codable {
    case active
    case completed
    case published
}

enum ExpeditionTrackingMode: String, Codable, CaseIterable, Identifiable {
    case highDetail
    case balanced
    case batterySaver
    case checkInOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .highDetail: "High Detail"
        case .balanced: "Balanced"
        case .batterySaver: "Battery Saver"
        case .checkInOnly: "Check-In Only"
        }
    }

    var subtitle: String {
        switch self {
        case .highDetail: "Best GPS detail for short trips"
        case .balanced: "Useful tracks with moderate battery use"
        case .batterySaver: "Sparse updates for long days"
        case .checkInOnly: "Only logs deliberate check-ins"
        }
    }

    var systemImage: String {
        switch self {
        case .highDetail: "scope"
        case .balanced: "location"
        case .batterySaver: "battery.75"
        case .checkInOnly: "mappin.and.ellipse"
        }
    }

    var locationMode: LocationService.TrackingMode {
        switch self {
        case .highDetail: .expeditionHighDetail
        case .balanced: .expeditionBalanced
        case .batterySaver: .expeditionBatterySaver
        case .checkInOnly: .expeditionCheckIn
        }
    }
}

// MARK: - Day

struct JournalDay: Codable, Identifiable {
    var id: String { "day-\(dayNumber)" }
    let dayNumber: Int
    var entries: [JournalEntry]
    var gpxFilename: String?
    var gpxTrackpoints: [[Double]]?         // [[lat, lon, ele], ...] cached from parse
    var summary: String?                    // post-ride narrative
    var actualMiles: Double?
    var actualElevation: Int?
    var weatherNote: String?
    var waterNote: String?
    var foodNote: String?
    var shelterNote: String?
    var sunsetNote: String?

    var photoCount: Int {
        entries.filter { $0.mediaType == .photo }.count
    }

    var audioCount: Int {
        entries.filter { $0.mediaType == .audio }.count
    }

    var videoCount: Int {
        entries.filter { $0.mediaType == .video }.count
    }

    var sortedEntries: [JournalEntry] {
        entries.sorted { $0.timestamp < $1.timestamp }
    }
}

// MARK: - Entry

struct JournalEntry: Codable, Identifiable {
    let id: String
    let timestamp: Date
    let coordinate: [Double]?               // [lat, lon]
    let text: String?                       // narrative, caption, or note
    let mediaFilename: String?              // stored in media/dayN/
    let mediaType: MediaType?
    let momentKind: ExpeditionMomentKind?
    let source: MediaSource
    var isFeatured: Bool

    init(
        text: String? = nil,
        mediaFilename: String? = nil,
        mediaType: MediaType? = nil,
        momentKind: ExpeditionMomentKind? = nil,
        source: MediaSource = .iphone,
        coordinate: CLLocationCoordinate2D? = nil,
        isFeatured: Bool = false
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.coordinate = coordinate.map { [$0.latitude, $0.longitude] }
        self.text = text
        self.mediaFilename = mediaFilename
        self.mediaType = mediaType
        self.momentKind = momentKind
        self.source = source
        self.isFeatured = isFeatured
    }

    var clCoordinate: CLLocationCoordinate2D? {
        guard let coord = coordinate, coord.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: coord[0], longitude: coord[1])
    }

    var isMedia: Bool { mediaFilename != nil }
    var isTextOnly: Bool { mediaFilename == nil && text != nil }
}

enum MediaType: String, Codable {
    case photo
    case audio
    case video
}

enum ExpeditionMomentKind: String, Codable, CaseIterable, Identifiable {
    case checkIn
    case water
    case food
    case shelter
    case sunset
    case weather
    case hazard
    case gear
    case wildlife
    case reflection

    var id: String { rawValue }

    var label: String {
        switch self {
        case .checkIn: "Check-In"
        case .water: "Water"
        case .food: "Food"
        case .shelter: "Shelter"
        case .sunset: "Sunset"
        case .weather: "Weather"
        case .hazard: "Hazard"
        case .gear: "Gear"
        case .wildlife: "Wildlife"
        case .reflection: "Reflection"
        }
    }

    var systemImage: String {
        switch self {
        case .checkIn: "mappin.and.ellipse"
        case .water: "drop"
        case .food: "fork.knife"
        case .shelter: "tent"
        case .sunset: "sunset"
        case .weather: "cloud.sun"
        case .hazard: "exclamationmark.triangle"
        case .gear: "backpack"
        case .wildlife: "binoculars"
        case .reflection: "text.bubble"
        }
    }
}

enum MediaSource: String, Codable {
    case iphone
    case fuji
    case garmin
    case contribution

    var label: String {
        switch self {
        case .iphone: "iPhone"
        case .fuji: "Fuji"
        case .garmin: "Garmin"
        case .contribution: "Contributor"
        }
    }
}

// MARK: - Contribution

struct MediaContribution: Codable, Identifiable {
    let id: String
    let contributorName: String
    let filename: String
    let mediaType: MediaType
    let caption: String?
    let submittedAt: Date
    let dayNumber: Int?
    var approved: Bool
    var rejected: Bool

    init(
        contributorName: String,
        filename: String,
        mediaType: MediaType,
        caption: String? = nil,
        dayNumber: Int? = nil
    ) {
        self.id = UUID().uuidString
        self.contributorName = contributorName
        self.filename = filename
        self.mediaType = mediaType
        self.caption = caption
        self.submittedAt = Date()
        self.dayNumber = dayNumber
        self.approved = false
        self.rejected = false
    }
}

// MARK: - Factory

extension ExpeditionJournal {
    /// Create a new journal from a TourGuide
    static func create(from guide: TourGuide, leaderName: String, startDate: Date) -> ExpeditionJournal {
        let dateStr = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: startDate)
        }()

        let days = (1...guide.totalDays).map { dayNum in
            JournalDay(
                dayNumber: dayNum,
                entries: [],
                gpxFilename: nil,
                gpxTrackpoints: nil,
                summary: nil,
                actualMiles: nil,
                actualElevation: nil,
                weatherNote: nil,
                waterNote: nil,
                foodNote: nil,
                shelterNote: nil,
                sunsetNote: nil
            )
        }

        return ExpeditionJournal(
            id: "\(guide.id)-\(dateStr)",
            guideId: guide.id,
            name: "\(guide.name) — \(dateStr)",
            leaderName: leaderName,
            status: .active,
            startDate: startDate,
            endDate: nil,
            days: days,
            contributions: [],
            coverPhotoId: nil
        )
    }
}
