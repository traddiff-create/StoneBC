import SwiftUI
import MapKit

struct RideDetailView: View {
    let ride: CompletedRide
    @State private var history = RideHistoryService.shared
    @State private var timeTrial = TimeTrialService.shared
    @State private var journalService = RideJournalService.shared
    @State private var showShare = false
    @State private var showJournal = false
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BCSpacing.lg) {
                headerCard
                if let trackpoints = ride.gpxTrackpoints, trackpoints.count >= 2 {
                    mapSection(trackpoints: trackpoints)
                }
                statsGrid
                if ride.isTimeTrial { timeTrialSection }
                if ride.calories != nil || ride.heartRateAvg != nil { healthSection }
            }
            .padding(BCSpacing.md)
        }
        .background(BCColors.background)
        .navigationTitle(ride.routeName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showShare = true } label: {
                        Label("Share Ride", systemImage: "square.and.arrow.up")
                    }
                    Button { showJournal = true } label: {
                        Label(
                            journalService.journal(forRideId: ride.id) != nil ? "View Journal" : "Write Journal",
                            systemImage: "book"
                        )
                    }
                    Divider()
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete Ride", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showShare) {
            RideShareSheetView(ride: ride)
        }
        .sheet(isPresented: $showJournal) {
            NavigationStack {
                RideJournalDetailView(journal: journalForRide)
            }
        }
        .confirmationDialog("Delete this ride?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                history.deleteRide(ride)
                dismiss()
            }
        }
    }

    private var journalForRide: RideJournal {
        journalService.journal(forRideId: ride.id) ?? RideJournal(
            rideId: ride.id,
            routeName: ride.routeName,
            date: ride.completedAt,
            distanceMiles: ride.distanceMiles,
            elapsedSeconds: ride.elapsedSeconds
        )
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(ride.formattedDate)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text(ride.routeName)
                .font(.system(size: 20, weight: .bold))
            Text(ride.category)
                .font(.system(size: 12))
                .foregroundColor(BCColors.brandBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(BCColors.brandBlue.opacity(0.12))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            Text("STATS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCell(label: "Distance", value: ride.formattedDistance, icon: "arrow.left.and.right")
                statCell(label: "Time", value: ride.formattedTime, icon: "clock")
                statCell(label: "Avg Speed", value: String(format: "%.1f mph", ride.avgSpeedMPH), icon: "speedometer")
                statCell(label: "Max Speed", value: String(format: "%.1f mph", ride.maxSpeedMPH), icon: "gauge.with.needle")
                statCell(label: "Elevation", value: String(format: "%.0f ft", ride.elevationGainFeet), icon: "mountain.2")
                statCell(label: "Moving Time", value: formatTime(ride.movingSeconds), icon: "figure.outdoor.cycle")
            }
        }
    }

    private func statCell(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(BCColors.brandBlue)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var timeTrialSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            Text("TIME TRIAL")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                if let rank = timeTrial.rank(forRideId: ride.id, routeId: ride.routeId) {
                    HStack(spacing: 10) {
                        Image(systemName: rank == 1 ? "crown.fill" : "medal")
                            .font(.system(size: 20))
                            .foregroundColor(rank == 1 ? .yellow : BCColors.brandBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rank #\(rank)")
                                .font(.system(size: 16, weight: .bold))
                            if let preset = timeTrial.preset(forRouteId: ride.routeId) {
                                Text("\(preset.attempts.count) attempts on this route")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(BCSpacing.md)
            .background(BCColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            Text("HEALTH")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                if let calories = ride.calories {
                    statCell(label: "Calories", value: String(format: "%.0f kcal", calories), icon: "flame")
                }
                if let hr = ride.heartRateAvg {
                    statCell(label: "Avg Heart Rate", value: String(format: "%.0f bpm", hr), icon: "heart")
                }
            }
        }
    }

    private func mapSection(trackpoints: [[Double]]) -> some View {
        let coords = trackpoints.compactMap { pt -> CLLocationCoordinate2D? in
            guard pt.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pt[0], longitude: pt[1])
        }
        let lats = coords.map { $0.latitude }
        let lons = coords.map { $0.longitude }
        let center = CLLocationCoordinate2D(
            latitude: ((lats.min() ?? 0) + (lats.max() ?? 0)) / 2,
            longitude: ((lons.min() ?? 0) + (lons.max() ?? 0)) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(((lats.max() ?? 0) - (lats.min() ?? 0)) * 1.4, 0.005),
            longitudeDelta: max(((lons.max() ?? 0) - (lons.min() ?? 0)) * 1.4, 0.005)
        )
        let region = MKCoordinateRegion(center: center, span: span)

        return VStack(alignment: .leading, spacing: BCSpacing.sm) {
            Text("MAP")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            ZStack(alignment: .bottomTrailing) {
                Map(initialPosition: .region(region)) {
                    MapPolyline(coordinates: coords)
                        .stroke(BCColors.brandBlue, lineWidth: 3)
                    if let first = coords.first {
                        Annotation("", coordinate: first) {
                            Circle()
                                .fill(.green)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        }
                    }
                    if let last = coords.last, coords.count > 1 {
                        Annotation("", coordinate: last) {
                            Circle()
                                .fill(.red)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        }
                    }
                }
                .frame(height: 220)

                Button {
                    let placemark = MKPlacemark(coordinate: center)
                    let mapItem = MKMapItem(placemark: placemark)
                    mapItem.name = ride.routeName
                    mapItem.openInMaps(launchOptions: nil)
                } label: {
                    Label("Open in Maps", systemImage: "map")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
