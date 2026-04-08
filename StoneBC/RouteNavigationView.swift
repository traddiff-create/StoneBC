//
//  RouteNavigationView.swift
//  StoneBC
//
//  Live route navigation — map + ride dashboard with compass, altimeter, speed,
//  audio turn cues, breadcrumb trail, and off-route warnings
//

import SwiftUI
import MapKit
import CoreLocation

struct RouteNavigationView: View {
    let route: Route

    @State private var locationService = LocationService()
    @State private var altimeterService = AltimeterService()
    @State private var audioService = NavigationAudioService()
    @State private var workoutService = WorkoutService()
    @State private var activityManager = RideActivityManager()
    @State private var session: RideSession
    @State private var position: MapCameraPosition = .automatic
    @State private var isFollowingUser = true
    @State private var mapStyle: MapStyleOption = .standard
    @State private var showEndConfirm = false
    @State private var wasOffRoute = false
    @State private var breadcrumbs: [CLLocationCoordinate2D] = []
    @State private var showAudioToggle = false
    @Environment(\.dismiss) var dismiss

    init(route: Route) {
        self.route = route
        self._session = State(initialValue: RideSession(route: route))
    }

    var body: some View {
        ZStack {
            // Map
            Map(position: $position) {
                // Route polyline (planned)
                MapPolyline(coordinates: route.clTrackpoints)
                    .stroke(BCColors.brandBlue, lineWidth: 4)

                // Breadcrumb trail (actual path ridden)
                if breadcrumbs.count >= 2 {
                    MapPolyline(coordinates: breadcrumbs)
                        .stroke(.orange, style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
                }

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
                guard let loc = locationService.userLocation else { return }

                // Update session
                session.updateLocation(loc, speed: locationService.speedMPS)

                // Add breadcrumb (every ~10m to avoid excessive points)
                if let last = breadcrumbs.last {
                    let lastCL = CLLocation(latitude: last.latitude, longitude: last.longitude)
                    let currentCL = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
                    if currentCL.distance(from: lastCL) > 10 {
                        breadcrumbs.append(loc)
                    }
                } else {
                    breadcrumbs.append(loc)
                }

                // Audio: off-route detection
                if session.isOffRoute {
                    if !wasOffRoute {
                        audioService.announceOffRoute(distanceMeters: session.distanceFromRouteMeters)
                        wasOffRoute = true
                    }
                } else if wasOffRoute {
                    audioService.announceBackOnRoute()
                    wasOffRoute = false
                }

                // Audio: milestone check
                audioService.checkMilestone(
                    distanceMiles: session.distanceTraveledMiles,
                    totalMiles: route.distanceMiles
                )

                // Live Activity update
                activityManager.updateActivity(
                    speedMPH: locationService.speedMPH,
                    distanceTraveled: session.distanceTraveledMiles,
                    distanceRemaining: session.distanceRemainingMiles,
                    elapsedTime: session.formattedElapsedTime,
                    progress: session.progressPercent,
                    isOffRoute: session.isOffRoute,
                    heading: locationService.heading
                )

                // HealthKit: feed GPS data every ~5 points
                if workoutService.isRecording && breadcrumbs.count % 5 == 0 {
                    let recent = Array(locationService.locationHistory.suffix(5))
                    workoutService.addRouteData(recent)
                }

                // Audio: turn detection
                if let turn = NavigationAudioService.detectTurn(
                    trackpoints: route.clTrackpoints,
                    currentIndex: session.closestTrackpointIndex
                ), turn.distanceMeters < 200 {
                    audioService.announceTurn(direction: turn.direction, distanceAhead: turn.distanceMeters)
                }

                // Follow user
                if isFollowingUser {
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
                HStack(spacing: 12) {
                    // Map style toggle
                    Button {
                        withAnimation { mapStyle = mapStyle.next }
                    } label: {
                        Image(systemName: mapStyle.icon)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    // Audio toggle
                    Button {
                        audioService.isEnabled.toggle()
                    } label: {
                        Image(systemName: audioService.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 14))
                            .foregroundColor(audioService.isEnabled ? .white : .orange)
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
            audioService.reset()
            session.start()
            activityManager.startActivity(
                routeName: route.name,
                distanceMiles: route.distanceMiles,
                category: route.category
            )
        }
        .task {
            if workoutService.isAvailable {
                await workoutService.requestAuthorization()
                if workoutService.isAuthorized {
                    await workoutService.startWorkout(routeName: route.name)
                }
            }
        }
        .onDisappear {
            locationService.stopTracking()
            altimeterService.stop()
            session.stop()
        }
        .confirmationDialog("End this ride?", isPresented: $showEndConfirm) {
            Button("End Ride", role: .destructive) {
                audioService.announceRideComplete(
                    distance: session.distanceTraveledMiles,
                    time: session.formattedElapsedTime
                )
                activityManager.endActivity(
                    finalDistance: session.distanceTraveledMiles,
                    finalTime: session.formattedElapsedTime
                )
                Task {
                    await workoutService.endWorkout(
                        distance: session.distanceTraveledMiles,
                        duration: session.elapsedSeconds
                    )
                }
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
