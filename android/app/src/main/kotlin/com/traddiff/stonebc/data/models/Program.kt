package com.traddiff.stonebc.data.models

import kotlinx.serialization.Serializable

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
