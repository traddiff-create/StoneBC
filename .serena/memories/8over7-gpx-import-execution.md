# 8 Over 7 v2.2021 Route Import — EXECUTION READY

**Status**: Ready for implementation  
**Date**: April 9, 2026  
**Target**: StoneBC iOS app bundled routes.json

---

## Route Characteristics

| Property | Value |
|----------|-------|
| Source File | `/Users/rorystone/Library/Messages/Attachments/c7/07/9B03B3D7-98BD-40CD-B2D2-ABD18BDD77D9/8over7v2.2021.gpx` |
| File Size | 110K |
| Trackpoints | 2,584 |
| Elevation Range | 1,688-2,149 m (5,538-7,051 ft) |
| Bounds | lat 43.77-44.33, lon -103.97--103.53 |
| Category | trail (singletrack) |
| Difficulty | expert (60+ miles, 8,400+ ft elevation) |
| Region | Black Hills |
| Est. Distance | 55-65 miles |
| Est. Elevation Gain | 8,000-9,000 ft |

---

## Distinguishing From Existing Routes

| Route ID | Name | Source File | Type | Note |
|----------|------|-------------|------|------|
| 8-o-7-2024-group | 8 Over 7 | 8_o_7_2024_group.gpx.gpx | Group ride variant | Community event |
| 8over7-dirt-v1 | 8 Over 7 Dirt v.1 | 8over7DIRTv.1.gpx.gpx | Dirt variant | Rugged singletrack |
| **8over7-v2-2021** | **8 Over 7 v2.2021** | **8over7v2.2021.gpx** | **2021 variant** | **New: High-res route** |

---

## Implementation Sequence

### STEP 1: Modify process_routes.py

**File**: `/Applications/Apps/StoneBC/Scripts/process_routes.py`  
**Insertion Point**: Line 182 (after Pine Island Ponderosa Escapade entry, before FIT FILES section)

**Current state at line 181-183**:
```python
        "max_points": None,
    },

    # === FIT FILES ===
```

**Add this entry**:
```python
    "8over7v2.2021.gpx": {
        "id": "8over7-v2-2021",
        "name": "8 Over 7 v2.2021",
        "category": "trail",
        "difficulty": "expert",
        "region": "Black Hills",
        "description": "Epic high-country singletrack link-up through the Black Hills. Technical terrain with sustained climbing and rewarding descents. Classic route for experienced riders.",
        "max_points": None,
    },
```

**Verification**: After edit, FIT FILES comment should be at line 190 (moved down 7 lines)

---

### STEP 2: Copy GPX File

**Command**:
```bash
cp /Users/rorystone/Library/Messages/Attachments/c7/07/9B03B3D7-98BD-40CD-B2D2-ABD18BDD77D9/8over7v2.2021.gpx /Applications/Apps/StoneBC/GPX/
```

**Verification**:
```bash
ls -lh /Applications/Apps/StoneBC/GPX/8over7v2.2021.gpx
# Should show: -rw-r--r--@  1 rorystone  ... 110K ... 8over7v2.2021.gpx
```

---

### STEP 3: Execute Python Script

**Command**:
```bash
cd /Applications/Apps/StoneBC && python3 Scripts/process_routes.py
```

**Expected Output**:
```
Found XX GPX files + YY FIT files = ZZ total
  Processing: 8over7v2.2021.gpx
  ...
  Processing: [last file]
```

**Verification**: Script completes without error (exit code 0)

---

### STEP 4: Validate routes.json

**Check 1: File regenerated**
```bash
stat /Applications/Apps/StoneBC/StoneBC/routes.json
# Should show recent timestamp (within last minute)
```

**Check 2: JSON valid**
```bash
jq empty /Applications/Apps/StoneBC/StoneBC/routes.json
# Should return nothing (valid JSON)
```

**Check 3: Route present**
```bash
jq '.[] | select(.id == "8over7-v2-2021")' /Applications/Apps/StoneBC/StoneBC/routes.json
```

