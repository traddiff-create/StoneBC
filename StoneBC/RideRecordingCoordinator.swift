//
//  RideRecordingCoordinator.swift
//  StoneBC
//

import CoreLocation
import Foundation
import UIKit

@Observable
@MainActor
final class RideRecordingCoordinator {
    enum LifecycleState {
        case preflighting
        case ready
        case recording
        case frozen
        case saved
        case discarded
    }

    let route: Route?
    let routeId: String?
    let routeName: String?
    let recordingMode: RouteRecordingMode
    let ridePreferences: RouteRidePreferences

    let locationService = LocationService()
    let altimeterService = AltimeterService()
    let audioService = NavigationAudioService()
    let workoutService = WorkoutService()
    let activityManager = RideActivityManager()
    let safetyService = EmergencySafetyService.shared
    let recording: RideSession

    var lifecycleState: LifecycleState = .preflighting
    var powerMode: RidePowerMode = .balanced
    var preflightMessage = "Preparing GPS"
    var lastPreflightError: String?
    var precomputedTurns: [TurnPoint] = []
    var wasOffRoute = false
    var frozenSnapshot: RideRecordingSnapshot?
    var offlineRouteReady = false
    var offlineTilesReady = false
    var weatherCacheReady = false

    private var didStartPreflight = false
    private var didStartRecording = false
    private var didStartWorkoutTask = false
    private var frozenEndDate: Date?

    init(
        route: Route? = nil,
        routeId: String? = nil,
        routeName: String? = nil,
        recordingMode: RouteRecordingMode = .free,
        ridePreferences: RouteRidePreferences? = nil
    ) {
        self.route = route
        self.routeId = route?.id ?? routeId
        self.routeName = route?.name ?? routeName
        self.recordingMode = route == nil && recordingMode == .follow ? .free : recordingMode
        self.ridePreferences = ridePreferences ?? RouteRidePreferences.load(route: route)
        if recordingMode == .follow, let route {
            recording = RideSession(route: route)
        } else {
            recording = RideSession(mode: .freeRecording)
        }
    }

    var title: String {
        routeName ?? route?.name ?? recordingMode.label
    }

    var canStart: Bool {
        guard isRecordingSupportedDevice else { return false }
        guard route?.isNavigable ?? true else { return false }
        guard locationService.authorizationStatus == .authorizedWhenInUse ||
                locationService.authorizationStatus == .authorizedAlways else { return false }
        guard !locationService.isReducedAccuracy else { return false }
        guard let location = locationService.lastLocation else { return false }
        return isUsableRideFix(location)
    }

    var preflightRows: [RecordingPreflightRow] {
        [
            RecordingPreflightRow(
                title: "Device",
                detail: deviceDetail,
                state: isRecordingSupportedDevice ? .ready : .blocked,
                icon: "iphone"
            ),
            RecordingPreflightRow(
                title: "Location",
                detail: locationDetail,
                state: locationState,
                icon: "location.fill"
            ),
            RecordingPreflightRow(
                title: "Precise GPS",
                detail: preciseLocationDetail,
                state: locationService.isReducedAccuracy ? .blocked : .ready,
                icon: "scope"
            ),
            RecordingPreflightRow(
                title: "First GPS Fix",
                detail: gpsFixDetail,
                state: gpsFixState,
                icon: "dot.radiowaves.left.and.right"
            ),
            RecordingPreflightRow(
                title: "Barometer",
                detail: altimeterService.isAvailable ? "Ready for climb and grade" : "Not available on this device",
                state: altimeterService.isAvailable ? .ready : .optional,
                icon: "gauge.with.needle"
            ),
            RecordingPreflightRow(
                title: "Health",
                detail: workoutService.isAvailable ? "Workout save available after authorization" : "HealthKit unavailable",
                state: workoutService.isAvailable ? .optional : .optional,
                icon: "heart.fill"
            ),
            RecordingPreflightRow(
                title: "Route",
                detail: route?.isNavigable == false ? "Route needs at least two trackpoints" : routeStatusDetail,
                state: route?.isNavigable == false ? .blocked : .ready,
                icon: "point.topleft.down.to.point.bottomright.curvepath"
            ),
            RecordingPreflightRow(
                title: "Offline Route",
                detail: offlineRouteDetail,
                state: route == nil ? .optional : (offlineRouteReady ? .ready : .warning),
                icon: "arrow.down.circle"
            ),
            RecordingPreflightRow(
                title: "Offline Tiles",
                detail: offlineTilesReady ? "Offline map tiles ready" : "Map tiles may need network or cache",
                state: route == nil ? .optional : (offlineTilesReady ? .ready : .warning),
                icon: "map"
            ),
            RecordingPreflightRow(
                title: "Cue Readiness",
                detail: cueReadinessDetail,
                state: route == nil ? .optional : .ready,
                icon: "arrow.turn.up.right"
            )
        ]
    }

