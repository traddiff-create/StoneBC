//
//  TourGuide.swift
//  StoneBC
//
//  Data model for multi-day tour guides
//

import Foundation
import CoreLocation

struct TourGuide: Codable, Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let description: String
    let type: GuideType           // "event" or "selfGuided"
    let eventDate: String?        // nil for self-guided
    let totalDays: Int
    let totalMiles: Double
    let totalElevation: Int
    let difficulty: String
    let category: String          // "gravel", "trail", "road", "brewery"
    let region: String
    let notes: [String]
    let checklist: [ChecklistItem]?
    let days: [TourDay]

    enum GuideType: String, Codable {
        case event
        case selfGuided
    }
}

struct TourDay: Codable, Identifiable {
    var id: String { "\(dayNumber)" }
    let dayNumber: Int
    let name: String
    let date: String?             // nil for self-guided
    let startTime: String?
    let startLocation: String
    let startCoordinate: [Double]? // [lat, lon]
    let totalMiles: Double
    let elevationGain: Int
    let estimatedDuration: String?
    let finishLocation: String?
    let routeFile: String?        // e.g. "Brewvet_Southern" — matches bundled trackpoints
    let gpxURL: String?           // Public URL to GPX/TCX file for gpx.studio embed
    let trackpoints: [[Double]]?  // [[lat, lon, ele], ...] — inline or loaded from route
    let stops: [TourStop]
}

struct TourStop: Codable, Identifiable {
    var id: String { "\(type.rawValue)-\(name)" }
    let name: String
    let type: StopType
    let coordinate: [Double]      // [lat, lon]
    let mileMarker: Double?
    let description: String?
    let beer: String?             // brewery/beer at this stop

    enum StopType: String, Codable {
        case sag
        case brewery
        case trailhead
        case pointOfInterest
        case start
        case finish
    }
}

extension TourGuide {
    static func loadFromBundle() -> [TourGuide] {
        guard let url = Bundle.main.url(forResource: "guides", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let guides = try? JSONDecoder().decode([TourGuide].self, from: data) else { return [] }
        return guides
    }
}
