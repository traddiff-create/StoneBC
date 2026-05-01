import SwiftUI

@main
struct StoneBCWatchApp: App {
    @State private var connectivity = WatchConnectivityService()

    var body: some Scene {
        WindowGroup {
            TabView {
                RideStatsWatchView()
                    .environment(connectivity)
                WatchRadioView()
            }
            .tabViewStyle(.verticalPage)
        }
    }
}
