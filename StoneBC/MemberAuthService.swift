//
//  MemberAuthService.swift
//  StoneBC
//

import Foundation
import Security

enum MemberAuthService {

    private static let baseURL = "https://stonebicyclecoalition.com/api/magic-link"
    private static let emailKey = "stonebc.member.email"
    private static let tokenKey = "stonebc.member.token"

    // MARK: - Magic Link Request

    static func requestMagicLink(email: String) async -> Result<Void, Error> {
        guard let url = URL(string: baseURL) else { return .failure(AuthError.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let msg = (try? JSONDecoder().decode(APIError.self, from: data))?.error ?? "Request failed"
                return .failure(AuthError.message(msg))
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Token Validation

    static func validateToken(_ token: String, email: String) async -> Bool {
        let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
        guard let url = URL(string: "\(baseURL)?token=\(token)&email=\(encoded)") else { return false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            let result = try? JSONDecoder().decode(ValidationResult.self, from: data)
            return result?.valid == true
        } catch {
            return false
        }
    }

    // MARK: - Keychain

    static func saveSession(email: String, token: String) {
        save(key: emailKey, value: email)
        save(key: tokenKey, value: token)
    }

    static func loadSession() -> (email: String, token: String)? {
        guard let email = load(key: emailKey), let token = load(key: tokenKey) else { return nil }
        return (email, token)
    }

    static func clearSession() {
        delete(key: emailKey)
        delete(key: tokenKey)
    }

    // MARK: - Keychain helpers

    private static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Models

    private struct APIError: Decodable { let error: String }
    private struct ValidationResult: Decodable { let valid: Bool }

    enum AuthError: LocalizedError {
        case badURL
        case message(String)
        var errorDescription: String? {
            switch self {
            case .badURL: return "Invalid URL"
            case .message(let m): return m
            }
        }
    }
}
