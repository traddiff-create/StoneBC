//
//  USFSService.swift
//  StoneBC
//
//  USFS ArcGIS Feature Layer client — queries Black Hills National Forest
//  trail closure and alert data. 100% free, no API key needed.
//

import Foundation
import CoreLocation

actor USFSService {
    static let shared = USFSService()

    // Black Hills National Forest trail layer
    private let baseURL = "https://apps.fs.usda.gov/arcx/rest/services/EDW/EDW_TrailActivityData_01/MapServer/0/query"

    private var cache: [String: CachedClosure] = [:]
    private let cacheExpiry: TimeInterval = 24 * 60 * 60 // 24 hours (closures don't change often)

    // MARK: - Query Closures

    /// Check for trail closures within a bounding box
    func closures(in boundingBox: BoundingBox) async -> [TrailClosure] {
        let cacheKey = "\(boundingBox.minLat),\(boundingBox.minLon),\(boundingBox.maxLat),\(boundingBox.maxLon)"

        if let cached = cache[cacheKey], Date().timeIntervalSince(cached.fetchedAt) < cacheExpiry {
            return cached.closures
        }

        // ArcGIS query with spatial filter
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "where", value: "1=1"),
            URLQueryItem(name: "geometry", value: "\(boundingBox.minLon),\(boundingBox.minLat),\(boundingBox.maxLon),\(boundingBox.maxLat)"),
            URLQueryItem(name: "geometryType", value: "esriGeometryEnvelope"),
            URLQueryItem(name: "inSR", value: "4326"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "outFields", value: "TRAIL_NAME,TRAIL_NO,TRAIL_STATUS,ACCESSIBILITY_STATUS,NATIONAL_TRAIL_DESIGNATION"),
            URLQueryItem(name: "returnGeometry", value: "false"),
            URLQueryItem(name: "f", value: "json")
        ]

        guard let url = components.url else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return [] }

            let result = try JSONDecoder().decode(ArcGISResponse.self, from: data)

            let closures = result.features.compactMap { feature -> TrailClosure? in
                guard let name = feature.attributes.TRAIL_NAME,
                      let status = feature.attributes.TRAIL_STATUS else { return nil }

                let isClosed = status.lowercased().contains("closed") ||
                               status.lowercased().contains("decommission")

                return TrailClosure(
                    trailName: name,
                    trailNumber: feature.attributes.TRAIL_NO,
                    status: status,
                    isClosed: isClosed,
                    source: "USFS"
                )
            }

            cache[cacheKey] = CachedClosure(closures: closures, fetchedAt: Date())
            return closures
        } catch {
            return []
        }
    }

    /// Check if a specific route intersects any closures
    func closuresAffecting(route: Route) async -> [TrailClosure] {
        let trackpoints = route.clTrackpoints
        guard trackpoints.count >= 2 else { return [] }

        // Build bounding box from route with padding
        var minLat = trackpoints[0].latitude
        var maxLat = trackpoints[0].latitude
        var minLon = trackpoints[0].longitude
        var maxLon = trackpoints[0].longitude

        for pt in trackpoints {
            minLat = min(minLat, pt.latitude)
            maxLat = max(maxLat, pt.latitude)
            minLon = min(minLon, pt.longitude)
            maxLon = max(maxLon, pt.longitude)
        }

        let padding = 0.01 // ~0.7 miles
        let bbox = BoundingBox(
            minLat: minLat - padding,
            minLon: minLon - padding,
            maxLat: maxLat + padding,
            maxLon: maxLon + padding
        )

        let all = await closures(in: bbox)
        return all.filter { $0.isClosed }
    }
}

// MARK: - Models

struct BoundingBox {
    let minLat: Double
    let minLon: Double
    let maxLat: Double
    let maxLon: Double
}

struct TrailClosure: Identifiable {
    let id = UUID()
    let trailName: String
    let trailNumber: String?
    let status: String
    let isClosed: Bool
    let source: String
}

// MARK: - ArcGIS Response

private struct ArcGISResponse: Codable {
    let features: [ArcGISFeature]
}

private struct ArcGISFeature: Codable {
    let attributes: ArcGISAttributes
}

private struct ArcGISAttributes: Codable {
    let TRAIL_NAME: String?
    let TRAIL_NO: String?
    let TRAIL_STATUS: String?
    let ACCESSIBILITY_STATUS: String?
    let NATIONAL_TRAIL_DESIGNATION: String?
}

private struct CachedClosure {
    let closures: [TrailClosure]
    let fetchedAt: Date
}
