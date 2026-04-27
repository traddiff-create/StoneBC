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
//  by `Scripts/build_tile_pack.py`). If that manifest is missing, runtime
//  coverage checks report false so the HUD never claims offline basemap
//  coverage before real tiles ship.
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

    /// Intended statewide coverage bbox for the SD offline map pack. Runtime
    /// `contains` calls still require a bundled `tile_coverage.json` manifest.
    private static let fallbackBbox = Bbox(
        minLat: 42.45,
        maxLat: 45.96,
        minLon: -104.10,
        maxLon: -96.40,
        minZoom: 11,
        maxZoom: 14,
        attribution: "USFS Topo (public domain) · OSM Cycle Map © OpenStreetMap contributors (CC BY-SA)"
    )

    static let hasBundledCoverageManifest: Bool = {
        Bundle.main.url(forResource: "tile_coverage", withExtension: "json") != nil
    }()

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
        guard hasBundledCoverageManifest else { return false }
        return coordinate.latitude >= bbox.minLat
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
