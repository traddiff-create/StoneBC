//
//  OnboardingView.swift
//  StoneBC
//
//  12-card feature tour + permission requests. Shown full-screen on first
//  launch; also presented as a sheet from the More tab ("Take the Tour")
//  so existing users can re-discover new features.
//
//  Card order: Welcome → Routes → Navigate → Record → Rally Radio →
//  Swiss Army Knife → Expedition Journal → Location → Motion → Mic →
//  Health → Ready.
//

import SwiftUI

struct OnboardingView: View {
    private static let pageCount = 13
    private static let lastIndex = pageCount - 1   // = 12 (Ready)

    @State private var currentPage = 0
    @State private var permissionService = PermissionService.shared
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            BCColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    routesPage.tag(1)
                    navigatePage.tag(2)
                    recordPage.tag(3)
                    radioPage.tag(4)
                    swissArmyPage.tag(5)
                    expeditionPage.tag(6)
                    locationPage.tag(7)
                    motionPage.tag(8)
                    micPage.tag(9)
                    healthPage.tag(10)
                    disclaimerPage.tag(11)
                    readyPage.tag(12)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                bottomControls
            }
        }
    }

    // MARK: - Feature cards

    private var welcomePage: some View {
        OnboardingPage(
            icon: "bicycle",
            iconColor: BCColors.brandGreen,
            title: "Explore the Black Hills",
            subtitle: "Stone Bicycle Coalition",
            description: "Your cycling Swiss army knife for South Dakota. 56 curated routes with glance-first navigation, ride recording, weather, and offline support.",
            showPermissionButton: false
        )
    }

    private var routesPage: some View {
        OnboardingPage(
            icon: "map.fill",
            iconColor: BCColors.brandBlue,
            title: "56 Curated Routes",
            subtitle: "Black Hills · Plains · Badlands",
            description: "Hand-picked road, gravel, fatbike, and trail routes with elevation profiles, difficulty ratings, and bundled offline data. From 3-mile city loops to multi-day bikepacking.",
            showPermissionButton: false
        )
    }

    private var navigatePage: some View {
        OnboardingPage(
            icon: "location.north.line.fill",
            iconColor: BCColors.brandBlue,
            title: "Glance-First Navigation",
            subtitle: "Bar-Mount Ready",
            description: "Legible at 25 mph — 150 pt speed hero, ambient compass, mini elevation profile, audio turn cues, and tiered off-route alerts. Status bar and tab bar disappear for full immersion.",
            showPermissionButton: false
        )
    }

    private var recordPage: some View {
        OnboardingPage(
            icon: "record.circle.fill",
            iconColor: .red,
            title: "Record Any Ride",
            subtitle: "Save as Ride or Route",
            description: "Start fresh recording from the Record tab. Auto-pause after 7 seconds at a light, auto-resume when you roll. Save each ride to your history, or publish it as a new route for friends to navigate.",
            showPermissionButton: false
        )
    }

    private var radioPage: some View {
        OnboardingPage(
            icon: "antenna.radiowaves.left.and.right",
            iconColor: BCColors.brandBlue,
            title: "Rally Radio",
            subtitle: "Voice Chat for Rides",
            description: "Push-to-talk group voice chat that works without cell service. Peer-to-peer WiFi keeps your ride group connected across the Black Hills backcountry.",
            showPermissionButton: false
        )
    }

    private var swissArmyPage: some View {
        OnboardingPage(
            icon: "wrench.and.screwdriver.fill",
            iconColor: BCColors.brandAmber,
            title: "Swiss Army Knife",
            subtitle: "Weather · Trails · Emergency",
            description: "WeatherKit forecasts at every route start, Trailforks + USFS closures live, satellite SOS detection on iPhone 14+, and one-tap emergency contacts. Route data caches for full offline use.",
            showPermissionButton: false
        )
    }

    private var expeditionPage: some View {
        OnboardingPage(
            icon: "book.closed.fill",
            iconColor: BCColors.brandGreen,
            title: "Follow My Expedition",
            subtitle: "Offline Field Log",
            description: "Multi-day trip docs. Daily field logs, GPS-tagged photos, audio memos, video clips, and PDF expedition export. Everything records offline first.",
            showPermissionButton: false
        )
    }

    // MARK: - Permission cards

    private var locationPage: some View {
        OnboardingPage(
            icon: "location.fill",
            iconColor: BCColors.brandBlue,
            title: "Location Access",
            subtitle: "For GPS Navigation & Recording",
            description: "Follow routes in real time, record new rides, and get off-route alerts. Your location stays on your device.",
            showPermissionButton: true,
            permissionLabel: permissionService.locationGranted ? "Location Enabled" : "Enable Location",
            permissionGranted: permissionService.locationGranted,
            permissionAction: {
                permissionService.requestLocation()
            }
        )
    }

    private var motionPage: some View {
        OnboardingPage(
            icon: "gauge.with.dots.needle.33percent",
            iconColor: BCColors.brandAmber,
            title: "Motion Sensors",
            subtitle: "Barometer & Altimeter",
            description: "Your iPhone's barometer powers accurate elevation, climb rate, and gradient in the ride dashboard. No external hardware needed.",
            showPermissionButton: true,
            permissionLabel: permissionService.motionGranted ? "Motion Enabled" : "Enable Motion",
            permissionGranted: permissionService.motionGranted,
            permissionAction: {
                permissionService.requestMotion()
            }
        )
    }

    private var micPage: some View {
        OnboardingPage(
            icon: "waveform.badge.mic",
            iconColor: BCColors.brandBlue,
            title: "Microphone",
            subtitle: "For Rally Radio",
            description: "Push-to-talk voice chat needs microphone access. Only active while you hold the talk button.",
            showPermissionButton: true,
            permissionLabel: permissionService.microphoneGranted ? "Microphone Enabled" : "Enable Microphone",
            permissionGranted: permissionService.microphoneGranted,
            permissionAction: {
                permissionService.requestMicrophone()
            }
        )
    }

    private var healthPage: some View {
        OnboardingPage(
            icon: "heart.fill",
            iconColor: .red,
            title: "Apple Health",
            subtitle: "Sync Rides as Workouts",
            description: "Every ride saves as a cycling workout with your GPS route. View rides in the Health app, share with Strava, or track your fitness over time.",
            showPermissionButton: permissionService.healthKitAvailable,
            permissionLabel: permissionService.healthKitAuthorized ? "Health Connected" : "Connect Health",
            permissionGranted: permissionService.healthKitAuthorized,
            permissionAction: {
                Task { await permissionService.requestHealthKit() }
            }
        )
    }

    // MARK: - Disclaimer

    private var disclaimerPage: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Rectangle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
            }

            VStack(spacing: 8) {
                Text("BEFORE YOU RIDE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.secondary)
                Text("Ride Responsibly")
                    .font(.system(size: 26, weight: .bold))
            }

            VStack(alignment: .leading, spacing: 12) {
                disclaimerPoint(icon: "map", text: "Route data is provided for reference only — we cannot verify current trail conditions, closures, or hazards.")
                disclaimerPoint(icon: "exclamationmark.shield", text: "Always check routes before riding. Conditions change. You assume all responsibility for your safety.")
                disclaimerPoint(icon: "person.fill.checkmark", text: "Wear a helmet. Carry water and a repair kit. Tell someone your plan.")
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    private func disclaimerPoint(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.orange)
                .frame(width: 20)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineSpacing(3)
        }
    }

    // MARK: - Ready

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(BCColors.brandGreen)

            Text("You're Ready to Ride")
                .font(.system(size: 24, weight: .bold))

            Text("56 routes across the Black Hills, Great Plains, and Badlands are waiting for you.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Feature checklist
            VStack(alignment: .leading, spacing: 10) {
                featureCheck("GPS Navigation + Audio Cues", granted: true)
                featureCheck("Ride Recording + Auto-Pause", granted: true)
                featureCheck("Weather & Wind Analysis", granted: true)
                featureCheck("Offline Maps & Cell Coverage", granted: true)
                featureCheck("Location Services", granted: permissionService.locationGranted)
                featureCheck("Motion Sensors", granted: permissionService.motionGranted)
                featureCheck("Rally Radio Microphone", granted: permissionService.microphoneGranted)
                if permissionService.healthKitAvailable {
                    featureCheck("Apple Health Workouts", granted: permissionService.healthKitAuthorized)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()

            Button {
                onComplete()
            } label: {
                Text("START EXPLORING")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(BCColors.brandGreen)
                    .foregroundColor(.white)
                    .clipShape(Rectangle())
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
    }

    private func featureCheck(_ label: String, granted: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: granted ? "checkmark.square.fill" : "square")
                .font(.system(size: 14))
                .foregroundColor(granted ? BCColors.brandGreen : .secondary)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(granted ? .primary : .secondary)
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<Self.pageCount, id: \.self) { page in
                    Rectangle()
                        .fill(page == currentPage ? BCColors.brandGreen : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }

            // Skip + Next on all pages except Ready
            if currentPage < Self.lastIndex {
                HStack {
                    Button("Skip") {
                        withAnimation { currentPage = Self.lastIndex }
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        withAnimation { currentPage += 1 }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Next")
                                .font(.system(size: 14, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(BCColors.brandGreen)
                    }
                }
                .padding(.horizontal, 32)
            }
        }
        .padding(.bottom, 16)
    }
}

// MARK: - Onboarding Page Template

struct OnboardingPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let description: String
    var showPermissionButton: Bool = false
    var permissionLabel: String = ""
    var permissionGranted: Bool = false
    var permissionAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon
            ZStack {
                Rectangle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(iconColor)
            }

            // Title
            VStack(spacing: 6) {
                Text(subtitle.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
            }

            // Description
            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)

            // Permission button
            if showPermissionButton {
                Button {
                    permissionAction?()
                } label: {
                    HStack(spacing: 8) {
                        if permissionGranted {
                            Image(systemName: "checkmark.square.fill")
                                .foregroundColor(.white)
                        }
                        Text(permissionLabel)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(permissionGranted ? BCColors.brandGreen : BCColors.brandBlue)
                    .foregroundColor(.white)
                    .clipShape(Rectangle())
                }
                .disabled(permissionGranted)
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView {}
}
