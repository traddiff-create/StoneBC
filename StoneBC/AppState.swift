//
//  AppState.swift
//  StoneBC
//
//  Central app state — loads data, manages filtering
//

import SwiftUI

@Observable
class AppState {
    // Data
    var bikes: [Bike] = []
    var posts: [Post] = []
    var events: [Event] = []
    var routes: [Route] = []
    var importedRoutes: [Route] = []
    var guides: [TourGuide] = []
    var config: AppConfig = .load()

    var allRoutes: [Route] { routes + importedRoutes }

    // Expedition
    var activeExpedition: ExpeditionJournal?

    // Member auth
    var memberEmail: String?
    var memberToken: String?
    var isMemberLoggedIn: Bool { memberEmail != nil && memberToken != nil }

    // Sync state
    var isSyncing = false
    var lastSyncDate: Date?
    private var syncTask: Task<Void, Never>?

    // Filtering
    var selectedBikeStatus: BikeStatus?
    var selectedBikeType: BikeType?

    private static let syncInterval: TimeInterval = 5 * 60 // 5 minutes

    init() {
        loadData()
        if let session = MemberAuthService.loadSession() {
            memberEmail = session.email
            memberToken = session.token
        }
        if let keys = config.apiKeys {
            if let id = keys.trailforksAppId, let secret = keys.trailforksAppSecret {
                Task { await TrailforksService.shared.configure(appId: id, appSecret: secret) }
            }
            if let id = keys.stravaClientId, let secret = keys.stravaClientSecret {
                StravaService.shared.configure(clientId: id, clientSecret: secret)
            }
        }
    }

    private static let importedRoutesKey = "importedRoutes"

    var loadErrors: [String] = []

    func loadData() {
        loadErrors = []
        bikes = Bike.loadFromBundle()
        posts = Post.loadFromBundle()
        events = Event.loadFromBundle()
        guides = TourGuide.loadFromBundle()
        loadImportedRoutes()

        // Routes get extra validation — filter out any with bad data
        let allRoutes = Route.loadFromBundle()
        let (valid, invalid) = allRoutes.reduce(into: ([Route](), [Route]())) { result, route in
            if route.isNavigable {
                result.0.append(route)
            } else {
                result.1.append(route)
            }
        }
        routes = valid
        if !invalid.isEmpty {
            loadErrors.append("\(invalid.count) routes skipped (insufficient trackpoints): \(invalid.map(\.name).joined(separator: ", "))")
        }
    }

    // MARK: - Member Auth

    func signIn(email: String, token: String) {
        memberEmail = email
        memberToken = token
        MemberAuthService.saveSession(email: email, token: token)
    }

    func signOut() {
        memberEmail = nil
        memberToken = nil
        MemberAuthService.clearSession()
    }

    // MARK: - Imported Routes

    func addImportedRoute(_ route: Route) {
        importedRoutes.append(route)
        persistImportedRoutes()
    }

    func removeImportedRoute(id: String) {
        importedRoutes.removeAll { $0.id == id }
        persistImportedRoutes()
    }

    private func loadImportedRoutes() {
        guard let data = UserDefaults.standard.data(forKey: Self.importedRoutesKey),
              let decoded = try? JSONDecoder().decode([Route].self, from: data) else { return }
        importedRoutes = decoded
    }

    private func persistImportedRoutes() {
        if let encoded = try? JSONEncoder().encode(importedRoutes) {
            UserDefaults.standard.set(encoded, forKey: Self.importedRoutesKey)
        }
    }

    // MARK: - WordPress Sync

    func syncFromWordPress() async {
        guard !isSyncing else { return }
        guard let urls = config.dataURLs,
              let base = urls.wordpressBase else { return }

        isSyncing = true
        defer { isSyncing = false }

        let service = WordPressService(baseURL: base)

        async let remoteBikes = service.fetchBikes()
        async let remotePosts = service.fetchPosts()
        async let remoteEvents = service.fetchEvents()

        let (b, p, e) = await (remoteBikes, remotePosts, remoteEvents)
        if let b { bikes = b }
        if let p { posts = p }
        if let e { events = e }
        lastSyncDate = Date()
    }

    /// Start periodic background sync every 5 minutes
    func startPeriodicSync() {
        syncTask?.cancel()
        syncTask = Task {
            while !Task.isCancelled {
                await syncFromWordPress()
                try? await Task.sleep(for: .seconds(Self.syncInterval))
            }
        }
    }

    /// Stop periodic sync
    func stopPeriodicSync() {
        syncTask?.cancel()
        syncTask = nil
    }

    // MARK: - Computed Filters

    var availableBikes: [Bike] {
        bikes.filter { $0.status != .sold }
    }

    var filteredBikes: [Bike] {
        availableBikes.filter { bike in
            (selectedBikeStatus == nil || bike.status == selectedBikeStatus) &&
            (selectedBikeType == nil || bike.type == selectedBikeType)
        }
    }

    var featuredBikes: [Bike] {
        Array(bikes.filter { $0.status == .available }.prefix(3))
    }

    var recentPosts: [Post] {
        Array(sortedPosts.prefix(3))
    }

    var sortedPosts: [Post] {
        posts.sorted { $0.date > $1.date }
    }

    var upcomingEvents: [Event] {
        Array(events.prefix(3))
    }

    // MARK: - Filter Counts

    func bikeCount(for status: BikeStatus) -> Int {
        availableBikes.filter { $0.status == status }.count
    }

    func bikeCount(for type: BikeType) -> Int {
        availableBikes.filter { $0.type == type }.count
    }
}
