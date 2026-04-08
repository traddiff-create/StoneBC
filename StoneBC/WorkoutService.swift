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
        let filtered = locations.filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy < 50 }
        guard !filtered.isEmpty else { return }

        routeBuilder.insertRouteData(filtered) { success, error in
            if let error {
                self.error = error.localizedDescription
            }
        }
    }

    /// End the workout and save to HealthKit
    func endWorkout(distance: Double, duration: TimeInterval) async {
        guard isRecording, let builder = workoutBuilder else { return }

        do {
            // End collection
            try await builder.endCollection(at: Date())

            // Add distance sample
            let distanceQuantity = HKQuantity(unit: .mile(), doubleValue: distance)
            let distanceSample = HKQuantityType(.distanceCycling)
            let startDate = builder.startDate ?? Date().addingTimeInterval(-duration)
            let sample = HKCumulativeQuantitySample(
                type: distanceSample,
                quantity: distanceQuantity,
                start: startDate,
                end: Date()
            )
            try await builder.addSamples([sample])

            // Finish workout
            guard let workout = try await builder.finishWorkout() else {
                isRecording = false
                return
            }

            // Attach route to workout
            if let routeBuilder {
                try await routeBuilder.finishRoute(with: workout, metadata: nil)
            }

            isRecording = false
            workoutBuilder = nil
            self.routeBuilder = nil
            error = nil
        } catch {
            self.error = error.localizedDescription
            isRecording = false
        }
    }

    func cancelWorkout() {
        workoutBuilder?.discardWorkout()
        workoutBuilder = nil
        routeBuilder = nil
        isRecording = false
    }
}
