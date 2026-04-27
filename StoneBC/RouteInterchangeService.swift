//
//  RouteInterchangeService.swift
//  StoneBC
//

import Compression
import CoreLocation
import Foundation

enum RouteFileFormat: String, Codable, CaseIterable, Identifiable {
    case gpx
    case tcx
    case fit
    case kml
    case kmz
    case zip
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gpx: "GPX"
        case .tcx: "TCX"
        case .fit: "FIT"
        case .kml: "KML"
        case .kmz: "KMZ"
        case .zip: "ZIP"
        case .unknown: "Unknown"
        }
    }

    var preferredExtension: String {
        switch self {
        case .gpx: "gpx"
        case .tcx: "tcx"
        case .fit: "fit"
        case .kml: "kml"
        case .kmz: "kmz"
        case .zip: "zip"
        case .unknown: "dat"
        }
    }
}

enum RouteAssetKind: String, Codable {
    case plannedRoute
    case completedRide

    var displayName: String {
        switch self {
        case .plannedRoute: "Route"
        case .completedRide: "Ride"
        }
    }
}

enum RouteCoursePointKind: String, Codable {
    case generic
    case left
    case right
    case straight
    case summit
    case valley
    case water
    case food
    case danger
    case firstAid
    case start
    case finish
}

struct RouteTrackPoint: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    let elevationMeters: Double?
    let timestamp: Date?
    let distanceMeters: Double?
    let speedMetersPerSecond: Double?
    let heartRate: Double?
    let cadence: Double?
    let powerWatts: Double?

    init(latitude: Double, longitude: Double, elevationMeters: Double? = nil,
         timestamp: Date? = nil, distanceMeters: Double? = nil,
         speedMetersPerSecond: Double? = nil, heartRate: Double? = nil,
         cadence: Double? = nil, powerWatts: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevationMeters = elevationMeters
        self.timestamp = timestamp
        self.distanceMeters = distanceMeters
        self.speedMetersPerSecond = speedMetersPerSecond
        self.heartRate = heartRate
        self.cadence = cadence
        self.powerWatts = powerWatts
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var routeArray: [Double] {
        [latitude, longitude, elevationMeters ?? 0]
    }
}

struct RouteCoursePoint: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let kind: RouteCoursePointKind
    let latitude: Double
    let longitude: Double
    let distanceMeters: Double?
    let generated: Bool

    init(id: String = UUID().uuidString, name: String, description: String? = nil,
         kind: RouteCoursePointKind = .generic, latitude: Double, longitude: Double,
         distanceMeters: Double? = nil, generated: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.kind = kind
        self.latitude = latitude
        self.longitude = longitude
        self.distanceMeters = distanceMeters
        self.generated = generated
    }

    var routeCuePoint: Route.CuePoint {
        Route.CuePoint(
            id: id,
            name: name,
            description: description,
            coordinate: Route.Coordinate(latitude: latitude, longitude: longitude)
        )
    }
}

struct RouteImportCandidate: Identifiable {
    let id: String
    let name: String
    let description: String?
    let sourceFilename: String
    let sourceFormat: RouteFileFormat
    let assetKind: RouteAssetKind
    let trackpoints: [RouteTrackPoint]
    let coursePoints: [RouteCoursePoint]
    let startedAt: Date?
    let category: String

    init(id: String = UUID().uuidString, name: String, description: String? = nil,
         sourceFilename: String, sourceFormat: RouteFileFormat, assetKind: RouteAssetKind,
         trackpoints: [RouteTrackPoint], coursePoints: [RouteCoursePoint] = [],
         startedAt: Date? = nil, category: String = "gravel") {
        self.id = id
        self.name = name
        self.description = description
        self.sourceFilename = sourceFilename
        self.sourceFormat = sourceFormat
        self.assetKind = assetKind
        self.trackpoints = trackpoints
        self.coursePoints = coursePoints
        self.startedAt = startedAt
        self.category = category
    }

    var trackpointArrays: [[Double]] {
        trackpoints.map(\.routeArray)
    }

    var distanceMiles: Double {
        Route.haversineDistance(trackpointArrays)
    }

    var elevationGainFeet: Int {
        Route.elevationGain(trackpointArrays)
    }

    var elapsedSeconds: TimeInterval {
        guard let first = trackpoints.compactMap(\.timestamp).first,
              let last = trackpoints.compactMap(\.timestamp).last,
              last > first else { return 0 }
        return last.timeIntervalSince(first)
    }

    var route: Route {
        let arrays = trackpointArrays
        let start = arrays.first ?? [0, 0, 0]
        return Route(
            id: UUID().uuidString,
            name: name,
            difficulty: Self.difficulty(distanceMiles: distanceMiles, elevationGainFeet: elevationGainFeet),
            category: category,
            distanceMiles: distanceMiles,
            elevationGainFeet: elevationGainFeet,
            region: "Imported",
            description: description ?? "Imported from \(sourceFormat.displayName) file",
            startCoordinate: Route.Coordinate(latitude: start[0], longitude: start[1]),
            trackpoints: arrays,
            cuePoints: coursePoints.map(\.routeCuePoint),
            isImported: true
        )
    }

    var completedRide: CompletedRide {
        let elapsed = elapsedSeconds
        let moving = elapsed > 0 ? elapsed : max(distanceMiles / 10 * 3600, 0)
        return CompletedRide(
            id: UUID().uuidString,
            routeId: UUID().uuidString,
            routeName: name,
            category: category,
            distanceMiles: distanceMiles,
            elapsedSeconds: elapsed,
            movingSeconds: moving,
            elevationGainFeet: Double(elevationGainFeet),
            avgSpeedMPH: moving > 0 ? distanceMiles / (moving / 3600) : 0,
            maxSpeedMPH: trackpoints.compactMap(\.speedMetersPerSecond).max().map { $0 * 2.23694 } ?? 0,
            completedAt: startedAt ?? Date(),
            gpxTrackpoints: trackpointArrays
        )
    }

    private static func difficulty(distanceMiles: Double, elevationGainFeet: Int) -> String {
        if distanceMiles > 80 || elevationGainFeet > 6000 { return "expert" }
        if distanceMiles > 40 || elevationGainFeet > 3000 { return "hard" }
        if distanceMiles > 20 || elevationGainFeet > 1500 { return "moderate" }
        return "easy"
    }
}

struct RouteImportFailure: Identifiable {
    let id = UUID()
    let filename: String
    let message: String
}

struct RouteImportBatch {
    let candidates: [RouteImportCandidate]
    let failures: [RouteImportFailure]
}

enum RouteExportFormat: String, CaseIterable, Identifiable {
    case deviceBundle
    case gpxTrack
    case tcxCourse
    case tcxHistory
    case fitCourse
    case fitActivity
    case kml

    var id: String { rawValue }

    var label: String {
        switch self {
        case .deviceBundle: "Device Bundle"
        case .gpxTrack: "GPX Track"
        case .tcxCourse: "TCX Course"
        case .tcxHistory: "TCX History"
        case .fitCourse: "FIT Course"
        case .fitActivity: "FIT Activity"
        case .kml: "KML"
        }
    }
}

enum RouteInterchangeError: LocalizedError {
    case emptyFile
    case fileTooLarge
    case unsupportedFormat
    case invalidFormat(String)
    case noTrackpoints
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .emptyFile: "The file is empty."
        case .fileTooLarge: "The file is too large to import on device."
        case .unsupportedFormat: "That route file type is not supported."
        case .invalidFormat(let message): message
        case .noTrackpoints: "The file does not contain enough GPS points."
        case .writeFailed: "Could not write the export file."
        }
    }
}

enum RouteInterchangeService {
    static let maxImportBytes = 50 * 1024 * 1024

