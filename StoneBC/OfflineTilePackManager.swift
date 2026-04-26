//
//  OfflineTilePackManager.swift
//  StoneBC
//
//  Downloads and manages per-route raster tile packs in Application Support.
//

import Foundation
import CoreLocation

struct OfflineTileBounds: Codable, Hashable, Sendable {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double

    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude >= minLat
            && coordinate.latitude <= maxLat
            && coordinate.longitude >= minLon
            && coordinate.longitude <= maxLon
    }
}

struct OfflineMapTile: Codable, Hashable, Sendable {
    let z: Int
    let x: Int
    let y: Int
}

struct OfflineTileDownloadProgress: Equatable, Sendable {
    let completedTiles: Int
    let totalTiles: Int
    let bytesDownloaded: Int

    var fractionCompleted: Double {
        guard totalTiles > 0 else { return 0 }
        return Double(completedTiles) / Double(totalTiles)
    }

    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesDownloaded), countStyle: .file)
    }
}

struct OfflineTilePackInfo: Codable, Hashable, Sendable {
    let routeId: String
    let routeName: String
    let source: OfflineTileSource
    let bounds: OfflineTileBounds
    let minZoom: Int
    let maxZoom: Int
    let tileCount: Int
    let sizeBytes: Int
    let downloadedAt: Date

    var sourceId: String { source.id }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }
}

enum OfflineTilePackError: LocalizedError {
    case noApprovedTileSource
    case invalidRouteBounds
    case invalidURL
    case serverStatus(Int)
    case exceedsSizeLimit(Int)

    var errorDescription: String? {
        switch self {
        case .noApprovedTileSource:
            return "No approved offline tile source is configured."
        case .invalidRouteBounds:
            return "This route does not have enough map data to download tiles."
        case .invalidURL:
            return "The configured tile source URL is invalid."
        case .serverStatus(let status):
            return "Tile server returned HTTP \(status)."
        case .exceedsSizeLimit(let limit):
            let formatted = ByteCountFormatter.string(fromByteCount: Int64(limit), countStyle: .file)
            return "Tile pack exceeded the configured \(formatted) limit."
        }
    }
}

