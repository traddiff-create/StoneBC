//
//  CommunityView.swift
//  StoneBC
//
//  Events, programs, toolkit, and about sections
//

import SwiftUI

struct CommunityView: View {
    @Environment(AppState.self) private var appState
    @State private var events: [Event] = []
    @State private var programs: [Program] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BCSpacing.lg) {
                // Events Section
                eventsSection

                // Programs Section
                programsSection

                // About Section
                aboutSection
            }
            .padding(BCSpacing.md)
        }
        .background(BCColors.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("COMMUNITY")
                    .font(.bcSectionTitle)
                    .tracking(2)
            }
        }
        .task {
            events = Event.loadFromBundle()
            programs = Program.loadFromBundle()
        }
    }

    // MARK: - Events
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BCSectionHeader("UPCOMING EVENTS", icon: "calendar")

            ForEach(events) { event in
                EventCard(event: event)
            }
        }
    }

    // MARK: - Programs
    private var programsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BCSectionHeader("OUR PROGRAMS", icon: "wrench.and.screwdriver")

            ForEach(programs) { program in
                ProgramCard(program: program)
            }
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BCSectionHeader("ABOUT", icon: "info.circle")

            VStack(alignment: .leading, spacing: 8) {
                Text(appState.config.coalitionName)
                    .font(.system(size: 16, weight: .semibold))

                Text("Creating a replicable, open-source bicycle cooperative model that empowers communities to establish their own bike co-ops.")
                    .font(.system(size: 13, weight: .regular))
                    .lineSpacing(4)
                    .foregroundColor(.secondary)

                BCHairline()

                if let location = appState.config.location {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                        Text("\(location.address), \(location.city), \(location.state) \(location.zip)")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                }
            }
            .bcInstrumentCard()
        }
    }
}

// MARK: - Event Card
struct EventCard: View {
    let event: Event

    var body: some View {
        HStack(spacing: 12) {
            BCIconTile(icon: event.categoryIcon, color: BCColors.brandBlue, size: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))

                Text(event.date)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)

                if event.isRecurring {
                    BCStatusPill(text: "Recurring", color: BCColors.brandGreen)
                }
            }

            Spacer()
        }
        .bcInstrumentCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title). \(event.date). \(event.location)")
    }
}

// MARK: - Program Card
struct ProgramCard: View {
    let program: Program
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    BCIconTile(icon: program.icon, color: BCColors.brandGreen, size: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(program.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(BCColors.primaryText)
                        Text(program.description)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(BCColors.tertiaryText)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(program.details, id: \.self) { detail in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(BCColors.brandGreen)
                                .padding(.top, 2)
                            Text(detail)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.primary)
                        }
                    }

                    if let schedule = program.schedule {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(schedule)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    }
                }
                .padding(.leading, 48)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .bcInstrumentCard()
    }
}

#Preview {
    NavigationStack {
        CommunityView()
    }
    .environment(AppState())
}