    static func importFiles(_ urls: [URL]) -> RouteImportBatch {
        var candidates: [RouteImportCandidate] = []
        var failures: [RouteImportFailure] = []

        for url in urls {
            do {
                candidates.append(contentsOf: try importFile(url: url))
            } catch {
                failures.append(RouteImportFailure(filename: url.lastPathComponent, message: error.localizedDescription))
            }
        }

        return RouteImportBatch(candidates: candidates, failures: failures)
    }

    static func importFile(url: URL) throws -> [RouteImportCandidate] {
        let data = try Data(contentsOf: url)
        return try importData(data, filename: url.lastPathComponent)
    }

    static func importData(_ data: Data, filename: String) throws -> [RouteImportCandidate] {
        guard !data.isEmpty else { throw RouteInterchangeError.emptyFile }
        guard data.count <= maxImportBytes else { throw RouteInterchangeError.fileTooLarge }

        let format = sniffFormat(data: data, filename: filename)
        switch format {
        case .gpx:
            return [try GPXInterchangeParser.parse(data: data, filename: filename)]
        case .tcx:
            return [try TCXInterchangeParser.parse(data: data, filename: filename)]
        case .fit:
            return [try FITInterchangeCodec.decode(data: data, filename: filename)]
        case .kml:
            return [try KMLInterchangeParser.parse(data: data, filename: filename, format: .kml)]
        case .kmz, .zip:
            return try importArchive(data: data, filename: filename, archiveFormat: format)
        case .unknown:
            throw RouteInterchangeError.unsupportedFormat
        }
    }

    static func sniffFormat(data: Data, filename: String) -> RouteFileFormat {
        let lower = filename.lowercased()
        if data.starts(with: [0x50, 0x4B, 0x03, 0x04]) {
            return lower.hasSuffix(".kmz") ? .kmz : .zip
        }
        if data.count >= 12, String(data: data[8..<12], encoding: .ascii) == ".FIT" {
            return .fit
        }

        let prefix = String(data: data.prefix(min(data.count, 4096)), encoding: .utf8)?
            .lowercased() ?? ""
        if prefix.contains("<gpx") { return .gpx }
        if prefix.contains("trainingcenterdatabase") { return .tcx }
        if prefix.contains("<kml") { return .kml }

        if lower.hasSuffix(".gpx") { return .gpx }
        if lower.hasSuffix(".tcx") { return .tcx }
        if lower.hasSuffix(".fit") { return .fit }
        if lower.hasSuffix(".kml") { return .kml }
        if lower.hasSuffix(".kmz") { return .kmz }
        if lower.hasSuffix(".zip") { return .zip }
        return .unknown
    }

    static func writeRouteExport(route: Route, format: RouteExportFormat) -> URL? {
        let basename = sanitizedFilename(route.name)
        switch format {
        case .deviceBundle:
            let files = routeDeviceBundleFiles(route: route)
            let data = ZipArchive.store(entries: files)
            return write(data: data, basename: "\(basename)_device_bundle", ext: "zip")
        case .gpxTrack:
            return write(text: exportGPX(route: route, includeTimes: false), basename: basename, ext: "gpx")
        case .tcxCourse:
            return write(text: exportTCXCourse(route: route), basename: basename, ext: "tcx")
        case .tcxHistory:
            return write(text: exportTCXHistory(routeName: route.name, points: points(from: route)), basename: basename, ext: "tcx")
        case .fitCourse:
            return write(data: exportFITCourseData(route: route), basename: basename, ext: "fit")
        case .fitActivity:
            return write(data: exportFITActivityData(routeName: route.name, points: points(from: route)), basename: basename, ext: "fit")
        case .kml:
            return write(text: exportKML(routeName: route.name, points: points(from: route), coursePoints: coursePoints(from: route)), basename: basename, ext: "kml")
        }
    }

    static func writeRideExport(ride: CompletedRide, format: RouteExportFormat) -> URL? {
        guard let trackpoints = ride.gpxTrackpoints else { return nil }
        let points = trackpoints.enumerated().map { index, point in
            RouteTrackPoint(
                latitude: point[0],
                longitude: point[1],
                elevationMeters: point.count > 2 ? point[2] : nil,
                timestamp: ride.completedAt.addingTimeInterval(Double(index) * max(ride.elapsedSeconds / Double(max(trackpoints.count - 1, 1)), 1))
            )
        }
        let basename = sanitizedFilename(ride.routeName)
        switch format {
        case .deviceBundle:
            let files = rideDeviceBundleFiles(ride: ride, points: points)
            return write(data: ZipArchive.store(entries: files), basename: "\(basename)_ride_bundle", ext: "zip")
        case .gpxTrack:
            return write(text: exportGPX(routeName: ride.routeName, description: "Recorded ride", points: points, coursePoints: []), basename: basename, ext: "gpx")
        case .tcxCourse:
            let route = Route(
                id: ride.routeId,
                name: ride.routeName,
                difficulty: "moderate",
                category: ride.category,
                distanceMiles: ride.distanceMiles,
                elevationGainFeet: Int(ride.elevationGainFeet),
                region: "Recorded",
                description: "Recorded ride",
                startCoordinate: Route.Coordinate(latitude: points.first?.latitude ?? 0, longitude: points.first?.longitude ?? 0),
                trackpoints: points.map(\.routeArray),
                isImported: true
            )
            return write(text: exportTCXCourse(route: route), basename: basename, ext: "tcx")
        case .tcxHistory:
            return write(text: exportTCXHistory(routeName: ride.routeName, points: points), basename: basename, ext: "tcx")
        case .fitCourse:
            let route = Route(
                id: ride.routeId,
                name: ride.routeName,
                difficulty: "moderate",
                category: ride.category,
                distanceMiles: ride.distanceMiles,
                elevationGainFeet: Int(ride.elevationGainFeet),
                region: "Recorded",
                description: "Recorded ride",
                startCoordinate: Route.Coordinate(latitude: points.first?.latitude ?? 0, longitude: points.first?.longitude ?? 0),
                trackpoints: points.map(\.routeArray),
                isImported: true
            )
            return write(data: exportFITCourseData(route: route), basename: basename, ext: "fit")
        case .fitActivity:
            return write(data: exportFITActivityData(routeName: ride.routeName, points: points), basename: basename, ext: "fit")
        case .kml:
            return write(text: exportKML(routeName: ride.routeName, points: points, coursePoints: []), basename: basename, ext: "kml")
        }
    }

    static func exportFITCourseData(route: Route) -> Data {
        FITInterchangeCodec.encodeCourse(routeName: route.name, points: points(from: route), coursePoints: coursePoints(from: route))
    }

    static func exportFITActivityData(routeName: String, points: [RouteTrackPoint]) -> Data {
        FITInterchangeCodec.encodeActivity(routeName: routeName, points: points)
    }

