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
//  the wrapper reports user-driven region changes back through the binding so
//  callers can detect panning and stop following automatically.
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
    let tilePack: OfflineTilePackInfo?
    let showsEndpointPins: Bool

    init(region: Binding<MKCoordinateRegion>,
         isFollowingUser: Binding<Bool> = .constant(true),
         routePolyline: [CLLocationCoordinate2D] = [],
         breadcrumb: [CLLocationCoordinate2D] = [],
         routeColor: UIColor = .systemOrange,
         showsCompass: Bool = true,
         tilePack: OfflineTilePackInfo? = nil,
         showsEndpointPins: Bool = true) {
        self._region = region
        self._isFollowingUser = isFollowingUser
        self.routePolyline = routePolyline
        self.breadcrumb = breadcrumb
        self.routeColor = routeColor
        self.showsCompass = showsCompass
        self.tilePack = tilePack
        self.showsEndpointPins = showsEndpointPins
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = showsCompass
        map.showsScale = false
        map.userTrackingMode = isFollowingUser ? .followWithHeading : .none
        map.region = region

        context.coordinator.syncTileOverlays(on: map)

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncTileOverlays(on: map)

        context.coordinator.syncRouteOverlay(on: map)
        context.coordinator.syncBreadcrumbOverlay(on: map)

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
        private var tileOverlayKey: String?
        private var routeOverlayKey: String?
        private var breadcrumbOverlayKey: String?

        init(_ parent: OfflineCapableMapView) {
            self.parent = parent
        }

        func syncTileOverlays(on map: MKMapView) {
            let key = parent.tilePack.map { "\($0.routeId):\($0.sourceId):\($0.downloadedAt.timeIntervalSince1970)" } ?? "bundled"
            guard key != tileOverlayKey else { return }

            let tileOverlays = map.overlays.filter {
                $0 is BundledTileOverlay || $0 is DownloadedRouteTileOverlay
            }
            map.removeOverlays(tileOverlays)

            if let tilePack = parent.tilePack {
                map.addOverlay(DownloadedRouteTileOverlay(tilePack: tilePack), level: .aboveLabels)
            } else {
                map.addOverlay(USFSTileOverlay(), level: .aboveLabels)
                map.addOverlay(OSMCycleTileOverlay(), level: .aboveLabels)
            }

            tileOverlayKey = key
        }

        func syncRouteOverlay(on map: MKMapView) {
            let key = polylineKey(parent.routePolyline) + ":\(parent.showsEndpointPins)"
            guard key != routeOverlayKey else { return }

            let routeOverlays = map.overlays.compactMap { overlay -> MKOverlay? in
                guard let polyline = overlay as? MKPolyline, polyline.title == "route" else { return nil }
                return overlay
            }
            map.removeOverlays(routeOverlays)
            map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })

            if parent.routePolyline.count >= 2 {
                let line = MKPolyline(coordinates: parent.routePolyline, count: parent.routePolyline.count)
                line.title = "route"
                map.addOverlay(line, level: .aboveLabels)

                if parent.showsEndpointPins, let first = parent.routePolyline.first {
                    let start = MKPointAnnotation()
                    start.title = "Start"
                    start.coordinate = first
                    map.addAnnotation(start)
                }
                if parent.showsEndpointPins, let last = parent.routePolyline.last {
                    let end = MKPointAnnotation()
                    end.title = "End"
                    end.coordinate = last
                    map.addAnnotation(end)
                }
            }

            routeOverlayKey = key
        }

        func syncBreadcrumbOverlay(on map: MKMapView) {
            let key = polylineKey(parent.breadcrumb)
            guard key != breadcrumbOverlayKey else { return }

            let breadcrumbOverlays = map.overlays.compactMap { overlay -> MKOverlay? in
                guard let polyline = overlay as? MKPolyline, polyline.title == "breadcrumb" else { return nil }
                return overlay
            }
            map.removeOverlays(breadcrumbOverlays)

            if parent.breadcrumb.count >= 2 {
                let crumbs = MKPolyline(coordinates: parent.breadcrumb, count: parent.breadcrumb.count)
                crumbs.title = "breadcrumb"
                map.addOverlay(crumbs, level: .aboveLabels)
            }

            breadcrumbOverlayKey = key
        }

        private func polylineKey(_ coordinates: [CLLocationCoordinate2D]) -> String {
            guard let first = coordinates.first, let last = coordinates.last else {
                return "0"
            }
            return "\(coordinates.count):\(first.latitude):\(first.longitude):\(last.latitude):\(last.longitude)"
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let downloaded = overlay as? DownloadedRouteTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: downloaded)
                renderer.alpha = CGFloat(downloaded.tilePack.source.overlayAlpha)
                return renderer
            }
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

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let identifier = "routeEndpoint"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            if let marker = view as? MKMarkerAnnotationView {
                marker.markerTintColor = annotation.title == "Start" ? .systemGreen : .systemRed
                marker.glyphImage = UIImage(systemName: annotation.title == "Start" ? "play.fill" : "flag.checkered")
            }
            return view
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
