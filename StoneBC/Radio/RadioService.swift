//
//  RadioService.swift
//  StoneBC
//
//  MultipeerConnectivity wrapper — peer discovery and audio data relay
//

import Foundation
import MultipeerConnectivity
import os.log

protocol RadioServiceDelegate: AnyObject {
    func radioService(_ service: RadioService, didReceiveAudio data: Data, from peer: MCPeerID)
    func radioService(_ service: RadioService, peerDidConnect peer: MCPeerID)
    func radioService(_ service: RadioService, peerDidDisconnect peer: MCPeerID)
    func radioService(_ service: RadioService, peerIsTransmitting peer: MCPeerID, transmitting: Bool)
    func radioService(_ service: RadioService, didReceiveMessage message: String, from peer: MCPeerID)
}

class RadioService: NSObject {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.traddiff.StoneBC", category: "RadioService")

    private let myPeerID: MCPeerID
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    weak var delegate: RadioServiceDelegate?

    var connectedPeers: [MCPeerID] {
        session?.connectedPeers ?? []
    }

    var displayName: String {
        myPeerID.displayName
    }

    override init() {
        let name = UIDevice.current.name
        self.myPeerID = MCPeerID(displayName: name)
        super.init()
        Self.logger.info("Initialized with peer name: \(name)")
    }

    // MARK: - Lifecycle

    func start() {
        let session = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session.delegate = self
        self.session = session

        let advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: [
                "app": RadioConfig.appIdentifier,
                "v": RadioConfig.protocolVersion
            ],
            serviceType: RadioConfig.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
        Self.logger.info("Advertising as '\(self.myPeerID.displayName)' on service '\(RadioConfig.serviceType)'")

        let browser = MCNearbyServiceBrowser(
            peer: myPeerID,
            serviceType: RadioConfig.serviceType
        )
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
        Self.logger.info("Browsing for peers on service '\(RadioConfig.serviceType)'")
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        Self.logger.info("Stopped and disconnected")
    }

    // MARK: - Audio Data

    func sendAudio(_ data: Data) {
        guard let session, !session.connectedPeers.isEmpty else { return }

        // Prefix with "A" byte to identify as audio data
        var tagged = Data([0x41])
        tagged.append(data)

        do {
            try session.send(tagged, toPeers: session.connectedPeers, with: .unreliable)
        } catch {
            Self.logger.error("Send audio error: \(error.localizedDescription)")
        }
    }

    func sendTransmitState(_ isTransmitting: Bool) {
        guard let session, !session.connectedPeers.isEmpty else { return }

        let data = Data([0x54, isTransmitting ? 1 : 0])
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            Self.logger.error("Send transmit state error: \(error.localizedDescription)")
        }
    }

    /// Send a preset text message to all peers (prefixed with 0x4D = "M")
    func sendPresetMessage(_ message: RadioPresetMessage) {
        guard let session, !session.connectedPeers.isEmpty else { return }

        var data = Data([0x4D]) // M for message
        if let msgData = message.text.data(using: .utf8) {
            data.append(msgData)
        }

        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            Self.logger.error("Send preset message error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preset Messages

enum RadioPresetMessage: String, CaseIterable, Identifiable {
    case trailMuddy = "Trail muddy ahead"
    case trailClear = "Trail is clear"
    case mechanical = "Mechanical issue — need help"
    case flatTire = "Flat tire — stopping"
    case regrouping = "Regrouping — wait up"
    case allGood = "All good — keep rolling"
    case waterStop = "Water stop ahead"
    case turnAhead = "Sharp turn ahead"
    case wildlifeAlert = "Wildlife on trail"
    case ridersBack = "Riders coming from behind"

    var id: String { rawValue }
    var text: String { rawValue }

    var icon: String {
        switch self {
        case .trailMuddy: "drop.fill"
        case .trailClear: "checkmark.circle"
        case .mechanical: "wrench.and.screwdriver"
        case .flatTire: "circle.slash"
        case .regrouping: "person.3"
        case .allGood: "hand.thumbsup"
        case .waterStop: "cup.and.saucer"
        case .turnAhead: "arrow.turn.up.right"
        case .wildlifeAlert: "pawprint"
        case .ridersBack: "arrow.backward"
        }
    }
}

// MARK: - MCSessionDelegate

extension RadioService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let stateStr: String
        switch state {
        case .connected: stateStr = "CONNECTED"
        case .connecting: stateStr = "connecting"
        case .notConnected: stateStr = "DISCONNECTED"
        @unknown default: stateStr = "unknown"
        }
        Self.logger.info("Peer '\(peerID.displayName)' state: \(stateStr)")

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch state {
            case .connected:
                self.delegate?.radioService(self, peerDidConnect: peerID)
            case .notConnected:
                self.delegate?.radioService(self, peerDidDisconnect: peerID)
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard !data.isEmpty else { return }

        let tag = data[0]
        let payload = data.dropFirst()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            switch tag {
            case 0x41: // "A" — audio data
                self.delegate?.radioService(self, didReceiveAudio: Data(payload), from: peerID)
            case 0x54: // "T" — transmit state
                let isTransmitting = payload.first == 1
                self.delegate?.radioService(self, peerIsTransmitting: peerID, transmitting: isTransmitting)
            case 0x4D: // "M" — preset message
                if let message = String(data: Data(payload), encoding: .utf8) {
                    self.delegate?.radioService(self, didReceiveMessage: message, from: peerID)
                }
            default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName: String, fromPeer: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName: String, fromPeer: MCPeerID, with: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName: String, fromPeer: MCPeerID, at: URL?, withError: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension RadioService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Accept invitations only when we have an active session
        // Peer identity is already validated by the browser before inviting
        guard let session else {
            Self.logger.warning("Rejected invitation — no active session")
            invitationHandler(false, nil)
            return
        }
        guard session.connectedPeers.count < RadioConfig.maxPeers else {
            Self.logger.warning("Rejected invitation — max peers reached")
            invitationHandler(false, nil)
            return
        }
        Self.logger.info("Accepted invitation from '\(peerID.displayName)'")
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Self.logger.error("Failed to start advertising: \(error.localizedDescription)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension RadioService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Self.logger.info("Found peer '\(peerID.displayName)' — checking identity")

        // Validate peer is a StoneBC app with compatible protocol
        guard let info,
              info["app"] == RadioConfig.appIdentifier,
              info["v"] == RadioConfig.protocolVersion else {
            Self.logger.warning("Rejected peer '\(peerID.displayName)' — invalid or missing discoveryInfo")
            return
        }

        guard let session else {
            Self.logger.error("No session available to invite peer")
            return
        }
        guard session.connectedPeers.count < RadioConfig.maxPeers else {
            Self.logger.info("Max peers reached, ignoring '\(peerID.displayName)'")
            return
        }

        Self.logger.info("Peer '\(peerID.displayName)' verified — inviting")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Self.logger.info("Lost peer '\(peerID.displayName)'")
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Self.logger.error("Failed to start browsing: \(error.localizedDescription)")
    }
}
