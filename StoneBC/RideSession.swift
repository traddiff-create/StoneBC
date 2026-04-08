//
//  RideSession.swift
//  StoneBC
//
//  Active ride state — elapsed time, distance, elevation, speed
//

import Foundation
import CoreLocation

@Observable
class RideSession {
    let route: Route
    var startTime: Date?
    var isActive = false

    // Time
    var elapsedSeconds: TimeInterval = 0
    var movingSeconds: TimeInterval = 0

    // Distance
    var distanceTraveledMiles: Double = 0
    private var lastLocation: CLLocationCoordinate2D?

    // Progress
    var closestTrackpointIndex: Int = 0
    var progressPercent: Double = 0
    var distanceRemainingMiles: Double = 0

    // Off-route
    var distanceFromRouteMeters: Double = 0
    var isOffRoute: Bool { distanceFromRouteMeters > 50 }

    private var timer: Timer?

    init(route: Route) {
        self.route = route
        self.distanceRemainingMiles = route.distanceMiles
    }

    func start() {
        startTime = Date()
        isActive = true
        elapsedSeconds = 0
        movingSeconds = 0
        distanceTraveledMiles = 0
        lastLocation = nil
        closestTrackpointIndex = 0

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.isActive else { return }
            self.elapsedSeconds = Date().timeIntervalSince(self.startTime ?? Date())
        }
    }

    func stop() {
        isActive = false
        timer?.invalidate()
        timer = nil
    }

    func updateLocation(_ coordinate: CLLocationCoordinate2D, speed: Double) {
        // Accumulate distance
        if let last = lastLocation {
            let from = CLLocation(latitude: last.latitude, longitude: last.longitude)
            let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let deltaMeters = to.distance(from: from)

            // Only count movement > 3m to filter GPS jitter
            if deltaMeters > 3 {
                distanceTraveledMiles += deltaMeters / 1609.344
            }

            // Count moving time (speed > 1 mph)
            if speed > 0.447 { // ~1 mph in m/s
                movingSeconds += 1
            }
        }
        lastLocation = coordinate

        // Find closest point on route
        let userCL = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var minDist = Double.greatestFiniteMagnitude
        var minIdx = 0

        for (i, pt) in route.clTrackpoints.enumerated() {
            let ptCL = CLLocation(latitude: pt.latitude, longitude: pt.longitude)
            let d = userCL.distance(from: ptCL)
            if d < minDist {
                minDist = d
                minIdx = i
            }
        }

        closestTrackpointIndex = minIdx
        distanceFromRouteMeters = minDist

        if !route.clTrackpoints.isEmpty {
            progressPercent = Double(minIdx) / Double(max(route.clTrackpoints.count - 1, 1))
        }

        // Distance remaining from closest point to end
        let remaining = Array(route.trackpoints[minIdx...])
        distanceRemainingMiles = Route.haversineDistance(remaining)
    }

    // MARK: - Bearing to next waypoint

    func bearingToNextWaypoint(from coordinate: CLLocationCoordinate2D) -> Double? {
        // Look ahead ~10 trackpoints for a meaningful bearing target
        let lookAheadIdx = min(closestTrackpointIndex + 10, route.clTrackpoints.count - 1)
        guard lookAheadIdx > closestTrackpointIndex else { return nil }

        let target = route.clTrackpoints[lookAheadIdx]
        return bearing(from: coordinate, to: target)
    }

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)

        return (radians * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Formatted Values

    var formattedElapsedTime: String {
        let h = Int(elapsedSeconds) / 3600
        let m = (Int(elapsedSeconds) % 3600) / 60
        let s = Int(elapsedSeconds) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    var formattedMovingTime: String {
        let h = Int(movingSeconds) / 3600
        let m = (Int(movingSeconds) % 3600) / 60
        let s = Int(movingSeconds) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    var formattedDistance: String {
        String(format: "%.1f mi", distanceTraveledMiles)
    }

    var formattedRemaining: String {
        String(format: "%.1f mi", distanceRemainingMiles)
    }
}
