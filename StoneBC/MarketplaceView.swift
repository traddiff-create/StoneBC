//
//  MarketplaceView.swift
//  StoneBC
//
//  Browse and filter refurbished bikes from The Quarry inventory
//

import SwiftUI

struct MarketplaceView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        @Bindable var state = appState

        NavigationStack {
            VStack(spacing: 0) {
                BikeFilterBar(
                    selectedStatus: $state.selectedBikeStatus,
                    selectedType: $state.selectedBikeType,
                    bikes: appState.availableBikes
                )

                if appState.filteredBikes.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(appState.filteredBikes) { bike in
                                NavigationLink(destination: BikeDetailView(bike: bike)) {
                                    BikeCardRow(bike: bike)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, BCSpacing.md)
                        .padding(.top, BCSpacing.sm)
                        .padding(.bottom, BCSpacing.xl)
                    }
                    .refreshable {
                        await appState.syncFromWordPress()
                    }
                }
            }
            .background(BCColors.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("THE QUARRY")
                            .font(.bcSectionTitle)
                            .tracking(2)
                        Text("\(appState.filteredBikes.count) bikes")
                            .font(.bcMicro)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: BCSpacing.md) {
            Spacer()
            Image(systemName: "bicycle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No bikes match your filters")
                .font(.bcPrimaryText)
                .foregroundColor(.secondary)
            Text("Try adjusting your selection")
                .font(.bcSecondaryText)
                .foregroundColor(BCColors.tertiaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MarketplaceView()
        .environment(AppState())
}
