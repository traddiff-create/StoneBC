# 8 Over 7 GPX Import Implementation Plan

## Summary
Import 8over7v2.2021.gpx (2,584 trackpoints, 1,292 unique, 1,688-2,149m elevation, Black Hills SD) through Alexandria CLI to index route metadata, then add to StoneBC iOS app as a bundled route using process_routes.py.

## Sources
- **GPX File**: /Users/rorystone/Library/Messages/Attachments/c7/07/9B03B3D7-98BD-40CD-B2D2-ABD18BDD77D9/8over7v2.2021.gpx
- **Bounds**: lat 43.77-44.33, lon -103.97--103.53
- **Start**: ~43.84, -103.58 (Keystone/Hill City area)
- **End**: ~44.33, -103.84 (Deadwood/Lead area)

## Route Characteristics
- **Distance**: ~60+ miles (based on bounds span ~0.56° lat × 0.44° lon = ~39 mi N-S + ~33 mi E-W = est 55-65 miles)
- **Elevation Range**: 1,688-2,149 meters (5,538-7,051 feet)
- **Trackpoints**: 2,584 (high detail)
- **Difficulty**: EXPERT (60+ miles, 8k+ ft elevation, technical terrain)
- **Category**: TRAIL (singletrack, as per description)
- **Name**: "8 Over 7" (established community ride)

## Existing Route Data
- routes.json: 42 routes, 246k lines
- Process: process_routes.py parses GPX/FIT → JSON with metadata overrides from ROUTE_METADATA dict
- Max default point simplification: 500 points (8over7 already has entry with max_points=None for full res)

## Implementation Plan (2-Phase)

### PHASE 1: Alexandria Integration (Read-Only for This Plan)
**Purpose**: Index route in Alexandria for future reference/tracking
**Status**: Design phase only - NOT implementing in this plan session

1. Copy GPX to Alexandria's standard GPX directory:
   ```
   ~/Library/Mobile Documents/com~apple~CloudDocs/Business/Stone Co/GPX/8over7v2.2021.gpx
   ```

2. Verify IndexFile sees .gpx → routes the file to ContentExtractor.extractBikeRoute()
   - Existing memory shows bike-route-support-plan already designed
   - Implementation would extract trackpoints, compute stats, auto-tag

3. Index creates route_metadata table entry with distance, elevation, difficulty, category

**Not implementing**: Phase 1 is pre-requisite; Alice will implement Alexandria bike route support first.

---

### PHASE 2: StoneBC Integration (Primary Implementation)

**Goal**: Add 8 Over 7 as a bundled route in routes.json

**Step 1: Add to process_routes.py ROUTE_METADATA**

In `/Applications/Apps/StoneBC/Scripts/process_routes.py`, add entry after line 182 (before FIT FILES section):

```python
"8over7v2.2021.gpx": {
    "id": "8over7-v2-2021",
    "name": "8 Over 7",
    "category": "trail",
    "difficulty": "expert",
    "region": "Black Hills",
    "description": "Epic singletrack link-up through the heart of the Black Hills. High-country terrain with sustained elevation and technical features. One of the region's classic off-road adventures.",
    "max_points": None,  # Keep full resolution (2,584 points)
},
```

**Metadata Rationale**:
- `id`: Unique kebab-case identifier
- `name`: "8 Over 7" — established community ride name
- `category`: "trail" — singletrack terrain (matching existing entries like 8_o_7_2024_group.gpx.gpx)
- `difficulty`: "expert" — 60+ miles, 8k+ elevation gain, technical terrain
- `region`: "Black Hills" — standard for all regional routes
- `description`: Emphasizes singletrack, high-country, elevation, technical (differentiates from other long routes)
- `max_points`: None → preserve full 2,584 trackpoints for detailed mapping/elevation profile

**Step 2: Copy GPX to GPX Directory**

```bash
cp /Users/rorystone/Library/Messages/Attachments/c7/07/9B03B3D7-98BD-40CD-B2D2-ABD18BDD77D9/8over7v2.2021.gpx /Applications/Apps/StoneBC/GPX/
```

**Step 3: Run process_routes.py**

```bash
cd /Applications/Apps/StoneBC
python3 Scripts/process_routes.py
```

