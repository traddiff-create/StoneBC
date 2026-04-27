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
            Rectangle()
                .fill(isTransmitting ? BCColors.danger : BCColors.brandBlue)
                .frame(width: RadioConfig.pttButtonSize, height: RadioConfig.pttButtonSize)
                .overlay {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }
                .overlay {
                    Rectangle()
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                }
                .opacity(isPressed ? 0.86 : 1.0)
                .animation(.linear(duration: 0.08), value: isPressed)
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
                .font(.ridrMicro)
                .tracking(1.5)
                .foregroundColor(isTransmitting ? BCColors.danger : BCColors.cockpitMutedText)
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
