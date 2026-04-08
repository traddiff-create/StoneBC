//
//  ContactView.swift
//  StoneBC
//
//  Volunteer signup, donate link, newsletter, and contact info
//

import SwiftUI

struct ContactView: View {
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
    }

    // MARK: - Get Involved
    private var getInvolvedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW TO HELP")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            ForEach(involveOptions, id: \.title) { option in
                HStack(spacing: 12) {
                    Image(systemName: option.icon)
                        .font(.system(size: 16))
                        .foregroundColor(BCColors.brandBlue)
                        .frame(width: 32, height: 32)
                        .background(BCColors.brandBlue.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.title)
                            .font(.system(size: 14, weight: .medium))
                        Text(option.description)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(BCSpacing.md)
                .background(BCColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Contact Info
    private var contactInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONTACT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                contactRow(icon: "mappin", text: "925 9th Street #3\nRapid City, SD 57701")
                contactRow(icon: "envelope", text: "stonebicyclecoalition@gmail.com")
                contactRow(icon: "globe", text: "stonebicyclecoalition.com")
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
                linkRow(title: "TD Technology", subtitle: "IT Services", icon: "desktopcomputer")
                linkRow(title: "Rory Stone Photography", subtitle: "Portfolio", icon: "camera")
                linkRow(title: "Brought To You By Drugs", subtitle: "Podcast", icon: "mic")
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

    private var involveOptions: [(title: String, description: String, icon: String)] {
        [
            ("Volunteer", "Help in the shop, lead rides, or teach classes", "hand.raised"),
            ("Donate", "Support our mission with a financial contribution", "heart"),
            ("Donate a Bike", "We accept bike donations of all conditions", "bicycle"),
            ("Spread the Word", "Follow us and share with your community", "megaphone")
        ]
    }
}

#Preview {
    NavigationStack {
        ContactView()
    }
}
