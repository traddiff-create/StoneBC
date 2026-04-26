//
//  RideTuning.swift
//  StoneBC
//
//  Single source of truth for ride/recording tuning constants. Consolidates
//  filter thresholds, timing values, and Live Activity cadence so the
//  unified `RideSession` and `WorkoutService` agree on the same gates.
//

import CoreLocation
import Foundation

enum RideTuning {
    /// Seconds below `autoPauseSpeedMPH` that trigger an auto-pause. The magic 7 —
    /// Strava's 3 s clips real rolling stops at lights.
    static let autoPauseSeconds: TimeInterval = 7

    /// Speed below which we start counting toward auto-pause.
    static let autoPauseSpeedMPH: Double = 1.0

    /// Speed at which an auto-paused session resumes on its own.
    static let autoResumeSpeedMPH: Double = 2.0

    /// GPS-jitter filter: ignore segments shorter than this distance (m).
    static let jitterFilterMeters: CLLocationDistance = 3

    /// Reject route jumps that imply an impossible bicycle speed.
    static let maxSegmentSpeedMPS: Double = 30

    /// Drop low-confidence GPS points from the ride engine.
    static let maxHorizontalAccuracyMeters: CLLocationAccuracy = 75

    /// Stricter accuracy ceiling for HealthKit route insertion (Apple's
    /// Workouts app uses ~50 m).
    static let healthKitMaxAccuracyMeters: CLLocationAccuracy = 50

    /// Elevation noise filter for ascent gain (positive deltas only).
    static let ascentDeadbandFeet: Double = 3

    /// Vertical accuracy ceiling for any altitude reading we trust.
    static let usableVerticalAccuracyMeters: CLLocationAccuracy = 30

    /// Vertical accuracy below which barometer baseline is recalibrated.
    static let recalibrationVerticalAccuracyMeters: CLLocationAccuracy = 10

    /// Fraction of the GPS-vs-fused delta blended into the baseline on
    /// recalibration. Low value avoids step-changes.
    static let recalibrationBlendFactor: Double = 0.2

    /// Distance from the active route at which we **enter** off-route state.
    /// Hysteresis pair with `offRouteExitMeters` prevents banner / audio flicker
    /// when a rider hovers near the threshold.
    static let offRouteEnterMeters: Double = 60

    /// Distance from the active route at which we **clear** off-route state.
    /// Must be lower than `offRouteEnterMeters` to give meaningful hysteresis.
    static let offRouteExitMeters: Double = 35

    /// Distance from the active route at which we surface a critical alert.
    static let criticallyOffRouteMeters: Double = 150

    /// Live Activity stale-date window — iOS uses this to render a stale visual
    /// treatment if the activity has not refreshed recently.
    static let liveActivityStaleSeconds: TimeInterval = 30

    /// Minimum interval between Live Activity update calls. Throttles app-driven
    /// updates well below iOS 18's enforced ceiling so the system never drops them.
    static let liveActivityUpdateIntervalSeconds: TimeInterval = 5.0

    /// Force a Live Activity update once accumulated distance since the last
    /// push exceeds this many meters, even if the time floor hasn't elapsed —
    /// keeps the lock-screen distance reading honest at speed.
    static let liveActivityUpdateMinDistanceMeters: Double = 25

    /// Relevance score for the Dynamic Island stack when the rider is off-route —
    /// promotes the activity above other Live Activities.
    static let liveActivityOffRouteRelevance: Double = 100

    /// Default relevance score during a normal ride.
    static let liveActivityNormalRelevance: Double = 50
}
