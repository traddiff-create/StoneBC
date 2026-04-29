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

    private let fileURL: URL

    init(documentsDirectory: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask).first!) {
        self.fileURL = documentsDirectory.appendingPathComponent("userRoutes.json")
        load()
    }

    func save(_ route: Route) {
        routes.insert(route, at: 0)
        persist()
    }

    func replaceAll(_ newRoutes: [Route]) {
        routes = newRoutes
        persist()
    }

    func mergeMigratedRoutes(_ migrated: [Route]) {
        let existingIds = Set(routes.map(\.id))
        let additions = migrated.filter { !existingIds.contains($0.id) }
        guard !additions.isEmpty else { return }
        routes.append(contentsOf: additions)
        persist()
    }

    func delete(id: String) {
        routes.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Persistence

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
