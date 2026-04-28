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

    init(initialSelectedTab: Int = 0) {
        _selectedTab = State(initialValue: initialSelectedTab)
    }

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

            RecordTabView()
                .tabItem {
                    Label("Record", systemImage: "record.circle.fill")
                        .accessibilityIdentifier("stonebc.tab.record")
                }
                .tag(2)
                .accessibilityIdentifier("stonebc.record.tab.root")

            RidesTabView()
                .tabItem {
                    Label("Rides", systemImage: "bicycle")
                }
                .tag(3)

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
                .tag(4)
        }
        .tint(BCColors.brandBlue)
    }
}

#Preview {
    TabContainerView()
        .environment(AppState())
}
