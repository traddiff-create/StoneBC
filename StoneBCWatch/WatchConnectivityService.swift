import Foundation
import WatchConnectivity
import Observation

/// Receives ride-state broadcasts from the paired iPhone via WCSession.
/// Holds the latest `WatchRideState` for the SwiftUI views to render.
@Observable
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    var ridingState: WatchRideState = .placeholder
    var isReachable: Bool = false

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        ingest(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        ingest(applicationContext)
    }

    private func ingest(_ payload: [String: Any]) {
        guard let state = try? WatchRideState.decode(from: payload) else { return }
        Task { @MainActor in
            self.ridingState = state
        }
    }
}
