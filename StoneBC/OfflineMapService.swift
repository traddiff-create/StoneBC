//
//  OfflineMapService.swift
//  StoneBC
//
//  Pre-renders static map snapshots for each route so maps work offline.
//  Also provides a "Prepare for Offline" tile-warming function.
//

import MapKit
import SwiftUI

actor OfflineMapService {
    static let shared = OfflineMapService()

    private let cacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RouteSnapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Snapshot Cache

    /// Check if a snapshot already exists for a route
    func hasSnapshot(for routeId: String) -> Bool {
        FileManager.default.fileExists(atPath: snapshotPath(for: routeId).path)
    }

    /// Get cached snapshot image for a route
    func snapshot(for routeId: String) -> UIImage? {
        guard hasSnapshot(for: routeId) else { return nil }
        return UIImage(contentsOfFile: snapshotPath(for: routeId).path)
    }

    /// Generate and cache a snapshot for a single route
    func generateSnapshot(for route: Route, size: CGSize = CGSize(width: 400, height: 250)) async -> UIImage? {
        let coords = route.clTrackpoints
        guard coords.count >= 2 else { return nil }

        // Calculate bounding region with padding
        let region = boundingRegion(for: coords, padding: 1.3)

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.mapType = .standard
        options.showsBuildings = false

        let snapshotter = MKMapSnapshotter(options: options)

        do {
            let snapshot = try await snapshotter.start()

            // Draw the route polyline on the snapshot
            let image = drawRoute(on: snapshot, coordinates: coords, size: size, color: routeColor(route))

            // Cache to disk
            if let data = image.pngData() {
                try data.write(to: snapshotPath(for: route.id))
            }

            return image
        } catch {
            return nil
        }
    }

    /// Generate snapshots for all routes that don't have one yet
    func generateAllSnapshots(for routes: [Route], progress: @escaping @Sendable (Int, Int) -> Void) async {
        let missing = routes.filter { !hasSnapshot(for: $0.id) }
        for (index, route) in missing.enumerated() {
            _ = await generateSnapshot(for: route)
            progress(index + 1, missing.count)
        }
    }

    // MARK: - Tile Warming

    /// "Prepare for Offline" — programmatically request map tiles at multiple zoom levels
    /// for a route's bounding box. MapKit caches these tiles automatically.
    func warmTiles(for route: Route) async {
        let coords = route.clTrackpoints
        guard coords.count >= 2 else { return }

        let region = boundingRegion(for: coords, padding: 1.2)

        // Generate snapshots at multiple zoom levels to populate tile cache
        let sizes: [CGSize] = [
            CGSize(width: 512, height: 512),  // Overview
            CGSize(width: 1024, height: 1024), // Medium detail
        ]

        // Also warm sub-regions for higher detail
        let subRegions = splitRegion(region, divisions: 2)

        for size in sizes {
            let options = MKMapSnapshotter.Options()
            options.region = region
            options.size = size
            options.mapType = .standard
            let snapshotter = MKMapSnapshotter(options: options)
            _ = try? await snapshotter.start()
        }

        // Higher zoom on sub-regions
        for subRegion in subRegions {
            let options = MKMapSnapshotter.Options()
            options.region = subRegion
            options.size = CGSize(width: 512, height: 512)
            options.mapType = .standard
            let snapshotter = MKMapSnapshotter(options: options)
            _ = try? await snapshotter.start()
        }
    }

    // MARK: - Private Helpers

    private func snapshotPath(for routeId: String) -> URL {
        cacheDir.appendingPathComponent("\(routeId).png")
    }

    private func boundingRegion(for coords: [CLLocationCoordinate2D], padding: Double) -> MKCoordinateRegion {
        var minLat = coords[0].latitude
        var maxLat = coords[0].latitude
        var minLon = coords[0].longitude
        var maxLon = coords[0].longitude

        for coord in coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * padding,
            longitudeDelta: (maxLon - minLon) * padding
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    private func splitRegion(_ region: MKCoordinateRegion, divisions: Int) -> [MKCoordinateRegion] {
        var regions: [MKCoordinateRegion] = []
        let latStep = region.span.latitudeDelta / Double(divisions)
        let lonStep = region.span.longitudeDelta / Double(divisions)
        let startLat = region.center.latitude - region.span.latitudeDelta / 2
        let startLon = region.center.longitude - region.span.longitudeDelta / 2

        for row in 0..<divisions {
            for col in 0..<divisions {
                let center = CLLocationCoordinate2D(
                    latitude: startLat + latStep * (Double(row) + 0.5),
                    longitude: startLon + lonStep * (Double(col) + 0.5)
                )
                let span = MKCoordinateSpan(latitudeDelta: latStep, longitudeDelta: lonStep)
                regions.append(MKCoordinateRegion(center: center, span: span))
            }
        }
        return regions
    }

    private func drawRoute(on snapshot: MKMapSnapshotter.Snapshot, coordinates: [CLLocationCoordinate2D], size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            snapshot.image.draw(at: .zero)

            let path = UIBezierPath()
            for (i, coord) in coordinates.enumerated() {
                let point = snapshot.point(for: coord)
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            color.setStroke()
            path.lineWidth = 3
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()

            // Start dot
            if let first = coordinates.first {
                let startPoint = snapshot.point(for: first)
                UIColor.green.setFill()
                UIBezierPath(ovalIn: CGRect(x: startPoint.x - 5, y: startPoint.y - 5, width: 10, height: 10)).fill()
            }

            // End dot
            if let last = coordinates.last, coordinates.count > 1 {
                let endPoint = snapshot.point(for: last)
                UIColor.red.setFill()
                UIBezierPath(ovalIn: CGRect(x: endPoint.x - 5, y: endPoint.y - 5, width: 10, height: 10)).fill()
            }
        }
    }

    private func routeColor(_ route: Route) -> UIColor {
        switch route.category {
        case "trail": return UIColor(red: 0.18, green: 0.63, blue: 0.26, alpha: 1)    // green
        case "gravel": return UIColor(red: 0.82, green: 0.60, blue: 0.13, alpha: 1)   // amber
        case "road": return UIColor(red: 0.34, green: 0.65, blue: 1.0, alpha: 1)      // blue
        case "fatbike": return UIColor(red: 0.64, green: 0.44, blue: 0.97, alpha: 1)  // purple
        default: return UIColor(red: 0.34, green: 0.65, blue: 1.0, alpha: 1)
        }
    }
}
