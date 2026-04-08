# Routes & GPX System — StoneBC

**Last Updated:** 2026-04-04

---

## Overview

StoneBC has a full GPX pipeline: 18 Black Hills cycling routes processed from raw GPX files, plus runtime GPX import/export, live navigation, route exploration, and social sharing.

## Data Pipeline

```
GPX + FIT files (40)  →  process_routes.py  →  routes.json (1.2MB)  →  Route.swift  →  MapKit
     ↑                                                                       ↑
  StoneBC/GPX/                                                     User imports (.gpx)
```

### Source Files
- **GPX directory:** `StoneBC/GPX/` — 18 .gpx + 22 .fit files (40 total)
- **Processing script:** `Scripts/process_routes.py` — Python 3 + fitdecode, extracts trackpoints from both GPX (XML) and FIT (binary), calculates distance/elevation, simplifies to max 500 points, outputs JSON
- **Bundled data:** `StoneBC/routes.json` — 35 routes, ~1.2MB
- **Skipped files (5):** 2022Dakota50v2.gpx (corrupt XML), Fat_Pursuit_60k_2022_FINAL.gpx (3 waypoints only), Sturgis Med.gpx (0 trackpoints), BH Expedition .fit / Gmaps Pedometer Track_course.fit (missing altitude fields)
- **Dependencies:** `pip3 install fitdecode` (for FIT binary parsing)

### Complete Route Inventory (35 routes)

| Route Name | Distance | Elevation | Difficulty | Category | Region | Source |
|------------|----------|-----------|------------|----------|--------|--------|
| 28 Below Fat Bike | 30.0 mi | 2,842 ft | moderate | fatbike | Black Hills | GPX |
| Badlands Prairie 35 | 35.0 mi | 1,992 ft | moderate | gravel | Badlands | GPX |
| Badlands Prairie 68 | 67.8 mi | 3,305 ft | hard | gravel | Badlands | GPX |
| Brewvet Rally | 44.4 mi | 4,567 ft | hard | gravel | Black Hills | FIT |
| Custer Medium Loop | 26.7 mi | 2,846 ft | moderate | road | Custer | FIT |
| Custer State Park Loop | 29.6 mi | 2,873 ft | moderate | road | Custer | GPX |
| Dakota 50 (2021 Course) | 50.2 mi | 5,460 ft | hard | gravel | Black Hills | FIT |
| Dead Swede 60 | 60.1 mi | 3,778 ft | hard | gravel | Black Hills | FIT |
| Deadman's Gravel | 10.4 mi | 2,824 ft | moderate | gravel | Black Hills | FIT |
| Deadwood Blue Loop | 29.3 mi | 3,099 ft | hard | gravel | Deadwood | GPX |
| Gold Rush 110 | 110.3 mi | 7,487 ft | expert | gravel | Black Hills | GPX |
| Gravel Pursuit 60 | 62.1 mi | 5,373 ft | hard | gravel | Black Hills | GPX |
| Hill City Explorer | 29.7 mi | 4,077 ft | hard | road | Hill City | FIT |
| Hill City Short Loop | 14.3 mi | 827 ft | easy | road | Hill City | FIT |
| Hill City — Rockerville — Rapid City | 52.7 mi | 4,512 ft | hard | road | Black Hills | GPX |
| Hilloween 50 | 47.4 mi | 0 ft | hard | gravel | Black Hills | FIT |
| Jenny Gulch Gravel | 65.2 mi | 6,841 ft | expert | gravel | Black Hills | GPX |
| Lead-Deadwood Ride | 28.8 mi | 3,429 ft | hard | road | Lead | FIT |
| Merit Mine Trail | 26.9 mi | 8,596 ft | expert | trail | Black Hills | FIT |
| Mickelson Trail | 108.8 mi | 7,944 ft | expert | trail | Black Hills | FIT |
| Nemo Loop | 35.1 mi | 1,946 ft | moderate | gravel | Nemo | FIT |
| Piedmont Quick Spin | 29.1 mi | 1,362 ft | easy | gravel | Piedmont | FIT |
| Piedmont Ranch Hard | 50.6 mi | 2,791 ft | hard | gravel | Piedmont | GPX |
| Piedmont Ranch Medium | 29.1 mi | 1,364 ft | moderate | gravel | Piedmont | GPX |
| Rapid City Bikepacking | 59.1 mi | 5,333 ft | hard | gravel | Rapid City | FIT |
| Rochford Loop | 33.0 mi | 3,402 ft | hard | gravel | Rochford | FIT |
| Rushmore to Rapid City | 42.9 mi | 3,855 ft | hard | road | Black Hills | FIT |
| Rushmore — Hill City — Home | 42.9 mi | 3,848 ft | hard | road | Black Hills | GPX |
| Spearfish Canyon Epic | 276.8 mi | 27,410 ft | expert | road | Spearfish | GPX |
| Spearfish Canyon Ride | 27.5 mi | 1,798 ft | moderate | road | Spearfish | FIT |
| Spearfish Short Loop | 27.4 mi | 2,299 ft | moderate | road | Spearfish | FIT |
| Sturgis Quick Loop | 28.7 mi | 2,230 ft | moderate | road | Sturgis | FIT |
| Sturgis to Rapid City | 50.0 mi | 2,011 ft | hard | road | Sturgis | GPX |
| Two-Day Century | 106.8 mi | 13,724 ft | expert | road | Black Hills | GPX |
| Woodle Gulch to Rapid City | 48.6 mi | 3,632 ft | hard | gravel | Black Hills | FIT |

