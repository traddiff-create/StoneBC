//
//  StravaService.swift
//  StoneBC
//
//  Strava API v3 client — OAuth2 login, segment exploration, leaderboards.
//  Free tier: 600 req/15min, 1000/day. Sufficient for community app (<10K users).
//

import Foundation
import AuthenticationServices
import CoreLocation

@Observable
class StravaService {
    static let shared = StravaService()

    var isAuthenticated = false
    var athleteName: String?
    var error: String?

    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date?

    private var clientId: String?
    private var clientSecret: String?
    var isConfigured: Bool { clientId != nil && clientSecret != nil }

    private let baseURL = "https://www.strava.com/api/v3"
    private var segmentCache: [String: CachedSegments] = [:]
    private let cacheExpiry: TimeInterval = 7 * 24 * 60 * 60 // 7 days

    private init() {
        loadTokens()
    }

    // MARK: - Configuration

    func configure(clientId: String, clientSecret: String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    // MARK: - OAuth

    /// Build the Strava OAuth URL for user authorization
    var authURL: URL? {
        guard let clientId else { return nil }
        var components = URLComponents(string: "https://www.strava.com/oauth/mobile/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: "stonebc://strava-callback"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: "read,activity:read")
        ]
        return components.url
    }

    /// Exchange authorization code for access token
    func handleAuthCallback(code: String) async {
        guard let clientId, let clientSecret else { return }

        let url = URL(string: "https://www.strava.com/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "grant_type": "authorization_code"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(StravaTokenResponse.self, from: data)

            accessToken = tokenResponse.access_token
            refreshToken = tokenResponse.refresh_token
            tokenExpiry = Date(timeIntervalSince1970: TimeInterval(tokenResponse.expires_at))
            athleteName = "\(tokenResponse.athlete?.firstname ?? "") \(tokenResponse.athlete?.lastname ?? "")"
            isAuthenticated = true
            saveTokens()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func disconnect() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        athleteName = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "strava_access_token")
        UserDefaults.standard.removeObject(forKey: "strava_refresh_token")
        UserDefaults.standard.removeObject(forKey: "strava_token_expiry")
        UserDefaults.standard.removeObject(forKey: "strava_athlete_name")
    }

    // MARK: - Segments

    /// Explore Strava segments near a coordinate
    func segments(near coordinate: CLLocationCoordinate2D, routeId: String) async -> [StravaSegment] {
        if let cached = segmentCache[routeId], Date().timeIntervalSince(cached.fetchedAt) < cacheExpiry {
            return cached.segments
        }

        guard let token = await validToken() else { return [] }

        let bounds = "\(coordinate.latitude - 0.05),\(coordinate.longitude - 0.05),\(coordinate.latitude + 0.05),\(coordinate.longitude + 0.05)"
        let urlString = "\(baseURL)/segments/explore?bounds=\(bounds)&activity_type=riding"

        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return [] }

            let result = try JSONDecoder().decode(StravaExploreResponse.self, from: data)
            let segments = result.segments.map { seg in
                StravaSegment(
                    id: seg.id,
                    name: seg.name,
                    distanceMiles: (seg.distance ?? 0) / 1609.344,
                    avgGradePercent: seg.avg_grade ?? 0,
                    elevDifferenceFeet: (seg.elev_difference ?? 0) * 3.28084,
                    climbCategory: seg.climb_category ?? 0
                )
            }

            segmentCache[routeId] = CachedSegments(segments: segments, fetchedAt: Date())
            return segments
        } catch {
            return []
        }
    }

    /// Get leaderboard for a specific segment
    func leaderboard(segmentId: Int) async -> [StravaLeaderEntry] {
        guard let token = await validToken() else { return [] }

        let urlString = "\(baseURL)/segments/\(segmentId)/leaderboard?per_page=3"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return [] }

            let result = try JSONDecoder().decode(StravaLeaderboardResponse.self, from: data)
            return result.entries.map { entry in
                StravaLeaderEntry(
                    rank: entry.rank,
                    athleteName: entry.athlete_name,
                    elapsedTime: entry.elapsed_time,
                    movingTime: entry.moving_time
                )
            }
        } catch {
            return []
        }
    }

    // MARK: - Token Management

    private func validToken() async -> String? {
        guard let token = accessToken else { return nil }

        // Refresh if expired
        if let expiry = tokenExpiry, Date() > expiry {
            await refreshAccessToken()
        }

        return accessToken ?? token
    }

    private func refreshAccessToken() async {
        guard let clientId, let clientSecret, let refresh = refreshToken else { return }

        let url = URL(string: "https://www.strava.com/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refresh,
            "grant_type": "refresh_token"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(StravaTokenResponse.self, from: data)
            accessToken = tokenResponse.access_token
            refreshToken = tokenResponse.refresh_token
            tokenExpiry = Date(timeIntervalSince1970: TimeInterval(tokenResponse.expires_at))
            saveTokens()
        } catch {
            isAuthenticated = false
        }
    }

    private func saveTokens() {
        UserDefaults.standard.set(accessToken, forKey: "strava_access_token")
        UserDefaults.standard.set(refreshToken, forKey: "strava_refresh_token")
        UserDefaults.standard.set(tokenExpiry?.timeIntervalSince1970, forKey: "strava_token_expiry")
        UserDefaults.standard.set(athleteName, forKey: "strava_athlete_name")
    }

    private func loadTokens() {
        accessToken = UserDefaults.standard.string(forKey: "strava_access_token")
        refreshToken = UserDefaults.standard.string(forKey: "strava_refresh_token")
        athleteName = UserDefaults.standard.string(forKey: "strava_athlete_name")
        if let expiry = UserDefaults.standard.object(forKey: "strava_token_expiry") as? TimeInterval {
            tokenExpiry = Date(timeIntervalSince1970: expiry)
        }
        isAuthenticated = accessToken != nil
    }
}

// MARK: - Models

struct StravaSegment: Identifiable {
    let id: Int
    let name: String
    let distanceMiles: Double
    let avgGradePercent: Double
    let elevDifferenceFeet: Double
    let climbCategory: Int // 0 = no category, 1-5 (5 = HC)

    var climbCategoryLabel: String {
        switch climbCategory {
        case 5: "HC"
        case 4: "Cat 4"
        case 3: "Cat 3"
        case 2: "Cat 2"
        case 1: "Cat 1"
        default: ""
        }
    }

    var formattedDistance: String {
        String(format: "%.1f mi", distanceMiles)
    }

    var formattedGrade: String {
        String(format: "%.1f%%", avgGradePercent)
    }
}

struct StravaLeaderEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let athleteName: String
    let elapsedTime: Int // seconds
    let movingTime: Int

    var formattedTime: String {
        let h = elapsedTime / 3600
        let m = (elapsedTime % 3600) / 60
        let s = elapsedTime % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - API Response Types

private struct StravaTokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let expires_at: Int
    let athlete: StravaAthlete?
}

private struct StravaAthlete: Codable {
    let firstname: String?
    let lastname: String?
}

private struct StravaExploreResponse: Codable {
    let segments: [StravaExploreSegment]
}

private struct StravaExploreSegment: Codable {
    let id: Int
    let name: String
    let distance: Double?
    let avg_grade: Double?
    let elev_difference: Double?
    let climb_category: Int?
}

private struct StravaLeaderboardResponse: Codable {
    let entries: [StravaLeaderboardEntry]
}

private struct StravaLeaderboardEntry: Codable {
    let rank: Int
    let athlete_name: String
    let elapsed_time: Int
    let moving_time: Int
}

private struct CachedSegments {
    let segments: [StravaSegment]
    let fetchedAt: Date
}