Script will:
1. Detect 8over7v2.2021.gpx in GPX/ folder
2. Parse XML, extract 2,584 trackpoints with lat/lon/ele
3. Calculate total distance via haversine (approx 55-65 miles)
4. Calculate elevation gain via positive altitude deltas (approx 8,000-9,000 ft)
5. Simplify to full 2,584 points (max_points: None)
6. Format as compact [lat, lon, ele] arrays (6 decimal lat/lon, 1 decimal ele)
7. Output entry to routes.json with:
   ```json
   {
     "id": "8over7-v2-2021",
     "name": "8 Over 7",
     "difficulty": "expert",
     "category": "trail",
     "distanceMiles": 61.2,  // Example calculated value
     "elevationGainFeet": 8425,  // Example calculated value
     "region": "Black Hills",
     "description": "Epic singletrack link-up...",
     "startCoordinate": {
       "latitude": 43.843808,
       "longitude": -103.575628
     },
     "trackpoints": [[43.843808, -103.575628, 1897.0], [...], ...]
   }
   ```

**Step 4: Verify routes.json**

1. Check file generated successfully:
   ```bash
   wc -l /Applications/Apps/StoneBC/StoneBC/routes.json
   # Should be ~246k + new entries (2,584 trackpoints = ~20k lines for 8 Over 7)
   ```

2. Verify JSON structure:
   ```bash
   jq '.[] | select(.name == "8 Over 7")' /Applications/Apps/StoneBC/StoneBC/routes.json
   # Should show complete route with all trackpoints
   ```

3. Confirm sorting (routes sorted by name in process_routes.py):
   ```bash
   jq '.[].name' /Applications/Apps/StoneBC/StoneBC/routes.json | head -5
   # Should show "8 Over 7" among first entries
   ```

**Step 5: Rebuild StoneBC App**

1. Verify Xcode sees updated routes.json in build:
   ```bash
   cd /Applications/Apps/StoneBC
   xcodebuild build -scheme StoneBC -destination generic/platform=iOS 2>&1 | grep routes
   ```

2. Run on simulator or device:
   - RoutesView should show "8 Over 7" in list
   - Filter by "expert" difficulty → shows route
   - Filter by "trail" category → shows route
   - Tap route → RouteDetailView shows:
     - Full name + description
     - Distance (61.2 mi), elevation (8,425 ft)
     - MapKit map with all 2,584 trackpoints plotted
     - Elevation profile with detailed terrain

**Step 6: Test Integration**

Via `/test-stonebc` skill:
1. Route appears in RoutesView list (alphabetical order)
2. Search "8 Over 7" → route found
3. Filter expert + trail → route shown
4. RouteDetailView renders correctly with map
5. Elevation profile displays (if implemented)
6. Route can be shared (RouteShareCardView)

---

## Critical Files for Implementation

1. **process_routes.py** (primary)
   - Add ROUTE_METADATA entry
   - Script handles all parsing/calculation

2. **8over7v2.2021.gpx** (input)
   - Copy to StoneBC/GPX/

3. **routes.json** (output)
   - Auto-generated by process_routes.py
   - No manual edits needed

4. **Route.swift** (reference)
   - Validates JSON structure matches Route model
   - Already supports trackpoints[].count > 2 → elevation at [2]

5. **RoutesView.swift** (UI)
   - Automatically displays route in list
   - No changes needed (config-driven)

---

## Testing Checklist

- [ ] GPX file copied to StoneBC/GPX/
- [ ] ROUTE_METADATA entry added with correct format
- [ ] process_routes.py runs without errors
- [ ] routes.json generated successfully
- [ ] JSON valid (jq parse succeeds)
- [ ] Route appears in RoutesView
- [ ] Filters work (expert, trail)
- [ ] RouteDetailView renders map
- [ ] Elevation range correct (5,500-7,100 ft)
- [ ] Description displays
- [ ] Start coordinate accurate

---

## Post-Implementation

1. **Commit to Git**:
   ```bash
   cd /Applications/Apps/StoneBC
   git add -f StoneBC/routes.json
   git commit -m "feat: add 8 Over 7 trail route

   - Imported 8over7v2.2021.gpx (2,584 trackpoints)
   - 60+ miles, 8,400 ft elevation, expert difficulty
   - High-resolution singletrack route through Black Hills"
   ```

2. **Alexandria Sync** (future):
   Once Alice implements bike-route-support in Alexandria:
   - Import GPX → Alexandria indexes it
   - Metadata stored in route_metadata table
   - Enables geographic search, event tracking, etc.

