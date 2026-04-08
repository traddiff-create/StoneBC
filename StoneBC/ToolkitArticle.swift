//
//  ToolkitArticle.swift
//  StoneBC
//
//  Open-source toolkit article model (loads markdown from bundle)
//

import Foundation

struct ToolkitArticle: Identifiable, Codable {
    let id: String
    let title: String
    let category: String            // legal, operations, programs, finance, community, resources
    let filename: String            // markdown file in Toolkit/ bundle folder

    var categoryIcon: String {
        switch category {
        case "legal": return "doc.text"
        case "operations": return "wrench.and.screwdriver"
        case "programs": return "person.3"
        case "finance": return "dollarsign.circle"
        case "community": return "house"
        case "resources": return "link"
        default: return "doc"
        }
    }

    var categoryLabel: String {
        category.capitalized
    }

    func loadContent() -> String {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "md", subdirectory: "Toolkit") else {
            return "Content not available."
        }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? "Content not available."
    }
}

// MARK: - Bundle Loading
extension ToolkitArticle {
    static func loadFromBundle() -> [ToolkitArticle] {
        guard let url = Bundle.main.url(forResource: "toolkit", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([ToolkitArticle].self, from: data)) ?? []
    }
}
