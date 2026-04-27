# Routes & Route Interop — StoneBC

**Last Updated:** 2026-04-27

## Overview

StoneBC routes are local-first. Bundled routes come from `StoneBC/routes.json`; user imports and exports run through `RouteInterchangeService` so riders can move files between StoneBC, Garmin, Wahoo, Ride with GPS, mapping tools, and devices even without cellular coverage.

The route surface now supports a full plan, prep, ride, record loop: list/map browsing, route readiness, rider-customizable overlays, route-linked recording modes, and a post-ride review hub.

The reliable baseline is offline file import/export. Direct provider integrations are feature-gated until credentials and provider approvals are available.

## Route Data Pipeline

```text
Source GPX/FIT/TCX files
  -> Scripts/process_routes.py
  -> StoneBC/routes.json
  -> Route.swift
  -> RoutesView / RouteDetailView / RouteNavigationView / RouteRecordingView
```

Runtime imports use a separate path:

```text
Files / share sheet / open-in-place
  -> GPXImportView
  -> RouteInterchangeService
  -> RouteImportCandidate
  -> UserRouteStore or RideHistoryService
```

## Supported Runtime Formats

| Format | Import | Export | Notes |
| --- | --- | --- | --- |
| GPX | Yes | Yes | Tracks, routes, waypoints; broadest compatibility |
| TCX | Yes | Yes | Courses, activities, course points |
| TPX fields | Yes | N/A | Treated as Garmin TCX ActivityExtension data, not a standalone file type |
| FIT | Yes | Yes | Minimal course/activity support for Garmin/Wahoo workflows |
| KML | Yes | Yes | LineString, MultiGeometry, and `gx:Track` style coordinate data |
| KMZ | Yes | Via ZIP bundle | Safely reads compressed KML bundles |
| ZIP | Yes | Yes | Device bundle import/export; entry paths are validated |

`RouteInterchangeService.detectFormat(data:filename:)` sniffs content before trusting file extensions. This matters because local route libraries often contain misnamed TCX files, extensionless files, and provider exports with generic MIME types.

## Canonical Import Models

Core models live in `RouteInterchangeService.swift`:

| Model | Purpose |
| --- | --- |
| `RouteFileFormat` | Detected input format: GPX, TCX, FIT, KML, KMZ, ZIP |
| `RouteAssetKind` | Planned route vs completed ride |
| `RouteTrackPoint` | Lat/lon/elevation/time/distance/sensor fields |
| `RouteCoursePoint` | Cue, POI, hazard, start, finish, generated course point |
| `RouteImportCandidate` | Preview-ready imported route or completed ride |
| `RouteImportFailure` | Per-file import error for batch UI |
| `RouteExportFormat` | Device bundle or single-format export target |

Planned routes become `Route` values and are saved through `AppState.addImportedRoute(_:)`. Completed activities become `CompletedRide` values and are saved through `RideHistoryService.importRide(_:)`; the import UI also offers "Save as Route" for activities riders want to navigate later.

## Storage

Bundled routes remain in `StoneBC/routes.json`.

User-imported routes are stored by `UserRouteStore` in the app Documents directory:

```text
Documents/
  Routes/
    userRoutes.json
```

`AppState.loadImportedRoutes()` migrates the legacy `UserDefaults` key `importedRoutes` into `UserRouteStore` on launch and then removes the old key. New imports are no longer persisted in `UserDefaults`.

Completed imported rides remain in `RideHistoryService` storage alongside locally recorded rides. Ride trackpoints use the existing `CompletedRide.gpxTrackpoints` field.

## Route Model and Customization

`Route.swift` is intentionally backwards-compatible with older route JSON. New route-level planning fields are optional.

```swift
struct Route: Identifiable, Codable {
    let id: String
    let name: String
    let difficulty: String
    let category: String
    let distanceMiles: Double
    let elevationGainFeet: Int
    let region: String
    let description: String
    let startCoordinate: Coordinate
    let trackpoints: [[Double]]
    let cuePoints: [CuePoint]
    let gpxURL: String?
    let rideDefaults: RouteRideDefaults?
    var isImported: Bool
}
```

`RouteRideDefaults` lets route authors configure optional defaults in bundled route data:

- `enabledOverlays`
- `recommendedRecordingMode`
- `offlinePriority`
- `cueVisibility`
- `safetyCheckInEnabled`
- `prepNotes`

`RouteRidePreferences` stores rider-local customization in `UserDefaults`, keyed by route ID. It covers enabled overlays, preferred recording mode, prep state, and post-ride save defaults. The free-recording key is `routeRidePreferences.free`.

Overlay cases are functional ride layers only: route line, breadcrumbs, cues, off-route alerts, offline status, weather, cell coverage, nearby stops, and safety check-in.

## Planning and Riding Surfaces

### Route Browser

`RoutesView` has a `List / Map` toggle. Both modes use the same filter, sort, selected-route, imported-route, and empty-state behavior.

- List mode keeps fast scanning with imported route and bundled route sections.
- Map mode renders filtered route polylines and a selected-route bottom card.
- Route cards remain the primary drill-down surface in both modes.

### Route Detail

`RouteDetailView` is organized into four modes:

- `Overview`: stats, elevation, native map preview, description, and GPX reference link.
- `Prep`: readiness checklist, weather, cell coverage, offline tools, and author prep notes.
- `Ride`: start navigation, start route-linked recording, choose recording mode, and toggle ride overlays.
- `History`: completed rides for the route plus share/export/time-trial actions.

