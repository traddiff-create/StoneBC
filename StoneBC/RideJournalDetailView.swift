import SwiftUI

struct RideJournalDetailView: View {
    @State private var journal: RideJournal
    @State private var section = 0
    @State private var showMomentEntry = false
    @State private var momentNote = ""
    @State private var momentMood: RideMood?
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    init(journal: RideJournal) {
        _journal = State(initialValue: journal)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: BCSpacing.lg) {
                moodPicker
                sectionPicker

                switch section {
                case 0: preRideSection
                case 1: momentsSection
                default: reflectionSection
                }
            }
            .padding(BCSpacing.md)
        }
        .background(BCColors.background)
        .navigationTitle(journal.routeName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        journal.isFavorite.toggle()
                        save()
                    } label: {
                        Label(
                            journal.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                            systemImage: journal.isFavorite ? "heart.fill" : "heart"
                        )
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Journal", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onChange(of: journal) { _, newVal in
            RideJournalService.shared.save(newVal)
        }
        .confirmationDialog("Delete this journal?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                RideJournalService.shared.delete(journal)
                dismiss()
            }
        }
        .sheet(isPresented: $showMomentEntry) {
            momentEntrySheet
        }
        .onAppear {
            save()
        }
    }

    // MARK: - Mood Picker

    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOW ARE YOU FEELING?")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RideMood.allCases, id: \.self) { mood in
                        Button {
                            journal.mood = journal.mood == mood ? nil : mood
                        } label: {
                            VStack(spacing: 2) {
                                Text(mood.emoji)
                                    .font(.system(size: 20))
                                Text(mood.label)
                                    .font(.system(size: 9))
                                    .foregroundColor(journal.mood == mood ? BCColors.brandBlue : .secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(journal.mood == mood ? BCColors.brandBlue.opacity(0.12) : BCColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(journal.mood == mood ? BCColors.brandBlue : Color.clear, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        Picker("Section", selection: $section) {
            Text("Pre-Ride").tag(0)
            Text("Moments").tag(1)
            Text("Reflection").tag(2)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Pre-Ride

    private var preRideSection: some View {
        VStack(spacing: BCSpacing.md) {
            if let miles = journal.distanceMiles, let secs = journal.elapsedSeconds {
                rideStatsCard(miles: miles, secs: secs)
            }

            promptCard(
                title: "INTENTIONS",
                prompt: "What am I riding for today?",
                text: Binding(
                    get: { journal.intentions ?? "" },
                    set: { journal.intentions = $0.isEmpty ? nil : $0 }
                )
            )

            promptCard(
                title: "CONDITIONS",
                prompt: "Weather, road, how I feel...",
                text: Binding(
                    get: { journal.conditions ?? "" },
                    set: { journal.conditions = $0.isEmpty ? nil : $0 }
                )
            )

            effortSlider
        }
    }

    private func rideStatsCard(miles: Double, secs: Double) -> some View {
        HStack(spacing: 20) {
            statPair(label: "Distance", value: String(format: "%.1f mi", miles))
            Divider().frame(height: 30)
            statPair(label: "Time", value: formatTime(secs))
        }
        .frame(maxWidth: .infinity)
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statPair(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .bold))
            Text(label).font(.system(size: 11)).foregroundColor(.secondary)
        }
    }

    private var effortSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EFFORT")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(journal.effortRating ?? 5)/10")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(BCColors.brandBlue)
            }
            Slider(
                value: Binding(
                    get: { Double(journal.effortRating ?? 5) },
                    set: { journal.effortRating = Int($0) }
                ),
                in: 1...10,
                step: 1
            )
            .tint(BCColors.brandBlue)
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Moments

    private var momentsSection: some View {
        VStack(spacing: BCSpacing.sm) {
            Button {
                momentNote = ""
                momentMood = nil
                showMomentEntry = true
            } label: {
                Label("Add Moment", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(BCColors.brandBlue.opacity(0.1))
                    .foregroundColor(BCColors.brandBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            if journal.rideEntries.isEmpty {
                Text("No moments yet — add notes during your ride")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, BCSpacing.lg)
            } else {
                ForEach(journal.rideEntries) { moment in
                    momentCard(moment)
                }
            }
        }
    }

    private func momentCard(_ moment: RideMoment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let mood = moment.mood {
                Text(mood.emoji).font(.system(size: 20))
            } else {
                Image(systemName: "note.text")
                    .font(.system(size: 14))
                    .foregroundColor(BCColors.brandBlue)
                    .frame(width: 24)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(moment.note)
                    .font(.system(size: 14))
                Text(moment.timestamp, style: .time)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var momentEntrySheet: some View {
        NavigationStack {
            VStack(spacing: BCSpacing.md) {
                TextEditor(text: $momentNote)
                    .frame(height: 100)
                    .padding(8)
                    .background(BCColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(RideMood.allCases, id: \.self) { mood in
                            Button {
                                momentMood = momentMood == mood ? nil : mood
                            } label: {
                                Text("\(mood.emoji) \(mood.label)")
                                    .font(.system(size: 13))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(momentMood == mood ? BCColors.brandBlue.opacity(0.15) : BCColors.cardBackground)
                                    .foregroundColor(momentMood == mood ? BCColors.brandBlue : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Spacer()
            }
            .padding(BCSpacing.md)
            .background(BCColors.background)
            .navigationTitle("Add Moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showMomentEntry = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !momentNote.isEmpty else { return }
                        journal.rideEntries.insert(RideMoment(note: momentNote, mood: momentMood), at: 0)
                        showMomentEntry = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Reflection

    private var reflectionSection: some View {
        VStack(spacing: BCSpacing.md) {
            promptCard(
                title: "HOW IT WENT",
                prompt: "How was the ride?",
                text: Binding(
                    get: { journal.reflection ?? "" },
                    set: { journal.reflection = $0.isEmpty ? nil : $0 }
                )
            )
            promptCard(
                title: "ACHIEVEMENTS",
                prompt: "What did you accomplish?",
                text: Binding(
                    get: { journal.achievements ?? "" },
                    set: { journal.achievements = $0.isEmpty ? nil : $0 }
                )
            )
            promptCard(
                title: "NEXT GOAL",
                prompt: "What's next?",
                text: Binding(
                    get: { journal.nextGoal ?? "" },
                    set: { journal.nextGoal = $0.isEmpty ? nil : $0 }
                )
            )
        }
    }

    // MARK: - Helpers

    private func promptCard(title: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            TextEditor(text: text)
                .frame(minHeight: 80)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if text.wrappedValue.isEmpty {
                        Text(prompt)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
                .padding(8)
                .background(BCColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func save() {
        RideJournalService.shared.save(journal)
    }
}
