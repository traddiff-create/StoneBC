//
//  RideAlertsSettingsView.swift
//  StoneBC
//
//  Edit time- and distance-based ride alerts. Toggle, change interval,
//  pick a signature sound, preview, add custom, delete.
//

import SwiftUI

struct RideAlertsSettingsView: View {
    @State private var service = RideAlertService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BCSpacing.md) {
                header

                ForEach(service.alerts) { alert in
                    AlertRow(
                        alert: alert,
                        onToggle: { service.toggle(alert.id) },
                        onUpdate: { service.update($0) },
                        onPreview: { service.preview($0) },
                        onDelete: { service.delete(alert.id) }
                    )
                }

                Button {
                    _ = service.add()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Custom Alert")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(BCColors.brandBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, BCSpacing.md)
                    .background(BCColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                footer
            }
            .padding(BCSpacing.md)
        }
        .background(BCColors.background)
        .navigationTitle("Ride Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Signature beeps fire while you're navigating a route — to remind you to eat, drink, or check your chain. Works in airplane mode.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private var footer: some View {
        Text("Beeps mix with music and respect the silent switch. Disable any alert to silence it.")
            .font(.system(size: 10))
            .foregroundColor(BCColors.tertiaryText)
            .padding(.top, BCSpacing.sm)
    }
}

// MARK: - Row

private struct AlertRow: View {
    let alert: RideAlertService.Alert
    let onToggle: () -> Void
    let onUpdate: (RideAlertService.Alert) -> Void
    let onPreview: (RideAlertService.SignatureSound) -> Void
    let onDelete: () -> Void

    @State private var draft: RideAlertService.Alert
    @State private var showDeleteConfirm = false

    init(
        alert: RideAlertService.Alert,
        onToggle: @escaping () -> Void,
        onUpdate: @escaping (RideAlertService.Alert) -> Void,
        onPreview: @escaping (RideAlertService.SignatureSound) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.alert = alert
        self.onToggle = onToggle
        self.onUpdate = onUpdate
        self.onPreview = onPreview
        self.onDelete = onDelete
        _draft = State(initialValue: alert)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            HStack {
                TextField("Label", text: $draft.label)
                    .font(.system(size: 15, weight: .medium))
                    .textFieldStyle(.plain)
                    .onSubmit { onUpdate(draft) }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { alert.enabled },
                    set: { _ in onToggle() }
                ))
                .labelsHidden()
                .tint(BCColors.brandGreen)
            }

            Picker("Kind", selection: $draft.kind) {
                ForEach(RideAlertService.AlertKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: draft.kind) { _, _ in onUpdate(draft) }

            intervalControl

            HStack(spacing: BCSpacing.sm) {
                Text("SOUND")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)

                ForEach(RideAlertService.SignatureSound.allCases) { sound in
                    soundChip(sound)
                }

                Spacer()

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(alert.enabled ? 1.0 : 0.65)
        .onChange(of: draft.label) { _, _ in onUpdate(draft) }
        .confirmationDialog("Delete this alert?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var intervalControl: some View {
        HStack {
            Text(draft.kind == .time ? "Every" : "Every")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            if draft.kind == .time {
                Stepper(
                    value: $draft.intervalMinutes,
                    in: 1...240,
                    step: 5
                ) {
                    Text("\(draft.intervalMinutes) min")
                        .font(.system(size: 14, weight: .medium))
                        .monospacedDigit()
                }
                .onChange(of: draft.intervalMinutes) { _, _ in onUpdate(draft) }
            } else {
                Stepper(
                    value: $draft.intervalMiles,
                    in: 0.5...200,
                    step: 0.5
                ) {
                    Text(String(format: "%.1f mi", draft.intervalMiles))
                        .font(.system(size: 14, weight: .medium))
                        .monospacedDigit()
                }
                .onChange(of: draft.intervalMiles) { _, _ in onUpdate(draft) }
            }
        }
    }

    private func soundChip(_ sound: RideAlertService.SignatureSound) -> some View {
        let isSelected = draft.sound == sound
        return Button {
            draft.sound = sound
            onUpdate(draft)
            onPreview(sound)
        } label: {
            Text(sound.label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? BCColors.accent : BCColors.secondaryFill)
                .foregroundColor(isSelected ? BCColors.accentForeground : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        RideAlertsSettingsView()
    }
}
