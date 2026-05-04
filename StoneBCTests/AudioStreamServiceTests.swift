import XCTest
import AVFoundation
@testable import StoneBC

/// These tests lock down the AVAudioSession category options. The Bluetooth
/// flag thrashed three times in commits 3f6330a → 3ea9760 → e97202f when the
/// iOS SDK on the runner changed; this prevents a silent regression next
/// time someone touches the audio session setup.
final class AudioStreamServiceTests: XCTestCase {

    func testAudioSessionOptions_containsExpectedFlags() {
        let options = AudioStreamService.audioSessionOptions
        XCTAssertTrue(options.contains(.defaultToSpeaker), "PTT must default to speaker output")
        XCTAssertTrue(options.contains(.allowBluetoothHFP), "Rally Radio relies on HFP Bluetooth headsets")
        XCTAssertTrue(options.contains(.mixWithOthers), "Music/podcasts must keep playing under the radio")
    }
}
