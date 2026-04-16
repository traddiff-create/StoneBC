//
//  DonateFormView.swift
//  StoneBC
//
//  Donation form for bikes, parts, tools, or monetary support
//

import SwiftUI

struct DonateFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var donationType: DonationType = .bike

    // Bike donation
    @State private var bikeType = ""
    @State private var bikeCondition: BikeCondition = .rideable
    @State private var bikeDescription = ""

    // Parts / Tools
    @State private var itemDescription = ""

    // Monetary
    @State private var monetaryNotes = ""

    @State private var canDropOff = true
    @State private var notes = ""
    @State private var showConfirmation = false

    enum DonationType: String, CaseIterable {
        case bike = "Bicycle"
        case parts = "Parts & Tools"
        case monetary = "Monetary"
    }

    enum BikeCondition: String, CaseIterable {
        case rideable = "Rideable"
        case needsWork = "Needs Work"
        case partsOnly = "Parts Only"
    }

    var body: some View {
        NavigationStack {
            Form {
                // Donation type
                Section {
                    Picker("What would you like to donate?", selection: $donationType) {
                        ForEach(DonationType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("DONATION TYPE")
                } footer: {
                    Text(typeFooter)
                }

                // Type-specific fields
                switch donationType {
                case .bike:
                    bikeSection
                case .parts:
                    partsSection
                case .monetary:
                    monetarySection
                }

                // Logistics
                if donationType != .monetary {
                    Section("LOGISTICS") {
                        Toggle("I can drop off", isOn: $canDropOff)
                        if !canDropOff {
                            Text("We may be able to arrange pickup — mention your location in the notes.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
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
                    TextField("Additional details...", text: $notes, axis: .vertical)
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
            .navigationTitle("Donate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Thank You!", isPresented: $showConfirmation) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your generosity helps keep bikes rolling in Rapid City. We'll follow up soon!")
            }
        }
    }

    // MARK: - Bike Section

    private var bikeSection: some View {
        Section("ABOUT THE BIKE") {
            TextField("Bike type (e.g. mountain, road, kids)", text: $bikeType)

            Picker("Condition", selection: $bikeCondition) {
                ForEach(BikeCondition.allCases, id: \.self) { condition in
                    Text(condition.rawValue).tag(condition)
                }
            }

            TextField("Any other details (brand, size, etc.)", text: $bikeDescription, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    // MARK: - Parts Section

    private var partsSection: some View {
        Section("WHAT ARE YOU DONATING?") {
            TextField("Describe the parts, tools, or accessories", text: $itemDescription, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Monetary Section

    private var monetarySection: some View {
        Section {
            Text("We're a community bike co-op working toward 501(c)(3) status. Monetary donations help us keep bikes rolling for everyone.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            TextField("Any notes about your contribution", text: $monetaryNotes, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Text("MONETARY SUPPORT")
        }
    }

    // MARK: - Helpers

    private var typeFooter: String {
        switch donationType {
        case .bike:
            return "We accept bikes in any condition — rideable, fixable, or parts-only."
        case .parts:
            return "Tires, tubes, chains, tools, helmets, locks — everything helps."
        case .monetary:
            return "Funds go directly to bike repairs, youth programs, and community events."
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submitForm() {
        var body = "Donation Inquiry — Stone Bicycle Coalition\n\n"
        body += "Name: \(name)\n"
        body += "Email: \(email)\n"
        if !phone.isEmpty { body += "Phone: \(phone)\n" }
        body += "Donation Type: \(donationType.rawValue)\n\n"

        switch donationType {
        case .bike:
            if !bikeType.isEmpty { body += "Bike Type: \(bikeType)\n" }
            body += "Condition: \(bikeCondition.rawValue)\n"
            if !bikeDescription.isEmpty { body += "Details: \(bikeDescription)\n" }
            body += "Can drop off: \(canDropOff ? "Yes" : "No — needs pickup")\n"
        case .parts:
            if !itemDescription.isEmpty { body += "Items: \(itemDescription)\n" }
            body += "Can drop off: \(canDropOff ? "Yes" : "No — needs pickup")\n"
        case .monetary:
            if !monetaryNotes.isEmpty { body += "Notes: \(monetaryNotes)\n" }
        }

        if !notes.isEmpty { body += "\nAdditional Notes: \(notes)\n" }

        let subject = "Donation: \(name) (\(donationType.rawValue))"
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