actor OfflineTilePackManager {
    static let shared = OfflineTilePackManager()

    private let fileManager = FileManager.default
    private let packsRoot: URL
    private let downloadsRoot: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StoneBC", isDirectory: true)
        packsRoot = appSupport.appendingPathComponent("OfflineTilePacks", isDirectory: true)
        downloadsRoot = packsRoot.appendingPathComponent(".downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: downloadsRoot, withIntermediateDirectories: true)
    }

    func approvedSources() -> [OfflineTileSource] {
        OfflineTileSource.approvedSources()
    }

    func installedPack(forRouteId routeId: String, sourceId: String? = nil) -> OfflineTilePackInfo? {
        Self.installedPackSync(forRouteId: routeId, sourceId: sourceId)
    }

    func deletePack(routeId: String, sourceId: String) {
        let dir = Self.packDirectory(routeId: routeId, sourceId: sourceId)
        try? fileManager.removeItem(at: dir)
    }

    func downloadPack(
        for route: Route,
        source: OfflineTileSource,
        progress: @escaping @Sendable (OfflineTileDownloadProgress) async -> Void
    ) async throws -> OfflineTilePackInfo {
        guard source.isDownloadable else { throw OfflineTilePackError.noApprovedTileSource }
        let bounds = try Self.bounds(for: route)
        let tiles = Self.tiles(for: bounds, minZoom: source.minZoom, maxZoom: source.maxZoom)
        guard !tiles.isEmpty else { throw OfflineTilePackError.invalidRouteBounds }

        let tempDir = downloadsRoot
            .appendingPathComponent("\(route.id)-\(source.id)-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var completed = 0
        var totalBytes = 0

        do {
            for tile in tiles {
                try Task.checkCancellation()
                guard let url = source.url(for: tile) else { throw OfflineTilePackError.invalidURL }

                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    throw OfflineTilePackError.serverStatus(http.statusCode)
                }

                totalBytes += data.count
                if totalBytes > source.maxDownloadBytes {
                    throw OfflineTilePackError.exceedsSizeLimit(source.maxDownloadBytes)
                }

                let tileURL = tempDir
                    .appendingPathComponent("\(tile.z)", isDirectory: true)
                    .appendingPathComponent("\(tile.x)", isDirectory: true)
                    .appendingPathComponent("\(tile.y).png")
                try fileManager.createDirectory(
                    at: tileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: tileURL, options: .atomic)

                completed += 1
                await progress(OfflineTileDownloadProgress(
                    completedTiles: completed,
                    totalTiles: tiles.count,
                    bytesDownloaded: totalBytes
                ))
            }

            let info = OfflineTilePackInfo(
                routeId: route.id,
                routeName: route.name,
                source: source,
                bounds: bounds,
                minZoom: source.minZoom,
                maxZoom: source.maxZoom,
                tileCount: completed,
                sizeBytes: totalBytes,
                downloadedAt: Date()
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let manifest = try encoder.encode(info)
            try manifest.write(to: tempDir.appendingPathComponent(Self.manifestFileName), options: .atomic)

            let finalDir = Self.packDirectory(routeId: route.id, sourceId: source.id)
            try? fileManager.removeItem(at: finalDir)
            try fileManager.createDirectory(at: finalDir.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.moveItem(at: tempDir, to: finalDir)
            return info
        } catch {
            try? fileManager.removeItem(at: tempDir)
            throw error
        }
    }
}

extension OfflineTilePackManager {
    static let manifestFileName = "manifest.json"

    static func packDirectory(routeId: String, sourceId: String) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StoneBC", isDirectory: true)
        return appSupport
            .appendingPathComponent("OfflineTilePacks", isDirectory: true)
            .appendingPathComponent(sanitized(routeId), isDirectory: true)
            .appendingPathComponent(sanitized(sourceId), isDirectory: true)
    }

    static func installedPackSync(forRouteId routeId: String, sourceId: String? = nil) -> OfflineTilePackInfo? {
        let routeDir = packDirectory(routeId: routeId, sourceId: "_")
            .deletingLastPathComponent()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: routeDir,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        let candidates: [URL]
        if let sourceId {
            candidates = [packDirectory(routeId: routeId, sourceId: sourceId)]
        } else {
            candidates = contents
                .filter { $0.hasDirectoryPath }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        for dir in candidates {
            let manifest = dir.appendingPathComponent(manifestFileName)
            guard let data = try? Data(contentsOf: manifest),
                  let info = try? decoder.decode(OfflineTilePackInfo.self, from: data) else {
                continue
            }
            return info
        }
        return nil
    }

    static func bounds(for route: Route) throws -> OfflineTileBounds {
        let coords = route.clTrackpoints
        guard let first = coords.first, coords.count >= 2 else {
            throw OfflineTilePackError.invalidRouteBounds
        }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coord in coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let padding = 0.01
        return OfflineTileBounds(
            minLat: max(minLat - padding, -85.05112878),
            maxLat: min(maxLat + padding, 85.05112878),
            minLon: max(minLon - padding, -180),
            maxLon: min(maxLon + padding, 180)
        )
    }

    static func tiles(for bounds: OfflineTileBounds, minZoom: Int, maxZoom: Int) -> [OfflineMapTile] {
        guard minZoom <= maxZoom else { return [] }
        var tiles: [OfflineMapTile] = []

        for z in minZoom...maxZoom {
            let northwest = tileXY(latitude: bounds.maxLat, longitude: bounds.minLon, zoom: z)
            let southeast = tileXY(latitude: bounds.minLat, longitude: bounds.maxLon, zoom: z)
            let minX = min(northwest.x, southeast.x)
            let maxX = max(northwest.x, southeast.x)
            let minY = min(northwest.y, southeast.y)
            let maxY = max(northwest.y, southeast.y)

            for x in minX...maxX {
                for y in minY...maxY {
                    tiles.append(OfflineMapTile(z: z, x: x, y: y))
                }
            }
        }

        return tiles
    }

    private static func tileXY(latitude: Double, longitude: Double, zoom: Int) -> (x: Int, y: Int) {
        let clampedLat = min(max(latitude, -85.05112878), 85.05112878)
        let latRad = clampedLat * .pi / 180
        let n = pow(2.0, Double(zoom))
        let x = Int(floor((longitude + 180.0) / 360.0 * n))
        let y = Int(floor((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / .pi) / 2.0 * n))
        let maxIndex = Int(n) - 1
        return (min(max(x, 0), maxIndex), min(max(y, 0), maxIndex))
    }

    private static func sanitized(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(scalars)
    }
}
