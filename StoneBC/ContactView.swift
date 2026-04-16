//
//  ContactView.swift
//  StoneBC
//
//  Volunteer signup, donate link, newsletter, and contact info
//

import SwiftUI

struct ContactView: View {
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
            Text("HOW TO HELP")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

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
                if let url = URL(string: "https://stonebicyclecoalition.com") {
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
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(BCColors.tertiaryText)
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Contact Info
    private var contactInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONTACT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    if let url = URL(string: "mailto:info@stonebicyclecoalition.com") {
                        openURL(url)
                    }
                } label: {
                    contactRow(icon: "envelope", text: "info@stonebicyclecoalition.com")
                }
                .buttonStyle(.plain)

                Button {
                    if let url = URL(string: "https://stonebicyclecoalition.com") {
                        openURL(url)
                    }
                } label: {
                    contactRow(icon: "globe", text: "stonebicyclecoalition.com")
                }
                .buttonStyle(.plain)
            }
            .padding(BCSpacing.md)
            .background(BCColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Links
    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MORE FROM TRAD DIFF")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

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
            .padding(BCSpacing.md)
            .background(BCColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func contactRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(BCColors.brandBlue)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.primary)
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
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
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
}
