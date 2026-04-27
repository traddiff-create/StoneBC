//
//  RideSession.swift
//  StoneBC
//
//  Unified ride engine. Handles two ride flavors behind one type:
//
//    .freeRecording — recording a brand-new track for "Save as Route"
//    .followingRoute(Route) — riding an existing GPX route (off-route detection,
//                              progress %, distance remaining, cue surfacing)
//
//  Both flavors share the same clock, GPS acceptance gate, distance
//  accumulator, and auto-pause state machine. Removed the foreground 1Hz
//  Timer that previously lived here and in RecordingService — elapsed time
//  is now derived from `startedAt`, `totalPausedSeconds`, and `pausedAt`,
//  so SwiftUI views render it with `Text(timerInterval:pauseTime:)` and
//  the lock-screen widget renders it with the same primitive.
//

import Foundation
import CoreLocation

@Observable
class RideSession {

    enum Mode {
        case freeRecording
        case followingRoute(Route)

        var route: Route? {
            if case .followingRoute(let r) = self { return r }
            return nil
        }
    }

    enum State {
        case idle, recording, paused, stopped

        var isLive: Bool { self == .recording || self == .paused }
    }

    let mode: Mode
    private let activeTrackStore = ActiveRideTrackStore()

    /// Convenience accessor — preserves the old `RideSession.route` API for
    /// view sites that haven't been migrated to mode-aware switches yet.
    /// Returns the active route in `.followingRoute` mode, nil in `.freeRecording`.
    var route: Route? { mode.route }

    // MARK: - State

    var state: State = .idle
    var trackpoints: [CLLocation] = []
    var startedAt: Date?

    /// Set while in `.paused`. Consumed by SwiftUI's `Text(timerInterval:pauseTime:)`
    /// and by the Live Activity widget so the lock-screen counter freezes
    /// without us pushing every-second updates.
    var pausedAt: Date?

    // Stats
    var elapsedSeconds: TimeInterval = 0
    var movingSeconds: TimeInterval = 0
    var distanceMeters: Double = 0
    var totalAscentFeet: Double = 0
    var maxSpeedMPH: Double = 0
    var avgSpeedMPH: Double = 0

    // Follow-mode state (always present; meaningful only in `.followingRoute`)
    var closestTrackpointIndex: Int = 0
    var progressPercent: Double = 0
    var distanceRemainingMiles: Double = 0
    var distanceFromRouteMeters: Double = 0

    /// Off-route flag with hysteresis (see `RideTuning.offRouteEnter/ExitMeters`).
    /// Backing storage is `_isOffRoute` so we control the transition logic.
    private(set) var isOffRoute: Bool = false
    var isCriticallyOffRoute: Bool {
        distanceFromRouteMeters > RideTuning.criticallyOffRouteMeters
    }

    // Callbacks the view subscribes to for audio cues, haptics, etc.
    var onAutoPause: (() -> Void)?
    var onAutoResume: (() -> Void)?

    /// Optional fused-altitude provider (typically `AltimeterService.fusedAltitudeMeters`).
    /// Falls back to raw `location.altitude` when nil.
    var altitudeProvider: (() -> Double?)?

    /// Last accepted location — exposed for route-progress observers.
    private(set) var lastLocation: CLLocation?

    /// Pause/resume events keyed by wall-clock timestamp. Consumed by
    /// `WorkoutService` to feed `HKWorkoutEvent` records so HealthKit subtracts
    /// paused intervals from the workout duration.
    enum PauseEventKind { case pause, resume }
    private(set) var pauseEvents: [(date: Date, kind: PauseEventKind)] = []

    // Internal
    private var lastElevationMeters: Double?
    private var lastIngestTimestamp: Date?
    private var belowThresholdSince: Date?
    private var pausedStartedAt: Date?
    private(set) var totalPausedSeconds: TimeInterval = 0
    private var movingSpeedSum: Double = 0
    private var movingSpeedSamples: Int = 0

    // Follow-mode windowed-search constant — full route scan is O(n);
    // riding ~10K-trackpoint routes makes that prohibitive at every GPS tick.
    private let searchWindow = 100

    // MARK: - Init

    init(mode: Mode = .freeRecording) {
        self.mode = mode
        if let route = mode.route {
            distanceRemainingMiles = route.distanceMiles
        }
    }

    /// Backwards-compat init for callers that pass a `Route` directly.
    convenience init(route: Route) {
        self.init(mode: .followingRoute(route))
    }

    // MARK: - Lifecycle

    var isActive: Bool { state.isLive }

