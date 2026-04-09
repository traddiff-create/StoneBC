//
//  HomeView.swift
//  StoneBC
//
//  Dashboard tab — featured bikes, recent posts, quick links
//

import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) var appState
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BCSpacing.xl) {
                    // Hero
                    heroSection

                    // Featured Bikes
                    if !appState.featuredBikes.isEmpty {
                        featuredBikesSection
                    }

                    // Recent Posts
                    if !appState.recentPosts.isEmpty {
                        recentPostsSection
                    }

                    // Quick Links
                    quickLinksSection

                    // Footer
                    footerSection
                }
                .padding(.bottom, BCSpacing.xl)
            }
            .background(BCColors.background)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: BCSpacing.md) {
            Spacer().frame(height: BCSpacing.lg)

            Image(systemName: "bicycle")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(BCColors.brandBlue)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -10)
                .animation(.easeOut(duration: 0.6).delay(0.1), value: appeared)

            VStack(spacing: 8) {
                Text(appState.config.coalitionName.uppercased())
                    .font(.system(size: 20, weight: .light))
                    .tracking(4)
                    .multilineTextAlignment(.center)

                Rectangle()
                    .fill(BCColors.brandBlue)
                    .frame(width: 40, height: 2)

                Text(appState.config.tagline)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .tracking(1)
            }
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.6), value: appeared)
        .onAppear {
            withAnimation { appeared = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(appState.config.coalitionName). \(appState.config.tagline)")
    }

    // MARK: - Featured Bikes

    private var featuredBikesSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            sectionHeader("AVAILABLE BIKES", icon: "bicycle")

            ForEach(appState.featuredBikes) { bike in
                NavigationLink(destination: BikeDetailView(bike: bike)) {
                    HStack(spacing: 12) {
                        Image(systemName: bike.type.icon)
                            .font(.system(size: 18))
                            .foregroundColor(BCColors.brandBlue)
                            .frame(width: 40, height: 40)
                            .background(BCColors.brandBlue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(bike.model)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            Text("\(bike.type.label) · \(bike.frameSize)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(bike.formattedPrice)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(BCColors.brandGreen)
                    }
                    .padding(BCSpacing.md)
                    .background(BCColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, BCSpacing.md)
    }

    // MARK: - Recent Posts

    private var recentPostsSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            sectionHeader("LATEST NEWS", icon: "newspaper")

            ForEach(appState.recentPosts) { post in
                NavigationLink(destination: PostDetailView(post: post)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(post.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text(post.excerpt)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(2)

                        HStack {
                            if let category = post.category {
                                Text(category.label.uppercased())
                                    .font(.system(size: 8, weight: .bold))
                                    .tracking(0.5)
                                    .foregroundColor(category.color)
                            }
                            Spacer()
                            Text(post.formattedDate)
                                .font(.system(size: 10))
                                .foregroundColor(BCColors.tertiaryText)
                        }
                    }
                    .padding(BCSpacing.md)
                    .background(BCColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, BCSpacing.md)
    }

    // MARK: - Quick Links

    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            // Rally Radio CTA
            if appState.config.features.enableRadio {
                NavigationLink(destination: RadioView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(BCColors.brandBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rally Radio")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Push-to-talk for group rides")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(BCSpacing.md)
                    .background(BCColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rally Radio. Push-to-talk voice chat for group rides.")
            }

            sectionHeader("EXPLORE", icon: "arrow.right.circle")

            VStack(spacing: 1) {
                quickLink(title: "Black Hills Routes", subtitle: "\(appState.routes.count) routes", icon: "map")
                quickLink(title: "Events & Programs", subtitle: "\(appState.events.count) upcoming", icon: "calendar")
                quickLink(title: "Get Involved", subtitle: "Volunteer · Donate · Connect", icon: "hand.raised")
            }
            .background(BCColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, BCSpacing.md)
    }

    private func quickLink(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(BCColors.brandBlue)
                .frame(width: 28, height: 28)
                .background(BCColors.brandBlue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(BCColors.tertiaryText)
        }
        .padding(.horizontal, BCSpacing.md)
        .padding(.vertical, 12)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 4) {
            if let location = appState.config.location {
                Text("\(location.city), \(location.state)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Text("v0.2")
                .font(.system(size: 10))
                .foregroundColor(BCColors.tertiaryText)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
        }
        .foregroundColor(.secondary)
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