    static func exportTCXCourse(route: Route) -> String {
        let points = points(from: route)
        let cues = coursePoints(from: route)
        let finalCues = cues.isEmpty ? generatedCoursePoints(points: points) : cues
        let distance = route.distanceMiles * 1609.344
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
          <Courses>
            <Course>
              <Name>\(xmlEscape(route.name))</Name>
              <Lap>
                <TotalTimeSeconds>\(Int(max(route.distanceMiles / 10 * 3600, 1)))</TotalTimeSeconds>
                <DistanceMeters>\(format(distance))</DistanceMeters>
                <BeginPosition><LatitudeDegrees>\(format(route.startCoordinate.latitude))</LatitudeDegrees><LongitudeDegrees>\(format(route.startCoordinate.longitude))</LongitudeDegrees></BeginPosition>
                <EndPosition><LatitudeDegrees>\(format(points.last?.latitude ?? route.startCoordinate.latitude))</LatitudeDegrees><LongitudeDegrees>\(format(points.last?.longitude ?? route.startCoordinate.longitude))</LongitudeDegrees></EndPosition>
                <Intensity>Active</Intensity>
              </Lap>
              <Track>
        \(points.map(tcxTrackpoint).joined(separator: "\n"))
              </Track>
        \(finalCues.map(tcxCoursePoint).joined(separator: "\n"))
            </Course>
          </Courses>
        </TrainingCenterDatabase>
        """
    }

    static func exportTCXHistory(routeName: String, points: [RouteTrackPoint]) -> String {
        let start = points.first?.timestamp ?? Date()
        let distance = accumulatedDistances(points: points).last ?? 0
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
          <Activities>
            <Activity Sport="Biking">
              <Id>\(iso8601(start))</Id>
              <Lap StartTime="\(iso8601(start))">
                <TotalTimeSeconds>\(Int((points.last?.timestamp ?? start).timeIntervalSince(start)))</TotalTimeSeconds>
                <DistanceMeters>\(format(distance))</DistanceMeters>
                <Intensity>Active</Intensity>
                <TriggerMethod>Manual</TriggerMethod>
                <Track>
        \(points.map(tcxTrackpoint).joined(separator: "\n"))
                </Track>
              </Lap>
              <Notes>\(xmlEscape(routeName))</Notes>
            </Activity>
          </Activities>
        </TrainingCenterDatabase>
        """
    }

    static func exportGPX(route: Route, includeTimes: Bool) -> String {
        exportGPX(routeName: route.name, description: route.description, points: points(from: route), coursePoints: coursePoints(from: route), includeTimes: includeTimes)
    }

    static func exportGPX(routeName: String, description: String, points: [RouteTrackPoint],
                          coursePoints: [RouteCoursePoint], includeTimes: Bool = true) -> String {
        var waypointXML = ""
        for cue in coursePoints {
            waypointXML += """
              <wpt lat="\(format(cue.latitude))" lon="\(format(cue.longitude))">
                <name>\(xmlEscape(cue.name))</name>
                <desc>\(xmlEscape(cue.description ?? ""))</desc>
                <type>\(xmlEscape(cue.kind.rawValue))</type>
              </wpt>

            """
        }

        let trackXML = points.map { point -> String in
            var body = ""
            if let elevation = point.elevationMeters {
                body += "\n        <ele>\(format(elevation))</ele>"
            }
            if includeTimes, let timestamp = point.timestamp {
                body += "\n        <time>\(iso8601(timestamp))</time>"
            }
            return body.isEmpty
                ? "      <trkpt lat=\"\(format(point.latitude))\" lon=\"\(format(point.longitude))\"/>"
                : """
                      <trkpt lat="\(format(point.latitude))" lon="\(format(point.longitude))">\(body)
                      </trkpt>
                  """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="StoneBC" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(xmlEscape(routeName))</name>
            <desc>\(xmlEscape(description))</desc>
            <time>\(iso8601(Date()))</time>
          </metadata>
        \(waypointXML)  <trk>
            <name>\(xmlEscape(routeName))</name>
            <type>Cycling</type>
            <trkseg>
        \(trackXML)
            </trkseg>
          </trk>
        </gpx>
        """
    }

    static func exportKML(routeName: String, points: [RouteTrackPoint], coursePoints: [RouteCoursePoint]) -> String {
        let coords = points
            .map { "\(format($0.longitude)),\(format($0.latitude)),\(format($0.elevationMeters ?? 0))" }
            .joined(separator: " ")
        let placemarks = coursePoints.map { cue in
            """
              <Placemark>
                <name>\(xmlEscape(cue.name))</name>
                <description>\(xmlEscape(cue.description ?? ""))</description>
                <Point><coordinates>\(format(cue.longitude)),\(format(cue.latitude)),0</coordinates></Point>
              </Placemark>
            """
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2">
          <Document>
            <name>\(xmlEscape(routeName))</name>
            <Placemark>
              <name>\(xmlEscape(routeName))</name>
              <LineString>
                <tessellate>1</tessellate>
                <coordinates>\(coords)</coordinates>
              </LineString>
            </Placemark>
        \(placemarks)
          </Document>
        </kml>
        """
    }

    static func generatedCoursePoints(points: [RouteTrackPoint]) -> [RouteCoursePoint] {
        guard points.count >= 3 else { return [] }
        let distances = accumulatedDistances(points: points)
        var result: [RouteCoursePoint] = []
        for index in stride(from: 10, to: points.count - 10, by: 12) {
            let before = points[index - 6].coordinate
            let current = points[index].coordinate
            let after = points[index + 6].coordinate
            let change = normalizedAngle(bearing(from: before, to: current) - bearing(from: current, to: after))
            guard abs(change) > 35 else { continue }
            let kind: RouteCoursePointKind = change > 0 ? .left : .right
            let name = kind == .left ? "Turn left" : "Turn right"
            result.append(RouteCoursePoint(
                name: name,
                description: "Generated from route geometry",
                kind: kind,
                latitude: current.latitude,
                longitude: current.longitude,
                distanceMeters: distances[index],
                generated: true
            ))
        }
        if let first = points.first {
            result.insert(RouteCoursePoint(name: "Start", kind: .start, latitude: first.latitude, longitude: first.longitude, distanceMeters: 0, generated: true), at: 0)
        }
        if let last = points.last {
            result.append(RouteCoursePoint(name: "Finish", kind: .finish, latitude: last.latitude, longitude: last.longitude, distanceMeters: distances.last, generated: true))
        }
        return result
    }

    private static func importArchive(data: Data, filename: String, archiveFormat: RouteFileFormat) throws -> [RouteImportCandidate] {
        let entries = try ZipArchive.entries(from: data)
        var candidates: [RouteImportCandidate] = []
        for entry in entries {
            let lower = entry.name.lowercased()
            guard lower.hasSuffix(".gpx") || lower.hasSuffix(".tcx") || lower.hasSuffix(".fit") || lower.hasSuffix(".kml") else {
                continue
            }
            let nestedName = "\(filename)/\(entry.name)"
            candidates.append(contentsOf: try importData(entry.data, filename: nestedName))
        }
        if candidates.isEmpty {
            throw RouteInterchangeError.invalidFormat("\(archiveFormat.displayName) did not contain supported route files.")
        }
        return candidates
    }

    private static func routeDeviceBundleFiles(route: Route) -> [(String, Data)] {
        let base = sanitizedFilename(route.name)
        let readme = """
        StoneBC route bundle: \(route.name)

        Files:
        - \(base).gpx: GPX Track for broad compatibility.
        - \(base).tcx: TCX Course with cue points.
        - \(base).fit: FIT Course for Garmin/Wahoo workflows.
        - \(base).kml: KML for Google Earth/GIS review.

        If your device accepts more than one format, try FIT or TCX first for turn/cue support, GPX for maximum compatibility.
        """
        return [
            ("README.txt", Data(readme.utf8)),
            ("\(base).gpx", Data(exportGPX(route: route, includeTimes: false).utf8)),
            ("\(base).tcx", Data(exportTCXCourse(route: route).utf8)),
            ("\(base).fit", exportFITCourseData(route: route)),
            ("\(base).kml", Data(exportKML(routeName: route.name, points: points(from: route), coursePoints: coursePoints(from: route)).utf8))
        ]
    }

    private static func rideDeviceBundleFiles(ride: CompletedRide, points: [RouteTrackPoint]) -> [(String, Data)] {
        let base = sanitizedFilename(ride.routeName)
        let readme = """
        StoneBC ride bundle: \(ride.routeName)

        Files:
        - \(base).gpx: GPX activity track.
        - \(base).tcx: TCX History activity.
        - \(base).fit: FIT Activity.
        - \(base).kml: KML track.
        """
        return [
            ("README.txt", Data(readme.utf8)),
            ("\(base).gpx", Data(exportGPX(routeName: ride.routeName, description: "Recorded ride", points: points, coursePoints: []).utf8)),
            ("\(base).tcx", Data(exportTCXHistory(routeName: ride.routeName, points: points).utf8)),
            ("\(base).fit", exportFITActivityData(routeName: ride.routeName, points: points)),
            ("\(base).kml", Data(exportKML(routeName: ride.routeName, points: points, coursePoints: []).utf8))
        ]
    }

    private static func points(from route: Route) -> [RouteTrackPoint] {
        let distances = route.trackpoints.enumerated().map { index, _ in
            Route.haversineDistance(Array(route.trackpoints.prefix(index + 1))) * 1609.344
        }
        return route.trackpoints.enumerated().compactMap { index, point in
            guard point.count >= 2 else { return nil }
            return RouteTrackPoint(
                latitude: point[0],
                longitude: point[1],
                elevationMeters: point.count > 2 ? point[2] : nil,
                distanceMeters: distances[index]
            )
        }
    }

    private static func coursePoints(from route: Route) -> [RouteCoursePoint] {
        route.cuePoints.map {
            RouteCoursePoint(
                id: $0.id,
                name: $0.name,
                description: $0.description,
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude
            )
        }
    }

    private static func accumulatedDistances(points: [RouteTrackPoint]) -> [Double] {
        guard !points.isEmpty else { return [] }
        var distances = Array(repeating: 0.0, count: points.count)
        for index in 1..<points.count {
            let from = CLLocation(latitude: points[index - 1].latitude, longitude: points[index - 1].longitude)
            let to = CLLocation(latitude: points[index].latitude, longitude: points[index].longitude)
            distances[index] = distances[index - 1] + from.distance(from: to)
        }
        return distances
    }

    private static func tcxTrackpoint(_ point: RouteTrackPoint) -> String {
        var xml = """
                  <Trackpoint>
                    <Time>\(iso8601(point.timestamp ?? Date()))</Time>
                    <Position><LatitudeDegrees>\(format(point.latitude))</LatitudeDegrees><LongitudeDegrees>\(format(point.longitude))</LongitudeDegrees></Position>
        """
        if let elevation = point.elevationMeters {
            xml += "\n            <AltitudeMeters>\(format(elevation))</AltitudeMeters>"
        }
        if let distance = point.distanceMeters {
            xml += "\n            <DistanceMeters>\(format(distance))</DistanceMeters>"
        }
        xml += "\n          </Trackpoint>"
        return xml
    }

    private static func tcxCoursePoint(_ point: RouteCoursePoint) -> String {
        """
              <CoursePoint>
                <Name>\(xmlEscape(point.name))</Name>
                <Time>\(iso8601(Date()))</Time>
                <Position><LatitudeDegrees>\(format(point.latitude))</LatitudeDegrees><LongitudeDegrees>\(format(point.longitude))</LongitudeDegrees></Position>
                <PointType>\(tcxPointType(point.kind))</PointType>
                <Notes>\(xmlEscape(point.description ?? ""))</Notes>
              </CoursePoint>
        """
    }

    private static func tcxPointType(_ kind: RouteCoursePointKind) -> String {
        switch kind {
        case .left: "Left"
        case .right: "Right"
        case .straight: "Straight"
        case .summit: "Summit"
        case .valley: "Valley"
        case .water, .food: "Food"
        case .danger: "Danger"
        case .firstAid: "First Aid"
        default: "Generic"
        }
    }

    static func sanitizedFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let name = String(scalars).replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        return name.trimmingCharacters(in: CharacterSet(charactersIn: "_")).isEmpty ? "route" : name
    }

