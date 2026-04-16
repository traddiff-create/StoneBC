//
//  OfflineRouteStorage.swift
//  StoneBC
//
//  Persistent route cache — saves route data, snapshots, and weather
//  to disk so riders can navigate without cellular.
//

import Foundation

actor OfflineRouteStorage {
    static let shared = OfflineRouteStorage()

    private let cacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OfflineRoutes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private let indexFile: URL = {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OfflineRoutes/index.json")
    }()

    // MARK: - Index

    struct CachedRouteEntry: Codable {
        let routeId: String
        let routeName: String
        let cachedAt: Date
        let hasSnapshot: Bool
        let hasWeather: Bool
        let dataSizeBytes: Int
    }

    /// Load the cache index
    func loadIndex() -> [CachedRouteEntry] {
        guard let data = try? Data(contentsOf: indexFile),
              let entries = try? JSONDecoder().decode([CachedRouteEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private func saveIndex(_ entries: [CachedRouteEntry]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(entries) {
            try? data.write(to: indexFile)
        }
    }

    // MARK: - Cache Route

    /// Cache a route's trackpoints for offline navigation
    func cacheRoute(_ route: Route) {
        let routeDir = cacheDir.appendingPathComponent(route.id, isDirectory: true)
        try? FileManager.default.createDirectory(at: routeDir, withIntermediateDirectories: true)

        // Save route data (trackpoints, metadata)
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(route) {
            try? data.write(to: routeDir.appendingPathComponent("route.json"))
        }

        // Update index
        var index = loadIndex()
        index.removeAll { $0.routeId == route.id }

        let dataSize = (try? FileManager.default.attributesOfItem(
            atPath: routeDir.appendingPathComponent("route.json").path
        )[.size] as? Int) ?? 0

        let snapshotExists = FileManager.default.fileExists(
            atPath: snapshotPath(for: route.id).path
        )

        index.append(CachedRouteEntry(
            routeId: route.id,
            routeName: route.name,
            cachedAt: Date(),
            hasSnapshot: snapshotExists,
            hasWeather: false,
            dataSizeBytes: dataSize
        ))

        saveIndex(index)
    }

    /// Cache weather data for a route
    func cacheWeather(_ weather: RouteWeather, routeId: String) {
        let routeDir = cacheDir.appendingPathComponent(routeId, isDirectory: true)
        try? FileManager.default.createDirectory(at: routeDir, withIntermediateDirectories: true)

        // Store weather as simple JSON
        let weatherData: [String: Any] = [
            "temperature": weather.temperature,
            "feelsLike": weather.feelsLike,
            "windSpeedMPH": weather.windSpeedMPH,
            "condition": weather.condition,
            "symbolName": weather.symbolName,
            "cachedAt": ISO8601DateFormatter().string(from: Date())
        ]

        if let data = try? JSONSerialization.data(withJSONObject: weatherData) {
            try? data.write(to: routeDir.appendingPathComponent("weather.json"))
        }

        // Update index
        var index = loadIndex()
        if let idx = index.firstIndex(where: { $0.routeId == routeId }) {
            let entry = index[idx]
            index[idx] = CachedRouteEntry(
                routeId: entry.routeId,
                routeName: entry.routeName,
                cachedAt: entry.cachedAt,
                hasSnapshot: entry.hasSnapshot,
                hasWeather: true,
                dataSizeBytes: entry.dataSizeBytes
            )
            saveIndex(index)
        }
    }

    // MARK: - Retrieve

    /// Check if a route is cached
    func isCached(routeId: String) -> Bool {
        loadIndex().contains { $0.routeId == routeId }
    }

    /// Load a cached route
    func loadCachedRoute(routeId: String) -> Route? {
        let routeFile = cacheDir
            .appendingPathComponent(routeId, isDirectory: true)
            .appendingPathComponent("route.json")

        guard let data = try? Data(contentsOf: routeFile) else { return nil }
        return try? JSONDecoder().decode(Route.self, from: data)
    }

    // MARK: - Eviction

    /// Remove a cached route
    func evict(routeId: String) {
        let routeDir = cacheDir.appendingPathComponent(routeId, isDirectory: true)
        try? FileManager.default.removeItem(at: routeDir)

        // Also remove snapshot
        let snapshot = snapshotPath(for: routeId)
        try? FileManager.default.removeItem(at: snapshot)

        var index = loadIndex()
        index.removeAll { $0.routeId == routeId }
        saveIndex(index)
    }

    /// Total cache size in bytes
    func totalCacheSize() -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: cacheDir,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        var total = 0
        for case let url as URL in enumerator {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += size
        }
        return total
    }

    /// Formatted cache size
    func formattedCacheSize() -> String {
        let bytes = totalCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    // MARK: - Helpers

    private func snapshotPath(for routeId: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RouteSnapshots/\(routeId).png")
    }
}
