//
//  RadioPeer.swift
//  StoneBC
//
//  Represents a connected rider in Rally Radio
//

import Foundation

struct RadioPeer: Identifiable, Hashable {
    let id: String          // MCPeerID.displayName
    let displayName: String
    var isTransmitting: Bool = false

    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}
