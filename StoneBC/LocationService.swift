//
//  LocationService.swift
//  StoneBC
//
//  CLLocationManager wrapper — GPS position, heading, speed, course, altitude
//

import CoreLocation
import UIKit

@Observable
class LocationService: NSObject, CLLocationManagerDelegate {
    enum TrackingMode {
        case foreground
        case ride
        case expeditionHighDetail
        case expeditionBalanced
        case expeditionBatterySaver
        case expeditionCheckIn

        var desiredAccuracy: CLLocationAccuracy {
            switch self {
            case .foreground, .ride, .expeditionHighDetail:
                kCLLocationAccuracyBest
            case .expeditionBalanced:
                kCLLocationAccuracyNearestTenMeters
            case .expeditionBatterySaver:
                kCLLocationAccuracyHundredMeters
            case .expeditionCheckIn:
                kCLLocationAccuracyKilometer
            }
        }

        var distanceFilter: CLLocationDistance {
            switch self {
            case .foreground: 10
            case .ride: 8
            case .expeditionHighDetail: 10
            case .expeditionBalanced: 25
            case .expeditionBatterySaver: 100
            case .expeditionCheckIn: 500
            }
        }

        var maximumHorizontalAccuracy: CLLocationAccuracy {
            switch self {
            case .foreground: 150
            case .ride: 100
            case .expeditionHighDetail: 100
            case .expeditionBalanced: 150
            case .expeditionBatterySaver: 300
            case .expeditionCheckIn: 1000
            }
        }

        var allowsBackgroundUpdates: Bool {
            switch self {
            case .ride, .expeditionHighDetail, .expeditionBalanced, .expeditionBatterySaver:
                true
            case .foreground, .expeditionCheckIn:
                false
            }
        }

        var usesAutomaticLocationPausing: Bool {
            switch self {
            case .ride, .expeditionBalanced, .expeditionBatterySaver:
                true
            case .foreground, .expeditionHighDetail, .expeditionCheckIn:
                false
            }
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
    var requestedPowerMode: RidePowerMode = .balanced
    var effectivePowerMode: RidePowerMode = .balanced
    var horizontalAccuracyMeters: Double = -1
    var verticalAccuracyMeters: Double = -1
    var lastLocationTimestamp: Date?
    var isReducedAccuracy = false
    var locationIssueDescription: String?
    var liveUpdateDiagnostics: Set<LocationDiagnostic> = []

    enum LocationDiagnostic: String, Hashable {
        case denied
        case deniedGlobally
        case restricted
        case requestInProgress
        case reducedAccuracy
        case serviceSessionRequired
        case insufficientlyInUse
        case unavailable
        case stationary

        var message: String {
            switch self {
            case .denied: "Location permission is denied"
            case .deniedGlobally: "Location Services are off"
            case .restricted: "Location is restricted on this device"
            case .requestInProgress: "Waiting for location permission"
            case .reducedAccuracy: "Precise Location is off"
            case .serviceSessionRequired: "Location service session is required"
            case .insufficientlyInUse: "Open StoneBC to continue active ride tracking"
            case .unavailable: "Location is temporarily unavailable"
            case .stationary: "GPS paused while stationary"
            }
        }
    }

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
    private var movingSpeedSum: Double = 0
    private var movingSpeedCount: Int = 0

    // Full CLLocation stream for workout route recording
    var locationHistory: [CLLocation] = []

    // Altitude fusion callback — set by RouteNavigationView to feed GPS altitude to AltimeterService
    var onFirstAltitude: ((Double) -> Void)?
    private var hasCalibrated = false
    private var pendingStartMode: TrackingMode?
    private var isInterfaceActive = true
    private var isRideStationary = false
    private var wantsHeadingUpdates = false
    private var precisionBoostUntil: Date?
    private var precisionBoostResetTask: Task<Void, Never>?
    private var serviceSession: AnyObject?
    private var backgroundActivitySession: CLBackgroundActivitySession?
    private var liveLocationTask: Task<Void, Never>?
    private var isUsingLiveLocationUpdates = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        configureManager(for: .foreground)
        authorizationStatus = manager.authorizationStatus
        isReducedAccuracy = manager.accuracyAuthorization == .reducedAccuracy
        installLifecycleObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        precisionBoostResetTask?.cancel()
    }

