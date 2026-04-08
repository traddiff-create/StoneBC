//
//  RadioService.swift
//  StoneBC
//
//  MultipeerConnectivity wrapper — peer discovery and audio data relay
//

import Foundation
import MultipeerConnectivity

protocol RadioServiceDelegate: AnyObject {
    func radioService(_ service: RadioService, didReceiveAudio data: Data, from peer: MCPeerID)
    func radioService(_ service: RadioService, peerDidConnect peer: MCPeerID)
    func radioService(_ service: RadioService, peerDidDisconnect peer: MCPeerID)
    func radioService(_ service: RadioService, peerIsTransmitting peer: MCPeerID, transmitting: Bool)
}

class RadioService: NSObject {
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
        print("[Radio] Initialized with peer name: \(name)")
    }

    // MARK: - Lifecycle

    func start() {
        let session = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .none
        )
        session.delegate = self
        self.session = session

        let advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: ["app": "StoneBC"],
            serviceType: RadioConfig.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
        print("[Radio] Advertising as '\(myPeerID.displayName)' on service '\(RadioConfig.serviceType)'")

        let browser = MCNearbyServiceBrowser(
            peer: myPeerID,
            serviceType: RadioConfig.serviceType
        )
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
        print("[Radio] Browsing for peers on service '\(RadioConfig.serviceType)'")
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        print("[Radio] Stopped and disconnected")
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
            print("[Radio] Send audio error: \(error)")
        }
    }

    func sendTransmitState(_ isTransmitting: Bool) {
        guard let session, !session.connectedPeers.isEmpty else { return }

        let data = Data([0x54, isTransmitting ? 1 : 0])
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("[Radio] Send transmit state error: \(error)")
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
        print("[Radio] Peer '\(peerID.displayName)' state: \(stateStr)")

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
        print("[Radio] Received invitation from '\(peerID.displayName)' — auto-accepting")
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("[Radio] ERROR: Failed to start advertising: \(error)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension RadioService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        print("[Radio] Found peer '\(peerID.displayName)' — inviting")
        guard let session else {
            print("[Radio] ERROR: No session available to invite peer")
            return
        }
        guard session.connectedPeers.count < RadioConfig.maxPeers else {
            print("[Radio] Max peers reached, ignoring '\(peerID.displayName)'")
            return
        }

        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("[Radio] Lost peer '\(peerID.displayName)'")
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("[Radio] ERROR: Failed to start browsing: \(error)")
    }
}
