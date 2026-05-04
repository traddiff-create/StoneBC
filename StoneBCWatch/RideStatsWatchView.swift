import SwiftUI

struct RideStatsWatchView: View {
    @Environment(WatchConnectivityService.self) private var connectivity

    var body: some View {
        let state = connectivity.ridingState

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("RIDE")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if state.isPaused {
                    Label("Paused", systemImage: "pause.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            stat(label: "Distance", value: String(format: "%.1f mi", state.distanceMiles))
            stat(label: "Time", value: formatted(seconds: state.movingSeconds))
            stat(label: "Climb", value: "\(state.elevationGainFeet) ft")
            stat(label: "Speed", value: String(format: "%.1f mph", state.currentSpeedMPH))

            if state.isOffRoute {
                Label("Off route", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }

            if !connectivity.isReachable && state.timestamp == .init(timeIntervalSince1970: 0) {
                Text("Waiting for iPhone…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    private func stat(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()
        }
    }

    private func formatted(seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
