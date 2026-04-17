package com.traddiff.stonebc.data.models

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
    val gpxURL: String? = null,
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
