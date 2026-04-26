//
//  RideLiveActivityWidget.swift
//  RideWidgetExtension
//
//  Lock Screen + Dynamic Island UI for the StoneBC ride Live Activity.
//
//  The elapsed-time counter is rendered with `Text(timerInterval:pauseTime:)`
//  so the widget animates locally and the main app does not push every-second
//  updates to ActivityKit. `pauseTime` freezes the counter when the rider
//  pauses; clearing it resumes counting from `rideStartedAt`, which the app
//  already slid forward by accumulated paused seconds.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct RideLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { context in
            // MARK: Lock Screen / Banner
            LockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded — appears when user long-presses the island
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.distanceTraveledMiles, format: .number.precision(.fractionLength(1)))
                            .font(.title3)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "bicycle")
                    }
                    .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        timerLabel(for: context)
                            .font(.title3)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "stopwatch")
                    }
                    .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.attributes.routeName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if context.state.isOffRoute {
                            Label("OFF ROUTE", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(.orange)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "bicycle")
                    .foregroundStyle(context.state.isOffRoute ? .orange : .white)
            } compactTrailing: {
                timerLabel(for: context)
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                timerLabel(for: context)
                    .font(.caption2)
                    .monospacedDigit()
            }
            .keylineTint(context.state.isOffRoute ? .orange : .blue)
        }
    }

    /// Renders the elapsed timer locally — no per-second push from the app.
    /// `pauseTime` freezes the counter while the rider is paused.
    private func timerLabel(for context: ActivityViewContext<RideActivityAttributes>) -> Text {
        Text(
            timerInterval: context.state.rideStartedAt...Date.distantFuture,
            pauseTime: context.state.pausedAt,
            countsDown: false,
            showsHours: true
        )
    }
}

// MARK: - Lock Screen view

private struct LockScreenView: View {
    let context: ActivityViewContext<RideActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(context.attributes.routeName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                if context.state.isOffRoute {
                    Label("OFF ROUTE", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 16) {
                stat(
                    value: speedText,
                    unit: "mph",
                    icon: "speedometer"
                )
                stat(
                    value: distanceText,
                    unit: "mi",
                    icon: "point.topleft.down.to.point.bottomright.curvepath.fill"
                )
                stat(
                    value: timerLabel,
                    unit: nil,
                    icon: "stopwatch"
                )
            }

            ProgressView(value: max(0, min(context.state.progressPercent, 1)))
                .progressViewStyle(.linear)
                .tint(context.state.isOffRoute ? .orange : .blue)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var speedText: Text {
        Text(context.state.speedMPH, format: .number.precision(.fractionLength(0)))
    }

    private var distanceText: Text {
        Text(context.state.distanceTraveledMiles, format: .number.precision(.fractionLength(1)))
    }

    private var timerLabel: Text {
        Text(
            timerInterval: context.state.rideStartedAt...Date.distantFuture,
            pauseTime: context.state.pausedAt,
            countsDown: false,
            showsHours: true
        )
    }

    private func stat(value: Text, unit: String?, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                value
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                if let unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
