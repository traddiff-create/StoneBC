//
//  OfflineTileCoverage.swift
//  StoneBC
//
//  Static lookup for "is this lat/lon inside the bundled tile pack?" Used
//  by `OfflineRouteStorage` to set `tilesAvailable` on cache entries and by
//  `RouteNavigationView` to drive the offline-pill HUD when the rider leaves
//  the covered region.
//
//  Coverage bbox is loaded from `Resources/tiles/tile_coverage.json` (emitted
//  by `Scripts/build_tile_pack.py`). Falls back to a hard-coded Black Hills
//  + foothills bbox if the JSON is missing — meaningful for early
//  dev-builds where the tile pack hasn't been generated yet.
//

import Foundation
import CoreLocation

enum OfflineTileCoverage {
    struct Bbox: Codable {
        let minLat: Double
        let maxLat: Double
        let minLon: Double
        let maxLon: Double
        let minZoom: Int
        let maxZoom: Int
        let attribution: String
    }

    /// Coverage bbox — Black Hills + foothills, USFS topo + OSM Cycle hybrid.
    /// Fallback used until `Resources/tiles/tile_coverage.json` ships in the
    /// app bundle. Same shape; the script overwrites with real values.
    private static let fallbackBbox = Bbox(
        minLat: 43.30,   // Wind Cave / southern Custer SP
        maxLat: 44.85,   // Belle Fourche / Sturgis / Spearfish Canyon
        minLon: -104.20, // Wyoming line
        maxLon: -102.85, // Rapid City / Box Elder
        minZoom: 11,
        maxZoom: 14,
        attribution: "USFS Topo (public domain) · OSM Cycle Map © OpenStreetMap contributors (CC BY-SA)"
    )

    static let bbox: Bbox = {
        if let url = Bundle.main.url(forResource: "tile_coverage", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let parsed = try? JSONDecoder().decode(Bbox.self, from: data) {
            return parsed
        }
        return fallbackBbox
    }()

    static var attributionString: String { bbox.attribution }

    /// Is this coordinate inside the bundled tile pack?
    static func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude >= bbox.minLat
            && coordinate.latitude <= bbox.maxLat
            && coordinate.longitude >= bbox.minLon
            && coordinate.longitude <= bbox.maxLon
    }

    /// Is the route's bbox entirely inside the bundled tile pack?
    static func contains(route: Route) -> Bool {
        let coords = route.clTrackpoints
        guard !coords.isEmpty else { return false }
        return coords.allSatisfy { contains(coordinate: $0) }
    }
}
