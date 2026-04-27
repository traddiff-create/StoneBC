//
//  WorkoutService.swift
//  StoneBC
//
//  HealthKit workout recording — saves cycling workouts with GPS route
//  to Apple Health. Users can view rides in Health app, Strava, etc.
//

import CoreLocation
import HealthKit

protocol WorkoutHealthStoreClient {
    var isHealthDataAvailable: Bool { get }
    func requestAuthorization() async throws
    func makeWorkoutBuilder(configuration: HKWorkoutConfiguration, device: HKDevice?) -> WorkoutBuilderClient
    var distanceCyclingType: HKQuantityType? { get }
}

protocol WorkoutBuilderClient: AnyObject {
    func beginCollection(at date: Date) async throws
    func seriesBuilder(for seriesType: HKSeriesType) -> WorkoutRouteBuilderClient?
    func addWorkoutEvents(_ events: [HKWorkoutEvent]) async throws
    func addSamples(_ samples: [HKSample]) async throws
    func endCollection(at date: Date) async throws
    func finishWorkout() async throws -> HKWorkout?
    func discardWorkout()
}

protocol WorkoutRouteBuilderClient: AnyObject {
    func insertRouteData(_ locations: [CLLocation]) async throws
    func finishRoute(with workout: HKWorkout, metadata: [String: Any]?) async throws
}

@Observable
class WorkoutService {
    var isAuthorized = false
    var isRecording = false
    var error: String?

    private let client: WorkoutHealthStoreClient
    private var workoutBuilder: WorkoutBuilderClient?
    private var routeBuilder: WorkoutRouteBuilderClient?
    private var pendingRouteLocations: [CLLocation] = []
    private var lastQueuedRouteTimestamp: Date?
    private var lastRouteFlushAt: Date = .distantPast
    private var lastRouteFlushLocation: CLLocation?
    private var workoutStartDate: Date?
    private var routeName = "Ride"
    private var isFinishing = false

    init(client: WorkoutHealthStoreClient = HealthKitWorkoutClient()) {
        self.client = client
    }

