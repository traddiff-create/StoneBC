//
//  RouteProviderService.swift
//  StoneBC
//

import CryptoKit
import Foundation
import Security
import SwiftUI

enum ConnectedRouteProvider: String, CaseIterable, Identifiable, Codable {
    case garmin
    case wahoo
    case rideWithGPS

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .garmin: "Garmin"
        case .wahoo: "Wahoo"
        case .rideWithGPS: "Ride with GPS"
        }
    }

    var icon: String {
        switch self {
        case .garmin: "location.north.circle"
        case .wahoo: "bolt.circle"
        case .rideWithGPS: "map.circle"
        }
    }

    var requiredScopes: String {
        switch self {
        case .garmin: "courses"
        case .wahoo: "user_read routes_read routes_write"
        case .rideWithGPS: "read write"
        }
    }
}

struct RouteProviderStatus: Identifiable {
    let provider: ConnectedRouteProvider
    let isConfigured: Bool
    let isAuthenticated: Bool
    let detail: String

    var id: String { provider.rawValue }
}

struct RouteProviderPushResult {
    let provider: ConnectedRouteProvider
    let remoteId: String?
    let message: String
}

enum RouteProviderError: LocalizedError {
    case notConfigured(String)
    case notAuthenticated
    case offline
    case unavailable(String)
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let provider): "\(provider) is not configured."
        case .notAuthenticated: "Connect this account before sending routes."
        case .offline: "Provider upload needs a network connection. File export still works offline."
        case .unavailable(let message): message
        case .badResponse(let message): message
        }
    }
}

@Observable
class RouteProviderManager {
    static let shared = RouteProviderManager()

    private var config: AppConfig = .load()
    private let keychain = RouteProviderKeychain()

    private var codeVerifiers: [ConnectedRouteProvider: String] = [:]

    private init() {}

    func configure(config: AppConfig) {
        self.config = config
    }

    func statuses() -> [RouteProviderStatus] {
        ConnectedRouteProvider.allCases.map { provider in
            RouteProviderStatus(
                provider: provider,
                isConfigured: isConfigured(provider),
                isAuthenticated: token(provider, kind: "access") != nil,
                detail: detail(for: provider)
            )
        }
    }

