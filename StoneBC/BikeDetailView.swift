//
//  BikeDetailView.swift
//  StoneBC
//
//  Full bike detail with specs, features, and contact CTA
//

import SwiftUI

struct BikeDetailView: View {
    let bike: Bike
    @Environment(AppState.self) var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero
                bikeHero

                VStack(alignment: .leading, spacing: BCSpacing.lg) {
                    // Header
                    headerSection

                    Divider()

                    // Specs
                    specsSection

                    // Features
                    if !bike.features.isEmpty {
                        Divider()
                        featuresSection
                    }

                    // Description
                    Divider()
                    Text(bike.description)
                        .font(.system(size: 14, weight: .regular))
                        .lineSpacing(4)
                        .foregroundColor(.secondary)

                    // Metadata
                    Divider()
                    metadataSection

                    // Contact CTA
                    contactButton
                }
                .padding(BCSpacing.md)
            }
        }
        .background(BCColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(bike.id)
                    .font(.bcSectionTitle)
                    .tracking(2)
            }
        }
    }

    // MARK: - Hero

    private var bikeHero: some View {
        ZStack {
            BCColors.brandBlue.opacity(0.08)
            VStack(spacing: BCSpacing.sm) {
                Image(systemName: bike.type.icon)
                    .font(.system(size: 48))
                    .foregroundColor(BCColors.brandBlue)
                Text(bike.type.label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(BCColors.brandBlue.opacity(0.6))
            }
        }
        .frame(height: 200)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            HStack(alignment: .top) {
                Text(bike.model)
                    .font(.system(size: 22, weight: .semibold))
                Spacer()
                Text(bike.formattedPrice)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(BCColors.brandGreen)
            }

            HStack(spacing: 8) {
                StatusBadge(status: bike.status)
                ConditionBadge(condition: bike.condition)
                CategoryBadge(category: bike.type.rawValue)
            }
        }
    }

    // MARK: - Specs

    private var specsSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            Text("SPECIFICATIONS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                specRow(label: "Frame Size", value: bike.frameSize)
                specRow(label: "Wheel Size", value: bike.wheelSize)
                specRow(label: "Color", value: bike.color)
                specRow(label: "Condition", value: bike.condition.label)
            }
        }
    }

    private func specRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            Text("FEATURES")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            ForEach(bike.features, id: \.self) { feature in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(BCColors.brandGreen)
                    Text(feature)
                        .font(.system(size: 13))
                }
            }
        }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.xs) {
            Text("DETAILS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            HStack {
                Text("Added \(bike.dateAdded)")
                Spacer()
                Text("Via \(bike.acquiredVia.capitalized)")
            }
            .font(.system(size: 11))
            .foregroundColor(BCColors.tertiaryText)
        }
    }

    // MARK: - Contact

    private var contactButton: some View {
        VStack(spacing: BCSpacing.sm) {
            Button(action: contactAboutBike) {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Inquire About This Bike")
                }
                .font(.system(size: 15, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(BCColors.brandBlue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(PressableButtonStyle())

            Text(appState.config.email)
                .font(.system(size: 11))
                .foregroundColor(BCColors.tertiaryText)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, BCSpacing.sm)
    }

    private func contactAboutBike() {
        let subject = "Inquiry About \(bike.model) (\(bike.id))"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = "Hi,\n\nI'm interested in the \(bike.model). Could you tell me more?\n\nThanks"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:\(appState.config.email)?subject=\(subject)&body=\(body)") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationStack {
        BikeDetailView(bike: .preview)
    }
    .environment(AppState())
}
