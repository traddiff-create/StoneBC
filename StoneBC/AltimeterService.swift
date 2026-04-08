//
//  AltimeterService.swift
//  StoneBC
//
//  CMAltimeter wrapper — barometric pressure, relative altitude, climb rate
//

import CoreMotion
import Foundation

@Observable
class AltimeterService {
    var isAvailable: Bool { CMAltimeter.isRelativeAltitudeAvailable() }
    var relativeAltitudeMeters: Double = 0
    var relativeAltitudeFeet: Double = 0
    var pressureKPa: Double = 0
    var pressureHPa: Double { pressureKPa * 10 }
    var climbRateFeetPerMin: Double = 0

    private let altimeter = CMAltimeter()
    private var lastAltitude: Double = 0
    private var lastTimestamp: Date?
    private var isRunning = false

    // Accumulated totals for the session
    var totalAscentFeet: Double = 0
    var totalDescentFeet: Double = 0

    func start() {
        guard isAvailable, !isRunning else { return }
        isRunning = true
        lastTimestamp = Date()
        lastAltitude = 0
        totalAscentFeet = 0
        totalDescentFeet = 0

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self, let data, error == nil else { return }

            let altMeters = data.relativeAltitude.doubleValue
            let altFeet = altMeters * 3.28084
            let now = Date()

            // Climb rate (smoothed over time delta)
            if let lastTime = self.lastTimestamp {
                let dt = now.timeIntervalSince(lastTime)
                if dt > 0.5 {
                    let deltaFeet = altFeet - self.relativeAltitudeFeet
                    let rate = (deltaFeet / dt) * 60 // feet per minute
                    // Exponential smoothing to reduce noise
                    self.climbRateFeetPerMin = self.climbRateFeetPerMin * 0.7 + rate * 0.3
                    self.lastTimestamp = now
                }
            }

            // Accumulate ascent/descent
            let deltaFromLast = altFeet - self.lastAltitude
            if abs(deltaFromLast) > 1.0 { // 1-foot deadband to filter noise
                if deltaFromLast > 0 {
                    self.totalAscentFeet += deltaFromLast
                } else {
                    self.totalDescentFeet += abs(deltaFromLast)
                }
                self.lastAltitude = altFeet
            }

            self.relativeAltitudeMeters = altMeters
            self.relativeAltitudeFeet = altFeet
            self.pressureKPa = data.pressure.doubleValue
        }
    }

    func stop() {
        guard isRunning else { return }
        altimeter.stopRelativeAltitudeUpdates()
        isRunning = false
    }

    var formattedPressure: String {
        String(format: "%.1f hPa", pressureHPa)
    }

    var formattedAltitudeChange: String {
        let sign = relativeAltitudeFeet >= 0 ? "+" : ""
        return String(format: "%@%.0f ft", sign, relativeAltitudeFeet)
    }

    var formattedClimbRate: String {
        let sign = climbRateFeetPerMin >= 0 ? "+" : ""
        return String(format: "%@%.0f ft/min", sign, climbRateFeetPerMin)
    }
}
