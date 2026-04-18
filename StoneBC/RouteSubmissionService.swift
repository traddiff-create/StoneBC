//
//  RouteSubmissionService.swift
//  StoneBC
//

import Foundation

enum RouteSubmissionService {

    private static let endpoint = "https://stonebicyclecoalition.com/api/submit-route"

    static func submit(
        name: String,
        description: String,
        difficulty: String,
        category: String,
        email: String,
        gpxData: Data
    ) async -> Result<Void, Error> {
        guard let url = URL(string: endpoint) else {
            return .failure(URLError(.badURL))
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        let fields: [(String, String)] = [
            ("name", name),
            ("description", description),
            ("difficulty", difficulty),
            ("category", category),
            ("email", email),
        ]

        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"gpx\"; filename=\"route.gpx\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/gpx+xml\r\n\r\n".data(using: .utf8)!)
        body.append(gpxData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let msg = (try? JSONDecoder().decode(APIError.self, from: data))?.error ?? "Submission failed"
                return .failure(SubmissionError(message: msg))
            }
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    private struct APIError: Decodable { let error: String }

    private struct SubmissionError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}
