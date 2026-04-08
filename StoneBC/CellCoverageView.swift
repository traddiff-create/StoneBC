//
//  CellCoverageView.swift
//  StoneBC
//
//  Cell coverage reference for route planning — shows where riders will
//  likely lose signal based on FCC tower data and terrain.
//
//  Data: Bundled cell_towers.json with tower lat/lon/carrier for the
//  Black Hills & western SD region. Generated from FCC ASR + OpenCelliD.
//
//  Coverage estimation: Simple radius model (towers cover ~2-5mi in hills,
//  ~10mi on plains). Not perfect, but gives riders a heads-up.
//

import SwiftUI
import MapKit

// MARK: - Cell Tower Model

struct CellTower: Codable, Identifiable {
    let id: String
    let latitude: Double
    let longitude: Double
    let carrier: String      // "Verizon", "AT&T", "T-Mobile", "US Cellular", "Other"
    let estimatedRangeMiles: Double  // rough coverage radius

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Coverage Analysis

struct CoverageSegment: Identifiable {
    let id = UUID()
    let startIndex: Int
    let endIndex: Int
    let startMile: Double
    let endMile: Double
    let hasCoverage: Bool
    let nearestTowerDistance: Double // miles
}

enum CoverageAnalyzer {

    /// Analyze a route against known tower positions
    /// Returns segments of coverage / no-coverage along the route
    static func analyze(route: Route, towers: [CellTower], coverageThresholdMiles: Double = 5.0) -> [CoverageSegment] {
        let trackpoints = route.clTrackpoints
        guard trackpoints.count >= 2 else { return [] }

        var segments: [CoverageSegment] = []
        var currentHasCoverage = false
        var segmentStartIdx = 0
        var segmentStartMile: Double = 0
        var cumulativeDistance: Double = 0

        for i in 0..<trackpoints.count {
            // Calculate distance from this point to nearest tower
            let point = trackpoints[i]
            let nearestDist = nearestTowerDistance(from: point, towers: towers)
            let hasCoverage = nearestDist <= coverageThresholdMiles

            // Accumulate distance
            if i > 0 {
                let prev = CLLocation(latitude: trackpoints[i-1].latitude, longitude: trackpoints[i-1].longitude)
                let curr = CLLocation(latitude: point.latitude, longitude: point.longitude)
                cumulativeDistance += prev.distance(from: curr) / 1609.344 // meters to miles
            }

            // Detect segment change
            if i == 0 {
                currentHasCoverage = hasCoverage
            } else if hasCoverage != currentHasCoverage || i == trackpoints.count - 1 {
                segments.append(CoverageSegment(
                    startIndex: segmentStartIdx,
                    endIndex: i,
                    startMile: segmentStartMile,
                    endMile: cumulativeDistance,
                    hasCoverage: currentHasCoverage,
                    nearestTowerDistance: nearestDist
                ))
                segmentStartIdx = i
                segmentStartMile = cumulativeDistance
                currentHasCoverage = hasCoverage
            }
        }

        return segments
    }

    static func nearestTowerDistance(from coordinate: CLLocationCoordinate2D, towers: [CellTower]) -> Double {
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var minDist = Double.greatestFiniteMagnitude

        for tower in towers {
            let towerLoc = CLLocation(latitude: tower.latitude, longitude: tower.longitude)
            let dist = loc.distance(from: towerLoc) / 1609.344 // meters to miles
            if dist < minDist { minDist = dist }
        }

        return minDist
    }

    /// Summary stats for a route's coverage
    static func coverageSummary(segments: [CoverageSegment]) -> (coveredMiles: Double, deadMiles: Double, deadZoneCount: Int) {
        var covered: Double = 0
        var dead: Double = 0
        var deadCount = 0

        for seg in segments {
            let miles = seg.endMile - seg.startMile
            if seg.hasCoverage {
                covered += miles
            } else {
                dead += miles
                deadCount += 1
            }
        }

        return (covered, dead, deadCount)
    }
}

// MARK: - Cell Coverage View

struct CellCoverageView: View {
    let route: Route
    @State private var towers: [CellTower] = []
    @State private var segments: [CoverageSegment] = []
    @State private var showTowers = true
    @State private var selectedCarrier: String?

    private let carriers = ["All", "Verizon", "AT&T", "T-Mobile", "US Cellular"]