    func requestPermission() {
        guard authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    func startTracking(mode: TrackingMode = .foreground,
                       powerMode: RidePowerMode = .balanced,
                       wantsHeadingUpdates: Bool? = nil,
                       resetSessionStats: Bool = true) {
        guard CLLocationManager.locationServicesEnabled() else { return }
        trackingMode = mode
        requestedPowerMode = powerMode
        effectivePowerMode = effectiveMode(for: powerMode)
        self.wantsHeadingUpdates = wantsHeadingUpdates ?? powerMode.usesHeadingUpdates
        pendingStartMode = mode
        isRideStationary = false
        liveLocationTask?.cancel()
        liveLocationTask = nil
        isUsingLiveLocationUpdates = false
        precisionBoostUntil = mode == .ride ? Date().addingTimeInterval(RideTuning.precisionBoostSeconds) : nil
        configureManager(for: mode)
        locationIssueDescription = nil
        liveUpdateDiagnostics = []
        if resetSessionStats {
            self.resetSessionStats()
        }

        guard isAuthorized else {
            requestPermission()
            return
        }

        beginUpdates()
    }

    func stopTracking() {
        isTracking = false
        pendingStartMode = nil
        precisionBoostResetTask?.cancel()
        liveLocationTask?.cancel()
        liveLocationTask = nil
        isUsingLiveLocationUpdates = false
        precisionBoostUntil = nil
        invalidateServiceSession()
        backgroundActivitySession?.invalidate()
        backgroundActivitySession = nil
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
    }

    func resetSessionStats() {
        speedSamples = []
        movingSpeedSamples = []
        movingSpeedSum = 0
        movingSpeedCount = 0
        maxSpeedMPH = 0
        averageSpeedMPH = 0
        locationHistory = []
        locationUpdateCount = 0
        lastLocation = nil
        lastLocationTimestamp = nil
        hasCalibrated = false
        locationIssueDescription = nil
        liveUpdateDiagnostics = []
    }

    func setInterfaceActive(_ isActive: Bool) {
        guard isInterfaceActive != isActive else { return }
        isInterfaceActive = isActive
        configureManager(for: trackingMode)
    }

    func setRideStationary(_ isStationary: Bool) {
        guard isRideStationary != isStationary else { return }
        isRideStationary = isStationary
        configureManager(for: trackingMode)
    }

    func requestTemporaryPrecisionBoost(duration: TimeInterval = RideTuning.precisionBoostSeconds) {
        guard trackingMode == .ride else { return }
        precisionBoostUntil = Date().addingTimeInterval(duration)
        configureManager(for: trackingMode)

        precisionBoostResetTask?.cancel()
        precisionBoostResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard let service = self else { return }
            await MainActor.run {
                service.expirePrecisionBoostIfNeeded()
            }
        }
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
        isReducedAccuracy = manager.accuracyAuthorization == .reducedAccuracy

        if isAuthorized, let mode = pendingStartMode {
            configureManager(for: mode)
            beginUpdates()
        } else if !isAuthorized {
            locationIssueDescription = "Location permission is denied"
            stopTracking()
        }
    }

    // MARK: - Private

    private var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    private func configureManager(for mode: TrackingMode) {
        effectivePowerMode = effectiveMode(for: requestedPowerMode)

        if mode == .ride {
            let profile = rideLocationProfile(for: effectivePowerMode)
            manager.desiredAccuracy = profile.accuracy
            manager.distanceFilter = profile.distanceFilter
            manager.pausesLocationUpdatesAutomatically = effectivePowerMode.usesAutomaticLocationPausing
        } else {
            manager.desiredAccuracy = mode.desiredAccuracy
            manager.distanceFilter = mode.distanceFilter
            manager.pausesLocationUpdatesAutomatically = mode.usesAutomaticLocationPausing
        }

        manager.activityType = .fitness
        manager.allowsBackgroundLocationUpdates = mode.allowsBackgroundUpdates
        manager.showsBackgroundLocationIndicator = mode.allowsBackgroundUpdates
        updateHeadingUpdates()

    }

