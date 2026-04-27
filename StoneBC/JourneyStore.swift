//
//  JourneyStore.swift
//  StoneBC
//
//  Tiny local persistence owner for the active journey console.
//

import Foundation
import CoreLocation

@Observable
final class JourneyStore {
    static let shared = JourneyStore()

    private let activeSessionKey = "activeJourneySession"
    private(set) var activeSession: JourneySession?

    private init() {
        activeSession = Self.loadSession(key: activeSessionKey)
    }

    func startJourney(
        title: String,
        route: Route? = nil,
        guide: TourGuide? = nil,
        journal: ExpeditionJournal? = nil
    ) {
        activeSession = JourneySession(
            title: title,
            routeId: route?.id,
            routeName: route?.name,
            guideId: guide?.id,
            guideName: guide?.name,
            journalId: journal?.id,
            journalName: journal?.name
        )
        persist()
    }

    func updatePowerProfile(_ profile: JourneyPowerProfile) {
        guard activeSession != nil else { return }
        activeSession?.powerProfile = profile
        persist()
    }

    func updateLastKnownLocation(_ coordinate: CLLocationCoordinate2D) {
        guard activeSession != nil else { return }
        activeSession?.lastKnownLatitude = coordinate.latitude
        activeSession?.lastKnownLongitude = coordinate.longitude
        activeSession?.lastKnownLocationAt = Date()
        persist()
    }

    func addDayReview(_ review: JourneyDayReview) {
        guard activeSession != nil else { return }
        activeSession?.dayReviews.insert(review, at: 0)
        persist()
    }

    func endJourney() {
        activeSession = nil
        UserDefaults.standard.removeObject(forKey: activeSessionKey)
    }

    private func persist() {
        guard let activeSession,
              let data = try? JSONEncoder().encode(activeSession) else { return }
        UserDefaults.standard.set(data, forKey: activeSessionKey)
    }

    private static func loadSession(key: String) -> JourneySession? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(JourneySession.self, from: data)
    }
}
