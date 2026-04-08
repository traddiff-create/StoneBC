//
//  AudioStreamService.swift
//  StoneBC
//
//  AVAudioEngine wrapper — microphone capture and audio playback
//  Uses SEPARATE engines for capture and playback to avoid conflicts
//

import AVFoundation

protocol AudioStreamDelegate: AnyObject {
    func audioStream(_ service: AudioStreamService, didCapture data: Data)
}

class AudioStreamService {
    // Separate engines — capture and playback must not interfere
    private var captureEngine: AVAudioEngine?
    private var playbackEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isCapturing = false
    private var isPlaybackReady = false

    weak var delegate: AudioStreamDelegate?

    // MARK: - Audio Session Setup

    func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try session.setPreferredSampleRate(RadioConfig.sampleRate)
            try session.setPreferredIOBufferDuration(0.02) // 20ms for low latency
            try session.setActive(true)
            print("[AudioStream] Audio session configured: \(session.sampleRate)Hz")
        } catch {
            print("[AudioStream] ERROR configuring audio session: \(error)")
        }
    }

    func teardownAudioSession() {
        stopCapture()
        stopPlayback()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: - Capture (Microphone → Data)

    func startCapture() {
        guard !isCapturing else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        print("[AudioStream] Starting capture: input format = \(inputFormat)")

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
            print("[AudioStream] Capture started")
        } catch {
            print("[AudioStream] ERROR starting capture: \(error)")
        }
    }

    func stopCapture() {
        guard isCapturing else { return }
        captureEngine?.inputNode.removeTap(onBus: 0)
        captureEngine?.stop()
        captureEngine = nil
        isCapturing = false
        print("[AudioStream] Capture stopped")
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
            print("[AudioStream] Failed to convert data to buffer (\(data.count) bytes)")
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
            print("[AudioStream] Playback engine ready")
        } catch {
            print("[AudioStream] ERROR starting playback: \(error)")
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
            print("[AudioStream] Cannot create converter from \(buffer.format) to \(format)")
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
            print("[AudioStream] Conversion error: \(error)")
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
