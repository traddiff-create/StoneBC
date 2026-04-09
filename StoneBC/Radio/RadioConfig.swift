//
//  RadioConfig.swift
//  StoneBC
//
//  Rally Radio constants — service type, audio format, UI dimensions
//

import AVFoundation

enum RadioConfig {
    // MultipeerConnectivity
    static let serviceType = "stonebc-radio"  // 1-15 chars, lowercase + hyphens
    static let maxPeers = 15

    // Audio format: 16-bit PCM, 16kHz, mono (32 KB/s)
    static let sampleRate: Double = 16000
    static let channels: UInt32 = 1
    static let bitsPerChannel: UInt32 = 16
    static let bufferDuration: TimeInterval = 0.5  // 500ms chunks

    static var audioFormat: AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: true
        )!
    }

    // Buffer size per chunk: 16000 Hz * 0.5s * 2 bytes = 16,000 bytes
    static var bufferFrameCount: AVAudioFrameCount {
        AVAudioFrameCount(sampleRate * bufferDuration)
    }

    // Reconnection
    static let reconnectTimeout: TimeInterval = 60  // seconds to keep trying

    // Peer Validation
    static let appIdentifier = "StoneBC"
    static let protocolVersion = "1"

    // UI
    static let pttButtonSize: CGFloat = 80
    static let peerAvatarSize: CGFloat = 40
}
