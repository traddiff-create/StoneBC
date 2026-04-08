//
//  ContentView.swift
//  StoneBC
//

import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        TabContainerView()
            .environment(appState)
            .task {
                await appState.syncFromWordPress()
            }
    }
}

#Preview {
    ContentView()
}
