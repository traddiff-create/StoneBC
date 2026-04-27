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
            BCIconTile(icon: bike.type.icon, color: BCColors.brandBlue, size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(bike.model)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(BCColors.primaryText)
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
                    .font(.bcInstrumentValue)
                    .foregroundColor(BCColors.brandGreen)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(BCColors.tertiaryText)
            }
        }
        .bcInstrumentCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bike.model), \(bike.status.label), \(bike.formattedPrice)")
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: BikeStatus

    var body: some View {
        BCStatusPill(text: status.label, icon: status.icon, color: status.color)
    }
}

// MARK: - Condition Badge

struct ConditionBadge: View {
    let condition: BikeCondition

    var body: some View {
        BCStatusPill(text: condition.label, color: condition.color)
    }
}

#Preview {
    VStack(spacing: 12) {
        BikeCardRow(bike: .preview)
    }
    .padding()
    .background(BCColors.background)
}
