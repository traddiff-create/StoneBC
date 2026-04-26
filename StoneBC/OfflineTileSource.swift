//
//  OfflineTileSource.swift
//  StoneBC
//
//  Configured raster tile sources for opt-in offline route packs.
//

import Foundation

struct OfflineTileSource: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let attribution: String
    let urlTemplate: String?
    let minZoom: Int
    let maxZoom: Int
    let tileSize: Int
    let maxDownloadBytes: Int
    let licenseNotes: String
    let canReplaceMapContent: Bool
    let overlayAlpha: Double
    let isEnabled: Bool

    init(id: String,
         name: String,
         attribution: String,
         urlTemplate: String?,
         minZoom: Int,
         maxZoom: Int,
         tileSize: Int = 256,
         maxDownloadBytes: Int = 80_000_000,
         licenseNotes: String,
         canReplaceMapContent: Bool = true,
         overlayAlpha: Double = 1.0,
         isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.attribution = attribution
        self.urlTemplate = urlTemplate
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.tileSize = tileSize
        self.maxDownloadBytes = maxDownloadBytes
        self.licenseNotes = licenseNotes
        self.canReplaceMapContent = canReplaceMapContent
        self.overlayAlpha = overlayAlpha
        self.isEnabled = isEnabled
    }

    var isDownloadable: Bool {
        isEnabled && urlTemplate?.isEmpty == false
    }

    func url(for tile: OfflineMapTile) -> URL? {
        guard let urlTemplate, !urlTemplate.isEmpty else { return nil }
        let raw = urlTemplate
            .replacingOccurrences(of: "{z}", with: "\(tile.z)")
            .replacingOccurrences(of: "{x}", with: "\(tile.x)")
            .replacingOccurrences(of: "{y}", with: "\(tile.y)")
        return URL(string: raw)
    }
}

extension OfflineTileSource {
    static func approvedSources() -> [OfflineTileSource] {
        let bundled = sourcesFromConfig() + sourcesFromStandaloneFile()
        return bundled
            .filter(\.isEnabled)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func sourcesFromStandaloneFile() -> [OfflineTileSource] {
        guard let url = Bundle.main.url(forResource: "offline_tile_sources", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([OfflineTileSource].self, from: data)) ?? []
    }

    private static func sourcesFromConfig() -> [OfflineTileSource] {
        guard let url = Bundle.main.url(forResource: "config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawSources = object["offlineTileSources"] else {
            return []
        }

        guard JSONSerialization.isValidJSONObject(rawSources),
              let sourceData = try? JSONSerialization.data(withJSONObject: rawSources) else {
            return []
        }
        return (try? JSONDecoder().decode([OfflineTileSource].self, from: sourceData)) ?? []
    }
}
