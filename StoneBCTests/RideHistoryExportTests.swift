import Foundation
import XCTest
@testable import StoneBC

final class RideHistoryExportTests: XCTestCase {
    func testCompletedRideDecodesWithoutTrackpointTimestamps() throws {
        let legacyRide = LegacyCompletedRide(
            id: "ride-1",
            routeId: "route-1",
            routeName: "Legacy Ride",
            category: "gravel",
            distanceMiles: 1.5,
            elapsedSeconds: 600,
            movingSeconds: 540,
            elevationGainFeet: 120,
            avgSpeedMPH: 10,
            maxSpeedMPH: 18,
            completedAt: Date(timeIntervalSinceReferenceDate: 1_000),
            gpxTrackpoints: [[44.0, -103.0, 100], [44.001, -103.001, 101]]
        )

        let data = try JSONEncoder().encode(legacyRide)
        let decoded = try JSONDecoder().decode(CompletedRide.self, from: data)

        XCTAssertEqual(decoded.routeName, "Legacy Ride")
        XCTAssertNil(decoded.gpxTrackpointTimestamps)
        XCTAssertEqual(decoded.gpxTrackpoints?.count, 2)
    }

    func testRideExportUsesStoredTrackpointTimestamps() throws {
        let start = Date(timeIntervalSince1970: 1_704_067_200)
        let finish = start.addingTimeInterval(60)
        let ride = CompletedRide(
            id: "ride-2",
            routeId: "route-2",
            routeName: "Fresh Ride",
            category: "gravel",
            distanceMiles: 0.2,
            elapsedSeconds: 60,
            movingSeconds: 60,
            elevationGainFeet: 10,
            avgSpeedMPH: 12,
            maxSpeedMPH: 18,
            completedAt: finish,
            gpxTrackpoints: [[44.0, -103.0, 100], [44.001, -103.001, 101]],
            gpxTrackpointTimestamps: [start, finish]
        )

        let url = try XCTUnwrap(RouteInterchangeService.writeRideExport(ride: ride, format: .gpxTrack))
        let gpx = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(gpx.contains(RouteInterchangeService.iso8601(start)))
        XCTAssertTrue(gpx.contains(RouteInterchangeService.iso8601(finish)))
    }
}

private struct LegacyCompletedRide: Encodable {
    let id: String
    let routeId: String
    let routeName: String
    let category: String
    let distanceMiles: Double
    let elapsedSeconds: TimeInterval
    let movingSeconds: TimeInterval
    let elevationGainFeet: Double
    let avgSpeedMPH: Double
    let maxSpeedMPH: Double
    let completedAt: Date
    let gpxTrackpoints: [[Double]]
}
