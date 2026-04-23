//
//  JournalPromptSheet.swift
//  StoneBC
//
//  Shown after a ride saves — invites the rider to write a journal entry.
//

import SwiftUI

struct JournalPromptSheet: View {
    let rideId: String
    let routeName: String
    let distanceMiles: Double
    let elapsedSeconds: Double

    @State private var goToJournal = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(BCColors.brandBlue.opacity(0.12))
                        .frame(width: 90, height: 90)
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 36))
                        .foregroundColor(BCColors.brandBlue)
                }

                VStack(spacing: 8) {
                    Text("RIDE SAVED")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(2)
                        .foregroundColor(.secondary)
                    Text("Write About This Ride?")
                        .font(.system(size: 22, weight: .bold))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 4) {
                    Text(routeName)
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(String(format: "%.1f", distanceMiles)) mi · \(formattedTime)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(BCColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("Capture how it felt, what you saw, and what you'll do next time.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                VStack(spacing: 12) {
                    NavigationLink(destination: RideJournalDetailView(journal: makeJournal())) {
                        Text("Write Journal Entry")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(BCColors.brandBlue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button("Maybe Later") {
                        dismiss()
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .background(BCColors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 13))
                }
            }
        }
    }

    private var formattedTime: String {
        let h = Int(elapsedSeconds) / 3600
        let m = (Int(elapsedSeconds) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func makeJournal() -> RideJournal {
        RideJournal(rideId: rideId, routeName: routeName, distanceMiles: distanceMiles, elapsedSeconds: elapsedSeconds)
    }
}
