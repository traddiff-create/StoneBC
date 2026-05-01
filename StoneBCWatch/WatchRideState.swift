import Foundation

/// Watch-side mirror of `WatchRideMessage` (in the iOS target).
/// Keep field-for-field identical until they're extracted into a
/// shared Swift Package.
struct WatchRideState: Codable, Equatable {
    let distanceMiles: Double
    let movingSeconds: Double
    let elevationGainFeet: Int
    let currentSpeedMPH: Double
    let isOffRoute: Bool
    let isPaused: Bool
    let timestamp: Date

    static let placeholder = WatchRideState(
        distanceMiles: 0,
        movingSeconds: 0,
        elevationGainFeet: 0,
        currentSpeedMPH: 0,
        isOffRoute: false,
        isPaused: false,
        timestamp: Date(timeIntervalSince1970: 0)
    )

    static func decode(from payload: [String: Any]) throws -> WatchRideState {
        let data = try JSONSerialization.data(withJSONObject: payload)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WatchRideState.self, from: data)
    }
}
