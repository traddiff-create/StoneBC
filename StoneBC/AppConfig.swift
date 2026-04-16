//
//  AppConfig.swift
//  StoneBC
//
//  Config-driven settings for open-source reuse by other bike co-ops
//

import Foundation

struct AppConfig: Codable {
    let coalitionName: String
    let shortName: String
    let tagline: String
    let websiteURL: String
    let email: String
    let phone: String?
    let instagramHandle: String?
    let location: LocationInfo?
    let colors: BrandColors
    let features: FeatureFlags
    let dataURLs: DataURLs?

    struct LocationInfo: Codable {
        let name: String
        let address: String
        let city: String
        let state: String
        let zip: String
    }

    struct BrandColors: Codable {
        let brandBlue: String
        let brandGreen: String
        let brandAmber: String
    }

    struct FeatureFlags: Codable {
        let enableMarketplace: Bool
        let enableCommunityFeed: Bool
        let enableRoutes: Bool
        let enableEvents: Bool
        let enableGallery: Bool
        let enableRadio: Bool
    }

    struct DataURLs: Codable {
        let wordpressBase: String?
        let bikes: String?
        let events: String?
        let posts: String?
    }

    struct APIKeys: Codable {
        let trailforksAppId: String?
        let trailforksAppSecret: String?
        let stravaClientId: String?
        let stravaClientSecret: String?
    }

    let apiKeys: APIKeys?

    static func load() -> AppConfig {
        guard let url = Bundle.main.url(forResource: "config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return .default
        }
        return config
    }

    static let `default` = AppConfig(
        coalitionName: "Stone Bicycle Coalition",
        shortName: "SBC",
        tagline: "Building Community Through Cycling",
        websiteURL: "https://stonebicyclecoalition.com",
        email: "info@stonebicyclecoalition.com",
        phone: nil,
        instagramHandle: "stone_bicycle_coalition",
        location: LocationInfo(
            name: "Minneluzahan Senior Center",
            address: "315 N 4th St",
            city: "Rapid City",
            state: "SD",
            zip: "57701"
        ),
        colors: BrandColors(
            brandBlue: "#2563eb",
            brandGreen: "#059669",
            brandAmber: "#f59e0b"
        ),
        features: FeatureFlags(
            enableMarketplace: true,
            enableCommunityFeed: true,
            enableRoutes: true,
            enableEvents: true,
            enableGallery: true,
            enableRadio: true
        ),
        dataURLs: nil,
        apiKeys: nil
    )
}
