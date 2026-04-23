import Foundation

struct TimeTrialPreset: Identifiable, Codable {
    let id: String
    var routeId: String
    var routeName: String
    var personalBestSeconds: Double?
    var personalBestDate: Date?
    var attempts: [TimeTrialAttempt]

    init(routeId: String, routeName: String) {
        self.id = UUID().uuidString
        self.routeId = routeId
        self.routeName = routeName
        self.attempts = []
    }

    var personalBest: TimeTrialAttempt? {
        attempts.min { $0.elapsedSeconds < $1.elapsedSeconds }
    }
}

struct TimeTrialAttempt: Identifiable, Codable {
    let id: String
    let rideId: String
    let completedAt: Date
    let elapsedSeconds: Double
    let distanceMiles: Double

    init(rideId: String, elapsedSeconds: Double, distanceMiles: Double) {
        self.id = UUID().uuidString
        self.rideId = rideId
        self.completedAt = .now
        self.elapsedSeconds = elapsedSeconds
        self.distanceMiles = distanceMiles
    }
}

@Observable
class TimeTrialService {
    static let shared = TimeTrialService()

    private(set) var presets: [TimeTrialPreset] = []
    private let key = "timeTrialPresets"

    private init() { load() }

    func isPreset(routeId: String) -> Bool {
        presets.contains { $0.routeId == routeId }
    }

    func preset(forRouteId routeId: String) -> TimeTrialPreset? {
        presets.first { $0.routeId == routeId }
    }

    func addPreset(routeId: String, routeName: String) {
        guard !isPreset(routeId: routeId) else { return }
        presets.append(TimeTrialPreset(routeId: routeId, routeName: routeName))
        persist()
    }

    func removePreset(routeId: String) {
        presets.removeAll { $0.routeId == routeId }
        persist()
    }

    /// Returns true if this attempt is a new personal best.
    @discardableResult
    func recordAttempt(rideId: String, routeId: String, seconds: Double, distanceMiles: Double) -> Bool {
        guard let idx = presets.firstIndex(where: { $0.routeId == routeId }) else { return false }
        let attempt = TimeTrialAttempt(rideId: rideId, elapsedSeconds: seconds, distanceMiles: distanceMiles)
        presets[idx].attempts.insert(attempt, at: 0)
        let isNewPB = presets[idx].personalBestSeconds.map { seconds < $0 } ?? true
        if isNewPB {
            presets[idx].personalBestSeconds = seconds
            presets[idx].personalBestDate = .now
        }
        persist()
        return isNewPB
    }

    func personalBest(forRouteId routeId: String) -> TimeTrialAttempt? {
        preset(forRouteId: routeId)?.personalBest
    }

    func rank(forRideId rideId: String, routeId: String) -> Int? {
        guard let preset = preset(forRouteId: routeId),
              let attempt = preset.attempts.first(where: { $0.rideId == rideId })
        else { return nil }
        let sorted = preset.attempts.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
        return (sorted.firstIndex(where: { $0.id == attempt.id }) ?? 0) + 1
    }

    /// Positive = behind PB, negative = ahead of PB. Nil if no PB exists.
    func splitDelta(routeId: String, currentSeconds: Double, progressPercent: Double) -> Double? {
        guard progressPercent > 0,
              let pb = personalBest(forRouteId: routeId)
        else { return nil }
        let projectedPBAtProgress = pb.elapsedSeconds * progressPercent
        return currentSeconds - projectedPBAtProgress
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TimeTrialPreset].self, from: data)
        else { return }
        presets = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
