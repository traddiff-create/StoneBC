//
//  TourGuideDetailView.swift
//  StoneBC
//
//  Full tour guide with day picker, map, stops, and notes
//

import SwiftUI
import MapKit

struct TourGuideDetailView: View {
    let guide: TourGuide
    @State private var selectedDay: Int = 1

    private var currentDay: TourDay? {
        guide.days.first { $0.dayNumber == selectedDay }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BCSpacing.lg) {
                // Header
                headerSection

                // Day picker
                if guide.totalDays > 1 {
                    dayPicker
                }

                // Day detail
                if let day = currentDay {
                    dayOverview(day)

                    // gpx.studio interactive map
                    if let gpxURL = day.gpxURL {
                        GPXStudioMapView(
                            gpxURL: gpxURL,
                            centerLat: day.startCoordinate?.first ?? 44.05,
                            centerLon: day.startCoordinate?.last ?? -103.7
                        )
                        .frame(height: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    stopsTimeline(day)
                }

                // Ride recording checklist
                if let checklist = guide.checklist, !checklist.isEmpty {
                    RideChecklistView(guideId: guide.id, items: checklist)
                }

                // Pack list + Expedition journal
                VStack(spacing: BCSpacing.sm) {
                    NavigationLink(destination: PackingListView(tripId: guide.id)) {
                        HStack(spacing: 10) {
                            Image(systemName: "bag.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(BCColors.brandAmber)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pack List")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("Bikepacking gear checklist")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(BCSpacing.md)
                        .background(BCColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: ExpeditionListView()) {
                        HStack(spacing: 10) {
                            Image(systemName: "book.pages.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(BCColors.brandBlue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Expedition Journal")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("Document this ride like Lewis & Clark")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(BCSpacing.md)
                        .background(BCColors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                // Tour notes
                notesSection
            }
            .padding(BCSpacing.md)
        }
        .background(BCColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(guide.name.uppercased())
                    .font(.bcSectionTitle)
                    .tracking(2)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(guide.subtitle)
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Text(guide.description)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .lineSpacing(4)

            if let date = guide.eventDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(date)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(BCColors.brandBlue)
                .padding(.top, 4)
            }

            // Stats row
            HStack(spacing: 20) {
                guideStat(icon: "figure.outdoor.cycle", value: String(format: "%.0f mi", guide.totalMiles))
                guideStat(icon: "arrow.up.right", value: formatElevation(guide.totalElevation))
                guideStat(icon: "calendar.badge.clock", value: "\(guide.totalDays) day\(guide.totalDays > 1 ? "s" : "")")
                Spacer()
                Text(guide.difficulty.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(BCColors.difficultyColor(guide.difficulty))
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Day Picker

    private var dayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(guide.days) { day in
                    Button {
                        withAnimation { selectedDay = day.dayNumber }
                    } label: {
                        VStack(spacing: 4) {
                            Text("Day \(day.dayNumber)")
                                .font(.system(size: 11, weight: .semibold))
                            Text(day.name)
                                .font(.system(size: 10))
                                .lineLimit(1)
                            Text(String(format: "%.0f mi", day.totalMiles))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedDay == day.dayNumber ? BCColors.brandBlue : BCColors.cardBackground)
                        .foregroundColor(selectedDay == day.dayNumber ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Day Overview

    private func dayOverview(_ day: TourDay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DAY \(day.dayNumber)")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            Text(day.name)
                .font(.system(size: 16, weight: .semibold))

            HStack(spacing: 16) {
                if let time = day.startTime {
                    dayDetail(icon: "clock", text: time)
                }
                dayDetail(icon: "mappin", text: day.startLocation)
            }

            HStack(spacing: 16) {
                dayDetail(icon: "road.lanes", text: String(format: "%.1f mi", day.totalMiles))
                if day.elevationGain > 0 {
                    dayDetail(icon: "arrow.up.right", text: formatElevation(day.elevationGain))
                }
                if let duration = day.estimatedDuration {
                    dayDetail(icon: "timer", text: duration)
                }
            }

            if let finish = day.finishLocation {
                dayDetail(icon: "flag.checkered", text: "Finish: \(finish)")
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Stops Timeline

    private func stopsTimeline(_ day: TourDay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("STOPS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)
                .padding(.bottom, 12)

            ForEach(Array(day.stops.enumerated()), id: \.element.id) { index, stop in
                HStack(alignment: .top, spacing: 12) {
                    // Timeline
                    VStack(spacing: 0) {
                        Circle()
                            .fill(stopColor(stop.type))
                            .frame(width: 12, height: 12)
                        if index < day.stops.count - 1 {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(width: 12)

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(stop.name)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            if let mile = stop.mileMarker {
                                Text(String(format: "mi %.1f", mile))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }

                        if let desc = stop.description {
                            Text(desc)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        if let beer = stop.beer {
                            HStack(spacing: 4) {
                                Image(systemName: "mug")
                                    .font(.system(size: 9))
                                Text(beer)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    .padding(.bottom, index < day.stops.count - 1 ? 16 : 0)
                }
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOUR NOTES")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            ForEach(guide.notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(BCColors.brandBlue)
                        .padding(.top, 1)
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .lineSpacing(3)
                }
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func guideStat(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.primary)
    }

    private func dayDetail(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(BCColors.brandBlue)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.primary)
        }
    }

    private func stopColor(_ type: TourStop.StopType) -> Color {
        switch type {
        case .start: return .green
        case .finish: return .red
        case .sag: return .orange
        case .brewery: return .brown
        case .trailhead: return BCColors.brandGreen
        case .pointOfInterest: return BCColors.brandBlue
        }
    }

    private func formatElevation(_ feet: Int) -> String {
        if feet >= 1000 {
            return String(format: "%.1fk ft", Double(feet) / 1000)
        }
        return "\(feet) ft"
    }
}

extension TourGuide: Hashable {
    static func == (lhs: TourGuide, rhs: TourGuide) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
