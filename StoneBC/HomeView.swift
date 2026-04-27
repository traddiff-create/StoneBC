//
//  HomeView.swift
//  StoneBC
//
//  Dashboard tab — featured bikes, recent posts, quick links
//

import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BCSpacing.xl) {
                    // Hero
                    heroSection

                    // Season Summary
                    seasonSummarySection

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
        VStack(alignment: .leading, spacing: BCSpacing.md) {
            HStack(alignment: .top) {
                BCIconTile(icon: "bicycle", color: BCColors.brandBlue, size: 52, filled: true)

                Spacer()

                if let location = appState.config.location {
                    BCStatusPill(text: "\(location.city), \(location.state)", icon: "location", color: BCColors.brandGreen)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(appState.config.coalitionName.uppercased())
                    .font(.bcHero)
                    .tracking(1.4)
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)

                Text(appState.config.tagline)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(BCColors.secondaryText)
                    .lineLimit(2)
            }

            BCHairline()

            HStack(spacing: BCSpacing.sm) {
                BCStatusPill(text: appState.config.shortName, icon: "gauge.with.dots.needle.bottom.50percent", color: BCColors.brandBlue)
                BCStatusPill(text: "Routes \(appState.routes.count)", icon: "map", color: BCColors.brandAmber)
                Spacer()
            }
        }
        .bcInstrumentCard(padding: BCSpacing.lg)
        .padding(.horizontal, BCSpacing.md)
        .padding(.top, BCSpacing.md)
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
                        BCIconTile(icon: bike.type.icon, color: BCColors.brandBlue, size: 42)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(bike.model)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(BCColors.primaryText)
                                .lineLimit(1)
                            Text("\(bike.type.label) · \(bike.frameSize)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(BCColors.secondaryText)
                        }

                        Spacer()

                        Text(bike.formattedPrice)
                            .font(.bcCaption)
                            .foregroundColor(BCColors.brandGreen)
                    }
                    .bcInstrumentCard()
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
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BCColors.primaryText)
                            .lineLimit(1)

                        Text(post.excerpt)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(BCColors.secondaryText)
                            .lineLimit(2)

                        HStack {
                            if let category = post.category {
                                BCStatusPill(text: category.label, color: category.color)
                            }
                            Spacer()
                            Text(post.formattedDate)
                                .font(.bcMicro)
                                .foregroundColor(BCColors.tertiaryText)
                        }
                    }
                    .bcInstrumentCard()
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
                    BCPrimaryAction(
                        title: "Rally Radio",
                        subtitle: "Push-to-talk for group rides",
                        icon: "antenna.radiowaves.left.and.right",
                        color: BCColors.brandBlue
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rally Radio. Push-to-talk voice chat for group rides.")
            }

            sectionHeader("EXPLORE", icon: "arrow.right.circle")

            VStack(spacing: 1) {
                quickLink(title: "Black Hills Routes", subtitle: "\(appState.routes.count) routes", icon: "map")
                BCHairline()
                quickLink(title: "Events & Programs", subtitle: "\(appState.events.count) upcoming", icon: "calendar")
                BCHairline()
                quickLink(title: "Get Involved", subtitle: "Volunteer · Donate · Connect", icon: "hand.raised")
            }
            .bcPanelList()
        }
        .padding(.horizontal, BCSpacing.md)
    }

    private func quickLink(title: String, subtitle: String, icon: String) -> some View {
        BCDisclosureRow(title: title, subtitle: subtitle, icon: icon)
    }

    // MARK: - Season Summary

    private var seasonSummarySection: some View {
        let summary = RideHistoryService.shared.seasonSummary

        return VStack(alignment: .leading, spacing: BCSpacing.sm) {
            sectionHeader("\(summary.year) SEASON", icon: "chart.bar")

            if summary.rideCount > 0 {
                BCMetricStrip(metrics: [
                    BCMetric(value: "\(summary.rideCount)", label: "Rides", icon: "figure.outdoor.cycle"),
                    BCMetric(value: summary.formattedMiles, label: "Miles", icon: "road.lanes"),
                    BCMetric(
                        value: summary.formattedElevation.replacingOccurrences(of: " ft", with: ""),
                        label: "Elevation",
                        icon: "arrow.up"
                    ),
                    BCMetric(value: summary.formattedTime, label: "Moving", icon: "clock")
                ])

                if let favorite = summary.favoriteRoute {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(BCColors.brandAmber)
                        Text("Favorite: \(favorite)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    BCIconTile(icon: "figure.outdoor.cycle", color: BCColors.brandBlue, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No rides yet this season")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(BCColors.primaryText)
                        Text("Navigate a route to start tracking")
                            .font(.system(size: 11))
                            .foregroundColor(BCColors.secondaryText)
                    }
                }
                .bcInstrumentCard()
            }
        }
        .padding(.horizontal, BCSpacing.md)
    }

    private func seasonStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(BCColors.brandBlue)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 7, weight: .bold))
                .tracking(0.5)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 4) {
            if let location = appState.config.location {
                Text("\(location.city), \(location.state)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Text("v0.8")
                .font(.system(size: 10))
                .foregroundColor(BCColors.tertiaryText)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        BCSectionHeader(title, icon: icon)
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
