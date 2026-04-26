//
//  OfflineCapableMapView.swift
//  StoneBC
//
//  `UIViewRepresentable<MKMapView>` wrapper that hosts the bundled
//  `MKTileOverlay` layers, the route polyline, the breadcrumb polyline, and
//  the user location annotation. The two SwiftUI `Map` sites (navigation +
//  free recording) cannot register `MKTileOverlay` instances on iOS 17, so
//  this is the migration target.
//
//  Camera state is owned by the caller via a `Binding<MKCoordinateRegion>`;
//  the wrapper sets the region only when the binding's value changes
//  externally (handle drift / "recenter" buttons), and reports user-driven
//  region changes back via the binding so the caller can detect "user is
//  panning, stop following them."
//

import SwiftUI
import MapKit

struct OfflineCapableMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var isFollowingUser: Bool

    let routePolyline: [CLLocationCoordinate2D]
    let breadcrumb: [CLLocationCoordinate2D]
    let routeColor: UIColor
    let showsCompass: Bool

    init(region: Binding<MKCoordinateRegion>,
         isFollowingUser: Binding<Bool> = .constant(true),
         routePolyline: [CLLocationCoordinate2D] = [],
         breadcrumb: [CLLocationCoordinate2D] = [],
         routeColor: UIColor = .systemOrange,
         showsCompass: Bool = true) {
        self._region = region
        self._isFollowingUser = isFollowingUser
        self.routePolyline = routePolyline
        self.breadcrumb = breadcrumb
        self.routeColor = routeColor
        self.showsCompass = showsCompass
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = showsCompass
        map.showsScale = false
        map.userTrackingMode = isFollowingUser ? .followWithHeading : .none
        map.region = region

        // Bundled tile layers — USFS base + OSM Cycle overlay. Order matters:
        // the base goes in first so the cycle layer renders on top of it.
        map.addOverlay(USFSTileOverlay(), level: .aboveLabels)
        map.addOverlay(OSMCycleTileOverlay(), level: .aboveLabels)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Refresh polylines — diff would be nicer but the polyline arrays are
        // small enough that re-adding is fine. Strip everything that isn't a
        // tile overlay, then re-add the route + breadcrumb.
        let nonTileOverlays = map.overlays.filter { !($0 is BundledTileOverlay) }
        map.removeOverlays(nonTileOverlays)

        if routePolyline.count >= 2 {
            let line = MKPolyline(coordinates: routePolyline, count: routePolyline.count)
            line.title = "route"
            map.addOverlay(line, level: .aboveLabels)
        }
        if breadcrumb.count >= 2 {
            let crumbs = MKPolyline(coordinates: breadcrumb, count: breadcrumb.count)
            crumbs.title = "breadcrumb"
            map.addOverlay(crumbs, level: .aboveLabels)
        }

        // Camera follow toggle — only set if it changed, to avoid fighting
        // the user when they pan.
        let desiredMode: MKUserTrackingMode = isFollowingUser ? .followWithHeading : .none
        if map.userTrackingMode != desiredMode {
            map.setUserTrackingMode(desiredMode, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: OfflineCapableMapView

        init(_ parent: OfflineCapableMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let cycleTile = overlay as? OSMCycleTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: cycleTile)
                renderer.alpha = 0.6
                return renderer
            }
            if let baseTile = overlay as? BundledTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: baseTile)
            }
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                if polyline.title == "breadcrumb" {
                    renderer.strokeColor = .systemOrange
                    renderer.lineWidth = 4
                    renderer.lineDashPattern = [4, 6]
                } else {
                    renderer.strokeColor = parent.routeColor
                    renderer.lineWidth = 5
                }
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // Detect user pan so the caller can stop following.
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // If the user pans, the tracking mode flips to .none. We mirror
            // that back to the binding so the recenter button reappears.
            if mapView.userTrackingMode == .none && parent.isFollowingUser {
                Task { @MainActor in
                    parent.isFollowingUser = false
                }
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Sync region back to the caller for any external listeners.
            Task { @MainActor in
                parent.region = mapView.region
            }
        }
    }
}
