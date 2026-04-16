//
//  TourGuideListView.swift
//  StoneBC
//
//  Browse available tour guides
//

import SwiftUI

struct TourGuideListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BCSpacing.md) {
                ForEach(appState.guides) { guide in
                    NavigationLink(destination: TourGuideDetailView(guide: guide)) {
                        guideCard(guide)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(BCSpacing.md)
        }
        .background(BCColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("TOUR GUIDES")
                    .font(.bcSectionTitle)
                    .tracking(2)
            }
        }
    }

    private func guideCard(_ guide: TourGuide) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(guide.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(guide.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if guide.type == .event, let date = guide.eventDate {
                    Text(date)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(BCColors.brandBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(BCColors.brandBlue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            Divider()

            HStack(spacing: 16) {
                statLabel(value: "\(guide.totalDays)", label: guide.totalDays == 1 ? "DAY" : "DAYS")
                statLabel(value: String(format: "%.0f", guide.totalMiles), label: "MILES")
                statLabel(value: formatElevation(guide.totalElevation), label: "ELEV")
                Spacer()
                Text(guide.difficulty.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(BCColors.difficultyColor(guide.difficulty))
                    .clipShape(Capsule())
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statLabel(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(1)
                .foregroundColor(.secondary)
        }
    }

    private func formatElevation(_ feet: Int) -> String {
        if feet >= 1000 {
            return String(format: "%.1fk", Double(feet) / 1000)
        }
        return "\(feet)"
    }
}
