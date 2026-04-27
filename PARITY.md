# StoneBC Cross-Platform Parity System

## Purpose

**iOS is the current reference; Android follows current shipped behavior.**

The Android app is a native Kotlin/Compose sibling. The `:shared` KMP module is the source of truth for data contracts, config shape, route recording metadata, and bundled-content decoding. Platform code may add UI or service adapters, but it should not redefine a data model that already exists in shared.

## Architecture

```
KMP Shared Module
android/shared/src/commonMain/kotlin/com/traddiff/stonebc/shared/
        |
        v
Android Kotlin/Compose
        |
        v
Bundled JSON synced from StoneBC/
```

iOS currently uses Swift models directly. Android keeps app-local model typealiases for compatibility, backed by shared KMP model definitions.

## Rules

1. Add cross-platform contracts to `android/shared` first, then wire platform code.
2. New JSON fields must be nullable or have defaults.
3. Never hardcode coalition identity, contact info, or colors; use `config.json`.
4. Run `python3 Scripts/sync_android_assets.py --check` before Android release work.
5. Platform exceptions must stay documented below.

## Feature Parity Status

**Last updated:** 2026-04-27
**iOS reference:** v0.8
**Android:** v0.8 parity branch, package `com.stonebicyclecoalition.stonebc`

| Feature | iOS | Android | Shared KMP | Status |
|---|---|---|---|---|
| Home dashboard | `HomeView` | `HomeScreen` | `AppConfig`, content models | PASS |
| Routes list + filters | `RoutesView` | `RoutesScreen` | `Route` | PASS |
| Route detail map/elevation | `RouteDetailView` | `RouteDetailScreen` | `Route`, `RouteRideDefaults` | PARTIAL |
| Route-linked recording | `RouteRecordingView` | `RecordScreen` + `RecordingService` | `RouteRecordingMode`, `RideSession` | PARTIAL |
| Free ride recording | `RecordTabView` | `RecordScreen` | `RideSession` | PASS |
| Ride history/stats | `RidesTabView` | `RidesScreen` | `RideSession` | PARTIAL |
| Bikes / The Quarry | `MarketplaceView` | `BikesScreen` | `Bike`, `BikesFile` | PASS |
| Community posts | `PostDetailView` / More | `CommunityFeedScreen` | `Post` | PASS |
| Events + programs | `CommunityView` | `EventsScreen`, `ProgramsScreen` | `Event`, `Program` | PASS |
| Gallery | `GalleryView` | `GalleryScreen` | `Photo` | PASS |
| Tour guides | `TourGuideListView` | `TourGuidesScreen` | `TourGuide` | PARTIAL |
| Expedition Journal | Expedition views | Expedition screens + Room | local DB only | PARTIAL |
| Swiss Army Knife | multiple services | `SwissArmyKnifeScreen` | config keys | PARTIAL |
| Rally Radio | `Radio/` | disabled card | — | ACCEPTED EXCEPTION |

## Accepted Exceptions

| Feature | Platform | Reason |
|---|---|---|
| Rally Radio | iOS-only for now | Built on MultipeerConnectivity; Android needs a separate nearby audio design. |
| HealthKit import/export | iOS-only | Android equivalent would require Health Connect scope and consent design. |
| ActivityKit / Live Activities | iOS-only | Android uses foreground service notification while recording. |
| WeatherKit | iOS-only API | Android uses OpenWeatherMap when configured. |
| MapKit | iOS-only API | Android uses MapLibre with shared route geometry. |

## Platform Mapping

| Concern | iOS | Android |
|---|---|---|
| UI | SwiftUI | Jetpack Compose + Material3 |
| State | `@Observable AppState` | `@Stable AppState` + CompositionLocal |
| Route maps | MapKit | MapLibre |
| Local preferences | UserDefaults | DataStore Preferences |
| Journals | Documents directory | Room + app files |
| Ride recording | CoreLocation / HealthKit | FusedLocationProvider + foreground service |
| OAuth tokens | Keychain | Android Keystore-backed encrypted values |

## Data Sync

Canonical app content is under `StoneBC/`. Android assets are generated from that source:

```bash
python3 Scripts/sync_android_assets.py
python3 Scripts/sync_android_assets.py --check
```

The current Quarry inventory is empty on both platforms (`bikes.json` has 0 bikes). Android tests assert the empty state until real inventory is exported through the existing inventory workflow.
