//
//  RadioViewModel.swift
//  StoneBC
//
//  Rally Radio state machine — manages PTT, open mic, peer connections
//

import SwiftUI
import AVFoundation
import MultipeerConnectivity

@Observable
class RadioViewModel: NSObject {
    // State
    var state: RadioState = .idle
    var connectedPeers: [RadioPeer] = []
    var isOpenMic: Bool = false
    var currentSpeaker: String?

    // Services
    private let radioService = RadioService()
    private let audioService = AudioStreamService()

    override init() {
        super.init()
        radioService.delegate = self
        audioService.delegate = self
    }

    // MARK: - Radio Lifecycle

    func startRadio() {
        guard state == .idle || state.isActive == false else { return }

        state = .connecting
        audioService.setupAudioSession()
        radioService.start()

        // Move to connected after brief delay (even with no peers)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.state == .connecting else { return }
            self.state = .connected
        }
    }

    func stopRadio() {
        stopTransmitting()
        radioService.stop()
        audioService.teardownAudioSession()
        connectedPeers.removeAll()
        currentSpeaker = nil
        state = .idle
    }

    // MARK: - Push-to-Talk

    func startTransmitting() {
        guard state == .connected || state == .connecting else { return }
        state = .transmitting
        radioService.sendTransmitState(true)
        audioService.startCapture()
    }

    func stopTransmitting() {
        guard state == .transmitting else { return }
        audioService.stopCapture()
        radioService.sendTransmitState(false)
        state = .connected
    }

    // MARK: - Open Mic Toggle

    func toggleOpenMic() {
        isOpenMic.toggle()

        if isOpenMic && state == .connected {
            radioService.sendTransmitState(true)
            audioService.startCapture()
            state = .transmitting
        } else if !isOpenMic && state == .transmitting {
            audioService.stopCapture()
            radioService.sendTransmitState(false)
            state = .connected
        }
    }

    // MARK: - Microphone Permission

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    var peerCount: Int { connectedPeers.count }
}

// MARK: - RadioServiceDelegate

extension RadioViewModel: RadioServiceDelegate {
    func radioService(_ service: RadioService, didReceiveAudio data: Data, from peer: MCPeerID) {
        audioService.playAudio(data)
    }

    func radioService(_ service: RadioService, peerDidConnect peer: MCPeerID) {
        let radioPeer = RadioPeer(id: peer.displayName, displayName: peer.displayName)
        if !connectedPeers.contains(where: { $0.id == radioPeer.id }) {
            connectedPeers.append(radioPeer)
        }
        if state == .connecting {
            state = .connected
        }
    }

    func radioService(_ service: RadioService, peerDidDisconnect peer: MCPeerID) {
        connectedPeers.removeAll { $0.id == peer.displayName }
        if peer.displayName == currentSpeaker {
            currentSpeaker = nil
        }
    }

    func radioService(_ service: RadioService, peerIsTransmitting peer: MCPeerID, transmitting: Bool) {
        if let idx = connectedPeers.firstIndex(where: { $0.id == peer.displayName }) {
            connectedPeers[idx].isTransmitting = transmitting
        }
        currentSpeaker = transmitting ? peer.displayName : nil
    }
}

// MARK: - AudioStreamDelegate

extension RadioViewModel: AudioStreamDelegate {
    func audioStream(_ service: AudioStreamService, didCapture data: Data) {
        radioService.sendAudio(data)
    }
}
