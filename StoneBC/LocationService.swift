//
//  LocationService.swift
//  StoneBC
//
//  CLLocationManager wrapper — GPS position, heading, speed, course, altitude
//

import CoreLocation

@Observable
class LocationService: NSObject, CLLocationManagerDelegate {
    enum TrackingMode {
        case foreground
        case ride

        var desiredAccuracy: CLLocationAccuracy {
            switch self {
            case .foreground: kCLLocationAccuracyBest
            case .ride: kCLLocationAccuracyBestForNavigation
            }
        }

        var distanceFilter: CLLocationDistance {
            switch self {
            case .foreground: 10
            case .ride: 3
            }
        }

        var maximumHorizontalAccuracy: CLLocationAccuracy {
            switch self {
            case .foreground: 150
            case .ride: 75
            }
        }

        var allowsBackgroundUpdates: Bool {
            self == .ride
        }
    }

    var userLocation: CLLocationCoordinate2D?
    var lastLocation: CLLocation?
    var locationUpdateCount = 0
    var heading: Double = 0
    var headingAccuracy: Double = -1
    var isTracking = false
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var trackingMode: TrackingMode = .foreground
    var horizontalAccuracyMeters: Double = -1
    var verticalAccuracyMeters: Double = -1
    var lastLocationTimestamp: Date?

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

    // Altitude fusion callback — set by RouteNavigationView to feed GPS altitude to AltimeterService
    var onFirstAltitude: ((Double) -> Void)?
    private var hasCalibrated = false
    private var pendingStartMode: TrackingMode?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        configureManager(for: .foreground)
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func startTracking(mode: TrackingMode = .foreground) {
        guard CLLocationManager.locationServicesEnabled() else { return }
        trackingMode = mode
        pendingStartMode = mode
        configureManager(for: mode)
        speedSamples = []
        movingSpeedSamples = []
        maxSpeedMPH = 0
        averageSpeedMPH = 0
        locationHistory = []
        locationUpdateCount = 0
        lastLocation = nil
        lastLocationTimestamp = nil
        hasCalibrated = false

        guard isAuthorized else {
            requestPermission()
            return
        }

        beginUpdates()
    }

    func stopTracking() {
        isTracking = false
        pendingStartMode = nil
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
    }

    func resetSessionStats() {
        speedSamples = []
        movingSpeedSamples = []
        maxSpeedMPH = 0
        averageSpeedMPH = 0
        locationHistory = []
        locationUpdateCount = 0
        lastLocation = nil
        lastLocationTimestamp = nil
        hasCalibrated = false
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations where isUsable(location) {
            process(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let candidate = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        guard candidate >= 0 else { return }
        heading = normalizedDegrees(candidate)
        headingAccuracy = newHeading.headingAccuracy
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        if isAuthorized, let mode = pendingStartMode {
            configureManager(for: mode)
            beginUpdates()
        } else if !isAuthorized {
            stopTracking()
        }
    }

    // MARK: - Private

    private var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    private func configureManager(for mode: TrackingMode) {
        manager.desiredAccuracy = mode.desiredAccuracy
        manager.distanceFilter = mode.distanceFilter
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = mode.allowsBackgroundUpdates
        manager.showsBackgroundLocationIndicator = mode.allowsBackgroundUpdates
    }

    private func beginUpdates() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        isTracking = true
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    private func isUsable(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= trackingMode.maximumHorizontalAccuracy else {
            return false
        }

        guard location.timestamp <= Date().addingTimeInterval(5) else { return false }
        if lastLocation == nil {
            return abs(location.timestamp.timeIntervalSinceNow) < 60
        }
        return true
    }

    private func process(_ location: CLLocation) {
        userLocation = location.coordinate
        lastLocation = location
        locationUpdateCount += 1
        horizontalAccuracyMeters = location.horizontalAccuracy
        verticalAccuracyMeters = location.verticalAccuracy
        lastLocationTimestamp = location.timestamp
        gpsAltitudeMeters = location.altitude

        // Calibrate altitude fusion on first accurate reading
        if !hasCalibrated && location.verticalAccuracy >= 0 && location.verticalAccuracy < 30 {
            hasCalibrated = true
            onFirstAltitude?(location.altitude)
        }

        let measuredSpeedMPS = measuredSpeed(for: location)
        speedMPS = measuredSpeedMPS
        speedMPH = measuredSpeedMPS * 2.23694

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

        // Course (direction of travel)
        if location.course >= 0 {
            course = normalizedDegrees(location.course)
        } else if speedMPS > 1.0, let previous = locationHistory.last {
            course = bearing(from: previous.coordinate, to: location.coordinate)
        }

        // Store for workout route recording
        locationHistory.append(location)
    }

    private func measuredSpeed(for location: CLLocation) -> Double {
        if location.speed >= 0 {
            return location.speed
        }

        guard let previous = locationHistory.last else { return 0 }
        let elapsed = location.timestamp.timeIntervalSince(previous.timestamp)
        guard elapsed > 0.5 else { return 0 }
        return location.distance(from: previous) / elapsed
    }

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return normalizedDegrees(atan2(y, x) * 180 / .pi)
    }

    private func normalizedDegrees(_ value: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: 360)
        return result >= 0 ? result : result + 360
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

    var navigationHeading: Double {
        if course >= 0, speedMPH > 3 {
            return course
        }
        return heading
    }

    var cardinalDirection: String {
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5).truncatingRemainder(dividingBy: 360) / 45)
        return dirs[index]
    }
}
