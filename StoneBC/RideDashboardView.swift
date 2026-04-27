//
//  RideDashboardView.swift
//  StoneBC
//
//  Ride cockpit — compass ring, barometric altimeter, speed, session stats
//

import SwiftUI

// MARK: - Compass Ring

struct CompassRingView: View {
    let heading: Double          // device true heading (0-360)
    let bearingToWaypoint: Double? // bearing to next waypoint (0-360)
    let headingAccuracy: Double

    private var rotation: Angle { .degrees(-heading) }

    var body: some View {
        ZStack {
            // Outer frame with cardinal marks
            Rectangle()
                .stroke(Color.white.opacity(0.15), lineWidth: 2)

            // Cardinal direction ticks
            ForEach(0..<36, id: \.self) { i in
                let angle = Double(i) * 10
                let isMajor = i % 9 == 0 // N, E, S, W
                let isMinor = i % 3 == 0 // every 30°

                if isMajor || isMinor {
                    Rectangle()
                        .fill(isMajor ? Color.white : Color.white.opacity(0.4))
                        .frame(width: isMajor ? 2 : 1, height: isMajor ? 12 : 7)
                        .offset(y: -52)
                        .rotationEffect(.degrees(angle))
                }
            }
            .rotationEffect(rotation)

            // Cardinal labels
            ForEach(["N", "E", "S", "W"], id: \.self) { label in
                let angle: Double = switch label {
                case "N": 0
                case "E": 90
                case "S": 180
                case "W": 270
                default: 0
                }

                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(label == "N" ? Color.red : Color.white.opacity(0.7))
                    .offset(y: -38)
                    .rotationEffect(.degrees(angle))
                    .rotationEffect(.degrees(heading)) // counter-rotate to stay upright
            }
            .rotationEffect(rotation)

            // Bearing-to-waypoint arrow
            if let bearing = bearingToWaypoint {
                WaypointArrow()
                    .fill(BCColors.brandGreen)
                    .frame(width: 10, height: 18)
                    .offset(y: -28)
                    .rotationEffect(.degrees(bearing))
                    .rotationEffect(rotation)
            }

            // North indicator (fixed at top)
            Triangle()
                .fill(Color.red)
                .frame(width: 8, height: 6)
                .offset(y: -62)

            // Center display
            VStack(spacing: 2) {
                Text(String(format: "%.0f°", heading))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text(cardinalDirection)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: 130, height: 130)
    }

    private var cardinalDirection: String {
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5).truncatingRemainder(dividingBy: 360) / 45)
        return dirs[index]
    }
}

// Arrow shape pointing up for waypoint bearing
struct WaypointArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.6))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Dashboard Stat Tile

struct DashStatTile: View {
    let label: String
    let value: String
    let unit: String
    var icon: String? = nil
    var highlight: Bool = false

