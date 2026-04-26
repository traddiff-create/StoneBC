//
//  OfflineBannerView.swift
//  StoneBC
//
//  Compact banner shown when the device has no network connectivity.
//  Reassures riders that GPS navigation, compass, and saved routes still work.
//

import SwiftUI

struct OfflineBannerView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.orange)

            Text("Offline — GPS, compass & saved routes still work")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.orange)

            Spacer()
        }
        .padding(.horizontal, BCSpacing.md)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// Modifier that conditionally shows the offline banner
struct OfflineAwareModifier: ViewModifier {
    let connectivity = ConnectivityService.shared

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            if !connectivity.isConnected {
                OfflineBannerView()
            }
            content
        }
        .animation(.easeInOut(duration: 0.3), value: connectivity.isConnected)
    }
}

extension View {
    func offlineAware() -> some View {
        modifier(OfflineAwareModifier())
    }
}
