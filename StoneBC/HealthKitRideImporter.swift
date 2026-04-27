import Foundation
import HealthKit
import CoreLocation

@Observable
class HealthKitRideImporter {
    static let shared = HealthKitRideImporter()

    private(set) var isImporting = false
    private(set) var importedCount = 0

    private let store = HKHealthStore()
    private let importedKey = "hkImportComplete"

    private init() {}

    var needsImport: Bool {
        !UserDefaults.standard.bool(forKey: importedKey)
    }

    func runIfNeeded() {
        guard needsImport, !isImporting else { return }
        Task { await run() }
    }

    private func run() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            markComplete()
            return
        }

        let workoutType = HKObjectType.workoutType()
        let routeType = HKSeriesType.workoutRoute()

        do {
            try await store.requestAuthorization(toShare: [], read: [workoutType, routeType])
        } catch {
            markComplete()
            return
        }

        await MainActor.run { isImporting = true }

        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: twoYearsAgo, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let workouts = await fetchWorkouts(predicate: predicate, sort: sort)
        let rides = RideHistoryService.shared.rides

        var updates: [(CompletedRide, [[Double]], [Date])] = []
        for workout in workouts {
            guard workout.workoutActivityType == .cycling else { continue }
            guard let match = findMatchingRide(workout: workout, in: rides) else { continue }
            guard match.gpxTrackpoints == nil else { continue }

            if let routeData = await fetchRouteTrackpoints(for: workout) {
                updates.append((match, routeData.trackpoints, routeData.timestamps))
            }
        }

        await MainActor.run {
            for (match, trackpoints, timestamps) in updates {
                var updated = match
                updated.gpxTrackpoints = trackpoints
                updated.gpxTrackpointTimestamps = timestamps
                RideHistoryService.shared.update(updated)
            }
            importedCount = updates.count
            isImporting = false
        }
        markComplete()
    }

    private func fetchWorkouts(predicate: NSPredicate, sort: NSSortDescriptor) async -> [HKWorkout] {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
    }

    private func findMatchingRide(workout: HKWorkout, in rides: [CompletedRide]) -> CompletedRide? {
        let hkMiles = workout.totalDistance?.doubleValue(for: .mile()) ?? 0
        let hkDate = workout.startDate

        return rides.first { ride in
            let timeDiff = abs(ride.completedAt.timeIntervalSince(hkDate))
            let distanceDiff = abs(ride.distanceMiles - hkMiles) / max(hkMiles, 0.1)
            return timeDiff < 600 && distanceDiff < 0.15
        }
    }

    private func fetchRouteTrackpoints(for workout: HKWorkout) async -> (trackpoints: [[Double]], timestamps: [Date])? {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        let routes: [HKWorkoutRoute] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            store.execute(query)
        }

        guard let route = routes.first else { return nil }

        var locations: [CLLocation] = []
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKWorkoutRouteQuery(route: route) { _, newLocations, done, _ in
                if let newLocations { locations.append(contentsOf: newLocations) }
                if done { continuation.resume() }
            }
            store.execute(query)
        }

        guard locations.count >= 2 else { return nil }
        return (
            locations.map { [$0.coordinate.latitude, $0.coordinate.longitude, $0.altitude] },
            locations.map(\.timestamp)
        )
    }

    private func markComplete() {
        UserDefaults.standard.set(true, forKey: importedKey)
    }
}
