//
//  Program.swift
//  StoneBC
//
//  Community program model (Earn-A-Bike, Safety, Youth, Open Shop)
//

import Foundation

struct Program: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String                // SF Symbol name
    let details: [String]
    let schedule: String?
    let eligibility: String?
}

// MARK: - Bundle Loading
extension Program {
    static func loadFromBundle() -> [Program] {
        guard let url = Bundle.main.url(forResource: "programs", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([Program].self, from: data)) ?? []
    }
}