    private func beginUpdates() {
        guard CLLocationManager.locationServicesEnabled() else { return }
        isTracking = true
        startServiceSessionIfNeeded()
        startBackgroundActivitySessionIfNeeded()
        if startLiveLocationUpdatesIfAvailable() {
            updateHeadingUpdates()
            return
        }
        manager.startUpdatingLocation()
        updateHeadingUpdates()
    }

    private func isUsable(_ location: CLLocation) -> Bool {
        let maxAccuracy = maximumHorizontalAccuracy
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= maxAccuracy else {
            return false
        }

        guard location.timestamp <= Date().addingTimeInterval(5) else { return false }
        if lastLocation == nil {
            return abs(location.timestamp.timeIntervalSinceNow) < 60
        }
        return true
    }

    private func process(_ location: CLLocation) {
        if ProcessInfo.processInfo.isLowPowerModeEnabled, effectivePowerMode != .endurance {
            effectivePowerMode = .endurance
            configureManager(for: trackingMode)
        }

        userLocation = location.coordinate
        lastLocation = location
        locationIssueDescription = nil
        liveUpdateDiagnostics.remove(.unavailable)
        liveUpdateDiagnostics.remove(.stationary)
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
        trimLongRunningSamples()
        if speedMPH > 1.0 {
            movingSpeedSamples.append(speedMPH)
            movingSpeedSum += speedMPH
            movingSpeedCount += 1
        }

        if speedMPH > maxSpeedMPH {
            maxSpeedMPH = speedMPH
        }

        if movingSpeedCount > 0 {
            averageSpeedMPH = movingSpeedSum / Double(movingSpeedCount)
        }

        // Course (direction of travel)
        if location.course >= 0 {
            course = normalizedDegrees(location.course)
        } else if speedMPS > 1.0, let previous = locationHistory.last {
            course = bearing(from: previous.coordinate, to: location.coordinate)
        }

        // Store for workout route recording
        locationHistory.append(location)
        if locationHistory.count > RideTuning.maxInMemoryTrackpoints {
            locationHistory.removeFirst(locationHistory.count - RideTuning.maxInMemoryTrackpoints)
        }

        if trackingMode == .ride,
           location.horizontalAccuracy > RideTuning.precisionBoostAccuracyTriggerMeters {
            requestTemporaryPrecisionBoost()
        }
    }

    private func installLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePowerStateChanged),
            name: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    @objc private func handleDidBecomeActive() {
        setInterfaceActive(true)
    }

    @objc private func handleWillResignActive() {
        setInterfaceActive(false)
    }

    @objc private func handleDidEnterBackground() {
        setInterfaceActive(false)
    }

    @objc private func handlePowerStateChanged() {
        configureManager(for: trackingMode)
    }

    private func effectiveMode(for requested: RidePowerMode) -> RidePowerMode {
        ProcessInfo.processInfo.isLowPowerModeEnabled ? .endurance : requested
    }

    private func rideLocationProfile(for mode: RidePowerMode) -> (accuracy: CLLocationAccuracy, distanceFilter: CLLocationDistance) {
        if hasActivePrecisionBoost {
            return (kCLLocationAccuracyBest, 8)
        }
        if isRideStationary {
            return (mode.stationaryAccuracy, mode.stationaryDistanceFilter)
        }
        if !isInterfaceActive {
            return (mode.backgroundAccuracy, mode.backgroundDistanceFilter)
        }
        return (mode.foregroundAccuracy, mode.foregroundDistanceFilter)
    }

    private var hasActivePrecisionBoost: Bool {
        guard let precisionBoostUntil else { return false }
        return precisionBoostUntil > Date()
    }

