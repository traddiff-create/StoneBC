# Getting Started — StoneBC Development

## Prerequisites

- macOS with Xcode 26.2+
- iOS 17.0+ deployment target
- No external dependencies (pure SwiftUI + Apple frameworks)

## Quick Start

```bash
cd /Applications/Apps/StoneBC
open StoneBC.xcodeproj
```

Build and run on any iOS 17+ simulator.

## CLI Build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -project StoneBC.xcodeproj \
  -scheme StoneBC \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Run on Simulator

```bash
# Boot simulator
xcrun simctl boot 00F18EF1-BF95-49A8-A210-411A3AFEA4B4

# Install
xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/StoneBC-*/Build/Products/Debug-iphonesimulator/StoneBC.app

# Launch
xcrun simctl launch booted com.traddiff.StoneBC
```

## Automated Testing

```bash
# Run full QA suite (builds, deploys, tests 25 flows via Blitz)
/test-stonebc
```

## Key Files to Know

| File | What It Does |
|------|-------------|
| `AppState.swift` | Central state — all data lives here |
| `AppConfig.swift` | Config model + `config.json` loader |
| `BCDesignSystem.swift` | All reusable UI components |
| `TabContainerView.swift` | Tab navigation (5 tabs) |
| `config.json` | Edit this to customize the app |
| `bikes.json` | Bike inventory (sync from `inventory/bikes.json`) |

## Adding Content

### New bike
Edit `inventory/bikes.json` via POS or directly, then copy to `StoneBC/bikes.json`.

### New post
Add entry to `StoneBC/posts.json` with id, title, body (markdown), date, category.

### New event
Add entry to `StoneBC/events.json` with id, title, date, location, category.

### New route
Add GPX file to `GPX/`, run `python Scripts/process_routes.py`, update `routes.json`.

## For Other Co-ops

See `CUSTOMIZE_ME/BUILD_CHECKLIST.md` for the full fork and customize guide.

## Git Notes

Parent repo gitignore blocks `*`. Always use `git add -f` when staging StoneBC files.
