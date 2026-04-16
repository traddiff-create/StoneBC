//
//  VolunteerFormView.swift
//  StoneBC
//
//  Time, Talent & Treasure volunteer signup form
//

import SwiftUI

struct VolunteerFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var selectedCategory: ContributionCategory = .time

    // Time
    @State private var timeOpenShop = false
    @State private var timeGroupRides = false
    @State private var timeEvents = false
    @State private var timeMechanic = false
    @State private var timeOther = false
    @State private var timeAvailability = ""

    // Talent
    @State private var talentMechanic = false
    @State private var talentTeaching = false
    @State private var talentMarketing = false
    @State private var talentPhotography = false
    @State private var talentGrantWriting = false
    @State private var talentOther = false
    @State private var talentDescription = ""

    // Treasure
    @State private var treasureBikes = false
    @State private var treasureParts = false
    @State private var treasureTools = false
    @State private var treasureMonetary = false
    @State private var treasureOther = false
    @State private var treasureDescription = ""

    @State private var notes = ""
    @State private var showConfirmation = false

    enum ContributionCategory: String, CaseIterable {
        case time = "Time"
        case talent = "Talent"
        case treasure = "Treasure"
    }

    var body: some View {
        NavigationStack {
            Form {
                // Category picker
                Section {
                    Picker("I'd like to contribute", selection: $selectedCategory) {
                        ForEach(ContributionCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("HOW CAN YOU HELP?")
                } footer: {
                    Text(categoryFooter)
                }

                // Category-specific fields
                switch selectedCategory {
                case .time:
                    timeSection
                case .talent:
                    talentSection
                case .treasure:
                    treasureSection
                }

                // Contact info
                Section("CONTACT INFO") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Phone (optional)", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                // Notes
                Section("ANYTHING ELSE?") {
                    TextField("Tell us more...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Submit
                Section {
                    Button(action: submitForm) {
                        HStack {
                            Spacer()
                            Text("Submit")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Volunteer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Thanks!", isPresented: $showConfirmation) {
                Button("Done") { dismiss() }
            } message: {
                Text("We'll be in touch soon. Thank you for volunteering with Stone Bicycle Coalition!")
            }
        }
    }

    // MARK: - Time Section

    private var timeSection: some View {
        Section("I CAN HELP WITH") {
            Toggle("Open Shop days", isOn: $timeOpenShop)
            Toggle("Group rides", isOn: $timeGroupRides)
            Toggle("Events & outreach", isOn: $timeEvents)
            Toggle("Bike mechanic work", isOn: $timeMechanic)
            Toggle("Other", isOn: $timeOther)

            TextField("When are you usually available?", text: $timeAvailability, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    // MARK: - Talent Section

    private var talentSection: some View {
        Section("SKILLS I CAN OFFER") {
            Toggle("Bike repair / mechanic", isOn: $talentMechanic)
            Toggle("Teaching / instruction", isOn: $talentTeaching)
            Toggle("Marketing / social media", isOn: $talentMarketing)
            Toggle("Photography / video", isOn: $talentPhotography)
            Toggle("Grant writing", isOn: $talentGrantWriting)
            Toggle("Other", isOn: $talentOther)

            if talentOther {
                TextField("Describe your skills", text: $talentDescription, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    // MARK: - Treasure Section

    private var treasureSection: some View {
        Section("I CAN DONATE") {
            Toggle("Bicycles", isOn: $treasureBikes)
            Toggle("Parts & accessories", isOn: $treasureParts)
            Toggle("Tools & equipment", isOn: $treasureTools)
            Toggle("Monetary donation", isOn: $treasureMonetary)
            Toggle("Other", isOn: $treasureOther)

            if treasureOther || treasureBikes {
                TextField("Tell us what you have", text: $treasureDescription, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    // MARK: - Helpers

    private var categoryFooter: String {
        switch selectedCategory {
        case .time:
            return "Volunteer your time at events, open shop, or group rides."
        case .talent:
            return "Share your professional skills to help us grow."
        case .treasure:
            return "Donate bikes, parts, tools, or funds."
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submitForm() {
        // Build mailto body
        var body = "Volunteer Signup — Stone Bicycle Coalition\n\n"
        body += "Name: \(name)\n"
        body += "Email: \(email)\n"
        if !phone.isEmpty { body += "Phone: \(phone)\n" }
        body += "Category: \(selectedCategory.rawValue)\n\n"

        switch selectedCategory {
        case .time:
            body += "Available for:\n"
            if timeOpenShop { body += "  - Open Shop days\n" }
            if timeGroupRides { body += "  - Group rides\n" }
            if timeEvents { body += "  - Events & outreach\n" }
            if timeMechanic { body += "  - Bike mechanic work\n" }
            if timeOther { body += "  - Other\n" }
            if !timeAvailability.isEmpty { body += "Availability: \(timeAvailability)\n" }
        case .talent:
            body += "Skills offered:\n"
            if talentMechanic { body += "  - Bike repair / mechanic\n" }
            if talentTeaching { body += "  - Teaching / instruction\n" }
            if talentMarketing { body += "  - Marketing / social media\n" }
            if talentPhotography { body += "  - Photography / video\n" }
            if talentGrantWriting { body += "  - Grant writing\n" }
            if talentOther { body += "  - Other: \(talentDescription)\n" }
        case .treasure:
            body += "Donations offered:\n"
            if treasureBikes { body += "  - Bicycles\n" }
            if treasureParts { body += "  - Parts & accessories\n" }
            if treasureTools { body += "  - Tools & equipment\n" }
            if treasureMonetary { body += "  - Monetary donation\n" }
            if treasureOther { body += "  - Other: \(treasureDescription)\n" }
        }

        if !notes.isEmpty { body += "\nNotes: \(notes)\n" }

        let subject = "Volunteer Signup: \(name) (\(selectedCategory.rawValue))"
        if let url = mailtoURL(subject: subject, body: body) {
            UIApplication.shared.open(url)
        }

        showConfirmation = true
    }

    private func mailtoURL(subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "info@stonebicyclecoalition.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}
