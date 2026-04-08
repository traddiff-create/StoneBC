//
//  RadioOverlayView.swift
//  StoneBC
//
//  Compact floating pill showing radio status on other tabs
//

import SwiftUI

struct RadioOverlayView: View {
    let peerCount: Int
    let state: RadioState
    let onTap: () -> Void

    var body: some View {
        if state.isActive {
            Button(action: onTap) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(state == .transmitting ? Color.red : BCColors.brandGreen)
                        .frame(width: 8, height: 8)

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 11))

                    Text("\(peerCount)")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rally Radio active. \(peerCount) riders connected.")
        }
    }
}

#Preview {
    RadioOverlayView(peerCount: 3, state: .connected, onTap: {})
}
