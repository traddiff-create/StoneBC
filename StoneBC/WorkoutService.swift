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
            self.isRecording = true
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Feed GPS locations during the ride
    func addRouteData(_ locations: [CLLocation]) {
        guard isRecording, let routeBuilder else { return }

        // Filter to only high-accuracy points
        let filtered = locations.filter {
            $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy < RideTuning.healthKitMaxAccuracyMeters
        }
        guard !filtered.isEmpty else { return }

        routeBuilder.insertRouteData(filtered) { success, error in
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
        }

        do {
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

    /// Discard the in-progress workout. No-op while `endWorkout` is running so
    /// we don't race `finishRoute` and end up with a stale `HKWorkoutBuilder`.
    func cancelWorkout() {
        guard !isFinishing else { return }
        workoutBuilder?.discardWorkout()
        workoutBuilder = nil
        routeBuilder = nil
        isRecording = false
    }
}
