//
//  PTTButton.swift
//  StoneBC
//
//  80pt push-to-talk button — press and hold to transmit
//

import SwiftUI

struct PTTButton: View {
    let isTransmitting: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: BCSpacing.sm) {
            Circle()
                .fill(isTransmitting ? Color.red : BCColors.brandBlue)
                .frame(width: RadioConfig.pttButtonSize, height: RadioConfig.pttButtonSize)
                .overlay {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }
                .shadow(color: isTransmitting ? .red.opacity(0.4) : .clear, radius: isTransmitting ? 12 : 0)
                .scaleEffect(isPressed ? 1.1 : 1.0)
                .animation(.spring(response: 0.2), value: isPressed)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isPressed {
                                isPressed = true
                                onPress()
                            }
                        }
                        .onEnded { _ in
                            isPressed = false
                            onRelease()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                )
                .accessibilityLabel("Push to talk")
                .accessibilityHint("Press and hold to transmit your voice")

            Text(isTransmitting ? "RELEASE TO STOP" : "HOLD TO TALK")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundColor(isTransmitting ? .red : .secondary)
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        PTTButton(isTransmitting: false, onPress: {}, onRelease: {})
        PTTButton(isTransmitting: true, onPress: {}, onRelease: {})
    }
    .padding()
}
