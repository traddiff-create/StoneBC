# Alexandria → StoneBC Route Sync — Implementation Prompt

## Context

Alexandria (personal digital library, Swift CLI) has indexed 18+ Black Hills bike routes from GPX/TCX files with full metadata: distance, elevation gain/loss, surface type, difficulty, event names, start/end coordinates, trackpoints. StoneBC (Stone Bicycle Coalition iOS app) already has a mature route system with bundled routes in `routes.json`, MapKit rendering, GPX/TCX/FIT/KML route interop, elevation charts, turn-by-turn navigation, and a route explorer with connection detection.

**Goal:** Replace the hand-curated `routes.json` with an Alexandria-generated export. Alexandria becomes the single source of truth for route data. StoneBC consumes it at build time (bundled JSON) with optional runtime sync via Alexandria's REST API.

---

## Architecture Decision: Static Export (not live API)

**Chosen approach:** `alexandria routes export` generates a `routes.json` that gets copied into the StoneBC bundle.

**Why not live API:**
- StoneBC is a community app used offline on trails — can't depend on network
- Alexandria runs on Rory's Mac, not a server
- routes.json is 519KB — trivial to bundle
- Runtime sync is a nice-to-have for later (Alexandria dashboard already runs on :8642)

**Future option:** Add `/api/routes` endpoint to Alexandria dashboard for OTA updates via AppState sync (similar pattern to existing WordPress sync in AppState).

---

## Data Flow

```
GPX/TCX files (iCloud)
    ↓
Alexandria indexes (ContentExtractor parses XML, computes Haversine distance, 
                    smoothed elevation, infers surface/difficulty/event)
    ↓
route_metadata table (SQLite) + entries_fts (full-text search)
    ↓
`alexandria routes export --output /Applications/Apps/StoneBC/StoneBC/routes.json`
    ↓
StoneBC Route.loadFromBundle() reads routes.json on app launch
    ↓
MapKit renders routes, filters by difficulty/category/surface
```

---

## Phase 1: Alexandria Export Command

### New CLI command: `alexandria routes export`

**File:** `Sources/Alexandria/Alexandria.swift` — add `RoutesExport` subcommand to `RoutesCommand`

**Behavior:**
1. Query `allRoutes()` from LibraryService (joins entries + route_metadata)
2. For each route, re-read the original GPX/TCX file to extract full trackpoint arrays
3. Map to StoneBC's `Route` JSON schema (see below)
4. Write JSON array to `--output` path (default: `/Applications/Apps/StoneBC/StoneBC/routes.json`)

### New method: `LibraryService.exportRoutesForStoneBC()`

**File:** `Sources/AlexandriaLib/LibraryService.swift`

**Returns:** `[StoneBCRoute]` — Codable struct matching StoneBC's Route.swift schema

```swift
public struct StoneBCRoute: Codable, Sendable {
    let id: String              // kebab-case from filename: "28-below-course"
    let name: String            // "28 Below Course"
    let difficulty: String      // "easy" | "moderate" | "hard" | "expert"
    let category: String        // "road" | "gravel" | "fatbike" | "trail"
    let distanceMiles: Double   // Haversine-computed
    let elevationGainFeet: Int  // Smoothed, meters→feet
    let region: String          // "Black Hills" (all routes for now)
    let description: String     // Auto-generated from metadata
    let startCoordinate: Coordinate
    let trackpoints: [[Double]] // [[lat, lon, elevation_meters], ...]
    
    struct Coordinate: Codable, Sendable {
        let latitude: Double
        let longitude: Double
    }
}
```

### Field Mapping: Alexandria → StoneBC

| Alexandria field | StoneBC field | Transform |
|-----------------|---------------|-----------|
| `entry.title` | `name` | Direct (already standardized) |
| filename kebab | `id` | lowercase, hyphens, no extension |
| `route.difficulty` | `difficulty` | Map: "easy"→"easy", "intermediate"→"moderate", "hard"→"hard", nil→"moderate" |
| `route.surfaceType` | `category` | Map: "gravel"→"gravel", "fat-tire"→"fatbike", "road"→"road", "trail"→"trail", nil→"gravel" |
| `route.distanceMiles` | `distanceMiles` | Direct |
| `route.elevationGainFt` | `elevationGainFeet` | Direct |
| "Black Hills" | `region` | Hardcode for now |
| auto-generated | `description` | Build from: distance, elevation, surface, event, location |
| `route.startLat/Lon` | `startCoordinate` | Wrap in Coordinate struct |
| GPX trackpoints | `trackpoints` | Re-parse GPX → `[[lat, lon, ele_meters]]` |

### Difficulty Mapping Logic

```
Alexandria          →  StoneBC
"easy"              →  "easy"
"intermediate"      →  "moderate"  
"hard"              →  "hard"
nil + distance < 30 →  "easy"
nil + distance < 60 →  "moderate"
nil + distance < 100→  "hard"
nil + distance ≥ 100→  "expert"
```

### Category Mapping Logic

```
Alexandria surface  →  StoneBC category
"gravel"            →  "gravel"
"fat-tire"          →  "fatbike"
"road"              →  "road"
"trail"             →  "trail"
nil                 →  "gravel" (most Black Hills routes are gravel)
```

### Description Auto-Generation

Template:
```
"{distance} mile {category} route through {location}. {elevation_gain} ft of climbing.
{event_info}{surface_info}"
```

Example outputs:
- "62.1 mile gravel route through the Black Hills. 5,068 ft of climbing. Part of the Gravel Pursuit race series."
- "30.0 mile fatbike route through the Black Hills. 2,706 ft of climbing. The 28 Below winter challenge course."
- "50.0 mile gravel route from Sturgis to Rapid City. 1,651 ft of climbing."

