//
//  BikeCardRow.swift
//  StoneBC
//
//  Bike list item for marketplace
//

import SwiftUI

struct BikeCardRow: View {
    let bike: Bike

    var body: some View {
        HStack(spacing: 14) {
            // Bike type icon
            Image(systemName: bike.type.icon)
                .font(.system(size: 24))
                .foregroundColor(BCColors.brandBlue)
                .frame(width: 56, height: 56)
                .background(BCColors.brandBlue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(bike.model)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(bike.type.label)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(BCColors.tertiaryText)

                    Text(bike.frameSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text("·")
                        .foregroundColor(BCColors.tertiaryText)

                    Text(bike.color)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    StatusBadge(status: bike.status)
                    ConditionBadge(condition: bike.condition)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(bike.formattedPrice)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(BCColors.brandGreen)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(BCColors.tertiaryText)
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bike.model), \(bike.status.label), \(bike.formattedPrice)")
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: BikeStatus

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: status.icon)
                .font(.system(size: 8))
            Text(status.label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .tracking(0.5)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(status.color.opacity(0.15))
        .foregroundColor(status.color)
        .clipShape(Capsule())
    }
}

// MARK: - Condition Badge

struct ConditionBadge: View {
    let condition: BikeCondition

    var body: some View {
        Text(condition.label.uppercased())
            .font(.system(size: 8, weight: .bold))
            .tracking(0.5)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(condition.color.opacity(0.15))
            .foregroundColor(condition.color)
            .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        BikeCardRow(bike: .preview)
    }
    .padding()
    .background(BCColors.background)
}
