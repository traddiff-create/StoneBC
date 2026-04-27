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

    enum StopType: String, Codable, Hashable {
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

struct RouteGuidance: Identifiable, Hashable {
    let id: String
    let routeId: String
    let guideName: String
    let dayName: String
    let routeDistanceMiles: Double
    let stops: [RouteGuidedStop]
    let issues: [RouteGuidanceIssue]

    var hasIssues: Bool {
        !issues.isEmpty
    }
}

struct RouteGuidedStop: Identifiable, Hashable {
    let id: String
    let sequence: Int
    let name: String
    let type: TourStop.StopType
    let description: String?
    let context: String?
    let guideMileMarker: Double?
    let routeMile: Double
    let progress: Double
    let distanceFromRouteMiles: Double

    var icon: String {
        switch type {
        case .start: "play.fill"
        case .finish: "flag.fill"
        case .sag, .resupply: "cross.case.fill"
        case .brewery: "mug.fill"
        case .trailhead: "figure.hiking"
        case .pointOfInterest: "star.fill"
        case .water: "drop.fill"
        case .camp: "tent.fill"
        case .safety: "exclamationmark.triangle.fill"
        }
    }
}

struct RouteGuidanceIssue: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let icon: String
}

struct RouteGuidanceProgress: Hashable {
    let completedStops: [RouteGuidedStop]
    let currentStop: RouteGuidedStop?
    let nextStop: RouteGuidedStop?
    let remainingMilesToNext: Double?
    let routeProgress: Double

    var completedCount: Int {
        completedStops.count
    }
}

enum RouteGuidanceResolver {
    static func guidance(for route: Route, guides: [TourGuide]) -> RouteGuidance? {
        guard route.isNavigable else { return nil }

        for guide in guides {
            for day in guide.days where day.resolvedRoute(in: [route])?.id == route.id {
                let routeCoordinates = route.clTrackpoints
                guard routeCoordinates.count >= 2, !day.stops.isEmpty else { continue }

                let cumulativeMiles = cumulativeDistances(for: routeCoordinates)
                let measuredRouteMiles = cumulativeMiles.last ?? route.distanceMiles
                let routeDistanceMiles = max(measuredRouteMiles, route.distanceMiles, 0.1)

                let stops = day.stops.enumerated().compactMap { offset, stop -> RouteGuidedStop? in
                    guard let coordinate = stop.clCoordinate else { return nil }
                    let projection = project(coordinate, onto: routeCoordinates, cumulativeMiles: cumulativeMiles)
                    return RouteGuidedStop(
                        id: "\(route.id)-\(day.dayNumber)-\(offset)-\(stop.id)",
                        sequence: offset + 1,
                        name: stop.name,
                        type: stop.type,
                        description: stop.description,
                        context: stop.beer,
                        guideMileMarker: stop.mileMarker,
                        routeMile: projection.routeMile,
                        progress: min(max(projection.routeMile / routeDistanceMiles, 0), 1),
                        distanceFromRouteMiles: projection.distanceFromRouteMiles
                    )
                }

                guard !stops.isEmpty else { continue }

                return RouteGuidance(
                    id: "\(guide.id)-day-\(day.dayNumber)-\(route.id)",
                    routeId: route.id,
                    guideName: guide.name,
                    dayName: day.name,
                    routeDistanceMiles: routeDistanceMiles,
                    stops: stops,
                    issues: issues(for: route, guide: guide, day: day, stops: stops)
                )
            }
        }

        return nil
    }

    static func progress(for guidance: RouteGuidance, routeProgress: Double) -> RouteGuidanceProgress {
        let normalizedProgress = min(max(routeProgress, 0), 1)
        let completed = guidance.stops.filter { $0.progress <= normalizedProgress + 0.0001 }
        let next = guidance.stops.first { $0.progress > normalizedProgress + 0.0001 }
        let current = completed.last
        let currentMile = normalizedProgress * guidance.routeDistanceMiles
        let remaining = next.map { max(0, $0.routeMile - currentMile) }

        return RouteGuidanceProgress(
            completedStops: completed,
            currentStop: current,
            nextStop: next,
            remainingMilesToNext: remaining,
            routeProgress: normalizedProgress
        )
    }

