//
//  NavigationAudioService.swift
//  StoneBC
//
//  AVSpeechSynthesizer navigation cues — turn alerts, off-route warnings,
//  milestone callouts. Works over AirPods, mixes with music.
//

import AVFoundation
import CoreLocation

@Observable
class NavigationAudioService {
    var isEnabled = true
    var lastSpokenMessage: String?

    private let synthesizer = AVSpeechSynthesizer()
    private var lastMilestone: Int = 0
    private var lastOffRouteAlert: Date?
    private var lastTurnAlert: Date?

    // Cooldowns to prevent spam
    private var offRouteCooldown: TimeInterval = 30
    private var turnCooldown: TimeInterval = 15
    private var milestoneStrideMiles = 5

    init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .voicePrompt, options: [.mixWithOthers, .duckOthers])
        } catch {
            // Audio session setup failed — cues will be silent
        }
    }

    // MARK: - Navigation Events

    func configure(for powerMode: RidePowerMode) {
        milestoneStrideMiles = powerMode.audioMilestoneMiles
        switch powerMode {
        case .highDetail:
            offRouteCooldown = 30
            turnCooldown = 15
        case .balanced:
            offRouteCooldown = 45
            turnCooldown = 25
        case .endurance:
            offRouteCooldown = 90
            turnCooldown = 45
        }
    }

    /// Called when user goes off-route
    func announceOffRoute(distanceMeters: Double) {
        guard isEnabled else { return }
        guard lastOffRouteAlert == nil || Date().timeIntervalSince(lastOffRouteAlert!) > offRouteCooldown else { return }

        let distFeet = Int(distanceMeters * 3.28084)
        speak("Off route. You are \(distFeet) feet from the trail.")
        lastOffRouteAlert = Date()
    }

    /// Called when user returns to route after being off
    func announceBackOnRoute() {
        guard isEnabled else { return }
        speak("Back on route.")
        lastOffRouteAlert = nil
    }

    /// Called at distance milestones
    func checkMilestone(distanceMiles: Double, totalMiles: Double) {
        guard isEnabled else { return }

        let currentMile = Int(distanceMiles)
        guard currentMile > lastMilestone else { return }
        lastMilestone = currentMile

        let remaining = totalMiles - distanceMiles

        // Announce every 5 miles, or at halfway, or near finish
        if currentMile % milestoneStrideMiles == 0 {
            speak("Mile \(currentMile). \(String(format: "%.1f", remaining)) miles remaining.")
        } else if abs(distanceMiles - totalMiles / 2) < 0.5 {
            speak("Halfway point. \(String(format: "%.1f", remaining)) miles to go.")
        } else if remaining < 1.0 && remaining > 0.3 {
            speak("Almost there. Less than a mile to the finish.")
        }
    }

    /// Called when approaching a turn detected from trackpoint geometry
    func announceTurn(direction: TurnDirection, distanceAhead: Double) {
        guard isEnabled else { return }
        guard lastTurnAlert == nil || Date().timeIntervalSince(lastTurnAlert!) > turnCooldown else { return }

        let distFeet = Int(distanceAhead * 3.28084)

        switch direction {
        case .sharpLeft:
            speak("Sharp left turn in \(distFeet) feet.")
        case .left:
            speak("Turn left in \(distFeet) feet.")
        case .slightLeft:
            speak("Bear left in \(distFeet) feet.")
        case .straight:
            break // no announcement
        case .slightRight:
            speak("Bear right in \(distFeet) feet.")
        case .right:
            speak("Turn right in \(distFeet) feet.")
        case .sharpRight:
            speak("Sharp right turn in \(distFeet) feet.")
        }

        lastTurnAlert = Date()
    }

    /// Called when ride ends
    func announceRideComplete(distance: Double, time: String) {
        guard isEnabled else { return }
        speak("Ride complete. \(String(format: "%.1f", distance)) miles in \(time).")
    }

    /// Called when the recording auto-pauses because the rider has been stationary.
    func announcePaused() {
        guard isEnabled else { return }
        speak("Recording paused.")
    }

    /// Called when the recording auto-resumes as the rider starts moving again.
    func announceResumed() {
        guard isEnabled else { return }
        speak("Recording resumed.")
    }

    // MARK: - Turn Detection

    /// Analyze trackpoints ahead to detect upcoming turns
    static func detectTurn(trackpoints: [CLLocationCoordinate2D], currentIndex: Int, lookAhead: Int = 20) -> (direction: TurnDirection, distanceMeters: Double)? {
        let start = currentIndex
        let mid = min(currentIndex + lookAhead / 2, trackpoints.count - 1)
        let end = min(currentIndex + lookAhead, trackpoints.count - 1)

        guard end > mid, mid > start else { return nil }

        let bearing1 = bearing(from: trackpoints[start], to: trackpoints[mid])
        let bearing2 = bearing(from: trackpoints[mid], to: trackpoints[end])

        var angleDiff = bearing2 - bearing1
        if angleDiff > 180 { angleDiff -= 360 }
        if angleDiff < -180 { angleDiff += 360 }

        // Calculate distance to the turn point
        let turnLoc = CLLocation(latitude: trackpoints[mid].latitude, longitude: trackpoints[mid].longitude)
        let currentLoc = CLLocation(latitude: trackpoints[start].latitude, longitude: trackpoints[start].longitude)
        let distance = currentLoc.distance(from: turnLoc)

        let direction = TurnDirection.from(angle: angleDiff)
        guard direction != .straight else { return nil }

        return (direction, distance)
    }

    // MARK: - Private

    private func speak(_ message: String) {
        // Cancel any in-progress speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .word)
        }

        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = 0.52 // slightly faster than default
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.9

        synthesizer.speak(utterance)
        lastSpokenMessage = message
    }

    private static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    func reset() {
        lastMilestone = 0
        lastOffRouteAlert = nil
        lastTurnAlert = nil
    }
}

// MARK: - Turn Direction

enum TurnDirection {
    case sharpLeft, left, slightLeft, straight, slightRight, right, sharpRight

    static func from(angle: Double) -> TurnDirection {
        switch angle {
        case ..<(-120): return .sharpLeft
        case -120..<(-45): return .left
        case -45..<(-15): return .slightLeft
        case -15...15: return .straight
        case 15..<45: return .slightRight
        case 45..<120: return .right
        default: return .sharpRight
        }
    }
}
