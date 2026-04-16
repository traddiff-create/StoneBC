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
    let source: MediaSource
    var isFeatured: Bool

    init(
        text: String? = nil,
        mediaFilename: String? = nil,
        mediaType: MediaType? = nil,
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
                weatherNote: nil
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
