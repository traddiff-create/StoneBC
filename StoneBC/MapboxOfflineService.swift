//
//  MapboxOfflineService.swift
//  StoneBC
//
//  Mapbox offline vector tile manager for full offline map navigation.
//  Requires MapboxMaps SPM package — see setup instructions below.
//
//  SETUP (one-time):
//  1. Create free Mapbox account at https://account.mapbox.com
//  2. Get access token from https://account.mapbox.com/access-tokens/
//  3. Add to config.json: "mapboxAccessToken": "pk.xxxx..."
//  4. In Xcode: File > Add Package > https://github.com/mapbox/mapbox-maps-ios.git
//  5. Add MapboxMaps framework to the StoneBC target
//  6. Uncomment the MapboxMaps import and implementation below
//
//  Free tier: 25,000 monthly active users, includes offline downloads.
//  Black Hills region (~100-150MB at zoom levels 6-14).
//

import Foundation
import CoreLocation

// Uncomment when MapboxMaps SPM package is added:
// import MapboxMaps

actor MapboxOfflineService {
    static let shared = MapboxOfflineService()

    var isConfigured = false
    var isDownloading = false
    var downloadProgress: Double = 0
    var downloadedRegions: [String] = []
    var error: String?

    // Black Hills bounding box (covers all 56 routes)
    static let blackHillsBounds = (
        sw: CLLocationCoordinate2D(latitude: 43.5, longitude: -104.1),
        ne: CLLocationCoordinate2D(latitude: 44.6, longitude: -103.0)
    )

    // MARK: - Configuration

    func configure(accessToken: String) {
        guard !accessToken.isEmpty else { return }
        isConfigured = true
        // Uncomment when MapboxMaps is added:
        // MapboxOptions.accessToken = accessToken
    }

    // MARK: - Download Region

    /// Download Black Hills offline tiles (zoom levels 6-14)
    /// Call this from "Prepare for Offline" button
    func downloadBlackHills() async {
        guard isConfigured else {
            error = "Mapbox not configured — add access token to config.json"
            return
        }

        isDownloading = true
        downloadProgress = 0
        error = nil

        // Mapbox implementation placeholder:
        // When MapboxMaps is added, use OfflineManager to download tiles:
        //
        // let tileset = TilesetDescriptor(styleURI: .outdoors, zoomRange: 6...14)
        // let region = OfflineRegion(
        //     id: "black-hills",
        //     styleURI: .outdoors,
        //     coordinate: CLLocationCoordinate2D(latitude: 44.05, longitude: -103.55),
        //     zoomRange: 6...14,
        //     geometry: .polygon(...)
        // )
        //
        // try await offlineManager.download(region) { progress in
        //     self.downloadProgress = progress.completedResourceCount / progress.requiredResourceCount
        // }

        // Simulate for now — remove when MapboxMaps is integrated
        for i in 1...10 {
            try? await Task.sleep(for: .milliseconds(200))
            downloadProgress = Double(i) / 10.0
        }

        isDownloading = false
        downloadedRegions.append("black-hills")
    }

    /// Check if a region has been downloaded
    func isRegionDownloaded(_ regionId: String) -> Bool {
        downloadedRegions.contains(regionId)
    }

    /// Estimated download size for Black Hills at zoom 6-14
    var estimatedDownloadSize: String {
        "~120 MB" // Typical for mountainous terrain at these zoom levels
    }

    // MARK: - Cleanup

    func deleteRegion(_ regionId: String) {
        downloadedRegions.removeAll { $0 == regionId }
        // Uncomment when MapboxMaps is added:
        // try? offlineManager.deleteRegion(forId: regionId)
    }

    func deleteAllRegions() {
        downloadedRegions.removeAll()
    }
}
