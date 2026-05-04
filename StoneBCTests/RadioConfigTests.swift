import XCTest
import AVFoundation
@testable import StoneBC

final class RadioConfigTests: XCTestCase {

    func testAudioFormat_matchesDeclaredConstants() {
        let format = RadioConfig.audioFormat
        XCTAssertEqual(format.sampleRate, RadioConfig.sampleRate)
        XCTAssertEqual(format.channelCount, AVAudioChannelCount(RadioConfig.channels))
        XCTAssertEqual(format.commonFormat, .pcmFormatInt16)
        XCTAssertTrue(format.isInterleaved)
    }

    func testBufferFrameCount_equalsSampleRateTimesBufferDuration() {
        let expected = AVAudioFrameCount(RadioConfig.sampleRate * RadioConfig.bufferDuration)
        XCTAssertEqual(RadioConfig.bufferFrameCount, expected)
        XCTAssertEqual(RadioConfig.bufferFrameCount, 8000)
    }

    func testServiceType_isStableConstant() {
        // Changing this would break peer discovery between app versions.
        XCTAssertEqual(RadioConfig.serviceType, "stonebc-radio")
    }
}