### Route Model (`Route.swift`)

```swift
struct Route: Identifiable, Codable {
    let id: String
    let name: String
    let difficulty: String          // easy, moderate, hard, expert
    let category: String            // road, gravel, fatbike, trail
    let distanceMiles: Double
    let elevationGainFeet: Int
    let region: String
    let description: String
    let startCoordinate: Coordinate
    let trackpoints: [[Double]]     // [[lat, lon, ele], ...]
    var isImported: Bool = false     // true for user-imported routes
}
```

**Computed properties:** `clTrackpoints`, `clStartCoordinate`, `elevations`, `formattedDistance`, `formattedElevation`, `elevationRange`, `minElevation`, `maxElevation`

**Factory method:** `Route.fromGPX(_:difficulty:category:region:)` — creates Route from parsed GPX data with Haversine distance and elevation gain calculation.

---

## Feature Set

### 1. Route List (`RoutesView.swift`)
- Difficulty filter chips (easy/moderate/hard/expert)
- Category filter chips (road/gravel/fatbike/trail)
- "MY ROUTES" section for imported routes with swipe-to-delete
- "BLACK HILLS ROUTES" section for bundled routes
- Toolbar: map icon → Route Explorer, plus icon → GPX Import

### 2. Route Detail (`RouteDetailView.swift`)
- Stats grid: distance, elevation gain, elevation range, trackpoint count
- Elevation profile chart (Charts framework, area + line marks)
- Map preview with start/end pins
- Full-screen map via RouteMapView
- **Toolbar actions:**
  - Share menu: Export GPX File / Share as Image
  - Navigate button → RouteNavigationView

### 3. Route Map (`RouteMapView.swift`)
- All routes as MapPolyline, color-coded by difficulty
- Start pin annotations with bicycle icon
- Filter panel (category + difficulty)
- Selected route card with drill-down to detail
- Uses `appState.allRoutes` (bundled + imported)

### 4. GPX Export (`GPXService.swift`)
- `GPXService.exportGPX(_ route:)` → valid GPX 1.1 XML string
- Includes `<metadata>`, `<trk>`, `<trkseg>`, `<trkpt>` with elevation
- `GPXService.writeToTempFile(_:name:)` → temp URL for ShareLink
- XML escaping for special characters
- Shared via native iOS share sheet (AirDrop, Files, Messages, etc.)

### 5. GPX Import (`GPXImportView.swift`, `GPXService.swift`)
- `GPXService.parseGPX(data:)` → XMLParser-based, handles `<trk>/<trkseg>` and `<rte>/<rtept>` formats
- Returns `GPXResult` with name, description, trackpoints
- File picker via `.fileImporter` (UTType: xml, gpx)
- Preview card with map, stats, difficulty/category selector
- Persisted to UserDefaults via `AppState.importedRoutes`
- Security-scoped resource access for Files app integration

### 6. Live Navigation (`RouteNavigationView.swift`, `LocationService.swift`)
- `LocationService` — @Observable CLLocationManager wrapper
  - 5m distance filter, bestForNavigation accuracy
  - Heading updates for camera orientation
  - Permission handling (WhenInUse)
