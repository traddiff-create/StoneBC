package com.traddiff.stonebc.data.models

import kotlinx.serialization.Serializable

@Serializable
data class Event(
    val id: String,
    val title: String,
    val date: String,
    val location: String = "",
    val category: String = "ride",
    val description: String = "",
    val isRecurring: Boolean = false
)
