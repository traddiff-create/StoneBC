//
//  RideActivityManager.swift
//  StoneBC
//
//  Manages the Live Activity lifecycle — start, update, end.
//  Called from RouteNavigationView during rides.
//

import ActivityKit
import Foundation

@Observable
class RideActivityManager {
    var isActivityActive = false
    private var activity: Activity<RideActivityAttributes>?

    /// Last update push timestamp — used to throttle calls to `Activity.update`
    /// so we sit comfortably below iOS 18's enforced ceiling.
    private var lastUpdatePushedAt: Date = .distantPast

    /// Cumulative distance (miles) at the moment of the last update push —
    /// new pushes compare against this so we can force an update once the
    /// rider has covered `RideTuning.liveActivityUpdateMinDistanceMeters`,
    /// keeping lock-screen distance honest at speed.
    private var lastPushedCumulativeMiles: Double = 0

    func startActivity(routeName: String, distanceMiles: Double, category: String, rideStartedAt: Date = Date()) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = RideActivityAttributes(
            routeName: routeName,
            routeDistanceMiles: distanceMiles,
            category: category
        )

        let initialState = RideActivityAttributes.ContentState(
            speedMPH: 0,
            distanceTraveledMiles: 0,
            distanceRemainingMiles: distanceMiles,
            rideStartedAt: rideStartedAt,
            pausedAt: nil,
            progressPercent: 0,
            isOffRoute: false,
            heading: 0
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(
                    state: initialState,
                    staleDate: .now.addingTimeInterval(RideTuning.liveActivityStaleSeconds),
                    relevanceScore: RideTuning.liveActivityNormalRelevance
                ),
                pushType: nil
            )
            isActivityActive = true
            lastUpdatePushedAt = .now
            lastPushedCumulativeMiles = 0
        } catch {
            // Live Activities not available on this device/OS
        }
    }

    /// Push an update, honoring the throttle floor. Pass `force: true` to bypass
    /// the floor (used for off-route transitions where freshness matters).
    ///
    /// `rideStartedAt` should already encode total paused time (i.e. the
    /// "effective" start) so `Text(timerInterval:pauseTime:)` in the widget
    /// renders active duration without us pushing every-second updates.
    func updateActivity(
        speedMPH: Double,
        distanceTraveled: Double,
        distanceRemaining: Double,
        rideStartedAt: Date,
        pausedAt: Date?,
        progress: Double,
        isOffRoute: Bool,
        heading: Double,
        force: Bool = false
    ) {
        guard let activity, isActivityActive else { return }

        let now = Date()
        let elapsedSinceLast = now.timeIntervalSince(lastUpdatePushedAt)
        let metersSinceLast = max(0, distanceTraveled - lastPushedCumulativeMiles) * 1609.344
        let underTimeFloor = elapsedSinceLast < RideTuning.liveActivityUpdateIntervalSeconds
        let underDistanceFloor = metersSinceLast < RideTuning.liveActivityUpdateMinDistanceMeters

        if !force && underTimeFloor && underDistanceFloor {
            return
        }

        let state = RideActivityAttributes.ContentState(
            speedMPH: speedMPH,
            distanceTraveledMiles: distanceTraveled,
            distanceRemainingMiles: distanceRemaining,
            rideStartedAt: rideStartedAt,
            pausedAt: pausedAt,
            progressPercent: progress,
            isOffRoute: isOffRoute,
            heading: heading
        )

        let relevance = isOffRoute
            ? RideTuning.liveActivityOffRouteRelevance
            : RideTuning.liveActivityNormalRelevance

        lastUpdatePushedAt = now
        lastPushedCumulativeMiles = distanceTraveled

        Task {
            await activity.update(
                .init(
                    state: state,
                    staleDate: now.addingTimeInterval(RideTuning.liveActivityStaleSeconds),
                    relevanceScore: relevance
                )
            )
        }
    }

    func endActivity(
        finalDistance: Double,
        rideStartedAt: Date,
        pausedAt: Date?
    ) {
        guard let activity, isActivityActive else { return }

        let finalState = RideActivityAttributes.ContentState(
            speedMPH: 0,
            distanceTraveledMiles: finalDistance,
            distanceRemainingMiles: 0,
            rideStartedAt: rideStartedAt,
            pausedAt: pausedAt,
            progressPercent: 1.0,
            isOffRoute: false,
            heading: 0
        )

        Task {
            await activity.end(
                .init(
                    state: finalState,
                    staleDate: .now.addingTimeInterval(RideTuning.liveActivityStaleSeconds),
                    relevanceScore: RideTuning.liveActivityNormalRelevance
                ),
                dismissalPolicy: .after(.now + 300) // dismiss after 5 min
            )
        }

        isActivityActive = false
        self.activity = nil
    }
}
