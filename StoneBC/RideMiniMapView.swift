import SwiftUI
import MapKit

struct RideMiniMapView: View {
    let trackpoints: [[Double]]

    private var coordinates: [CLLocationCoordinate2D] {
        trackpoints.compactMap { pt in
            guard pt.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pt[0], longitude: pt[1])
        }
    }

    private var region: MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 44.08, longitude: -103.23),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        let lats = coordinates.map { $0.latitude }
        let lons = coordinates.map { $0.longitude }
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.002),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.002)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    var body: some View {
        Map(initialPosition: .region(region)) {
            MapPolyline(coordinates: coordinates)
                .stroke(BCColors.brandBlue, lineWidth: 2)
        }
        .disabled(true)
        .allowsHitTesting(false)
    }
}
