import XCTest
@testable import StoneBC

final class WatchRideMessageTests: XCTestCase {

    func testPayloadRoundTrip_preservesAllFields() throws {
        let original = WatchRideMessage(
            distanceMiles: 12.4,
            movingSeconds: 3_550,
            elevationGainFeet: 740,
            currentSpeedMPH: 14.2,
            isOffRoute: true,
            isPaused: false,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let payload = try original.payload()
        let decoded = try WatchRideMessage.decode(from: payload)

        XCTAssertEqual(decoded, original)
    }

    func testPayload_isJSONCompatibleDictionary() throws {
        let message = WatchRideMessage(
            distanceMiles: 1, movingSeconds: 60,
            elevationGainFeet: 0, currentSpeedMPH: 1,
            isOffRoute: false, isPaused: false,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let payload = try message.payload()
        // Must be serialisable through `WCSession.sendMessage`, which
        // requires JSON-safe values.
        XCTAssertTrue(JSONSerialization.isValidJSONObject(payload))
    }
}
