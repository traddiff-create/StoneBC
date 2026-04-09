//
//  TabContainerView.swift
//  StoneBC
//
//  Main tab navigation — replaces hero drill-down
//

import SwiftUI

struct TabContainerView: View {
    @Environment(AppState.self) var appState
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            if appState.config.features.enableRoutes {
                NavigationStack {
                    RoutesView()
                }
                .tabItem {
                    Label("Routes", systemImage: "map")
                }
                .tag(1)
            }

            if appState.config.features.enableMarketplace {
                MarketplaceView()
                    .tabItem {
                        Label("Bikes", systemImage: "bicycle")
                    }
                    .tag(2)
            }

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
                .tag(3)
        }
        .tint(BCColors.brandBlue)
    }
}

#Preview {
    TabContainerView()
        .environment(AppState())
}
