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
    var isAbsoluteAltitudeAvailable: Bool {
        if #available(iOS 15.0, *) {
            return CMAltimeter.isAbsoluteAltitudeAvailable()
        }
        return false
    }
    var relativeAltitudeMeters: Double = 0
    var relativeAltitudeFeet: Double = 0
    var absoluteAltitudeMeters: Double?
    var absoluteAltitudeFeet: Double? {
        absoluteAltitudeMeters.map { $0 * 3.28084 }
    }
    var absoluteAltitudeAccuracyMeters: Double?
    var absoluteAltitudePrecisionMeters: Double?
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

        if #available(iOS 15.0, *), CMAltimeter.isAbsoluteAltitudeAvailable() {
            altimeter.startAbsoluteAltitudeUpdates(to: .main) { [weak self] data, error in
                guard let self, let data, error == nil else { return }
                self.absoluteAltitudeMeters = data.altitude
                self.absoluteAltitudeAccuracyMeters = data.accuracy
                self.absoluteAltitudePrecisionMeters = data.precision
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        altimeter.stopRelativeAltitudeUpdates()
        if #available(iOS 15.0, *) {
            altimeter.stopAbsoluteAltitudeUpdates()
        }
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

    /// Drift-correction recalibration. Called whenever a fresh GPS sample
    /// arrives with vertical accuracy tighter than
    /// `RideTuning.recalibrationVerticalAccuracyMeters`. Blends a small
    /// fraction of the GPS-vs-fused delta into the baseline so the fused
    /// altitude tracks reality over long climbs without step-changes.
    func recalibrateIfPossible(gpsAltitudeMeters: Double, verticalAccuracy: Double) {
        guard verticalAccuracy >= 0,
              verticalAccuracy < RideTuning.recalibrationVerticalAccuracyMeters,
              let baseline = gpsBaseline else { return }

        let fused = baseline + relativeAltitudeMeters
        let delta = gpsAltitudeMeters - fused
        gpsBaseline = baseline + delta * RideTuning.recalibrationBlendFactor
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

    var bestAltitudeMeters: Double? {
        if gpsBaseline != nil {
            return fusedAltitudeMeters
        }
        if let absoluteAltitudeMeters {
            return absoluteAltitudeMeters
        }
        return nil
    }

    var bestAltitudeFeet: Double? {
        bestAltitudeMeters.map { $0 * 3.28084 }
    }

    var altitudeSourceLabel: String {
        if gpsBaseline != nil {
            return "GPS+BARO"
        }
        if absoluteAltitudeMeters != nil {
            return "ABS"
        }
        return "WAITING"
    }

    var formattedFusedAltitude: String {
        let ft = Int(fusedAltitudeFeet)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: ft)) ?? "\(ft)") + " ft"
    }

    var formattedBestAltitude: String {
        guard let feet = bestAltitudeFeet else { return "-- ft" }
        let ft = Int(feet)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: ft)) ?? "\(ft)") + " ft"
    }

    var formattedAbsoluteAccuracy: String {
        guard let accuracy = absoluteAltitudeAccuracyMeters else { return "--" }
        return String(format: "%.0f m", accuracy)
    }

    var formattedAbsolutePrecision: String {
        guard let precision = absoluteAltitudePrecisionMeters else { return "--" }
        return String(format: "%.0f m", precision)
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
