package com.traddiff.stonebc.storage

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

private val Context.rideHistoryDataStore by preferencesDataStore(name = "ride_history")

@Serializable
data class RideEntry(
    val id: String,
    val date: String,
    val distanceMiles: Double,
    val elevationGainFeet: Int,
    val durationSeconds: Long,
    val routeId: String? = null
)

class RideHistoryStore(private val context: Context) {

    private val json = Json { ignoreUnknownKeys = true }
    private val entriesKey = stringPreferencesKey("entries_json")
    private val lastUpdatedKey = longPreferencesKey("last_updated")

    val entries: Flow<List<RideEntry>> =
        context.rideHistoryDataStore.data.map { prefs ->
            prefs[entriesKey]?.let { decode(it) } ?: emptyList()
        }

    suspend fun addRide(entry: RideEntry) {
        context.rideHistoryDataStore.edit { prefs ->
            val current = prefs[entriesKey]?.let { decode(it) } ?: emptyList()
            prefs[entriesKey] = json.encodeToString(
                kotlinx.serialization.builtins.ListSerializer(RideEntry.serializer()),
                current + entry
            )
            prefs[lastUpdatedKey] = System.currentTimeMillis()
        }
    }

    suspend fun clear() {
        context.rideHistoryDataStore.edit { it.clear() }
    }

    private fun decode(text: String): List<RideEntry> =
        runCatching {
            json.decodeFromString(
                kotlinx.serialization.builtins.ListSerializer(RideEntry.serializer()),
                text
            )
        }.getOrDefault(emptyList())
}

data class SeasonSummary(
    val rideCount: Int,
    val totalMiles: Double,
    val totalElevationFeet: Int
) {
    companion object {
        val Empty = SeasonSummary(0, 0.0, 0)

        fun from(entries: List<RideEntry>): SeasonSummary = SeasonSummary(
            rideCount = entries.size,
            totalMiles = entries.sumOf { it.distanceMiles },
            totalElevationFeet = entries.sumOf { it.elevationGainFeet }
        )
    }
}
