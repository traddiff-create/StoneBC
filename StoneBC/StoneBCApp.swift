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
                    NetworkStatusService.shared.start()
                    appState.startPeriodicSync()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        if let provider = routeProviderCallback(for: url),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
            Task {
                try? await RouteProviderManager.shared.handleCallback(provider: provider, code: code)
            }
            return
        }

        guard url.scheme == "stonebc",
              url.host == "auth",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              let email = components.queryItems?.first(where: { $0.name == "email" })?.value
        else { return }

        Task {
            let valid = await MemberAuthService.validateToken(token, email: email)
            if valid {
                appState.signIn(email: email, token: token)
            }
        }
    }

    private func routeProviderCallback(for url: URL) -> ConnectedRouteProvider? {
        guard url.scheme == "stonebc" else { return nil }
        switch url.host {
        case "wahoo-callback":
            return .wahoo
        case "rwgps-callback":
            return .rideWithGPS
        default:
            return nil
        }
    }
}
