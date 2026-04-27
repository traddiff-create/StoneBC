package com.traddiff.stonebc.shared.models

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

@Serializable
data class Photo(
    val id: String,
    val filename: String,
    val title: String,
    val category: String = "general"
)

@Serializable
data class Post(
    val id: String,
    val title: String,
    val body: String,
    val imageURL: String? = null,
    val date: String,
    val category: String = "news"
)

@Serializable
data class Program(
    val id: String,
    val name: String,
    val description: String,
    val icon: String = "",
    val details: List<String> = emptyList(),
    val schedule: String = "",
    val eligibility: String = ""
)
