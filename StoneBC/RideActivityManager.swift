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

    func startActivity(routeName: String, distanceMiles: Double, category: String) {
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
            elapsedTime: "0:00",
            progressPercent: 0,
            isOffRoute: false,
            heading: 0
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            isActivityActive = true
        } catch {
            // Live Activities not available on this device/OS
        }
    }

    func updateActivity(
        speedMPH: Double,
        distanceTraveled: Double,
        distanceRemaining: Double,
        elapsedTime: String,
        progress: Double,
        isOffRoute: Bool,
        heading: Double
    ) {
        guard let activity, isActivityActive else { return }

        let state = RideActivityAttributes.ContentState(
            speedMPH: speedMPH,
            distanceTraveledMiles: distanceTraveled,
            distanceRemainingMiles: distanceRemaining,
            elapsedTime: elapsedTime,
            progressPercent: progress,
            isOffRoute: isOffRoute,
            heading: heading
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func endActivity(
        finalDistance: Double,
        finalTime: String
    ) {
        guard let activity, isActivityActive else { return }

        let finalState = RideActivityAttributes.ContentState(
            speedMPH: 0,
            distanceTraveledMiles: finalDistance,
            distanceRemainingMiles: 0,
            elapsedTime: finalTime,
            progressPercent: 1.0,
            isOffRoute: false,
            heading: 0
        )

        Task {
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now + 300) // dismiss after 5 min
            )
        }

        isActivityActive = false
        self.activity = nil
    }
}
