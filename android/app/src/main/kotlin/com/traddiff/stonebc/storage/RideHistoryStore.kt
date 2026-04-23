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
    val routeName: String = "Recorded Ride",
    val category: String = "road",
    val distanceMiles: Double,
    val elevationGainFeet: Int,
    val durationSeconds: Long,
    val movingSeconds: Long = 0,
    val avgSpeedMph: Double = 0.0,
    val maxSpeedMph: Double = 0.0,
    val routeId: String? = null,
    val gpxTrackpoints: List<List<Double>>? = null
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

data class AllTimeSummary(
    val rideCount: Int,
    val totalMiles: Double,
    val totalElevationFeet: Int
) {
    companion object {
        val Empty = AllTimeSummary(0, 0.0, 0)

        fun from(entries: List<RideEntry>): AllTimeSummary = AllTimeSummary(
            rideCount = entries.size,
            totalMiles = entries.sumOf { it.distanceMiles },
            totalElevationFeet = entries.sumOf { it.elevationGainFeet }
        )
    }
}

data class PersonalRecords(
    val longestMiles: Double,
    val fastestAvgMph: Double,
    val mostElevationFeet: Int,
    val longestStreakDays: Int
) {
    companion object {
        val Empty = PersonalRecords(0.0, 0.0, 0, 0)

        fun from(entries: List<RideEntry>): PersonalRecords {
            if (entries.isEmpty()) return Empty
            val streak = longestStreak(entries)
            return PersonalRecords(
                longestMiles = entries.maxOf { it.distanceMiles },
                fastestAvgMph = entries.maxOf { it.avgSpeedMph },
                mostElevationFeet = entries.maxOf { it.elevationGainFeet },
                longestStreakDays = streak
            )
        }

        private fun longestStreak(entries: List<RideEntry>): Int {
            val dates = entries.mapNotNull { e ->
                runCatching { java.time.LocalDate.parse(e.date) }.getOrNull()
            }.toSortedSet()
            if (dates.isEmpty()) return 0
            var best = 1
            var current = 1
            var prev = dates.first()
            for (date in dates.drop(1)) {
                current = if (date == prev.plusDays(1)) current + 1 else 1
                if (current > best) best = current
                prev = date
            }
            return best
        }
    }
}

fun monthlyMiles(entries: List<RideEntry>): List<Pair<String, Double>> {
    val today = java.time.LocalDate.now()
    return (11 downTo 0).map { monthsBack ->
        val month = today.minusMonths(monthsBack.toLong())
        val label = month.month.getDisplayName(java.time.format.TextStyle.SHORT, java.util.Locale.getDefault())
        val miles = entries.filter { e ->
            runCatching {
                val d = java.time.LocalDate.parse(e.date)
                d.year == month.year && d.monthValue == month.monthValue
            }.getOrDefault(false)
        }.sumOf { it.distanceMiles }
        label to miles
    }
}