    func startPreflight() {
        guard !didStartPreflight else { return }
        didStartPreflight = true
        lifecycleState = .preflighting
        locationService.requestPermission()
        locationService.startTracking(
            mode: .foreground,
            powerMode: .balanced,
            wantsHeadingUpdates: false
        )
        refreshPreflightStatus()
        refreshOfflineReadiness()
    }

    func refreshPreflightStatus() {
        if canStart {
            lifecycleState = .ready
            preflightMessage = "Ready to record"
            lastPreflightError = nil
        } else {
            lifecycleState = .preflighting
            preflightMessage = nextPreflightMessage()
            lastPreflightError = blockingPreflightDetail()
        }
    }

    func stopPreflightIfNeeded() {
        guard !didStartRecording else { return }
        locationService.stopTracking()
    }

    func startRecording() {
        guard !didStartRecording, canStart else { return }
        didStartRecording = true
        lifecycleState = .recording

        locationService.onFirstAltitude = { [altimeterService] gpsAltitude in
            altimeterService.calibrateWithGPS(altitudeMeters: gpsAltitude)
        }
        recording.altitudeProvider = { [altimeterService] in
            altimeterService.bestRecordingAltitudeMeters
        }
        locationService.startTracking(
            mode: .ride,
            powerMode: powerMode,
            wantsHeadingUpdates: powerMode.usesHeadingUpdates,
            resetSessionStats: false
        )
        altimeterService.start()
        audioService.configure(for: powerMode)
        audioService.reset()
        recording.onAutoPause = { [audioService] in audioService.announcePaused() }
        recording.onAutoResume = { [audioService] in audioService.announceResumed() }

        recording.start()
        if let location = locationService.lastLocation, isUsableRideFix(location) {
            recording.ingestLocation(location)
            workoutService.addRouteData([location], powerMode: powerMode, force: true)
        }

        if let route {
            precomputedTurns = RouteAnalysisService.analyzeTurns(for: route)
        }
        if ridePreferences.enabledOverlays.contains(.safetyCheckIn) {
            safetyService.startCheckInTimer(routeName: title)
        }
        activityManager.startActivity(
            routeName: title,
            distanceMiles: route?.distanceMiles ?? 0,
            category: route?.category ?? "recording",
            rideStartedAt: recording.startedAt ?? Date()
        )
        startWorkoutIfAvailable()
    }

    func handleLocationTick() {
        guard lifecycleState == .recording,
              let location = locationService.lastLocation else { return }

        altimeterService.recalibrateIfPossible(
            gpsAltitudeMeters: location.altitude,
            verticalAccuracy: location.verticalAccuracy
        )
        recording.ingestLocation(location)
        locationService.setRideStationary(recording.state == .paused)
        workoutService.addRouteData([location], powerMode: powerMode)
        handleRouteFollowEvents()
        updateLiveActivity()
    }

    func togglePause() {
        switch recording.state {
        case .recording:
            recording.pause()
            locationService.setRideStationary(true)
            updateLiveActivity(force: true)
        case .paused:
            recording.resume()
            locationService.setRideStationary(false)
            updateLiveActivity(force: true)
        default:
            break
        }
    }

    func freezeForSave() {
        guard lifecycleState == .recording else { return }
        frozenEndDate = recording.lastLocation?.timestamp ?? Date()
        frozenSnapshot = RideRecordingSnapshot(
            routeId: routeId,
            routeName: title,
            recordingMode: recordingMode,
            sourceRoute: route,
            category: route?.category ?? "gravel",
            difficulty: route?.difficulty ?? "moderate",
            region: route?.region ?? "Recorded",
            startedAt: recording.startedAt ?? Date(),
            endedAt: frozenEndDate ?? Date(),
            locations: recording.exportLocations,
            distanceMeters: recording.distanceMeters,
            elapsedSeconds: recording.elapsedSeconds,
            movingSeconds: recording.movingSeconds,
            totalAscentFeet: recording.totalAscentFeet,
            avgSpeedMPH: recording.avgSpeedMPH,
            maxSpeedMPH: recording.maxSpeedMPH,
            pauseEvents: recording.pauseEvents.map { ($0.date, $0.kind == .pause) }
        )
        recording.stop()
        stopActiveSensors()
        if let effectiveStart = recording.effectiveStartedAt {
            activityManager.endActivity(
                finalDistance: recording.distanceMiles,
                rideStartedAt: effectiveStart,
                pausedAt: recording.pausedAt
            )
        }
        lifecycleState = .frozen
    }

