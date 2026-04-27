# Getting Started — StoneBC Development

## Prerequisites

- macOS with Xcode 26.2+
- iOS 17.0+ deployment target
- No external dependencies (pure SwiftUI + Apple frameworks)

## Quick Start

```bash
cd /Applications/Apps/StoneBC
open app.xcodeproj
```

Build and run scheme `StoneBC` on any iOS 17+ simulator.

## CLI Build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -scheme StoneBC \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

## Run on Simulator

```bash
# Boot simulator
xcrun simctl boot "iPhone 17 Pro Max" 2>/dev/null || true

# Install
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/app-*/Build/Products/Debug-iphonesimulator/StoneBC.app

# Launch
xcrun simctl launch booted com.traddiff.StoneBC
```

## Automated Testing

```bash
# Minimum local verification
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -scheme StoneBC \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

See [Testing](TESTING.md) for simulator and real-device QA.

## Key Files to Know

| File | What It Does |
|------|-------------|
| `AppState.swift` | Central state — all data lives here |
| `AppConfig.swift` | Config model + `config.json` loader |
| `BCDesignSystem.swift` | All reusable UI components |
| `TabContainerView.swift` | Tab navigation (5 tabs) |
| `config.json` | Edit this to customize the app |
| `bikes.json` | Bike inventory (sync from `inventory/bikes.json`) |
| `ExpeditionJournal.swift` | Follow My Expedition data model |
| `ExpeditionTimelineView.swift` | Expedition field log, autosave, PDF export |

## Adding Content

### New bike
Edit `inventory/bikes.json` via POS or directly, then copy to `StoneBC/bikes.json`.

### New post
Add entry to `StoneBC/posts.json` with id, title, body (markdown), date, category.

### New event
Add entry to `StoneBC/events.json` with id, title, date, location, category.

### New route
Add source files to `GPX/`, run `python Scripts/process_routes.py`, update `routes.json`, then verify the route count. Runtime user imports are handled separately by `RouteInterchangeService` and can accept GPX, TCX, FIT, KML/KMZ, and ZIP bundles from Files.

### New expedition guide
Edit `StoneBC/guides.json`. Each guide contains days, stops, optional route references, safety notes, and journal affordances.

## For Other Co-ops

See `CUSTOMIZE_ME/BUILD_CHECKLIST.md` for the full fork and customize guide. See [Configuration](CONFIGURATION.md) for the engineering details behind `config.json`.

## Git Notes

Parent repo gitignore blocks `*`. Always use `git add -f` when staging StoneBC files.
