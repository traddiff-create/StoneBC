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
                                title: "My Expeditions",
                                subtitle: appState.activeExpedition != nil ? "Active" : "Document your rides",
                                icon: "book.pages"
                            )
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

    // MARK: - Section Builder

    private func moreSection(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            VStack(spacing: 1) {
                content()
            }
            .background(BCColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func moreRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(BCColors.brandBlue)
                .frame(width: 32, height: 32)
                .background(BCColors.brandBlue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(BCColors.tertiaryText)
        }
        .padding(BCSpacing.md)
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            Text("ABOUT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text(appState.config.coalitionName)
                    .font(.system(size: 16, weight: .medium))

                Text(appState.config.tagline)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                if let location = appState.config.location {
                    Divider()
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                        Text("\(location.address), \(location.city), \(location.state) \(location.zip)")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }

                Divider()

                Text("v0.2")
                    .font(.system(size: 10))
                    .foregroundColor(BCColors.tertiaryText)
            }
            .padding(BCSpacing.md)
            .background(BCColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    MoreView()
        .environment(AppState())
}
