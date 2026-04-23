import SwiftUI
import MapKit
import Photos

enum ShareStat: String, CaseIterable, Identifiable {
    case distance, time, avgSpeed, maxSpeed, elevation

    var id: String { rawValue }
    var label: String {
        switch self {
        case .distance: "Distance"
        case .time: "Time"
        case .avgSpeed: "Avg Speed"
        case .maxSpeed: "Max Speed"
        case .elevation: "Elevation"
        }
    }
    var icon: String {
        switch self {
        case .distance: "arrow.left.and.right"
        case .time: "clock"
        case .avgSpeed: "speedometer"
        case .maxSpeed: "gauge.with.needle"
        case .elevation: "mountain.2"
        }
    }

    func value(for ride: CompletedRide) -> String {
        switch self {
        case .distance: ride.formattedDistance
        case .time: ride.formattedTime
        case .avgSpeed: String(format: "%.1f mph", ride.avgSpeedMPH)
        case .maxSpeed: String(format: "%.1f mph", ride.maxSpeedMPH)
        case .elevation: String(format: "%.0f ft", ride.elevationGainFeet)
        }
    }
}

struct RideShareSheetView: View {
    let ride: CompletedRide
    @State private var selectedStats: Set<ShareStat> = [.distance, .time, .elevation]
    @State private var showingShareSheet = false
    @State private var renderedImage: UIImage?
    @State private var mapSnapshot: UIImage?
    @State private var isSavingToPhotos = false
    @State private var photosSaveAlert: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: BCSpacing.lg) {
                cardPreview
                    .padding(.horizontal, BCSpacing.md)

                VStack(alignment: .leading, spacing: BCSpacing.sm) {
                    Text("CHOOSE STATS TO SHOW")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, BCSpacing.md)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ShareStat.allCases) { stat in
                                Toggle(isOn: Binding(
                                    get: { selectedStats.contains(stat) },
                                    set: { on in
                                        if on { selectedStats.insert(stat) }
                                        else { selectedStats.remove(stat) }
                                    }
                                )) {
                                    Label(stat.label, systemImage: stat.icon)
                                }
                                .toggleStyle(.button)
                                .tint(BCColors.brandBlue)
                                .font(.system(size: 13))
                            }
                        }
                        .padding(.horizontal, BCSpacing.md)
                    }
                }

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        renderAndShare()
                    } label: {
                        Label("Share Ride", systemImage: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(BCColors.brandBlue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        saveToPhotos()
                    } label: {
                        Label(isSavingToPhotos ? "Saving…" : "Save to Photos", systemImage: "photo.badge.plus")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(BCColors.cardBackground)
                            .foregroundColor(BCColors.brandBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isSavingToPhotos)
                }
                .padding(.horizontal, BCSpacing.md)
                .padding(.bottom, BCSpacing.md)
            }
            .background(BCColors.background)
            .navigationTitle("Share Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let img = renderedImage {
                    ShareSheet(activityItems: [img, shareText])
                }
            }
            .alert("Photos", isPresented: Binding(
                get: { photosSaveAlert != nil },
                set: { if !$0 { photosSaveAlert = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(photosSaveAlert ?? "")
            }
            .task {
                if let trackpoints = ride.gpxTrackpoints, trackpoints.count >= 2 {
                    mapSnapshot = await generateMapSnapshot(trackpoints: trackpoints)
                }
            }
        }
    }

    private var shareText: String {
        "Rode \(ride.routeName) — \(ride.formattedDistance) in \(ride.formattedTime). #StoneBC #CyclingLife"
    }

    @ViewBuilder
    private var cardPreview: some View {
        shareCardView
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    private var shareCardView: some View {
        ZStack(alignment: .bottomLeading) {
            backgroundLayer

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bicycle")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Stone Bicycle Coalition")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.85))

                    Text(ride.routeName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text(ride.formattedDate)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))

                    if !selectedStats.isEmpty {
                        Divider().background(Color.white.opacity(0.3))

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible()), count: min(selectedStats.count, 3)),
                            spacing: 12
                        ) {
                            ForEach(ShareStat.allCases.filter { selectedStats.contains($0) }) { stat in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stat.label.uppercased())
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.65))
                                    Text(stat.value(for: ride))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    if ride.elevationGainFeet > 0 {
                        let floors = Int(ride.elevationGainFeet / 10)
                        Text("Climbed \(floors) floors worth of elevation")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.65))
                            .italic()
                    }
                }
                .padding(16)
                .background(Color.black.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.91, contentMode: .fit)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let snapshot = mapSnapshot {
            Image(uiImage: snapshot)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [BCColors.brandBlue, BCColors.brandBlue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func renderAndShare() {
        let renderer = ImageRenderer(content: shareCardView.frame(width: 800, height: 418))
        renderer.scale = 2
        guard let image = renderer.uiImage else { return }
        renderedImage = image
        showingShareSheet = true
    }

    private func saveToPhotos() {
        let renderer = ImageRenderer(content: shareCardView.frame(width: 800, height: 418))
        renderer.scale = 2
        guard let image = renderer.uiImage else { return }

        isSavingToPhotos = true
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    isSavingToPhotos = false
                    photosSaveAlert = "Photos access is required. Enable it in Settings > Privacy > Photos."
                    return
                }
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                } completionHandler: { success, _ in
                    DispatchQueue.main.async {
                        isSavingToPhotos = false
                        photosSaveAlert = success ? "Ride card saved to Photos!" : "Couldn't save to Photos. Try again."
                    }
                }
            }
        }
    }

    private func generateMapSnapshot(trackpoints: [[Double]]) async -> UIImage? {
        let coords = trackpoints.compactMap { pt -> CLLocationCoordinate2D? in
            guard pt.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pt[0], longitude: pt[1])
        }
        guard coords.count >= 2 else { return nil }

        let lats = coords.map { $0.latitude }
        let lons = coords.map { $0.longitude }
        let center = CLLocationCoordinate2D(
            latitude: ((lats.min() ?? 0) + (lats.max() ?? 0)) / 2,
            longitude: ((lons.min() ?? 0) + (lons.max() ?? 0)) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(((lats.max() ?? 0) - (lats.min() ?? 0)) * 1.5, 0.005),
            longitudeDelta: max(((lons.max() ?? 0) - (lons.min() ?? 0)) * 1.5, 0.005)
        )
        let region = MKCoordinateRegion(center: center, span: span)

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: 800, height: 418)
        options.scale = 2
        options.mapType = .standard

        let snapshotter = MKMapSnapshotter(options: options)

        return await withCheckedContinuation { continuation in
            snapshotter.start { snapshot, _ in
                guard let snapshot else {
                    continuation.resume(returning: nil)
                    return
                }

                // Draw the route polyline onto the snapshot
                let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)
                let image = renderer.image { ctx in
                    snapshot.image.draw(at: .zero)

                    let path = UIBezierPath()
                    var isFirst = true
                    for coord in coords {
                        let point = snapshot.point(for: coord)
                        if isFirst {
                            path.move(to: point)
                            isFirst = false
                        } else {
                            path.addLine(to: point)
                        }
                    }

                    ctx.cgContext.setStrokeColor(UIColor(BCColors.brandBlue).cgColor)
                    ctx.cgContext.setLineWidth(4)
                    ctx.cgContext.setLineCap(.round)
                    ctx.cgContext.setLineJoin(.round)
                    path.stroke()

                    // Start dot (green)
                    if let first = coords.first {
                        let pt = snapshot.point(for: first)
                        let dotRect = CGRect(x: pt.x - 6, y: pt.y - 6, width: 12, height: 12)
                        ctx.cgContext.setFillColor(UIColor.systemGreen.cgColor)
                        ctx.cgContext.fillEllipse(in: dotRect)
                        ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
                        ctx.cgContext.setLineWidth(2)
                        ctx.cgContext.strokeEllipse(in: dotRect)
                    }

                    // End dot (red)
                    if let last = coords.last {
                        let pt = snapshot.point(for: last)
                        let dotRect = CGRect(x: pt.x - 6, y: pt.y - 6, width: 12, height: 12)
                        ctx.cgContext.setFillColor(UIColor.systemRed.cgColor)
                        ctx.cgContext.fillEllipse(in: dotRect)
                        ctx.cgContext.setStrokeColor(UIColor.white.cgColor)
                        ctx.cgContext.setLineWidth(2)
                        ctx.cgContext.strokeEllipse(in: dotRect)
                    }
                }

                continuation.resume(returning: image)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
