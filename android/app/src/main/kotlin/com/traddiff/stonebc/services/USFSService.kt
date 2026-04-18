package com.traddiff.stonebc.services

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.URL
import java.net.URLEncoder

data class TrailClosure(
    val trailName: String,
    val trailNumber: String?,
    val status: String,
    val isClosed: Boolean,
    val source: String = "USFS"
)

// No API key needed — free public ArcGIS endpoint for Black Hills NF
object USFSService {
    private const val BASE_URL = "https://apps.fs.usda.gov/arcx/rest/services/EDW/EDW_TrailActivityData_01/MapServer/0/query"
    private const val CACHE_EXPIRY_MS = 24 * 60 * 60 * 1000L // 24 hours

    private data class CachedResult(val closures: List<TrailClosure>, val fetchedAt: Long)
    private val cache = mutableMapOf<String, CachedResult>()

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun closures(minLat: Double, minLon: Double, maxLat: Double, maxLon: Double): List<TrailClosure> {
        val cacheKey = "$minLat,$minLon,$maxLat,$maxLon"
        val cached = cache[cacheKey]
        if (cached != null && System.currentTimeMillis() - cached.fetchedAt < CACHE_EXPIRY_MS) {
            return cached.closures
        }
        return withContext(Dispatchers.IO) {
            try {
                val geom = URLEncoder.encode("$minLon,$minLat,$maxLon,$maxLat", "UTF-8")
                val fields = URLEncoder.encode("TRAIL_NAME,TRAIL_NO,TRAIL_STATUS,ACCESSIBILITY_STATUS", "UTF-8")
                val url = "$BASE_URL?where=1%3D1&geometry=$geom&geometryType=esriGeometryEnvelope" +
                    "&inSR=4326&spatialRel=esriSpatialRelIntersects&outFields=$fields&returnGeometry=false&f=json"
                val text = URL(url).readText()
                val response = json.decodeFromString<ArcGISResponse>(text)
                val closures = response.features.mapNotNull { feature ->
                    val name = feature.attributes.TRAIL_NAME ?: return@mapNotNull null
                    val status = feature.attributes.TRAIL_STATUS ?: return@mapNotNull null
                    val isClosed = status.lowercase().let { it.contains("closed") || it.contains("decommission") }
                    TrailClosure(
                        trailName = name,
                        trailNumber = feature.attributes.TRAIL_NO,
                        status = status,
                        isClosed = isClosed
                    )
                }
                cache[cacheKey] = CachedResult(closures, System.currentTimeMillis())
                closures
            } catch (_: Exception) {
                emptyList()
            }
        }
    }

    @Serializable private data class ArcGISResponse(val features: List<ArcGISFeature> = emptyList())
    @Serializable private data class ArcGISFeature(val attributes: ArcGISAttributes)
    @Serializable private data class ArcGISAttributes(
        val TRAIL_NAME: String? = null,
        val TRAIL_NO: String? = null,
        val TRAIL_STATUS: String? = null,
        val ACCESSIBILITY_STATUS: String? = null
    )
}
