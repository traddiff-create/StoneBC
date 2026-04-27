//
//  ContactView.swift
//  StoneBC
//
//  Volunteer signup, donate link, newsletter, and contact info
//

import SwiftUI

struct ContactView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @State private var showVolunteerForm = false
    @State private var showDonateForm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BCSpacing.lg) {
                // Get Involved
                getInvolvedSection

                // Contact Info
                contactInfoSection

                // Links
                linksSection
            }
            .padding(BCSpacing.md)
        }
        .background(BCColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("GET INVOLVED")
                    .font(.bcSectionTitle)
                    .tracking(2)
            }
        }
        .sheet(isPresented: $showVolunteerForm) {
            VolunteerFormView()
        }
        .sheet(isPresented: $showDonateForm) {
            DonateFormView()
        }
    }

    // MARK: - Get Involved
    private var getInvolvedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BCSectionHeader("HOW TO HELP", icon: "hand.raised")

            // Volunteer
            Button { showVolunteerForm = true } label: {
                involveCard(
                    title: "Volunteer",
                    description: "Give your time, skills, or expertise",
                    icon: "hand.raised"
                )
            }
            .buttonStyle(.plain)

            // Donate
            Button { showDonateForm = true } label: {
                involveCard(
                    title: "Donate",
                    description: "Bikes, parts, tools, or funds",
                    icon: "heart"
                )
            }
            .buttonStyle(.plain)

            // Spread the Word
            Button {
                if let url = URL(string: appState.config.websiteURL) {
                    openURL(url)
                }
            } label: {
                involveCard(
                    title: "Spread the Word",
                    description: "Share our site with your community",
                    icon: "megaphone"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func involveCard(title: String, description: String, icon: String) -> some View {
        HStack(spacing: 12) {
            BCIconTile(icon: icon, color: BCColors.brandBlue, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(BCColors.primaryText)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(BCColors.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(BCColors.tertiaryText)
        }
        .bcInstrumentCard()
    }

    // MARK: - Contact Info
    private var contactInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BCSectionHeader("CONTACT", icon: "envelope")

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    if let url = URL(string: "mailto:\(appState.config.email)") {
                        openURL(url)
                    }
                } label: {
                    contactRow(icon: "envelope", text: appState.config.email)
                }
                .buttonStyle(.plain)

                Button {
                    if let url = URL(string: appState.config.websiteURL) {
                        openURL(url)
                    }
                } label: {
                    contactRow(
                        icon: "globe",
                        text: appState.config.websiteURL.replacingOccurrences(of: "https://", with: "")
                    )
                }
                .buttonStyle(.plain)
            }
            .bcInstrumentCard()
        }
    }

    // MARK: - Links
    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BCSectionHeader("MORE FROM TRAD DIFF", icon: "link")

            VStack(spacing: 8) {
                Button {
                    if let url = URL(string: "https://traddiff.com") { openURL(url) }
                } label: {
                    linkRow(title: "TD Technology", subtitle: "IT Services", icon: "desktopcomputer")
                }
                .buttonStyle(.plain)

                Button {
                    if let url = URL(string: "https://rorystonephotography.com") { openURL(url) }
                } label: {
                    linkRow(title: "Rory Stone Photography", subtitle: "Portfolio", icon: "camera")
                }
                .buttonStyle(.plain)

                Button {
                    if let url = URL(string: "https://broughttoyoubydrugs.com") { openURL(url) }
                } label: {
                    linkRow(title: "Brought To You By Drugs", subtitle: "Podcast", icon: "mic")
                }
                .buttonStyle(.plain)
            }
            .bcInstrumentCard()
        }
    }

    private func contactRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(BCColors.brandBlue)
                .frame(width: 20)
            Text(text)
                .font(.bcCaption)
                .foregroundColor(BCColors.primaryText)
        }
    }

    private func linkRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(BCColors.primaryText)
                Text(subtitle.uppercased())
                    .font(.system(size: 8, weight: .medium))
                    .tracking(1)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 10))
                .foregroundColor(BCColors.tertiaryText)
        }
    }
}

#Preview {
    NavigationStack {
        ContactView()
    }
    .environment(AppState())
}
