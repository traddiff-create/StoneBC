import XCTest
@testable import StoneBC

final class MediaCaptureServiceTests: XCTestCase {

    func testVoiceMemoFilename_followsExpectedPattern() {
        // Pin the date so the filename is deterministic.
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let filename = MediaCaptureService.voiceMemoFilename(at: date)
        XCTAssertEqual(filename, "voice_1700000000.m4a")
    }

    func testFormattedDuration_padsSecondsAndHandlesMinutes() {
        XCTAssertEqual(MediaCaptureService.formattedDuration(0), "0:00")
        XCTAssertEqual(MediaCaptureService.formattedDuration(7), "0:07")
        XCTAssertEqual(MediaCaptureService.formattedDuration(65), "1:05")
        XCTAssertEqual(MediaCaptureService.formattedDuration(610), "10:10")
    }
}
