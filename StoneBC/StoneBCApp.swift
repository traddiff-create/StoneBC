//
//  StoneBCApp.swift
//  StoneBC
//
//  Stone Bicycle Coalition - Rapid City, SD
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct StoneBCApp: App {
    @State private var appState = AppState()

    init() {
        StoneBCTestMode.configureRuntimeIfNeeded()
        StoneBCTestMode.prepareLocalSandboxIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .task {
                    RidePulsePublisher.shared.start()
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

enum StoneBCTestMode {
    private static let arguments = ProcessInfo.processInfo.arguments

    static var isUITesting: Bool {
        arguments.contains("-stonebc-ui-testing")
    }

    static var skipOnboarding: Bool {
        isUITesting && arguments.contains("-stonebc-ui-skip-onboarding")
    }

    static var initialTab: Int {
        arguments.contains("-stonebc-ui-start-record") ? 2 : 0
    }

    static var autoStartRide: Bool {
        isUITesting && arguments.contains("-stonebc-ui-auto-start-ride")
    }

    static func configureRuntimeIfNeeded() {
        guard isUITesting else { return }
#if canImport(UIKit)
        UIView.setAnimationsEnabled(false)
#endif
    }

    static func prepareLocalSandboxIfNeeded() {
        guard isUITesting else { return }

        if arguments.contains("-stonebc-ui-reset"),
           let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
            clearDocumentsDirectory()
        }

        if skipOnboarding {
            UserDefaults.standard.set(true, forKey: "onboardingComplete")
        }
    }

    private static func clearDocumentsDirectory() {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let contents = try? FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: nil
              ) else {
            return
        }

        for url in contents {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
