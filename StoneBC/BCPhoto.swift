//
//  BCPhoto.swift
//  StoneBC
//
//  Photo model for gallery display
//

import Foundation

struct BCPhoto: Identifiable, Codable {
    let id: String
    let filename: String
    let title: String
    let category: String            // shop, rides, events, community, bikes
}

// MARK: - Bundle Loading
extension BCPhoto {
    static func loadFromBundle() -> [BCPhoto] {
        guard let url = Bundle.main.url(forResource: "photos", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([BCPhoto].self, from: data)) ?? []
    }
}
