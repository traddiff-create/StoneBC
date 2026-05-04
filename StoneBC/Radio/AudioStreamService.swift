//
//  AudioStreamService.swift
//  StoneBC
//
//  AVAudioEngine wrapper — microphone capture and audio playback
//  Uses SEPARATE engines for capture and playback to avoid conflicts
//

import AVFoundation
import os.log

protocol AudioStreamDelegate: AnyObject {
    func audioStream(_ service: AudioStreamService, didCapture data: Data)
    func audioStreamWasInterrupted(_ service: AudioStreamService)
    func audioStreamInterruptionEnded(_ service: AudioStreamService)
}

class AudioStreamService: NSObject {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.traddiff.StoneBC", category: "AudioStream")

    static let audioSessionOptions: AVAudioSession.CategoryOptions = [
        .defaultToSpeaker,
        .allowBluetoothHFP,
        .mixWithOthers
    ]

    // Separate engines — capture and playback must not interfere
    private var captureEngine: AVAudioEngine?
    private var playbackEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let stateLock = NSLock()
    private var _isCapturing = false
    private var _isPlaybackReady = false
    private var wasCapturingBeforeInterruption = false

    private var isCapturing: Bool {
        get { stateLock.withLock { _isCapturing } }
        set { stateLock.withLock { _isCapturing = newValue } }
    }

    private var isPlaybackReady: Bool {
        get { stateLock.withLock { _isPlaybackReady } }
        set { stateLock.withLock { _isPlaybackReady = newValue } }
    }

    weak var delegate: AudioStreamDelegate?

    // MARK: - Audio Session Setup

    func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: Self.audioSessionOptions
            )
            try session.setPreferredSampleRate(RadioConfig.sampleRate)
            try session.setPreferredIOBufferDuration(0.02) // 20ms for low latency
            try session.setActive(true)
            Self.logger.info("Audio session configured: \(session.sampleRate)Hz")
        } catch {
            Self.logger.error("Error configuring audio session: \(error.localizedDescription)")
        }

        // Observe interruptions (phone calls, Siri, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
    }

    func teardownAudioSession() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        stopCapture()
        stopPlayback()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            Self.logger.info("Interruption began (phone call, Siri, etc.)")
            wasCapturingBeforeInterruption = isCapturing
            stopCapture()
            stopPlayback()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.audioStreamWasInterrupted(self)
            }

        case .ended:
            Self.logger.info("Interruption ended")
            let options = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)

            if shouldResume {
                try? AVAudioSession.sharedInstance().setActive(true)
                if wasCapturingBeforeInterruption {
                    startCapture()
                }
                setupPlaybackEngine()
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.audioStreamInterruptionEnded(self)
            }

        @unknown default:
            break
        }
    }

    // MARK: - Capture (Microphone → Data)

    func startCapture() {
        guard !isCapturing else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        Self.logger.info("Starting capture: input format = \(String(describing: inputFormat))")

        // Use the hardware format for the tap, convert in the callback
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            let data: Data
            if inputFormat.sampleRate != RadioConfig.sampleRate || inputFormat.channelCount != 1 {
                // Convert to our target format
                if let converted = self.convertBuffer(buffer, to: RadioConfig.audioFormat) {
                    data = self.bufferToData(converted)
                } else {
                    return // conversion failed, skip this buffer
                }
            } else {
                data = self.bufferToData(buffer)
            }

            guard !data.isEmpty else { return }

            DispatchQueue.main.async {
                self.delegate?.audioStream(self, didCapture: data)
            }
        }

        do {
            try engine.start()
            captureEngine = engine
            isCapturing = true
            Self.logger.info("Capture started")
        } catch {
            Self.logger.error("Error starting capture: \(error.localizedDescription)")
        }
    }

    func stopCapture() {
        guard isCapturing else { return }
        captureEngine?.inputNode.removeTap(onBus: 0)
        captureEngine?.stop()
        captureEngine = nil
        isCapturing = false
        Self.logger.info("Capture stopped")
    }

    // MARK: - Playback (Data → Speaker)

    func playAudio(_ data: Data) {
        guard !data.isEmpty else { return }

        // Set up playback engine if needed (separate from capture)
        if !isPlaybackReady {
            setupPlaybackEngine()
        }

        guard let player = playerNode, isPlaybackReady else { return }

        // Convert data to PCM buffer
        guard let buffer = dataToBuffer(data) else {
            Self.logger.warning("Failed to convert data to buffer (\(data.count) bytes)")
            return
        }
        player.scheduleBuffer(buffer)
    }

    private func setupPlaybackEngine() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: RadioConfig.audioFormat)

        do {
            try engine.start()
            player.play()
            playbackEngine = engine
            playerNode = player
            isPlaybackReady = true
            Self.logger.info("Playback engine ready")
        } catch {
            Self.logger.error("Error starting playback: \(error.localizedDescription)")
        }
    }

    func stopPlayback() {
        playerNode?.stop()
        playbackEngine?.stop()
        playbackEngine = nil
        playerNode = nil
        isPlaybackReady = false
    }

    // MARK: - Conversion Helpers

    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard buffer.format != format else { return buffer }
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            Self.logger.warning("Cannot create converter from \(String(describing: buffer.format)) to \(String(describing: format))")
            return nil
        }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard outputFrameCount > 0,
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputFrameCount) else {
            return nil
        }

        var error: NSError?
        var hasData = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if !hasData {
                hasData = true
                outStatus.pointee = .haveData
                return buffer
            }
            outStatus.pointee = .noDataNow
            return nil
        }

        if let error {
            Self.logger.error("Conversion error: \(error.localizedDescription)")
            return nil
        }

        return outputBuffer
    }

    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        guard let mData = audioBuffer.mData, audioBuffer.mDataByteSize > 0 else {
            return Data()
        }
        return Data(bytes: mData, count: Int(audioBuffer.mDataByteSize))
    }

    private func dataToBuffer(_ data: Data) -> AVAudioPCMBuffer? {
        let format = RadioConfig.audioFormat
        let bytesPerFrame = format.streamDescription.pointee.mBytesPerFrame
        guard bytesPerFrame > 0 else { return nil }

        let frameCount = AVAudioFrameCount(data.count) / bytesPerFrame
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount

        data.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                memcpy(buffer.audioBufferList.pointee.mBuffers.mData, baseAddress, data.count)
            }
        }

        return buffer
    }
}
