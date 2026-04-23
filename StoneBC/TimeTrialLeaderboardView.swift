import SwiftUI

struct TimeTrialLeaderboardView: View {
    let preset: TimeTrialPreset
    @State private var history = RideHistoryService.shared
    @Environment(\.dismiss) private var dismiss

    private var sortedAttempts: [TimeTrialAttempt] {
        preset.attempts.sorted { $0.elapsedSeconds < $1.elapsedSeconds }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BCSpacing.lg) {
                if let pb = preset.personalBest {
                    pbCard(pb)
                }

                VStack(alignment: .leading, spacing: BCSpacing.sm) {
                    Text("ALL ATTEMPTS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.secondary)

                    if sortedAttempts.isEmpty {
                        Text("No attempts yet")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.top, BCSpacing.md)
                    } else {
                        ForEach(Array(sortedAttempts.enumerated()), id: \.element.id) { rank, attempt in
                            attemptRow(attempt: attempt, rank: rank + 1)
                        }
                    }
                }
            }
            .padding(BCSpacing.md)
        }
        .background(BCColors.background)
        .navigationTitle(preset.routeName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pbCard(_ pb: TimeTrialAttempt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Personal Best")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(formatTime(pb.elapsedSeconds))
                        .font(.system(size: 28, weight: .bold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(pb.completedAt, style: .date)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("\(preset.attempts.count) attempts")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func attemptRow(attempt: TimeTrialAttempt, rank: Int) -> some View {
        let pbTime = preset.personalBestSeconds ?? attempt.elapsedSeconds
        let delta = attempt.elapsedSeconds - pbTime

        return HStack(spacing: 12) {
            rankBadge(rank)

            VStack(alignment: .leading, spacing: 2) {
                Text(attempt.completedAt, style: .date)
                    .font(.system(size: 13, weight: .medium))
                Text(String(format: "%.1f mi", attempt.distanceMiles))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(attempt.elapsedSeconds))
                    .font(.system(size: 15, weight: .bold))

                if rank > 1 {
                    Text("+\(formatTime(delta))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func rankBadge(_ rank: Int) -> some View {
        ZStack {
            if rank == 1 {
                Circle().fill(Color.yellow.opacity(0.2))
                Image(systemName: "crown.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
            } else {
                Circle().fill(BCColors.brandBlue.opacity(0.1))
                Text("\(rank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(BCColors.brandBlue)
            }
        }
        .frame(width: 32, height: 32)
    }

    private func formatTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
