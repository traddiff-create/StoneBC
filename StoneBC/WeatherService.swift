//
//  WeatherService.swift
//  StoneBC
//
//  WeatherKit wrapper — current conditions + hourly forecast with caching.
//  Wind direction relative to route bearing for headwind/tailwind detection.
//

import WeatherKit
import CoreLocation
import Foundation

@Observable
class WeatherService {
    static let shared = WeatherService()

    var isLoading = false
    var error: String?

    // Cache: keyed by rounded lat/lon string, expires after 30 min
    private var cache: [String: CachedWeather] = [:]
    private let cacheExpiry: TimeInterval = 30 * 60 // 30 minutes

    private let service = WeatherKit.WeatherService()

    private init() {}

    // MARK: - Fetch Weather

    /// Fetch current + hourly weather for a location
    func weather(for coordinate: CLLocationCoordinate2D) async -> RouteWeather? {
        let key = cacheKey(for: coordinate)

        // Return cached if fresh
        if let cached = cache[key], Date().timeIntervalSince(cached.fetchedAt) < cacheExpiry {
            return cached.weather
        }

        isLoading = true
        defer { isLoading = false }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let (current, hourly, daily) = try await service.weather(
                for: location,
                including: .current, .hourly, .daily
            )

            let today = daily.forecast.first { Calendar.current.isDateInToday($0.date) }
                ?? daily.forecast.first
            let tomorrow = daily.forecast.first { Calendar.current.isDateInTomorrow($0.date) }

            let result = RouteWeather(
                temperature: current.temperature.converted(to: .fahrenheit).value,
                feelsLike: current.apparentTemperature.converted(to: .fahrenheit).value,
                humidity: current.humidity * 100,
                windSpeedMPH: current.wind.speed.converted(to: .milesPerHour).value,
                windDirection: current.wind.direction.converted(to: .degrees).value,
                windGustMPH: current.wind.gust?.converted(to: .milesPerHour).value,
                condition: current.condition.description,
                symbolName: current.symbolName,
                uvIndex: current.uvIndex.value,
                precipitationChance: hourly.forecast.first?.precipitationChance ?? 0,
                sunriseToday: today?.sun.sunrise,
                sunsetToday: today?.sun.sunset,
                sunriseTomorrow: tomorrow?.sun.sunrise,
                hourlyForecast: hourly.forecast.prefix(24).map { hour in
                    HourForecast(
                        date: hour.date,
                        temperature: hour.temperature.converted(to: .fahrenheit).value,
                        windSpeedMPH: hour.wind.speed.converted(to: .milesPerHour).value,
                        windDirection: hour.wind.direction.converted(to: .degrees).value,
                        precipitationChance: hour.precipitationChance,
                        condition: hour.condition.description,
                        symbolName: hour.symbolName
                    )
                }
            )

            cache[key] = CachedWeather(weather: result, fetchedAt: Date())
            error = nil
            return result
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    /// Fetch weather at multiple points along a route
    func weatherAlongRoute(_ route: Route, sampleCount: Int = 5) async -> [RoutePointWeather] {
        let trackpoints = route.clTrackpoints
        guard trackpoints.count >= 2 else { return [] }

        // Sample evenly spaced points
        let step = max(1, trackpoints.count / sampleCount)
        var points: [(index: Int, coord: CLLocationCoordinate2D)] = []
        for i in stride(from: 0, to: trackpoints.count, by: step) {
            points.append((i, trackpoints[i]))
        }
        // Always include last point
        if points.last?.index != trackpoints.count - 1 {
            points.append((trackpoints.count - 1, trackpoints.last!))
        }

        var results: [RoutePointWeather] = []
        for (index, coord) in points {
            if let weather = await weather(for: coord) {
                let mileEstimate = Double(index) / Double(max(trackpoints.count - 1, 1)) * route.distanceMiles
                results.append(RoutePointWeather(
                    mileMarker: mileEstimate,
                    coordinate: coord,
                    weather: weather
                ))
            }
        }

        return results
    }

    // MARK: - Wind Analysis

    /// Calculate headwind/tailwind component given wind direction and route bearing
    static func windComponent(windDirection: Double, routeBearing: Double, windSpeed: Double) -> WindComponent {
        // Wind direction is where wind comes FROM (meteorological convention)
        // Route bearing is where rider is GOING
        let relativeAngle = abs((windDirection - routeBearing + 360).truncatingRemainder(dividingBy: 360))

        // 0° = pure headwind, 180° = pure tailwind, 90°/270° = crosswind
        let headwindComponent: Double
        let crosswindComponent: Double

        if relativeAngle <= 180 {
            headwindComponent = cos(relativeAngle * .pi / 180) * windSpeed
            crosswindComponent = sin(relativeAngle * .pi / 180) * windSpeed
        } else {
            headwindComponent = cos((360 - relativeAngle) * .pi / 180) * windSpeed
            crosswindComponent = sin((360 - relativeAngle) * .pi / 180) * windSpeed
        }

        let type: WindType
        if abs(headwindComponent) < 2 {
            type = .crosswind
        } else if headwindComponent > 0 {
            type = .headwind
        } else {
            type = .tailwind
        }

        return WindComponent(
            headwindMPH: headwindComponent,
            crosswindMPH: abs(crosswindComponent),
            type: type
        )
    }

    // MARK: - Ride Window

    /// Analyze hourly forecast to find the best ride window
    func bestRideWindow(for coordinate: CLLocationCoordinate2D, rideDurationHours: Double = 3) async -> RideWindow? {
        guard let weather = await weather(for: coordinate) else { return nil }
        let forecast = weather.hourlyForecast

        guard forecast.count >= 4 else { return nil }

        var bestScore: Double = -1
        var bestStartIndex: Int = 0

        let windowSize = max(1, Int(rideDurationHours))

        for i in 0...(forecast.count - windowSize) {
            let window = Array(forecast[i..<min(i + windowSize, forecast.count)])
            let score = rideScore(for: window)
            if score > bestScore {
                bestScore = score
                bestStartIndex = i
            }
        }

        let bestWindow = Array(forecast[bestStartIndex..<min(bestStartIndex + windowSize, forecast.count)])
        guard let first = bestWindow.first, let last = bestWindow.last else { return nil }

        let avgTemp = bestWindow.map(\.temperature).reduce(0, +) / Double(bestWindow.count)
        let avgWind = bestWindow.map(\.windSpeedMPH).reduce(0, +) / Double(bestWindow.count)
        let maxPrecip = bestWindow.map(\.precipitationChance).max() ?? 0

        return RideWindow(
            startTime: first.date,
            endTime: last.date.addingTimeInterval(3600),
            avgTemperature: avgTemp,
            avgWindMPH: avgWind,
            maxPrecipChance: maxPrecip,
            score: bestScore
        )
    }

    /// Score a window of hours for ride-ability (0-100)
    private func rideScore(for hours: [HourForecast]) -> Double {
        var score: Double = 100

        for hour in hours {
            // Precipitation penalty (biggest factor)
            score -= hour.precipitationChance * 40

            // Wind penalty (over 15 mph gets bad)
            if hour.windSpeedMPH > 25 { score -= 20 }
            else if hour.windSpeedMPH > 15 { score -= 10 }
            else if hour.windSpeedMPH > 10 { score -= 3 }

            // Temperature — ideal 55-80°F
            if hour.temperature < 35 { score -= 15 }
            else if hour.temperature < 45 { score -= 8 }
            else if hour.temperature < 55 { score -= 3 }
            else if hour.temperature > 95 { score -= 15 }
            else if hour.temperature > 85 { score -= 5 }
        }

        return max(0, score / Double(hours.count))
    }

    // MARK: - Helpers

    private func cacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        // Round to ~0.5 mile grid for cache dedup
        let lat = (coordinate.latitude * 100).rounded() / 100
        let lon = (coordinate.longitude * 100).rounded() / 100
        return "\(lat),\(lon)"
    }
}