    private static func write(text: String, basename: String, ext: String) -> URL? {
        write(data: Data(text.utf8), basename: basename, ext: ext)
    }

    private static func write(data: Data, basename: String, ext: String) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(basename)
            .appendingPathExtension(ext)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static func parseISO8601(_ string: String) -> Date? {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = f1.date(from: string) { return date }
        return ISO8601DateFormatter().date(from: string)
    }

    static func xmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    static func format(_ value: Double) -> String {
        String(format: "%.6f", value)
    }

    private static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x) * 180 / .pi
    }

    private static func normalizedAngle(_ angle: Double) -> Double {
        var result = angle
        while result > 180 { result -= 360 }
        while result < -180 { result += 360 }
        return result
    }
}

private final class GPXInterchangeParser: NSObject, XMLParserDelegate {
    private var filename = ""
    private var trackpoints: [RouteTrackPoint] = []
    private var waypoints: [RouteCoursePoint] = []
    private var routeName: String?
    private var routeDescription: String?
    private var currentElement = ""
    private var currentText = ""
    private var pointKind: PointKind?
    private var inMetadata = false
    private var inTrackOrRoute = false
    private var lat: Double?
    private var lon: Double?
    private var ele: Double?
    private var time: Date?
    private var name: String?
    private var desc: String?
    private var type: String?

    private enum PointKind {
        case track
        case waypoint
    }

    static func parse(data: Data, filename: String) throws -> RouteImportCandidate {
        let parserDelegate = GPXInterchangeParser()
        parserDelegate.filename = filename
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate
        guard parser.parse() else {
            throw RouteInterchangeError.invalidFormat("The GPX file is not valid XML.")
        }
        guard parserDelegate.trackpoints.count >= 2 else {
            throw RouteInterchangeError.noTrackpoints
        }
        return RouteImportCandidate(
            name: parserDelegate.routeName ?? RouteInterchangeService.sanitizedFilename((filename as NSString).deletingPathExtension),
            description: parserDelegate.routeDescription,
            sourceFilename: filename,
            sourceFormat: .gpx,
            assetKind: parserDelegate.trackpoints.contains(where: { $0.timestamp != nil }) ? .completedRide : .plannedRoute,
            trackpoints: parserDelegate.trackpoints,
            coursePoints: parserDelegate.waypoints,
            startedAt: parserDelegate.trackpoints.first?.timestamp
        )
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""
        switch stripped(elementName) {
        case "metadata":
            inMetadata = true
        case "trk", "rte":
            inTrackOrRoute = true
        case "trkpt", "rtept":
            startPoint(attributes: attributes, kind: .track)
        case "wpt":
            startPoint(attributes: attributes, kind: .waypoint)
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName: String?) {
        let element = stripped(elementName)
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch element {
        case "name":
            if pointKind == .waypoint {
                name = text
            } else if routeName == nil && (inMetadata || inTrackOrRoute) {
                routeName = text
            }
        case "desc", "cmt":
            if pointKind == .waypoint {
                desc = desc ?? text
            } else if routeDescription == nil && inMetadata {
                routeDescription = text
            }
        case "type", "sym":
            if pointKind == .waypoint { type = text }
        case "ele":
            ele = Double(text)
        case "time":
            time = RouteInterchangeService.parseISO8601(text)
        case "trkpt", "rtept":
            if let lat, let lon {
                trackpoints.append(RouteTrackPoint(latitude: lat, longitude: lon, elevationMeters: ele, timestamp: time))
            }
            resetPoint()
        case "wpt":
            if let lat, let lon {
                let waypointName = name.flatMap { $0.isEmpty ? nil : $0 } ?? "Waypoint"
                waypoints.append(RouteCoursePoint(
                    name: waypointName,
                    description: desc,
                    kind: Self.kind(from: type ?? name ?? ""),
                    latitude: lat,
                    longitude: lon
                ))
            }
            resetPoint()
        case "metadata":
            inMetadata = false
        case "trk", "rte":
            inTrackOrRoute = false
        default:
            break
        }
    }

    private func startPoint(attributes: [String: String], kind: PointKind) {
        lat = Double(attributes["lat"] ?? "")
        lon = Double(attributes["lon"] ?? "")
        ele = nil
        time = nil
        name = nil
        desc = nil
        type = nil
        pointKind = kind
    }

    private func resetPoint() {
        lat = nil
        lon = nil
        ele = nil
        time = nil
        name = nil
        desc = nil
        type = nil
        pointKind = nil
    }

    private func stripped(_ elementName: String) -> String {
        elementName.components(separatedBy: ":").last ?? elementName
    }

    private static func kind(from value: String) -> RouteCoursePointKind {
        let lower = value.lowercased()
        if lower.contains("left") { return .left }
        if lower.contains("right") { return .right }
        if lower.contains("water") { return .water }
        if lower.contains("food") || lower.contains("resupply") { return .food }
        if lower.contains("danger") || lower.contains("warning") { return .danger }
        if lower.contains("start") { return .start }
        if lower.contains("finish") { return .finish }
        return .generic
    }
}

private final class TCXInterchangeParser: NSObject, XMLParserDelegate {
    private var filename = ""
    private var trackpoints: [RouteTrackPoint] = []
    private var coursePoints: [RouteCoursePoint] = []
    private var routeName: String?
    private var routeDescription: String?
    private var assetKind: RouteAssetKind = .plannedRoute
    private var currentElement = ""
    private var currentText = ""
    private var stack: [String] = []
    private var point = MutableTrackPoint()
    private var coursePoint = MutableCoursePoint()
    private var inTrackpoint = false
    private var inCoursePoint = false
    private var inCourse = false
    private var inActivity = false