    func start() {
        let now = Date()
        state = .recording
        startedAt = now
        pausedAt = nil
        trackpoints.removeAll()
        activeTrackStore.startSession()
        elapsedSeconds = 0
        movingSeconds = 0
        distanceMeters = 0
        totalAscentFeet = 0
        maxSpeedMPH = 0
        avgSpeedMPH = 0
        lastLocation = nil
        lastElevationMeters = nil
        lastIngestTimestamp = nil
        belowThresholdSince = nil
        pausedStartedAt = nil
        totalPausedSeconds = 0
        movingSpeedSum = 0
        movingSpeedSamples = 0
        closestTrackpointIndex = 0
        progressPercent = 0
        distanceFromRouteMeters = 0
        isOffRoute = false
        if let route = mode.route {
            distanceRemainingMiles = route.distanceMiles
        } else {
            distanceRemainingMiles = 0
        }
        pauseEvents.removeAll()
    }

    func pause(at date: Date = Date()) {
        guard state == .recording else { return }
        refreshElapsed(at: date)
        state = .paused
        pausedStartedAt = date
        pausedAt = date
        pauseEvents.append((date: date, kind: .pause))
    }

    func resume(at date: Date = Date()) {
        guard state == .paused else { return }
        if let pausedStartedAt {
            totalPausedSeconds += max(0, date.timeIntervalSince(pausedStartedAt))
        }
        state = .recording
        self.pausedStartedAt = nil
        self.pausedAt = nil
        belowThresholdSince = nil
        lastIngestTimestamp = nil
        pauseEvents.append((date: date, kind: .resume))
        refreshElapsed(at: date)
    }

    func stop() {
        refreshElapsed()
        state = .stopped
        activeTrackStore.close()
    }

    // MARK: - Location ingest

    /// Feed every accepted `CLLocation` from `LocationService` here. Runs the
    /// shared recording pipeline (auto-pause, distance, ascent, speed); when
    /// the session is following a route, additionally updates progress and
    /// off-route state.
    func ingestLocation(_ location: CLLocation) {
        guard isUsable(location) else { return }

        let timestamp = location.timestamp
        refreshElapsed(at: timestamp)

        let speedMPS = measuredSpeed(for: location)
        let speedMPH = speedMPS * 2.23694

        switch state {
        case .recording:
            let deltaSeconds = acceptedDeltaSeconds(at: timestamp)

            // Auto-pause: sustained low speed
            if speedMPH < RideTuning.autoPauseSpeedMPH {
                if let since = belowThresholdSince {
                    if timestamp.timeIntervalSince(since) >= RideTuning.autoPauseSeconds {
                        pause(at: timestamp)
                        onAutoPause?()
                        return
                    }
                } else {
                    belowThresholdSince = timestamp
                }
            } else {
                belowThresholdSince = nil
                movingSeconds += deltaSeconds
            }

            // Distance accumulate with jitter filter
            if let last = lastLocation {
                let delta = location.distance(from: last)
                let elapsed = max(location.timestamp.timeIntervalSince(last.timestamp), 1)
                let segmentSpeed = delta / elapsed
                if delta > RideTuning.jitterFilterMeters, segmentSpeed <= RideTuning.maxSegmentSpeedMPS {
                    distanceMeters += delta
                }
            }

            // Ascent — fused altitude when available, positive deltas, deadband
            let altitudeMeters = currentAltitudeMeters(for: location)
            if let altitudeMeters, let lastEle = lastElevationMeters {
                let deltaFeet = (altitudeMeters - lastEle) * 3.28084
                if deltaFeet > RideTuning.ascentDeadbandFeet {
                    totalAscentFeet += deltaFeet
                }
            }
            if let altitudeMeters {
                lastElevationMeters = altitudeMeters
            }

            // Speed stats — only count while actually moving
            if speedMPH > maxSpeedMPH { maxSpeedMPH = speedMPH }
            if speedMPH > RideTuning.autoPauseSpeedMPH {
                movingSpeedSum += speedMPH
                movingSpeedSamples += 1
                avgSpeedMPH = movingSpeedSum / Double(movingSpeedSamples)
            }

            appendAcceptedTrackpoint(location)
            lastLocation = location
            lastIngestTimestamp = timestamp

            // Follow-mode progress + off-route only updates while recording
            updateRouteProgress(for: location)

        case .paused:
            // Auto-resume when rider clearly starts moving again
            if speedMPH >= RideTuning.autoResumeSpeedMPH {
                resume(at: timestamp)
                onAutoResume?()
                appendAcceptedTrackpoint(location)
                lastLocation = location
                lastIngestTimestamp = timestamp
                if let altitudeMeters = currentAltitudeMeters(for: location) {
                    lastElevationMeters = altitudeMeters
                }
                updateRouteProgress(for: location)
            }

        case .idle, .stopped:
            break
        }
    }

