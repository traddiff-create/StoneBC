//
//  RouteConditionReporter.swift
//  StoneBC
//
//  Local-first crowdsourced trail condition reports. Riders tap a quick
//  condition after their ride; reports display on route cards.
//  Reports persist to UserDefaults, optionally sync via WordPress.
//

import Foundation

@Observable
class RouteConditionReporter {
    static let shared = RouteConditionReporter()

    private(set) var reports: [String: [ConditionReport]] = [:] // keyed by routeId
    private let storageKey = "conditionReports"
    private let maxReportsPerRoute = 20
    private let reportStaleDays = 14 // reports older than 14 days are dimmed

    private init() {
        loadReports()
    }

    // MARK: - Submit Report

    func submitReport(routeId: String, condition: RideCondition, note: String? = nil) {
        var routeReports = reports[routeId] ?? []

        let report = ConditionReport(
            id: UUID().uuidString,
            routeId: routeId,
            condition: condition,
            note: note,
            reportedAt: Date(),
            synced: false
        )

        routeReports.insert(report, at: 0)

        // Cap at max
        if routeReports.count > maxReportsPerRoute {
            routeReports = Array(routeReports.prefix(maxReportsPerRoute))
        }

        reports[routeId] = routeReports
        persistReports()
    }

    // MARK: - Query

    /// Most recent condition for a route (within last 14 days)
    func latestCondition(for routeId: String) -> TrailCondition? {
        guard let routeReports = reports[routeId],
              let latest = routeReports.first,
              Date().timeIntervalSince(latest.reportedAt) < Double(reportStaleDays) * 86400 else {
            return nil
        }

        let recentReports = routeReports.filter {
            Date().timeIntervalSince($0.reportedAt) < Double(reportStaleDays) * 86400
        }

        return TrailCondition(
            status: latest.condition.trailStatus,
            conditionText: latest.condition.label,
            lastReportDate: latest.reportedAt,
            reportCount: recentReports.count,
            source: .crowdsourced
        )
    }

    /// Number of recent reports for a route
    func reportCount(for routeId: String) -> Int {
        reports[routeId]?.filter {
            Date().timeIntervalSince($0.reportedAt) < Double(reportStaleDays) * 86400
        }.count ?? 0
    }

    /// All unsynced reports (for WordPress upload)
    func unsyncedReports() -> [ConditionReport] {
        reports.values.flatMap { $0 }.filter { !$0.synced }
    }

    /// Mark reports as synced
    func markSynced(ids: [String]) {
        for routeId in reports.keys {
            reports[routeId] = reports[routeId]?.map { report in
                if ids.contains(report.id) {
                    var synced = report
                    synced.synced = true
                    return synced
                }
                return report
            }
        }
        persistReports()
    }

    // MARK: - Persistence

    private func loadReports() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: [ConditionReport]].self, from: data) else {
            return
        }
        reports = decoded
    }

    private func persistReports() {
        if let data = try? JSONEncoder().encode(reports) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - Models

enum RideCondition: String, Codable, CaseIterable {
    case great = "Great"
    case good = "Good"
    case muddy = "Muddy"
    case wet = "Wet"
    case icy = "Icy"
    case overgrown = "Overgrown"
    case closed = "Closed"

    var label: String { rawValue }

    var icon: String {
        switch self {
        case .great: "star.fill"
        case .good: "checkmark.circle"
        case .muddy: "drop.fill"
        case .wet: "cloud.rain"
        case .icy: "snowflake"
        case .overgrown: "leaf.fill"
        case .closed: "xmark.octagon"
        }
    }

    var color: String {
        switch self {
        case .great: "green"
        case .good: "green"
        case .muddy: "brown"
        case .wet: "blue"
        case .icy: "cyan"
        case .overgrown: "orange"
        case .closed: "red"
        }
    }

    var trailStatus: TrailStatus {
        switch self {
        case .great, .good: .open
        case .muddy, .wet, .icy, .overgrown: .warning
        case .closed: .closed
        }
    }
}

struct ConditionReport: Codable, Identifiable {
    let id: String
    let routeId: String
    let condition: RideCondition
    let note: String?
    let reportedAt: Date
    var synced: Bool
}