    static func parse(data: Data, filename: String) throws -> RouteImportCandidate {
        let delegate = TCXInterchangeParser()
        delegate.filename = filename
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw RouteInterchangeError.invalidFormat("The TCX file is not valid XML.")
        }
        guard delegate.trackpoints.count >= 2 else {
            throw RouteInterchangeError.noTrackpoints
        }
        return RouteImportCandidate(
            name: delegate.routeName ?? RouteInterchangeService.sanitizedFilename((filename as NSString).deletingPathExtension),
            description: delegate.routeDescription,
            sourceFilename: filename,
            sourceFormat: .tcx,
            assetKind: delegate.assetKind,
            trackpoints: delegate.trackpoints,
            coursePoints: delegate.coursePoints,
            startedAt: delegate.trackpoints.first?.timestamp
        )
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        let element = stripped(elementName)
        stack.append(element)
        currentElement = element
        currentText = ""
        switch element {
        case "Course":
            inCourse = true
            assetKind = .plannedRoute
        case "Activity":
            inActivity = true
            assetKind = .completedRide
        case "Trackpoint":
            inTrackpoint = true
            point = MutableTrackPoint()
        case "CoursePoint":
            inCoursePoint = true
            coursePoint = MutableCoursePoint()
        case "Lap":
            if let start = attributes["StartTime"] {
                point.startedAt = RouteInterchangeService.parseISO8601(start)
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName: String?) {
        let element = stripped(elementName)
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch element {
        case "Name":
            if inCoursePoint {
                coursePoint.name = text
            } else if inCourse && routeName == nil {
                routeName = text
            }
        case "Notes":
            if inCoursePoint {
                coursePoint.notes = text
            } else if routeDescription == nil {
                routeDescription = text
            }
        case "Time":
            if inTrackpoint {
                point.timestamp = RouteInterchangeService.parseISO8601(text)
            } else if inCoursePoint {
                coursePoint.timestamp = RouteInterchangeService.parseISO8601(text)
            }
        case "LatitudeDegrees":
            if inTrackpoint {
                point.latitude = Double(text)
            } else if inCoursePoint {
                coursePoint.latitude = Double(text)
            }
        case "LongitudeDegrees":
            if inTrackpoint {
                point.longitude = Double(text)
            } else if inCoursePoint {
                coursePoint.longitude = Double(text)
            }
        case "AltitudeMeters":
            if inTrackpoint { point.elevationMeters = Double(text) }
        case "DistanceMeters":
            if inTrackpoint {
                point.distanceMeters = Double(text)
            } else if inCoursePoint {
                coursePoint.distanceMeters = Double(text)
            }
        case "Speed":
            if inTrackpoint { point.speedMetersPerSecond = Double(text) }
        case "Watts":
            if inTrackpoint { point.powerWatts = Double(text) }
        case "Cadence":
            if inTrackpoint { point.cadence = Double(text) }
        case "Value":
            if inTrackpoint && stack.contains("HeartRateBpm") {
                point.heartRate = Double(text)
            }
        case "PointType":
            if inCoursePoint { coursePoint.kind = Self.kind(from: text) }
        case "Trackpoint":
            if let latitude = point.latitude, let longitude = point.longitude {
                trackpoints.append(RouteTrackPoint(
                    latitude: latitude,
                    longitude: longitude,
                    elevationMeters: point.elevationMeters,
                    timestamp: point.timestamp ?? point.startedAt,
                    distanceMeters: point.distanceMeters,
                    speedMetersPerSecond: point.speedMetersPerSecond,
                    heartRate: point.heartRate,
                    cadence: point.cadence,
                    powerWatts: point.powerWatts
                ))
            }
            inTrackpoint = false
        case "CoursePoint":
            if let latitude = coursePoint.latitude, let longitude = coursePoint.longitude {
                let pointName = coursePoint.name.flatMap { $0.isEmpty ? nil : $0 } ?? "Course Point"
                coursePoints.append(RouteCoursePoint(
                    name: pointName,
                    description: coursePoint.notes,
                    kind: coursePoint.kind,
                    latitude: latitude,
                    longitude: longitude,
                    distanceMeters: coursePoint.distanceMeters
                ))
            }
            inCoursePoint = false
        case "Course":
            inCourse = false
        case "Activity":
            inActivity = false
        default:
            break
        }
        _ = stack.popLast()
    }

    private func stripped(_ elementName: String) -> String {
        elementName.components(separatedBy: ":").last ?? elementName
    }

    private static func kind(from value: String) -> RouteCoursePointKind {
        switch value.lowercased() {
        case let v where v.contains("left"): .left
        case let v where v.contains("right"): .right
        case let v where v.contains("straight"): .straight
        case let v where v.contains("summit"): .summit
        case let v where v.contains("valley"): .valley
        case let v where v.contains("danger"): .danger
        case let v where v.contains("first"): .firstAid
        default: .generic
        }
    }

    private struct MutableTrackPoint {
        var latitude: Double?
        var longitude: Double?
        var elevationMeters: Double?
        var timestamp: Date?
        var startedAt: Date?
        var distanceMeters: Double?
        var speedMetersPerSecond: Double?
        var heartRate: Double?
        var cadence: Double?
        var powerWatts: Double?
    }

    private struct MutableCoursePoint {
        var name: String?
        var notes: String?
        var kind: RouteCoursePointKind = .generic
        var latitude: Double?
        var longitude: Double?
        var timestamp: Date?
        var distanceMeters: Double?
    }
}

private final class KMLInterchangeParser: NSObject, XMLParserDelegate {
    private var filename = ""
    private var format: RouteFileFormat = .kml
    private var routeName: String?
    private var coordinatesText: [String] = []
    private var gxCoords: [String] = []
    private var gxTimes: [Date] = []
    private var currentElement = ""
    private var currentText = ""

