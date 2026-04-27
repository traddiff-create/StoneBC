package com.traddiff.stonebc.shared.models

import kotlinx.serialization.Serializable

@Serializable
data class BikesFile(val bikes: List<Bike>)

@Serializable
data class Bike(
    val id: String,
    val status: String,
    val model: String,
    val type: String,
    val frameSize: String = "",
    val wheelSize: String = "",
    val color: String = "",
    val condition: String = "",
    val features: List<String> = emptyList(),
    val photos: List<String> = emptyList(),
    val sponsorPrice: Int? = null,
    val description: String = "",
    val dateAdded: String = "",
    val acquiredVia: String = ""
) {
    val isAvailable: Boolean get() = status.equals("available", ignoreCase = true)
    val primaryPhoto: String? get() = photos.firstOrNull()
}
