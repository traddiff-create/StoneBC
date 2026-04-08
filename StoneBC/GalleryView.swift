//
//  GalleryView.swift
//  StoneBC
//
//  Photo gallery with category filters (Phase 3 - placeholder for Phase 1)
//

import SwiftUI

struct GalleryView: View {
    @State private var photos: [BCPhoto] = []
    @State private var selectedCategory: String?
    @State private var appeared = false

    private let columns = [
        GridItem(.flexible(), spacing: BCSpacing.sm),
        GridItem(.flexible(), spacing: BCSpacing.sm)
    ]

    private var filteredPhotos: [BCPhoto] {
        if let cat = selectedCategory {
            return photos.filter { $0.category == cat }
        }
        return photos
    }

    private var categories: [String] {
        Array(Set(photos.map { $0.category })).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BCSpacing.xs) {
                    FilterChip(title: "All", count: photos.count, isSelected: selectedCategory == nil) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = nil
                        }
                    }
                    ForEach(categories, id: \.self) { cat in
                        FilterChip(
                            title: cat.capitalized,
                            count: photos.filter { $0.category == cat }.count,
                            isSelected: selectedCategory == cat
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        }
                    }
                }
                .padding(.horizontal, BCSpacing.md)
                .padding(.vertical, 12)
            }
            .background(BCColors.background)

            // Photo grid
            ScrollView {
                if filteredPhotos.isEmpty {
                    VStack(spacing: BCSpacing.md) {
                        Spacer().frame(height: 80)
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("Photos coming soon")
                            .font(.bcPrimaryText)
                        Text("GALLERY IN DEVELOPMENT")
                            .font(.bcLabel)
                            .tracking(2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: columns, spacing: BCSpacing.sm) {
                        ForEach(Array(filteredPhotos.enumerated()), id: \.element.id) { index, photo in
                            PhotoPlaceholder(photo: photo)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.8)
                                    .delay(Double(min(index, 20)) * 0.02),
                                    value: appeared
                                )
                        }
                    }
                    .padding(.horizontal, BCSpacing.sm)
                    .padding(.top, BCSpacing.sm)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("GALLERY")
                        .font(.bcSectionTitle)
                        .tracking(2)
                    Text("\(filteredPhotos.count) photos")
                        .font(.bcMicro)
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            if photos.isEmpty {
                photos = BCPhoto.loadFromBundle()
            }
            try? await Task.sleep(for: .milliseconds(100))
            appeared = true
        }
    }
}

// MARK: - Photo Placeholder (until ImageCache is ported)
struct PhotoPlaceholder: View {
    let photo: BCPhoto

    var body: some View {
        Rectangle()
            .fill(BCColors.overlayMedium)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                    Text(photo.title)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .accessibilityLabel(photo.title)
    }
}

#Preview {
    NavigationStack {
        GalleryView()
    }
}
