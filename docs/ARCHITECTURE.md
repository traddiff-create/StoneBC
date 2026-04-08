# Architecture — StoneBC iOS App

## Pattern: MVVM with @Observable

```
┌─────────────────────────────────────────────┐
│                   Views                      │
│  HomeView · MarketplaceView · RadioView     │
│  RoutesView · CommunityFeedView · MoreView  │
└──────────────────┬──────────────────────────┘
                   │ @Environment
┌──────────────────▼──────────────────────────┐
│              AppState (@Observable)           │
│  bikes[] · posts[] · events[] · routes[]     │
│  config · filtering · radioViewModel         │
└──────┬───────────────────────┬──────────────┘
       │                       │
┌──────▼──────┐   ┌───────────▼──────────────┐
│ Data Layer  │   │    Radio Layer            │
│ Bundle JSON │   │ RadioService (MCSession)  │
│ WordPressSvc│   │ AudioStreamService (AVAudio)│
└─────────────┘   └──────────────────────────┘
```

## State Flow

1. `StoneBCApp` creates `ContentView`
2. `ContentView` creates `AppState` and injects via `.environment()`
3. `AppState.init()` loads all JSON from bundle
4. `ContentView.task` calls `appState.syncFromWordPress()` (fire-and-forget)
5. `TabContainerView` reads `AppState` from environment
6. All child views access `AppState` via `@Environment(AppState.self)`

## Navigation

```
TabContainerView (TabView, 5 tabs)
├── HomeView (NavigationStack)
│   ├── BikeDetailView (via featured bikes)
│   └── PostDetailView (via recent posts)
├── RoutesView (NavigationStack)
│   ├── RouteDetailView (stats + elevation + weather + ride tools)
│   │   ├── RouteWeatherSection (WeatherKit conditions + ride window)
│   │   ├── CellCoverageView (tower map + dead zones)
│   │   └── RouteNavigationView (ride dashboard + map)
│   │       ├── RideDashboardView (compass + altimeter + speed)
│   │       ├── NavigationAudioService (turn cues + milestones)
│   │       ├── WorkoutService (HealthKit recording)
│   │       └── RideActivityManager (Live Activities)
│   ├── RouteMapView (full-screen single route map)
│   └── RouteExplorerView (all routes on one map)
├── MarketplaceView (NavigationStack)
│   ├── BikeFilterBar (filter chips)
│   └── BikeDetailView (specs + contact CTA)
├── RadioView (NavigationStack)
│   └── PTTButton (long-press gesture)
└── MoreView (NavigationStack)
    ├── CommunityFeedView → PostDetailView
    ├── CommunityView (events + programs)
    ├── GalleryView
    └── ContactView
```

## Data Strategy

| Source | When | Fallback |
|--------|------|----------|
| Bundled JSON | Always loaded on init | — |
| WordPress REST API | On launch (if configured) | Bundled JSON |
| The Quarry POS | Owner exports → bundle | Previous bikes.json |

## Services Layer (Lewis & Clark)

```
┌─────────────────────────────────────────────────────────┐
│                    Sensor Services                       │
│  LocationService   — GPS, heading, speed, course        │
│  AltimeterService  — CMAltimeter pressure, altitude     │
│  NavigationAudioService — AVSpeechSynthesizer cues      │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│                   Network Services                       │
│  WeatherService    — WeatherKit with 30-min cache       │
│  ConnectivityService — NWPathMonitor online/offline      │
│  OfflineMapService — MKMapSnapshotter tile pre-cache    │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│                   Health & Activity                       │
│  WorkoutService    — HKWorkoutBuilder + RouteBuilder    │
│  RideActivityManager — ActivityKit Live Activities      │
│  PermissionService — CLLocation + HealthKit status      │
└─────────────────────────────────────────────────────────┘
```

## Offline Capability

| Feature | Offline? | Source |
|---------|----------|--------|
| Route list, detail, elevation | Yes | Bundled routes.json |
| GPS navigation + off-route | Yes | CoreLocation + bundled trackpoints |
| Compass, altimeter, speed | Yes | CoreLocation + CoreMotion sensors |
| Audio turn cues | Yes | AVSpeechSynthesizer (on-device) |
| Cell coverage map | Yes | Bundled cell_towers.json |
| Map tiles | Partial | MapKit cache + MKMapSnapshotter fallback |
| Weather | No | WeatherKit requires network |
| HealthKit recording | Yes | Local HealthKit store |

## Key Decisions

- **No auth** — app is read-only for users
- **No backend** — all data bundled or optional WordPress
- **Config-driven** — `config.json` controls everything forkable
- **MultipeerConnectivity** for Rally Radio — no server needed
- **@Observable** over Combine — simpler, iOS 17+ only
- **Offline-first** — all sensors + route data work without signal
- **Graceful degradation** — WeatherKit shows "unavailable" without entitlement
