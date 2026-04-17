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
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

@Stable
class AppState(private val repository: AssetsRepository) {

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
            config = repository.loadConfig()
            bikes = repository.loadBikes()
            posts = repository.loadPosts()
            events = repository.loadEvents()
            programs = repository.loadPrograms()
            photos = repository.loadPhotos()
            tourGuides = repository.loadTourGuides()
            routes = repository.loadRoutes()
            isLoading = false
        }
    }
}

val LocalAppState = compositionLocalOf<AppState> {
    error("AppState not provided. Wrap content in CompositionLocalProvider.")
}