    static func parse(data: Data, filename: String, format: RouteFileFormat) throws -> RouteImportCandidate {
        let delegate = KMLInterchangeParser()
        delegate.filename = filename
        delegate.format = format
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw RouteInterchangeError.invalidFormat("The KML file is not valid XML.")
        }
        var points = delegate.parseLineStringCoordinates()
        if points.isEmpty {
            points = delegate.parseGXTrackCoordinates()
        }
        guard points.count >= 2 else {
            throw RouteInterchangeError.noTrackpoints
        }
        return RouteImportCandidate(
            name: delegate.routeName ?? RouteInterchangeService.sanitizedFilename((filename as NSString).deletingPathExtension),
            sourceFilename: filename,
            sourceFormat: format,
            assetKind: delegate.gxTimes.isEmpty ? .plannedRoute : .completedRide,
            trackpoints: points,
            startedAt: points.first?.timestamp
        )
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName.components(separatedBy: ":").last ?? elementName
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName: String?) {
        let element = elementName.components(separatedBy: ":").last ?? elementName
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch element {
        case "name":
            if routeName == nil && !text.isEmpty { routeName = text }
        case "coordinates":
            if !text.isEmpty { coordinatesText.append(text) }
        case "coord":
            if !text.isEmpty { gxCoords.append(text) }
        case "when":
            if let date = RouteInterchangeService.parseISO8601(text) { gxTimes.append(date) }
        default:
            break
        }
    }

    private func parseLineStringCoordinates() -> [RouteTrackPoint] {
        coordinatesText.flatMap { blob -> [RouteTrackPoint] in
            blob
                .components(separatedBy: .whitespacesAndNewlines)
                .compactMap { tuple -> RouteTrackPoint? in
                    let parts = tuple.split(separator: ",").compactMap { Double($0) }
                    guard parts.count >= 2 else { return nil }
                    return RouteTrackPoint(latitude: parts[1], longitude: parts[0], elevationMeters: parts.count > 2 ? parts[2] : nil)
                }
        }
    }

    private func parseGXTrackCoordinates() -> [RouteTrackPoint] {
        gxCoords.enumerated().compactMap { index, value in
            let parts = value.split(separator: " ").compactMap { Double($0) }
            guard parts.count >= 2 else { return nil }
            return RouteTrackPoint(
                latitude: parts[1],
                longitude: parts[0],
                elevationMeters: parts.count > 2 ? parts[2] : nil,
                timestamp: index < gxTimes.count ? gxTimes[index] : nil
            )
        }
    }
}

private enum FitEndian {
    case little
    case big
}

private enum FITInterchangeCodec {
    private struct FieldDef {
        let number: UInt8
        let size: Int
        let baseType: UInt8
    }

    private struct Definition {
        let global: UInt16
        let endian: FitEndian
        let fields: [FieldDef]
    }

    static func decode(data: Data, filename: String) throws -> RouteImportCandidate {
        guard data.count >= 14 else { throw RouteInterchangeError.invalidFormat("The FIT file is too small.") }
        let headerSize = Int(data[0])
        guard headerSize >= 12, data.count >= headerSize else {
            throw RouteInterchangeError.invalidFormat("The FIT header is invalid.")
        }
        let dataSize = Int(readUInt32(data, offset: 4, endian: .little))
        let dataEnd = min(data.count, headerSize + dataSize)
        guard dataEnd > headerSize else { throw RouteInterchangeError.noTrackpoints }

        var definitions: [UInt8: Definition] = [:]
        var index = headerSize
        var points: [RouteTrackPoint] = []
        var cues: [RouteCoursePoint] = []
        var routeName: String?
        var assetKind: RouteAssetKind = .completedRide
        var currentPoint = MutableFitPoint()

        while index < dataEnd {
            let header = data[index]
            index += 1
            if header & 0x80 != 0 {
                let local = (header >> 5) & 0x03
                guard let def = definitions[local] else { break }
                parseDataMessage(def: def, data: data, index: &index, point: &currentPoint, points: &points, cues: &cues, routeName: &routeName, assetKind: &assetKind)
            } else if header & 0x40 != 0 {
                let local = header & 0x0F
                guard index + 5 <= dataEnd else { break }
                index += 1
                let architecture = data[index]
                index += 1
                let endian: FitEndian = architecture == 0 ? .little : .big
                let global = readUInt16(data, offset: index, endian: endian)
                index += 2
                let fieldCount = Int(data[index])
                index += 1
                var fields: [FieldDef] = []
                for _ in 0..<fieldCount where index + 3 <= dataEnd {
                    fields.append(FieldDef(number: data[index], size: Int(data[index + 1]), baseType: data[index + 2]))
                    index += 3
                }
                if header & 0x20 != 0, index < dataEnd {
                    let devFields = Int(data[index])
                    index += 1 + devFields * 3
                }
                definitions[local] = Definition(global: global, endian: endian, fields: fields)
            } else {
                let local = header & 0x0F
                guard let def = definitions[local] else { break }
                parseDataMessage(def: def, data: data, index: &index, point: &currentPoint, points: &points, cues: &cues, routeName: &routeName, assetKind: &assetKind)
            }
        }

        guard points.count >= 2 else { throw RouteInterchangeError.noTrackpoints }
        return RouteImportCandidate(
            name: routeName ?? RouteInterchangeService.sanitizedFilename((filename as NSString).deletingPathExtension),
            sourceFilename: filename,
            sourceFormat: .fit,
            assetKind: assetKind,
            trackpoints: points,
            coursePoints: cues,
            startedAt: points.first?.timestamp
        )
    }

    static func encodeCourse(routeName: String, points: [RouteTrackPoint], coursePoints: [RouteCoursePoint]) -> Data {
        var writer = FitWriter()
        writer.writeHeader()
        writer.writeDefinition(local: 0, global: 0, fields: [(0, 1, 0x00), (1, 2, 0x84), (2, 2, 0x84), (4, 4, 0x86)])
        writer.writeDefinition(local: 1, global: 31, fields: [(4, 1, 0x00), (5, 32, 0x07)])
        writer.writeDefinition(local: 2, global: 20, fields: [(253, 4, 0x86), (0, 4, 0x85), (1, 4, 0x85), (2, 2, 0x84), (5, 4, 0x86)])
        writer.writeDefinition(local: 3, global: 32, fields: [(1, 4, 0x86), (2, 4, 0x85), (3, 4, 0x85), (4, 4, 0x86), (5, 1, 0x00), (6, 16, 0x07)])
        writer.writeFileId(fileType: 6)
        writer.writeCourse(name: routeName)
        let distances = distancesForFIT(points)
        for (index, point) in points.enumerated() {
            writer.writeRecord(point: point, distanceMeters: distances[index])
        }
        let cues = coursePoints.isEmpty ? RouteInterchangeService.generatedCoursePoints(points: points) : coursePoints
        for cue in cues {
            writer.writeCoursePoint(cue)
        }
        return writer.finalized()
    }

    static func encodeActivity(routeName: String, points: [RouteTrackPoint]) -> Data {
        var writer = FitWriter()
        writer.writeHeader()
        writer.writeDefinition(local: 0, global: 0, fields: [(0, 1, 0x00), (1, 2, 0x84), (2, 2, 0x84), (4, 4, 0x86)])
        writer.writeDefinition(local: 2, global: 20, fields: [(253, 4, 0x86), (0, 4, 0x85), (1, 4, 0x85), (2, 2, 0x84), (5, 4, 0x86)])
        writer.writeFileId(fileType: 4)
        let distances = distancesForFIT(points)
        for (index, point) in points.enumerated() {
            writer.writeRecord(point: point, distanceMeters: distances[index])
        }
        _ = routeName
        return writer.finalized()
    }

