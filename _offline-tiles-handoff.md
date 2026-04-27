# StoneBC Offline Tile Pack — Handoff

**Status:** Scaffolding landed (2026-04-25). Two follow-up steps required to ship offline tile rendering.

## What's done in code

| File | Purpose |
|---|---|
| `StoneBC/RideMapTileOverlay.swift` | `MKTileOverlay` subclasses (`USFSTileOverlay`, `OSMCycleTileOverlay`) reading from `Bundle.main.url(forResource: "tiles/<provider>/{z}/{x}/{y}", withExtension: "png")`. |
| `StoneBC/OfflineCapableMapView.swift` | `UIViewRepresentable<MKMapView>` wrapper that hosts the two tile overlays + route + breadcrumb polylines. Ready to swap into `RouteNavigationView` and `RouteRecordingView`. |
| `StoneBC/NetworkStatusService.swift` | `NWPathMonitor` wrapper, `@Observable isOnline`. Started from `StoneBCApp.swift`. |
| `StoneBC/OfflineTileCoverage.swift` | Loads bbox + zoom + attribution from `Resources/tiles/tile_coverage.json` at runtime; falls back to the hard-coded Black Hills + foothills bbox until the pack ships. |
| `StoneBC/OfflineRouteStorage.swift` | `CachedRouteEntry` extended with `tilesAvailable: Bool` (decoder is backwards-compat — legacy index entries default to false). |
| `StoneBC/RouteNavigationView.swift` | OFFLINE pill HUD overlay on the navigation map (`offline / offline · no tiles / out of tile pack`). Uses `NetworkStatusService` + `OfflineTileCoverage`. |
| `Scripts/build_tile_pack.py` | One-shot builder. Reads two source MBTiles archives (USFS topo + OSM Cycle), crops to the bbox, writes the xyz tree under `StoneBC/Resources/tiles/`, emits `tile_coverage.json`. |

## Two steps remaining to render tiles offline

### 1. Source MBTiles + run the build script

The pack needs ~150 MB total covering the Black Hills + foothills (Wind Cave south to Belle Fourche / Sturgis north, Wyoming line east to Box Elder), zoom 11–14.

**USFS topo (public domain):**
- Best source: USFS 2024 national raster topo via `https://services.nationalmap.gov/arcgis/rest/services/USGSTopo/MapServer`
- Easier path: download a regional GeoPackage from `data.fs.usda.gov` and convert with `gdal_translate` + `gdaldem tri` to produce raster tiles, then pack with `mb-util` to MBTiles.

**OSM Cycle Map (CC BY-SA):**
- ThunderForest OpenCycleMap export (paid, smallest dev cost): `https://www.thunderforest.com/maps/opencyclemap/`
- Free path: `tilemaker` against a Black Hills `.osm.pbf` extract (Geofabrik US/SD region) with the `cycle.lua` profile.

Once both `.mbtiles` files exist, run:

```bash
python3 Scripts/build_tile_pack.py \
    --usfs path/to/usfs.mbtiles \
    --osm path/to/osm-cycle.mbtiles
```

The script prints total bytes and warns if outside the ~150 MB ± 10 % target.

### 2. Bundle the tile tree + migrate the two Map sites

After the script writes `StoneBC/Resources/tiles/`, the directory needs to ship with the app:

- In Xcode → StoneBC target → Build Phases → Copy Bundle Resources → `+` → add the `Resources/tiles` folder as a **folder reference** (blue folder, not yellow group). This preserves the `{z}/{x}/{y}.png` tree at runtime so `Bundle.main.url(forResource:)` can find tiles by path.
- Add `tile_coverage.json` to the same Copy Bundle Resources phase (it's at the root of `Resources/tiles/`).

Then migrate the two `Map(...)` sites to `OfflineCapableMapView`:

- **`RouteNavigationView.swift:342–402`** (`navigationMap`) — replace the SwiftUI `Map` with `OfflineCapableMapView(region: $region, isFollowingUser: $isFollowingUser, routePolyline: route.clTrackpoints, breadcrumb: breadcrumbs, routeColor: BCColors.routeOrange.uiColor)`. Keep the existing camera-follow logic; the wrapper handles user-pan detection.
- **`RouteRecordingView.swift:173–213`** — same swap, route polyline becomes `recording.trackpoints.map(\.coordinate)`, no `routePolyline` argument needed (free-recording mode has no planned route).

Both view bodies currently compute a `MapCameraPosition`; convert that to an `MKCoordinateRegion` `@State` for the wrapper. The conversion is mechanical.

## Verification (after both steps land)

1. `du -sh StoneBC/Resources/tiles/usfs StoneBC/Resources/tiles/osm` should sum to ~150 MB ± 10 %.
2. `xcodebuild` should still pass.
3. On iPhone 17 Pro Max simulator: open a Black Hills route, toggle Network → Off → basemap topography still renders inside the bbox.
4. Outside the bbox in airplane mode: basemap blank, polyline + breadcrumb + cue sheet still render, OFFLINE pill appears.
5. About screen: confirm OSM CC BY-SA attribution string is visible (`OfflineTileCoverage.attributionString`).
6. `/test-stonebc` Blitz pass — gates on launch + tab nav.

## Why split this out

The view migration is invasive enough that it deserves its own focused session with QA. The ride-truth P0s (HK pause/duration, one shared engine, ActivityKit staleDate, barometer in both pipelines) ship without it — this scaffolding leaves the offline rendering one mechanical step from done.