Readiness composes existing local services and route data:

- Route geometry and navigability
- Offline route data
- Offline tile status
- Weather cache
- Cue availability
- Cell coverage
- Warning/safety state

### Ride Overlays

Navigation and route-linked recording honor `RouteRidePreferences.enabledOverlays`.

- Route line and breadcrumbs control map geometry.
- Cues control turn prompt/audio behavior.
- Off-route alerts control warning banners and spoken alerts.
- Offline status controls map offline state indicators.
- Safety check-in controls reminder timers.

### Recording Modes

`RouteRecordingMode` is shared by `RecordTabView`, `RouteRecordingView`, and route-linked starts.

| Mode | Purpose |
| --- | --- |
| `Free Ride` | Record a ride without a source route |
| `Follow Route` | Record while riding an existing route |
| `Scout Route` | Capture a new route for cleanup and submission |

Scout mode biases the review flow toward saving as a route and submitting to the co-op review path. Follow mode links the recording to the selected route.

### Post-Ride Review Hub

The recording save sheet is now a review hub:

- Stats summary
- Map preview of the recorded track
- Name/category/difficulty/region fields
- Save to ride history
- Save as local route
- Submit to co-op through the existing review path
- Export GPX/share text
- Start journal prompt

## Import UI

`GPXImportView.swift` is still the file name for project stability, but the UI is now "Import Route or Ride".

Flow:

1. User taps the plus button in Routes.
2. File picker accepts multiple route/ride files.
3. The importer opens security-scoped resources.
4. `RouteInterchangeService.importFiles(_:)` returns candidates and failures.
5. Preview shows detected format, source filename, route vs activity, distance, elevation, point count, cue count, map preview, and errors.
6. Planned routes can be added to My Routes.
7. Completed rides can be saved to ride history or converted into a route.

`StoneBC/Info.plist` registers document types for GPX, TCX, FIT, KML, KMZ, and ZIP and enables open-in-place behavior.

## Export Behavior

Default route export is a device bundle ZIP:

```text
<route>_device_bundle.zip
  README.txt
  <route>.gpx
  <route>.tcx
  <route>.fit
  <route>.kml
```

Single-format exports are also available from route detail:

- GPX Track
- TCX Course
- FIT Course
- KML

Ride detail exports completed rides as:

- Device bundle ZIP
- GPX Activity Track
- TCX History
- FIT Activity
- KML

Course points and POIs are preserved when present. If a route has no cues, `RouteInterchangeService.generatedCoursePoints(points:)` creates basic start, finish, and coarse turn cues and marks them as generated.

## Provider Integrations

Connected app support lives in `RouteProviderService.swift` and is surfaced in `More -> Connected Apps` plus route detail send actions.

| Provider | Current Behavior |
| --- | --- |
| Garmin | Feature-gated until StoneBC has approved Courses API access |
| Wahoo | OAuth/PKCE scaffold and FIT course upload path through Wahoo Routes API when credentials and tokens exist |
| Ride with GPS | OAuth entry scaffold; route-write behavior gated until approved API access/proxy exists |

All provider tokens are stored in Keychain through `RouteProviderKeychain`. `config.json` may carry public client IDs only; do not commit client secrets, access tokens, refresh tokens, API keys, or private endpoints.

Provider upload requires network. File import/export remains fully offline.

## Navigation Runtime

Navigation still consumes `Route.trackpoints`:

- MapKit renders route polylines and user location.
- `LocationService` supplies GPS, heading, speed, and course.
- `AltimeterService` supplies barometer-backed altitude where available.
- `RouteAnalysisService` and route cue data support turn/cue UI.
- Off-route warnings and progress calculations use nearest-trackpoint geometry.
- `RouteRidePreferences` controls which ride overlays are active for a route.

Map tiles depend on MapKit cache and any installed offline tile support, but route geometry, cue data, GPS, compass, and barometer behavior do not require network.

## Security Rules

- Validate imported filenames and ZIP entry paths.
- Treat all imported XML/binary payloads as untrusted.
- Use security-scoped access for Files app URLs.
- Keep provider tokens in Keychain only.
- Keep real provider secrets out of source, `config.json`, docs, and staged files.
- Do not store route blobs or large import payloads in `UserDefaults`.

## QA Checklist

- Verify Route Browser List and Map modes share filters, sort order, selected route state, imported routes, and empty states.
- Verify Route Detail `Overview`, `Prep`, `Ride`, and `History` sections render for bundled and imported routes.
- Verify readiness state before and after saving offline route data/tiles/weather.
- Verify overlay toggles persist per route and affect both guided navigation and route-linked recording.
- Verify `Free Ride`, `Follow Route`, and `Scout Route` start, pause/resume, stop, and save correctly.
- Verify post-ride review can save history only, save as route, submit to co-op, export/share GPX content, and open journal prompt.
- Import valid GPX 1.0/1.1, GPX route-only, and GPX with waypoints.
- Import TCX Course and TCX Activity with TPX extension fields.
- Import FIT Course and FIT Activity.
- Import KML, KMZ, and ZIP bundle.
- Verify corrupt XML and oversized/unsupported files show per-file errors.
- Verify path-traversal ZIP entries are rejected.
- Export route device bundle and import into Garmin Connect, Wahoo app/API sandbox, and Ride with GPS where available.
- Export completed ride bundle and verify GPX/TCX/FIT/KML files are created.
- Run the simulator build:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -scheme StoneBC \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```