    private static func parseDataMessage(def: Definition, data: Data, index: inout Int,
                                         point: inout MutableFitPoint, points: inout [RouteTrackPoint],
                                         cues: inout [RouteCoursePoint], routeName: inout String?,
                                         assetKind: inout RouteAssetKind) {
        var fields: [UInt8: Data] = [:]
        for field in def.fields {
            guard index + field.size <= data.count else { return }
            fields[field.number] = data[index..<index + field.size]
            index += field.size
        }

        switch def.global {
        case 0:
            if let fileType = uint(fields[0], endian: def.endian), fileType == 6 {
                assetKind = .plannedRoute
            }
        case 20:
            guard let latRaw = int(fields[0], endian: def.endian),
                  let lonRaw = int(fields[1], endian: def.endian) else { return }
            let latitude = semicirclesToDegrees(latRaw)
            let longitude = semicirclesToDegrees(lonRaw)
            let altitude = altitudeMeters(fields[78], endian: def.endian)
                ?? altitudeMeters(fields[2], endian: def.endian)
            let timestamp = uint(fields[253], endian: def.endian).map(fitDate)
            let distance = uint(fields[5], endian: def.endian).map { Double($0) / 100 }
            let speed = uint(fields[73], endian: def.endian).map { Double($0) / 1000 }
                ?? uint(fields[6], endian: def.endian).map { Double($0) / 1000 }
            points.append(RouteTrackPoint(
                latitude: latitude,
                longitude: longitude,
                elevationMeters: altitude,
                timestamp: timestamp,
                distanceMeters: distance,
                speedMetersPerSecond: speed,
                heartRate: uint(fields[3], endian: def.endian).map(Double.init),
                cadence: uint(fields[4], endian: def.endian).map(Double.init),
                powerWatts: uint(fields[7], endian: def.endian).map(Double.init)
            ))
        case 31:
            if let name = string(fields[5]), !name.isEmpty {
                routeName = name
                assetKind = .plannedRoute
            }
        case 32:
            guard let latRaw = int(fields[2], endian: def.endian),
                  let lonRaw = int(fields[3], endian: def.endian) else { return }
            cues.append(RouteCoursePoint(
                name: string(fields[6]) ?? "Course Point",
                kind: coursePointKind(uint(fields[5], endian: def.endian)),
                latitude: semicirclesToDegrees(latRaw),
                longitude: semicirclesToDegrees(lonRaw),
                distanceMeters: uint(fields[4], endian: def.endian).map { Double($0) / 100 }
            ))
            assetKind = .plannedRoute
        default:
            skipKnownSummary(def: def, fields: fields, point: &point)
        }
    }

    private static func skipKnownSummary(def: Definition, fields: [UInt8: Data], point: inout MutableFitPoint) {
        _ = def
        _ = fields
        _ = point
    }

    private static func distancesForFIT(_ points: [RouteTrackPoint]) -> [Double] {
        if points.allSatisfy({ $0.distanceMeters != nil }) {
            return points.map { $0.distanceMeters ?? 0 }
        }
        var result = Array(repeating: 0.0, count: points.count)
        for index in 1..<points.count {
            let from = CLLocation(latitude: points[index - 1].latitude, longitude: points[index - 1].longitude)
            let to = CLLocation(latitude: points[index].latitude, longitude: points[index].longitude)
            result[index] = result[index - 1] + from.distance(from: to)
        }
        return result
    }

    private static func altitudeMeters(_ data: Data?, endian: FitEndian) -> Double? {
        uint(data, endian: endian).map { Double($0) / 5 - 500 }
    }

    private static func int(_ data: Data?, endian: FitEndian) -> Int32? {
        guard let data else { return nil }
        if data.count >= 4 {
            return readInt32(data, offset: 0, endian: endian)
        }
        if data.count >= 2 {
            return Int32(readInt16(data, offset: 0, endian: endian))
        }
        return data.first.map { Int32(Int8(bitPattern: $0)) }
    }

    private static func uint(_ data: Data?, endian: FitEndian) -> UInt32? {
        guard let data else { return nil }
        if data.count >= 4 { return readUInt32(data, offset: 0, endian: endian) }
        if data.count >= 2 { return UInt32(readUInt16(data, offset: 0, endian: endian)) }
        return data.first.map(UInt32.init)
    }

    private static func string(_ data: Data?) -> String? {
        guard let data else { return nil }
        let trimmed = data.prefix { $0 != 0 }
        return String(data: trimmed, encoding: .utf8)
    }

    private static func semicirclesToDegrees(_ value: Int32) -> Double {
        Double(value) * 180.0 / 2147483648.0
    }

    private static func degreesToSemicircles(_ value: Double) -> Int32 {
        Int32(max(Double(Int32.min), min(Double(Int32.max), value * 2147483648.0 / 180.0)))
    }

    private static func fitDate(_ value: UInt32) -> Date {
        Date(timeIntervalSince1970: TimeInterval(value) + 631065600)
    }

    private static func fitTimestamp(_ date: Date) -> UInt32 {
        UInt32(max(0, date.timeIntervalSince1970 - 631065600))
    }

    private static func coursePointKind(_ raw: UInt32?) -> RouteCoursePointKind {
        switch raw {
        case 6: .left
        case 7: .right
        case 8: .straight
        case 1: .summit
        case 2: .valley
        case 10: .water
        case 11: .food
        case 13: .danger
        default: .generic
        }
    }

    private static func coursePointType(_ kind: RouteCoursePointKind) -> UInt8 {
        switch kind {
        case .summit: 1
        case .valley: 2
        case .left: 6
        case .right: 7
        case .straight: 8
        case .water: 10
        case .food: 11
        case .danger: 13
        default: 0
        }
    }

    private struct MutableFitPoint {}

    private struct FitWriter {
        private var data = Data()
        private var dataStart = 12

        mutating func writeHeader() {
            data.append(12)
            data.append(0x10)
            data.appendUInt16LE(0)
            data.appendUInt32LE(0)
            data.append(contentsOf: [0x2E, 0x46, 0x49, 0x54])
        }

        mutating func writeDefinition(local: UInt8, global: UInt16, fields: [(UInt8, UInt8, UInt8)]) {
            data.append(0x40 | local)
            data.append(0)
            data.append(0)
            data.appendUInt16LE(global)
            data.append(UInt8(fields.count))
            for field in fields {
                data.append(field.0)
                data.append(field.1)
                data.append(field.2)
            }
        }

        mutating func writeFileId(fileType: UInt8) {
            data.append(0)
            data.append(fileType)
            data.appendUInt16LE(255)
            data.appendUInt16LE(1)
            data.appendUInt32LE(fitTimestamp(Date()))
        }

        mutating func writeCourse(name: String) {
            data.append(1)
            data.append(2)
            data.appendFixedString(name, length: 32)
        }

        mutating func writeRecord(point: RouteTrackPoint, distanceMeters: Double) {
            data.append(2)
            data.appendUInt32LE(fitTimestamp(point.timestamp ?? Date()))
            data.appendInt32LE(degreesToSemicircles(point.latitude))
            data.appendInt32LE(degreesToSemicircles(point.longitude))
            let altitude = UInt16(max(0, min(65535, ((point.elevationMeters ?? 0) + 500) * 5)))
            data.appendUInt16LE(altitude)
            data.appendUInt32LE(UInt32(max(0, distanceMeters * 100)))
        }

