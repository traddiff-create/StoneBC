//
//  WorkoutService.swift
//  StoneBC
//
//  HealthKit workout recording — saves cycling workouts with GPS route
//  to Apple Health. Users can view rides in Health app, Strava, etc.
//

import HealthKit
import CoreLocation

@Observable
class WorkoutService {
    var isAuthorized = false
    var isRecording = false
    var error: String?

    private let store = HKHealthStore()
    private var workoutBuilder: HKWorkoutBuilder?
    private var routeBuilder: HKWorkoutRouteBuilder?
    private var pendingRouteLocations: [CLLocation] = []
    private var lastQueuedRouteTimestamp: Date?
    private var lastRouteFlushAt: Date = .distantPast
    private var lastRouteFlushLocation: CLLocation?

    /// Set while `endWorkout` is in flight so a concurrent `cancelWorkout`
    /// from a discard / dismiss path becomes a no-op instead of racing
    /// `finishRoute` and tearing down builders mid-await.
    private var isFinishing = false

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else { return }

        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType()
        ]

        do {
            try await store.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            isAuthorized = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Recording

    func startWorkout(routeName: String) async {
        guard isAuthorized, !isRecording else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .outdoor

        do {
            let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
            try await builder.beginCollection(at: Date())

            self.workoutBuilder = builder
            self.routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
            self.pendingRouteLocations = []
            self.lastQueuedRouteTimestamp = nil
            self.lastRouteFlushAt = Date()
            self.lastRouteFlushLocation = nil
            self.isRecording = true
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Feed GPS locations during the ride
    func addRouteData(_ locations: [CLLocation],
                      powerMode: RidePowerMode = .balanced,
                      force: Bool = false) {
        guard isRecording, let routeBuilder else { return }

        // Filter to only high-accuracy points
        let filtered = locations.filter {
            $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy < RideTuning.healthKitMaxAccuracyMeters
        }.filter {
            guard let lastQueuedRouteTimestamp else { return true }
            return $0.timestamp > lastQueuedRouteTimestamp
        }
        guard !filtered.isEmpty else { return }

        pendingRouteLocations.append(contentsOf: filtered)
        lastQueuedRouteTimestamp = pendingRouteLocations.last?.timestamp ?? lastQueuedRouteTimestamp

        guard force || shouldFlushRouteData(powerMode: powerMode) else {
            return
        }

        flushRouteData(using: routeBuilder)
    }

    private func shouldFlushRouteData(powerMode: RidePowerMode) -> Bool {
        guard !pendingRouteLocations.isEmpty else { return false }
        if Date().timeIntervalSince(lastRouteFlushAt) >= powerMode.healthKitBatchInterval {
            return true
        }

        let latest = pendingRouteLocations.last
        let distanceSinceFlush: CLLocationDistance
        if let lastRouteFlushLocation, let latest {
            distanceSinceFlush = latest.distance(from: lastRouteFlushLocation)
        } else if let first = pendingRouteLocations.first, let latest {
            distanceSinceFlush = latest.distance(from: first)
        } else {
            distanceSinceFlush = 0
        }

        return distanceSinceFlush >= powerMode.healthKitBatchDistanceMeters
    }

    private func flushRouteData(using routeBuilder: HKWorkoutRouteBuilder) {
        let batch = pendingRouteLocations
        guard !batch.isEmpty else { return }

        pendingRouteLocations.removeAll()
        lastRouteFlushAt = Date()
        lastRouteFlushLocation = batch.last

        routeBuilder.insertRouteData(batch) { _, error in
            if let error {
                self.error = error.localizedDescription
            }
        }
    }

    /// End the workout and save to HealthKit.
    ///
    /// `endDate` is the wall-clock end of the ride (typically the last accepted
    /// `CLLocation.timestamp` from `RideSession`, not `Date()`). Paused
    /// intervals are passed as `HKWorkoutEvent.pauseOrResume` records so
    /// HealthKit subtracts them from the saved workout duration. Distance is
    /// derived from the attached `HKWorkoutRoute`; the caller no longer needs
    /// to pass a manual cumulative distance sample.
    func endWorkout(endDate: Date,
                    pauseEvents: [(date: Date, isPause: Bool)] = []) async {
        guard isRecording, !isFinishing, let builder = workoutBuilder else { return }

        // Snapshot the builders so an in-flight cancel can't pull the rug
        // out from under us while we're awaiting `finishWorkout` / `finishRoute`.
        let route = routeBuilder
        isFinishing = true
        defer {
            isFinishing = false
            isRecording = false
            workoutBuilder = nil
            routeBuilder = nil
            pendingRouteLocations = []
            lastQueuedRouteTimestamp = nil
            lastRouteFlushLocation = nil
        }

        do {
            if let route {
                try await flushPendingRouteData(using: route)
            }

            if !pauseEvents.isEmpty {
                let events = pauseEvents.map { event in
                    HKWorkoutEvent(
                        type: event.isPause ? .pause : .resume,
                        dateInterval: DateInterval(start: event.date, duration: 0),
                        metadata: nil
                    )
                }
                try await builder.addWorkoutEvents(events)
            }

            try await builder.endCollection(at: endDate)

            guard let workout = try await builder.finishWorkout() else {
                return
            }

            if let route {
                try await route.finishRoute(with: workout, metadata: nil)
            }

            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func flushPendingRouteData(using routeBuilder: HKWorkoutRouteBuilder) async throws {
        let batch = pendingRouteLocations
        guard !batch.isEmpty else { return }

        pendingRouteLocations.removeAll()
        lastRouteFlushAt = Date()
        lastRouteFlushLocation = batch.last

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            routeBuilder.insertRouteData(batch) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "StoneBC.WorkoutService",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "HealthKit rejected route data."]
                        )
                    )
                }
            }
        }
    }

    /// Discard the in-progress workout. No-op while `endWorkout` is running so
    /// we don't race `finishRoute` and end up with a stale `HKWorkoutBuilder`.
    func cancelWorkout() {
        guard !isFinishing else { return }
        workoutBuilder?.discardWorkout()
        workoutBuilder = nil
        routeBuilder = nil
        pendingRouteLocations = []
        lastQueuedRouteTimestamp = nil
        lastRouteFlushLocation = nil
        isRecording = false
    }
}
