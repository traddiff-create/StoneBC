# Stone Bicycle Coalition

A forkable local-first bike co-op app. The primary app is a SwiftUI iOS app; an Android port lives under `android/`.

**Features:** offline route import/export, navigation, ride recording, ride history, bike marketplace, community content, events, Rally Radio, tour guides, and Follow My Expedition.

## Quick Start

```bash
cd StoneBC
open app.xcodeproj
```

Build and run scheme `StoneBC` on an iOS 17+ simulator or device.

CLI build:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -scheme StoneBC \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

## For Your Co-op

1. **Fork this repo**
2. **Edit `StoneBC/config.json`** — your name, email, location, colors
3. **Replace data files** — `bikes.json`, `posts.json`, `events.json`
4. **Change bundle ID** in Xcode (Signing & Capabilities)
5. **Build & submit** to the App Store

See `CUSTOMIZE_ME/BUILD_CHECKLIST.md` for the owner walkthrough and `CUSTOMIZE_ME/` for template data files.

## Architecture

| Layer | Tech |
|-------|------|
| UI | SwiftUI, iOS 17+ |
| State | `@Observable` AppState (MVVM) |
| Data | Bundled JSON (local-first) + optional WordPress REST API sync |
| Navigation | TabView (Home, Routes, Record, Rides, More) |
| Config | `config.json` — feature flags, branding, contact info |

## App Structure

```
StoneBC/
├── App shell:      StoneBCApp, ContentView, TabContainerView
├── State:          AppState (@Observable)
├── Routes:         List/map browsing, route prep, navigation, route interop services
├── Recording:      Free/Follow/Scout modes, RouteRecordingView, RideSession, WorkoutService
├── Rides:          RidesTabView, RideHistoryService, RideJournalService
├── Marketplace:    MarketplaceView, BikeDetailView, inventory JSON
├── More:           events, programs, gallery, contact, tour guides, expeditions
├── Expedition:     Follow My Expedition capture, timeline, map, PDF/HTML export
├── Radio:          Rally Radio MultipeerConnectivity stack
├── Design:         BCDesignSystem tokens and reusable components
└── Data:           config.json, bikes.json, posts.json, events.json, routes.json, guides.json
```

## Data Files

| File | Purpose | Format |
|------|---------|--------|
| `config.json` | Co-op identity, colors, feature flags | See `CUSTOMIZE_ME/CONFIG_TEMPLATE.json` |
| `bikes.json` | Bike inventory from The Quarry POS | `{ "bikes": [...] }` |
| `posts.json` | Community bulletin board posts | `[...]` with markdown body |
| `events.json` | Events and workshops | `[...]` with category/recurring |
| `routes.json` | Cycling routes with GPX trackpoints and optional ride defaults | `[...]` with coordinates |
| `guides.json` | Multi-day tour guides | `[...]` with days, stops, overlays |

Runtime route import/export supports GPX, TCX, FIT, KML/KMZ, and ZIP device bundles through the Files app and native share sheet. Garmin, Wahoo, and Ride with GPS actions are provider-gated; local file workflows remain the offline fallback. Rider route preferences are local, per-route settings for overlays, prep state, and post-ride save defaults.

## WordPress Integration (Optional)

Set `dataURLs.wordpressBase` in `config.json` to your WordPress REST API URL. The app will sync bikes, posts, and events on launch, falling back to bundled JSON if the network is unavailable.

Expected WordPress setup:
- Custom post types: `sbc_bike`, `sbc_event` with ACF fields
- Standard `posts` endpoint for community feed

## Documentation

Start with [docs/README.md](docs/README.md).

Core engineering docs:

- [Getting Started](docs/GETTING_STARTED.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Build, Test, Release](docs/BUILD_TEST_RELEASE.md)
- [Configuration](docs/CONFIGURATION.md)
- [Data Model](docs/DATA_MODEL.md)
- [Permissions & Services](docs/PERMISSIONS_SERVICES.md)
- [Offline Storage](docs/OFFLINE_STORAGE.md)
- [Routes & Route Interop](docs/ROUTES.md)
- [Follow My Expedition](docs/FOLLOW_MY_EXPEDITION.md)

## Auth, Payments, Data

The app has no in-app payments and no analytics. Most user flows are local-only. Optional member login exists for member-specific flows, and the token is stored locally by `MemberAuthService`.

The co-op owner manages public content by editing JSON, exporting inventory, or configuring optional WordPress public content sync.

## License

Creative Commons BY-SA 4.0 — fork it, customize it, share it back.

## Credits

Built by [Stone Bicycle Coalition](https://stonebicyclecoalition.com) in Rapid City, South Dakota.

Part of the [OpenSource-BikeCoopToolkit](OpenSource-BikeCoopToolkit/) — a complete guide for starting your own community bike co-op.
