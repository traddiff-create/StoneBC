import SwiftUI

struct DisclaimerBannerView: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)

                    Text("Route data is provided for reference only. Verify conditions before riding.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text("""
                    Route information in this app is provided for general reference only. \
                    Stone Bicycle Coalition cannot verify current trail conditions, road closures, \
                    hazards, or access restrictions. Conditions change — always confirm before riding. \
                    You assume all risk associated with your ride. Ride responsibly, wear appropriate \
                    safety equipment, and follow all applicable laws and regulations.
                    """)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    VStack(spacing: 16) {
        DisclaimerBannerView()
        DisclaimerBannerView()
    }
    .padding()
}
