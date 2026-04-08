//
//  RouteWeatherView.swift
//  StoneBC
//
//  Weather section for route detail — current conditions, wind analysis,
//  hourly forecast, and best ride window recommendation.
//

import SwiftUI
import CoreLocation

// MARK: - Route Weather Section (embeddable in RouteDetailView)

struct RouteWeatherSection: View {
    let route: Route
    @State private var weather: RouteWeather?
    @State private var rideWindow: RideWindow?
    @State private var isLoading = true

    private var routeBearing: Double {
        guard route.clTrackpoints.count >= 2 else { return 0 }
        let start = route.clTrackpoints[0]
        // Use a point ~10% into the route for initial bearing
        let idx = min(route.clTrackpoints.count / 10, route.clTrackpoints.count - 1)
        let next = route.clTrackpoints[idx]
        return bearing(from: start, to: next)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WEATHER AT START")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading weather...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else if let weather {
                VStack(spacing: 12) {
                    // Current conditions row
                    currentConditionsRow(weather)

                    // Wind analysis
                    windAnalysisRow(weather)

                    // Ride window recommendation
                    if let window = rideWindow {
                        rideWindowRow(window)
                    }

                    // Hourly mini forecast
                    hourlyStrip(weather)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "cloud.slash")
                        .foregroundColor(.secondary)
                    Text("Weather unavailable")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task {
            let coord = route.clStartCoordinate
            async let weatherTask = WeatherService.shared.weather(for: coord)
            async let windowTask = WeatherService.shared.bestRideWindow(
                for: coord,
                rideDurationHours: max(1, route.distanceMiles / 12) // estimate ~12mph avg
            )
            weather = await weatherTask
            rideWindow = await windowTask
            isLoading = false
        }
    }

    // MARK: - Current Conditions

    private func currentConditionsRow(_ w: RouteWeather) -> some View {
        HStack(spacing: 16) {
            // Temperature + condition
            HStack(spacing: 8) {
                Image(systemName: w.symbolName)
                    .font(.system(size: 22))
                    .foregroundColor(.orange)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.0f°F", w.temperature))
                        .font(.system(size: 20, weight: .bold))
                    Text(w.condition)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Quick stats
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                    Text(String(format: "%.0f%%", w.precipitationChance * 100))
                        .font(.system(size: 11, weight: .medium))
                }
                HStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                    Text("UV \(w.uvIndex)")
                        .font(.system(size: 11, weight: .medium))
                }
                HStack(spacing: 4) {
                    Image(systemName: "humidity.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.cyan)
                    Text(String(format: "%.0f%%", w.humidity))
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Wind Analysis

    private func windAnalysisRow(_ w: RouteWeather) -> some View {
        let wind = WeatherService.windComponent(
            windDirection: w.windDirection,
            routeBearing: routeBearing,
            windSpeed: w.windSpeedMPH
        )

        return HStack(spacing: 12) {
            // Wind arrow (rotated to show direction relative to route)
            ZStack {
                Circle()
                    .fill(windColor(wind.type).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(windColor(wind.type))
                    .rotationEffect(.degrees(w.windDirection))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(wind.type.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(windColor(wind.type))
                    Text(String(format: "%.0f mph", w.windSpeedMPH))
                        .font(.system(size: 13, weight: .medium))
                }
                if let gust = w.windGustMPH {
                    Text(String(format: "Gusts to %.0f mph", gust))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Impact badge
            VStack(spacing: 2) {
                Text(windImpact(w.windSpeedMPH, type: wind.type))
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(windColor(wind.type).opacity(0.15))
                    .foregroundColor(windColor(wind.type))
                    .clipShape(Capsule())
            }
        }
        .padding(10)
        .background(windColor(wind.type).opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Ride Window

    private func rideWindowRow(_ window: RideWindow) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 14))
                .foregroundColor(BCColors.brandGreen)

            VStack(alignment: .leading, spacing: 2) {
                Text("Best Ride Window")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(BCColors.brandGreen)
                HStack(spacing: 8) {
                    Text(window.timeRange)
                        .font(.system(size: 12, weight: .medium))
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f°F", window.avgTemperature))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f mph wind", window.avgWindMPH))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    if window.maxPrecipChance > 0.1 {
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f%% rain", window.maxPrecipChance * 100))
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()
        }
        .padding(10)
        .background(BCColors.brandGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Hourly Strip

    private func hourlyStrip(_ w: RouteWeather) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Array(w.hourlyForecast.prefix(12).enumerated()), id: \.offset) { _, hour in
                    VStack(spacing: 4) {
                        Text(hourLabel(hour.date))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                        Image(systemName: hour.symbolName)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                            .frame(height: 16)
                        Text(String(format: "%.0f°", hour.temperature))
                            .font(.system(size: 11, weight: .semibold))
                        if hour.precipitationChance > 0.1 {
                            Text(String(format: "%.0f%%", hour.precipitationChance * 100))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func windColor(_ type: WindType) -> Color {
        switch type {
        case .headwind: .red
        case .tailwind: .green
        case .crosswind: .orange
        }
    }

    private func windImpact(_ speed: Double, type: WindType) -> String {
        if type == .tailwind { return "BOOST" }
        if speed > 25 { return "SEVERE" }
        if speed > 15 { return "STRONG" }
        if speed > 8 { return "MODERATE" }
        return "LIGHT"
    }

    private func hourLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "ha"
        return fmt.string(from: date).lowercased()
    }

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}