    var body: some View {
        VStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(highlight ? BCColors.brandGreen : .white.opacity(0.5))
            } else {
                Text(label.uppercased())
                    .font(.system(size: 7, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.5))
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(highlight ? BCColors.brandGreen : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(unit)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Ride Dashboard View

struct RideDashboardView: View {
    let session: RideSession
    let locationService: LocationService
    let altimeterService: AltimeterService

    @State private var showExpandedStats = false

    private var bearingToWaypoint: Double? {
        guard let loc = locationService.userLocation else { return nil }
        return session.bearingToNextWaypoint(from: loc)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar — route name + time + end button
            topBar

            // Main dashboard
            VStack(spacing: 12) {
                // Speed + Compass row
                HStack(spacing: 16) {
                    // Speed cluster (left)
                    VStack(spacing: 8) {
                        // Big current speed
                        VStack(spacing: 0) {
                            Text(locationService.formattedSpeed)
                                .font(.system(size: 44, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Text("MPH")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(2)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        // Avg / Max row
                        HStack(spacing: 16) {
                            VStack(spacing: 1) {
                                Text("AVG")
                                    .font(.system(size: 7, weight: .bold))
                                    .tracking(0.5)
                                    .foregroundColor(.white.opacity(0.4))
                                Text(locationService.formattedAvgSpeed)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            VStack(spacing: 1) {
                                Text("MAX")
                                    .font(.system(size: 7, weight: .bold))
                                    .tracking(0.5)
                                    .foregroundColor(.white.opacity(0.4))
                                Text(locationService.formattedMaxSpeed)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Compass (right)
                    CompassRingView(
                        heading: locationService.heading,
                        bearingToWaypoint: bearingToWaypoint,
                        headingAccuracy: locationService.headingAccuracy
                    )
                }
                .padding(.horizontal, 16)

                // Progress bar
                VStack(spacing: 4) {
                    ProgressView(value: session.progressPercent)
                        .tint(BCColors.brandGreen)
                    HStack {
                        Text(session.formattedDistance)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("\(session.formattedRemaining) remaining")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)

                // Stats grid — altimeter + session
                statsGrid

                // Off-route warning
                if session.isOffRoute {
                    offRouteWarning
                }
            }
            .padding(.vertical, 12)
            .background(.ultraThinMaterial.opacity(0.9))

            // Expandable detailed stats
            if showExpandedStats {
                expandedStats
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.route?.name ?? "Free Ride")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(session.formattedElapsedTime)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    showExpandedStats.toggle()
                }
            } label: {
                Image(systemName: showExpandedStats ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.5))
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 1) {
            // Fused altitude (GPS baseline + barometer)
            DashStatTile(
                label: "Elev",
                value: altimeterService.isAvailable
                    ? altimeterService.formattedBestAltitude.replacingOccurrences(of: " ft", with: "")
                    : "--",
                unit: "ft",
                icon: "mountain.2"
            )

            // Climb rate
            DashStatTile(
                label: "Climb",
                value: altimeterService.isAvailable
                    ? String(format: "%+.0f", altimeterService.climbRateFeetPerMin)
                    : "--",
                unit: "ft/m",
                icon: "chart.line.uptrend.xyaxis",
                highlight: altimeterService.climbRateFeetPerMin > 50
            )

            // Pressure
            DashStatTile(
                label: "Pressure",
                value: altimeterService.isAvailable
                    ? String(format: "%.0f", altimeterService.pressureHPa)
                    : "--",
                unit: "hPa",
                icon: "barometer"
            )

            // Elapsed
            DashStatTile(
                label: "Time",
                value: session.formattedElapsedTime,
                unit: "",
                icon: "clock"
            )
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Off-Route Warning

    private var offRouteWarning: some View {
        let isCritical = session.isCriticallyOffRoute
        let color: Color = isCritical ? .red : .orange
        return HStack(spacing: 8) {
            Image(systemName: isCritical ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(color)
            Text(isCritical
                 ? "Far off route — \(Int(session.distanceFromRouteMeters))m away"
                 : "Off route — \(Int(session.distanceFromRouteMeters))m away")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
    }

    // MARK: - Expanded Stats

    private var expandedStats: some View {
        VStack(spacing: 12) {
            HStack(spacing: 1) {
                DashStatTile(
                    label: "Moving",
                    value: session.formattedMovingTime,
                    unit: "",
                    icon: "figure.outdoor.cycle"
                )
                DashStatTile(
                    label: "Ascent",
                    value: String(format: "%.0f", altimeterService.totalAscentFeet),
                    unit: "ft",
                    icon: "arrow.up"
                )
                DashStatTile(
                    label: "Descent",
                    value: String(format: "%.0f", altimeterService.totalDescentFeet),
                    unit: "ft",
                    icon: "arrow.down"
                )
                DashStatTile(
                    label: "Alt Chg",
                    value: altimeterService.isAvailable
                        ? String(format: "%+.0f", altimeterService.relativeAltitudeFeet)
                        : "--",
                    unit: "ft",
                    icon: "arrow.up.and.down"
                )
            }

            if altimeterService.isAbsoluteAltitudeAvailable {
                HStack(spacing: 1) {
                    DashStatTile(
                        label: "Source",
                        value: altimeterService.altitudeSourceLabel,
                        unit: "",
                        icon: "sensor"
                    )
                    DashStatTile(
                        label: "Abs",
                        value: altimeterService.absoluteAltitudeFeet.map {
                            String(format: "%.0f", $0)
                        } ?? "--",
                        unit: "ft",
                        icon: "location.north.line"
                    )
                    DashStatTile(
                        label: "Accuracy",
                        value: altimeterService.formattedAbsoluteAccuracy,
                        unit: "",
                        icon: "scope"
                    )
                    DashStatTile(
                        label: "Precision",
                        value: altimeterService.formattedAbsolutePrecision,
                        unit: "",
                        icon: "gauge.with.dots.needle.bottom.50percent"
                    )
                }
            }

            // Emergency SOS row
            HStack(spacing: 12) {
                if EmergencySafetyService.shared.supportsSatelliteSOS {
                    HStack(spacing: 4) {
                        Image(systemName: "satellite.fill")
                            .font(.system(size: 9))
                        Text("Satellite SOS")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(.green)
                }

                Spacer()

                if let contact = EmergencySafetyService.shared.emergencyContact {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.shield.checkmark")
                            .font(.system(size: 9))
                        Text("ICE: \(contact.name)")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.6))
                }

                // SOS button
                if let smsURL = EmergencySafetyService.shared.emergencySMSURL {
                    Link(destination: smsURL) {
                        Text("SOS")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .clipShape(Rectangle())
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.9))
    }
}

#Preview {
    ZStack {
        Color.black
        VStack {
            Spacer()
            CompassRingView(
                heading: 45,
                bearingToWaypoint: 120,
                headingAccuracy: 10
            )
            Spacer()
        }
    }
}
