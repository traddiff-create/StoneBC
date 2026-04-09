//
//  OnboardingView.swift
//  StoneBC
//
//  First-launch onboarding — introduces features and requests permissions.
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var permissionService = PermissionService.shared
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            BCColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    locationPage.tag(1)
                    sensorsPage.tag(2)
                    radioPage.tag(3)
                    healthPage.tag(4)
                    readyPage.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)

                // Page indicator + controls
                bottomControls
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        OnboardingPage(
            icon: "bicycle",
            iconColor: BCColors.brandGreen,
            title: "Explore the Black Hills",
            subtitle: "Stone Bicycle Coalition",
            description: "Your cycling Swiss army knife for South Dakota. 41 curated routes with GPS navigation, real-time sensors, weather intelligence, and offline support.",
            showPermissionButton: false
        )
    }

    private var locationPage: some View {
        OnboardingPage(
            icon: "location.fill",
            iconColor: BCColors.brandBlue,
            title: "GPS Navigation",
            subtitle: "Know Where You Are",
            description: "Follow routes in real time with off-route alerts, distance tracking, and turn-by-turn audio cues. Your location stays on your device.",
            showPermissionButton: true,
            permissionLabel: permissionService.locationGranted ? "Location Enabled" : "Enable Location",
            permissionGranted: permissionService.locationGranted,
            permissionAction: {
                permissionService.requestLocation()
            }
        )
    }

    private var sensorsPage: some View {
        OnboardingPage(
            icon: "gauge.with.dots.needle.33percent",
            iconColor: BCColors.brandAmber,
            title: "Ride Dashboard",
            subtitle: "Compass · Barometer · Speed",
            description: "Your iPhone's sensors power a full cycling cockpit — compass heading, barometric altitude and climb rate, GPS speed with averages. All works offline, no extra hardware needed.",
            showPermissionButton: false
        )
    }

    private var radioPage: some View {
        OnboardingPage(
            icon: "antenna.radiowaves.left.and.right",
            iconColor: BCColors.brandBlue,
            title: "Rally Radio",
            subtitle: "Voice Chat for Rides",
            description: "Push-to-talk group voice chat that works without cell service. Uses peer-to-peer WiFi to keep your ride group connected — no backend, no accounts, just talk.",
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
            title: "Record Workouts",
            subtitle: "Sync to Apple Health",
            description: "Every ride is saved as a cycling workout with your GPS route. View rides in the Health app, share with Strava, or track your fitness over time.",
            showPermissionButton: permissionService.healthKitAvailable,
            permissionLabel: permissionService.healthKitAuthorized ? "Health Connected" : "Connect Health",
            permissionGranted: permissionService.healthKitAuthorized,
            permissionAction: {
                Task { await permissionService.requestHealthKit() }
            }
        )
    }

    private var readyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(BCColors.brandGreen)

            Text("You're Ready to Ride")
                .font(.system(size: 24, weight: .bold))

            Text("41 routes across the Black Hills, Great Plains, and Badlands are waiting for you.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Feature checklist
            VStack(alignment: .leading, spacing: 10) {
                featureCheck("GPS Navigation + Audio Cues", granted: true)
                featureCheck("Compass, Altimeter & Speed", granted: true)
                featureCheck("Weather & Wind Analysis", granted: true)
                featureCheck("Offline Maps & Cell Coverage", granted: true)
                featureCheck("Location Services", granted: permissionService.locationGranted)
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
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
    }

    private func featureCheck(_ label: String, granted: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle")
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
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { page in
                    Circle()
                        .fill(page == currentPage ? BCColors.brandGreen : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            // Buttons
            if currentPage < 5 {
                HStack {
                    Button("Skip") {
                        withAnimation { currentPage = 5 }
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
                Circle()
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
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                        }
                        Text(permissionLabel)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(permissionGranted ? BCColors.brandGreen : BCColors.brandBlue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .disabled(permissionGranted)
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
    }
}
