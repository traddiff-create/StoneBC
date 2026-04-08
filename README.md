# Stone Bicycle Coalition — iOS App

A forkable iOS app for community bicycle cooperatives. Built with SwiftUI.

**Features:** Bike marketplace, community feed, cycling routes, events, and programs — all config-driven so any bike co-op can make it their own.

## Quick Start

```bash
git clone https://github.com/your-fork/StoneBC.git
cd StoneBC
open StoneBC.xcodeproj
```

Build and run on any iOS 17+ simulator or device.

## For Your Co-op

1. **Fork this repo**
2. **Edit `StoneBC/config.json`** — your name, email, location, colors
3. **Replace data files** — `bikes.json`, `posts.json`, `events.json`
4. **Change bundle ID** in Xcode (Signing & Capabilities)
5. **Build & submit** to the App Store

See `CUSTOMIZE_ME/BUILD_CHECKLIST.md` for the full walkthrough and `CUSTOMIZE_ME/` for template data files.

## Architecture

| Layer | Tech |
|-------|------|
| UI | SwiftUI, iOS 17+ |
| State | `@Observable` AppState (MVVM) |
| Data | Bundled JSON (local-first) + optional WordPress REST API sync |
| Navigation | TabView (Home, Routes, Bikes, Community, More) |
| Config | `config.json` — feature flags, branding, contact info |

## App Structure

```
StoneBC/
├── Models:     Bike, Post, Event, Route, Program, AppConfig
├── State:      AppState (@Observable), WordPressService
├── Tabs:       TabContainerView → 5 tabs
├── Home:       Dashboard with featured bikes + posts + quick links
├── Bikes:      MarketplaceView → BikeDetailView (filter by status/type)
├── Community:  CommunityFeedView → PostDetailView (markdown)
├── Routes:     RoutesView → RouteDetailView (map + elevation)
├── More:       Events, Programs, Gallery, Contact, About
├── Design:     BCDesignSystem (colors, typography, components)
└── Data:       config.json, bikes.json, posts.json, events.json, routes.json
```

## Data Files

| File | Purpose | Format |
|------|---------|--------|
| `config.json` | Co-op identity, colors, feature flags | See `CUSTOMIZE_ME/CONFIG_TEMPLATE.json` |
| `bikes.json` | Bike inventory from The Quarry POS | `{ "bikes": [...] }` |
| `posts.json` | Community bulletin board posts | `[...]` with markdown body |
| `events.json` | Events and workshops | `[...]` with category/recurring |
| `routes.json` | Cycling routes with GPX trackpoints | `[...]` with coordinates |

## WordPress Integration (Optional)

Set `dataURLs.wordpressBase` in `config.json` to your WordPress REST API URL. The app will sync bikes, posts, and events on launch, falling back to bundled JSON if the network is unavailable.

Requires:
- Custom post types: `sbc_bike`, `sbc_event` with ACF fields
- Standard `posts` endpoint for community feed

## No Auth, No Payments

This app is read-only for users. The co-op owner manages content via:
- Editing JSON files directly (bikes, posts, events)
- Optional WordPress CMS for live updates
- Contact via email link (no in-app payments)

## License

Creative Commons BY-SA 4.0 — fork it, customize it, share it back.

## Credits

Built by [Stone Bicycle Coalition](https://stonebicyclecoalition.com) in Rapid City, South Dakota.

Part of the [OpenSource-BikeCoopToolkit](OpenSource-BikeCoopToolkit/) — a complete guide for starting your own community bike co-op.
