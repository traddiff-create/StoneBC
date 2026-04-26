//
//  RideWidgetBundle.swift
//  RideWidgetExtension
//
//  Entry point for the StoneBC Live Activity. The widget bundle declares
//  every widget the extension provides; today that's only the ride
//  ActivityConfiguration (Lock Screen + Dynamic Island).
//

import SwiftUI
import WidgetKit

@main
struct RideWidgetBundle: WidgetBundle {
    var body: some Widget {
        RideLiveActivityWidget()
    }
}
