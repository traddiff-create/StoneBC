//
//  RideMapTileOverlay.swift
//  StoneBC
//
//  `MKTileOverlay` subclasses that read raster tiles from the bundled
//  Resources/tiles/ directory rather than a remote URL. When a tile is
//  missing (rider outside the Black Hills + foothills coverage region) we
//  return `nil`, letting MapKit fall through to the Apple basemap when
//  online. When offline, missing tiles render as the system blank — the
//  navigation HUD still shows the route polyline + breadcrumb + cue sheet
//  on top, so the rider isn't blind.
//
//  Two layers compose to a "topo + cycle" rendering:
//    USFSTileOverlay  — `canReplaceMapContent = true`, base topographic raster.
//    OSMCycleTileOverlay — `canReplaceMapContent = false`, translucent cycle
//                           styling (route shields, surface hints, cycle
//                           network) layered on top.
//

import MapKit
import Foundation

/// Base type — handles file-URL lookup so the two layered providers stay tiny.
class BundledTileOverlay: MKTileOverlay {
    /// Subdirectory under `Resources/tiles/` — `usfs` or `osm`.
    let provider: String

    init(provider: String) {
        self.provider = provider
        super.init(urlTemplate: nil)
        self.tileSize = CGSize(width: 256, height: 256)
        self.minimumZ = OfflineTileCoverage.bbox.minZoom
        self.maximumZ = OfflineTileCoverage.bbox.maxZoom
    }

    override func loadTile(at path: MKTileOverlayPath,
                           result: @escaping (Data?, Error?) -> Void) {
        let resourcePath = "tiles/\(provider)/\(path.z)/\(path.x)/\(path.y)"
        guard let url = Bundle.main.url(forResource: resourcePath, withExtension: "png"),
              let data = try? Data(contentsOf: url) else {
            // Outside the bundled region (or pack not yet built) — let MapKit
            // fall through to the next overlay or the Apple basemap.
            result(nil, nil)
            return
        }
        result(data, nil)
    }
}

/// USFS topo base layer — public domain. Replaces map content when online so
/// the rider sees consistent topography rather than the Apple basemap shifting
/// in/out of cell range.
final class USFSTileOverlay: BundledTileOverlay {
    init() {
        super.init(provider: "usfs")
        self.canReplaceMapContent = true
    }
}

/// OSM Cycle Map overlay — CC BY-SA, attribution required (rendered in About
/// screen). Sits on top of the USFS base at reduced alpha for cycle-specific
/// styling cues without obscuring contour lines.
final class OSMCycleTileOverlay: BundledTileOverlay {
    init() {
        super.init(provider: "osm")
        self.canReplaceMapContent = false
    }
}

final class DownloadedRouteTileOverlay: MKTileOverlay {
    let tilePack: OfflineTilePackInfo
    private let packDirectory: URL

    init(tilePack: OfflineTilePackInfo) {
        self.tilePack = tilePack
        self.packDirectory = OfflineTilePackManager.packDirectory(
            routeId: tilePack.routeId,
            sourceId: tilePack.sourceId
        )
        super.init(urlTemplate: nil)
        self.tileSize = CGSize(width: tilePack.source.tileSize, height: tilePack.source.tileSize)
        self.minimumZ = tilePack.minZoom
        self.maximumZ = tilePack.maxZoom
        self.canReplaceMapContent = tilePack.source.canReplaceMapContent
    }

    override func loadTile(at path: MKTileOverlayPath,
                           result: @escaping (Data?, Error?) -> Void) {
        let url = packDirectory
            .appendingPathComponent("\(path.z)", isDirectory: true)
            .appendingPathComponent("\(path.x)", isDirectory: true)
            .appendingPathComponent("\(path.y).png")
        guard let data = try? Data(contentsOf: url) else {
            result(nil, nil)
            return
        }
        result(data, nil)
    }
}