    func discardRecording() {
        stopActiveSensors()
        recording.stop()
        workoutService.cancelWorkout()
        frozenSnapshot = nil
        lifecycleState = .discarded
    }

    func handleDisappear() {
        if lifecycleState == .recording || lifecycleState == .preflighting || lifecycleState == .ready {
            discardRecording()
        }
    }

    func finishWorkoutAfterSave() async {
        guard lifecycleState == .frozen, let snapshot = frozenSnapshot else { return }
        await workoutService.endWorkout(
            endDate: snapshot.endedAt,
            distanceMeters: snapshot.distanceMeters,
            ascentFeet: snapshot.totalAscentFeet,
            pauseEvents: snapshot.pauseEvents
        )
        lifecycleState = .saved
    }

    private func startWorkoutIfAvailable() {
        guard workoutService.isAvailable, !didStartWorkoutTask else { return }
        didStartWorkoutTask = true
        Task {
            await workoutService.requestAuthorization()
            await workoutService.startWorkout(routeName: title, startDate: recording.startedAt ?? Date())
            if let location = locationService.lastLocation {
                workoutService.addRouteData([location], powerMode: powerMode, force: true)
            }
        }
    }

    private func refreshOfflineReadiness() {
        guard let route else { return }
        Task {
            let offlineIndex = await OfflineRouteStorage.shared.loadIndex()
            let cached = offlineIndex.first { $0.routeId == route.id }
            let tilePack = await OfflineTilePackManager.shared.installedPack(forRouteId: route.id)
            offlineRouteReady = cached != nil
            offlineTilesReady = tilePack != nil || cached?.tilesAvailable == true
            weatherCacheReady = cached?.hasWeather == true
        }
    }

    private func stopActiveSensors() {
        locationService.stopTracking()
        altimeterService.stop()
        safetyService.stopCheckInTimer()
    }

    private func updateLiveActivity(force: Bool = false) {
        guard let effectiveStart = recording.effectiveStartedAt else { return }
        activityManager.updateActivity(
            speedMPH: locationService.speedMPH,
            distanceTraveled: recording.distanceMiles,
            distanceRemaining: route == nil ? 0 : recording.distanceRemainingMiles,
            rideStartedAt: effectiveStart,
            pausedAt: recording.pausedAt,
            progress: route == nil ? 0 : recording.progressPercent,
            isOffRoute: route == nil ? false : recording.isOffRoute,
            heading: locationService.navigationHeading,
            powerMode: powerMode,
            force: force
        )
    }

    private func handleRouteFollowEvents() {
        guard route != nil else { return }
        let offRouteFlipped = recording.isOffRoute != wasOffRoute

        if recording.isOffRoute, ridePreferences.enabledOverlays.contains(.offRouteAlerts) {
            locationService.requestTemporaryPrecisionBoost()
            if !wasOffRoute || recording.isCriticallyOffRoute {
                audioService.announceOffRoute(distanceMeters: recording.distanceFromRouteMeters)
                wasOffRoute = true
            }
        } else if wasOffRoute {
            audioService.announceBackOnRoute()
            wasOffRoute = false
        }

        audioService.checkMilestone(
            distanceMiles: recording.distanceMiles,
            totalMiles: route?.distanceMiles ?? recording.distanceMiles
        )

        if ridePreferences.enabledOverlays.contains(.cues),
           let route,
           let nextTurn = RouteAnalysisService.nextTurn(
            from: recording.closestTrackpointIndex,
            in: precomputedTurns
           ) {
            let distance = RouteAnalysisService.distanceToTurn(
                from: recording.closestTrackpointIndex,
                to: nextTurn,
                trackpoints: route.clTrackpoints
            )
            if distance < 200 && distance > 10 {
                locationService.requestTemporaryPrecisionBoost()
                audioService.announceTurn(direction: nextTurn.direction, distanceAhead: distance)
            }
        }

        if offRouteFlipped {
            updateLiveActivity(force: true)
        }
    }

    private func isUsableRideFix(_ location: CLLocation) -> Bool {
        location.horizontalAccuracy >= 0
            && location.horizontalAccuracy <= RideTuning.maxHorizontalAccuracyMeters
            && abs(location.timestamp.timeIntervalSinceNow) < 60
    }

    private var isRecordingSupportedDevice: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    private var deviceDetail: String {
        isRecordingSupportedDevice ? "iPhone ride recording ready" : "Ride recording is iPhone-only for this phase"
    }