    private var maximumHorizontalAccuracy: CLLocationAccuracy {
        if isReducedAccuracy {
            return max(trackingMode.maximumHorizontalAccuracy, 1000)
        }
        if trackingMode == .ride {
            return hasActivePrecisionBoost ? 100 : effectivePowerMode.maximumHorizontalAccuracy
        }
        return trackingMode.maximumHorizontalAccuracy
    }

    private func updateHeadingUpdates() {
        let shouldRunHeading = isTracking
            && isInterfaceActive
            && wantsHeadingUpdates
            && CLLocationManager.headingAvailable()

        if shouldRunHeading {
            manager.startUpdatingHeading()
        } else {
            manager.stopUpdatingHeading()
        }
    }

    private func startBackgroundActivitySessionIfNeeded() {
        guard trackingMode == .ride,
              backgroundActivitySession == nil else {
            return
        }
        backgroundActivitySession = CLBackgroundActivitySession()
    }

    private func startServiceSessionIfNeeded() {
        guard trackingMode == .ride, serviceSession == nil else { return }
        if #available(iOS 18.0, *) {
            serviceSession = CLServiceSession(authorization: .whenInUse) as AnyObject
        }
    }

    private func invalidateServiceSession() {
        if #available(iOS 18.0, *), let session = serviceSession as? CLServiceSession {
            session.invalidate()
        }
        serviceSession = nil
    }

    private func startLiveLocationUpdatesIfAvailable() -> Bool {
        guard trackingMode == .ride,
              effectivePowerMode.prefersLiveLocationUpdates,
              liveLocationTask == nil else {
            return false
        }

        if #available(iOS 17.0, *) {
            isUsingLiveLocationUpdates = true
            manager.stopUpdatingLocation()
            liveLocationTask = Task { [weak self] in
                do {
                    for try await update in CLLocationUpdate.liveUpdates(.fitness) {
                        guard !Task.isCancelled else { continue }
                        await MainActor.run { [weak self] in
                            self?.process(update)
                        }
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run { [weak self] in
                        self?.fallBackToStandardLocationUpdates()
                    }
                }
            }
            return true
        }

        return false
    }

    @available(iOS 17.0, *)
    private func process(_ update: CLLocationUpdate) {
        isReducedAccuracy = manager.accuracyAuthorization == .reducedAccuracy
        if #available(iOS 18.0, *) {
            var diagnostics: Set<LocationDiagnostic> = []
            if update.authorizationDenied { diagnostics.insert(.denied) }
            if update.authorizationDeniedGlobally { diagnostics.insert(.deniedGlobally) }
            if update.authorizationRestricted { diagnostics.insert(.restricted) }
            if update.authorizationRequestInProgress { diagnostics.insert(.requestInProgress) }
            if update.accuracyLimited { diagnostics.insert(.reducedAccuracy) }
            if update.serviceSessionRequired { diagnostics.insert(.serviceSessionRequired) }
            if update.insufficientlyInUse { diagnostics.insert(.insufficientlyInUse) }
            if update.locationUnavailable { diagnostics.insert(.unavailable) }
            if update.stationary { diagnostics.insert(.stationary) }
            liveUpdateDiagnostics = diagnostics
            locationIssueDescription = diagnostics.first?.message
            isReducedAccuracy = isReducedAccuracy || update.accuracyLimited
        }

        guard let location = update.location, isUsable(location) else { return }
        process(location)
    }

    private func fallBackToStandardLocationUpdates() {
        liveLocationTask?.cancel()
        liveLocationTask = nil
        isUsingLiveLocationUpdates = false
        guard isTracking else { return }
        manager.startUpdatingLocation()
        updateHeadingUpdates()
    }

    private func expirePrecisionBoostIfNeeded() {
        guard !hasActivePrecisionBoost else { return }
        precisionBoostUntil = nil
        configureManager(for: trackingMode)
    }

    private func trimLongRunningSamples() {
        let maxSamples = RideTuning.maxInMemoryTrackpoints
        if speedSamples.count > maxSamples {
            speedSamples.removeFirst(speedSamples.count - maxSamples)
        }
        if movingSpeedSamples.count > maxSamples {
            movingSpeedSamples.removeFirst(movingSpeedSamples.count - maxSamples)
        }
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
