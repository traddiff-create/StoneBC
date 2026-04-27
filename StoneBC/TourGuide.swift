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
    let enabledSections: [TourGuideSection]?
    let overlayDefaults: TourGuideOverlayDefaults?
    let stopTags: [String]?
    let gearProfile: String?
    let safetyNotes: [String]?
    let days: [TourDay]

    enum GuideType: String, Codable {
        case event
        case selfGuided

        var displayName: String {
            switch self {
            case .event: "Event"
            case .selfGuided: "Self-guided"
            }
        }

        var icon: String {
            switch self {
            case .event: "calendar.badge.clock"
            case .selfGuided: "figure.outdoor.cycle"
            }
        }
    }
}

enum TourGuideSection: String, Codable, CaseIterable, Identifiable {
    case overview
    case map
    case stops
    case checklist
    case packList
    case journal
    case notes
    case weather
    case safety

    var id: String { rawValue }
}

enum TourGuideOverlay: String, Codable, CaseIterable, Identifiable {
    case stops
    case sag
    case breweries
    case water
    case safety
    case weather
    case cellCoverage
    case mileMarkers
    case offlineStatus

    var id: String { rawValue }

    var label: String {
        switch self {
        case .stops: "Stops"
        case .sag: "Sag"
        case .breweries: "Breweries"
        case .water: "Water"
        case .safety: "Safety"
        case .weather: "Weather"
        case .cellCoverage: "Cell"
        case .mileMarkers: "Miles"
        case .offlineStatus: "Offline"
        }
    }

    var systemImage: String {
        switch self {
        case .stops: "mappin.and.ellipse"
        case .sag: "cross.case"
        case .breweries: "mug"
        case .water: "drop"
        case .safety: "exclamationmark.triangle"
        case .weather: "cloud.sun"
        case .cellCoverage: "antenna.radiowaves.left.and.right"
        case .mileMarkers: "number"
        case .offlineStatus: "icloud.and.arrow.down"
        }
    }
}

struct TourGuideOverlayDefaults: Codable {
    let enabled: [TourGuideOverlay]
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
    let routeId: String?
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
    let tags: [String]?

    enum StopType: String, Codable {
        case sag
        case brewery
        case trailhead
        case pointOfInterest
        case start
        case finish
        case water
        case resupply
        case camp
        case safety
    }
}

extension TourGuide {
    static func loadFromBundle() -> [TourGuide] {
        guard let url = Bundle.main.url(forResource: "guides", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let guides = try? JSONDecoder().decode([TourGuide].self, from: data) else { return [] }
        return guides
    }

    var defaultEnabledSections: Set<TourGuideSection> {
        Set(enabledSections ?? TourGuideSection.allCases)
    }

    var defaultEnabledOverlays: Set<TourGuideOverlay> {
        Set(overlayDefaults?.enabled ?? [.stops, .sag, .breweries, .water, .safety, .mileMarkers, .offlineStatus])
    }
}

extension TourDay {
    var clStartCoordinate: CLLocationCoordinate2D? {
        guard let startCoordinate, startCoordinate.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: startCoordinate[0], longitude: startCoordinate[1])
    }

    func resolvedRoute(in routes: [Route]) -> Route? {
        let candidateIds = [
            routeId,
            routeFile,
            routeFile.map(Self.normalizedRouteKey),
            gpxURL.flatMap(Self.routeKeyFromURL)
        ].compactMap { $0 }

        return routes.first { route in
            candidateIds.contains(route.id) || candidateIds.contains(Self.normalizedRouteKey(route.id))
        }
    }

    private static func normalizedRouteKey(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ".gpx", with: "")
            .replacingOccurrences(of: ".tcx", with: "")
            .replacingOccurrences(of: ".fit", with: "")
    }

    private static func routeKeyFromURL(_ value: String) -> String? {
        guard let lastPathComponent = URL(string: value)?.lastPathComponent, !lastPathComponent.isEmpty else {
            return nil
        }
        return normalizedRouteKey(lastPathComponent)
    }
}

extension TourStop {
    var clCoordinate: CLLocationCoordinate2D? {
        guard coordinate.count >= 2 else { return nil }
        return CLLocationCoordinate2D(latitude: coordinate[0], longitude: coordinate[1])
    }

    var searchableTags: Set<String> {
        Set((tags ?? []) + [type.rawValue])
    }
}
