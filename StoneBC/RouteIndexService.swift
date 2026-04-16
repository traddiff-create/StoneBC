//
//  RouteIndexService.swift
//  StoneBC
//
//  SQLite FTS5 full-text search index for routes. Enables queries like
//  "gravel routes near Spearfish over 30 miles" with instant results.
//  Rebuilds on app launch from bundled + imported routes.
//

import Foundation
import SQLite3

actor RouteIndexService {
    static let shared = RouteIndexService()

    private var db: OpaquePointer?

    private let dbPath: String = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("route_index.sqlite3").path
    }()

    private init() {}

    // MARK: - Setup

    /// Create the FTS5 virtual table and index all routes
    func buildIndex(from routes: [Route]) {
        close()

        // Delete old index — always rebuild from current data
        try? FileManager.default.removeItem(atPath: dbPath)

        guard sqlite3_open(dbPath, &db) == SQLITE_OK else { return }

        // Create FTS5 table
        let createSQL = """
            CREATE VIRTUAL TABLE IF NOT EXISTS routes_fts USING fts5(
                route_id,
                name,
                difficulty,
                category,
                region,
                description,
                distance_miles UNINDEXED,
                elevation_gain UNINDEXED,
                start_lat UNINDEXED,
                start_lon UNINDEXED
            );
        """
        sqlite3_exec(db, createSQL, nil, nil, nil)

        // Insert all routes
        let insertSQL = """
            INSERT INTO routes_fts (route_id, name, difficulty, category, region, description, distance_miles, elevation_gain, start_lat, start_lon)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else { return }

        for route in routes {
            sqlite3_bind_text(stmt, 1, (route.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (route.name as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (route.difficulty as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (route.category as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 5, (route.region as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 6, (route.description as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 7, route.distanceMiles)
            sqlite3_bind_int(stmt, 8, Int32(route.elevationGainFeet))
            sqlite3_bind_double(stmt, 9, route.startCoordinate.latitude)
            sqlite3_bind_double(stmt, 10, route.startCoordinate.longitude)

            sqlite3_step(stmt)
            sqlite3_reset(stmt)
        }

        sqlite3_finalize(stmt)
    }

    // MARK: - Search

    /// Full-text search across route name, region, difficulty, category, description
    func search(query: String) -> [RouteSearchResult] {
        guard let db, !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        // Sanitize query for FTS5 — escape quotes, add prefix matching
        let sanitized = query
            .replacingOccurrences(of: "\"", with: "\"\"")
            .trimmingCharacters(in: .whitespaces)

        // Use prefix matching so "spear" matches "Spearfish"
        let ftsQuery = sanitized.split(separator: " ").map { "\($0)*" }.joined(separator: " ")

        let sql = """
            SELECT route_id, name, difficulty, category, region, distance_miles, elevation_gain,
                   rank
            FROM routes_fts
            WHERE routes_fts MATCH ?
            ORDER BY rank
            LIMIT 20;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }

        sqlite3_bind_text(stmt, 1, (ftsQuery as NSString).utf8String, -1, nil)

        var results: [RouteSearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let result = RouteSearchResult(
                routeId: String(cString: sqlite3_column_text(stmt, 0)),
                name: String(cString: sqlite3_column_text(stmt, 1)),
                difficulty: String(cString: sqlite3_column_text(stmt, 2)),
                category: String(cString: sqlite3_column_text(stmt, 3)),
                region: String(cString: sqlite3_column_text(stmt, 4)),
                distanceMiles: sqlite3_column_double(stmt, 5),
                elevationGainFeet: Int(sqlite3_column_int(stmt, 6)),
                relevanceScore: sqlite3_column_double(stmt, 7)
            )
            results.append(result)
        }

        sqlite3_finalize(stmt)
        return results
    }

    /// Filter routes by criteria (distance range, category, difficulty)
    func filter(
        category: String? = nil,
        difficulty: String? = nil,
        minMiles: Double? = nil,
        maxMiles: Double? = nil
    ) -> [RouteSearchResult] {
        guard let db else { return [] }

        var conditions: [String] = []
        var params: [Any] = []

        if let category {
            conditions.append("category = ?")
            params.append(category)
        }
        if let difficulty {
            conditions.append("difficulty = ?")
            params.append(difficulty)
        }
        if let minMiles {
            conditions.append("CAST(distance_miles AS REAL) >= ?")
            params.append(minMiles)
        }
        if let maxMiles {
            conditions.append("CAST(distance_miles AS REAL) <= ?")
            params.append(maxMiles)
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
        let sql = """
            SELECT route_id, name, difficulty, category, region, distance_miles, elevation_gain, 0.0
            FROM routes_fts
            \(whereClause)
            ORDER BY CAST(distance_miles AS REAL)
            LIMIT 50;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }

        for (i, param) in params.enumerated() {
            let idx = Int32(i + 1)
            if let str = param as? String {
                sqlite3_bind_text(stmt, idx, (str as NSString).utf8String, -1, nil)
            } else if let num = param as? Double {
                sqlite3_bind_double(stmt, idx, num)
            }
        }

        var results: [RouteSearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let result = RouteSearchResult(
                routeId: String(cString: sqlite3_column_text(stmt, 0)),
                name: String(cString: sqlite3_column_text(stmt, 1)),
                difficulty: String(cString: sqlite3_column_text(stmt, 2)),
                category: String(cString: sqlite3_column_text(stmt, 3)),
                region: String(cString: sqlite3_column_text(stmt, 4)),
                distanceMiles: sqlite3_column_double(stmt, 5),
                elevationGainFeet: Int(sqlite3_column_int(stmt, 6)),
                relevanceScore: 0
            )
            results.append(result)
        }

        sqlite3_finalize(stmt)
        return results
    }

    // MARK: - Cleanup

    func close() {
        if let db {
            sqlite3_close(db)
            self.db = nil
        }
    }
}

// MARK: - Model

struct RouteSearchResult: Identifiable {
    let routeId: String
    let name: String
    let difficulty: String
    let category: String
    let region: String
    let distanceMiles: Double
    let elevationGainFeet: Int
    let relevanceScore: Double

    var id: String { routeId }

    var formattedDistance: String {
        String(format: "%.1f mi", distanceMiles)
    }
}