- Navigation view features:
  - Route polyline + start/end pins
  - User location annotation (blue dot with pulse)
  - Progress bar (percentage along route)
  - Distance remaining display
  - Off-route detection (>50m from nearest trackpoint → warning banner)
  - Camera follows user with 45° pitch, heading-aligned
  - "END" button to stop tracking
- **Info.plist:** `NSLocationWhenInUseUsageDescription` added

### 7. Route Explorer (`RouteExplorerView.swift`)
- All routes overlaid on a single map for finding connections
- Each route gets a distinct color from 18-color palette
- Green dots = start points, red dots = end points
- **Connection detection:** white dashed lines between any endpoints <2 miles apart
- Route name labels at midpoints
- Map style toggle: Hybrid / Satellite / Standard (all with realistic elevation)
- Toggle connections on/off
- Toggle labels on/off
- Reset view button
- Selected route card shows link count to nearby routes
- Legend bar at bottom
- Access: Routes tab → map icon in toolbar

### 8. Share Card (`RouteShareCardView.swift`)
- Social media card: map thumbnail, route name, badges, stats grid, SBC branding
- `ImageRenderer` (iOS 16+) at 3x scale → UIImage
- Shared via ShareLink as Image with preview
- Sheet presentation from RouteDetailView

---

## Files

| File | Lines | Purpose |
|------|-------|---------|
| `Route.swift` | ~165 | Model + computed props + GPX factory + Haversine math |
| `GPXService.swift` | ~170 | GPX 1.1 export (XML gen) + import (XMLParser) |
| `GPXImportView.swift` | ~200 | File picker, preview, save flow |
| `LocationService.swift` | ~60 | CLLocationManager @Observable wrapper |
| `RouteNavigationView.swift` | ~190 | Live navigation map + HUD |
| `RouteExplorerView.swift` | ~280 | Topo overlay, connection finder |
| `RouteShareCardView.swift` | ~100 | Social media share card |
| `RouteDetailView.swift` | ~330 | Detail view + share menu + navigate |
| `RoutesView.swift` | ~275 | Route list + filters + import |
| `RouteMapView.swift` | ~265 | Interactive map with polylines |
| `AppState.swift` | ~150 | Data loading + imported route persistence |

---

## AppState Integration

```swift
// Bundled routes (from routes.json)
var routes: [Route]

// User-imported routes (persisted to UserDefaults)
var importedRoutes: [Route]

// Combined — used by all views
var allRoutes: [Route] { routes + importedRoutes }

// CRUD for imports
func addImportedRoute(_ route: Route)
func removeImportedRoute(id: String)
```

---

## Difficulty Classification

| Level | Distance | Elevation Gain |
|-------|----------|---------------|
| Easy | < 20 mi | < 1,500 ft |
| Moderate | < 40 mi | < 3,000 ft |
| Hard | < 80 mi | < 6,000 ft |
| Expert | >= 80 mi | >= 6,000 ft |

Auto-classified by `process_routes.py`, user-selectable on import.

---

## Design System Usage

- **Colors:** `BCColors.difficultyColor()`, `BCColors.categoryColor()`, `BCColors.brandBlue/Green/Amber`
- **Components:** `FilterChip`, `DifficultyBadge`, `CategoryBadge`, `StatCard`, `PressableButtonStyle`
- **Typography:** `.bcSectionTitle`, `.bcCaption`, `.bcPrimaryText`, `.bcSecondaryText`, `.bcMicro`
- **Spacing:** `BCSpacing.xs/sm/md/lg/xl/xxl`
- **Cards:** `BCSpacing.md` padding, `cardBackground`, 12pt corner radius

---

## Testing

- `/test-stonebc` — Full automated QA (build + 25 Blitz tests)
- GPX export: verify output opens in Garmin Connect / Ride with GPS
- GPX import: test with various sources (Strava, plotaroute, Garmin)
- Navigation: real-device GPS testing required
- Explorer: verify connection lines match visual proximity

---

## Future Enhancements

- CloudKit sync for imported routes
- Strava API integration for direct import
- Turn-by-turn directions (beyond follow-the-line)
- Route recording (track your own ride → save as GPX)
- Multi-route planner (chain connected routes into a single ride)
- Offline map tiles for navigation without signal
