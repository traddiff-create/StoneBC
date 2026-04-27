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

final class RouteGuidanceResolverTests: XCTestCase {
    func testMatchesGuideDayAndPreservesStopOrder() throws {
        let route = testRoute(distanceMiles: 2.0)
        let guide = testGuide(
            routeId: route.id,
            totalMiles: 2.0,
            elevationGain: route.elevationGainFeet,
            stops: [
                testStop(name: "Start", longitude: -103.0, mileMarker: 0),
                testStop(name: "Middle", longitude: -102.99, mileMarker: 0.7),
                testStop(name: "Finish", longitude: -102.98, mileMarker: 1.4)
            ]
        )

        let guidance = try XCTUnwrap(RouteGuidanceResolver.guidance(for: route, guides: [guide]))

        XCTAssertEqual(guidance.guideName, guide.name)
        XCTAssertEqual(guidance.dayName, "Test Day")
        XCTAssertEqual(guidance.stops.map(\.name), ["Start", "Middle", "Finish"])
        XCTAssertLessThan(guidance.stops[0].routeMile, guidance.stops[1].routeMile)
        XCTAssertLessThan(guidance.stops[1].routeMile, guidance.stops[2].routeMile)
        XCTAssertEqual(guidance.stops[1].distanceFromRouteMiles, 0, accuracy: 0.01)
    }

    func testReportsKnownDataGaps() throws {
        let route = Route(
            id: "rc-brewery-crawl",
            name: "RC Brewery Crawl",
            difficulty: "hard",
            category: "road",
            distanceMiles: 4.7,
            elevationGainFeet: 3227,
            region: "Rapid City",
            description: "Dakota Point, Hay Camp, Firehouse, Knuckle, Lost Cabin. Start at Hanson-Larsen Memorial Park.",
            startCoordinate: .init(latitude: 44.0898, longitude: -103.2453),
            trackpoints: [
                [44.0898, -103.2453, 980],
                [44.0805, -103.2310, 981],
                [44.0812, -103.2248, 982],
                [44.0803, -103.2283, 983],
                [44.0764, -103.2088, 984]
            ]
        )
        let guide = testGuide(
            routeId: route.id,
            startLocation: "Dakota Point Brewing",
            startCoordinate: [44.0805, -103.2310],
            totalMiles: 15,
            elevationGain: 0,
            stops: [
                testStop(name: "Dakota Point Brewing", longitude: -103.2310, mileMarker: 0),
                testStop(name: "Hay Camp Brewing", longitude: -103.2248, mileMarker: 4),
                testStop(name: "Firehouse Brewing Co.", longitude: -103.2283, mileMarker: 8),
                testStop(name: "Lost Cabin Beer Co.", longitude: -103.2088, mileMarker: 15)
            ]
        )

        let guidance = try XCTUnwrap(RouteGuidanceResolver.guidance(for: route, guides: [guide]))
        let issueIds = Set(guidance.issues.map(\.id))

        XCTAssertTrue(issueIds.contains("distance-mismatch"))
        XCTAssertTrue(issueIds.contains("elevation-missing"))
        XCTAssertTrue(issueIds.contains("stop-marker-mismatch"))
        XCTAssertTrue(issueIds.contains("start-location-mismatch"))
        XCTAssertTrue(issueIds.contains("description-start-mismatch"))
        XCTAssertTrue(issueIds.contains("missing-described-stop"))
        XCTAssertTrue(issueIds.contains("missing-cues"))
    }