    /// Backward-compat alias used by `RouteNavigationView`.
    func updateLocation(_ location: CLLocation) {
        ingestLocation(location)
    }

    /// Backward-compat alias used by simulators / testing harnesses that supply
    /// a coordinate + speed without a full `CLLocation`.
    func updateLocation(_ coordinate: CLLocationCoordinate2D, speed: Double) {
        let location = CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: -1,
            course: -1,
            speed: speed,
            timestamp: Date()
        )
        ingestLocation(location)
    }

    // MARK: - Follow-mode helpers

    private func updateRouteProgress(for location: CLLocation) {
        guard let route = mode.route else { return }
        let trackpoints = route.clTrackpoints
        guard !trackpoints.isEmpty else { return }

        // Closest-point search with a moving window. Falls back to a full scan
        // when off-route or first-fix so the rider doesn't get stuck at index 0.
        let userCL = CLLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        var minDist = Double.greatestFiniteMagnitude
        var minIdx = closestTrackpointIndex

        let needsFullScan = isOffRoute || closestTrackpointIndex == 0
        let lo = needsFullScan ? 0 : max(0, closestTrackpointIndex - searchWindow)
        let hi = needsFullScan
            ? trackpoints.count - 1
            : min(trackpoints.count - 1, closestTrackpointIndex + searchWindow)

        for i in lo...hi {
            let pt = trackpoints[i]
            let d = userCL.distance(from: CLLocation(latitude: pt.latitude, longitude: pt.longitude))
            if d < minDist {
                minDist = d
                minIdx = i
            }
        }

        closestTrackpointIndex = minIdx
        distanceFromRouteMeters = minDist
        progressPercent = Double(minIdx) / Double(max(trackpoints.count - 1, 1))

        if minIdx < route.trackpoints.count {
            let remaining = Array(route.trackpoints[minIdx...])
            distanceRemainingMiles = Route.haversineDistance(remaining)
        }

        // Hysteresis transition — banner / audio cooldowns key off this flag,
        // so we damp the raw distance with `offRouteEnterMeters` going up and
        // `offRouteExitMeters` coming back down.
        if !isOffRoute, distanceFromRouteMeters > RideTuning.offRouteEnterMeters {
            isOffRoute = true
        } else if isOffRoute, distanceFromRouteMeters < RideTuning.offRouteExitMeters {
            isOffRoute = false
        }
    }

    func bearingToNextWaypoint(from coordinate: CLLocationCoordinate2D) -> Double? {
        guard let route = mode.route else { return nil }
        let lookAheadIdx = min(closestTrackpointIndex + 10, route.clTrackpoints.count - 1)
        guard lookAheadIdx > closestTrackpointIndex else { return nil }
        return bearing(from: coordinate, to: route.clTrackpoints[lookAheadIdx])
    }

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)

        return (radians * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Filters

    private func isUsable(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= RideTuning.maxHorizontalAccuracyMeters else {
            return false
        }
        return location.timestamp <= Date().addingTimeInterval(5)
    }

    private func hasUsableAltitude(_ location: CLLocation) -> Bool {
        location.verticalAccuracy >= 0
            && location.verticalAccuracy <= RideTuning.usableVerticalAccuracyMeters
    }

    private func currentAltitudeMeters(for location: CLLocation) -> Double? {
        if let fused = altitudeProvider?() {
            return fused
        }
        return hasUsableAltitude(location) ? location.altitude : nil
    }

    private func measuredSpeed(for location: CLLocation) -> Double {
        if location.speed >= 0 {
            return location.speed
        }
        guard let lastLocation else { return 0 }
        let elapsed = location.timestamp.timeIntervalSince(lastLocation.timestamp)
        guard elapsed > 0.5 else { return 0 }
        return location.distance(from: lastLocation) / elapsed
    }

    private func acceptedDeltaSeconds(at timestamp: Date) -> TimeInterval {
        guard let lastIngestTimestamp else { return 0 }
        let delta = timestamp.timeIntervalSince(lastIngestTimestamp)
        return min(max(delta, 0), 10)
    }

    private func appendAcceptedTrackpoint(_ location: CLLocation) {
        activeTrackStore.append(location)
        trackpoints.append(location)
        if trackpoints.count > RideTuning.maxInMemoryTrackpoints {
            trackpoints.removeFirst(trackpoints.count - RideTuning.maxInMemoryTrackpoints)
        }
    }

    private func refreshElapsed(at now: Date = Date()) {
        guard let startedAt else {
            elapsedSeconds = 0
            return
        }
        let currentPausedSeconds: TimeInterval
        if state == .paused, let pausedStartedAt {
            currentPausedSeconds = max(0, now.timeIntervalSince(pausedStartedAt))
        } else {
            currentPausedSeconds = 0
        }
        elapsedSeconds = max(0, now.timeIntervalSince(startedAt) - totalPausedSeconds - currentPausedSeconds)
    }

    // MARK: - Live Activity / Widget timer source

    /// Effective start moment for `Text(timerInterval:pauseTime:)`. Slides
    /// forward by `totalPausedSeconds` so the displayed counter shows
    /// **active** duration (excluding pauses) without us having to push
    /// every-second updates.
    var effectiveStartedAt: Date? {
        guard let startedAt else { return nil }
        return startedAt.addingTimeInterval(totalPausedSeconds)
    }

    // MARK: - Formatting / aliases

    var distanceMiles: Double { distanceMeters / 1609.344 }

    /// Backwards-compat alias used by `RouteNavigationView` and the Live Activity bridge.
    var distanceTraveledMiles: Double { distanceMiles }

    var formattedElapsed: String {
        let h = Int(elapsedSeconds) / 3600
        let m = (Int(elapsedSeconds) % 3600) / 60
        let s = Int(elapsedSeconds) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// Alias preserved for `RouteNavigationView` and journal/share view sites.
    var formattedElapsedTime: String { formattedElapsed }

    var formattedMovingTime: String {
        let h = Int(movingSeconds) / 3600
        let m = (Int(movingSeconds) % 3600) / 60
        let s = Int(movingSeconds) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    var formattedDistance: String {
        String(format: "%.2f mi", distanceMiles)
    }

    var formattedRemaining: String {
        String(format: "%.1f mi", distanceRemainingMiles)
    }

    /// `[[lat, lon, ele], ...]` shape the `Route` model expects.
    var routeTrackpointTriples: [[Double]] {
        let persisted = activeTrackStore.readTrackpointTriples()
        guard !persisted.isEmpty else {
            return trackpoints.map {
                [$0.coordinate.latitude, $0.coordinate.longitude, $0.altitude]
            }
        }
        return persisted
    }

    var exportLocations: [CLLocation] {
        let persisted = activeTrackStore.readLocations()
        return persisted.isEmpty ? trackpoints : persisted
    }

    /// Recording is "saveable as a new Route" once it has at least 2 trackpoints.
    var isSaveable: Bool { activeTrackStore.count >= 2 || trackpoints.count >= 2 }
}

final class ActiveRideTrackStore {
    private(set) var url: URL?
    private(set) var count = 0
    private var handle: FileHandle?

    func startSession() {
        close()
        count = 0

        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = baseURL.appendingPathComponent("ActiveRideTracks", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileURL = directory.appendingPathComponent("\(UUID().uuidString).csv")
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        handle = try? FileHandle(forWritingTo: fileURL)
        url = fileURL
    }

    func append(_ location: CLLocation) {
        guard let handle else { return }

        let line = String(
            format: "%.3f,%.8f,%.8f,%.2f,%.1f,%.1f,%.3f,%.1f\n",
            locale: Locale(identifier: "en_US_POSIX"),
            location.timestamp.timeIntervalSince1970,
            location.coordinate.latitude,
            location.coordinate.longitude,
            location.altitude,
            location.horizontalAccuracy,
            location.verticalAccuracy,
            location.speed,
            location.course
        )
        if let data = line.data(using: .utf8) {
            handle.write(data)
            count += 1
        }
    }

    func readTrackpointTriples() -> [[Double]] {
        guard let url,
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        return contents.split(separator: "\n").compactMap { row -> [Double]? in
            let values = parsedValues(from: row)
            guard values.count >= 4 else { return nil }
            return [values[1], values[2], values[3]]
        }
    }

    func readLocations() -> [CLLocation] {
        guard let url,
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        return contents.split(separator: "\n").compactMap { row -> CLLocation? in
            let values = parsedValues(from: row)
            guard values.count >= 8 else { return nil }
            return CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: values[1], longitude: values[2]),
                altitude: values[3],
                horizontalAccuracy: values[4],
                verticalAccuracy: values[5],
                course: values[7],
                speed: values[6],
                timestamp: Date(timeIntervalSince1970: values[0])
            )
        }
    }

    func close() {
        handle?.synchronizeFile()
        try? handle?.close()
        handle = nil
    }

    private func parsedValues(from row: Substring) -> [Double] {
        row.split(separator: ",").compactMap { Double($0) }
    }
}
