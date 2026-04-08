//
//  CommunityView.swift
//  StoneBC
//
//  Events, programs, toolkit, and about sections
//

import SwiftUI

struct CommunityView: View {
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
            Text("UPCOMING EVENTS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            ForEach(events) { event in
                EventCard(event: event)
            }
        }
    }

    // MARK: - Programs
    private var programsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OUR PROGRAMS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            ForEach(programs) { program in
                ProgramCard(program: program)
            }
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ABOUT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Stone Bicycle Coalition")
                    .font(.system(size: 16, weight: .medium))

                Text("Creating a replicable, open-source bicycle cooperative model that empowers communities to establish their own bike co-ops.")
                    .font(.system(size: 13, weight: .regular))
                    .lineSpacing(4)
                    .foregroundColor(.secondary)

                Divider()

                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 11))
                    Text("925 9th Street #3, Rapid City, SD 57701")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
            }
            .padding(BCSpacing.md)
            .background(BCColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Event Card
struct EventCard: View {
    let event: Event

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.categoryIcon)
                .font(.system(size: 18))
                .foregroundColor(BCColors.brandBlue)
                .frame(width: 36, height: 36)
                .background(BCColors.brandBlue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 14, weight: .medium))

                Text(event.date)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)

                if event.isRecurring {
                    Text("RECURRING")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundColor(BCColors.brandGreen)
                }
            }

            Spacer()
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    Image(systemName: program.icon)
                        .font(.system(size: 18))
                        .foregroundColor(BCColors.brandGreen)
                        .frame(width: 36, height: 36)
                        .background(BCColors.brandGreen.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(program.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
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
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        CommunityView()
    }
}
