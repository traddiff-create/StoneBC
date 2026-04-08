//
//  LocationService.swift
//  StoneBC
//
//  CLLocationManager wrapper — GPS position, heading, speed, course, altitude
//

import CoreLocation

@Observable
class LocationService: NSObject, CLLocationManagerDelegate {
    var userLocation: CLLocationCoordinate2D?
    var heading: Double = 0
    var headingAccuracy: Double = -1
    var isTracking = false
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // Speed & course from GPS
    var speedMPS: Double = 0          // meters per second (raw)
    var speedMPH: Double = 0          // miles per hour
    var course: Double = -1           // direction of travel (0-360), -1 = unavailable
    var gpsAltitudeMeters: Double = 0 // GPS altitude (noisy but absolute)

    // Session stats
    var maxSpeedMPH: Double = 0
    var averageSpeedMPH: Double = 0
    private var speedSamples: [Double] = []
    private var movingSpeedSamples: [Double] = [] // only samples > 1 mph (filtering stops)

    // Full CLLocation stream for workout route recording
    var locationHistory: [CLLocation] = []

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
        manager.activityType = .fitness
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        isTracking = true
        speedSamples = []
        movingSpeedSamples = []
        maxSpeedMPH = 0
        averageSpeedMPH = 0
        locationHistory = []
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func stopTracking() {
        isTracking = false
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func resetSessionStats() {
        speedSamples = []
        movingSpeedSamples = []
        maxSpeedMPH = 0
        averageSpeedMPH = 0
        locationHistory = []
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location.coordinate
        gpsAltitudeMeters = location.altitude

        // Speed (CLLocation.speed is -1 when unavailable)
        if location.speed >= 0 {
            speedMPS = location.speed
            speedMPH = location.speed * 2.23694 // m/s to mph

            speedSamples.append(speedMPH)
            if speedMPH > 1.0 {
                movingSpeedSamples.append(speedMPH)
            }

            if speedMPH > maxSpeedMPH {
                maxSpeedMPH = speedMPH
            }

            if !movingSpeedSamples.isEmpty {
                averageSpeedMPH = movingSpeedSamples.reduce(0, +) / Double(movingSpeedSamples.count)
            }
        } else {
            speedMPS = 0
            speedMPH = 0
        }

        // Course (direction of travel)
        if location.course >= 0 {
            course = location.course
        }

        // Store for workout route recording
        locationHistory.append(location)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading
        headingAccuracy = newHeading.headingAccuracy
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            if isTracking { manager.startUpdatingLocation() }
        }
    }

    // MARK: - Formatted Values

    var formattedSpeed: String {
        String(format: "%.1f", speedMPH)
    }

    var formattedAvgSpeed: String {
        String(format: "%.1f", averageSpeedMPH)
    }

    var formattedMaxSpeed: String {
        String(format: "%.1f", maxSpeedMPH)
    }

    var cardinalDirection: String {
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5).truncatingRemainder(dividingBy: 360) / 45)
        return dirs[index]
    }
}