    private var locationState: RecordingPreflightState {
        switch locationService.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return .ready
        case .denied, .restricted:
            return .blocked
        case .notDetermined:
            return .waiting
        @unknown default:
            return .waiting
        }
    }

    private var gpsFixState: RecordingPreflightState {
        guard let location = locationService.lastLocation else { return .waiting }
        return isUsableRideFix(location) ? .ready : .waiting
    }

    private var locationDetail: String {
        switch locationService.authorizationStatus {
        case .authorizedWhenInUse:
            return "When In Use active ride tracking"
        case .authorizedAlways:
            return "Authorized"
        case .denied, .restricted:
            return "Enable Location in Settings"
        case .notDetermined:
            return "Waiting for permission"
        @unknown default:
            return "Checking authorization"
        }
    }

    private var preciseLocationDetail: String {
        locationService.isReducedAccuracy ? "Turn on Precise Location for ride recording" : "Precise Location is on"
    }

    private var gpsFixDetail: String {
        if let issue = locationService.locationIssueDescription {
            return issue
        }
        guard let location = locationService.lastLocation else {
            return "Waiting for first GPS point"
        }
        if isUsableRideFix(location) {
            return String(format: "±%.0f m", location.horizontalAccuracy)
        }
        return String(format: "Improving accuracy: ±%.0f m", location.horizontalAccuracy)
    }

    private var routeStatusDetail: String {
        if let route {
            return "\(route.formattedDistance) ready"
        }
        return "Free ride or scout recording"
    }

    private var offlineRouteDetail: String {
        guard route != nil else { return "No route needed for free or scout recording" }
        if offlineRouteReady {
            return weatherCacheReady ? "Route and weather cached" : "Route geometry cached"
        }
        return "Route works from bundled data; offline cache optional"
    }

    private var cueReadinessDetail: String {
        guard let route else { return "No route cues needed" }
        return route.cuePoints.isEmpty ? "Generated turn cues available from route shape" : "\(route.cuePoints.count) authored cues ready"
    }

    private func nextPreflightMessage() -> String {
        if !isRecordingSupportedDevice { return "Ride recording needs iPhone" }
        if route?.isNavigable == false { return "Route is not navigable" }
        if locationState == .blocked { return "Location permission is blocked" }
        if locationService.isReducedAccuracy { return "Precise Location is required" }
        if gpsFixState != .ready { return "Waiting for a usable GPS fix" }
        return "Checking sensors"
    }

    private func blockingPreflightDetail() -> String? {
        if !isRecordingSupportedDevice { return "Use an iPhone to record active rides." }
        if route?.isNavigable == false { return "Choose a route with at least two trackpoints." }
        if locationState == .blocked { return "Open Settings and allow Location access for StoneBC." }
        if locationService.isReducedAccuracy { return "Open Settings and enable Precise Location." }
        if gpsFixState != .ready { return gpsFixDetail }
        return nil
    }
}

enum RecordingPreflightState {
    case ready
    case waiting
    case warning
    case optional
    case blocked
}

struct RecordingPreflightRow: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let state: RecordingPreflightState
    let icon: String
}

struct RideRecordingSnapshot: Identifiable {
    let id = UUID()
    let routeId: String?
    let routeName: String
    let recordingMode: RouteRecordingMode
    let sourceRoute: Route?
    let category: String
    let difficulty: String
    let region: String
    let startedAt: Date
    let endedAt: Date
    let locations: [CLLocation]
    let distanceMeters: Double
    let elapsedSeconds: TimeInterval
    let movingSeconds: TimeInterval
    let totalAscentFeet: Double
    let avgSpeedMPH: Double
    let maxSpeedMPH: Double
    let pauseEvents: [(date: Date, isPause: Bool)]

    var distanceMiles: Double { distanceMeters / 1609.344 }
    var isSaveable: Bool { locations.count >= 2 }

    var formattedDistance: String {
        String(format: "%.2f mi", distanceMiles)
    }

    var formattedElapsed: String {
        let h = Int(elapsedSeconds) / 3600
        let m = (Int(elapsedSeconds) % 3600) / 60
        let s = Int(elapsedSeconds) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    var routeTrackpointTriples: [[Double]] {
        locations.map {
            [$0.coordinate.latitude, $0.coordinate.longitude, $0.altitude]
        }
    }

    var trackpointTimestamps: [Date] {
        locations.map(\.timestamp)
    }

    var exportTrackpoints: [RouteTrackPoint] {
        var distance: Double = 0
        var previous: CLLocation?
        return locations.map { location in
            if let previous {
                distance += location.distance(from: previous)
            }
            previous = location
            return RouteTrackPoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                elevationMeters: location.altitude,
                timestamp: location.timestamp,
                distanceMeters: distance,
                speedMetersPerSecond: location.speed >= 0 ? location.speed : nil
            )
        }
    }
}
