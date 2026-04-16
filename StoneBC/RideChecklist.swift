//
//  RideChecklist.swift
//  StoneBC
//
//  Ride recording checklist for building better tour guides
//

import SwiftUI

struct ChecklistItem: Codable, Identifiable {
    var id: String { key }
    let key: String
    let category: String          // "capture", "note", "safety"
    let title: String
    let description: String
    let mileEstimate: Double?     // approximate mile marker
}

struct RideChecklistView: View {
    let guideId: String
    let items: [ChecklistItem]
    @State private var completed: Set<String> = []

    private let storageKey: String

    init(guideId: String, items: [ChecklistItem]) {
        self.guideId = guideId
        self.items = items
        self.storageKey = "checklist-\(guideId)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RIDE RECORDING CHECKLIST")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(completed.count)/\(items.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(BCColors.brandBlue)
            }

            ForEach(groupedItems, id: \.key) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.key.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundColor(categoryColor(group.key))
                        .padding(.top, 4)

                    ForEach(group.items) { item in
                        Button { toggle(item.key) } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: completed.contains(item.key) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(completed.contains(item.key) ? .green : .secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(item.title)
                                            .font(.system(size: 13, weight: .medium))
                                            .strikethrough(completed.contains(item.key))
                                            .foregroundColor(completed.contains(item.key) ? .secondary : .primary)
                                        if let mile = item.mileEstimate {
                                            Spacer()
                                            Text("~mi \(Int(mile))")
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .monospacedDigit()
                                        }
                                    }
                                    Text(item.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineSpacing(2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(BCSpacing.md)
        .background(BCColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { loadCompleted() }
    }

    private var groupedItems: [(key: String, items: [ChecklistItem])] {
        let grouped = Dictionary(grouping: items) { $0.category }
        let order = ["capture", "note", "safety"]
        return order.compactMap { cat in
            guard let items = grouped[cat] else { return nil }
            return (key: cat, items: items)
        }
    }

    private func toggle(_ key: String) {
        if completed.contains(key) {
            completed.remove(key)
        } else {
            completed.insert(key)
        }
        saveCompleted()
    }

    private func loadCompleted() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let set = try? JSONDecoder().decode(Set<String>.self, from: data) {
            completed = set
        }
    }

    private func saveCompleted() {
        if let data = try? JSONEncoder().encode(completed) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "capture": return BCColors.brandBlue
        case "note": return .orange
        case "safety": return .red
        default: return .secondary
        }
    }
}
