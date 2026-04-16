//
//  RecordingService.swift
//  StoneBC
//
//  GPS-recording state machine for route recording. Handles start / pause /
//  resume / stop, trackpoint accumulation, distance / ascent / speed stats,
//  and auto-pause detection tuned to 7 s — Strava's 3 s is twitchy on rides
//  with frequent short stops. Seven seconds lets a rolling pause at a light
//  feel real without getting unfairly clipped.
//

import Foundation
import CoreLocation

@Observable
class RecordingService {
    enum State {
        case idle, recording, paused, stopped

        var isLive: Bool { self == .recording || self == .paused }
    }

    // MARK: - Tuning

    /// Seconds below `autoPauseSpeedMPH` that trigger an auto-pause. The magic 7.
    static let autoPauseThreshold: TimeInterval = 7
    /// Speed below which we start counting toward auto-pause.
    static let autoPauseSpeedMPH: Double = 1.0
    /// Speed at which an auto-paused session resumes on its own.
    static let autoResumeSpeedMPH: Double = 2.0
    /// GPS-jitter filter: ignore segments shorter than this distance (m).
    static let jitterFilterMeters: Double = 3

    // MARK: - State

    var state: State = .idle
    var trackpoints: [CLLocation] = []
    var startedAt: Date?

    // Derived stats
    var elapsedSeconds: TimeInterval = 0
    var movingSeconds: TimeInterval = 0
    var distanceMeters: Double = 0
    var totalAscentFeet: Double = 0
    var maxSpeedMPH: Double = 0
    var avgSpeedMPH: Double = 0

    // Callbacks the view can subscribe to for audio cues, haptics, etc.
    var onAutoPause: (() -> Void)?
    var onAutoResume: (() -> Void)?

    // Internal
    private var timer: Timer?
    private var lastTrackpoint: CLLocation?
    private var lastElevationMeters: Double?
    private var belowThresholdSince: Date?
    private var movingSpeedSum: Double = 0
    private var movingSpeedSamples: Int = 0

    // MARK: - Lifecycle

    func start() {
        state = .recording
        startedAt = Date()
        trackpoints.removeAll()
        elapsedSeconds = 0
        movingSeconds = 0
        distanceMeters = 0
        totalAscentFeet = 0
        maxSpeedMPH = 0
        avgSpeedMPH = 0
        lastTrackpoint = nil
        lastElevationMeters = nil
        belowThresholdSince = nil
        movingSpeedSum = 0
        movingSpeedSamples = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.state == .recording else { return }
            self.elapsedSeconds += 1
        }
    }

    func pause() {
        guard state == .recording else { return }
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        state = .recording
        belowThresholdSince = nil
    }

    func stop() {
        state = .stopped
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Location ingest

    /// Feed every `CLLocation` update from `LocationService` into here.
    /// Handles distance accumulation, ascent, auto-pause, auto-resume, and
    /// speed stats. Called from the view's `.onChange(of:)` GPS tick.
    func ingestLocation(_ location: CLLocation) {
        let speedMPH = location.speed >= 0 ? location.speed * 2.23694 : 0

        switch state {
        case .recording:
            // Auto-pause: sustained low speed
            if speedMPH < Self.autoPauseSpeedMPH {
                if let since = belowThresholdSince {
                    if Date().timeIntervalSince(since) >= Self.autoPauseThreshold {
                        pause()
                        onAutoPause?()
                        return
                    }
                } else {
                    belowThresholdSince = Date()
                }
            } else {
                belowThresholdSince = nil
                movingSeconds += 1
            }

            // Distance accumulate with 3 m jitter filter
            if let last = lastTrackpoint {
                let delta = location.distance(from: last)
                if delta > Self.jitterFilterMeters {
                    distanceMeters += delta
                }
            }

            // Ascent — positive elevation deltas only, 1 ft deadband
            if let lastEle = lastElevationMeters, location.verticalAccuracy >= 0 {
                let deltaFeet = (location.altitude - lastEle) * 3.28084
                if deltaFeet > 1 {
                    totalAscentFeet += deltaFeet
                }
            }
            if location.verticalAccuracy >= 0 {
                lastElevationMeters = location.altitude
            }

            // Speed stats — only count while actually moving
            if speedMPH > maxSpeedMPH { maxSpeedMPH = speedMPH }
            if speedMPH > Self.autoPauseSpeedMPH {
                movingSpeedSum += speedMPH
                movingSpeedSamples += 1
                avgSpeedMPH = movingSpeedSum / Double(movingSpeedSamples)
            }

            trackpoints.append(location)
            lastTrackpoint = location

        case .paused:
            // Auto-resume when rider clearly starts moving again
            if speedMPH >= Self.autoResumeSpeedMPH {
                resume()
                onAutoResume?()
            }

        case .idle, .stopped:
            break
        }
    }

    // MARK: - Formatting

    var distanceMiles: Double { distanceMeters / 1609.344 }

    var formattedElapsed: String {
        let h = Int(elapsedSeconds) / 3600
        let m = (Int(elapsedSeconds) % 3600) / 60
        let s = Int(elapsedSeconds) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    var formattedDistance: String {
        String(format: "%.2f mi", distanceMiles)
    }

    /// Converts recorded `CLLocation` trackpoints to the `[[lat, lon, ele], ...]`
    /// shape the `Route` model expects when saving as a route template.
    var routeTrackpointTriples: [[Double]] {
        trackpoints.map {
            [$0.coordinate.latitude, $0.coordinate.longitude, $0.altitude]
        }
    }

    /// Can this recording become a saved route? Needs at least 2 points.
    var isSaveable: Bool { trackpoints.count >= 2 }
}
