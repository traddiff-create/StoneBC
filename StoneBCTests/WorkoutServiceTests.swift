import CoreLocation
import HealthKit
import XCTest
@testable import StoneBC

final class WorkoutServiceTests: XCTestCase {
    func testBuffersRouteDataUntilWorkoutStarts() async {
        let client = FakeWorkoutHealthStoreClient()
        let service = WorkoutService(client: client)
        let start = Date()
        let first = location(longitude: -103.0, timestamp: start)

        service.addRouteData([first])
        await service.requestAuthorization()
        await service.startWorkout(routeName: "Ride", startDate: start)

        XCTAssertTrue(client.didRequestAuthorization)
        XCTAssertEqual(client.builder.beginDates, [start])
        XCTAssertEqual(client.builder.seriesBuilderTypes.first?.identifier, HKSeriesType.workoutRoute().identifier)
        XCTAssertEqual(client.builder.routeBuilder.insertedLocations, [first])
    }

    func testEndWorkoutFlushesRouteDistanceEventsAndMetadata() async throws {
        let client = FakeWorkoutHealthStoreClient()
        let service = WorkoutService(client: client)
        let start = Date()
        let end = start.addingTimeInterval(60)
        let first = location(longitude: -103.0, timestamp: start)
        let second = location(longitude: -102.999, timestamp: start.addingTimeInterval(30))

        service.addRouteData([first])
        await service.requestAuthorization()
        await service.startWorkout(routeName: "Ride", startDate: start)
        service.addRouteData([second])

        await service.endWorkout(
            endDate: end,
            distanceMeters: 1234,
            ascentFeet: 42,
            pauseEvents: [
                (date: start.addingTimeInterval(10), isPause: true),
                (date: start.addingTimeInterval(20), isPause: false)
            ]
        )

        XCTAssertEqual(client.builder.routeBuilder.insertedLocations, [first, second])
        XCTAssertEqual(client.builder.events.map(\.type), [.pause, .resume])
        XCTAssertEqual(client.builder.endDates, [end])
        XCTAssertEqual(client.builder.finishWorkoutCalls, 1)
        XCTAssertTrue(client.builder.routeBuilder.didFinishRoute)
        XCTAssertFalse(service.isRecording)

        let distance = try XCTUnwrap(client.builder.samples.compactMap { $0 as? HKQuantitySample }.first)
        XCTAssertEqual(distance.quantity.doubleValue(for: .meter()), 1234, accuracy: 0.1)

        let ascent = try XCTUnwrap(client.builder.routeBuilder.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)
        XCTAssertEqual(ascent.doubleValue(for: .foot()), 42, accuracy: 0.1)
    }

    func testCancelDoesNotDiscardWhileFinishIsInFlight() async {
        let client = FakeWorkoutHealthStoreClient()
        client.builder.finishDelayNanoseconds = 100_000_000
        let service = WorkoutService(client: client)
        let start = Date()

        service.addRouteData([location(longitude: -103.0, timestamp: start)])
        await service.requestAuthorization()
        await service.startWorkout(routeName: "Ride", startDate: start)

        let finishTask = Task {
            await service.endWorkout(endDate: start.addingTimeInterval(10), distanceMeters: 10)
        }
        try? await Task.sleep(nanoseconds: 10_000_000)
        service.cancelWorkout()
        await finishTask.value

        XCTAssertFalse(client.builder.didDiscard)
        XCTAssertFalse(service.isRecording)
    }

    private func location(longitude: Double, timestamp: Date) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 44.0, longitude: longitude),
            altitude: 100,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: -1,
            speed: 5,
            timestamp: timestamp
        )
    }
}

private final class FakeWorkoutHealthStoreClient: WorkoutHealthStoreClient {
    var isHealthDataAvailable = true
    var didRequestAuthorization = false
    var builder = FakeWorkoutBuilderClient()
    var distanceCyclingType: HKQuantityType? = HKObjectType.quantityType(forIdentifier: .distanceCycling)

    func requestAuthorization() async throws {
        didRequestAuthorization = true
    }

    func makeWorkoutBuilder(configuration: HKWorkoutConfiguration, device: HKDevice?) -> WorkoutBuilderClient {
        builder.configuration = configuration
        builder.device = device
        return builder
    }
}

private final class FakeWorkoutBuilderClient: WorkoutBuilderClient {
    var configuration: HKWorkoutConfiguration?
    var device: HKDevice?
    var beginDates: [Date] = []
    var seriesBuilderTypes: [HKSeriesType] = []
    var routeBuilder = FakeWorkoutRouteBuilderClient()
    var events: [HKWorkoutEvent] = []
    var samples: [HKSample] = []
    var endDates: [Date] = []
    var finishWorkoutCalls = 0
    var didDiscard = false
    var finishDelayNanoseconds: UInt64 = 0

    func beginCollection(at date: Date) async throws {
        beginDates.append(date)
    }

    func seriesBuilder(for seriesType: HKSeriesType) -> WorkoutRouteBuilderClient? {
        seriesBuilderTypes.append(seriesType)
        return routeBuilder
    }

    func addWorkoutEvents(_ events: [HKWorkoutEvent]) async throws {
        self.events.append(contentsOf: events)
    }

    func addSamples(_ samples: [HKSample]) async throws {
        self.samples.append(contentsOf: samples)
    }

    func endCollection(at date: Date) async throws {
        endDates.append(date)
    }

    func finishWorkout() async throws -> HKWorkout? {
        finishWorkoutCalls += 1
        if finishDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: finishDelayNanoseconds)
        }
        let start = beginDates.first ?? Date()
        let end = endDates.last ?? start.addingTimeInterval(1)
        return HKWorkout(activityType: .cycling, start: start, end: end)
    }

    func discardWorkout() {
        didDiscard = true
    }
}

private final class FakeWorkoutRouteBuilderClient: WorkoutRouteBuilderClient {
    var insertedLocations: [CLLocation] = []
    var didFinishRoute = false
    var metadata: [String: Any]?

    func insertRouteData(_ locations: [CLLocation]) async throws {
        insertedLocations.append(contentsOf: locations)
    }

    func finishRoute(with workout: HKWorkout, metadata: [String: Any]?) async throws {
        didFinishRoute = true
        self.metadata = metadata
    }
}