    var isAvailable: Bool {
        client.isHealthDataAvailable
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else { return }

        do {
            try await client.requestAuthorization()
            isAuthorized = true
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Recording

    func startWorkout(routeName: String, startDate: Date = Date()) async {
        guard isAuthorized, !isRecording else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .outdoor

        do {
            let builder = client.makeWorkoutBuilder(configuration: config, device: .local())
            try await builder.beginCollection(at: startDate)

            self.workoutBuilder = builder
            self.routeBuilder = builder.seriesBuilder(for: HKSeriesType.workoutRoute())
            self.workoutStartDate = startDate
            self.routeName = routeName
            self.lastRouteFlushAt = Date()
            self.lastRouteFlushLocation = nil
            self.isRecording = true
            self.error = nil

            if let routeBuilder {
                try await flushPendingRouteData(using: routeBuilder)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Feed GPS locations during the ride. Accurate points are buffered even
    /// before HealthKit authorization/start completes, then flushed once a
    /// route builder is ready.
    func addRouteData(_ locations: [CLLocation],
                      powerMode: RidePowerMode = .balanced,
                      force: Bool = false) {
        let filtered = locations.filter {
            $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy < RideTuning.healthKitMaxAccuracyMeters
        }.filter {
            guard let lastQueuedRouteTimestamp else { return true }
            return $0.timestamp > lastQueuedRouteTimestamp
        }
        guard !filtered.isEmpty else { return }

        pendingRouteLocations.append(contentsOf: filtered)
        lastQueuedRouteTimestamp = pendingRouteLocations.last?.timestamp ?? lastQueuedRouteTimestamp

        guard isRecording, let routeBuilder, force || shouldFlushRouteData(powerMode: powerMode) else {
            return
        }

        Task {
            do {
                try await flushPendingRouteData(using: routeBuilder)
            } catch {
                self.error = error.localizedDescription
            }
        }
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

    /// End the workout and save to HealthKit.
    func endWorkout(endDate: Date,
                    distanceMeters: Double? = nil,
                    ascentFeet: Double? = nil,
                    pauseEvents: [(date: Date, isPause: Bool)] = []) async {
        guard isRecording, !isFinishing, let builder = workoutBuilder else { return }

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
            workoutStartDate = nil
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

            if let sample = cyclingDistanceSample(distanceMeters: distanceMeters, endDate: endDate) {
                try await builder.addSamples([sample])
            }

            try await builder.endCollection(at: endDate)

            guard let workout = try await builder.finishWorkout() else {
                return
            }

            if let route {
                try await route.finishRoute(
                    with: workout,
                    metadata: routeMetadata(ascentFeet: ascentFeet)
                )
            }

            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func cyclingDistanceSample(distanceMeters: Double?, endDate: Date) -> HKQuantitySample? {
        guard let distanceMeters,
              distanceMeters > 0,
              let workoutStartDate,
              let distanceType = client.distanceCyclingType else {
            return nil
        }

        return HKQuantitySample(
            type: distanceType,
            quantity: HKQuantity(unit: .meter(), doubleValue: distanceMeters),
            start: workoutStartDate,
            end: endDate
        )
    }

    private func routeMetadata(ascentFeet: Double?) -> [String: Any] {
        var metadata: [String: Any] = [
            HKMetadataKeyWorkoutBrandName: "StoneBC",
            "StoneBCRouteName": routeName
        ]
        if let ascentFeet, ascentFeet > 0 {
            metadata[HKMetadataKeyElevationAscended] = HKQuantity(unit: .foot(), doubleValue: ascentFeet)
        }
        return metadata
    }

    private func flushPendingRouteData(using routeBuilder: WorkoutRouteBuilderClient) async throws {
        let batch = pendingRouteLocations
        guard !batch.isEmpty else { return }

        pendingRouteLocations.removeAll()
        lastRouteFlushAt = Date()
        lastRouteFlushLocation = batch.last

        try await routeBuilder.insertRouteData(batch)
    }

    /// Discard the in-progress workout. No-op while `endWorkout` is running so
    /// we don't race `finishRoute` and end up with a stale workout builder.
    func cancelWorkout() {
        guard !isFinishing else { return }
        workoutBuilder?.discardWorkout()
        workoutBuilder = nil
        routeBuilder = nil
        pendingRouteLocations = []
        lastQueuedRouteTimestamp = nil
        lastRouteFlushLocation = nil
        workoutStartDate = nil
        isRecording = false
    }
}

final class HealthKitWorkoutClient: WorkoutHealthStoreClient {
    private let store = HKHealthStore()

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var distanceCyclingType: HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: .distanceCycling)
    }

    func requestAuthorization() async throws {
        var typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        if let distanceCyclingType {
            typesToWrite.insert(distanceCyclingType)
        }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType()
        ]

        try await store.requestAuthorization(toShare: typesToWrite, read: typesToRead)
    }

    func makeWorkoutBuilder(configuration: HKWorkoutConfiguration, device: HKDevice?) -> WorkoutBuilderClient {
        HealthKitWorkoutBuilderClient(
            builder: HKWorkoutBuilder(healthStore: store, configuration: configuration, device: device)
        )
    }
}

final class HealthKitWorkoutBuilderClient: WorkoutBuilderClient {
    private let builder: HKWorkoutBuilder

    init(builder: HKWorkoutBuilder) {
        self.builder = builder
    }

    func beginCollection(at date: Date) async throws {
        try await builder.beginCollection(at: date)
    }

    func seriesBuilder(for seriesType: HKSeriesType) -> WorkoutRouteBuilderClient? {
        guard let routeBuilder = builder.seriesBuilder(for: seriesType) as? HKWorkoutRouteBuilder else {
            return nil
        }
        return HealthKitWorkoutRouteBuilderClient(builder: routeBuilder)
    }

    func addWorkoutEvents(_ events: [HKWorkoutEvent]) async throws {
        try await builder.addWorkoutEvents(events)
    }

    func addSamples(_ samples: [HKSample]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add(samples) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "StoneBC.WorkoutService",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "HealthKit rejected workout samples."]
                        )
                    )
                }
            }
        }
    }

    func endCollection(at date: Date) async throws {
        try await builder.endCollection(at: date)
    }

    func finishWorkout() async throws -> HKWorkout? {
        try await builder.finishWorkout()
    }

    func discardWorkout() {
        builder.discardWorkout()
    }
}

final class HealthKitWorkoutRouteBuilderClient: WorkoutRouteBuilderClient {
    private let builder: HKWorkoutRouteBuilder

    init(builder: HKWorkoutRouteBuilder) {
        self.builder = builder
    }

    func insertRouteData(_ locations: [CLLocation]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.insertRouteData(locations) { success, error in
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

    func finishRoute(with workout: HKWorkout, metadata: [String: Any]?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.finishRoute(with: workout, metadata: metadata) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
