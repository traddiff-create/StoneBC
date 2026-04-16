//
//  PhotoGeotaggingService.swift
//  StoneBC
//
//  Matches photos to GPS coordinates using:
//  1. EXIF GPS data (iPhone photos, some Fuji with GPS)
//  2. Timestamp matching against Garmin 810 GPX track
//  3. Manual placement (fallback)
//

import Foundation
import CoreLocation
import ImageIO

enum PhotoGeotaggingService {

    // MARK: - EXIF Extraction

    /// Extract GPS coordinate from photo EXIF data
    static func extractEXIFCoordinate(from imageURL: URL) -> CLLocationCoordinate2D? {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            return nil
        }

        guard let latitude = gps[kCGImagePropertyGPSLatitude as String] as? Double,
              let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
              let longitude = gps[kCGImagePropertyGPSLongitude as String] as? Double,
              let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String else {
            return nil
        }

        let lat = latRef == "S" ? -latitude : latitude
        let lon = lonRef == "W" ? -longitude : longitude

        guard (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Extract capture date from photo EXIF data
    static func extractEXIFDate(from imageURL: URL) -> Date? {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let dateStr = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateStr)
    }

    // MARK: - Timestamp-to-Track Matching

    /// Match a photo timestamp to the nearest point on a Garmin GPX track.
    /// Garmin 810 trackpoints: [[lat, lon, ele], ...] with timestamps in the GPX file.
    /// This method takes pre-parsed trackpoints with timestamps.
    static func geotagByTimestamp(
        photoTimestamp: Date,
        trackWithTimestamps: [(coordinate: CLLocationCoordinate2D, timestamp: Date)],
        maxDeltaSeconds: TimeInterval = 120
    ) -> CLLocationCoordinate2D? {
        var bestMatch: (coordinate: CLLocationCoordinate2D, delta: TimeInterval)?

        for point in trackWithTimestamps {
            let delta = abs(photoTimestamp.timeIntervalSince(point.timestamp))
            if delta <= maxDeltaSeconds {
                if bestMatch == nil || delta < bestMatch!.delta {
                    bestMatch = (point.coordinate, delta)
                }
            }
        }

        return bestMatch?.coordinate
    }

    /// Simpler version: match against trackpoints array with uniform time spacing.
    /// Useful when GPX timestamps aren't parsed but you know start/end times.
    static func geotagByInterpolation(
        photoTimestamp: Date,
        trackpoints: [[Double]],
        trackStartTime: Date,
        trackEndTime: Date,
        maxDeltaSeconds: TimeInterval = 120
    ) -> CLLocationCoordinate2D? {
        guard trackpoints.count >= 2 else { return nil }

        let totalDuration = trackEndTime.timeIntervalSince(trackStartTime)
        guard totalDuration > 0 else { return nil }

        let photoOffset = photoTimestamp.timeIntervalSince(trackStartTime)
        guard photoOffset >= -maxDeltaSeconds,
              photoOffset <= totalDuration + maxDeltaSeconds else { return nil }

        // Interpolate position along track
        let fraction = max(0, min(1, photoOffset / totalDuration))
        let index = Int(fraction * Double(trackpoints.count - 1))
        let safeIndex = max(0, min(trackpoints.count - 1, index))

        let pt = trackpoints[safeIndex]
        guard pt.count >= 2 else { return nil }

        return CLLocationCoordinate2D(latitude: pt[0], longitude: pt[1])
    }

    // MARK: - Batch Geotagging

    struct GeotagResult {
        let photoURL: URL
        let coordinate: CLLocationCoordinate2D?
        let source: GeotagSource
        let confidence: GeotagConfidence
    }

    enum GeotagSource {
        case exif           // GPS from photo EXIF
        case trackMatch     // Matched to Garmin track by timestamp
        case interpolated   // Interpolated along track
        case none           // Could not geotag
    }

    enum GeotagConfidence {
        case high       // EXIF GPS or exact track match (<30s)
        case medium     // Track match within 2 minutes
        case low        // Interpolated or large time gap
        case none
    }

    /// Batch geotag photos against a GPX track
    static func batchGeotag(
        photoURLs: [URL],
        trackpoints: [[Double]],
        trackStartTime: Date,
        trackEndTime: Date
    ) -> [GeotagResult] {
        photoURLs.map { url in
            // Try EXIF first
            if let coord = extractEXIFCoordinate(from: url) {
                return GeotagResult(
                    photoURL: url,
                    coordinate: coord,
                    source: .exif,
                    confidence: .high
                )
            }

            // Try timestamp matching
            if let photoDate = extractEXIFDate(from: url) {
                if let coord = geotagByInterpolation(
                    photoTimestamp: photoDate,
                    trackpoints: trackpoints,
                    trackStartTime: trackStartTime,
                    trackEndTime: trackEndTime
                ) {
                    let offset = abs(photoDate.timeIntervalSince(trackStartTime))
                    let confidence: GeotagConfidence = offset < 30 ? .high : offset < 120 ? .medium : .low
                    return GeotagResult(
                        photoURL: url,
                        coordinate: coord,
                        source: .interpolated,
                        confidence: confidence
                    )
                }
            }

            return GeotagResult(photoURL: url, coordinate: nil, source: .none, confidence: .none)
        }
    }
}
