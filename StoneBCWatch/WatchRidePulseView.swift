//
//  WatchRidePulseView.swift
//  StoneBCWatch
//

import SwiftUI

struct WatchRidePulseView: View {
    @ObservedObject var model: WatchRidePulseModel
    @State private var isShowingNoteSheet = false

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { timeline in
            let stale = model.isStale(now: timeline.date)
            ScrollView {
                SafetyJournalDashboard(
                    model: model,
                    snapshot: model.snapshot,
                    stale: stale,
                    now: timeline.date,
                    onDictateNote: { isShowingNoteSheet = true }
                )
            }
            .accessibilityIdentifier("stonebc.watch.safetyJournal")
            .containerBackground(.black, for: .navigation)
            .sheet(isPresented: $isShowingNoteSheet) {
                DictatedNoteSheet { text in
                    model.sendJournalText(text)
                }
            }
        }
    }
}

private struct SafetyJournalDashboard: View {
    @ObservedObject var model: WatchRidePulseModel
    let snapshot: RidePulseSnapshot?
    let stale: Bool
    let now: Date
    let onDictateNote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            safetyCard
            journalCard
            emergencyCard
            if let snapshot {
                ridePulseCard(snapshot)
            } else {
                EmptyPulseView()
            }
            commandFooter
        }
        .padding(.horizontal, 2)
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(safetyTitle, systemImage: safetyIcon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(safetyColor)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(checkInTimeText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Button {
                model.sendCheckIn()
            } label: {
                Label("I'm OK", systemImage: "checkmark.seal.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .accessibilityIdentifier("stonebc.watch.checkIn")

            if stale {
                Text("Open StoneBC on iPhone for a fresh pulse.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(8)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var journalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Adventure Note", systemImage: "text.bubble.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.cyan)

            Text(journalStatusText)
                .font(.caption2)
                .foregroundStyle(canCreateJournalEntry ? Color.secondary : Color.orange)
                .lineLimit(2)

            Button {
                onDictateNote()
            } label: {
                Label("Dictate", systemImage: "mic.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!canCreateJournalEntry)
            .accessibilityIdentifier("stonebc.watch.dictate")
        }
        .padding(8)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var emergencyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Emergency", systemImage: "sos.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)

            Button(role: .destructive) {
                model.sendEmergencyHandoff()
            } label: {
                Label("SOS Handoff", systemImage: "iphone.radiowaves.left.and.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("stonebc.watch.sosHandoff")

            Text("Uses iPhone safety tools when reachable.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(8)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func ridePulseCard(_ snapshot: RidePulseSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.routeName.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(routeStatusText(snapshot))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(routeStatusColor(snapshot))
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                ProgressRing(value: snapshot.clampedProgress, color: routeStatusColor(snapshot))
                    .frame(width: 30, height: 30)
            }

            Text(primaryCue(snapshot))
                .font(.body.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            HStack {
                metricText(value: String(format: "%.1f mi", max(0, snapshot.distanceRemainingMiles)), label: "left")
                Spacer()
                metricText(value: "\(Int((snapshot.clampedProgress * 100).rounded()))%", label: "route")
            }
            ProgressView(value: snapshot.clampedProgress)
                .tint(routeStatusColor(snapshot))

            HStack {
                metricText(value: String(format: "%.0f", snapshot.speedMPH.rounded()), label: "mph")
                Spacer()
                Text(updateAge(snapshot))
                    .font(.caption2)
                    .foregroundStyle(stale ? Color.orange : Color.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var commandFooter: some View {
        HStack {
            if let status = model.lastCommandStatus {
                Text(status)
            } else if model.pendingCommandCount > 0 {
                Text("\(model.pendingCommandCount) queued")
            } else {
                Text(model.isReachable ? "Phone reachable" : "Queued when offline")
            }
            Spacer(minLength: 4)
            if model.pendingCommandCount > 0 {
                Image(systemName: "tray.and.arrow.up")
            }
        }
        .font(.caption2)
        .foregroundStyle(model.pendingCommandCount > 0 ? Color.orange : Color.secondary)
        .lineLimit(1)
    }

    private var canCreateJournalEntry: Bool {
        guard let snapshot,
              !stale,
              snapshot.activeJournalId != nil,
              snapshot.activeJournalDayNumber != nil else {
            return false
        }
        return true
    }

    private var journalStatusText: String {
        guard let snapshot, !stale else { return "Open StoneBC on iPhone" }
        guard let name = snapshot.activeJournalName,
              let day = snapshot.activeJournalDayNumber else {
            return "No active expedition"
        }
        return "\(name), day \(day)"
    }

    private var safetyTitle: String {
        guard let snapshot else { return "No Pulse" }
        if stale { return "Stale Pulse" }
        if snapshot.safetyState == .overdue { return "Check In" }
        if snapshot.safetyState == .active { return "Safety Active" }
        return "Safety Ready"
    }

    private var safetyIcon: String {
        guard let snapshot else { return "exclamationmark.triangle" }
        if stale || snapshot.safetyState == .overdue { return "timer" }
        return "checkmark.shield.fill"
    }

    private var safetyColor: Color {
        guard let snapshot else { return .orange }
        if stale || snapshot.safetyState == .overdue { return .orange }
        return snapshot.safetyState == .active ? .green : .secondary
    }

    private var checkInTimeText: String {
        guard let snapshot, snapshot.safetyState != .inactive else { return "--" }
        guard let deadline = snapshot.checkInDeadline else { return "--" }
        let remaining = deadline.timeIntervalSince(now)
        guard remaining > 0 else { return "OVERDUE" }
        return "\(Int(ceil(remaining / 60)))m"
    }

    private func routeStatusText(_ snapshot: RidePulseSnapshot) -> String {
        if stale { return "STALE" }
        if snapshot.isCriticalOffRoute { return "FAR OFF" }
        if snapshot.isOffRoute { return "OFF ROUTE" }
        if snapshot.rideState == .paused { return "PAUSED" }
        if snapshot.rideState == .ended || snapshot.rideState == .stopped { return "ENDED" }
        return snapshot.rideState == .recording ? "ON ROUTE" : "READY"
    }

    private func routeStatusColor(_ snapshot: RidePulseSnapshot) -> Color {
        if stale { return .orange }
        if snapshot.isCriticalOffRoute { return .red }
        if snapshot.isOffRoute { return .yellow }
        if snapshot.rideState == .paused { return .blue }
        return .green
    }

    private func primaryCue(_ snapshot: RidePulseSnapshot) -> String {
        if stale { return "Last pulse \(updateAge(snapshot).lowercased())" }
        if snapshot.safetyState == .overdue { return "Confirm you are OK" }
        if snapshot.isOffRoute { return "Rejoin route" }
        guard let cue = snapshot.nextCueText, !cue.isEmpty else { return "Keep rolling" }
        if let distance = snapshot.nextCueDistanceMeters {
            return "\(cue) · \(formatDistanceMeters(distance))"
        }
        return cue
    }

    private func updateAge(_ snapshot: RidePulseSnapshot) -> String {
        let age = max(0, now.timeIntervalSince(snapshot.updatedAt))
        if age < 90 { return "Updated now" }
        if age < 3600 { return "Updated \(Int(age / 60))m ago" }
        return "Updated \(Int(age / 3600))h ago"
    }

    private func metricText(value: String, label: String) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
            Text(label.uppercased())
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func formatDistanceMeters(_ meters: Double) -> String {
        if meters < 304.8 {
            return "\(Int((meters * 3.28084).rounded())) ft"
        }
        return String(format: "%.1f mi", meters / 1609.344)
    }
}

private struct DictatedNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("Adventure Note")
                    .font(.headline.weight(.bold))
                TextField("Dictate note", text: $text, axis: .vertical)
                    .lineLimit(2...5)
                    .accessibilityIdentifier("stonebc.watch.noteText")
                Spacer()
            }
            .padding(.top, 8)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("stonebc.watch.noteCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("stonebc.watch.noteSave")
                }
            }
        }
    }
}

private struct ProgressRing: View {
    let value: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 4)
            Circle()
                .trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct EmptyPulseView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "iphone.slash")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("Open StoneBC on iPhone")
                .font(.headline.weight(.bold))
            Text("No ride pulse")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    SafetyJournalDashboard(
        model: WatchRidePulseModel(),
        snapshot: RidePulseSnapshot(
            routeId: "route",
            routeName: "Skyline",
            rideState: .recording,
            updatedAt: Date(),
            effectiveStartedAt: Date().addingTimeInterval(-3700),
            pausedAt: nil,
            speedMPH: 11,
            distanceTraveledMiles: 12.4,
            distanceRemainingMiles: 8.2,
            progressPercent: 0.6,
            nextCueText: "Turn right",
            nextCueDistanceMeters: 180,
            isOffRoute: false,
            isCriticalOffRoute: false,
            safetyState: .active,
            powerMode: .balanced,
            phoneBatteryLevel: 0.72,
            phoneLowPowerModeEnabled: false,
            lastKnownCoordinate: RidePulseCoordinate(latitude: 44.08, longitude: -103.23),
            activeJournalId: "8over7",
            activeJournalName: "8 Over 7",
            activeJournalDayNumber: 2,
            checkInDeadline: Date().addingTimeInterval(1_800)
        ),
        stale: false,
        now: Date(),
        onDictateNote: {}
    )
}
