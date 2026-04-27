//
//  JourneyReadinessService.swift
//  StoneBC
//
//  Composes existing local services into one journey readiness snapshot.
//

import Foundation
import CoreLocation

enum JourneyReadinessService {
    static func evaluate(
        route: Route?,
        guide: TourGuide?,
        journal: ExpeditionJournal?
    ) async -> JourneyReadiness {
        var items: [JourneyReadinessItem] = []

        items.append(JourneyReadinessItem(
            id: "route-data",
            title: "Route Data",
            detail: route == nil ? "No route linked; scout or check-in mode recommended" :
                ((route?.isNavigable ?? false) ? "\(route?.clTrackpoints.count ?? 0) trackpoints ready" : "Route needs at least two trackpoints"),
            state: route == nil ? .warning : ((route?.isNavigable ?? false) ? .ready : .blocked),
            icon: "point.topleft.down.to.point.bottomright.curvepath"
        ))

        if let route {
            let offlineIndex = await OfflineRouteStorage.shared.loadIndex()
            let cached = offlineIndex.first { $0.routeId == route.id }
            let tilePack = await OfflineTilePackManager.shared.installedPack(forRouteId: route.id)
            items.append(JourneyReadinessItem(
                id: "offline-route",
                title: "Offline Route",
                detail: cached == nil ? "Route data not saved offline" : "Saved \(cached?.cachedAt.formatted(date: .abbreviated, time: .shortened) ?? "")",
                state: cached == nil ? .warning : .ready,
                icon: "arrow.down.circle"
            ))
            items.append(JourneyReadinessItem(
                id: "offline-tiles",
                title: "Offline Tiles",
                detail: tilePack?.formattedSize ?? (cached?.tilesAvailable == true ? "Bundled tile coverage available" : "Tile pack not installed"),
                state: tilePack != nil || cached?.tilesAvailable == true ? .ready : .warning,
                icon: "map"
            ))
            items.append(JourneyReadinessItem(
                id: "weather",
                title: "Weather Cache",
                detail: cached?.hasWeather == true ? "Cached route weather available" : "Refresh before departure if online",
                state: cached?.hasWeather == true ? .ready : .warning,
                icon: "cloud.sun"
            ))
            items.append(JourneyReadinessItem(
                id: "cues",
                title: "Cue Sheet",
                detail: route.cuePoints.isEmpty ? "No authored cues; follow the route line" : "\(route.cuePoints.count) cues ready",
                state: route.cuePoints.isEmpty ? .warning : .ready,
                icon: "arrow.turn.up.right"
            ))
        }

        items.append(JourneyReadinessItem(
            id: "cell",
            title: "Cell Coverage",
            detail: route == nil ? "Coverage map needs a linked route" : "Coverage layer available for route review",
            state: route == nil ? .warning : .ready,
            icon: "antenna.radiowaves.left.and.right"
        ))

        items.append(JourneyReadinessItem(
            id: "pack",
            title: "Pack List",
            detail: guide == nil ? "No guide pack profile linked" : "Guide-linked pack list available",
            state: guide == nil ? .warning : .ready,
            icon: "bag"
        ))

        items.append(JourneyReadinessItem(
            id: "journal",
            title: "Journal",
            detail: journal == nil ? "Start or select an expedition journal" : "Journal ready for camp review",
            state: journal == nil ? .warning : .ready,
            icon: "book.pages"
        ))

        items.append(JourneyReadinessItem(
            id: "battery",
            title: "Battery Policy",
            detail: ProcessInfo.processInfo.isLowPowerModeEnabled ? "Low Power Mode is on; endurance tracking active" : "Endurance mode recommended for remote days",
            state: .ready,
            icon: "battery.75"
        ))

        return JourneyReadiness(routeId: route?.id, generatedAt: Date(), items: items)
    }
}
