//
//  StoneBCWatchApp.swift
//  StoneBCWatch
//

import SwiftUI

@main
struct StoneBCWatchApp: App {
    @StateObject private var model = WatchRidePulseModel()

    var body: some Scene {
        WindowGroup {
            WatchRidePulseView(model: model)
                .task {
                    model.start()
                }
        }
    }
}
