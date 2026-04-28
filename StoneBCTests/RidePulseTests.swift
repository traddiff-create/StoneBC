import XCTest
@testable import StoneBC

final class RidePulseTests: XCTestCase {
    func testSnapshotRoundTripsAndDetectsStaleState() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = RidePulseSnapshot(
            routeId: "route-1",
            routeName: "Skyline",
            rideState: .recording,
            updatedAt: updatedAt,
            effectiveStartedAt: updatedAt.addingTimeInterval(-600),
            pausedAt: nil,
            speedMPH: 12.3,
            distanceTraveledMiles: 4.5,
            distanceRemainingMiles: 6.7,
            progressPercent: 0.42,
            nextCueText: "Turn right",
            nextCueDistanceMeters: 180,
            isOffRoute: false,
            isCriticalOffRoute: false,
            safetyState: .active,
            powerMode: .balanced,
            phoneBatteryLevel: 0.8,
            phoneLowPowerModeEnabled: false,
            lastKnownCoordinate: RidePulseCoordinate(latitude: 44.081, longitude: -103.231),
            activeJournalId: "journal-1",
            activeJournalName: "8 Over 7",
            activeJournalDayNumber: 2,
            checkInDeadline: updatedAt.addingTimeInterval(1_800)
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(RidePulseSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertFalse(decoded.isStale(now: updatedAt.addingTimeInterval(RidePulseConstants.staleAfter - 1)))
        XCTAssertTrue(decoded.isStale(now: updatedAt.addingTimeInterval(RidePulseConstants.staleAfter)))
    }

    func testWatchRideCommandRoundTrips() throws {
        let command = WatchRideCommand(
            id: "command-1",
            kind: .journalText,
            createdAt: Date(timeIntervalSince1970: 2_000),
            text: "Saw fresh gravel on the ridge.",
            coordinate: RidePulseCoordinate(latitude: 44.1, longitude: -103.2),
            journalId: "journal-1",
            journalDayNumber: 1
        )

        let data = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(WatchRideCommand.self, from: data)

        XCTAssertEqual(decoded, command)
    }

    func testCommandQueuePersistsAndRemovesAcceptedCommands() {
        let suiteName = "RidePulseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let queue = RidePulseCommandQueue(key: "commands", defaults: defaults)
        let first = WatchRideCommand(id: "first", kind: .checkIn)
        let second = WatchRideCommand(id: "second", kind: .openEmergencyHandoff)

        queue.enqueue(first)
        queue.enqueue(first)
        queue.enqueue(second)
        XCTAssertEqual(queue.load(), [first, second])

        queue.remove(ids: Set(["first"]))
        XCTAssertEqual(queue.load(), [second])

        queue.clear()
        XCTAssertTrue(queue.load().isEmpty)
    }

    func testThrottleUsesPowerModeCadence() {
        let now = Date()
        let snapshot = snapshot(
            updatedAt: now,
            distanceTraveledMiles: 1.0,
            powerMode: .balanced
        )

        XCTAssertTrue(RidePulseThrottle.shouldPublish(
            snapshot: snapshot,
            lastPublishedAt: nil,
            lastPublishedDistanceMiles: 0,
            force: false
        ))
        XCTAssertFalse(RidePulseThrottle.shouldPublish(
            snapshot: snapshot,
            lastPublishedAt: now.addingTimeInterval(-60),
            lastPublishedDistanceMiles: 0.9,
            force: false
        ))
        XCTAssertTrue(RidePulseThrottle.shouldPublish(
            snapshot: snapshot,
            lastPublishedAt: now.addingTimeInterval(-120),
            lastPublishedDistanceMiles: 0.9,
            force: false
        ))
        XCTAssertTrue(RidePulseThrottle.shouldPublish(
            snapshot: snapshot,
            lastPublishedAt: now.addingTimeInterval(-10),
            lastPublishedDistanceMiles: 0.7,
            force: false
        ))
        XCTAssertTrue(RidePulseThrottle.shouldPublish(
            snapshot: snapshot,
            lastPublishedAt: now,
            lastPublishedDistanceMiles: 1.0,
            force: true
        ))
    }

    @MainActor
    func testCoordinatorPublishesForcedPulseWithInjectedPublisher() {
        let publisher = FakeRidePulsePublisher()
        let coordinator = RideRecordingCoordinator(
            route: testRoute,
            recordingMode: .follow,
            pulsePublisher: publisher
        )

        coordinator.publishWatchPulse(force: true, events: [.rideEnded])

        XCTAssertEqual(publisher.published.count, 1)
        XCTAssertTrue(publisher.published[0].force)
        XCTAssertEqual(publisher.published[0].events, [.rideEnded])
        XCTAssertEqual(publisher.published[0].snapshot.routeName, "Test Route")
    }

    @MainActor
    func testCommandProcessorRefreshesSafetyCheckIn() async {
        let suiteName = "RidePulseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            EmergencySafetyService.shared.stopCheckInTimer()
        }

        let queue = RidePulseCommandQueue(key: "phoneCommands", defaults: defaults)
        let processor = RidePulseCommandProcessor(defaults: defaults, pendingQueue: queue)
        EmergencySafetyService.shared.startCheckInTimer(routeName: "Test", interval: 3_600)
        let previousCheckIn = EmergencySafetyService.shared.lastCheckInAt

        await processor.receive(WatchRideCommand(id: "check-in", kind: .checkIn))

        XCTAssertTrue(queue.load().isEmpty)
        XCTAssertNotNil(EmergencySafetyService.shared.lastCheckInAt)
        XCTAssertNotEqual(EmergencySafetyService.shared.lastCheckInAt, previousCheckIn)
    }

