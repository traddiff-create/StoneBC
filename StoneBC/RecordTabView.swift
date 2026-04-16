//
//  RecordTabView.swift
//  StoneBC
//
//  Landing screen for the Record tab. Big red CTA to start a fresh GPS
//  recording + a list of recent personal rides pulled from RideHistoryService.
//

import SwiftUI

struct RecordTabView: View {
    @State private var history = RideHistoryService.shared
    @State private var isRecording = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BCSpacing.lg) {
                    startRecordingButton
                        .padding(.top, BCSpacing.lg)

                    if !history.rides.isEmpty {
                        recentRidesSection
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, BCSpacing.md)
            }
            .navigationTitle("Record")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $isRecording) {
                RouteRecordingView()
            }
        }
    }

    // MARK: - Start button

    private var startRecordingButton: some View {
        Button {
            isRecording = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 32, weight: .bold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("START RECORDING")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(2)
                    Text("Capture a new ride or route")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, BCSpacing.lg)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color.red.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Recent rides

    private var recentRidesSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            Text("RECENT RIDES")
                .font(.bcSectionTitle)
                .tracking(1)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            LazyVStack(spacing: BCSpacing.sm) {
                ForEach(history.rides.prefix(20)) { ride in
                    rideRow(ride)
                }
            }
        }
    }

    private func rideRow(_ ride: CompletedRide) -> some View {
        HStack(spacing: BCSpacing.md) {
            Image(systemName: "bicycle")
                .font(.system(size: 18))
                .foregroundStyle(BCColors.categoryColor(ride.category))
                .frame(width: 36, height: 36)
                .background(BCColors.categoryColor(ride.category).opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(ride.routeName)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text("\(ride.formattedDistance) · \(ride.formattedTime) · \(ride.formattedDate)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: BCSpacing.sm) {
            Image(systemName: "dot.circle.and.cursorarrow")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("No recordings yet")
                .font(.system(size: 14, weight: .semibold))
            Text("Tap Start Recording to log your first ride.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, BCSpacing.xxl)
    }
}

#Preview {
    RecordTabView()
}
