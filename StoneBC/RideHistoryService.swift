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

    func recordRide(
        routeId: String,
        routeName: String,
        category: String,
        distanceMiles: Double,
        elapsedSeconds: TimeInterval,
        movingSeconds: TimeInterval,
        elevationGainFeet: Double,
        avgSpeedMPH: Double,
        maxSpeedMPH: Double
    ) {
        let ride = CompletedRide(
            id: UUID().uuidString,
            routeId: routeId,
            routeName: routeName,
            category: category,
            distanceMiles: distanceMiles,
            elapsedSeconds: elapsedSeconds,
            movingSeconds: movingSeconds,
            elevationGainFeet: elevationGainFeet,
            avgSpeedMPH: avgSpeedMPH,
            maxSpeedMPH: maxSpeedMPH,
            completedAt: Date()
        )

        rides.insert(ride, at: 0)

        if rides.count > maxRides {
            rides = Array(rides.prefix(maxRides))
        }

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
