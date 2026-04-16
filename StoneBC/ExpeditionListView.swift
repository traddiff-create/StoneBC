//
//  ExpeditionListView.swift
//  StoneBC
//
//  Browse expedition journals, start new ones from tour guides.
//

import SwiftUI

struct ExpeditionListView: View {
    @Environment(AppState.self) var appState
    @State private var journals: [ExpeditionJournal] = []
    @State private var showNewExpedition = false

    var body: some View {
        VStack(spacing: 0) {
            if journals.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: BCSpacing.sm) {
                        ForEach(journals) { journal in
                            NavigationLink(destination: ExpeditionTimelineView(
                                journal: .constant(journal) // TODO: bind to storage
                            )) {
                                expeditionCard(journal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, BCSpacing.md)
                    .padding(.top, BCSpacing.sm)
                }
            }
        }
        .navigationTitle("Expeditions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewExpedition = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewExpedition) {
            NewExpeditionSheet(guides: appState.guides) { journal in
                journals.insert(journal, at: 0)
                appState.activeExpedition = journal
                Task {
                    await ExpeditionStorage.shared.save(journal)
                }
            }
        }
        .task {
            journals = await ExpeditionStorage.shared.listJournals()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "book.pages")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No Expeditions Yet")
                .font(.system(size: 16, weight: .medium))
            Text("Document your rides like Lewis & Clark.\nPhotos, audio, video, GPS — all in one journal.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showNewExpedition = true
            } label: {
                Text("START EXPEDITION")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(BCColors.brandBlue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
            Spacer()
        }
        .padding()
    }

    private func expeditionCard(_ journal: ExpeditionJournal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(journal.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                Text(journal.status.rawValue.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor(journal.status).opacity(0.15))
                    .foregroundColor(statusColor(journal.status))
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                Label("\(journal.days.count)d", systemImage: "calendar")
                Label("\(journal.totalPhotos)", systemImage: "photo")
                Label("\(journal.totalEntries)", systemImage: "note.text")
                if journal.pendingContributions > 0 {
                    Label("\(journal.pendingContributions)", systemImage: "tray.and.arrow.down")
                        .foregroundColor(.orange)
                }
            }
            .font(.system(size: 10))
            .foregroundColor(.secondary)

            Text(journal.startDate, style: .date)
                .font(.system(size: 10))
                .foregroundColor(BCColors.tertiaryText)
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusColor(_ status: JournalStatus) -> Color {
        switch status {
        case .active: BCColors.brandGreen
        case .completed: BCColors.brandBlue
        case .published: BCColors.brandAmber
        }
    }
}

// MARK: - New Expedition Sheet

struct NewExpeditionSheet: View {
    let guides: [TourGuide]
    let onCreate: (ExpeditionJournal) -> Void

    @State private var selectedGuide: TourGuide?
    private var selectedGuideId: String? { selectedGuide?.id }
    @State private var expeditionName = ""
    @State private var startDate = Date()
    @State private var leaderName = "Rory Stone"
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Tour Guide") {
                    ForEach(guides) { guide in
                        Button {
                            selectedGuide = guide
                            expeditionName = guide.name
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(guide.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("\(guide.totalDays) days · \(String(format: "%.0f", guide.totalMiles)) mi")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedGuideId == guide.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(BCColors.brandBlue)
                                }
                            }
                        }
                    }
                }

                Section("Details") {
                    TextField("Expedition Name", text: $expeditionName)
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    TextField("Leader Name", text: $leaderName)
                }
            }
            .navigationTitle("New Expedition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        guard let guide = selectedGuide else { return }
                        var journal = ExpeditionJournal.create(
                            from: guide,
                            leaderName: leaderName,
                            startDate: startDate
                        )
                        if !expeditionName.isEmpty {
                            // Use custom name
                            journal = ExpeditionJournal(
                                id: journal.id,
                                guideId: journal.guideId,
                                name: expeditionName,
                                leaderName: leaderName,
                                status: .active,
                                startDate: startDate,
                                endDate: nil,
                                days: journal.days,
                                contributions: [],
                                coverPhotoId: nil
                            )
                        }
                        onCreate(journal)
                        dismiss()
                    }
                    .disabled(selectedGuide == nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
