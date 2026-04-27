package com.traddiff.stonebc.shared.models

import kotlinx.serialization.Serializable
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

@Serializable
data class Trackpoint(
    val latitude: Double,
    val longitude: Double,
    val elevationMeters: Double?,
    val speedMetersPerSecond: Float?,
    val timestampMillis: Long
)

@Serializable
data class RideSession(
    val id: String,
    val startTimestamp: Long,
    val trackpoints: List<Trackpoint> = emptyList(),
    val isPaused: Boolean = false,
    val recordingMode: RouteRecordingMode = RouteRecordingMode.free,
    val routeId: String? = null,
    val routeName: String? = null,
    val routeCategory: String? = null
) {
    val distanceMeters: Double
        get() = trackpoints.zipWithNext { a, b -> haversine(a, b) }.sum()

    val distanceMiles: Double
        get() = distanceMeters * METERS_TO_MILES

    val elevationGainMeters: Double
        get() = trackpoints.zipWithNext { a, b ->
            val delta = (b.elevationMeters ?: 0.0) - (a.elevationMeters ?: 0.0)
            if (delta > 0) delta else 0.0
        }.sum()

    val elevationGainFeet: Int get() = (elevationGainMeters * METERS_TO_FEET).toInt()

    val durationSeconds: Long
        get() = ((trackpoints.lastOrNull()?.timestampMillis ?: startTimestamp) - startTimestamp) / 1000

    val currentSpeedMetersPerSecond: Float
        get() = trackpoints.lastOrNull()?.speedMetersPerSecond ?: 0f

    val currentSpeedMph: Float
        get() = currentSpeedMetersPerSecond * MPS_TO_MPH.toFloat()

    companion object {
        private const val EARTH_RADIUS_METERS = 6_371_000.0
        private const val METERS_TO_MILES = 0.000621371
        private const val METERS_TO_FEET = 3.28084
        private const val MPS_TO_MPH = 2.236936

        private fun haversine(a: Trackpoint, b: Trackpoint): Double {
            val lat1 = Math.toRadians(a.latitude)
            val lat2 = Math.toRadians(b.latitude)
            val dLat = lat2 - lat1
            val dLon = Math.toRadians(b.longitude - a.longitude)
            val h = sin(dLat / 2).let { it * it } +
                cos(lat1) * cos(lat2) * sin(dLon / 2).let { it * it }
            return EARTH_RADIUS_METERS * 2 * atan2(sqrt(h), sqrt(1 - h))
        }
    }
}
