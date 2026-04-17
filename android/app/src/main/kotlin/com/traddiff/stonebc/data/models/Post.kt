package com.traddiff.stonebc.data.models

import kotlinx.serialization.Serializable

@Serializable
data class Post(
    val id: String,
    val title: String,
    val body: String,
    val imageURL: String? = null,
    val date: String,
    val category: String = "news"
)