    private static func issues(
        for route: Route,
        guide: TourGuide,
        day: TourDay,
        stops: [RouteGuidedStop]
    ) -> [RouteGuidanceIssue] {
        var issues: [RouteGuidanceIssue] = []

        if abs(day.totalMiles - route.distanceMiles) > max(0.5, route.distanceMiles * 0.1) {
            issues.append(RouteGuidanceIssue(
                id: "distance-mismatch",
                title: "Guide mileage differs",
                detail: "\(guide.name) day lists \(formatMiles(day.totalMiles)); route data is \(route.formattedDistance). Stop cards use projected route miles.",
                icon: "arrow.left.arrow.right"
            ))
        }

        if route.elevationGainFeet > 500 && day.elevationGain == 0 {
            issues.append(RouteGuidanceIssue(
                id: "elevation-missing",
                title: "Guide elevation is missing",
                detail: "\(guide.name) day lists 0 ft while route data reports \(route.formattedElevation).",
                icon: "arrow.up.right"
            ))
        } else if abs(day.elevationGain - route.elevationGainFeet) > max(250, route.elevationGainFeet / 5) {
            issues.append(RouteGuidanceIssue(
                id: "elevation-mismatch",
                title: "Guide elevation differs",
                detail: "\(guide.name) day lists \(formatFeet(day.elevationGain)); route data reports \(route.formattedElevation).",
                icon: "arrow.up.right"
            ))
        }

        let markerMismatches = stops.filter { stop in
            guard let guideMile = stop.guideMileMarker else { return false }
            return guideMile > route.distanceMiles + 0.25 || abs(guideMile - stop.routeMile) > 0.5
        }
        if !markerMismatches.isEmpty {
            let names = markerMismatches.prefix(3).map(\.name).joined(separator: ", ")
            issues.append(RouteGuidanceIssue(
                id: "stop-marker-mismatch",
                title: "Stop mile markers differ",
                detail: "Guide markers do not match projected route positions for \(names). Progression uses route geometry.",
                icon: "mappin.and.ellipse"
            ))
        }

        if let dayStart = day.clStartCoordinate,
           let routeStart = route.clTrackpoints.first {
            let distance = distanceMiles(dayStart, routeStart)
            if distance > 0.25 {
                issues.append(RouteGuidanceIssue(
                    id: "start-location-mismatch",
                    title: "Start location differs",
                    detail: "Guide starts at \(day.startLocation), about \(formatMiles(distance)) from the route track start.",
                    icon: "location"
                ))
            }
        }

        if route.description.localizedCaseInsensitiveContains("Hanson-Larsen"),
           !day.startLocation.localizedCaseInsensitiveContains("Hanson-Larsen") {
            issues.append(RouteGuidanceIssue(
                id: "description-start-mismatch",
                title: "Route description names another start",
                detail: "Route copy says Hanson-Larsen Memorial Park; guided stops start at \(day.startLocation).",
                icon: "text.quote"
            ))
        }

        if route.description.localizedCaseInsensitiveContains("Knuckle"),
           !stops.contains(where: { $0.name.localizedCaseInsensitiveContains("Knuckle") || ($0.context?.localizedCaseInsensitiveContains("Knuckle") ?? false) }) {
            issues.append(RouteGuidanceIssue(
                id: "missing-described-stop",
                title: "Description mentions a missing stop",
                detail: "Route copy mentions Knuckle, but the matched guide day has no Knuckle stop record.",
                icon: "exclamationmark.triangle"
            ))
        }

        if route.cuePoints.isEmpty {
            issues.append(RouteGuidanceIssue(
                id: "missing-cues",
                title: "No authored cue points",
                detail: "Navigation can still follow the route line; guided stops come from the tour guide data.",
                icon: "arrow.turn.up.right"
            ))
        }

        return issues
    }

    private static func cumulativeDistances(for coordinates: [CLLocationCoordinate2D]) -> [Double] {
        guard !coordinates.isEmpty else { return [] }
        var distances = Array(repeating: 0.0, count: coordinates.count)
        for index in 1..<coordinates.count {
            distances[index] = distances[index - 1] + distanceMiles(coordinates[index - 1], coordinates[index])
        }
        return distances
    }

    private static func project(
        _ coordinate: CLLocationCoordinate2D,
        onto routeCoordinates: [CLLocationCoordinate2D],
        cumulativeMiles: [Double]
    ) -> (routeMile: Double, distanceFromRouteMiles: Double) {
        guard routeCoordinates.count >= 2 else { return (0, 0) }

        var bestRouteMile = 0.0
        var bestDistanceMeters = Double.greatestFiniteMagnitude
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = metersPerDegreeLatitude * cos(coordinate.latitude * .pi / 180)

        for index in 0..<(routeCoordinates.count - 1) {
            let start = routeCoordinates[index]
            let end = routeCoordinates[index + 1]
            let startX = (start.longitude - coordinate.longitude) * metersPerDegreeLongitude
            let startY = (start.latitude - coordinate.latitude) * metersPerDegreeLatitude
            let endX = (end.longitude - coordinate.longitude) * metersPerDegreeLongitude
            let endY = (end.latitude - coordinate.latitude) * metersPerDegreeLatitude
            let deltaX = endX - startX
            let deltaY = endY - startY
            let lengthSquared = deltaX * deltaX + deltaY * deltaY
            let fraction = lengthSquared == 0
                ? 0
                : min(max(((-startX * deltaX) + (-startY * deltaY)) / lengthSquared, 0), 1)
            let projectedX = startX + fraction * deltaX
            let projectedY = startY + fraction * deltaY
            let distanceMeters = sqrt(projectedX * projectedX + projectedY * projectedY)

            if distanceMeters < bestDistanceMeters {
                let segmentMiles = cumulativeMiles[index + 1] - cumulativeMiles[index]
                bestDistanceMeters = distanceMeters
                bestRouteMile = cumulativeMiles[index] + segmentMiles * fraction
            }
        }

        return (bestRouteMile, bestDistanceMeters / 1609.344)
    }

    private static func distanceMiles(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D) -> Double {
        let from = CLLocation(latitude: lhs.latitude, longitude: lhs.longitude)
        let to = CLLocation(latitude: rhs.latitude, longitude: rhs.longitude)
        return from.distance(from: to) / 1609.344
    }

    private static func formatMiles(_ miles: Double) -> String {
        String(format: "%.1f mi", miles)
    }

    private static func formatFeet(_ feet: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: feet)) ?? "\(feet)"
        return "\(formatted) ft"
    }
}