// MARK: - Models

struct RouteWeather {
    let temperature: Double         // °F
    let feelsLike: Double           // °F
    let humidity: Double            // %
    let windSpeedMPH: Double
    let windDirection: Double       // degrees (meteorological: where wind comes FROM)
    let windGustMPH: Double?
    let condition: String           // "Partly Cloudy", "Rain", etc.
    let symbolName: String          // SF Symbol name
    let uvIndex: Int
    let precipitationChance: Double // 0-1
    let sunriseToday: Date?
    let sunsetToday: Date?
    let sunriseTomorrow: Date?
    let hourlyForecast: [HourForecast]

    /// Time remaining until today's sunset, or nil if sunset already passed or unknown.
    var secondsUntilSunset: TimeInterval? {
        guard let sunset = sunsetToday else { return nil }
        let delta = sunset.timeIntervalSinceNow
        return delta > 0 ? delta : nil
    }
}

struct HourForecast {
    let date: Date
    let temperature: Double
    let windSpeedMPH: Double
    let windDirection: Double
    let precipitationChance: Double
    let condition: String
    let symbolName: String
}

struct RoutePointWeather {
    let mileMarker: Double
    let coordinate: CLLocationCoordinate2D
    let weather: RouteWeather
}

struct WindComponent {
    let headwindMPH: Double    // positive = headwind, negative = tailwind
    let crosswindMPH: Double
    let type: WindType
}

enum WindType {
    case headwind, tailwind, crosswind

    var label: String {
        switch self {
        case .headwind: "Headwind"
        case .tailwind: "Tailwind"
        case .crosswind: "Crosswind"
        }
    }

    var icon: String {
        switch self {
        case .headwind: "arrow.down"
        case .tailwind: "arrow.up"
        case .crosswind: "arrow.left.arrow.right"
        }
    }

    var color: String {
        switch self {
        case .headwind: "red"
        case .tailwind: "green"
        case .crosswind: "orange"
        }
    }
}

struct RideWindow {
    let startTime: Date
    let endTime: Date
    let avgTemperature: Double
    let avgWindMPH: Double
    let maxPrecipChance: Double
    let score: Double

    var timeRange: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h a"
        return "\(fmt.string(from: startTime)) – \(fmt.string(from: endTime))"
    }
}

private struct CachedWeather {
    let weather: RouteWeather
    let fetchedAt: Date
}
