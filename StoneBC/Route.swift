//
//  Route.swift
//  StoneBC
//
//  Cycling route model with GPS trackpoints for map display
//

import Foundation
import CoreLocation

struct Route: Identifiable, Codable {
    let id: String
    let name: String
    let difficulty: String          // easy, moderate, hard, expert
    let category: String            // road, gravel, fatbike, trail
    let distanceMiles: Double
    let elevationGainFeet: Int
    let region: String
    let description: String
    let startCoordinate: Coordinate
    let trackpoints: [[Double]]     // [[lat, lon, ele], ...]
    let cuePoints: [CuePoint]
    let gpxURL: String?             // Public URL for gpx.studio embed
    var isImported: Bool

    struct Coordinate: Codable, Hashable {
        let latitude: Double
        let longitude: Double
    }

    struct CuePoint: Codable, Identifiable, Hashable {
        let id: String
        let name: String
        let description: String?
        let coordinate: Coordinate

        init(id: String = UUID().uuidString,
             name: String,
             description: String? = nil,
             coordinate: Coordinate) {
            self.id = id
            self.name = name
            self.description = description
            self.coordinate = coordinate
        }

        var clCoordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        difficulty = try container.decode(String.self, forKey: .difficulty)
        category = try container.decode(String.self, forKey: .category)
        distanceMiles = try container.decode(Double.self, forKey: .distanceMiles)
        elevationGainFeet = try container.decode(Int.self, forKey: .elevationGainFeet)
        region = try container.decode(String.self, forKey: .region)
        description = try container.decode(String.self, forKey: .description)
        startCoordinate = try container.decode(Coordinate.self, forKey: .startCoordinate)
        trackpoints = try container.decode([[Double]].self, forKey: .trackpoints)
        cuePoints = try container.decodeIfPresent([CuePoint].self, forKey: .cuePoints) ?? []
        gpxURL = try container.decodeIfPresent(String.self, forKey: .gpxURL)
        isImported = try container.decodeIfPresent(Bool.self, forKey: .isImported) ?? false
    }

    init(id: String, name: String, difficulty: String, category: String,
         distanceMiles: Double, elevationGainFeet: Int, region: String,
         description: String, startCoordinate: Coordinate, trackpoints: [[Double]],
         cuePoints: [CuePoint] = [], gpxURL: String? = nil, isImported: Bool = false) {
        self.id = id
        self.name = name
        self.difficulty = difficulty
        self.category = category
        self.distanceMiles = distanceMiles
        self.elevationGainFeet = elevationGainFeet
        self.region = region
        self.description = description
        self.startCoordinate = startCoordinate
        self.trackpoints = trackpoints
        self.cuePoints = cuePoints
        self.gpxURL = gpxURL
        self.isImported = isImported
    }
}

// MARK: - Computed Properties
extension Route {
    var clStartCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: startCoordinate.latitude,
            longitude: startCoordinate.longitude
        )
    }

    var clTrackpoints: [CLLocationCoordinate2D] {
        trackpoints.compactMap { pt in
            guard pt.count >= 2 else { return nil }
            let lat = pt[0], lon = pt[1]
            guard (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    var elevations: [Double] {
        trackpoints.compactMap { $0.count > 2 ? $0[2] : nil }
    }

    /// Whether this route has enough data for navigation
    var isNavigable: Bool {
        clTrackpoints.count >= 2
    }

    var formattedDistance: String {
        String(format: "%.1f mi", distanceMiles)
    }

    var formattedElevation: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: elevationGainFeet)) ?? "\(elevationGainFeet)"
        return "\(formatted) ft"
    }

    var minElevation: Double {
        elevations.min() ?? 0
    }

    var maxElevation: Double {
        elevations.max() ?? 0
    }

    var elevationRange: String {
        let minFt = Int(minElevation * 3.28084)
        let maxFt = Int(maxElevation * 3.28084)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let minStr = formatter.string(from: NSNumber(value: minFt)) ?? "\(minFt)"
        let maxStr = formatter.string(from: NSNumber(value: maxFt)) ?? "\(maxFt)"
        return "\(minStr) - \(maxStr) ft"
    }
}

// MARK: - Bundle Loading
extension Route {
    static func loadFromBundle() -> [Route] {
        guard let url = Bundle.main.url(forResource: "routes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([Route].self, from: data)) ?? []
    }
}

// MARK: - Filtering
extension Route {
    static let allDifficulties = ["easy", "moderate", "hard", "expert"]
    static let allCategories = ["road", "gravel", "fatbike", "trail"]
}

// MARK: - GPX Import Factory

extension Route {
    static func fromGPX(
        _ result: GPXResult,
        difficulty: String = "moderate",
        category: String = "gravel",
        region: String = "Imported"
    ) -> Route {
        let trackpoints = result.trackpoints
        let distance = Self.haversineDistance(trackpoints)
        let elevGain = Self.elevationGain(trackpoints)
        let start = trackpoints.first ?? [0, 0]

        return Route(
            id: UUID().uuidString,
            name: result.name ?? "Imported Route",
            difficulty: difficulty,
            category: category,
            distanceMiles: distance,
            elevationGainFeet: elevGain,
            region: region,
            description: result.description ?? "Imported from GPX file",
            startCoordinate: Coordinate(latitude: start[0], longitude: start[1]),
            trackpoints: trackpoints,
            cuePoints: result.cuePoints,
            isImported: true
        )
    }

    /// Haversine total distance in miles
    static func haversineDistance(_ points: [[Double]]) -> Double {
        guard points.count >= 2 else { return 0 }
        var total: Double = 0
        for i in 1..<points.count {
            let lat1 = points[i - 1][0] * .pi / 180
            let lon1 = points[i - 1][1] * .pi / 180
            let lat2 = points[i][0] * .pi / 180
            let lon2 = points[i][1] * .pi / 180
            let dlat = lat2 - lat1
            let dlon = lon2 - lon1
            let a = sin(dlat / 2) * sin(dlat / 2) +
                    cos(lat1) * cos(lat2) * sin(dlon / 2) * sin(dlon / 2)
            let c = 2 * atan2(sqrt(a), sqrt(1 - a))
            total += 3958.8 * c // Earth radius in miles
        }
        return total
    }

    /// Sum of positive elevation changes in feet
    static func elevationGain(_ points: [[Double]]) -> Int {
        var gain: Double = 0
        for i in 1..<points.count {
            guard points[i].count > 2, points[i - 1].count > 2 else { continue }
            let diff = points[i][2] - points[i - 1][2]
            if diff > 0 { gain += diff }
        }
        return Int(gain * 3.28084) // meters to feet
    }
}

// MARK: - Preview Helper
extension Route {
    static let preview = Route(
        id: "preview-route",
        name: "Preview Route",
        difficulty: "moderate",
        category: "gravel",
        distanceMiles: 42.5,
        elevationGainFeet: 3200,
        region: "Black Hills",
        description: "A scenic gravel route through the Black Hills.",
        startCoordinate: Coordinate(latitude: 44.0805, longitude: -103.2310),
        trackpoints: [
            [44.0805, -103.2310, 1000],
            [44.0900, -103.2400, 1100],
            [44.1000, -103.2500, 1200],
            [44.1100, -103.2400, 1050],
            [44.1200, -103.2300, 950]
        ]
    )
}
