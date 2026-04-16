//
//  EventNotificationService.swift
//  StoneBC
//
//  Local notifications for favorited routes and best ride windows.
//  Scheduled via UNUserNotificationCenter — no push server needed.
//

import Foundation
import UserNotifications

@Observable
class EventNotificationService {
    static let shared = EventNotificationService()

    var isAuthorized = false
    private(set) var favoriteRouteIds: Set<String> = []
    private let favoritesKey = "favoriteRouteIds"

    private init() {
        loadFavorites()
    }

    // MARK: - Authorization

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Favorites

    func toggleFavorite(routeId: String) {
        if favoriteRouteIds.contains(routeId) {
            favoriteRouteIds.remove(routeId)
        } else {
            favoriteRouteIds.insert(routeId)
        }
        saveFavorites()
    }

    func isFavorite(routeId: String) -> Bool {
        favoriteRouteIds.contains(routeId)
    }

    // MARK: - Schedule Notifications

    /// Schedule a notification for an event on a favorited route
    func scheduleEventNotification(
        eventTitle: String,
        routeName: String,
        eventDate: Date,
        routeId: String
    ) {
        guard isAuthorized, favoriteRouteIds.contains(routeId) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Event on \(routeName)"
        content.body = eventTitle
        content.sound = .default
        content.categoryIdentifier = "ROUTE_EVENT"

        // Notify 24 hours before event
        let triggerDate = eventDate.addingTimeInterval(-24 * 60 * 60)
        guard triggerDate > Date() else { return }

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "event-\(routeId)-\(eventDate.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Schedule a weekly "best ride window" notification
    func scheduleWeeklyRideWindow(routeName: String, windowDescription: String) {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Great Riding Weather"
        content.body = "\(routeName): \(windowDescription)"
        content.sound = .default
        content.categoryIdentifier = "RIDE_WINDOW"

        // Every Saturday at 7 AM
        var dateComponents = DateComponents()
        dateComponents.weekday = 7 // Saturday
        dateComponents.hour = 7

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "weekly-ride-window",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Remove all pending notifications
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Persistence

    private func loadFavorites() {
        if let ids = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            favoriteRouteIds = Set(ids)
        }
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteRouteIds), forKey: favoritesKey)
    }
}