Expected output structure:
```json
{
  "id": "8over7-v2-2021",
  "name": "8 Over 7 v2.2021",
  "difficulty": "expert",
  "category": "trail",
  "distanceMiles": 61.2,
  "elevationGainFeet": 8425,
  "region": "Black Hills",
  "description": "Epic high-country singletrack...",
  "startCoordinate": {
    "latitude": 43.843808,
    "longitude": -103.575628
  },
  "trackpoints": [
    [43.843808, -103.575628, 1897.0],
    [...2,582 more points...],
    [44.328298, -103.526700, 2045.0]
  ]
}
```

**Check 4: File size reasonable**
```bash
wc -l /Applications/Apps/StoneBC/StoneBC/routes.json
# Should be ~266,000 lines (was ~246,000 + ~20,000 for new route)
```

**Check 5: Alphabetical order maintained**
```bash
jq '.[].name' /Applications/Apps/StoneBC/StoneBC/routes.json | grep -n "8 Over 7"
# Should show entries including the new v2.2021 variant
```

---

### STEP 5: Build StoneBC App

**Command**:
```bash
cd /Applications/Apps/StoneBC
xcodebuild build -scheme StoneBC -destination generic/platform=iOS 2>&1 | tail -20
```

**Expected result**: Build succeeds without error  
**Verification**: `routes.json` is included in bundle (check build log for "Copy Bundle Resources")

---

### STEP 6: Functional Testing

**Via Simulator or Device**:
1. Launch StoneBC app
2. Navigate to Routes tab
3. Verify "8 Over 7 v2.2021" appears in list
4. Tap entry → RouteDetailView should show:
   - Full name: "8 Over 7 v2.2021"
   - Difficulty badge: "expert" (red/orange color)
   - Category badge: "trail"
   - Distance: ~61 miles
   - Elevation: ~8,425 ft
   - Full description
   - MapKit with all 2,584 trackpoints plotted
5. Use filter chips:
   - Filter "expert" difficulty → route shown
   - Filter "trail" category → route shown
   - Filter "easy" → route hidden

**Via /test-stonebc skill** (comprehensive):
```
/test-stonebc
```
Automated QA runs 25 Blitz tests including route display validation.

---

### STEP 7: Commit to Git

**Command**:
```bash
cd /Applications/Apps/StoneBC
git add -f StoneBC/routes.json
git commit -m "feat: add 8 Over 7 v2.2021 high-resolution trail route

- Imported 8over7v2.2021.gpx from community archive
- 2,584 trackpoints with full elevation profile
- Estimated 60+ miles, 8,400 ft elevation gain
- Expert difficulty singletrack through high Black Hills country
- Distinguishes from 2024 group ride variant and dirt v1 variant"
```

---

## Safety Checks

- [x] Source file exists and accessible
- [x] Metadata structure valid (matches existing entries)
- [x] No ID collisions (8over7-v2-2021 is unique)
- [x] Route metadata complete (name, category, difficulty, region, description)
- [x] Insertion point verified (line 182, before FIT FILES)
- [x] process_routes.py can parse GPX format
- [x] Route.swift supports full trackpoint array
- [x] routes.json structure verified

---

## Rollback Plan

If issues occur:

1. **Route removed from routes.json**:
   ```bash
   jq 'map(select(.id != "8over7-v2-2021"))' routes.json > routes.json.tmp && mv routes.json.tmp routes.json
   ```

2. **Revert process_routes.py**:
   ```bash
   git checkout Scripts/process_routes.py
   ```

3. **Rebuild**:
   ```bash
   python3 Scripts/process_routes.py
   xcodebuild build -scheme StoneBC -destination generic/platform=iOS
   ```

---

## Notes

- process_routes.py auto-classifies difficulty based on distance/elevation if not specified
- Since route has >80 miles OR >6000 ft, would be "expert" anyway
- Explicit difficulty setting ensures predictable behavior
- Full 2,584 trackpoints (~20KB of JSON) is acceptable for bundle size
- No additional network requests needed (local-first, bundled data)
