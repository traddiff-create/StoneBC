//
//  GPXImportView.swift
//  StoneBC
//
//  Import GPX files from Files app, preview route, and save to app
//

import SwiftUI
import MapKit
import UniformTypeIdentifiers

struct GPXImportView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    @State private var showFilePicker = false
    @State private var parsedResult: GPXResult?
    @State private var previewRoute: Route?
    @State private var selectedDifficulty = "moderate"
    @State private var selectedCategory = "gravel"
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BCSpacing.lg) {
                    if let route = previewRoute {
                        previewSection(route)
                    } else {
                        emptyState
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.bcSecondaryText)
                            .foregroundColor(.red)
                            .padding(BCSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(BCSpacing.md)
            }
            .background(BCColors.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("IMPORT ROUTE")
                        .font(.bcSectionTitle)
                        .tracking(2)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType.xml, UTType(filenameExtension: "gpx") ?? .xml],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: BCSpacing.lg) {
            Spacer().frame(height: 60)

            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundColor(BCColors.brandBlue.opacity(0.5))

            VStack(spacing: BCSpacing.sm) {
                Text("Import a GPX File")
                    .font(.bcPrimaryText)
                Text("Select a GPX file from your device to add it as a route")
                    .font(.bcSecondaryText)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showFilePicker = true
            } label: {
                Label("Select GPX File", systemImage: "folder")
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

    // MARK: - Preview Section

    private func previewSection(_ route: Route) -> some View {
        VStack(spacing: BCSpacing.md) {
            // Map preview
            Map {
                MapPolyline(coordinates: route.clTrackpoints)
                    .stroke(BCColors.brandBlue, lineWidth: 3)
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .allowsHitTesting(false)

            // Route info
            VStack(alignment: .leading, spacing: 12) {
                Text(route.name)
                    .font(.system(size: 20, weight: .semibold))

                HStack(spacing: 12) {
                    StatCard(icon: "arrow.left.arrow.right", label: "Distance", value: route.formattedDistance)
                    StatCard(icon: "arrow.up.right", label: "Elevation", value: route.formattedElevation)
                }

                HStack(spacing: 12) {
                    StatCard(icon: "point.topleft.down.to.point.bottomright.curvepath", label: "Trackpoints", value: "\(route.trackpoints.count)")
                    StatCard(icon: "mountain.2", label: "Elev Range", value: route.elevationRange)
                }
            }

            // Difficulty picker
            VStack(alignment: .leading, spacing: BCSpacing.sm) {
                Text("DIFFICULTY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BCSpacing.xs) {
                        ForEach(Route.allDifficulties, id: \.self) { diff in
                            FilterChip(title: diff.capitalized, isSelected: selectedDifficulty == diff) {
                                selectedDifficulty = diff
                            }
                        }
                    }
                }
            }

            // Category picker
            VStack(alignment: .leading, spacing: BCSpacing.sm) {
                Text("CATEGORY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: BCSpacing.xs) {
                        ForEach(Route.allCategories, id: \.self) { cat in
                            FilterChip(title: cat.capitalized, isSelected: selectedCategory == cat) {
                                selectedCategory = cat
                            }
                        }
                    }
                }
            }

            // Save button
            Button {
                saveRoute()
            } label: {
                Text("Add to Routes")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(BCColors.brandGreen)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(PressableButtonStyle())

            // Pick different file
            Button {
                parsedResult = nil
                previewRoute = nil
                errorMessage = nil
                showFilePicker = true
            } label: {
                Text("Choose Different File")
                    .font(.bcSecondaryText)
                    .foregroundColor(BCColors.brandBlue)
            }
        }
    }

    // MARK: - Actions

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        errorMessage = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Unable to access that file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                let gpxResult = try GPXService.parseGPX(data: data)
                parsedResult = gpxResult
                previewRoute = Route.fromGPX(
                    gpxResult,
                    difficulty: selectedDifficulty,
                    category: selectedCategory
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func saveRoute() {
        guard let result = parsedResult else { return }
        let route = Route.fromGPX(
            result,
            difficulty: selectedDifficulty,
            category: selectedCategory
        )
        appState.addImportedRoute(route)
        dismiss()
    }
}

#Preview {
    GPXImportView()
        .environment(AppState())
}