    func authURL(for provider: ConnectedRouteProvider) -> URL? {
        guard isConfigured(provider) else { return nil }
        let verifier = PKCE.verifier()
        codeVerifiers[provider] = verifier

        switch provider {
        case .garmin:
            return nil
        case .wahoo:
            guard let clientId = config.apiKeys?.wahooClientId else { return nil }
            var components = wahooComponents(path: "/oauth/authorize")
            components?.queryItems = [
                URLQueryItem(name: "client_id", value: clientId),
                URLQueryItem(name: "redirect_uri", value: "stonebc://wahoo-callback"),
                URLQueryItem(name: "scope", value: provider.requiredScopes),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "code_challenge", value: PKCE.challenge(for: verifier)),
                URLQueryItem(name: "code_challenge_method", value: "S256")
            ]
            return components?.url
        case .rideWithGPS:
            guard let clientId = config.apiKeys?.rideWithGPSClientId else { return nil }
            var components = URLComponents(string: "https://ridewithgps.com/oauth/authorize")
            components?.queryItems = [
                URLQueryItem(name: "client_id", value: clientId),
                URLQueryItem(name: "redirect_uri", value: "stonebc://rwgps-callback"),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: provider.requiredScopes),
                URLQueryItem(name: "code_challenge", value: PKCE.challenge(for: verifier)),
                URLQueryItem(name: "code_challenge_method", value: "S256")
            ]
            return components?.url
        }
    }

    func disconnect(_ provider: ConnectedRouteProvider) {
        keychain.delete(key(provider, "access"))
        keychain.delete(key(provider, "refresh"))
        keychain.delete(key(provider, "expires"))
    }

    func handleCallback(provider: ConnectedRouteProvider, code: String) async throws {
        switch provider {
        case .garmin:
            throw RouteProviderError.unavailable("Garmin Courses API requires approved developer access before in-app OAuth can be completed.")
        case .wahoo:
            try await exchangeWahooCode(code, verifier: codeVerifiers[provider])
        case .rideWithGPS:
            throw RouteProviderError.unavailable("Ride with GPS OAuth is configured, but token exchange needs the approved API client secret/proxy before enabling in production.")
        }
    }

    func push(route: Route, to provider: ConnectedRouteProvider) async -> Result<RouteProviderPushResult, RouteProviderError> {
        guard isConfigured(provider) else {
            return .failure(.notConfigured(provider.displayName))
        }
        guard NetworkStatusService.shared.isOnline else {
            return .failure(.offline)
        }
        guard token(provider, kind: "access") != nil else {
            return .failure(.notAuthenticated)
        }

        switch provider {
        case .garmin:
            return .failure(.unavailable("Garmin Courses API publishing is feature-gated until StoneBC has approved Garmin developer access. Export the device bundle now."))
        case .wahoo:
            return await pushToWahoo(route)
        case .rideWithGPS:
            return .failure(.unavailable("Ride with GPS direct upload is feature-gated until OAuth and route-write access are approved. Export the device bundle now."))
        }
    }

    private func pushToWahoo(_ route: Route) async -> Result<RouteProviderPushResult, RouteProviderError> {
        guard let token = token(.wahoo, kind: "access") else { return .failure(.notAuthenticated) }
        let fit = RouteInterchangeService.exportFITCourseData(route: route)
        let encodedFile = "data:application/vnd.fit;base64,\(fit.base64EncodedString())"
        let params: [String: String] = [
            "route[file]": encodedFile,
            "route[filename]": "\(RouteInterchangeService.sanitizedFilename(route.name)).fit",
            "route[external_id]": "stonebc-\(route.id)",
            "route[provider_updated_at]": RouteInterchangeService.iso8601(Date()),
            "route[name]": route.name,
            "route[description]": route.description,
            "route[workout_type_family_id]": "0",
            "route[start_lat]": "\(route.startCoordinate.latitude)",
            "route[start_lng]": "\(route.startCoordinate.longitude)",
            "route[distance]": "\(route.distanceMiles * 1609.344)",
            "route[ascent]": "\(Double(route.elevationGainFeet) / 3.28084)"
        ]

        var request = URLRequest(url: wahooURL(path: "/v1/routes"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = params
            .map { "\($0.key.urlFormEncoded)=\($0.value.urlFormEncoded)" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.badResponse("Wahoo did not return an HTTP response."))
            }
            guard (200...299).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Wahoo upload failed."
                return .failure(.badResponse(message))
            }
            let id = try? JSONDecoder().decode(WahooRouteResponse.self, from: data).id
            return .success(RouteProviderPushResult(provider: .wahoo, remoteId: id.map(String.init), message: "Sent to Wahoo. Sync your ELEMNT device to load it."))
        } catch {
            return .failure(.badResponse(error.localizedDescription))
        }
    }

    private func exchangeWahooCode(_ code: String, verifier: String?) async throws {
        guard let clientId = config.apiKeys?.wahooClientId else {
            throw RouteProviderError.notConfigured("Wahoo")
        }
        guard let verifier else {
            throw RouteProviderError.badResponse("Missing PKCE verifier.")
        }
        var request = URLRequest(url: wahooURL(path: "/oauth/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params = [
            "client_id": clientId,
            "code": code,
            "redirect_uri": "stonebc://wahoo-callback",
            "grant_type": "authorization_code",
            "code_verifier": verifier
        ]
        request.httpBody = params
            .map { "\($0.key.urlFormEncoded)=\($0.value.urlFormEncoded)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw RouteProviderError.badResponse(String(data: data, encoding: .utf8) ?? "Wahoo authorization failed.")
        }
        let decoded = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        saveTokens(provider: .wahoo, access: decoded.access_token, refresh: decoded.refresh_token, expiresIn: decoded.expires_in)
    }

    private func wahooComponents(path: String) -> URLComponents? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.wahooligan.com"
        components.path = path
        return components
    }

    private func wahooURL(path: String) -> URL {
        wahooComponents(path: path)?.url ?? URL(fileURLWithPath: "/")
    }

    private func isConfigured(_ provider: ConnectedRouteProvider) -> Bool {
        switch provider {
        case .garmin:
            return config.apiKeys?.garminClientId != nil
        case .wahoo:
            return config.apiKeys?.wahooClientId != nil
        case .rideWithGPS:
            return config.apiKeys?.rideWithGPSClientId != nil
        }
    }

    private func detail(for provider: ConnectedRouteProvider) -> String {
        if !isConfigured(provider) {
            return "API credentials not configured"
        }
        if token(provider, kind: "access") != nil {
            return "Connected"
        }
        switch provider {
        case .garmin:
            return "Requires approved Garmin Courses API access"
        case .wahoo:
            return "Ready for OAuth"
        case .rideWithGPS:
            return "Requires approved OAuth client"
        }
    }

    private func token(_ provider: ConnectedRouteProvider, kind: String) -> String? {
        keychain.load(key(provider, kind))
    }

    private func saveTokens(provider: ConnectedRouteProvider, access: String, refresh: String?, expiresIn: TimeInterval?) {
        keychain.save(key(provider, "access"), value: access)
        if let refresh { keychain.save(key(provider, "refresh"), value: refresh) }
        if let expiresIn {
            keychain.save(key(provider, "expires"), value: "\(Date().addingTimeInterval(expiresIn).timeIntervalSince1970)")
        }
    }

    private func key(_ provider: ConnectedRouteProvider, _ kind: String) -> String {
        "stonebc.routeprovider.\(provider.rawValue).\(kind)"
    }

    private struct WahooRouteResponse: Decodable {
        let id: Int
    }

    private struct OAuthTokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: TimeInterval?
    }
}

struct ConnectedAppsView: View {
    @Environment(AppState.self) private var appState
    @State private var manager = RouteProviderManager.shared
    @State private var statusMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(manager.statuses()) { status in
                    providerRow(status)
                }
            } header: {
                Text("ROUTE PROVIDERS")
            } footer: {
                Text("File import and device bundles work offline. Direct provider upload appears when API credentials and approvals are available.")
            }
        }
        .navigationTitle("Connected Apps")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            manager.configure(config: appState.config)
        }
        .alert("Connected Apps", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusMessage ?? "")
        }
    }

    private func providerRow(_ status: RouteProviderStatus) -> some View {
        HStack(spacing: 12) {
            Image(systemName: status.provider.icon)
                .font(.system(size: 18))
                .foregroundColor(BCColors.brandBlue)
                .frame(width: 34, height: 34)
                .background(BCColors.brandBlue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(status.provider.displayName)
                    .font(.system(size: 15, weight: .medium))
                Text(status.detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if status.isAuthenticated {
                Button("Disconnect") {
                    manager.disconnect(status.provider)
                    statusMessage = "\(status.provider.displayName) disconnected."
                }
                .font(.system(size: 12, weight: .medium))
            } else if let url = manager.authURL(for: status.provider) {
                Link("Connect", destination: url)
                    .font(.system(size: 12, weight: .medium))
            } else {
                Text(status.isConfigured ? "Gated" : "Off")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RouteProviderKeychain {
    func save(_ key: String, value: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func load(_ key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(_ key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private enum PKCE {
    static func verifier() -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<64).map { _ in chars[Int.random(in: 0..<chars.count)] })
    }

    static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension String {
    var urlFormEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
