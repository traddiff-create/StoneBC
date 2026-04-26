//
//  RideActivityAttributes.swift
//  StoneBC
//
//  ActivityKit model for Live Activities during rides. Shared between the
//  main app and the `RideWidgetExtension` widget target.
//
//  SETUP: To enable Live Activities, create a Widget Extension target in
//  Xcode (File > New > Target > Widget Extension), name it
//  "RideWidgetExtension", and add this file to both targets' Compile Sources.
//

import ActivityKit
import Foundation

struct RideActivityAttributes: ActivityAttributes {

    /// Static data that doesn't change during the activity.
    let routeName: String
    let routeDistanceMiles: Double
    let category: String

    /// Dynamic data updated during the ride. Note: `rideStartedAt` slides
    /// forward by accumulated paused time so the widget can render
    /// `Text(timerInterval: rideStartedAt...future, pauseTime: pausedAt)`
    /// without us pushing every-second updates over the ActivityKit budget.
    struct ContentState: Codable, Hashable {
        let speedMPH: Double
        let distanceTraveledMiles: Double
        let distanceRemainingMiles: Double

        /// Effective ride start (real start + total paused so far). Renders the
        /// active duration when fed into `Text(timerInterval:)`.
        let rideStartedAt: Date

        /// Set while the ride is paused. `Text(timerInterval:pauseTime:)`
        /// freezes the counter at this moment.
        let pausedAt: Date?

        let progressPercent: Double
        let isOffRoute: Bool
        let heading: Double
    }
}