---

## Phase 2: Trackpoint Re-Extraction

The `route_metadata` table stores computed stats but NOT the full trackpoint arrays (those are too large for SQLite). The export command must re-read the original GPX/TCX files.

**New method:** `ContentExtractor.extractTrackpoints(from url: URL) -> [[Double]]`

- Reuse the existing `RouteXMLParser` 
- Return `[[lat, lon, elevation_meters]]` arrays
- Handle missing elevation gracefully (use 0.0)
- Source files are in iCloud: `/Users/rorystone/Library/Mobile Documents/com~apple~CloudDocs/Business/Stone Co/GPX/`
- File path stored in `entries.path` column

**Trackpoint format must match StoneBC exactly:**
```json
"trackpoints": [
    [44.350385, -103.933311, 1532.6],
    [44.350401, -103.933289, 1533.1],
    ...
]
```
Where: `[latitude, longitude, elevation_in_meters]`

Note: StoneBC's Route.swift stores elevation in meters in trackpoints but displays in feet (× 3.28084).

---

## Phase 3: StoneBC Integration Changes

### Minimal changes needed — the export matches existing schema

**No changes required to:**
- Route.swift (model already matches)
- RoutesView.swift (filtering works with existing difficulty/category values)
- RouteDetailView.swift (stats computed from trackpoints)
- RouteMapView.swift (reads trackpoints as-is)
- RouteExplorerView.swift (connection detection uses trackpoints)
- RouteNavigationView.swift (uses trackpoints for progress)
- GPXImportView.swift (user imports remain separate)
- GPXService.swift (export still works)

**Optional enhancements:**
1. Add `event` field to Route.swift for race/event names (display in RouteDetailView)
2. Add `surface` field to Route.swift for surface type badges
3. Add sync-from-Alexandria button in settings (hits localhost:8642/api/routes)

### AppState.swift — No changes for bundled routes

`Route.loadFromBundle()` already reads `routes.json` from the bundle. Replacing the file contents is all that's needed. User-imported routes live in the Documents-backed `UserRouteStore` and should remain untouched.

---

## Phase 4: REST API Endpoint (Future/Optional)

Add to Alexandria's Dashboard.swift:

```
GET /api/routes                    → All routes with metadata (no trackpoints)
GET /api/routes?full=true          → All routes with full trackpoints
GET /api/routes/:id                → Single route with trackpoints
GET /api/routes/export/stonebc     → Full StoneBC-format JSON
```

StoneBC could add a "Sync Routes" button that:
1. Hits `http://<mac-ip>:8642/api/routes/export/stonebc`
2. Decodes as `[Route]`
3. Replaces `AppState.routes`
4. Persists to the Documents-backed user route store only if the user explicitly saves imported routes

This requires same-network access (WiFi). Not a priority — bundled JSON works fine.

---

## Verification Plan

### After export:
```bash
# Generate the export
alexandria routes export --output /Applications/Apps/StoneBC/StoneBC/routes.json

# Verify JSON is valid and has expected count
python3 -c "import json; d=json.load(open('/Applications/Apps/StoneBC/StoneBC/routes.json')); print(f'{len(d)} routes'); print(d[0].keys())"

# Check route IDs are unique
python3 -c "import json; d=json.load(open('/Applications/Apps/StoneBC/StoneBC/routes.json')); ids=[r['id'] for r in d]; print(f'Unique: {len(set(ids))}/{len(ids)}')"

# Verify trackpoints exist for all routes
python3 -c "import json; d=json.load(open('/Applications/Apps/StoneBC/StoneBC/routes.json')); [print(f\"{r['name']}: {len(r['trackpoints'])} pts, {r['distanceMiles']:.1f} mi\") for r in d]"
```

### After StoneBC build:
1. Build and run StoneBC in simulator
2. Verify Routes tab shows all routes with correct stats
3. Verify difficulty/category filters work
4. Verify Route Explorer shows all routes on map
5. Tap a route → verify elevation chart renders
6. Verify connection detection still works between nearby routes
7. Verify GPX export from a route produces valid GPX
8. Verify imported routes in `Documents/Routes/userRoutes.json` are not affected

---

## Files to Create/Modify

### Alexandria (export side):
| File | Action | What |
|------|--------|------|
| `Sources/Alexandria/Alexandria.swift` | Modify | Add `RoutesExport` subcommand |
| `Sources/AlexandriaLib/LibraryService.swift` | Modify | Add `exportRoutesForStoneBC()` method |
| `Sources/AlexandriaLib/Models.swift` | Modify | Add `StoneBCRoute` Codable struct |
| `Sources/AlexandriaLib/ContentExtractor.swift` | Modify | Add `extractTrackpoints(from:)` public method |

### StoneBC (consume side):
| File | Action | What |
|------|--------|------|
| `StoneBC/routes.json` | Replace | New export from Alexandria |
| (nothing else required for Phase 1) | — | Schema already matches |

---

## Key Constraints

- **Offline-first:** routes.json must be bundled, not fetched at runtime
- **Elevation in meters:** trackpoints store meters, app converts to feet for display
- **Existing imported routes:** must not be overwritten — they live in `UserRouteStore`
- **GPX source files must be accessible:** they're in iCloud, path stored in entries.path
- **2 routes have 0 trackpoints** (Sturgis Med, 2022Dakota50v2) — waypoint-only files. Either skip them in export or include with startCoordinate only.
- **Route IDs must be stable** across re-exports so bookmarks/favorites don't break (use kebab-case filename as ID)