        mutating func writeCoursePoint(_ point: RouteCoursePoint) {
            data.append(3)
            data.appendUInt32LE(fitTimestamp(Date()))
            data.appendInt32LE(degreesToSemicircles(point.latitude))
            data.appendInt32LE(degreesToSemicircles(point.longitude))
            data.appendUInt32LE(UInt32(max(0, (point.distanceMeters ?? 0) * 100)))
            data.append(coursePointType(point.kind))
            data.appendFixedString(point.name, length: 16)
        }

        mutating func finalized() -> Data {
            let dataSize = UInt32(data.count - dataStart)
            data.replaceSubrange(4..<8, with: Data.uint32LE(dataSize))
            let crc = CRC.fit(data)
            data.appendUInt16LE(crc)
            return data
        }
    }
}

private enum ZipArchive {
    struct Entry {
        let name: String
        let data: Data
    }

    static func store(entries: [(String, Data)]) -> Data {
        var output = Data()
        var central = Data()
        for entry in entries {
            let safeName = entry.0
                .replacingOccurrences(of: "..", with: "")
                .replacingOccurrences(of: "/", with: "_")
            let nameData = Data(safeName.utf8)
            let offset = UInt32(output.count)
            let crc = CRC.crc32(entry.1)

            output.appendUInt32LE(0x04034B50)
            output.appendUInt16LE(20)
            output.appendUInt16LE(0)
            output.appendUInt16LE(0)
            output.appendUInt16LE(0)
            output.appendUInt16LE(0)
            output.appendUInt32LE(crc)
            output.appendUInt32LE(UInt32(entry.1.count))
            output.appendUInt32LE(UInt32(entry.1.count))
            output.appendUInt16LE(UInt16(nameData.count))
            output.appendUInt16LE(0)
            output.append(nameData)
            output.append(entry.1)

            central.appendUInt32LE(0x02014B50)
            central.appendUInt16LE(20)
            central.appendUInt16LE(20)
            central.appendUInt16LE(0)
            central.appendUInt16LE(0)
            central.appendUInt16LE(0)
            central.appendUInt16LE(0)
            central.appendUInt32LE(crc)
            central.appendUInt32LE(UInt32(entry.1.count))
            central.appendUInt32LE(UInt32(entry.1.count))
            central.appendUInt16LE(UInt16(nameData.count))
            central.appendUInt16LE(0)
            central.appendUInt16LE(0)
            central.appendUInt16LE(0)
            central.appendUInt16LE(0)
            central.appendUInt32LE(0)
            central.appendUInt32LE(offset)
            central.append(nameData)
        }

        let centralOffset = UInt32(output.count)
        output.append(central)
        output.appendUInt32LE(0x06054B50)
        output.appendUInt16LE(0)
        output.appendUInt16LE(0)
        output.appendUInt16LE(UInt16(entries.count))
        output.appendUInt16LE(UInt16(entries.count))
        output.appendUInt32LE(UInt32(central.count))
        output.appendUInt32LE(centralOffset)
        output.appendUInt16LE(0)
        return output
    }

    static func entries(from data: Data) throws -> [Entry] {
        var entries: [Entry] = []
        var index = 0
        while index + 30 <= data.count {
            let signature = readUInt32(data, offset: index, endian: .little)
            guard signature == 0x04034B50 else { break }
            let flags = readUInt16(data, offset: index + 6, endian: .little)
            let method = readUInt16(data, offset: index + 8, endian: .little)
            let compressedSize = Int(readUInt32(data, offset: index + 18, endian: .little))
            let uncompressedSize = Int(readUInt32(data, offset: index + 22, endian: .little))
            let nameLength = Int(readUInt16(data, offset: index + 26, endian: .little))
            let extraLength = Int(readUInt16(data, offset: index + 28, endian: .little))
            guard flags & 0x08 == 0 else {
                throw RouteInterchangeError.invalidFormat("ZIP entries with streaming descriptors are not supported.")
            }
            let nameStart = index + 30
            let dataStart = nameStart + nameLength + extraLength
            let dataEnd = dataStart + compressedSize
            guard nameStart + nameLength <= data.count, dataEnd <= data.count else {
                throw RouteInterchangeError.invalidFormat("ZIP entry is truncated.")
            }
            let name = String(data: data[nameStart..<nameStart + nameLength], encoding: .utf8) ?? "entry"
            guard !name.contains(".."), !name.hasPrefix("/") else {
                throw RouteInterchangeError.invalidFormat("ZIP entry path is not safe.")
            }
            let payload = data[dataStart..<dataEnd]
            let entryData: Data
            if method == 0 {
                entryData = payload
            } else if method == 8 {
                entryData = try inflate(payload, expectedSize: uncompressedSize)
            } else {
                throw RouteInterchangeError.invalidFormat("ZIP compression method \(method) is not supported.")
            }
            entries.append(Entry(name: name, data: entryData))
            index = dataEnd
        }
        return entries
    }

    private static func inflate(_ data: Data, expectedSize: Int) throws -> Data {
        guard expectedSize > 0 else {
            throw RouteInterchangeError.invalidFormat("Compressed ZIP entry is missing its uncompressed size.")
        }
        let destinationSize = max(expectedSize, data.count * 8)
        let output = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationSize)
        defer { output.deallocate() }
        let written = data.withUnsafeBytes { source in
            guard let sourceAddress = source.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                output,
                destinationSize,
                sourceAddress,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }
        guard written > 0 else {
            throw RouteInterchangeError.invalidFormat("Could not decompress ZIP entry.")
        }
        return Data(bytes: output, count: written)
    }
}

private enum CRC {
    static func fit(_ data: Data) -> UInt16 {
        var crc: UInt16 = 0
        for byte in data {
            var current = UInt16(byte)
            for _ in 0..<8 {
                let bit = (crc ^ current) & 1
                crc >>= 1
                if bit != 0 { crc ^= 0xA001 }
                current >>= 1
            }
        }
        return crc
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            var current = (crc ^ UInt32(byte)) & 0xFF
            for _ in 0..<8 {
                current = (current & 1) != 0 ? (current >> 1) ^ 0xEDB8_8320 : current >> 1
            }
            crc = (crc >> 8) ^ current
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private func readUInt16(_ data: Data, offset: Int, endian: FitEndian) -> UInt16 {
    guard offset + 2 <= data.count else { return 0 }
    let value = UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    return endian == .little ? value : value.byteSwapped
}

private func readInt16(_ data: Data, offset: Int, endian: FitEndian) -> Int16 {
    Int16(bitPattern: readUInt16(data, offset: offset, endian: endian))
}

private func readUInt32(_ data: Data, offset: Int, endian: FitEndian) -> UInt32 {
    guard offset + 4 <= data.count else { return 0 }
    let value = UInt32(data[offset])
        | UInt32(data[offset + 1]) << 8
        | UInt32(data[offset + 2]) << 16
        | UInt32(data[offset + 3]) << 24
    return endian == .little ? value : value.byteSwapped
}

private func readInt32(_ data: Data, offset: Int, endian: FitEndian) -> Int32 {
    Int32(bitPattern: readUInt32(data, offset: offset, endian: endian))
}

private extension Data {
    func starts(with bytes: [UInt8]) -> Bool {
        count >= bytes.count && zip(prefix(bytes.count), bytes).allSatisfy { $0 == $1 }
    }

    static func uint32LE(_ value: UInt32) -> Data {
        var data = Data()
        data.appendUInt32LE(value)
        return data
    }

    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendInt32LE(_ value: Int32) {
        appendUInt32LE(UInt32(bitPattern: value))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }

    mutating func appendFixedString(_ string: String, length: Int) {
        let bytes = Array(string.utf8.prefix(length - 1))
        append(contentsOf: bytes)
        if bytes.count < length {
            append(contentsOf: Array(repeating: 0, count: length - bytes.count))
        }
    }
}