    @MainActor
    func testCommandProcessorAppendsDictatedJournalEntry() async {
        let suiteName = "RidePulseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let journalId = "watch-command-\(UUID().uuidString)"
        let journal = testJournal(id: journalId)
        await ExpeditionStorage.shared.save(journal)

        let queue = RidePulseCommandQueue(key: "phoneCommands", defaults: defaults)
        let processor = RidePulseCommandProcessor(defaults: defaults, pendingQueue: queue)
        let command = WatchRideCommand(
            id: "journal-entry",
            kind: .journalText,
            text: "Dictated from the watch.",
            coordinate: RidePulseCoordinate(latitude: 44.2, longitude: -103.3),
            journalId: journalId,
            journalDayNumber: 1
        )

        await processor.receive(command)

        let updated = await ExpeditionStorage.shared.load(id: journalId)
        XCTAssertTrue(queue.load().isEmpty)
        XCTAssertEqual(updated?.days.first?.entries.count, 1)
        XCTAssertEqual(updated?.days.first?.entries.first?.text, "Dictated from the watch.")
        XCTAssertEqual(updated?.days.first?.entries.first?.coordinate, [44.2, -103.3])
        XCTAssertEqual(updated?.days.first?.entries.first?.source, .iphone)

        await ExpeditionStorage.shared.delete(id: journalId)
    }

    @MainActor
    func testCommandProcessorLeavesJournalCommandPendingWithoutActiveExpedition() async {
        let suiteName = "RidePulseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let queue = RidePulseCommandQueue(key: "phoneCommands", defaults: defaults)
        let processor = RidePulseCommandProcessor(defaults: defaults, pendingQueue: queue)
        let command = WatchRideCommand(
            id: "missing-journal",
            kind: .journalText,
            text: "Hold this until the phone has the journal.",
            journalId: "missing-\(UUID().uuidString)",
            journalDayNumber: 1
        )

        await processor.receive(command)

        XCTAssertEqual(queue.load(), [command])
    }

    private func snapshot(
        updatedAt: Date,
        distanceTraveledMiles: Double,
        powerMode: RidePulseSnapshot.PowerMode
    ) -> RidePulseSnapshot {
        RidePulseSnapshot(
            routeId: "route-1",
            routeName: "Route",
            rideState: .recording,
            updatedAt: updatedAt,
            effectiveStartedAt: nil,
            pausedAt: nil,
            speedMPH: 10,
            distanceTraveledMiles: distanceTraveledMiles,
            distanceRemainingMiles: 5,
            progressPercent: 0.5,
            nextCueText: nil,
            nextCueDistanceMeters: nil,
            isOffRoute: false,
            isCriticalOffRoute: false,
            safetyState: .active,
            powerMode: powerMode,
            phoneBatteryLevel: nil,
            phoneLowPowerModeEnabled: false
        )
    }

    private var testRoute: Route {
        Route(
            id: "test-route",
            name: "Test Route",
            difficulty: "easy",
            category: "gravel",
            distanceMiles: 1.0,
            elevationGainFeet: 20,
            region: "Test",
            description: "Test",
            startCoordinate: .init(latitude: 44.0, longitude: -103.0),
            trackpoints: [
                [44.0, -103.0, 0],
                [44.0, -102.999, 0],
                [44.0, -102.998, 0]
            ]
        )
    }

    private func testJournal(id: String) -> ExpeditionJournal {
        ExpeditionJournal(
            id: id,
            guideId: "guide",
            name: "Test Expedition",
            leaderName: "StoneBC",
            status: .active,
            startDate: Date(),
            endDate: nil,
            days: [
                JournalDay(
                    dayNumber: 1,
                    entries: [],
                    gpxFilename: nil,
                    gpxTrackpoints: nil,
                    summary: nil,
                    actualMiles: nil,
                    actualElevation: nil,
                    weatherNote: nil,
                    waterNote: nil,
                    foodNote: nil,
                    shelterNote: nil,
                    sunsetNote: nil
                )
            ],
            contributions: [],
            coverPhotoId: nil
        )
    }
}

@MainActor
private final class FakeRidePulsePublisher: RidePulsePublishing {
    struct Published {
        let snapshot: RidePulseSnapshot
        let force: Bool
        let events: [RidePulseEvent]
    }

    var published: [Published] = []

    func start() {}

    func publish(snapshot: RidePulseSnapshot, force: Bool, events: [RidePulseEvent]) {
        published.append(Published(snapshot: snapshot, force: force, events: events))
    }
}
