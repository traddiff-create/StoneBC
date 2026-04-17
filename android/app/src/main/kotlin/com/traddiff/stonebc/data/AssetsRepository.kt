package com.traddiff.stonebc.data

import android.content.Context
import com.traddiff.stonebc.data.models.AppConfig
import com.traddiff.stonebc.data.models.Bike
import com.traddiff.stonebc.data.models.BikesFile
import com.traddiff.stonebc.data.models.Event
import com.traddiff.stonebc.data.models.Photo
import com.traddiff.stonebc.data.models.Post
import com.traddiff.stonebc.data.models.Program
import com.traddiff.stonebc.data.models.Route
import com.traddiff.stonebc.data.models.TourGuide
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json

class AssetsRepository(private val context: Context) {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        coerceInputValues = true
    }

    suspend fun loadConfig(): AppConfig = decode("config.json", AppConfig.Default)

    suspend fun loadBikes(): List<Bike> =
        decodeOrEmpty<BikesFile>("bikes.json")?.bikes ?: emptyList()

    suspend fun loadPosts(): List<Post> = decodeListOrEmpty("posts.json")

    suspend fun loadEvents(): List<Event> = decodeListOrEmpty("events.json")

    suspend fun loadPrograms(): List<Program> = decodeListOrEmpty("programs.json")

    suspend fun loadPhotos(): List<Photo> = decodeListOrEmpty("photos.json")

    suspend fun loadTourGuides(): List<TourGuide> = decodeListOrEmpty("guides.json")

    suspend fun loadRoutes(): List<Route> = decodeListOrEmpty("routes.json")

    private suspend inline fun <reified T> decode(fileName: String, fallback: T): T =
        decodeOrEmpty<T>(fileName) ?: fallback

    private suspend inline fun <reified T> decodeOrEmpty(fileName: String): T? =
        withContext(Dispatchers.IO) {
            runCatching {
                val text = context.assets.open(fileName).bufferedReader().use { it.readText() }
                json.decodeFromString<T>(text)
            }.onFailure { android.util.Log.e("AssetsRepo", "Failed to load $fileName", it) }
                .getOrNull()
        }

    private suspend inline fun <reified T> decodeListOrEmpty(fileName: String): List<T> =
        decodeOrEmpty<List<T>>(fileName) ?: emptyList()
}
