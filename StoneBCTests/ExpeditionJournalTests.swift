import XCTest
@testable import StoneBC

final class ExpeditionJournalTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ExpeditionJournalTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    // MARK: - JournalEntry pure logic

    func testJournalEntry_isTextOnly_trueForTextWithoutMedia() {
        let entry = JournalEntry(text: "Stopped for water at the spring.")
        XCTAssertTrue(entry.isTextOnly)
        XCTAssertFalse(entry.isMedia)
    }

    func testJournalDay_sortedEntries_returnsByTimestampAscending() {
        // Construct three entries — JournalEntry.init stamps `Date()` so we
        // sleep briefly between to get distinct timestamps in insertion order,
        // then jumble the order before asserting `sortedEntries` reorders.
        let first = JournalEntry(text: "first")
        Thread.sleep(forTimeInterval: 0.01)
        let second = JournalEntry(text: "second")
        Thread.sleep(forTimeInterval: 0.01)
        let third = JournalEntry(text: "third")

        let day = JournalDay(
            dayNumber: 1,
            entries: [third, first, second],
            gpxFilename: nil, gpxTrackpoints: nil, summary: nil,
            actualMiles: nil, actualElevation: nil,
            weatherNote: nil, waterNote: nil, foodNote: nil,
            shelterNote: nil, sunsetNote: nil
        )

        XCTAssertEqual(day.sortedEntries.map(\.text), ["first", "second", "third"])
    }

    // MARK: - ExpeditionStorage round-trip

    func testStorage_saveThenLoad_roundTripsJournalWithISO8601Dates() async throws {
        let storage = ExpeditionStorage(documentsDirectory: tempDir)
        let journal = makeJournal(id: "test-2026-04-30", name: "Round Trip Test")

        await storage.save(journal)

        let result = await storage.load(id: "test-2026-04-30")
        let loaded = try XCTUnwrap(result)
        XCTAssertEqual(loaded.id, journal.id)
        XCTAssertEqual(loaded.name, journal.name)
        XCTAssertEqual(loaded.leaderName, journal.leaderName)
        XCTAssertEqual(loaded.days.count, journal.days.count)
        XCTAssertEqual(loaded.startDate.timeIntervalSinceReferenceDate,
                       journal.startDate.timeIntervalSinceReferenceDate,
                       accuracy: 1.0,
                       "ISO8601 strategy should preserve dates within a second")
    }

    func testStorage_listJournals_sortsByStartDateDescending() async throws {
        let storage = ExpeditionStorage(documentsDirectory: tempDir)
        let now = Date()
        let older = makeJournal(id: "older", name: "Older",
                                startDate: now.addingTimeInterval(-86400 * 7))
        let middle = makeJournal(id: "middle", name: "Middle",
                                 startDate: now.addingTimeInterval(-86400 * 2))
        let newest = makeJournal(id: "newest", name: "Newest", startDate: now)

        // Save out-of-order to confirm ordering is by startDate, not insertion.
        await storage.save(middle)
        await storage.save(older)
        await storage.save(newest)

        let journals = await storage.listJournals()
        XCTAssertEqual(journals.map(\.id), ["newest", "middle", "older"])
    }

    // MARK: - Helpers

    private func makeJournal(
        id: String,
        name: String,
        startDate: Date = Date()
    ) -> ExpeditionJournal {
        let day = JournalDay(
            dayNumber: 1,
            entries: [],
            gpxFilename: nil, gpxTrackpoints: nil, summary: nil,
            actualMiles: nil, actualElevation: nil,
            weatherNote: nil, waterNote: nil, foodNote: nil,
            shelterNote: nil, sunsetNote: nil
        )
        return ExpeditionJournal(
            id: id,
            guideId: "test-guide",
            name: name,
            leaderName: "Test Leader",
            status: .active,
            startDate: startDate,
            endDate: nil,
            days: [day],
            contributions: [],
            coverPhotoId: nil
        )
    }
}
