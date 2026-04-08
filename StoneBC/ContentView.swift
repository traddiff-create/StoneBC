//
//  ContentView.swift
//  StoneBC
//

import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        if onboardingComplete {
            TabContainerView()
                .environment(appState)
                .task {
                    await appState.syncFromWordPress()
                }
        } else {
            OnboardingView {
                withAnimation(.easeInOut(duration: 0.5)) {
                    onboardingComplete = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
