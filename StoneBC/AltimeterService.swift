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

    // MARK: - Altitude Fusion (GPS baseline + barometer deltas)

    private var gpsBaseline: Double?       // first GPS altitude reading (meters)
    private var baroBaselineOffset: Double? // difference between GPS baseline and baro at calibration

    /// Call once with the first GPS altitude to calibrate the fused altitude
    func calibrateWithGPS(altitudeMeters: Double) {
        if gpsBaseline == nil {
            gpsBaseline = altitudeMeters
            baroBaselineOffset = altitudeMeters // baro starts at 0 relative
        }
    }

    /// Fused altitude: GPS baseline + barometer relative changes (meters)
    var fusedAltitudeMeters: Double {
        guard let baseline = gpsBaseline else { return 0 }
        return baseline + relativeAltitudeMeters
    }

    /// Fused altitude in feet
    var fusedAltitudeFeet: Double {
        fusedAltitudeMeters * 3.28084
    }

    var formattedFusedAltitude: String {
        let ft = Int(fusedAltitudeFeet)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: ft)) ?? "\(ft)") + " ft"
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
