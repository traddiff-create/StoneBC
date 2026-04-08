//
//  RouteNavigationView.swift
//  StoneBC
//
//  Live route navigation — map + ride dashboard with compass, altimeter, speed
//

import SwiftUI
import MapKit
import CoreLocation

struct RouteNavigationView: View {
    let route: Route

    @State private var locationService = LocationService()
    @State private var altimeterService = AltimeterService()
    @State private var session: RideSession
    @State private var position: MapCameraPosition = .automatic
    @State private var isFollowingUser = true
    @State private var mapStyle: MapStyleOption = .standard
    @State private var showEndConfirm = false
    @Environment(\.dismiss) var dismiss

    init(route: Route) {
        self.route = route
        self._session = State(initialValue: RideSession(route: route))
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
            .mapStyle(mapStyle.style)
            .onChange(of: locationService.userLocation?.latitude) {
                // Update session with new location
                if let loc = locationService.userLocation {
                    session.updateLocation(loc, speed: locationService.speedMPS)
                }

                // Follow user
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

            // Dashboard overlay
            VStack(spacing: 0) {
                // Offline banner
                if !ConnectivityService.shared.isConnected {
                    OfflineBannerView()
                }

                // Ride dashboard at top
                RideDashboardView(
                    session: session,
                    locationService: locationService,
                    altimeterService: altimeterService
                )

                Spacer()

                // Bottom controls
                HStack(spacing: 16) {
                    // Map style toggle
                    Button {
                        withAnimation {
                            mapStyle = mapStyle.next
                        }
                    } label: {
                        Image(systemName: mapStyle.icon)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Recenter button
                    if !isFollowingUser {
                        Button {
                            isFollowingUser = true
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14))
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    // End ride button
                    Button {
                        showEndConfirm = true
                    } label: {
                        Text("END RIDE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.9))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, BCSpacing.md)
                .padding(.bottom, BCSpacing.md)
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
            altimeterService.start()
            session.start()
        }
        .onDisappear {
            locationService.stopTracking()
            altimeterService.stop()
            session.stop()
        }
        .confirmationDialog("End this ride?", isPresented: $showEndConfirm) {
            Button("End Ride", role: .destructive) {
                locationService.stopTracking()
                altimeterService.stop()
                session.stop()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(session.formattedDistance) ridden in \(session.formattedElapsedTime)")
        }
    }
}

// MARK: - Map Style Option

enum MapStyleOption: CaseIterable {
    case standard, satellite, hybrid

    var style: MapStyle {
        switch self {
        case .standard: .standard(elevation: .realistic)
        case .satellite: .imagery(elevation: .realistic)
        case .hybrid: .hybrid(elevation: .realistic)
        }
    }

    var icon: String {
        switch self {
        case .standard: "map"
        case .satellite: "globe.americas"
        case .hybrid: "square.stack.3d.up"
        }
    }

    var next: MapStyleOption {
        let all = MapStyleOption.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }
}

#Preview {
    NavigationStack {
        RouteNavigationView(route: .preview)
    }
}
