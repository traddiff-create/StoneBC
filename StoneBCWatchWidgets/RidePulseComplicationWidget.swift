//
//  RidePulseComplicationWidget.swift
//  StoneBCWatchWidgets
//

import SwiftUI
import WidgetKit

@main
struct StoneBCWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        RidePulseComplicationWidget()
    }
}

struct RidePulseComplicationWidget: Widget {
    static let kind = RidePulseConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: RidePulseTimelineProvider()) { entry in
            RidePulseWidgetView(entry: entry)
        }
        .configurationDisplayName("Ride Pulse")
        .description("StoneBC route pulse")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

struct RidePulseTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: RidePulseSnapshot?
}

struct RidePulseTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RidePulseTimelineEntry {
        RidePulseTimelineEntry(date: Date(), snapshot: placeholderSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (RidePulseTimelineEntry) -> Void) {
        completion(RidePulseTimelineEntry(date: Date(), snapshot: RidePulseStore.shared.loadSnapshot() ?? placeholderSnapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RidePulseTimelineEntry>) -> Void) {
        let now = Date()
        let snapshot = RidePulseStore.shared.loadSnapshot()
        let staleDate = snapshot?.updatedAt.addingTimeInterval(RidePulseConstants.staleAfter)
        let rollover = staleDate.map { max($0, now.addingTimeInterval(60)) } ?? now.addingTimeInterval(30 * 60)

        let entries = [
            RidePulseTimelineEntry(date: now, snapshot: snapshot),
            RidePulseTimelineEntry(date: rollover, snapshot: snapshot)
        ]
        completion(Timeline(entries: entries, policy: .after(rollover.addingTimeInterval(60))))
    }

    private var placeholderSnapshot: RidePulseSnapshot {
        RidePulseSnapshot(
            routeId: "preview",
            routeName: "StoneBC",
            rideState: .recording,
            updatedAt: Date(),
            effectiveStartedAt: Date().addingTimeInterval(-1800),
            pausedAt: nil,
            speedMPH: 10,
            distanceTraveledMiles: 6.4,
            distanceRemainingMiles: 3.6,
            progressPercent: 0.64,
            nextCueText: "Turn right",
            nextCueDistanceMeters: 120,
            isOffRoute: false,
            isCriticalOffRoute: false,
            safetyState: .active,
            powerMode: .balanced,
            phoneBatteryLevel: nil,
            phoneLowPowerModeEnabled: false
        )
    }
}

struct RidePulseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RidePulseTimelineEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .accessoryCorner:
            corner
        case .accessoryInline:
            inline
        default:
            rectangular
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let snapshot = entry.snapshot {
                Gauge(value: snapshot.clampedProgress) {
                    Image(systemName: iconName(for: snapshot))
                } currentValueLabel: {
                    Text(circularValue(for: snapshot))
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                }
                .gaugeStyle(.accessoryCircular)
                .tint(color(for: snapshot))
            } else {
                Image(systemName: "bicycle")
            }
        }
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.snapshot.map(iconName(for:)) ?? "bicycle")
                .foregroundStyle(entry.snapshot.map(color(for:)) ?? .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(primaryText)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(secondaryText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
    }

    private var corner: some View {
        Text(cornerText)
            .widgetLabel {
                Gauge(value: entry.snapshot?.clampedProgress ?? 0) {
                    Text("Pulse")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(entry.snapshot.map(color(for:)) ?? .secondary)
            }
    }

    private var inline: some View {
        Text("\(Image(systemName: entry.snapshot.map(iconName(for:)) ?? "bicycle")) \(primaryText)")
    }

    private var primaryText: String {
        guard let snapshot = entry.snapshot else { return "Open StoneBC" }
        if snapshot.isStale(now: entry.date) { return "StoneBC stale" }
        if snapshot.safetyState == .overdue { return "Check in" }
        if snapshot.isOffRoute { return "Off route" }
        if let cue = snapshot.nextCueText, !cue.isEmpty {
            return cue
        }
        return String(format: "%.1f mi left", max(0, snapshot.distanceRemainingMiles))
    }

    private var secondaryText: String {
        guard let snapshot = entry.snapshot else { return "No ride pulse" }
        if snapshot.isStale(now: entry.date) { return updateAge(for: snapshot) }
        if let meters = snapshot.nextCueDistanceMeters {
            return "\(formatDistanceMeters(meters)) · \(String(format: "%.1f mi", max(0, snapshot.distanceRemainingMiles))) left"
        }
        return "\(Int((snapshot.clampedProgress * 100).rounded()))% · \(String(format: "%.1f mi", max(0, snapshot.distanceRemainingMiles))) left"
    }

    private var cornerText: String {
        guard let snapshot = entry.snapshot else { return "--" }
        if snapshot.isStale(now: entry.date) { return "stale" }
        if snapshot.isOffRoute { return "off" }
        return String(format: "%.0f", max(0, snapshot.distanceRemainingMiles))
    }

    private func circularValue(for snapshot: RidePulseSnapshot) -> String {
        if snapshot.isStale(now: entry.date) { return "!" }
        if snapshot.isOffRoute { return "OFF" }
        return "\(Int((snapshot.clampedProgress * 100).rounded()))"
    }

    private func iconName(for snapshot: RidePulseSnapshot) -> String {
        if snapshot.isStale(now: entry.date) { return "iphone.slash" }
        if snapshot.safetyState == .overdue { return "timer" }
        if snapshot.isOffRoute { return "exclamationmark.triangle.fill" }
        if snapshot.rideState == .paused { return "pause.fill" }
        return "bicycle"
    }

    private func color(for snapshot: RidePulseSnapshot) -> Color {
        if snapshot.isStale(now: entry.date) || snapshot.safetyState == .overdue { return .orange }
        if snapshot.isCriticalOffRoute { return .red }
        if snapshot.isOffRoute { return .yellow }
        if snapshot.rideState == .paused { return .blue }
        return .green
    }

    private func formatDistanceMeters(_ meters: Double) -> String {
        if meters < 304.8 {
            return "\(Int((meters * 3.28084).rounded())) ft"
        }
        return String(format: "%.1f mi", meters / 1609.344)
    }

    private func updateAge(for snapshot: RidePulseSnapshot) -> String {
        let age = max(0, entry.date.timeIntervalSince(snapshot.updatedAt))
        if age < 3600 { return "\(Int(age / 60))m ago" }
        return "\(Int(age / 3600))h ago"
    }
}

#Preview(as: .accessoryRectangular) {
    RidePulseComplicationWidget()
} timeline: {
    RidePulseTimelineEntry(
        date: Date(),
        snapshot: RidePulseSnapshot(
            routeId: "preview",
            routeName: "Skyline",
            rideState: .recording,
            updatedAt: Date(),
            effectiveStartedAt: Date().addingTimeInterval(-1800),
            pausedAt: nil,
            speedMPH: 10,
            distanceTraveledMiles: 6.4,
            distanceRemainingMiles: 3.6,
            progressPercent: 0.64,
            nextCueText: "Turn right",
            nextCueDistanceMeters: 120,
            isOffRoute: false,
            isCriticalOffRoute: false,
            safetyState: .active,
            powerMode: .balanced,
            phoneBatteryLevel: nil,
            phoneLowPowerModeEnabled: false
        )
    )
}
