//
//  GPXImportView.swift
//  StoneBC
//

import MapKit
import SwiftUI
import UniformTypeIdentifiers

struct GPXImportView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    @State private var showFilePicker = false
    @State private var candidates: [RouteImportCandidate] = []
    @State private var failures: [RouteImportFailure] = []
    @State private var importedIds: Set<String> = []
    @State private var saveMessage: String?

    private let allowedTypes: [UTType] = [
        UTType(filenameExtension: "gpx") ?? .xml,
        UTType(filenameExtension: "tcx") ?? .xml,
        UTType(filenameExtension: "fit") ?? .data,
        UTType(filenameExtension: "kml") ?? .xml,
        UTType(filenameExtension: "kmz") ?? .zip,
        .zip,
        .xml,
        .data
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BCSpacing.lg) {
                    if candidates.isEmpty && failures.isEmpty {
                        emptyState
                    } else {
                        importSummary
                        ForEach(candidates) { candidate in
                            candidateCard(candidate)
                        }
                        ForEach(failures) { failure in
                            failureCard(failure)
                        }
                    }
                }
                .padding(BCSpacing.md)
            }
            .background(BCColors.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("IMPORT ROUTE OR RIDE")
                        .font(.bcSectionTitle)
                        .tracking(2)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFilePicker = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .accessibilityLabel("Choose route files")
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: allowedTypes,
                allowsMultipleSelection: true
            ) { result in
                handleFileSelection(result)
            }
            .alert("Import", isPresented: Binding(
                get: { saveMessage != nil },
                set: { if !$0 { saveMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveMessage ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: BCSpacing.lg) {
            Spacer().frame(height: 60)

            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                .font(.system(size: 48))
                .foregroundColor(BCColors.brandBlue.opacity(0.55))

            VStack(spacing: BCSpacing.sm) {
                Text("Import Route or Ride")
                    .font(.bcPrimaryText)
                Text("GPX, TCX, FIT, KML, KMZ, and ZIP bundles")
                    .font(.bcSecondaryText)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showFilePicker = true
            } label: {
                Label("Select Files", systemImage: "folder")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(BCColors.brandBlue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle())
        }
        .frame(maxWidth: .infinity)
    }

    private var importSummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(candidates.count) ready")
                    .font(.system(size: 16, weight: .semibold))
                Text("\(failures.count) issue\(failures.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Choose More") {
                showFilePicker = true
            }
            .font(.system(size: 13, weight: .medium))
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func candidateCard(_ candidate: RouteImportCandidate) -> some View {
        VStack(alignment: .leading, spacing: BCSpacing.md) {
            candidateMap(candidate)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(candidate.name)
                            .font(.system(size: 18, weight: .semibold))
                            .lineLimit(2)
                        Text(candidate.sourceFilename)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(candidate.assetKind.displayName.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                        Text(candidate.sourceFormat.displayName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(BCColors.brandBlue)
                    }
                }

                HStack(spacing: 8) {
                    miniStat("Distance", String(format: "%.1f mi", candidate.distanceMiles))
                    miniStat("Elev", "\(candidate.elevationGainFeet) ft")
                    miniStat("Points", "\(candidate.trackpoints.count)")
                    miniStat("Cues", "\(candidate.coursePoints.count)")
                }
            }

            HStack(spacing: 10) {
                if candidate.assetKind == .completedRide {
                    Button {
                        saveRide(candidate)
                    } label: {
                        Label(importedIds.contains("ride-\(candidate.id)") ? "Saved Ride" : "Save Ride", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(importedIds.contains("ride-\(candidate.id)"))
                    .buttonStyle(ImportButtonStyle(color: BCColors.brandGreen))

                    Button {
                        saveRoute(candidate)
                    } label: {
                        Label(importedIds.contains("route-\(candidate.id)") ? "Saved Route" : "Save as Route", systemImage: "map")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(importedIds.contains("route-\(candidate.id)"))
                    .buttonStyle(ImportButtonStyle(color: BCColors.brandBlue))
                } else {
                    Button {
                        saveRoute(candidate)
                    } label: {
                        Label(importedIds.contains("route-\(candidate.id)") ? "Added" : "Add to Routes", systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(importedIds.contains("route-\(candidate.id)"))
                    .buttonStyle(ImportButtonStyle(color: BCColors.brandGreen))
                }
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func failureCard(_ failure: RouteImportFailure) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(failure.filename, systemImage: "exclamationmark.triangle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(BCColors.navAlertRed)
            Text(failure.message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BCSpacing.md)
        .background(BCColors.navAlertRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func candidateMap(_ candidate: RouteImportCandidate) -> some View {
        let coords = candidate.trackpoints.map(\.coordinate)
        let region = region(for: coords)

        return Map(initialPosition: .region(region)) {
            MapPolyline(coordinates: coords)
                .stroke(BCColors.brandBlue, lineWidth: 3)
            if let first = coords.first {
                Annotation("", coordinate: first) {
                    Circle().fill(.green).frame(width: 10, height: 10)
                }
            }
            if let last = coords.last {
                Annotation("", coordinate: last) {
                    Circle().fill(.red).frame(width: 10, height: 10)
                }
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .allowsHitTesting(false)
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(BCColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var accessibleURLs: [URL] = []
            for url in urls {
                if url.startAccessingSecurityScopedResource() {
                    accessibleURLs.append(url)
                } else {
                    failures.append(RouteImportFailure(filename: url.lastPathComponent, message: "Unable to access that file."))
                }
            }
            defer {
                accessibleURLs.forEach { $0.stopAccessingSecurityScopedResource() }
            }
            let batch = RouteInterchangeService.importFiles(accessibleURLs)
            candidates.append(contentsOf: batch.candidates)
            failures.append(contentsOf: batch.failures)
        case .failure(let error):
            failures.append(RouteImportFailure(filename: "Files", message: error.localizedDescription))
        }
    }

    private func saveRoute(_ candidate: RouteImportCandidate) {
        appState.addImportedRoute(candidate.route)
        importedIds.insert("route-\(candidate.id)")
        saveMessage = "\(candidate.name) added to Routes."
    }

    private func saveRide(_ candidate: RouteImportCandidate) {
        RideHistoryService.shared.importRide(candidate.completedRide)
        importedIds.insert("ride-\(candidate.id)")
        saveMessage = "\(candidate.name) saved to ride history."
    }

    private func region(for coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coords.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 44.0805, longitude: -103.2310),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: ((lats.min() ?? 0) + (lats.max() ?? 0)) / 2,
            longitude: ((lons.min() ?? 0) + (lons.max() ?? 0)) / 2
        )
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: max(((lats.max() ?? 0) - (lats.min() ?? 0)) * 1.4, 0.01),
                longitudeDelta: max(((lons.max() ?? 0) - (lons.min() ?? 0)) * 1.4, 0.01)
            )
        )
    }
}

private struct ImportButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.vertical, 12)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    GPXImportView()
        .environment(AppState())
}
