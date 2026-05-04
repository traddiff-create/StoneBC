import Foundation

/// Minimal ride-state payload broadcast from iPhone to Apple Watch.
/// Mirrored on the watchOS side as `WatchRideState` — keep both in sync
/// until they're extracted into a shared Swift Package.
struct WatchRideMessage: Codable, Equatable {
    let distanceMiles: Double
    let movingSeconds: Double
    let elevationGainFeet: Int
    let currentSpeedMPH: Double
    let isOffRoute: Bool
    let isPaused: Bool
    let timestamp: Date

    /// JSON-compatible dictionary for `WCSession.sendMessage` /
    /// `updateApplicationContext`. Uses ISO8601 dates so the watch
    /// side can decode without the encoder strategy mismatching.
    func payload() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let object = try JSONSerialization.jsonObject(with: data)
        return (object as? [String: Any]) ?? [:]
    }

    static func decode(from payload: [String: Any]) throws -> WatchRideMessage {
        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WatchRideMessage.self, from: data)
    }
}