    func testProgressFindsNextAndCurrentStops() throws {
        let guidance = RouteGuidance(
            id: "guide-day-route",
            routeId: "route",
            guideName: "Guide",
            dayName: "Day",
            routeDistanceMiles: 10,
            stops: [
                progressStop(sequence: 1, name: "First", routeMile: 2, progress: 0.2),
                progressStop(sequence: 2, name: "Second", routeMile: 6, progress: 0.6)
            ],
            issues: []
        )

        let beforeFirst = RouteGuidanceResolver.progress(for: guidance, routeProgress: 0.1)
        XCTAssertNil(beforeFirst.currentStop)
        XCTAssertEqual(beforeFirst.nextStop?.name, "First")
        XCTAssertEqual(try XCTUnwrap(beforeFirst.remainingMilesToNext), 1.0, accuracy: 0.01)

        let betweenStops = RouteGuidanceResolver.progress(for: guidance, routeProgress: 0.4)
        XCTAssertEqual(betweenStops.currentStop?.name, "First")
        XCTAssertEqual(betweenStops.nextStop?.name, "Second")
        XCTAssertEqual(betweenStops.completedCount, 1)
        XCTAssertEqual(try XCTUnwrap(betweenStops.remainingMilesToNext), 2.0, accuracy: 0.01)

        let afterFinal = RouteGuidanceResolver.progress(for: guidance, routeProgress: 0.9)
        XCTAssertEqual(afterFinal.currentStop?.name, "Second")
        XCTAssertNil(afterFinal.nextStop)
        XCTAssertEqual(afterFinal.completedCount, 2)
    }

    private func testRoute(distanceMiles: Double) -> Route {
        Route(
            id: "test-route",
            name: "Test Route",
            difficulty: "easy",
            category: "road",
            distanceMiles: distanceMiles,
            elevationGainFeet: 100,
            region: "Test",
            description: "Test route",
            startCoordinate: .init(latitude: 44.0, longitude: -103.0),
            trackpoints: [
                [44.0, -103.0, 0],
                [44.0, -102.99, 0],
                [44.0, -102.98, 0]
            ],
            cuePoints: [
                Route.CuePoint(
                    name: "Turn",
                    coordinate: .init(latitude: 44.0, longitude: -102.99)
                )
            ]
        )
    }

    private func testGuide(
        routeId: String,
        startLocation: String = "Test Start",
        startCoordinate: [Double]? = [44.0, -103.0],
        totalMiles: Double,
        elevationGain: Int,
        stops: [TourStop]
    ) -> TourGuide {
        TourGuide(
            id: "test-guide",
            name: "Test Guide",
            subtitle: "Test",
            description: "Test",
            type: .selfGuided,
            eventDate: nil,
            totalDays: 1,
            totalMiles: totalMiles,
            totalElevation: elevationGain,
            difficulty: "easy",
            category: "road",
            region: "Test",
            notes: [],
            checklist: nil,
            enabledSections: nil,
            overlayDefaults: nil,
            stopTags: nil,
            gearProfile: nil,
            safetyNotes: nil,
            days: [
                TourDay(
                    dayNumber: 1,
                    name: "Test Day",
                    date: nil,
                    startTime: nil,
                    startLocation: startLocation,
                    startCoordinate: startCoordinate,
                    totalMiles: totalMiles,
                    elevationGain: elevationGain,
                    estimatedDuration: nil,
                    finishLocation: nil,
                    routeId: routeId,
                    routeFile: nil,
                    gpxURL: nil,
                    trackpoints: nil,
                    stops: stops
                )
            ]
        )
    }

    private func testStop(name: String, longitude: Double, mileMarker: Double?) -> TourStop {
        TourStop(
            name: name,
            type: .brewery,
            coordinate: [44.0, longitude],
            mileMarker: mileMarker,
            description: "\(name) context",
            beer: name,
            tags: nil
        )
    }

    private func progressStop(sequence: Int, name: String, routeMile: Double, progress: Double) -> RouteGuidedStop {
        RouteGuidedStop(
            id: "\(sequence)",
            sequence: sequence,
            name: name,
            type: .brewery,
            description: nil,
            context: nil,
            guideMileMarker: nil,
            routeMile: routeMile,
            progress: progress,
            distanceFromRouteMiles: 0
        )
    }
}
