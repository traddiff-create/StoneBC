//
//  RadioChannel.swift
//  StoneBC
//
//  A Rally Radio channel that riders join for group communication
//

import Foundation

struct RadioChannel: Identifiable {
    let id: UUID
    let name: String
    var peers: [RadioPeer] = []
    var isActive: Bool = false

    static let `default` = RadioChannel(
        id: UUID(),
        name: "Group Ride"
    )
}
