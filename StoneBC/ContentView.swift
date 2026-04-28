//
//  ContentView.swift
//  StoneBC
//

import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        Group {
            if onboardingComplete || StoneBCTestMode.skipOnboarding {
                TabContainerView(initialSelectedTab: StoneBCTestMode.initialTab)
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
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
