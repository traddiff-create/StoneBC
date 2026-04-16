//
//  TrailforksService.swift
//  StoneBC
//
//  Trailforks API client — fetches trail conditions, status, and difficulty.
//  Free tier with app_id/app_secret approval.
//  Falls back gracefully when API keys are not configured.
//

import Foundation
import CoreLocation

actor TrailforksService {
    static let shared = TrailforksService()

    private let baseURL = "https://www.trailforks.com/api/1"
    private var cache: [String: CachedCondition] = [:]
    private let cacheExpiry: TimeInterval = 4 * 60 * 60 // 4 hours

    private var appId: String?
    private var appSecret: String?
    var isConfigured: Bool { appId != nil && appSecret != nil }

    // MARK: - Configuration

    func configure(appId: String, appSecret: String) {
        self.appId = appId
        self.appSecret = appSecret
    }

    // MARK: - Trail Conditions

    /// Fetch trail condition near a coordinate (searches within 5km radius)
    func condition(near coordinate: CLLocationCoordinate2D, routeId: String) async -> TrailCondition? {
        // Return cached if fresh
        if let cached = cache[routeId], Date().timeIntervalSince(cached.fetchedAt) < cacheExpiry {
            return cached.condition
        }

        guard let appId, let appSecret else { return nil }

        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let urlString = "\(baseURL)/trails?scope=nearby&lat=\(lat)&lon=\(lon)&radius=5000&fields=title,condition,status,difficulty&app_id=\(appId)&app_secret=\(appSecret)"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return nil }

            let result = try JSONDecoder().decode(TrailforksResponse.self, from: data)

            guard let trail = result.data.first else { return nil }

            let condition = TrailCondition(
                status: TrailStatus(rawValue: trail.status) ?? .unknown,
                conditionText: trail.condition?.title ?? "Unknown",
                lastReportDate: nil,
                reportCount: 0,
                source: .trailforks
            )

            cache[routeId] = CachedCondition(condition: condition, fetchedAt: Date())
            return condition
        } catch {
            return nil
        }
    }

    /// Fetch conditions for multiple routes in batch
    func conditionsForRoutes(_ routes: [(id: String, coordinate: CLLocationCoordinate2D)]) async -> [String: TrailCondition] {
        var results: [String: TrailCondition] = [:]

        for route in routes {
            if let condition = await condition(near: route.coordinate, routeId: route.id) {
                results[route.id] = condition
            }
        }

        return results
    }
}

// MARK: - Models

struct TrailCondition {
    let status: TrailStatus
    let conditionText: String
    let lastReportDate: Date?
    let reportCount: Int
    let source: ConditionSource

    var displayLabel: String {
        switch status {
        case .open: conditionText.isEmpty ? "Open" : conditionText
        case .closed: "Closed"
        case .warning: "Warning"
        case .unknown: "Unknown"
        }
    }

    var badgeColor: String {
        switch status {
        case .open: "green"
        case .closed: "red"
        case .warning: "orange"
        case .unknown: "gray"
        }
    }

    var icon: String {
        switch status {
        case .open: "checkmark.circle.fill"
        case .closed: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .unknown: "questionmark.circle"
        }
    }
}

enum TrailStatus: Int, Codable {
    case open = 1
    case closed = 2
    case warning = 3
    case unknown = 0
}

enum ConditionSource {
    case trailforks
    case usfs
    case crowdsourced
    case manual // from config.json
}

// MARK: - API Response Types

private struct TrailforksResponse: Codable {
    let data: [TrailforksTrail]
}

private struct TrailforksTrail: Codable {
    let title: String?
    let status: Int
    let difficulty: Int?
    let condition: TrailforksCondition?
}

private struct TrailforksCondition: Codable {
    let title: String?
}

private struct CachedCondition {
    let condition: TrailCondition
    let fetchedAt: Date
}