    private var filteredTowers: [CellTower] {
        guard let carrier = selectedCarrier, carrier != "All" else { return towers }
        return towers.filter { $0.carrier == carrier }
    }

    private var summary: (coveredMiles: Double, deadMiles: Double, deadZoneCount: Int) {
        CoverageAnalyzer.coverageSummary(segments: segments)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Coverage summary bar
            coverageSummaryBar

            // Map
            Map {
                // Route polyline — color-coded by coverage
                ForEach(segments) { segment in
                    let startIdx = segment.startIndex
                    let endIdx = min(segment.endIndex + 1, route.clTrackpoints.count)
                    let coords = Array(route.clTrackpoints[startIdx..<endIdx])

                    MapPolyline(coordinates: coords)
                        .stroke(
                            segment.hasCoverage ? Color.green : Color.red,
                            lineWidth: 4
                        )
                }

                // Cell towers
                if showTowers {
                    ForEach(filteredTowers) { tower in
                        Annotation(tower.carrier, coordinate: tower.coordinate) {
                            TowerPin(carrier: tower.carrier)
                        }
                    }
                }

                // Route start/end
                if let first = route.clTrackpoints.first {
                    Annotation("Start", coordinate: first) {
                        Circle()
                            .fill(.green)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
                if let last = route.clTrackpoints.last, route.clTrackpoints.count > 1 {
                    Annotation("End", coordinate: last) {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))

            // Bottom controls
            VStack(spacing: 12) {
                // Carrier filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(carriers, id: \.self) { carrier in
                            FilterChip(
                                title: carrier,
                                isSelected: (selectedCarrier ?? "All") == carrier
                            ) {
                                selectedCarrier = carrier == "All" ? nil : carrier
                            }
                        }

                        Toggle(isOn: $showTowers) {
                            Text("Towers")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, BCSpacing.md)
                }

                // Dead zone warnings
                if summary.deadZoneCount > 0 {
                    deadZoneList
                }
            }
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("CELL COVERAGE")
                    .font(.bcSectionTitle)
                    .tracking(2)
            }
        }
        .task {
            towers = CellTower.loadFromBundle()
            segments = CoverageAnalyzer.analyze(route: route, towers: towers)
        }
    }

    // MARK: - Coverage Summary

    private var coverageSummaryBar: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("COVERED")
                    .font(.system(size: 7, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f mi", summary.coveredMiles))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
            }

            VStack(spacing: 2) {
                Text("DEAD ZONES")
                    .font(.system(size: 7, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.secondary)
                Text(String(format: "%.0f mi", summary.deadMiles))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)
            }

            // Coverage bar
            GeometryReader { geo in
                let totalMiles = summary.coveredMiles + summary.deadMiles
                let coveragePercent = totalMiles > 0 ? summary.coveredMiles / totalMiles : 1.0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red.opacity(0.3))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: geo.size.width * coveragePercent)
                }
                .frame(height: 8)
                .frame(maxHeight: .infinity, alignment: .center)
            }

            Text(String(format: "%.0f%%", (summary.coveredMiles / max(summary.coveredMiles + summary.deadMiles, 1)) * 100))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, BCSpacing.md)
        .padding(.vertical, 10)
        .background(BCColors.cardBackground)
    }

    // MARK: - Dead Zone List

    private var deadZoneList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DEAD ZONES")
                .font(.system(size: 8, weight: .bold))
                .tracking(1)
                .foregroundColor(.secondary)
                .padding(.horizontal, BCSpacing.md)

            ForEach(segments.filter { !$0.hasCoverage }) { segment in
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    Text(String(format: "Mile %.0f – %.0f", segment.startMile, segment.endMile))
                        .font(.system(size: 12, weight: .medium))
                    Text(String(format: "(%.1f mi)", segment.endMile - segment.startMile))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, BCSpacing.md)
            }
        }
    }
}

// MARK: - Tower Pin

struct TowerPin: View {
    let carrier: String

    private var color: Color {
        switch carrier {
        case "Verizon": return .red
        case "AT&T": return .blue
        case "T-Mobile": return .pink
        case "US Cellular": return .green
        default: return .gray
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 24, height: 24)
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Bundle Loading

extension CellTower {
    static func loadFromBundle() -> [CellTower] {
        guard let url = Bundle.main.url(forResource: "cell_towers", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([CellTower].self, from: data)) ?? []
    }
}
