//
//  UserRouteStore.swift
//  StoneBC
//
//  Persists user-created route templates (from recordings or GPX imports)
//  to `Documents/userRoutes.json`. Bundled `routes.json` stays read-only.
//

import Foundation

@Observable
class UserRouteStore {
    static let shared = UserRouteStore()

    private(set) var routes: [Route] = []

    private init() {
        load()
    }

    func save(_ route: Route) {
        routes.insert(route, at: 0)
        persist()
    }

    func delete(id: String) {
        routes.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Persistence

    private var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("userRoutes.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Route].self, from: data) else {
            return
        }
        routes = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(routes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
