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
    @State private var showConditionReport = false
    @State private var wasOffRoute = false
    @State private var breadcrumbs: [CLLocationCoordinate2D] = []
    @State private var showAudioToggle = false
    @State private var precomputedTurns: [TurnPoint] = []
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

                // Update session + emergency location
                session.updateLocation(loc, speed: locationService.speedMPS)
                EmergencySafetyService.shared.updateLocation(loc)

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

                // Audio: off-route detection (warn at 50m, critical at 150m)
                if session.isOffRoute {
                    if !wasOffRoute || session.isCriticallyOffRoute {
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

                // Audio: turn detection (uses pre-computed turns for O(1) lookup)
                if let nextTurn = RouteAnalysisService.nextTurn(
                    from: session.closestTrackpointIndex,
                    in: precomputedTurns
                ) {
                    let dist = RouteAnalysisService.distanceToTurn(
                        from: session.closestTrackpointIndex,
                        to: nextTurn,
                        trackpoints: route.clTrackpoints
                    )
                    if dist < 200 && dist > 10 { // announce 200m out, stop once past
                        audioService.announceTurn(direction: nextTurn.direction, distanceAhead: dist)
                    }
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
            guard route.isNavigable else {
                dismiss()
                return
            }
            locationService.requestPermission()
            locationService.startTracking()
            altimeterService.start()
            audioService.reset()
            session.start()

            // Wire GPS → barometer altitude fusion calibration
            locationService.onFirstAltitude = { [altimeterService] gpsAltitude in
                altimeterService.calibrateWithGPS(altitudeMeters: gpsAltitude)
            }

            // Pre-compute turn points for efficient navigation
            precomputedTurns = RouteAnalysisService.analyzeTurns(for: route)
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
                // Record ride to history
                RideHistoryService.shared.recordRide(
                    routeId: route.id,
                    routeName: route.name,
                    category: route.category,
                    distanceMiles: session.distanceTraveledMiles,
                    elapsedSeconds: session.elapsedSeconds,
                    movingSeconds: session.movingSeconds,
                    elevationGainFeet: Double(altimeterService.totalAscentFeet),
                    avgSpeedMPH: locationService.averageSpeedMPH,
                    maxSpeedMPH: locationService.maxSpeedMPH
                )

                // Feed last GPS to emergency service
                EmergencySafetyService.shared.lastKnownLocation = nil

                locationService.stopTracking()
                altimeterService.stop()
                session.stop()
                showConditionReport = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(session.formattedDistance) ridden in \(session.formattedElapsedTime)")
        }
        .sheet(isPresented: $showConditionReport) {
            ConditionReportSheet(routeId: route.id, routeName: route.name) {
                dismiss()
            }
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

// MARK: - Condition Report Sheet

struct ConditionReportSheet: View {
    let routeId: String
    let routeName: String
    let onDismiss: () -> Void

    @State private var selectedCondition: RideCondition?
    @State private var note = ""
    @Environment(\.dismiss) var sheetDismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("How was the trail?")
                    .font(.system(size: 18, weight: .semibold))

                Text(routeName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                // Condition quick-tap grid
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(RideCondition.allCases, id: \.self) { condition in
                        Button {
                            selectedCondition = condition
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: condition.icon)
                                    .font(.system(size: 20))
                                Text(condition.label)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedCondition == condition
                                        ? Color.accentColor.opacity(0.2)
                                        : Color(UIColor.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedCondition == condition ? Color.accentColor : .clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Optional note
                TextField("Add a note (optional)", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))

                Spacer()
            }
            .padding()
            .navigationTitle("Trail Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") {
                        sheetDismiss()
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Submit") {
                        if let condition = selectedCondition {
                            RouteConditionReporter.shared.submitReport(
                                routeId: routeId,
                                condition: condition,
                                note: note.isEmpty ? nil : note
                            )
                        }
                        sheetDismiss()
                        onDismiss()
                    }
                    .disabled(selectedCondition == nil)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        RouteNavigationView(route: .preview)
    }
}
