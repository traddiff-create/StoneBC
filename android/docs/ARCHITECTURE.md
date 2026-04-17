# StoneBC Android — Architecture

Compose + Material3, single-Activity with a NavHost. `@Stable` state holder in `data/AppState.kt` drives every screen via `CompositionLocal`. All data is bundled JSON (no backend call on launch); Room powers the Expedition Journal; DataStore persists onboarding flag + ride history summaries.

## Entry path

```
MainActivity (ComponentActivity)
  └─ setContent
      └─ AppState (remember, load JSON + Room)
          └─ LocalAppState.provides(appState)
              ├─ if !onboardingStore.hasCompleted  → OnboardingScreen
              └─ else                              → MainNavHost
```

`MainActivity.onCreate` collects `onboardingStore.hasCompleted` as Flow and gates the composition. `null` → empty screen briefly (DataStore warmup); `false` → 12-card `OnboardingScreen`; `true` → `MainNavHost`.

## State holder — `AppState`

```kotlin
@Stable
class AppState(
    val repository: AssetsRepository,
    val rideHistoryStore: RideHistoryStore,
    val onboardingStore: OnboardingStore
) {
    var config by mutableStateOf<AppConfig?>(null)
    var bikes by mutableStateOf<List<Bike>>(emptyList())
    var posts by mutableStateOf<List<Post>>(emptyList())
    var events by mutableStateOf<List<Event>>(emptyList())
    var programs by mutableStateOf<List<Program>>(emptyList())
    var photos by mutableStateOf<List<Photo>>(emptyList())
    var tourGuides by mutableStateOf<List<TourGuide>>(emptyList())
    var routes by mutableStateOf<List<Route>>(emptyList())
    var isLoading by mutableStateOf(true)

    fun load() {
        scope.launch {
            launch { config = repository.loadConfig() }
            launch { bikes = repository.loadBikes() }
            launch { posts = repository.loadPosts() }
            launch { events = repository.loadEvents() }
            launch { programs = repository.loadPrograms() }
            launch { photos = repository.loadPhotos() }
            launch { tourGuides = repository.loadTourGuides() }
            launch {
                routes = repository.loadRoutes()  // largest file (~531KB)
                isLoading = false
            }
        }
    }
}
```

The `isLoading` flag gates the Home tab only. Every other tab renders its own empty state — a lesson from the original 20s-blocking implementation where a single `isLoading` blocked all 5 tabs behind the slowest JSON file.

## Composition access

`data/LocalAppState.kt` defines `val LocalAppState = compositionLocalOf<AppState> { error("AppState not provided") }`. Every screen pulls state via `val state = LocalAppState.current`. No ViewModels — the `@Stable` holder + Compose recomposition is sufficient and keeps the iOS/Android parity clear (iOS uses `@Observable`).

## Navigation — `ui/navigation/MainNavHost.kt`

5-tab bottom navigation (`NavigationBar`):

| Tab | Route | Screen |
|---|---|---|
| Home | `home` | `HomeScreen` |
| Routes | `routes` | `RoutesScreen` → `route_detail/{id}` |
| Record | `record` | `RecordScreen` |
| Bikes | `bikes` | `BikesScreen` → `bike_detail/{id}` |
| More | `more` | `MoreScreen` + nested sub-screens |

Sub-screens under More (Community Feed, Events, Programs, Gallery, Tour Guides, Expedition Journal, Swiss Army Knife, Volunteer, Donate, Rally Radio disabled) are destinations in the same NavHost. System back pops the stack.

## Services

### `services/RecordingService.kt` — foreground GPS recording

`android:foregroundServiceType="location"` in `AndroidManifest.xml`. Subscribes to `FusedLocationProviderClient` at 1Hz, buffers points in-memory, posts a `STOP` pending-intent in the notification. On stop, hands points back to `AppState` for GPX export via `GPXExporter.kt`.

### `services/LocationService.kt` — one-shot location

