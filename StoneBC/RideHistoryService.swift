//
//  RideHistoryService.swift
//  StoneBC
//
//  Persistent ride history — stores completed rides with stats.
//  Uses UserDefaults (simple, no SwiftData dependency).
//  Season summary for Home tab.
//

import Foundation

@Observable
class RideHistoryService {
    static let shared = RideHistoryService()

    private(set) var rides: [CompletedRide] = []
    private let storageKey = "rideHistory"
    private let maxRides = 500

    private init() {
        loadRides()
    }

    // MARK: - Record Ride

    @discardableResult
    func recordRide(
        routeId: String,
        routeName: String,
        category: String,
        distanceMiles: Double,
        elapsedSeconds: TimeInterval,
        movingSeconds: TimeInterval,
        elevationGainFeet: Double,
        avgSpeedMPH: Double,
        maxSpeedMPH: Double,
        calories: Double? = nil,
        heartRateAvg: Double? = nil,
        gpxTrackpoints: [[Double]]? = nil,
        isTimeTrial: Bool = false
    ) -> String {
        let rideId = UUID().uuidString
        let ride = CompletedRide(
            id: rideId,
            routeId: routeId,
            routeName: routeName,
            category: category,
            distanceMiles: distanceMiles,
            elapsedSeconds: elapsedSeconds,
            movingSeconds: movingSeconds,
            elevationGainFeet: elevationGainFeet,
            avgSpeedMPH: avgSpeedMPH,
            maxSpeedMPH: maxSpeedMPH,
            completedAt: Date(),
            gpxTrackpoints: gpxTrackpoints,
            heartRateAvg: heartRateAvg,
            calories: calories,
            isTimeTrial: isTimeTrial
        )

        rides.insert(ride, at: 0)

        if rides.count > maxRides {
            rides = Array(rides.prefix(maxRides))
        }

        persistRides()
        return rideId
    }

    func deleteRide(_ ride: CompletedRide) {
        rides.removeAll { $0.id == ride.id }
        persistRides()
    }

    func update(_ ride: CompletedRide) {
        guard let idx = rides.firstIndex(where: { $0.id == ride.id }) else { return }
        rides[idx] = ride
        persistRides()
    }

    // MARK: - Season Summary

    var seasonSummary: SeasonSummary {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let seasonStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!

        let seasonRides = rides.filter { $0.completedAt >= seasonStart }

        let totalMiles = seasonRides.reduce(0) { $0 + $1.distanceMiles }
        let totalElevation = seasonRides.reduce(0) { $0 + $1.elevationGainFeet }
        let totalTime = seasonRides.reduce(0) { $0 + $1.movingSeconds }
        let avgSpeed = seasonRides.isEmpty ? 0 :
            seasonRides.reduce(0) { $0 + $1.avgSpeedMPH } / Double(seasonRides.count)

        // Favorite route (most ridden)
        let routeCounts = Dictionary(grouping: seasonRides, by: { $0.routeId })
        let favoriteRoute = routeCounts.max(by: { $0.value.count < $1.value.count })?.value.first?.routeName

        return SeasonSummary(
            year: year,
            rideCount: seasonRides.count,
            totalMiles: totalMiles,
            totalElevationFeet: totalElevation,
            totalMovingSeconds: totalTime,
            avgSpeedMPH: avgSpeed,
            favoriteRoute: favoriteRoute
        )
    }

    /// Rides in the last N days
    func recentRides(days: Int = 30) -> [CompletedRide] {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        return rides.filter { $0.completedAt >= cutoff }
    }

    // MARK: - All-Time Stats

    var allTimeMiles: Double { rides.reduce(0) { $0 + $1.distanceMiles } }
    var allTimeElevationFeet: Double { rides.reduce(0) { $0 + $1.elevationGainFeet } }

    struct PersonalRecords {
        var longestMiles: Double = 0
        var fastestAvgMPH: Double = 0
        var mostElevationFeet: Double = 0
        var longestStreakDays: Int = 0
    }

    var personalRecords: PersonalRecords {
        var pr = PersonalRecords()
        for ride in rides {
            if ride.distanceMiles > pr.longestMiles { pr.longestMiles = ride.distanceMiles }
            if ride.avgSpeedMPH > pr.fastestAvgMPH { pr.fastestAvgMPH = ride.avgSpeedMPH }
            if ride.elevationGainFeet > pr.mostElevationFeet { pr.mostElevationFeet = ride.elevationGainFeet }
        }
        pr.longestStreakDays = longestStreakDays
        return pr
    }

    func monthlyMiles() -> [(month: Date, miles: Double)] {
        let calendar = Calendar.current
        let now = Date()
        var results: [(month: Date, miles: Double)] = []
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        for offset in (0..<12).reversed() {
            guard let monthStart = calendar.date(byAdding: .month, value: -offset, to: currentMonthStart) else { continue }
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
            let miles = rides
                .filter { $0.completedAt >= monthStart && $0.completedAt < monthEnd }
                .reduce(0) { $0 + $1.distanceMiles }
            results.append((month: monthStart, miles: miles))
        }
        return results
    }

