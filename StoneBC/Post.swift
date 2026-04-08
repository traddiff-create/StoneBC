//
//  Post.swift
//  StoneBC
//
//  Community bulletin board post model
//

import SwiftUI

struct Post: Identifiable, Codable {
    let id: String
    let title: String
    let body: String
    let imageURL: String?
    let date: String
    let category: PostCategory?

    var formattedDate: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium

        if let parsed = isoFormatter.date(from: date) {
            return displayFormatter.string(from: parsed)
        }
        return date
    }

    var excerpt: String {
        let plain = body
            .replacingOccurrences(of: #"[#*_`>\[\]()]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: " ")
        if plain.count > 120 {
            return String(plain.prefix(120)) + "..."
        }
        return plain
    }
}

enum PostCategory: String, Codable, CaseIterable {
    case featured, news, event, announcement

    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .featured: return BCColors.brandBlue
        case .news: return BCColors.brandGreen
        case .event: return BCColors.brandAmber
        case .announcement: return .orange
        }
    }

    var icon: String {
        switch self {
        case .featured: return "star.fill"
        case .news: return "newspaper"
        case .event: return "calendar"
        case .announcement: return "megaphone"
        }
    }
}

// MARK: - Bundle Loading

extension Post {
    static func loadFromBundle() -> [Post] {
        guard let url = Bundle.main.url(forResource: "posts", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([Post].self, from: data)) ?? []
    }
}

// MARK: - Preview Helper

extension Post {
    static let preview = Post(
        id: "post-001",
        title: "Spring Kickoff Ride!",
        body: "Join us for our first group ride of the season. All skill levels welcome — just bring your bike and a smile.\n\nMeet at Minneluzahan Senior Center at 10am. We'll ride the creek path and grab coffee after.",
        imageURL: nil,
        date: "2026-04-01",
        category: .event
    )
}
