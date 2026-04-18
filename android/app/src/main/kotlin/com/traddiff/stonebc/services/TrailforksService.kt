package com.traddiff.stonebc.services

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.URL

enum class TrailStatus(val value: Int) {
    OPEN(1), CLOSED(2), WARNING(3), UNKNOWN(0);
    companion object { fun fromInt(v: Int) = entries.firstOrNull { it.value == v } ?: UNKNOWN }
}

data class TrailCondition(
    val status: TrailStatus,
    val conditionText: String,
    val source: String = "Trailforks"
) {
    val displayLabel: String get() = when (status) {
        TrailStatus.OPEN -> conditionText.ifEmpty { "Open" }
        TrailStatus.CLOSED -> "Closed"
        TrailStatus.WARNING -> "Warning"
        TrailStatus.UNKNOWN -> "Unknown"
    }
}

object TrailforksService {
    private const val BASE_URL = "https://www.trailforks.com/api/1"
    private const val CACHE_EXPIRY_MS = 4 * 60 * 60 * 1000L // 4 hours

    private var appId: String? = null
    private var appSecret: String? = null
    val isConfigured: Boolean get() = appId != null && appSecret != null

    private data class CachedCondition(val condition: TrailCondition, val fetchedAt: Long)
    private val cache = mutableMapOf<String, CachedCondition>()

    private val json = Json { ignoreUnknownKeys = true }

    fun configure(appId: String, appSecret: String) {
        this.appId = appId
        this.appSecret = appSecret
    }

    suspend fun condition(lat: Double, lon: Double, routeId: String): TrailCondition? {
        val id = appId ?: return null
        val secret = appSecret ?: return null
        val cached = cache[routeId]
        if (cached != null && System.currentTimeMillis() - cached.fetchedAt < CACHE_EXPIRY_MS) {
            return cached.condition
        }
        return withContext(Dispatchers.IO) {
            try {
                val url = "$BASE_URL/trails?scope=nearby&lat=$lat&lon=$lon&radius=5000" +
                    "&fields=title,condition,status,difficulty&app_id=$id&app_secret=$secret"
                val text = URL(url).readText()
                val response = json.decodeFromString<TFResponse>(text)
                val trail = response.data.firstOrNull() ?: return@withContext null
                val condition = TrailCondition(
                    status = TrailStatus.fromInt(trail.status),
                    conditionText = trail.condition?.title ?: "Unknown"
                )
                cache[routeId] = CachedCondition(condition, System.currentTimeMillis())
                condition
            } catch (_: Exception) {
                null
            }
        }
    }

    @Serializable private data class TFResponse(val data: List<TFTrail>)
    @Serializable private data class TFTrail(val title: String? = null, val status: Int = 0, val condition: TFCondition? = null)
    @Serializable private data class TFCondition(val title: String? = null)
}
