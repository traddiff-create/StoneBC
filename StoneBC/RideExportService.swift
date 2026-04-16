//
//  RideExportService.swift
//  StoneBC
//
//  Export completed rides as GPX files for sharing, Strava upload,
//  or archival. Generates GPX 1.1 with trackpoints, elevation, and timestamps.
//

import Foundation
import CoreLocation

enum RideExportService {

    /// Generate GPX XML from a completed ride's location history
    static func exportGPX(
        routeName: String,
        locations: [CLLocation],
        startTime: Date
    ) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="StoneBC"
          xmlns="http://www.topografix.com/GPX/1/1"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(xmlEscape(routeName))</name>
            <time>\(dateFormatter.string(from: startTime))</time>
          </metadata>
          <trk>
            <name>\(xmlEscape(routeName))</name>
            <type>Cycling</type>
            <trkseg>
        """

        for location in locations {
            gpx += """

                  <trkpt lat="\(location.coordinate.latitude)" lon="\(location.coordinate.longitude)">
                    <ele>\(String(format: "%.1f", location.altitude))</ele>
                    <time>\(dateFormatter.string(from: location.timestamp))</time>
                  </trkpt>
            """
        }

        gpx += """

            </trkseg>
          </trk>
        </gpx>
        """

        return gpx
    }

    /// Write GPX to a temporary file and return the URL
    static func writeToTempFile(_ gpx: String, name: String) -> URL? {
        let sanitized = name.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        let dateStr = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()

        let filename = "\(sanitized)_\(dateStr).gpx"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try gpx.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    /// Generate ride summary text for sharing
    static func rideSummary(
        routeName: String,
        distanceMiles: Double,
        elapsedTime: String,
        elevationGainFeet: Double,
        avgSpeedMPH: Double,
        maxSpeedMPH: Double
    ) -> String {
        """
        🚴 Ride Complete — \(routeName)
        📏 \(String(format: "%.1f", distanceMiles)) miles
        ⏱ \(elapsedTime)
        ⬆️ \(String(format: "%.0f", elevationGainFeet)) ft gained
        🏎 Avg \(String(format: "%.1f", avgSpeedMPH)) mph / Max \(String(format: "%.1f", maxSpeedMPH)) mph

        Tracked with Stone Bicycle Coalition app
        """
    }

    // MARK: - Helpers

    private static func xmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
