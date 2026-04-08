//
//  WordPressService.swift
//  StoneBC
//
//  WordPress REST API client — fetches events, bikes, and posts
//  from a headless WordPress instance. Returns nil on failure
//  so the app falls back to bundled JSON.
//

import Foundation

actor WordPressService {
    private let baseURL: String
    private let session: URLSession
    private let cache = NSCache<NSString, CacheEntry>()
    private var inFlight: [String: Task<Data?, Error>] = [:]

    private let cacheDuration: TimeInterval = 300 // 5 minutes

    init(baseURL: String) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    func fetchBikes() async -> [Bike]? {
        guard let data = await fetch(path: "/sbc_bike?per_page=50") else { return nil }
        return decodeWPBikes(from: data)
    }

    func fetchPosts() async -> [Post]? {
        guard let data = await fetch(path: "/posts?per_page=20&_embed") else { return nil }
        return decodeWPPosts(from: data)
    }

    func fetchEvents() async -> [Event]? {
        guard let data = await fetch(path: "/sbc_event?per_page=50") else { return nil }
        return decodeWPEvents(from: data)
    }

    // MARK: - Network Layer

    private func fetch(path: String) async -> Data? {
        let urlString = baseURL + path
        let cacheKey = urlString as NSString

        // Check cache
        if let entry = cache.object(forKey: cacheKey),
           Date().timeIntervalSince(entry.timestamp) < cacheDuration {
            return entry.data
        }

        // Deduplicate in-flight requests
        if let existing = inFlight[urlString] {
            return try? await existing.value
        }

        let task = Task<Data?, Error> {
            guard let url = URL(string: urlString) else { return nil }
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode) else {
                    return nil
                }
                cache.setObject(CacheEntry(data: data), forKey: cacheKey)
                return data
            } catch {
                return nil
            }
        }

        inFlight[urlString] = task
        let result = try? await task.value
        inFlight[urlString] = nil
        return result
    }

    // MARK: - WP JSON → Swift Model Mapping

    private func decodeWPBikes(from data: Data) -> [Bike]? {
        guard let wpBikes = try? JSONDecoder().decode([WPBike].self, from: data) else {
            return nil
        }
        return wpBikes.compactMap { $0.toBike() }
    }

    private func decodeWPPosts(from data: Data) -> [Post]? {
        guard let wpPosts = try? JSONDecoder().decode([WPPost].self, from: data) else {
            return nil
        }
        return wpPosts.compactMap { $0.toPost() }
    }

    private func decodeWPEvents(from data: Data) -> [Event]? {
        guard let wpEvents = try? JSONDecoder().decode([WPEvent].self, from: data) else {
            return nil
        }
        return wpEvents.compactMap { $0.toEvent() }
    }
}

// MARK: - Cache Entry

private final class CacheEntry: NSObject {
    let data: Data
    let timestamp: Date

    init(data: Data) {
        self.data = data
        self.timestamp = Date()
    }
}

// MARK: - WordPress Response Models

/// WP REST API bike (custom post type: sbc_bike)
private struct WPBike: Decodable {
    let id: Int
    let title: WPRendered
    let content: WPRendered
    let acf: WPBikeFields

    struct WPBikeFields: Decodable {
        let bike_id: String?
        let bike_status: String?
        let bike_type: String?
        let frame_size: String?
        let wheel_size: String?
        let bike_color: String?
        let condition: String?
        let features: [WPRepeaterField]?
        let sponsor_price: Int?
        let acquired_via: String?
        let date_added: String?
    }

    struct WPRepeaterField: Decodable {
        let value: String?

        // ACF repeater can return strings or objects
        init(from decoder: Decoder) throws {
            if let container = try? decoder.singleValueContainer(),
               let str = try? container.decode(String.self) {
                value = str
            } else {
                value = nil
            }
        }
    }

    func toBike() -> Bike? {
        let bikeID = acf.bike_id ?? "SBC-\(id)"
        let status = BikeStatus(rawValue: acf.bike_status ?? "") ?? .available
        let type = BikeType(rawValue: acf.bike_type ?? "") ?? .hybrid
        let condition = BikeCondition(rawValue: acf.condition ?? "") ?? .good
        let features = acf.features?.compactMap(\.value) ?? []

        return Bike(
            id: bikeID,
            status: status,
            model: title.rendered.strippingHTML(),
            type: type,
            frameSize: acf.frame_size ?? "",
            wheelSize: acf.wheel_size ?? "",
            color: acf.bike_color ?? "",
            condition: condition,
            features: features,
            photos: [],
            sponsorPrice: acf.sponsor_price ?? 0,
            description: content.rendered.strippingHTML(),
            dateAdded: acf.date_added ?? "",
            acquiredVia: acf.acquired_via ?? "donation"
        )
    }
}

/// WP REST API standard post
private struct WPPost: Decodable {
    let id: Int
    let title: WPRendered
    let content: WPRendered
    let excerpt: WPRendered
    let date: String  // ISO 8601 from WP
    let featured_media: Int?
    let categories: [Int]?

    func toPost() -> Post {
        // Extract date portion (YYYY-MM-DD) from WP ISO datetime
        let dateOnly = String(date.prefix(10))
        let body = content.rendered.strippingHTML()

        return Post(
            id: "wp-\(id)",
            title: title.rendered.strippingHTML(),
            body: body,
            imageURL: nil,
            date: dateOnly,
            category: nil
        )
    }
}

/// WP REST API event (custom post type: sbc_event)
private struct WPEvent: Decodable {
    let id: Int
    let title: WPRendered
    let content: WPRendered
    let acf: WPEventFields

    struct WPEventFields: Decodable {
        let event_date: String?
        let event_time: String?
        let event_location: String?
        let event_category: String?
        let is_recurring: Bool?
    }

    func toEvent() -> Event {
        let dateStr: String
        if let time = acf.event_time, !time.isEmpty {
            dateStr = "\(acf.event_date ?? "TBD"), \(time)"
        } else {
            dateStr = acf.event_date ?? "TBD"
        }

        return Event(
            id: "wp-\(id)",
            title: title.rendered.strippingHTML(),
            date: dateStr,
            location: acf.event_location ?? "",
            category: acf.event_category ?? "social",
            description: content.rendered.strippingHTML(),
            isRecurring: acf.is_recurring ?? false
        )
    }
}

/// WP rendered content wrapper
private struct WPRendered: Decodable {
    let rendered: String
}

// MARK: - HTML Stripping

private extension String {
    func strippingHTML() -> String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#8217;", with: "'")
            .replacingOccurrences(of: "&#8220;", with: "\"")
            .replacingOccurrences(of: "&#8221;", with: "\"")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
