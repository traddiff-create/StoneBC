//
//  RideActivityAttributes.swift
//  StoneBC
//
//  ActivityKit model for Live Activities during rides.
//  Shared between the main app and the Widget Extension.
//
//  SETUP: To enable Live Activities, create a Widget Extension target
//  in Xcode (File > New > Target > Widget Extension), name it
//  "StoneBCWidgets", and add this file to both targets.
//

import ActivityKit
import Foundation

struct RideActivityAttributes: ActivityAttributes {
    /// Static data that doesn't change during the activity
    let routeName: String
    let routeDistanceMiles: Double
    let category: String

    /// Dynamic data updated during the ride
    struct ContentState: Codable, Hashable {
        let speedMPH: Double
        let distanceTraveledMiles: Double
        let distanceRemainingMiles: Double
        let elapsedTime: String
        let progressPercent: Double
        let isOffRoute: Bool
        let heading: Double
    }
}
