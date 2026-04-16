//
//  ExpeditionMapView.swift
//  StoneBC
//
//  Interactive map with GPS track overlay and media pins.
//  Blue pins = Rory, green = contributions, amber = featured.
//

import SwiftUI
import MapKit

struct ExpeditionMapView: View {
    let journal: ExpeditionJournal
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedEntry: JournalEntry?
    @State private var selectedDay: Int?

    private var allEntries: [JournalEntry] {
        let days = selectedDay.map { d in journal.days.filter { $0.dayNumber == d } } ?? journal.days
        return days.flatMap { $0.sortedEntries }.filter { $0.coordinate != nil }
    }

    private var trackpoints: [CLLocationCoordinate2D] {
        let days = selectedDay.map { d in journal.days.filter { $0.dayNumber == d } } ?? journal.days
        return days.flatMap { day in
            (day.gpxTrackpoints ?? []).compactMap { pt in
                guard pt.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: pt[0], longitude: pt[1])
            }
        }
    }

    var body: some View {
        ZStack {
            Map(position: $position) {
                // GPS track polyline
                if trackpoints.count >= 2 {
                    MapPolyline(coordinates: trackpoints)
                        .stroke(BCColors.brandBlue, lineWidth: 3)
                }

                // Media pins
                ForEach(allEntries) { entry in
                    if let coord = entry.clCoordinate {
                        Annotation(
                            entry.text?.prefix(20).description ?? entry.mediaType?.rawValue ?? "Entry",
                            coordinate: coord
                        ) {
                            mediaPinView(for: entry)
                                .onTapGesture {
                                    selectedEntry = entry
                                }
                        }
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))

            // Day filter chips
            VStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        dayFilterChip(label: "All Days", day: nil)
                        ForEach(journal.days) { day in
                            dayFilterChip(label: "Day \(day.dayNumber)", day: day.dayNumber)
                        }
                    }
                    .padding(.horizontal, BCSpacing.md)
                    .padding(.vertical, 8)
                }
                .background(.ultraThinMaterial)

                Spacer()

                // Stats bar
                HStack(spacing: 16) {
                    Label("\(allEntries.filter { $0.mediaType == .photo }.count) photos", systemImage: "photo")
                    Label("\(allEntries.filter { $0.mediaType == .audio }.count) audio", systemImage: "mic")
                    Spacer()
                    Label("\(allEntries.count) pins", systemImage: "mappin")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, BCSpacing.md)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Expedition Map")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedEntry) { entry in
            entryDetailSheet(entry)
        }
    }

    // MARK: - Pin Views

    private func mediaPinView(for entry: JournalEntry) -> some View {
        let color: Color = entry.isFeatured ? BCColors.brandAmber :
            entry.source == .contribution ? .green : BCColors.brandBlue

        let icon: String = switch entry.mediaType {
        case .photo: "camera.fill"
        case .audio: "mic.fill"
        case .video: "video.fill"
        case .none: "note.text"
        }

        return Image(systemName: icon)
            .font(.system(size: 10))
            .foregroundColor(.white)
            .padding(6)
            .background(color)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
            .shadow(radius: 2)
    }

    private func dayFilterChip(label: String, day: Int?) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { selectedDay = day }
        } label: {
            Text(label)
                .font(.system(size: 10, weight: selectedDay == day ? .bold : .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selectedDay == day ? BCColors.brandBlue : BCColors.cardBackground)
                .foregroundColor(selectedDay == day ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Entry Detail

    private func entryDetailSheet(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(entry.timestamp, style: .date)
                    .font(.system(size: 12, weight: .medium))
                Text(entry.timestamp, style: .time)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text(entry.source.label)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(BCColors.brandBlue.opacity(0.1))
                    .clipShape(Capsule())
            }

            if let text = entry.text {
                Text(text)
                    .font(.system(size: 14))
                    .lineSpacing(4)
            }

            if let coord = entry.coordinate {
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.system(size: 10))
                    Text(String(format: "%.5f, %.5f", coord[0], coord[1]))
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .presentationDetents([.medium])
    }
}
