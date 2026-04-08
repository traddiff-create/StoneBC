//
//  Event.swift
//  StoneBC
//
//  Community event model
//

import Foundation

struct Event: Identifiable, Codable {
    let id: String
    let title: String
    let date: String                // ISO 8601 or description like "Every Saturday"
    let location: String
    let category: String            // ride, workshop, openShop, social
    let description: String
    let isRecurring: Bool

    var categoryIcon: String {
        switch category {
        case "ride": return "bicycle"
        case "workshop": return "wrench.and.screwdriver"
        case "openShop": return "door.left.hand.open"
        case "social": return "person.3"
        default: return "calendar"
        }
    }

    var categoryLabel: String {
        switch category {
        case "ride": return "Group Ride"
        case "workshop": return "Workshop"
        case "openShop": return "Open Shop"
        case "social": return "Social"
        default: return category.capitalized
        }
    }
}

// MARK: - Bundle Loading
extension Event {
    static func loadFromBundle() -> [Event] {
        guard let url = Bundle.main.url(forResource: "events", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([Event].self, from: data)) ?? []
    }
}
