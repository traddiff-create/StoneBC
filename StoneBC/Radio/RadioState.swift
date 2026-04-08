//
//  RadioState.swift
//  StoneBC
//
//  Rally Radio state machine
//

import SwiftUI

enum RadioState: Equatable {
    case idle           // Radio off
    case connecting     // Searching for peers
    case connected      // In channel, listening
    case transmitting   // PTT active, sending audio
    case error(String)  // Something went wrong

    var label: String {
        switch self {
        case .idle: return "Off"
        case .connecting: return "Searching..."
        case .connected: return "Listening"
        case .transmitting: return "Transmitting"
        case .error(let msg): return msg
        }
    }

    var color: Color {
        switch self {
        case .idle: return .secondary
        case .connecting: return BCColors.brandAmber
        case .connected: return BCColors.brandGreen
        case .transmitting: return .red
        case .error: return .red
        }
    }

    var isActive: Bool {
        switch self {
        case .connected, .transmitting, .connecting: return true
        default: return false
        }
    }
}
