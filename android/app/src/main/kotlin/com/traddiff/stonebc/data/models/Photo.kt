package com.traddiff.stonebc.data.models

import kotlinx.serialization.Serializable

@Serializable
data class Photo(
    val id: String,
    val filename: String,
    val title: String,
    val category: String = "general"
)
