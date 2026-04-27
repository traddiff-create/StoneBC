package com.traddiff.stonebc.shared.models

import kotlinx.serialization.Serializable

@Serializable
data class Route(
    val id: String,
    val name: String,
    val difficulty: String,
    val category: String,
    val distanceMiles: Double,
    val elevationGainFeet: Int,
    val region: String,
    val description: String = "",
    val startCoordinate: Coordinate,
    val trackpoints: List<List<Double>> = emptyList(),
    val cuePoints: List<CuePoint> = emptyList(),
    val gpxURL: String? = null,
    val rideDefaults: RouteRideDefaults? = null,
    val isImported: Boolean = false
) {
    @Serializable
    data class Coordinate(
        val latitude: Double,
        val longitude: Double
    )

    val difficultyRank: Int
        get() = when (difficulty.lowercase()) {
            "easy" -> 0
            "moderate" -> 1
            "hard" -> 2
            "expert" -> 3
            else -> 4
        }
}

@Serializable
data class CuePoint(
    val distanceMiles: Double? = null,
    val instruction: String = "",
    val coordinate: Route.Coordinate? = null
)

@Serializable
enum class RouteRecordingMode(val label: String, val subtitle: String) {
    free("Free Ride", "Record a new ride from scratch"),
    follow("Follow Route", "Record while riding an existing route"),
    scout("Scout Route", "Capture a route for cleanup and submission")
}

@Serializable
data class RouteRideDefaults(
    val enabledOverlays: List<RouteRideOverlay>? = null,
    val recommendedRecordingMode: RouteRecordingMode? = null,
    val offlinePriority: Boolean? = null,
    val cueVisibility: Boolean? = null,
    val safetyCheckInEnabled: Boolean? = null,
    val prepNotes: List<String>? = null
)

@Serializable
enum class RouteRideOverlay {
    routeLine,
    breadcrumbs,
    cues,
    offRouteAlerts,
    offlineStatus,
    weather,
    cellCoverage,
    nearbyStops,
    safetyCheckIn
}
