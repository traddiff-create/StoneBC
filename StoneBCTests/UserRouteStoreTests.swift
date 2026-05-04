import XCTest
@testable import StoneBC

final class UserRouteStoreTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("UserRouteStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    // MARK: - Init

    func testInitFromEmptyDirectory_hasNoRoutes() {
        let store = UserRouteStore(documentsDirectory: tempDir)
        XCTAssertTrue(store.routes.isEmpty)
    }

    func testInitFromCorruptJSON_doesNotCrash_andLeavesRoutesEmpty() throws {
        let url = tempDir.appendingPathComponent("userRoutes.json")
        try Data("not valid json".utf8).write(to: url)

        let store = UserRouteStore(documentsDirectory: tempDir)
        XCTAssertTrue(store.routes.isEmpty)
    }

    // MARK: - Save

    func testSave_insertsRouteAtTop() {
        let store = UserRouteStore(documentsDirectory: tempDir)
        store.save(makeRoute(id: "a", name: "First"))
        store.save(makeRoute(id: "b", name: "Second"))

        XCTAssertEqual(store.routes.map(\.id), ["b", "a"])
    }

    func testSave_persistsAcrossReloads() {
        let store1 = UserRouteStore(documentsDirectory: tempDir)
        store1.save(makeRoute(id: "a", name: "First"))
        store1.save(makeRoute(id: "b", name: "Second"))

        let store2 = UserRouteStore(documentsDirectory: tempDir)
        XCTAssertEqual(store2.routes.map(\.id), ["b", "a"])
        XCTAssertEqual(store2.routes.first?.name, "Second")
    }

    func testSave_writesAtomically_toUserRoutesJSON() throws {
        let store = UserRouteStore(documentsDirectory: tempDir)
        store.save(makeRoute(id: "x", name: "X"))

        let url = tempDir.appendingPathComponent("userRoutes.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([Route].self, from: data)
        XCTAssertEqual(decoded.map(\.id), ["x"])
    }

    // MARK: - ReplaceAll

    func testReplaceAll_overwritesAllRoutes_andPersists() {
        let store1 = UserRouteStore(documentsDirectory: tempDir)
        store1.save(makeRoute(id: "a", name: "A"))
        store1.save(makeRoute(id: "b", name: "B"))

        store1.replaceAll([makeRoute(id: "c", name: "C")])

        XCTAssertEqual(store1.routes.map(\.id), ["c"])

        let store2 = UserRouteStore(documentsDirectory: tempDir)
        XCTAssertEqual(store2.routes.map(\.id), ["c"])
    }

    // MARK: - Delete

    func testDelete_removesById_andPersists() {
        let store1 = UserRouteStore(documentsDirectory: tempDir)
        store1.save(makeRoute(id: "a", name: "A"))
        store1.save(makeRoute(id: "b", name: "B"))

        store1.delete(id: "a")

        XCTAssertEqual(store1.routes.map(\.id), ["b"])

        let store2 = UserRouteStore(documentsDirectory: tempDir)
        XCTAssertEqual(store2.routes.map(\.id), ["b"])
    }

    func testDelete_unknownId_isNoOp() {
        let store = UserRouteStore(documentsDirectory: tempDir)
        store.save(makeRoute(id: "a", name: "A"))

        store.delete(id: "nonexistent")

        XCTAssertEqual(store.routes.map(\.id), ["a"])
    }

    // MARK: - mergeMigratedRoutes

    func testMergeMigratedRoutes_appendsOnlyUnknownIds() {
        let store = UserRouteStore(documentsDirectory: tempDir)
        store.save(makeRoute(id: "a", name: "A"))

        store.mergeMigratedRoutes([
            makeRoute(id: "a", name: "duplicate of A"),
            makeRoute(id: "b", name: "B"),
            makeRoute(id: "c", name: "C")
        ])

        // "a" is preserved, "b" and "c" appended (not inserted at top).
        XCTAssertEqual(store.routes.map(\.id), ["a", "b", "c"])
    }

    func testMergeMigratedRoutes_emptyMigrated_isNoOp() {
        let store = UserRouteStore(documentsDirectory: tempDir)
        store.save(makeRoute(id: "a", name: "A"))

        store.mergeMigratedRoutes([])

        XCTAssertEqual(store.routes.map(\.id), ["a"])
    }

    func testMergeMigratedRoutes_allDuplicates_isNoOp_andSkipsPersist() throws {
        let store = UserRouteStore(documentsDirectory: tempDir)
        store.save(makeRoute(id: "a", name: "A"))

        // Snapshot file mtime, then merge only-duplicates, then re-check mtime.
        let url = tempDir.appendingPathComponent("userRoutes.json")
        let before = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date

        // Sleep a beat so any rewrite would produce a measurably different mtime.
        Thread.sleep(forTimeInterval: 0.05)

        store.mergeMigratedRoutes([makeRoute(id: "a", name: "duplicate")])

        let after = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        XCTAssertEqual(before, after, "persist() should be skipped when no new routes were merged")
        XCTAssertEqual(store.routes.map(\.id), ["a"])
    }

    // MARK: - Helpers

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
            ],
            isImported: true
        )
    }
}
