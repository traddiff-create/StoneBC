//
//  Bike.swift
//  StoneBC
//
//  Bike inventory model derived from The Quarry POS system
//

import SwiftUI

// MARK: - Bike Model

struct Bike: Identifiable, Codable {
    let id: String              // SBC-### format
    let status: BikeStatus
    let model: String
    let type: BikeType
    let frameSize: String
    let wheelSize: String
    let color: String
    let condition: BikeCondition
    let features: [String]
    let photos: [String]
    let sponsorPrice: Int
    let description: String
    let dateAdded: String
    let acquiredVia: String

    var formattedPrice: String {
        "$\(sponsorPrice)"
    }
}

// MARK: - Enums

enum BikeStatus: String, Codable, CaseIterable {
    case available, refurbishing, sponsored, sold

    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .available: return .green
        case .refurbishing: return .orange
        case .sponsored: return .purple
        case .sold: return .gray
        }
    }

    var icon: String {
        switch self {
        case .available: return "checkmark.circle.fill"
        case .refurbishing: return "wrench.and.screwdriver"
        case .sponsored: return "heart.fill"
        case .sold: return "tag.fill"
        }
    }
}

enum BikeType: String, Codable, CaseIterable {
    case road, hybrid, mountain, cargo, cruiser

    var label: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .road: return "road.lanes"
        case .hybrid: return "bicycle"
        case .mountain: return "mountain.2"
        case .cargo: return "shippingbox"
        case .cruiser: return "sun.max"
        }
    }
}

enum BikeCondition: String, Codable, CaseIterable {
    case excellent, good, fair, poor

    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
}

// MARK: - Bundle Loading

extension Bike {
    static func loadFromBundle() -> [Bike] {
        guard let url = Bundle.main.url(forResource: "bikes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        let wrapper = try? JSONDecoder().decode(BikeWrapper.self, from: data)
        return wrapper?.bikes ?? []
    }
}

private struct BikeWrapper: Codable {
    let bikes: [Bike]
}

// MARK: - Preview Helper

extension Bike {
    static let preview = Bike(
        id: "SBC-001",
        status: .available,
        model: "Trek 7100 Hybrid",
        type: .hybrid,
        frameSize: "56cm",
        wheelSize: "700c",
        color: "Blue",
        condition: .good,
        features: ["Fenders", "Kickstand", "Rear rack"],
        photos: ["SBC-001-front.jpg"],
        sponsorPrice: 275,
        description: "Reliable commuter hybrid. New tires, brake pads, and chain. Ready to ride.",
        dateAdded: "2026-03-26",
        acquiredVia: "donation"
    )
}
