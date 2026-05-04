import SwiftUI

/// Stub for v0.1 — the PTT button is rendered but not wired through to
/// Rally Radio yet. Wiring requires a watchOS audio-routing path that
/// proxies through the iPhone's MultipeerConnectivity session, which is
/// a v0.2+ piece of work.
struct WatchRadioView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("RALLY RADIO")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 90, height: 90)
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
            }

            Text("Coming in v0.2")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }
}
