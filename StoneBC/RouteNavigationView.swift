//
//  RouteNavigationView.swift
//  StoneBC
//
//  Live route navigation — user location on map, progress tracking, off-route alerts
//

import SwiftUI
import MapKit
import CoreLocation

struct RouteNavigationView: View {
    let route: Route

    @State private var locationService = LocationService()
    @State private var position: MapCameraPosition = .automatic
    @State private var isFollowingUser = true
    @Environment(\.dismiss) var dismiss

    private var closestPointIndex: Int? {
        guard let userLoc = locationService.userLocation else { return nil }
        let userCL = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        return route.clTrackpoints.enumerated().min { a, b in
            let locA = CLLocation(latitude: a.element.latitude, longitude: a.element.longitude)
            let locB = CLLocation(latitude: b.element.latitude, longitude: b.element.longitude)
            return userCL.distance(from: locA) < userCL.distance(from: locB)
        }?.offset
    }

    private var distanceFromRoute: Double {
        guard let userLoc = locationService.userLocation,
              let idx = closestPointIndex else { return 0 }
        let userCL = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let closestCL = CLLocation(
            latitude: route.clTrackpoints[idx].latitude,
            longitude: route.clTrackpoints[idx].longitude
        )
        return userCL.distance(from: closestCL)
    }

    private var isOffRoute: Bool { distanceFromRoute > 50 }

    private var progressPercent: Double {
        guard let idx = closestPointIndex, !route.clTrackpoints.isEmpty else { return 0 }
        return Double(idx) / Double(max(route.clTrackpoints.count - 1, 1))
    }

    private var distanceRemaining: Double {
        guard let idx = closestPointIndex else { return route.distanceMiles }
        let remaining = Array(route.trackpoints[idx...])
        return Route.haversineDistance(remaining)
    }

    var body: some View {
        ZStack {
            // Map
            Map(position: $position) {
                // Route polyline
                MapPolyline(coordinates: route.clTrackpoints)
                    .stroke(BCColors.brandBlue, lineWidth: 4)

                // Start pin
                if let first = route.clTrackpoints.first {
                    Annotation("Start", coordinate: first) {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }

                // End pin
                if let last = route.clTrackpoints.last, route.clTrackpoints.count > 1 {
                    Annotation("End", coordinate: last) {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }

                // User location
                if let userLoc = locationService.userLocation {
                    Annotation("You", coordinate: userLoc) {
                        ZStack {
                            Circle()
                                .fill(BCColors.brandBlue)
                                .frame(width: 20, height: 20)
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 20, height: 20)
                            Circle()
                                .fill(BCColors.brandBlue.opacity(0.2))
                                .frame(width: 40, height: 40)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .onChange(of: locationService.userLocation?.latitude) {
                if isFollowingUser, let loc = locationService.userLocation {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        position = .camera(MapCamera(
                            centerCoordinate: loc,
                            distance: 1500,
                            heading: locationService.heading,
                            pitch: 45
                        ))
                    }
                }
            }
            .onMapCameraChange { _ in
                // User panned manually — stop auto-following
                // Re-enable with recenter button
            }

            // HUD overlay
            VStack(spacing: 0) {
                // Top stats panel
                VStack(spacing: BCSpacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(route.name)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                            if locationService.userLocation != nil {
                                Text(String(format: "%.1f mi remaining", distanceRemaining))
                                    .font(.bcCaption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Acquiring location...")
                                    .font(.bcCaption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button {
                            locationService.stopTracking()
                            dismiss()
                        } label: {
                            Text("END")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.9))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }

                    // Progress bar
                    if locationService.userLocation != nil {
                        ProgressView(value: progressPercent)
                            .tint(BCColors.brandGreen)
                    }
                }
                .padding(BCSpacing.md)
                .background(.ultraThinMaterial)

                // Off-route warning
                if isOffRoute {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("You're off route (\(Int(distanceFromRoute))m away)")
                            .font(.bcSecondaryText)
                        Spacer()
                    }
                    .padding(BCSpacing.sm)
                    .padding(.horizontal, BCSpacing.sm)
                    .background(Color.orange.opacity(0.15))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Recenter button
                if !isFollowingUser {
                    HStack {
                        Spacer()
                        Button {
                            isFollowingUser = true
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        .padding(BCSpacing.md)
                    }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("NAVIGATING")
                    .font(.bcSectionTitle)
                    .tracking(2)
            }
        }
        .onAppear {
            locationService.requestPermission()
            locationService.startTracking()
        }
        .onDisappear {
            locationService.stopTracking()
        }
    }
}

#Preview {
    NavigationStack {
        RouteNavigationView(route: .preview)
    }
}
