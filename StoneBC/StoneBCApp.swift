//
//  StoneBCApp.swift
//  StoneBC
//
//  Stone Bicycle Coalition - Rapid City, SD
//

import SwiftUI

@main
struct StoneBCApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .task {
                    appState.startPeriodicSync()
                }
        }
    }
}
