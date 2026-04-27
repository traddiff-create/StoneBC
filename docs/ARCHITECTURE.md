# Architecture — StoneBC iOS App

## Pattern: MVVM with @Observable

```
┌─────────────────────────────────────────────┐
│                   Views                      │
│  HomeView · RoutesView · RecordTabView      │
│  RidesTabView · MoreView · Expedition views │
└──────────────────┬──────────────────────────┘
                   │ @Environment
┌──────────────────▼──────────────────────────┐
│              AppState (@Observable)           │
│  bikes[] · posts[] · events[] · routes[]    │
│  guides[] · config · filtering · sync state │
└──────┬───────────────────────┬──────────────┘
       │                       │
┌──────▼──────┐   ┌───────────▼──────────────┐
│ Data Layer  │   │    Radio Layer            │
│ Bundle JSON │   │ RadioService (MCSession)  │
│ WordPressSvc│   │ AudioStreamService         │
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
│   ├── PostDetailView (via recent posts)
│   └── RadioView → PTTButton
├── RoutesView (NavigationStack, List/Map browser)
│   ├── RouteDetailView (Overview + Prep + Ride + History)
│   │   ├── RouteWeatherSection (WeatherKit conditions + ride window)
│   │   ├── CellCoverageView (tower map + dead zones)
│   │   ├── RouteInterchangeService (GPX/TCX/FIT/KML/KMZ/ZIP import/export)
│   │   ├── RouteProviderManager (Garmin/Wahoo/Ride with GPS actions)
│   │   ├── RouteNavigationView (ride cockpit + overlay-aware map)
│   │   └── RouteRecordingView (Follow Route / Scout Route starts)
│   │       ├── RideDashboardView (compass + altimeter + speed)
│   │       ├── NavigationAudioService (turn cues + milestones)
│   │       ├── WorkoutService (HealthKit recording)
│   │       └── RideActivityManager (Live Activities)
│   ├── RouteMapView (full-screen single route map)
│   └── RouteExplorerView (all routes on one map)
├── RecordTabView
│   └── RouteRecordingView (Free Ride / Follow Route / Scout Route)
├── RidesTabView
│   ├── RideDetailView
│   └── RideJournalDetailView
└── MoreView (NavigationStack)
    ├── CommunityFeedView → PostDetailView
    ├── CommunityView (events + programs)
    ├── MarketplaceView → BikeDetailView
    ├── TourGuideListView → TourGuideDetailView
    ├── ExpeditionListView → ExpeditionTimelineView
    ├── GalleryView
    └── ContactView
```

## Data Strategy

| Source | When | Fallback |
|--------|------|----------|
| Bundled JSON | Always loaded on init | — |
| WordPress REST API | On launch (if configured) | Bundled JSON |
| The Quarry POS | Owner exports → bundle | Previous bikes.json |
| Documents directory | User routes, expedition journals/media/exports | Local files |
| UserDefaults | Small local preferences, route ride preferences, lightweight ride/journal records | Defaults |
| HealthKit | Completed cycling workouts | Health app |

## Services Layer

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
│  RouteProviderManager — provider-gated route uploads    │
└─────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────┐
│                  Route Interchange                       │
│  RouteInterchangeService — GPX/TCX/FIT/KML/KMZ/ZIP      │
│  UserRouteStore — Documents-backed imported route JSON  │
│  RouteRidePreferences — rider-local overlay/save prefs  │
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
| Route overlay preferences | Yes | UserDefaults keyed by route ID |
| Route file import/export | Yes | Files app + local parsers/exporters |
| Device bundle sharing | Yes | Local ZIP creation |
| GPS navigation + off-route | Yes | CoreLocation + bundled trackpoints |
| Route-linked recording modes | Yes | RouteRecordingView + RideSession |
| Compass, altimeter, speed | Yes | CoreLocation + CoreMotion sensors |
| Audio turn cues | Yes | AVSpeechSynthesizer (on-device) |
| Cell coverage map | Yes | Bundled cell_towers.json |
| Map tiles | Partial | MapKit cache + MKMapSnapshotter fallback |
| Follow My Expedition capture | Yes | Documents directory |
| Expedition PDF export | Yes | Local renderer + local media |
| Weather | No | WeatherKit requires network |
| Garmin/Wahoo/RWGPS upload | No | Provider APIs require network and credentials |
| HealthKit recording | Yes | Local HealthKit store |

## Key Decisions

- **Public-first** — most features require no account; optional member login is local-token based
- **No backend** — all data bundled or optional WordPress
- **Config-driven** — `config.json` controls everything forkable
- **MultipeerConnectivity** for Rally Radio — no server needed
- **@Observable** over Combine — simpler, iOS 17+ only
- **Offline-first** — all sensors + route data work without signal
- **Graceful degradation** — WeatherKit shows "unavailable" without entitlement
- **File-first route interop** — provider APIs enhance, but do not replace, offline import/export
- **Keychain for provider tokens** — no provider secrets or tokens in bundled config
