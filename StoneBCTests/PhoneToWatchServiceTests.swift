import XCTest
@testable import StoneBC

final class PhoneToWatchServiceTests: XCTestCase {

    func testBroadcast_sendsEncodedPayload_thatRoundTripsBackToMessage() throws {
        var captured: [String: Any]?
        let service = PhoneToWatchService { payload in
            captured = payload
        }

        let message = WatchRideMessage(
            distanceMiles: 8.6,
            movingSeconds: 2_400,
            elevationGainFeet: 510,
            currentSpeedMPH: 12.9,
            isOffRoute: false,
            isPaused: true,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        service.broadcast(message)

        let payload = try XCTUnwrap(captured)
        let decoded = try WatchRideMessage.decode(from: payload)
        XCTAssertEqual(decoded, message)
    }
}
