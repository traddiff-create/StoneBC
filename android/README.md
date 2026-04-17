# StoneBC Android

Native Android sibling to the StoneBC iOS app. Kotlin + Jetpack Compose, shipping feature parity minus Rally Radio (iOS-only via MultipeerConnectivity).

**Package:** `com.traddiff.stonebc` · **minSdk:** 26 (Android 8.0) · **targetSdk:** 35 · **versionName:** 0.87

## Quickstart

```bash
cd /Applications/Apps/StoneBC/android
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.traddiff.stonebc/.MainActivity
```

First launch completes a 12-card onboarding (including runtime permission prompts). Permissions can be pre-granted for automated testing:

```bash
for p in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION ACTIVITY_RECOGNITION POST_NOTIFICATIONS CAMERA RECORD_AUDIO; do
  adb shell pm grant com.traddiff.stonebc "android.permission.$p"
done
```

## Package tour

```
app/src/main/kotlin/com/traddiff/stonebc/
├── MainActivity.kt             # Entry point; hosts onboarding gate + MainNavHost
├── data/
│   ├── AppState.kt             # @Stable state holder; parallel JSON loading
│   ├── AssetsRepository.kt     # Reads bundled JSON from assets/
│   ├── GPXExporter.kt          # Ride session → GPX 1.1
│   ├── ExpeditionExporter.kt   # Journal → standalone HTML
│   ├── LocalAppState.kt        # CompositionLocal for AppState access
│   ├── models/                 # Route, Bike, Post, Event, Program, Photo, TourGuide, RideSession, AppConfig
│   ├── repositories/           # RoutesRepository (search/filter helpers)
│   └── database/               # Room schema for Expedition Journal (journals, days, entries, contributions)
├── services/
│   ├── LocationService.kt      # FusedLocationProviderClient wrapper
│   ├── RecordingService.kt     # Foreground service for GPS ride recording
│   └── PhotoGeotaggingService.kt  # ExifInterface GPS tagging
├── storage/
│   ├── OnboardingStore.kt      # DataStore Preferences — onboarding completion flag
│   └── RideHistoryStore.kt     # DataStore Preferences — persisted ride summaries
└── ui/
    ├── theme/                  # BCColors, BCSpacing, Theme.kt (Material3)
    ├── components/             # BCComponents (filter chips, badges, cards), ElevationProfileChart, DisabledFeatureCard
    ├── navigation/MainNavHost.kt  # 5-tab NavHost + nested destinations
    └── screens/
        ├── onboarding/         # 12-card HorizontalPager onboarding
        ├── home/               # Hero, Your Season, Quick Links, Featured Bikes, Recent Posts
        ├── routes/             # RoutesScreen + RouteDetailScreen + RouteMapView (MapLibre)
        ├── record/             # RecordScreen — START/END + navigation HUD
        ├── bikes/              # BikesScreen (The Quarry) + BikeDetailScreen
        ├── expedition/         # Journal list, detail, capture, timeline
        ├── more/               # MoreScreen hub + SubScreens + SwissArmyKnifeScreen
        └── Screens.kt          # Shared navigation route keys
```

## Data pipeline

All content ships as bundled JSON in `app/src/main/assets/`:

| File | Contents |
|---|---|
| `config.json` | Feature flags, branding, contact info |
| `bikes.json` | Quarry inventory |
| `posts.json` | Community feed posts |
| `events.json` | Upcoming events |
| `programs.json` | Coalition programs (Earn-A-Bike, etc.) |
| `routes.json` | 56 Black Hills routes with trackpoints (~531KB) |
| `guides.json` | Tour guides (Brewvet, 8 Over 7) |
| `photos.json` | Gallery metadata; actual photos in `assets/images/` |

`AssetsRepository.kt` reads + deserializes via `kotlinx.serialization`. `AppState.kt` loads all JSON in parallel (`async`/`awaitAll` on `Dispatchers.IO`) for ~4.5s cold start.

## Feature parity with iOS

| Feature | iOS | Android | Notes |
|---|---|---|---|
| Home dashboard | ✅ | ✅ | |
| Routes list + filters | ✅ | ✅ | 56 routes, difficulty + category chips |
| Route detail + elevation | ✅ | ✅ | MapLibre on Android (MapKit on iOS) |
| Ride recording (GPS) | ✅ | ✅ | Foreground service on Android |
| GPX export | ✅ | ✅ | |
| Bikes / The Quarry | ✅ | ✅ | |
| Bike detail + mailto | ✅ | ✅ | |
| Gallery | ✅ | ✅ | 40 bundled images |
| Tour Guides | ✅ | ✅ | |
| Expedition Journal | ✅ | ✅ | Room DB on Android |
| Swiss Army Knife | ✅ | ✅ | Emergency Call live; others marked "coming soon" |
| Volunteer / Donate mailto | ✅ | ✅ | |
| Onboarding (12 cards) | ✅ | ✅ | |
| **Rally Radio** | ✅ | ❌ | iOS-exclusive (MultipeerConnectivity); shown as disabled card |

## Further reading

- [`SETUP.md`](SETUP.md) — release signing, Fastlane lanes, GitHub Actions secrets, Play Console setup
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — Compose + state flow, navigation, services
- [`docs/TESTING.md`](docs/TESTING.md) — Maestro flows + `/test-android` skill
- [`../docs/DATA_MODEL.md`](../docs/DATA_MODEL.md) — entity schemas (shared with iOS)
- [`../docs/DESIGN_SYSTEM.md`](../docs/DESIGN_SYSTEM.md) — color/spacing/typography tokens (shared semantics; Android implements via `ui/theme/`)
