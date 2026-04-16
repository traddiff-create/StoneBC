//
//  RouteAnalysisService.swift
//  StoneBC
//
//  Pre-computes turn points, segment bearings, and difficulty segments
//  from route trackpoints. Enables O(1) turn lookups during navigation.
//

import CoreLocation

struct TurnPoint: Identifiable {
    let id = UUID()
    let trackpointIndex: Int
    let coordinate: CLLocationCoordinate2D
    let direction: TurnDirection
    let angleDegrees: Double
    let distanceFromStartMiles: Double
}

struct RouteSegment {
    let startIndex: Int
    let endIndex: Int
    let bearing: Double        // compass bearing of this segment
    let distanceMeters: Double
    let elevationChangeFeet: Double
    let gradientPercent: Double
}

enum RouteAnalysisService {

    // MARK: - Turn Analysis

    /// Pre-compute all turn points for a route.
    /// Returns turns sorted by trackpoint index for efficient lookup.
    static func analyzeTurns(
        for route: Route,
        lookAhead: Int = 20,
        minAngle: Double = 15
    ) -> [TurnPoint] {
        let trackpoints = route.clTrackpoints
        guard trackpoints.count >= lookAhead * 2 else { return [] }

        var turns: [TurnPoint] = []
        var cumulativeDistance: Double = 0
        var lastTurnIndex = -lookAhead // prevent overlapping detections

        for i in stride(from: 0, to: trackpoints.count - lookAhead, by: lookAhead / 2) {
            let mid = min(i + lookAhead / 2, trackpoints.count - 1)
            let end = min(i + lookAhead, trackpoints.count - 1)

            guard end > mid, mid > i else { continue }

            let bearing1 = bearing(from: trackpoints[i], to: trackpoints[mid])
            let bearing2 = bearing(from: trackpoints[mid], to: trackpoints[end])

            var angleDiff = bearing2 - bearing1
            if angleDiff > 180 { angleDiff -= 360 }
            if angleDiff < -180 { angleDiff += 360 }

            let direction = TurnDirection.from(angle: angleDiff)
            guard direction != .straight else { continue }
            guard mid - lastTurnIndex >= lookAhead / 2 else { continue }

            // Compute distance from start
            if turns.isEmpty {
                for j in 1...mid {
                    let from = CLLocation(latitude: trackpoints[j-1].latitude, longitude: trackpoints[j-1].longitude)
                    let to = CLLocation(latitude: trackpoints[j].latitude, longitude: trackpoints[j].longitude)
                    cumulativeDistance += to.distance(from: from)
                }
            } else if let lastIdx = turns.last?.trackpointIndex {
                for j in (lastIdx + 1)...mid {
                    let from = CLLocation(latitude: trackpoints[j-1].latitude, longitude: trackpoints[j-1].longitude)
                    let to = CLLocation(latitude: trackpoints[j].latitude, longitude: trackpoints[j].longitude)
                    cumulativeDistance += to.distance(from: from)
                }
            }

            turns.append(TurnPoint(
                trackpointIndex: mid,
                coordinate: trackpoints[mid],
                direction: direction,
                angleDegrees: angleDiff,
                distanceFromStartMiles: cumulativeDistance / 1609.344
            ))

            lastTurnIndex = mid
        }

        return turns
    }

    /// Find the next upcoming turn given current position on the route.
    /// Returns nil if no more turns ahead.
    static func nextTurn(
        from currentIndex: Int,
        in turns: [TurnPoint]
    ) -> TurnPoint? {
        turns.first { $0.trackpointIndex > currentIndex }
    }

    /// Distance in meters from current trackpoint index to a turn point
    static func distanceToTurn(
        from currentIndex: Int,
        to turn: TurnPoint,
        trackpoints: [CLLocationCoordinate2D]
    ) -> Double {
        guard currentIndex < turn.trackpointIndex,
              turn.trackpointIndex < trackpoints.count else { return 0 }

        var distance: Double = 0
        for i in currentIndex..<turn.trackpointIndex {
            let from = CLLocation(latitude: trackpoints[i].latitude, longitude: trackpoints[i].longitude)
            let to = CLLocation(latitude: trackpoints[i+1].latitude, longitude: trackpoints[i+1].longitude)
            distance += to.distance(from: from)
        }
        return distance
    }

    // MARK: - Segment Analysis

    /// Break a route into segments with bearing, gradient, and distance
    static func analyzeSegments(
        for route: Route,
        segmentLength: Int = 20
    ) -> [RouteSegment] {
        let trackpoints = route.clTrackpoints
        let elevations = route.elevations
        guard trackpoints.count >= segmentLength else { return [] }

        var segments: [RouteSegment] = []

        for i in stride(from: 0, to: trackpoints.count - 1, by: segmentLength) {
            let endIdx = min(i + segmentLength, trackpoints.count - 1)
            guard endIdx > i else { continue }

            let segBearing = bearing(from: trackpoints[i], to: trackpoints[endIdx])

            var segDistance: Double = 0
            for j in i..<endIdx {
                let from = CLLocation(latitude: trackpoints[j].latitude, longitude: trackpoints[j].longitude)
                let to = CLLocation(latitude: trackpoints[j+1].latitude, longitude: trackpoints[j+1].longitude)
                segDistance += to.distance(from: from)
            }

            var elevChange: Double = 0
            if i < elevations.count && endIdx < elevations.count {
                elevChange = (elevations[endIdx] - elevations[i]) * 3.28084 // meters to feet
            }

            let gradient = segDistance > 0 ? (elevChange / 3.28084) / segDistance * 100 : 0

            segments.append(RouteSegment(
                startIndex: i,
                endIndex: endIdx,
                bearing: segBearing,
                distanceMeters: segDistance,
                elevationChangeFeet: elevChange,
                gradientPercent: gradient
            ))
        }

        return segments
    }

    // MARK: - Helpers

    private static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}
