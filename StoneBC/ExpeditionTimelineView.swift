//
//  ExpeditionTimelineView.swift
//  StoneBC
//
//  Post-ride expedition curation — day-by-day timeline with entries,
//  media gallery, day summaries, and contribution review.
//

import SwiftUI

struct ExpeditionTimelineView: View {
    @Binding var journal: ExpeditionJournal
    @State private var selectedDay: Int = 1
    @State private var showCapture = false
    @State private var showImportGPX = false
    @State private var showContributions = false
    @State private var editingSummary = false

    private var currentDay: JournalDay? {
        journal.days.first { $0.dayNumber == selectedDay }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Day picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BCSpacing.sm) {
                    ForEach(journal.days) { day in
                        Button {
                            withAnimation(.spring(response: 0.3)) { selectedDay = day.dayNumber }
                        } label: {
                            VStack(spacing: 4) {
                                Text("DAY \(day.dayNumber)")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1)
                                HStack(spacing: 4) {
                                    if day.photoCount > 0 {
                                        Label("\(day.photoCount)", systemImage: "photo")
                                            .font(.system(size: 8))
                                    }
                                    if day.audioCount > 0 {
                                        Label("\(day.audioCount)", systemImage: "mic")
                                            .font(.system(size: 8))
                                    }
                                }
                                .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedDay == day.dayNumber ? BCColors.brandBlue : BCColors.cardBackground)
                            .foregroundColor(selectedDay == day.dayNumber ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, BCSpacing.md)
                .padding(.vertical, 10)
            }

            // Day content
            if let day = currentDay {
                ScrollView {
                    VStack(alignment: .leading, spacing: BCSpacing.md) {
                        // Day stats
                        dayStatsBar(day)

                        // Summary editor
                        daySummarySection(day)

                        // Garmin GPX import
                        if day.gpxFilename == nil {
                            importGPXButton
                        } else {
                            gpxImportedBadge(day)
                        }

                        // Timeline entries
                        if day.sortedEntries.isEmpty {
                            emptyDayView
                        } else {
                            ForEach(day.sortedEntries) { entry in
                                EntryCard(entry: entry, journalId: journal.id, dayNumber: selectedDay)
                            }
                        }
                    }
                    .padding(.horizontal, BCSpacing.md)
                    .padding(.top, BCSpacing.sm)
                    .padding(.bottom, 80) // space for FAB
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // Floating action button
            Button {
                showCapture = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(BCColors.brandBlue)
                    .clipShape(Circle())
                    .shadow(radius: 4, y: 2)
            }
            .padding(BCSpacing.md)
        }
        .navigationTitle(journal.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showContributions = true
                    } label: {
                        Label("Contributions (\(journal.pendingContributions))", systemImage: "tray.and.arrow.down")
                    }

                    NavigationLink(destination: ExpeditionMapView(journal: journal)) {
                        Label("Map View", systemImage: "map")
                    }

                    if journal.status == .active {
                        Button {
                            journal.status = .completed
                        } label: {
                            Label("Mark Complete", systemImage: "checkmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showCapture) {
            ExpeditionCaptureView(
                journalId: journal.id,
                dayNumber: selectedDay,
                currentLocation: nil // wire to LocationService in integration
            ) { entry in
                if var day = journal.days.first(where: { $0.dayNumber == selectedDay }),
                   let idx = journal.days.firstIndex(where: { $0.dayNumber == selectedDay }) {
                    day.entries.append(entry)
                    journal.days[idx] = day
                }
            }
        }
    }

    // MARK: - Subviews

    private func dayStatsBar(_ day: JournalDay) -> some View {
        HStack(spacing: 16) {
            statPill(icon: "note.text", value: "\(day.entries.filter { $0.isTextOnly }.count)", label: "Notes")
            statPill(icon: "photo", value: "\(day.photoCount)", label: "Photos")
            statPill(icon: "mic", value: "\(day.audioCount)", label: "Audio")
            statPill(icon: "video", value: "\(day.videoCount)", label: "Video")
            Spacer()
            if let miles = day.actualMiles {
                statPill(icon: "road.lanes", value: String(format: "%.1f", miles), label: "Miles")
            }
        }
    }

    private func statPill(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    private func daySummarySection(_ day: JournalDay) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("DAY SUMMARY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)
                Spacer()
                Button(editingSummary ? "Done" : "Edit") {
                    editingSummary.toggle()
                }
                .font(.system(size: 11, weight: .medium))
            }

            if editingSummary {
                TextEditor(text: Binding(
                    get: { day.summary ?? "" },
                    set: { newValue in
                        if let idx = journal.days.firstIndex(where: { $0.dayNumber == selectedDay }) {
                            journal.days[idx].summary = newValue.isEmpty ? nil : newValue
                        }
                    }
                ))
                .font(.system(size: 13))
                .frame(minHeight: 80)
                .padding(8)
                .background(BCColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let summary = day.summary, !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .padding(BCSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BCColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("Tap Edit to write your day summary...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }

    private var importGPXButton: some View {
        Button {
            showImportGPX = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 14))
                    .foregroundColor(BCColors.brandBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Garmin GPX")
                        .font(.system(size: 12, weight: .medium))
                    Text("Load today's track from Garmin 810")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(BCSpacing.sm)
            .background(BCColors.brandBlue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func gpxImportedBadge(_ day: JournalDay) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(BCColors.brandGreen)
            Text("Garmin track imported")
                .font(.system(size: 11, weight: .medium))
            if let miles = day.actualMiles {
                Text("(\(String(format: "%.1f", miles)) mi)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(BCColors.brandGreen.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var emptyDayView: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Image(systemName: "doc.text.image")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No entries yet")
                .font(.system(size: 14, weight: .medium))
            Text("Tap + to log your first entry")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Entry Card

struct EntryCard: View {
    let entry: JournalEntry
    let journalId: String
    let dayNumber: Int

    private var mediaURL: URL? {
        guard let filename = entry.mediaFilename else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Expeditions/\(journalId)/media/day\(dayNumber)/\(filename)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timestamp + source
            HStack {
                Text(entry.timestamp, style: .time)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)

                if let coord = entry.coordinate {
                    Text(String(format: "%.3f, %.3f", coord[0], coord[1]))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(BCColors.tertiaryText)
                }

                Spacer()

                Text(entry.source.label)
                    .font(.system(size: 8, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(BCColors.brandBlue.opacity(0.1))
                    .foregroundColor(BCColors.brandBlue)
                    .clipShape(Capsule())

                if entry.isFeatured {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundColor(BCColors.brandAmber)
                }
            }

            // Photo
            if entry.mediaType == .photo, let url = mediaURL,
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Audio indicator
            if entry.mediaType == .audio {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 14))
                        .foregroundColor(BCColors.brandBlue)
                    Text("Voice memo")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(BCColors.brandBlue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Video indicator
            if entry.mediaType == .video {
                HStack(spacing: 6) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                    Text("Video clip")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.purple.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Text
            if let text = entry.text, !text.isEmpty {
                Text(text)
                    .font(.system(size: 13))
                    .lineSpacing(4)
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
