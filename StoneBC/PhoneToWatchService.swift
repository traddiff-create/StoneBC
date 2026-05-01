import Foundation
import WatchConnectivity

/// Broadcasts ride state from iPhone to a paired Apple Watch.
///
/// Reachability-aware: uses `sendMessage` for live updates when the watch
/// is reachable, falls back to `updateApplicationContext` for the last
/// known state when it isn't. The send mechanism is injectable so unit
/// tests can capture the payload without booting a real `WCSession`.
final class PhoneToWatchService: NSObject {
    typealias Send = ([String: Any]) -> Void

    private let send: Send

    init(send: @escaping Send = PhoneToWatchService.defaultSend) {
        self.send = send
        super.init()
    }

    func broadcast(_ message: WatchRideMessage) {
        guard let payload = try? message.payload() else { return }
        send(payload)
    }

    /// Production send: routes through `WCSession.default`. No-ops on
    /// devices without WatchConnectivity (iPad, Simulator without Watch).
    static func defaultSend(_ payload: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.activationState != .activated {
            session.activate()
        }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            try? session.updateApplicationContext(payload)
        }
    }
}
