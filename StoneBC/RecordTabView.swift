//
//  RecordTabView.swift
//  StoneBC
//
//  Landing screen for the Record tab. Big red CTA to start a fresh GPS
//  recording + a list of recent personal rides pulled from RideHistoryService.
//

import SwiftUI

struct RecordTabView: View {
    @Environment(AppState.self) private var appState
    @State private var history = RideHistoryService.shared
    @State private var isRecording = false
    @State private var selectedMode: RouteRecordingMode = .free
    @State private var selectedRoute: Route?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BCSpacing.lg) {
                    recordingModeSection

                    if selectedMode == .follow {
                        routePickerSection
                    }

                    startRecordingButton

                    if let lastRide = history.rides.first {
                        lastRidePeek(lastRide)
                    }
                }
                .padding(.horizontal, BCSpacing.md)
            }
            .background(BCColors.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("RECORD")
                        .font(.bcSectionTitle)
                        .tracking(2)
                }
            }
            .fullScreenCover(isPresented: $isRecording) {
                RouteRecordingView(route: selectedMode == .follow ? selectedRoute : nil, recordingMode: selectedMode)
            }
        }
    }

    private var recordingModeSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            BCSectionHeader("RECORDING MODE", icon: "slider.horizontal.3")

            ForEach(RouteRecordingMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 12) {
                        BCIconTile(
                            icon: mode.icon,
                            color: BCColors.brandBlue,
                            size: 38,
                            filled: selectedMode == mode
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.label)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(BCColors.primaryText)
                            Text(mode.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(BCColors.secondaryText)
                        }

                        Spacer()

                        if selectedMode == mode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(BCColors.brandGreen)
                        }
                    }
                    .bcInstrumentCard()
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedMode == mode ? .isSelected : [])
            }
        }
        .padding(.top, BCSpacing.lg)
    }

    private var routePickerSection: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            BCSectionHeader("FOLLOW ROUTE", icon: "point.topleft.down.curvedto.point.bottomright.up")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BCSpacing.sm) {
                    ForEach(appState.allRoutes.prefix(12)) { route in
                        Button {
                            selectedRoute = route
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(route.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(BCColors.primaryText)
                                    .lineLimit(2)
                                Text("\(route.formattedDistance) · \(route.difficulty)")
                                    .font(.bcCaption)
                                    .foregroundStyle(BCColors.secondaryText)
                                if selectedRoute?.id == route.id {
                                    Label("Selected", systemImage: "checkmark.circle.fill")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(BCColors.brandGreen)
                                }
                            }
                            .frame(width: 150, alignment: .leading)
                            .bcInstrumentCard()
                            .overlay {
                                RoundedRectangle(cornerRadius: BCRadius.card, style: .continuous)
                                    .stroke(
                                        selectedRoute?.id == route.id ? BCColors.brandBlue : Color.clear,
                                        lineWidth: 1.5
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Start button

    private var startRecordingButton: some View {
        Button {
            isRecording = true
        } label: {
            BCPrimaryAction(
                title: "Start Recording",
                subtitle: startSubtitle,
                icon: "record.circle.fill",
                color: BCColors.danger
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(selectedMode == .follow && selectedRoute == nil)
        .opacity(selectedMode == .follow && selectedRoute == nil ? 0.55 : 1)
    }

    private var startSubtitle: String {
        if selectedMode == .follow {
            return selectedRoute?.name ?? "Choose a route first"
        }
        return selectedMode.subtitle
    }

    // MARK: - Last ride peek

    private func lastRidePeek(_ ride: CompletedRide) -> some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            BCSectionHeader("LAST RIDE", icon: "clock.arrow.circlepath")

            HStack(spacing: BCSpacing.md) {
                BCIconTile(icon: "bicycle", color: BCColors.categoryColor(ride.category), size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ride.routeName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(BCColors.primaryText)
                        .lineLimit(1)
                    Text("\(ride.formattedDistance) · \(ride.formattedTime) · \(ride.formattedDate)")
                        .font(.bcCaption)
                        .foregroundStyle(BCColors.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(BCColors.tertiaryText)
            }
            .bcInstrumentCard()
        }
    }
}

#Preview {
    RecordTabView()
}
