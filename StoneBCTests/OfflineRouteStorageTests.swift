import XCTest
@testable import StoneBC

final class OfflineRouteStorageTests: XCTestCase {
    private var appSupportDir: URL!
    private var cachesDir: URL!
    private var rootDir: URL!

    override func setUpWithError() throws {
        rootDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("OfflineRouteStorageTests-\(UUID().uuidString)", isDirectory: true)
        appSupportDir = rootDir.appendingPathComponent("ApplicationSupport", isDirectory: true)
        cachesDir = rootDir.appendingPathComponent("Caches", isDirectory: true)
        try FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: rootDir)
        rootDir = nil
        appSupportDir = nil
        cachesDir = nil
    }

    // MARK: - cacheRoute

    func testCacheRoute_writesRouteJSON_andCreatesIndexEntry() async throws {
        let storage = makeStorage()
        let route = makeRoute(id: "r1", name: "Route One")

        await storage.cacheRoute(route)

        let entries = await storage.loadIndex()
        XCTAssertEqual(entries.map(\.routeId), ["r1"])
        XCTAssertEqual(entries.first?.routeName, "Route One")
        XCTAssertFalse(entries.first?.hasWeather ?? true)
        XCTAssertFalse(entries.first?.tilesAvailable ?? true)
        XCTAssertGreaterThan(entries.first?.dataSizeBytes ?? 0, 0)

        let routeFile = storageRoot()
            .appendingPathComponent("r1", isDirectory: true)
            .appendingPathComponent("route.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: routeFile.path))
    }

    func testCacheRoute_preservesTilesAvailableFlag() async throws {
        let storage = makeStorage()
        let route = makeRoute(id: "r1", name: "Route One")

        await storage.cacheRoute(route, tilesAvailable: true)

        let entries = await storage.loadIndex()
        XCTAssertEqual(entries.first?.tilesAvailable, true)
    }

    func testCacheRoute_replacesExistingEntry_forSameId() async throws {
        let storage = makeStorage()
        await storage.cacheRoute(makeRoute(id: "r1", name: "Original"))
        await storage.cacheRoute(makeRoute(id: "r1", name: "Renamed"), tilesAvailable: true)

        let entries = await storage.loadIndex()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.routeName, "Renamed")
        XCTAssertEqual(entries.first?.tilesAvailable, true)
    }

    func testCacheRoute_snapshotOverride_setsHasSnapshotTrue() async throws {
        let storage = makeStorage()
        await storage.cacheRoute(makeRoute(id: "r1", name: "R1"), hasSnapshot: true)

        let entries = await storage.loadIndex()
        XCTAssertEqual(entries.first?.hasSnapshot, true)
    }

    // MARK: - cacheWeather

    func testCacheWeather_marksHasWeatherTrue_andPreservesTilesAvailable() async throws {
        let storage = makeStorage()
        await storage.cacheRoute(makeRoute(id: "r1", name: "R1"), tilesAvailable: true)

        await storage.cacheWeather(makeWeather(), routeId: "r1")

        let entries = await storage.loadIndex()
        XCTAssertEqual(entries.first?.hasWeather, true)
        XCTAssertEqual(entries.first?.tilesAvailable, true, "tilesAvailable must survive a weather update")
    }

    func testCacheWeather_forUnknownRoute_doesNotCreateIndexEntry() async throws {
        let storage = makeStorage()
        await storage.cacheWeather(makeWeather(), routeId: "ghost")

        let entries = await storage.loadIndex()
        XCTAssertTrue(entries.isEmpty)
    }

    // MARK: - isCached / loadCachedRoute

    func testIsCached_returnsExpectedValues() async throws {
        let storage = makeStorage()
        let cachedBefore = await storage.isCached(routeId: "r1")
        XCTAssertFalse(cachedBefore)

        await storage.cacheRoute(makeRoute(id: "r1", name: "R1"))

        let cachedAfter = await storage.isCached(routeId: "r1")
        XCTAssertTrue(cachedAfter)
    }

    func testLoadCachedRoute_returnsRoundTrippedRoute() async throws {
        let storage = makeStorage()
        let original = makeRoute(id: "r1", name: "R1")
        await storage.cacheRoute(original)

        let loaded = await storage.loadCachedRoute(routeId: "r1")

        XCTAssertEqual(loaded?.id, original.id)
        XCTAssertEqual(loaded?.name, original.name)
        XCTAssertEqual(loaded?.trackpoints.count, original.trackpoints.count)
    }

    func testLoadCachedRoute_unknownId_returnsNil() async throws {
        let storage = makeStorage()
        let loaded = await storage.loadCachedRoute(routeId: "ghost")
        XCTAssertNil(loaded)
    }

    // MARK: - evict

    func testEvict_removesIndexEntry_andRouteJSON() async throws {
        let storage = makeStorage()
        await storage.cacheRoute(makeRoute(id: "r1", name: "R1"))
        await storage.cacheRoute(makeRoute(id: "r2", name: "R2"))

        await storage.evict(routeId: "r1")

        let entries = await storage.loadIndex()
        XCTAssertEqual(entries.map(\.routeId), ["r2"])

        let removedFile = storageRoot()
            .appendingPathComponent("r1", isDirectory: true)
            .appendingPathComponent("route.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: removedFile.path))
    }

    // MARK: - totalCacheSize

    func testTotalCacheSize_isPositive_afterCaching() async throws {
        let storage = makeStorage()
        await storage.cacheRoute(makeRoute(id: "r1", name: "R1"))

        let size = await storage.totalCacheSize()
        XCTAssertGreaterThan(size, 0)
    }

    // MARK: - Legacy index decoding

    func testLoadIndex_decodesLegacyEntryWithoutTilesAvailable_asFalse() async throws {
        // Hand-craft a legacy index.json without the `tilesAvailable` field.
        let dir = storageRoot()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let legacyJSON = """
        [{
          "routeId": "legacy-1",
          "routeName": "Legacy Route",
          "cachedAt": 770000000,
          "hasSnapshot": false,
          "hasWeather": false,
          "dataSizeBytes": 1234
        }]
        """
        try Data(legacyJSON.utf8).write(to: dir.appendingPathComponent("index.json"))

        let storage = makeStorage()
        let entries = await storage.loadIndex()

        XCTAssertEqual(entries.first?.routeId, "legacy-1")
        XCTAssertEqual(entries.first?.tilesAvailable, false,
                       "Missing tilesAvailable must default to false to keep legacy caches loadable")
    }

    // MARK: - Helpers

    private func makeStorage() -> OfflineRouteStorage {
        OfflineRouteStorage(
            applicationSupportDirectory: appSupportDir,
            cachesDirectory: cachesDir
        )
    }

    private func storageRoot() -> URL {
        appSupportDir
            .appendingPathComponent("StoneBC", isDirectory: true)
            .appendingPathComponent("OfflineRoutes", isDirectory: true)
    }

    private func makeRoute(id: String, name: String) -> Route {
        Route(
            id: id,
            name: name,
            difficulty: "moderate",
            category: "gravel",
            distanceMiles: 10.0,
            elevationGainFeet: 500,
            region: "Test",
            description: "Test route",
            startCoordinate: .init(latitude: 44.0, longitude: -103.0),
            trackpoints: [
                [44.0, -103.0, 1000],
                [44.001, -103.001, 1010],
                [44.002, -103.002, 1020]
            ]
        )
    }

    private func makeWeather() -> RouteWeather {
        RouteWeather(
            temperature: 65,
            feelsLike: 64,
            humidity: 50,
            windSpeedMPH: 5,
            windDirection: 180,
            windGustMPH: nil,
            condition: "Partly Cloudy",
            symbolName: "cloud.sun",
            uvIndex: 3,
            precipitationChance: 0.1,
            sunriseToday: nil,
            sunsetToday: nil,
            sunriseTomorrow: nil,
            hourlyForecast: []
        )
    }
}
