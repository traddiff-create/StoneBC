import CoreLocation
import XCTest
@testable import StoneBC

final class RideSessionTests: XCTestCase {
    func testJitterFilterIgnoresShortSegments() {
        let session = RideSession()
        let start = Date().addingTimeInterval(-60)

        session.start()
        session.ingestLocation(location(latitude: 44.0, longitude: -103.0, speed: 4, timestamp: start))
        session.ingestLocation(location(latitude: 44.0, longitude: -102.999988, speed: 4, timestamp: start.addingTimeInterval(5)))
        session.ingestLocation(location(latitude: 44.0, longitude: -102.99986, speed: 4, timestamp: start.addingTimeInterval(10)))

        XCTAssertGreaterThan(session.distanceMeters, 5)
        XCTAssertLessThan(session.distanceMeters, 20)
    }

    func testAutoPauseResumeMovingTimeAndPauseEvents() {
        let session = RideSession()
        let start = Date().addingTimeInterval(-60)

        session.start()
        session.ingestLocation(location(latitude: 44.0, longitude: -103.0, speed: 0, timestamp: start))
        session.ingestLocation(location(latitude: 44.0, longitude: -103.0, speed: 0, timestamp: start.addingTimeInterval(8)))

        guard case .paused = session.state else {
            return XCTFail("Expected auto-pause")
        }
        XCTAssertEqual(session.pauseEvents.count, 1)

        session.ingestLocation(location(latitude: 44.0, longitude: -102.99995, speed: 3, timestamp: start.addingTimeInterval(10)))
        session.ingestLocation(location(latitude: 44.0, longitude: -102.99990, speed: 3, timestamp: start.addingTimeInterval(15)))

        guard case .recording = session.state else {
            return XCTFail("Expected auto-resume")
        }
        XCTAssertEqual(session.pauseEvents.count, 2)
        XCTAssertGreaterThan(session.movingSeconds, 0)
    }

    func testAscentUsesDeadband() {
        let session = RideSession()
        let start = Date().addingTimeInterval(-60)

        session.start()
        session.ingestLocation(location(latitude: 44.0, longitude: -103.0, altitude: 100, speed: 5, timestamp: start))
        session.ingestLocation(location(latitude: 44.0, longitude: -102.9999, altitude: 100.5, speed: 5, timestamp: start.addingTimeInterval(5)))
        session.ingestLocation(location(latitude: 44.0, longitude: -102.9998, altitude: 102, speed: 5, timestamp: start.addingTimeInterval(10)))

        XCTAssertGreaterThan(session.totalAscentFeet, RideTuning.ascentDeadbandFeet)
        XCTAssertLessThan(session.totalAscentFeet, 10)
    }

    func testRouteProgressAndOffRouteHysteresis() {
        let route = Route(
            id: "route-1",
            name: "Test Route",
            difficulty: "easy",
            category: "gravel",
            distanceMiles: 0.2,
            elevationGainFeet: 0,
            region: "Test",
            description: "Test",
            startCoordinate: .init(latitude: 44.0, longitude: -103.0),
            trackpoints: [
                [44.0, -103.0, 0],
                [44.0, -102.999, 0],
                [44.0, -102.998, 0]
            ]
        )
        let session = RideSession(route: route)
        let start = Date().addingTimeInterval(-60)

        session.start()
        session.ingestLocation(location(latitude: 44.0, longitude: -102.999, speed: 4, timestamp: start))

        XCTAssertGreaterThan(session.progressPercent, 0.4)
        XCTAssertFalse(session.isOffRoute)

        session.ingestLocation(location(latitude: 44.001, longitude: -102.999, speed: 4, timestamp: start.addingTimeInterval(5)))
        XCTAssertTrue(session.isOffRoute)

        session.ingestLocation(location(latitude: 44.00018, longitude: -102.999, speed: 4, timestamp: start.addingTimeInterval(10)))
        XCTAssertFalse(session.isOffRoute)
    }

    private func location(latitude: Double,
                          longitude: Double,
                          altitude: Double = 0,
                          speed: Double,
                          timestamp: Date) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: -1,
            speed: speed,
            timestamp: timestamp
        )
    }
}
