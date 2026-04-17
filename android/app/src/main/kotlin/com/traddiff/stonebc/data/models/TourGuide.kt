package com.traddiff.stonebc.data.models

import kotlinx.serialization.Serializable

@Serializable
data class TourGuide(
    val id: String,
    val name: String,
    val subtitle: String = "",
    val description: String = "",
    val type: String = "event",
    val eventDate: String = "",
    val totalDays: Int = 1,
    val totalMiles: Double = 0.0,
    val totalElevation: Int = 0,
    val difficulty: String = "moderate",
    val category: String = "",
    val region: String = "",
    val notes: List<String> = emptyList(),
    val checklist: List<ChecklistItem>? = null,
    val days: List<TourDay> = emptyList()
)

@Serializable
data class ChecklistItem(
    val key: String,
    val category: String = "note",
    val title: String,
    val description: String = "",
    val mileEstimate: Double? = null
)

@Serializable
data class TourDay(
    val dayNumber: Int,
    val name: String,
    val date: String = "",
    val startTime: String = "",
    val startLocation: String = "",
    val startCoordinate: List<Double> = emptyList(),
    val totalMiles: Double = 0.0,
    val elevationGain: Int = 0,
    val estimatedDuration: String = "",
    val finishLocation: String = "",
    val routeFile: String? = null,
    val gpxURL: String? = null,
    val trackpoints: List<List<Double>>? = null,
    val stops: List<TourStop> = emptyList()
)

@Serializable
data class TourStop(
    val name: String,
    val type: String,
    val coordinate: List<Double> = emptyList(),
    val mileMarker: Double? = null,
    val description: String = "",
    val beer: String? = null
)
