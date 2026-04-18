package com.traddiff.stonebc.data

import androidx.compose.runtime.Stable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.traddiff.stonebc.data.models.AppConfig
import com.traddiff.stonebc.data.models.Bike
import com.traddiff.stonebc.data.models.Event
import com.traddiff.stonebc.data.models.Photo
import com.traddiff.stonebc.data.models.Post
import com.traddiff.stonebc.data.models.Program
import com.traddiff.stonebc.data.models.Route
import com.traddiff.stonebc.data.models.TourGuide
import com.traddiff.stonebc.services.TrailforksService
import com.traddiff.stonebc.services.WeatherService
import com.traddiff.stonebc.services.StravaService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

@Stable
class AppState(
    private val repository: AssetsRepository,
    val rideHistoryStore: com.traddiff.stonebc.storage.RideHistoryStore,
    val onboardingStore: com.traddiff.stonebc.storage.OnboardingStore
) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    var isLoading by mutableStateOf(true)
        private set
    var config by mutableStateOf(AppConfig.Default)
        private set
    var bikes by mutableStateOf<List<Bike>>(emptyList())
        private set
    var posts by mutableStateOf<List<Post>>(emptyList())
        private set
    var events by mutableStateOf<List<Event>>(emptyList())
        private set
    var programs by mutableStateOf<List<Program>>(emptyList())
        private set
    var photos by mutableStateOf<List<Photo>>(emptyList())
        private set
    var tourGuides by mutableStateOf<List<TourGuide>>(emptyList())
        private set
    var routes by mutableStateOf<List<Route>>(emptyList())
        private set

    val featuredBikes: List<Bike>
        get() = bikes.filter { it.isAvailable }.take(3)

    val recentPosts: List<Post>
        get() = posts.sortedByDescending { it.date }.take(3)

    val upcomingEvents: List<Event>
        get() = events.sortedBy { it.date }.take(3)

    fun load() {
        scope.launch {
            // Fire all 8 JSON loads in parallel. Each coroutine updates its
            // own state field as it completes, so Home can render bikes + posts
            // the instant they're ready instead of waiting for the 3.9MB routes
            // decode. The global `isLoading` flag is released when routes — the
            // slowest load — finishes, but individual screens should gate on
            // their own collections (e.g. routes.isEmpty()) rather than this.
            launch {
                config = repository.loadConfig()
                config.apiKeys?.let { keys ->
                    keys.openWeatherApiKey?.let { WeatherService.configure(it) }
                    val tfId = keys.trailforksAppId
                    val tfSecret = keys.trailforksAppSecret
                    if (tfId != null && tfSecret != null) TrailforksService.configure(tfId, tfSecret)
                    val stravaId = keys.stravaClientId
                    val stravaSecret = keys.stravaClientSecret
                    if (stravaId != null && stravaSecret != null) StravaService.configure(stravaId, stravaSecret)
                }
            }
            launch { bikes = repository.loadBikes() }
            launch { posts = repository.loadPosts() }
            launch { events = repository.loadEvents() }
            launch { programs = repository.loadPrograms() }
            launch { photos = repository.loadPhotos() }
            launch { tourGuides = repository.loadTourGuides() }
            launch {
                routes = repository.loadRoutes()
                isLoading = false
            }
        }
    }
}

val LocalAppState = compositionLocalOf<AppState> {
    error("AppState not provided. Wrap content in CompositionLocalProvider.")
}
