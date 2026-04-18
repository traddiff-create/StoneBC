package com.traddiff.stonebc.services

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.URL
import java.time.Instant

data class WeatherForecast(
    val temp: Double,
    val feelsLike: Double,
    val condition: String,
    val icon: String,
    val windKph: Double,
    val humidity: Int,
    val timestamp: Long
)

object WeatherService {
    private const val BASE_URL = "https://api.openweathermap.org/data/2.5"
    private const val CACHE_EXPIRY_MS = 30 * 60 * 1000L // 30 minutes

    private var apiKey: String? = null
    val isConfigured: Boolean get() = apiKey != null

    private data class CachedForecast(val forecasts: List<WeatherForecast>, val fetchedAt: Long)
    private val cache = mutableMapOf<String, CachedForecast>()

    private val json = Json { ignoreUnknownKeys = true }

    fun configure(apiKey: String) {
        this.apiKey = apiKey
    }

    suspend fun forecast(lat: Double, lon: Double, cacheKey: String): List<WeatherForecast>? {
        val key = apiKey ?: return null
        val cached = cache[cacheKey]
        if (cached != null && System.currentTimeMillis() - cached.fetchedAt < CACHE_EXPIRY_MS) {
            return cached.forecasts
        }
        return withContext(Dispatchers.IO) {
            try {
                val url = "$BASE_URL/forecast?lat=$lat&lon=$lon&units=metric&cnt=8&appid=$key"
                val text = URL(url).readText()
                val response = json.decodeFromString<OWMForecastResponse>(text)
                val forecasts = response.list.map { item ->
                    WeatherForecast(
                        temp = item.main.temp,
                        feelsLike = item.main.feels_like,
                        condition = item.weather.firstOrNull()?.description?.replaceFirstChar { it.uppercase() } ?: "",
                        icon = item.weather.firstOrNull()?.icon ?: "",
                        windKph = item.wind.speed * 3.6,
                        humidity = item.main.humidity,
                        timestamp = item.dt
                    )
                }
                cache[cacheKey] = CachedForecast(forecasts, System.currentTimeMillis())
                forecasts
            } catch (_: Exception) {
                null
            }
        }
    }

    @Serializable private data class OWMForecastResponse(val list: List<OWMItem>)
    @Serializable private data class OWMItem(val dt: Long, val main: OWMMain, val weather: List<OWMWeather>, val wind: OWMWind)
    @Serializable private data class OWMMain(val temp: Double, val feels_like: Double, val humidity: Int)
    @Serializable private data class OWMWeather(val description: String, val icon: String)
    @Serializable private data class OWMWind(val speed: Double)
}