Thin wrapper around `FusedLocationProviderClient` for non-recording needs (Home tab "nearest route" computation, navigation HUD bearing reference).

### `services/PhotoGeotaggingService.kt` — EXIF write

Used by Expedition Journal photo capture — writes GPS lat/lng + timestamp into EXIF so photos carry their location when exported via HTML report or shared externally.

## Persistence

| Kind | Layer | What |
|---|---|---|
| Bundled JSON | `assets/` + `AssetsRepository.kt` | Routes, bikes, posts, events, programs, photos, guides, config |
| DataStore Preferences | `storage/OnboardingStore.kt` | `completed: Boolean` for onboarding gate |
| DataStore Preferences | `storage/RideHistoryStore.kt` | Persisted `RideSession` list for Record tab "Recent Rides" |
| Room | `data/database/` | Expedition Journal: journals, days, entries, contributions (4 entities + DAO) |
| Filesystem | `files/` + `FileProvider` | GPX exports, HTML expedition exports, captured photos. Served via `FileProvider` for share-sheet intents. |

## Maps — MapLibre

`ui/screens/routes/RouteMapView.kt` uses MapLibre Android SDK 11.0.1 + annotation plugin. Stable tile source: `https://tiles.versatiles.org/assets/styles/colorful.json` (swapped from MapLibre demo tiles, which rate-limited aggressively).

Route polyline rendered as a `LineLayer` from the trackpoints. No offline pack yet (scaffolded for v0.9).

## Images

`io.coil-kt:coil-compose:2.5.0` → `AsyncImage(model = "file:///android_asset/images/$filename")` for bundled gallery photos. 40 photos ship in `assets/images/` (copied from `StoneBC/GalleryPhotos/` on the iOS side).

## Theme

`ui/theme/` mirrors iOS `BCDesignSystem.swift`:

- `Color.kt` — `BCColors.BrandBlue`, `BrandGreen`, `BrandAmber`, `NavAlertRed`, `NavAlertAmber`
- `Spacing.kt` — `BCSpacing.xs` (4dp), `.sm` (8dp), `.md` (16dp), `.lg` (24dp), `.xl` (32dp)
- `Theme.kt` — `StoneBCTheme` Material3 wrapper

Design-system components (filter chips, cards, badges, pressable buttons) live in `ui/components/BCComponents.kt`.

## iOS parity notes

- **No Rally Radio** — iOS MultipeerConnectivity is not portable. Android shows Rally Radio as a disabled card on the More tab with "IOS ONLY" section header.
- **Swiss Army Knife placeholder state** — API keys live on the iOS side; Android rows render with "· coming soon" suffix until shared keys ship.
- **MapKit → MapLibre** — iOS uses MapKit; Android uses MapLibre. Same trackpoint data, same elevation profile algorithm, different render.
- **CoreLocation → FusedLocation** — same 1Hz sample rate, same 7-second auto-pause heuristic, different APIs.
- **ActivityKit → foreground notification** — iOS Live Activity / Dynamic Island is replaced by an Android ongoing notification during ride recording.

## Build config highlights

`app/build.gradle.kts`:

- Kotlin 1.9.x + Compose BOM 2024.02.00
- KAPT for Room annotation processing
- Release signing config reads from `keystore.properties` or env vars (see [`SETUP.md`](../SETUP.md))
- No minification (`isMinifyEnabled = false`) — keep stack traces human-readable until we start shipping through Play Console

## Known gotchas

- **ANR during emulator Maestro runs** — keep other test apps (Dharma Wellness, LakLang) uninstalled from the test emulator; the x86_64 emulator ANRs under sustained UI-automation load
- **Onboarding state race** — `markComplete()` is a suspend fn; `launchApp` immediately after a finish tap may see the old state. Maestro flows work around this with `subflows/skip-onboarding.yaml`
- **Back from deep MoreScreen sub-screens** — device back button (`- back` in Maestro) is the canonical pop. There's no in-app "Back" widget with an id
