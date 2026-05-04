import XCTest
@testable import StoneBC

final class RideJournalServiceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "RideJournalServiceTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testEmptyDefaults_journalsStartsEmpty() {
        let service = RideJournalService(defaults: defaults, key: "test")
        XCTAssertTrue(service.journals.isEmpty)
    }

    func testSave_persistsAcrossReinit() {
        let service1 = RideJournalService(defaults: defaults, key: "test")
        service1.save(RideJournal(rideId: "r1", routeName: "Hill Loop"))
        service1.save(RideJournal(rideId: "r2", routeName: "Creek Trail"))

        let service2 = RideJournalService(defaults: defaults, key: "test")
        XCTAssertEqual(service2.journals.map(\.rideId), ["r2", "r1"])
        XCTAssertEqual(service2.journals.first?.routeName, "Creek Trail")
    }

    func testDelete_removesAndPersists() {
        let service1 = RideJournalService(defaults: defaults, key: "test")
        let keep = RideJournal(rideId: "r1", routeName: "Keep")
        let drop = RideJournal(rideId: "r2", routeName: "Drop")
        service1.save(keep)
        service1.save(drop)

        service1.delete(drop)
        XCTAssertEqual(service1.journals.map(\.rideId), ["r1"])

        let service2 = RideJournalService(defaults: defaults, key: "test")
        XCTAssertEqual(service2.journals.map(\.rideId), ["r1"])
    }
}
