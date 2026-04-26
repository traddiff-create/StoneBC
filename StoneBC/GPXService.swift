//
//  GPXService.swift
//  StoneBC
//
//  GPX 1.1 export and import — generates valid XML from Route trackpoints,
//  parses GPX files into Route structs
//

import Foundation

enum GPXService {

    // MARK: - Export

    static func exportGPX(_ route: Route) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="StoneBC"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(escapeXML(route.name))</name>
            <desc>\(escapeXML(route.description))</desc>
            <time>\(iso8601Now())</time>
          </metadata>

        """

        for cue in route.cuePoints {
            xml += """
          <wpt lat="\(cue.coordinate.latitude)" lon="\(cue.coordinate.longitude)">
            <name>\(escapeXML(cue.name))</name>

        """
            if let description = cue.description, !description.isEmpty {
                xml += "    <desc>\(escapeXML(description))</desc>\n"
            }
            xml += "  </wpt>\n"
        }

        xml += """
          <trk>
            <name>\(escapeXML(route.name))</name>
            <trkseg>

        """

        for point in route.trackpoints {
            guard point.count >= 2 else { continue }
            let lat = point[0]
            let lon = point[1]
            if point.count >= 3 {
                xml += "      <trkpt lat=\"\(lat)\" lon=\"\(lon)\"><ele>\(point[2])</ele></trkpt>\n"
            } else {
                xml += "      <trkpt lat=\"\(lat)\" lon=\"\(lon)\"/>\n"
            }
        }

        xml += """
            </trkseg>
          </trk>
        </gpx>
        """

        return xml
    }

    static func writeToTempFile(_ gpxString: String, name: String) -> URL? {
        let sanitized = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(sanitized)
            .appendingPathExtension("gpx")
        do {
            try gpxString.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Import

    static func parseGPX(data: Data) throws -> GPXResult {
        let delegate = GPXParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw GPXError.invalidXML
        }
        guard delegate.trackpoints.count >= 2 else {
            throw GPXError.insufficientTrackpoints
        }
        return GPXResult(
            name: delegate.routeName,
            description: delegate.routeDescription,
            trackpoints: delegate.trackpoints,
            cuePoints: delegate.cuePoints
        )
    }

    // MARK: - Helpers

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func iso8601Now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - GPX Parse Result

struct GPXResult {
    let name: String?
    let description: String?
    let trackpoints: [[Double]] // [[lat, lon, ele], ...]
    let cuePoints: [Route.CuePoint]
}

// MARK: - GPX Errors

enum GPXError: LocalizedError {
    case invalidXML
    case insufficientTrackpoints

    var errorDescription: String? {
        switch self {
        case .invalidXML: return "The file is not valid GPX."
        case .insufficientTrackpoints: return "The file contains fewer than 2 trackpoints."
        }
    }
}

// MARK: - XMLParser Delegate

private class GPXParserDelegate: NSObject, XMLParserDelegate {
    var trackpoints: [[Double]] = []
    var cuePoints: [Route.CuePoint] = []
    var routeName: String?
    var routeDescription: String?

    private var currentElement = ""
    private var currentText = ""
    private var currentLat: Double?
    private var currentLon: Double?
    private var currentEle: Double?
    private var currentWaypointName: String?
    private var currentWaypointDescription: String?
    private var currentPointKind: PointKind?
    private var inTrack = false
    private var inMetadata = false

    private enum PointKind {
        case track
        case waypoint
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""

        switch elementName {
        case "trk", "rte":
            inTrack = true
        case "metadata":
            inMetadata = true
        case "trkpt", "rtept":
            if let latStr = attributes["lat"], let lonStr = attributes["lon"],
               let lat = Double(latStr), let lon = Double(lonStr) {
                currentLat = lat
                currentLon = lon
                currentEle = nil
                currentPointKind = .track
            }
        case "wpt":
            if let latStr = attributes["lat"], let lonStr = attributes["lon"],
               let lat = Double(latStr), let lon = Double(lonStr) {
                currentLat = lat
                currentLon = lon
                currentEle = nil
                currentWaypointName = nil
                currentWaypointDescription = nil
                currentPointKind = .waypoint
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "ele":
            currentEle = Double(text)
        case "name":
            if currentPointKind == .waypoint {
                currentWaypointName = text
            } else if inMetadata && routeName == nil {
                routeName = text
            } else if inTrack && currentPointKind == nil && routeName == nil {
                routeName = text
            }
        case "desc":
            if currentPointKind == .waypoint {
                currentWaypointDescription = text
            } else if inMetadata && routeDescription == nil {
                routeDescription = text
            }
        case "trkpt", "rtept":
            if let lat = currentLat, let lon = currentLon {
                if let ele = currentEle {
                    trackpoints.append([lat, lon, ele])
                } else {
                    trackpoints.append([lat, lon])
                }
            }
            currentLat = nil
            currentLon = nil
            currentEle = nil
            currentPointKind = nil
        case "wpt":
            if let lat = currentLat, let lon = currentLon {
                let name = currentWaypointName.flatMap { $0.isEmpty ? nil : $0 } ?? "Cue"
                cuePoints.append(Route.CuePoint(
                    name: name,
                    description: currentWaypointDescription,
                    coordinate: Route.Coordinate(latitude: lat, longitude: lon)
                ))
            }
            currentLat = nil
            currentLon = nil
            currentEle = nil
            currentWaypointName = nil
            currentWaypointDescription = nil
            currentPointKind = nil
        case "metadata":
            inMetadata = false
        case "trk", "rte":
            inTrack = false
        default:
            break
        }
    }
}
