//
//  SunsetPillView.swift
//  StoneBC
//
//  Compact daylight-remaining pill. Reads `RouteWeather.secondsUntilSunset` and
//  formats as "3h 22m" or "0:42" when under an hour. Turns urgent under 60 min.
//  Renders in two styles: pre-ride badge (light) and active-ride sensor tile (dark).
//

import SwiftUI

struct SunsetPillView: View {
    let weather: RouteWeather?
    var style: Style = .badge

    enum Style { case badge, sensorTile }

    var body: some View {
        switch style {
        case .badge: badgeBody
        case .sensorTile: sensorBody
        }
    }

    // Pre-ride: small capsule next to other weather chips
    private var badgeBody: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.15))
        .foregroundColor(tint)
        .clipShape(Capsule())
        .accessibilityLabel(accessibilityText)
    }

    // Active ride: matches the sensor strip tile shape (white-on-black)
    private var sensorBody: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isUrgent ? Color(red: 0.96, green: 0.45, blue: 0.18) : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("LIGHT")
                .font(.system(size: 10, weight: .medium))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Derived

    private var label: String {
        guard let seconds = weather?.secondsUntilSunset else { return "—" }
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return String(format: "0:%02d", minutes)
        }
        return "\(hours)h \(minutes)m"
    }

    private var isUrgent: Bool {
        guard let seconds = weather?.secondsUntilSunset else { return false }
        return seconds < 60 * 60
    }

    private var icon: String {
        isUrgent ? "sun.horizon.fill" : "sun.max.fill"
    }

    private var tint: Color {
        if weather?.secondsUntilSunset == nil { return .secondary }
        return isUrgent ? .orange : BCColors.brandAmber
    }

    private var accessibilityText: String {
        guard weather?.secondsUntilSunset != nil else { return "Daylight remaining unknown" }
        return "Daylight remaining: \(label)"
    }
}

#Preview("Badge") {
    SunsetPillView(weather: nil, style: .badge)
        .padding()
}
