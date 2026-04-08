//
//  RadioView.swift
//  StoneBC
//
//  Rally Radio — main interface with PTT, peer list, open mic toggle
//

import SwiftUI

struct RadioView: View {
    @Environment(AppState.self) var appState
    @State private var hasPermission = false
    @State private var showPermissionAlert = false

    private var viewModel: RadioViewModel {
        appState.radioViewModel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BCColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Status
                    statusSection

                    Spacer().frame(height: BCSpacing.xl)

                    // Peer list
                    if !viewModel.connectedPeers.isEmpty {
                        peerSection
                    }

                    Spacer()

                    // PTT Button
                    pttSection

                    Spacer().frame(height: BCSpacing.lg)

                    // Open Mic toggle
                    openMicToggle

                    Spacer().frame(height: BCSpacing.lg)

                    // Connect/Disconnect
                    connectionButton

                    Spacer().frame(height: BCSpacing.xl)
                }
                .padding(.horizontal, BCSpacing.md)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("RALLY RADIO")
                            .font(.bcSectionTitle)
                            .tracking(2)
                        if viewModel.state.isActive {
                            Text("\(viewModel.peerCount) rider\(viewModel.peerCount == 1 ? "" : "s")")
                                .font(.bcMicro)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .alert("Microphone Access", isPresented: $showPermissionAlert) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Rally Radio needs microphone access for voice chat. Enable it in Settings.")
            }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(spacing: BCSpacing.sm) {
            // Radio icon
            Image(systemName: viewModel.state == .transmitting ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 36, weight: .thin))
                .foregroundColor(viewModel.state.color)
                .symbolEffect(.pulse, isActive: viewModel.state == .transmitting)

            Text(viewModel.state.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(viewModel.state.color)
                .tracking(1)

            if let speaker = viewModel.currentSpeaker {
                Text("\(speaker) is talking")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.state)
    }

    // MARK: - Peers

    private var peerSection: some View {
        VStack(spacing: BCSpacing.sm) {
            Text("CONNECTED RIDERS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.connectedPeers) { peer in
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(peer.isTransmitting ? Color.red.opacity(0.2) : BCColors.brandBlue.opacity(0.1))
                                    .frame(width: RadioConfig.peerAvatarSize, height: RadioConfig.peerAvatarSize)

                                Text(peer.initials)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(peer.isTransmitting ? .red : BCColors.brandBlue)
                            }

                            Text(peer.displayName)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 60)
                    }
                }
                .padding(.horizontal, BCSpacing.md)
            }
        }
    }

    // MARK: - PTT Button

    private var pttSection: some View {
        VStack(spacing: BCSpacing.sm) {
            if viewModel.isOpenMic {
                // Open mic active — show live indicator instead of PTT
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: RadioConfig.pttButtonSize, height: RadioConfig.pttButtonSize)
                        .overlay {
                            Text("LIVE")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .tracking(2)
                        }
                        .symbolEffect(.pulse, isActive: true)

                    Text("Open mic active")
                        .font(.bcMicro)
                        .foregroundColor(.secondary)
                }
            } else {
                PTTButton(isTransmitting: viewModel.state == .transmitting) {
                    startTransmitting()
                } onRelease: {
                    viewModel.stopTransmitting()
                }
                .disabled(!viewModel.state.isActive)
                .opacity(viewModel.state.isActive ? 1 : 0.4)
            }
        }
    }

    // MARK: - Open Mic

    private var openMicToggle: some View {
        HStack {
            Image(systemName: "mic.fill")
                .font(.system(size: 14))
                .foregroundColor(viewModel.isOpenMic ? .red : .secondary)

            Text("Open Mic")
                .font(.system(size: 14, weight: .medium))

            Spacer()

            Toggle("", isOn: Binding(
                get: { viewModel.isOpenMic },
                set: { _ in viewModel.toggleOpenMic() }
            ))
            .tint(.red)
        }
        .padding(.horizontal, BCSpacing.lg)
        .padding(.vertical, 12)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(!viewModel.state.isActive)
        .opacity(viewModel.state.isActive ? 1 : 0.4)
    }

    // MARK: - Connection

    private var connectionButton: some View {
        Button {
            if viewModel.state.isActive {
                viewModel.stopRadio()
            } else {
                Task { await connectRadio() }
            }
        } label: {
            HStack {
                Image(systemName: viewModel.state.isActive ? "xmark.circle.fill" : "antenna.radiowaves.left.and.right")
                Text(viewModel.state.isActive ? "Disconnect" : "Start Rally Radio")
            }
            .font(.system(size: 15, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(viewModel.state.isActive ? Color.red.opacity(0.15) : BCColors.brandBlue)
            .foregroundColor(viewModel.state.isActive ? .red : .white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.horizontal, BCSpacing.lg)
    }

    // MARK: - Helpers

    private func connectRadio() async {
        let granted = await viewModel.requestMicrophonePermission()
        if granted {
            hasPermission = true
            viewModel.startRadio()
        } else {
            showPermissionAlert = true
        }
    }

    private func startTransmitting() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        viewModel.startTransmitting()
    }
}

#Preview {
    RadioView()
        .environment(AppState())
}
