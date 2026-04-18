package com.traddiff.stonebc.services

import android.content.Context
import android.content.Intent
import android.net.Uri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.OutputStreamWriter
import java.net.URL
import java.net.HttpURLConnection

data class StravaSegment(
    val id: Long,
    val name: String,
    val distanceM: Double,
    val avgGradePct: Double,
    val climbCategoryDesc: String
)

object StravaService {
    private const val AUTH_URL = "https://www.strava.com/oauth/mobile/authorize"
    private const val TOKEN_URL = "https://www.strava.com/api/v3/oauth/token"
    private const val SEGMENTS_URL = "https://www.strava.com/api/v3/segments/explore"
    private const val REDIRECT_URI = "com.traddiff.stonebc://oauth2callback"
    private const val PREFS_NAME = "stonebc_strava"
    private const val KEY_ACCESS_TOKEN = "access_token"
    private const val KEY_REFRESH_TOKEN = "refresh_token"
    private const val KEY_ATHLETE_NAME = "athlete_name"
    private const val CACHE_EXPIRY_MS = 7 * 24 * 60 * 60 * 1000L // 7 days

    private var clientId: String? = null
    private var clientSecret: String? = null
    val isConfigured: Boolean get() = clientId != null && clientSecret != null

    private data class CachedSegments(val segments: List<StravaSegment>, val fetchedAt: Long)
    private val segmentCache = mutableMapOf<String, CachedSegments>()

    private val json = Json { ignoreUnknownKeys = true }

    // Called by MainActivity.onNewIntent when Strava redirects back
    var pendingAuthCallback: ((code: String) -> Unit)? = null

    fun configure(clientId: String, clientSecret: String) {
        this.clientId = clientId
        this.clientSecret = clientSecret
    }

    fun isAuthenticated(context: Context): Boolean =
        prefs(context).getString(KEY_ACCESS_TOKEN, null) != null

    fun athleteName(context: Context): String? =
        prefs(context).getString(KEY_ATHLETE_NAME, null)

    fun startAuth(context: Context) {
        val id = clientId ?: return
        val uri = Uri.parse(AUTH_URL).buildUpon()
            .appendQueryParameter("client_id", id)
            .appendQueryParameter("redirect_uri", REDIRECT_URI)
            .appendQueryParameter("response_type", "code")
            .appendQueryParameter("approval_prompt", "auto")
            .appendQueryParameter("scope", "read,activity:read")
            .build()
        context.startActivity(Intent(Intent.ACTION_VIEW, uri).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }

    suspend fun handleAuthCode(code: String, context: Context): Boolean {
        val id = clientId ?: return false
        val secret = clientSecret ?: return false
        return withContext(Dispatchers.IO) {
            try {
                val body = "client_id=$id&client_secret=$secret&code=$code&grant_type=authorization_code"
                val conn = (URL(TOKEN_URL).openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    doOutput = true
                    setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                }
                OutputStreamWriter(conn.outputStream).use { it.write(body) }
                val text = conn.inputStream.bufferedReader().readText()
                val response = json.decodeFromString<StravaTokenResponse>(text)
                prefs(context).edit()
                    .putString(KEY_ACCESS_TOKEN, response.access_token)
                    .putString(KEY_REFRESH_TOKEN, response.refresh_token)
                    .putString(KEY_ATHLETE_NAME, "${response.athlete.firstname} ${response.athlete.lastname}".trim())
                    .apply()
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    suspend fun segments(lat: Double, lon: Double, routeId: String, context: Context): List<StravaSegment>? {
        val token = prefs(context).getString(KEY_ACCESS_TOKEN, null) ?: return null
        val cached = segmentCache[routeId]
        if (cached != null && System.currentTimeMillis() - cached.fetchedAt < CACHE_EXPIRY_MS) {
            return cached.segments
        }
        return withContext(Dispatchers.IO) {
            try {
                val pad = 0.05
                val bounds = "${lat - pad},${lon - pad},${lat + pad},${lon + pad}"
                val url = "$SEGMENTS_URL?bounds=$bounds&activity_type=riding"
                val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                    setRequestProperty("Authorization", "Bearer $token")
                }
                val text = conn.inputStream.bufferedReader().readText()
                val response = json.decodeFromString<StravaSegmentsResponse>(text)
                val segments = response.segments.map { s ->
                    StravaSegment(
                        id = s.id,
                        name = s.name,
                        distanceM = s.distance,
                        avgGradePct = s.avg_grade,
                        climbCategoryDesc = s.climb_category_desc ?: "NC"
                    )
                }
                segmentCache[routeId] = CachedSegments(segments, System.currentTimeMillis())
                segments
            } catch (_: Exception) {
                null
            }
        }
    }

    fun disconnect(context: Context) {
        prefs(context).edit().clear().apply()
        segmentCache.clear()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    @Serializable private data class StravaTokenResponse(
        val access_token: String,
        val refresh_token: String,
        val athlete: StravaAthlete
    )
    @Serializable private data class StravaAthlete(val firstname: String = "", val lastname: String = "")
    @Serializable private data class StravaSegmentsResponse(val segments: List<StravaSegItem> = emptyList())
    @Serializable private data class StravaSegItem(
        val id: Long,
        val name: String,
        val distance: Double,
        val avg_grade: Double,
        val climb_category_desc: String? = null
    )
}
