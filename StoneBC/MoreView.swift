//
//  MoreView.swift
//  StoneBC
//
//  Events, Programs, Gallery, Contact — existing views in a More tab
//

import SwiftUI

struct MoreView: View {
    @Environment(AppState.self) var appState
    @State private var showTour = false
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BCSpacing.lg) {
                    // Community Feed
                    if appState.config.features.enableCommunityFeed {
                        moreSection(title: "COMMUNITY", icon: "bubble.left") {
                            NavigationLink(destination: CommunityFeedView()) {
                                moreRow(
                                    title: "Community Feed",
                                    subtitle: "\(appState.sortedPosts.count) posts",
                                    icon: "bubble.left.and.bubble.right"
                                )
                            }
                        }
                    }

                    // Events section
                    if appState.config.features.enableEvents {
                        moreSection(title: "EVENTS & PROGRAMS", icon: "calendar") {
                            NavigationLink(destination: CommunityView()) {
                                moreRow(
                                    title: "Events & Programs",
                                    subtitle: "\(appState.events.count) upcoming",
                                    icon: "calendar"
                                )
                            }
                        }
                    }

                    // Expedition Journals
                    moreSection(title: "EXPEDITIONS", icon: "book") {
                        NavigationLink(destination: ExpeditionListView()) {
                            moreRow(
                                title: "Follow My Expedition",
                                subtitle: appState.activeExpedition != nil ? "Active offline log" : "PDF-ready field record",
                                icon: "book.pages"
                            )
                        }
                    }

                    // Ride Tools
                    if appState.config.features.enableRideAlerts ?? true {
                        moreSection(title: "RIDE TOOLS", icon: "bell.badge") {
                            NavigationLink(destination: RideAlertsSettingsView()) {
                                moreRow(
                                    title: "Ride Alerts",
                                    subtitle: rideAlertsSubtitle,
                                    icon: "bell.badge"
                                )
                            }
                        }
                    }

                    // Tour Guides
                    if !appState.guides.isEmpty {
                        moreSection(title: "TOUR GUIDES", icon: "map") {
                            NavigationLink(destination: TourGuideListView()) {
                                moreRow(
                                    title: "Tour Guides",
                                    subtitle: "\(appState.guides.count) guides",
                                    icon: "map"
                                )
                            }
                        }
                    }

                    // Route provider connections
                    moreSection(title: "NAVIGATION", icon: "point.topleft.down.to.point.bottomright.curvepath") {
                        NavigationLink(destination: ConnectedAppsView()) {
                            moreRow(
                                title: "Connected Apps",
                                subtitle: "Garmin, Wahoo, Ride with GPS",
                                icon: "point.topleft.down.to.point.bottomright.curvepath"
                            )
                        }
                    }

                    // Gallery section
                    if appState.config.features.enableGallery {
                        moreSection(title: "GALLERY", icon: "photo") {
                            NavigationLink(destination: GalleryView()) {
                                moreRow(
                                    title: "Photo Gallery",
                                    subtitle: "Community moments",
                                    icon: "photo.on.rectangle"
                                )
                            }
                        }
                    }

                    // Bikes / Marketplace
                    if appState.config.features.enableMarketplace {
                        moreSection(title: "THE QUARRY", icon: "bicycle") {
                            NavigationLink(destination: MarketplaceView()) {
                                moreRow(
                                    title: "Bike Marketplace",
                                    subtitle: "Browse available co-op bikes",
                                    icon: "bicycle"
                                )
                            }
                        }
                    }

                    // Member login
                    moreSection(title: "CO-OP MEMBER", icon: "person.badge.key") {
                        if appState.isMemberLoggedIn, let email = appState.memberEmail {
                            moreRow(
                                title: "Signed in",
                                subtitle: email,
                                icon: "checkmark.seal.fill"
                            )
                            Button {
                                appState.signOut()
                            } label: {
                                moreRow(
                                    title: "Sign Out",
                                    subtitle: "Remove this device from your account",
                                    icon: "rectangle.portrait.and.arrow.right"
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                showLogin = true
                            } label: {
                                moreRow(
                                    title: "Member Login",
                                    subtitle: "Sign in to submit routes & save progress",
                                    icon: "person.badge.key"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Contact section
                    moreSection(title: "CONNECT", icon: "person") {
                        NavigationLink(destination: ContactView()) {
                            moreRow(
                                title: "Get Involved",
                                subtitle: "Volunteer, donate, connect",
                                icon: "hand.raised"
                            )
                        }

                        if let url = URL(string: appState.config.websiteURL) {
                            Link(destination: url) {
                                moreRow(
                                    title: "Website",
                                    subtitle: appState.config.websiteURL
                                        .replacingOccurrences(of: "https://", with: ""),
                                    icon: "globe"
                                )
                            }
                        }

                        if let handle = appState.config.instagramHandle {
                            Link(destination: URL(string: "https://instagram.com/\(handle)")!) {
                                moreRow(
                                    title: "Instagram",
                                    subtitle: "@\(handle)",
                                    icon: "camera"
                                )
                            }
                        }
                    }

                    // Take the Tour
                    moreSection(title: "LEARN", icon: "graduationcap") {
                        Button {
                            showTour = true
                        } label: {
                            moreRow(
                                title: "Take the Tour",
                                subtitle: "Walk through every feature",
                                icon: "graduationcap.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // About
                    aboutSection
                }
                .padding(BCSpacing.md)
            }
            .background(BCColors.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("MORE")
                        .font(.bcSectionTitle)
                        .tracking(2)
                }
            }
            .sheet(isPresented: $showTour) {
                OnboardingView {
                    showTour = false
                }
            }
            .sheet(isPresented: $showLogin) {
                MemberLoginView()
            }
        }
    }

    private var rideAlertsSubtitle: String {
        let enabled = RideAlertService.shared.alerts.filter(\.enabled).count
        let total = RideAlertService.shared.alerts.count
        if enabled == 0 { return "Beep on time or distance · \(total) presets" }
        return "\(enabled) active of \(total)"
    }

    // MARK: - Section Builder

    private func moreSection(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            BCSectionHeader(title, icon: icon)

            VStack(spacing: 1) {
                content()
            }
            .bcPanelList()
        }
    }

    private func moreRow(title: String, subtitle: String, icon: String) -> some View {
        BCDisclosureRow(title: title, subtitle: subtitle, icon: icon)
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            BCSectionHeader("ABOUT", icon: "info.circle")

            VStack(alignment: .leading, spacing: 8) {
                Text(appState.config.coalitionName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(BCColors.primaryText)

                Text(appState.config.tagline)
                    .font(.system(size: 13))
                    .foregroundColor(BCColors.secondaryText)

                if let location = appState.config.location {
                    BCHairline()
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                        Text("\(location.address), \(location.city), \(location.state) \(location.zip)")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }

                BCHairline()

                Text("v0.2")
                    .font(.bcMicro)
                    .foregroundColor(BCColors.tertiaryText)
            }
            .bcInstrumentCard()
        }
    }
}

#Preview {
    MoreView()
        .environment(AppState())
}
