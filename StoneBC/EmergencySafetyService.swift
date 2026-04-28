//
//  EmergencySafetyService.swift
//  StoneBC
//
//  Emergency safety features — satellite SOS detection, emergency contact
//  notification, and last-known GPS broadcasting.
//
//  Apple Satellite SOS: Available on iPhone 14+ (no developer API yet,
//  expected 2026-2027). This service detects capability and provides
//  deep links to Settings > Emergency SOS.
//

import Foundation
import CoreLocation
import UIKit
import UserNotifications

@Observable
class EmergencySafetyService {
    static let shared = EmergencySafetyService()

    enum CheckInState: String {
        case inactive
        case active
        case overdue
    }

    var emergencyContact: EmergencyContact?
    var lastKnownLocation: CLLocationCoordinate2D?
    var lastLocationTimestamp: Date?
    var checkInState: CheckInState = .inactive
    var checkInDeadline: Date?
    var lastCheckInAt: Date?
    var activeRouteName: String?
    var onCheckInStateChanged: ((CheckInState) -> Void)?

    private let storageKey = "emergencyContact"
    private var checkInInterval: TimeInterval = RideTuning.safetyCheckInIntervalSeconds
    private var checkInTimer: Timer?

    /// Whether device supports satellite SOS (iPhone 14+)
    var supportsSatelliteSOS: Bool {
        // Detect by checking iOS version + device model
        // Satellite SOS requires iPhone 14 or later running iOS 16.1+
        if #available(iOS 16.1, *) {
            // Check if the device model supports satellite
            var systemInfo = utsname()
            uname(&systemInfo)
            let model = withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(validatingCString: $0)
                }
            } ?? ""

            // iPhone 14 = iPhone15,x; iPhone 15 = iPhone16,x; iPhone 16 = iPhone17,x; iPhone 17 = iPhone18,x
            if let range = model.range(of: "iPhone(\\d+)", options: .regularExpression),
               let number = Int(model[range].dropFirst(6)) {
                return number >= 15 // iPhone 14 and later
            }
        }
        return false
    }

    private init() {
        loadContact()
    }

    // MARK: - Emergency Contact

    func setEmergencyContact(name: String, phone: String) {
        emergencyContact = EmergencyContact(name: name, phone: phone)
        saveContact()
    }

    func clearEmergencyContact() {
        emergencyContact = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - Location Tracking

    /// Update last known location (called from LocationService)
    func updateLocation(_ coordinate: CLLocationCoordinate2D) {
        lastKnownLocation = coordinate
        lastLocationTimestamp = Date()
    }

    // MARK: - Local Check-In Timer

    func startCheckInTimer(routeName: String?, interval: TimeInterval = RideTuning.safetyCheckInIntervalSeconds) {
        checkInTimer?.invalidate()
        checkInInterval = interval
        activeRouteName = routeName
        lastCheckInAt = Date()
        checkInDeadline = Date().addingTimeInterval(interval)
        setCheckInState(.active, notifyUnchanged: true)

        checkInTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.refreshCheckInState()
        }
    }

    func checkIn(at date: Date = Date()) {
        guard checkInState != .inactive else { return }
        lastCheckInAt = date
        checkInDeadline = date.addingTimeInterval(checkInInterval)
        setCheckInState(.active, notifyUnchanged: true)
        scheduleCheckInNotification()
    }

    func stopCheckInTimer() {
        checkInTimer?.invalidate()
        checkInTimer = nil
        setCheckInState(.inactive)
        checkInDeadline = nil
        lastCheckInAt = nil
        activeRouteName = nil
    }

    private func refreshCheckInState(at date: Date = Date()) {
        guard let deadline = checkInDeadline else {
            setCheckInState(.inactive)
            return
        }
        setCheckInState(date >= deadline ? .overdue : .active)
    }

    private func setCheckInState(_ state: CheckInState, notifyUnchanged: Bool = false) {
        guard checkInState != state else {
            if notifyUnchanged {
                onCheckInStateChanged?(state)
            }
            return
        }
        checkInState = state
        onCheckInStateChanged?(state)
    }

    var formattedCheckInRemaining: String {
        guard checkInState != .inactive, let deadline = checkInDeadline else { return "" }
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else { return "OVERDUE" }
        let minutes = Int(ceil(remaining / 60))
        return "\(minutes)m"
    }

    func scheduleCheckInNotification() {
        guard checkInState != .inactive, let deadline = checkInDeadline else { return }

        let content = UNMutableNotificationContent()
        content.title = "Journey Check-In"
        content.body = activeRouteName.map { "Confirm you are OK on \($0)." } ?? "Confirm you are OK."
        content.sound = .default
        content.categoryIdentifier = "JOURNEY_CHECK_IN"

        let interval = max(5, deadline.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "journey-check-in",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["journey-check-in"])
        UNUserNotificationCenter.current().add(request)
    }

    /// Format last known location for emergency text
    var emergencyLocationText: String {
        guard let loc = lastKnownLocation, let time = lastLocationTimestamp else {
            return "Location unknown"
        }

        let age = Date().timeIntervalSince(time)
        let ageStr: String
        if age < 60 { ageStr = "just now" }
        else if age < 3600 { ageStr = "\(Int(age / 60))m ago" }
        else { ageStr = "\(Int(age / 3600))h ago" }

        return "Last GPS: \(loc.latitude), \(loc.longitude) (\(ageStr))"
    }

    /// Apple Maps URL for last known location
    var emergencyMapURL: URL? {
        guard let loc = lastKnownLocation else { return nil }
        return URL(string: "https://maps.apple.com/?ll=\(loc.latitude),\(loc.longitude)&q=Rider%20Location")
    }

    // MARK: - Emergency Actions

    /// Compose emergency SMS text (for use with MFMessageComposeViewController or SMS URL)
    var emergencySMSBody: String {
        var body = "SOS — I need help on a bike ride.\n"
        if let activeRouteName {
            body += "Route: \(activeRouteName)\n"
        }
        body += emergencyLocationText
        if let url = emergencyMapURL {
            body += "\nMap: \(url.absoluteString)"
        }
        body += "\n\nSent via Stone Bicycle Coalition app"
        return body
    }

    /// SMS URL for emergency contact
    var emergencySMSURL: URL? {
        guard let contact = emergencyContact else { return nil }
        let body = emergencySMSBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "sms:\(contact.phone)&body=\(body)")
    }

    /// Open Settings > Emergency SOS for satellite setup
    func openEmergencySOSSettings() {
        if let url = URL(string: "App-prefs:EMERGENCY_SOS") {
            UIApplication.shared.open(url)
        }
    }

    /// Call 911
    func call911() {
        if let url = URL(string: "tel://911") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Persistence

    private func saveContact() {
        if let contact = emergencyContact,
           let data = try? JSONEncoder().encode(contact) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadContact() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let contact = try? JSONDecoder().decode(EmergencyContact.self, from: data) {
            emergencyContact = contact
        }
    }
}

// MARK: - Model

struct EmergencyContact: Codable {
    let name: String
    let phone: String
}