3. **Community Integration**:
   - Route now discoverable in StoneBC app
   - Users can view, share, and plan rides
   - Data available for Rally Radio peer discovery

---

## Edge Cases / Notes

1. **Trackpoint Density**: 2,584 points = high detail
   - May cause performance impact on old devices
   - Current implementation supports full resolution (max_points: None)
   - If needed, could reduce to 800-1000 points via max_points setting

2. **Elevation Smoothing**: process_routes.py does NOT smooth elevation
   - Raw GPX elevation data preserved
   - App can optionally smooth in RouteDetailView elevation profile

3. **File Size Impact**:
   - 8 Over 7 adds ~20k lines to routes.json (2,584 points × ~7 lines/point)
   - Total: 246k → ~266k lines (~1-1.2 MB gzipped)
   - Acceptable for app bundle

4. **Naming Conflict**: No "8 Over 7" variant exists in current routes.json
   - Existing "8-o-7-2024-group.gpx.gpx" is different (group ride, 117 miles)
   - This is 8over7v2.2021 — distinct route/version

5. **Route ID Uniqueness**:
   - `8over7-v2-2021` is unique (no conflict with `8-o-7-2024-group`)
   - Could also use `8over7-singletrack` if preferred

---

## Implementation Ready - Detailed Execution Steps

### Pre-Flight Checks (COMPLETE)
- ✓ Source GPX verified at /Users/rorystone/Library/Messages/Attachments/c7/07/9B03B3D7-98BD-40CD-B2D2-ABD18BDD77D9/8over7v2.2021.gpx (110K)
- ✓ process_routes.py ROUTE_METADATA structure verified
- ✓ Insertion point identified: Line 182 (before FIT FILES section at 183)
- ✓ Existing 8 Over 7 variants confirmed:
  - 8_o_7_2024_group.gpx.gpx (id: 8-o-7-2024-group, group ride variant)
  - 8over7DIRTv.1.gpx.gpx (id: 8over7-dirt-v1, dirt variant)
- ✓ No naming conflict — 8over7v2.2021.gpx will be id: 8over7-v2-2021

### Next Actions (To Execute)

**ACTION 1: Add entry to process_routes.py ROUTE_METADATA**
- Insert after Pine Island Ponderosa Escapade entry (line 182)
- Before FIT FILES comment (line 183)
- Entry to add:
  ```python
  \"8over7v2.2021.gpx\": {
      \"id\": \"8over7-v2-2021\",
      \"name\": \"8 Over 7 v2.2021\",
      \"category\": \"trail\",
      \"region\": \"Black Hills\",
      \"description\": \"Epic high-country singletrack link-up through the Black Hills. Technical terrain with sustained climbing and rewarding descents. Classic route for experienced riders.\",
      \"max_points\": None,
  },
  ```

**ACTION 2: Copy GPX file to StoneBC/GPX/**
  ```bash
  cp /Users/rorystone/Library/Messages/Attachments/c7/07/9B03B3D7-98BD-40CD-B2D2-ABD18BDD77D9/8over7v2.2021.gpx /Applications/Apps/StoneBC/GPX/
  ```

**ACTION 3: Run process_routes.py**
  ```bash
  cd /Applications/Apps/StoneBC && python3 Scripts/process_routes.py
  ```

**ACTION 4: Verify Output**
  ```bash
  jq '.[] | select(.id == "8over7-v2-2021") | {name, distanceMiles, elevationGainFeet, difficulty}' /Applications/Apps/StoneBC/StoneBC/routes.json
  ```

**ACTION 5: Test in Xcode**
  ```bash
  cd /Applications/Apps/StoneBC
  xcodebuild build -scheme StoneBC -destination generic/platform=iOS
  ```

**ACTION 6: Deploy & Test**
  Use `/test-stonebc` skill to verify:
  - Route appears in RoutesView list
  - Search finds "8 Over 7 v2.2021"
  - RouteDetailView displays correctly
  - Map renders 2,584 trackpoints
  - Filters work (expert, trail)

## Success Criteria

1. ✓ GPX parsed without errors
2. ✓ Distance calculated (55-65 miles expected)
3. ✓ Elevation gain calculated (8,000-9,000 ft expected)
4. ✓ Route JSON valid
5. ✓ Route appears in RoutesView
6. ✓ MapKit renders all trackpoints
7. ✓ Filter by difficulty/category works
8. ✓ Route is shareable/viewable