    var currentStreakDays: Int {
        let calendar = Calendar.current
        let ridedays = Set(rides.map { calendar.startOfDay(for: $0.completedAt) }).sorted(by: >)
        guard !ridedays.isEmpty else { return 0 }
        let today = calendar.startOfDay(for: Date())
        guard ridedays.first == today || ridedays.first == calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        var streak = 1
        for i in 1..<ridedays.count {
            let expected = calendar.date(byAdding: .day, value: -1, to: ridedays[i - 1])!
            if ridedays[i] == expected { streak += 1 } else { break }
        }
        return streak
    }

    var longestStreakDays: Int {
        let calendar = Calendar.current
        let ridedays = Set(rides.map { calendar.startOfDay(for: $0.completedAt) }).sorted(by: >)
        guard !ridedays.isEmpty else { return 0 }
        var best = 1, current = 1
        for i in 1..<ridedays.count {
            let expected = calendar.date(byAdding: .day, value: -1, to: ridedays[i - 1])!
            if ridedays[i] == expected { current += 1; if current > best { best = current } } else { current = 1 }
        }
        return best
    }

    var milesByCategory: [String: Double] {
        Dictionary(grouping: rides, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.distanceMiles } }
    }

    func updateGPXTrackpoints(rideId: String, trackpoints: [[Double]]) {
        guard let idx = rides.firstIndex(where: { $0.id == rideId }) else { return }
        var updated = rides[idx]
        updated.gpxTrackpoints = trackpoints
        rides[idx] = updated
        persistRides()
    }

    // MARK: - Persistence

    private func loadRides() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CompletedRide].self, from: data) else {
            return
        }
        rides = decoded
    }

    private func persistRides() {
        if let data = try? JSONEncoder().encode(rides) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - Models

struct CompletedRide: Codable, Identifiable {
    let id: String
    let routeId: String
    let routeName: String
    let category: String
    let distanceMiles: Double
    let elapsedSeconds: TimeInterval
    let movingSeconds: TimeInterval
    let elevationGainFeet: Double
    let avgSpeedMPH: Double
    let maxSpeedMPH: Double
    let completedAt: Date

    // Phase 2 additions — optional for backwards compatibility
    var journalId: String?
    var gpxTrackpoints: [[Double]]?
    var heartRateAvg: Double?
    var calories: Double?
    var isTimeTrial: Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        routeId = try c.decode(String.self, forKey: .routeId)
        routeName = try c.decode(String.self, forKey: .routeName)
        category = try c.decode(String.self, forKey: .category)
        distanceMiles = try c.decode(Double.self, forKey: .distanceMiles)
        elapsedSeconds = try c.decode(TimeInterval.self, forKey: .elapsedSeconds)
        movingSeconds = try c.decode(TimeInterval.self, forKey: .movingSeconds)
        elevationGainFeet = try c.decode(Double.self, forKey: .elevationGainFeet)
        avgSpeedMPH = try c.decode(Double.self, forKey: .avgSpeedMPH)
        maxSpeedMPH = try c.decode(Double.self, forKey: .maxSpeedMPH)
        completedAt = try c.decode(Date.self, forKey: .completedAt)
        journalId = try c.decodeIfPresent(String.self, forKey: .journalId)
        gpxTrackpoints = try c.decodeIfPresent([[Double]].self, forKey: .gpxTrackpoints)
        heartRateAvg = try c.decodeIfPresent(Double.self, forKey: .heartRateAvg)
        calories = try c.decodeIfPresent(Double.self, forKey: .calories)
        isTimeTrial = try c.decodeIfPresent(Bool.self, forKey: .isTimeTrial) ?? false
    }

    init(id: String, routeId: String, routeName: String, category: String,
         distanceMiles: Double, elapsedSeconds: TimeInterval, movingSeconds: TimeInterval,
         elevationGainFeet: Double, avgSpeedMPH: Double, maxSpeedMPH: Double,
         completedAt: Date, journalId: String? = nil, gpxTrackpoints: [[Double]]? = nil,
         heartRateAvg: Double? = nil, calories: Double? = nil, isTimeTrial: Bool = false) {
        self.id = id; self.routeId = routeId; self.routeName = routeName
        self.category = category; self.distanceMiles = distanceMiles
        self.elapsedSeconds = elapsedSeconds; self.movingSeconds = movingSeconds
        self.elevationGainFeet = elevationGainFeet; self.avgSpeedMPH = avgSpeedMPH
        self.maxSpeedMPH = maxSpeedMPH; self.completedAt = completedAt
        self.journalId = journalId; self.gpxTrackpoints = gpxTrackpoints
        self.heartRateAvg = heartRateAvg; self.calories = calories
        self.isTimeTrial = isTimeTrial
    }

    var formattedDistance: String {
        String(format: "%.1f mi", distanceMiles)
    }

    var formattedTime: String {
        let h = Int(elapsedSeconds) / 3600
        let m = (Int(elapsedSeconds) % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: completedAt)
    }
}

struct SeasonSummary {
    let year: Int
    let rideCount: Int
    let totalMiles: Double
    let totalElevationFeet: Double
    let totalMovingSeconds: TimeInterval
    let avgSpeedMPH: Double
    let favoriteRoute: String?

    var formattedMiles: String {
        String(format: "%.0f", totalMiles)
    }

    var formattedElevation: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: Int(totalElevationFeet))) ?? "\(Int(totalElevationFeet))") + " ft"
    }

    var formattedTime: String {
        let h = Int(totalMovingSeconds) / 3600
        return "\(h)h"
    }
}
