# StoneBC — Stone Bicycle Coalition

**Location:** `/Applications/Apps/StoneBC/`
**Repo:** `traddiff-create/StoneBC`
**Type:** Hybrid (iOS App + Website + Open-Source Toolkit)
**Owners:** Rory & Nicole Stone
**Status:** Active Development
**Bundle ID:** `com.traddiff.StoneBC` | **Version:** 0.8
**Deployment Target:** iOS 17.0

---

## Overview

Stone Bicycle Coalition is a community bike co-op in Rapid City, SD with three components:
1. **iOS App** (SwiftUI) — marketplace, community feed, routes, Rally Radio, events, expedition journals
2. **Website** (Eleventy + Netlify) — stonebicyclecoalition.com
3. **Open-Source Toolkit** — replicable co-op formation guide (CC BY-SA 4.0)

The app is **config-driven** so other bike co-ops can fork and customize it.

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| iOS App | Swift 5, SwiftUI, MapKit, CoreLocation, CoreMotion, WeatherKit, HealthKit, ActivityKit, AVFoundation, MultipeerConnectivity, SQLite3, ImageIO, PhotosUI |
| Architecture | MVVM with @Observable AppState |
| Data | Bundled JSON (local-first) + optional WordPress REST API sync |
| Voice Chat | MultipeerConnectivity (peer-to-peer, no backend) |
| Website | Eleventy + Netlify (headless WordPress optional) |
| Route Data | GPX/FIT → JSON (Python processing) |
| Config | `config.json` — feature flags, branding, contact, data URLs |

---

## Project Structure

```
StoneBC/
├── StoneBC/                     # iOS app source (65 Swift files)
│   ├── StoneBCApp.swift         # Entry point
│   ├── ContentView.swift        # Root → TabContainerView + AppState
│   ├── TabContainerView.swift   # 5-tab navigation
│   ├── AppState.swift           # @Observable central state
│   ├── AppConfig.swift          # Config-driven settings
│   ├── BCDesignSystem.swift     # Design tokens (colors, typography, components)
│   │
│   ├── HomeView.swift           # Dashboard: featured bikes, posts, quick links
│   ├── RoutesView.swift         # 42 Black Hills cycling routes
│   ├── RouteDetailView.swift    # Route map + elevation profile
│   ├── RouteMapView.swift       # Interactive map
│   │
│   ├── MarketplaceView.swift    # The Quarry: browse/filter bikes
│   ├── BikeDetailView.swift     # Single bike with specs + contact CTA
│   ├── BikeCardRow.swift        # Bike list item
│   ├── BikeFilterBar.swift      # Status/type filter chips
│   ├── Bike.swift               # Model (from POS schema)
│   │
│   ├── CommunityFeedView.swift  # Post bulletin board
│   ├── PostDetailView.swift     # Full post with markdown
│   ├── PostCardRow.swift        # Post list item
│   ├── Post.swift               # Model
│   │
│   ├── Radio/                   # Rally Radio — push-to-talk voice chat
│   │   ├── RadioService.swift   # MCSession wrapper
│   │   ├── AudioStreamService.swift  # AVAudioEngine wrapper
│   │   ├── RadioViewModel.swift # @Observable state machine
│   │   ├── RadioView.swift      # Main radio UI
│   │   ├── PTTButton.swift      # 80pt push-to-talk button
│   │   ├── RadioOverlayView.swift    # Floating status pill
│   │   ├── RadioConfig.swift    # Constants
│   │   ├── RadioPeer/Channel/State.swift  # Models
│   │   └── AppState+Radio.swift # Extension
│   │
│   ├── MoreView.swift           # Events, programs, gallery, contact, about
│   ├── CommunityView.swift      # Events + programs (existing)
│   ├── GalleryView.swift        # Photo gallery
│   ├── ContactView.swift        # Contact info + links
│   ├── WordPressService.swift   # WP REST API client (optional sync)
│   │
│   └── Data files:              # Bundled JSON
│       ├── config.json          # App configuration
│       ├── bikes.json           # Inventory (from The Quarry POS)
│       ├── posts.json           # Community posts
│       ├── events.json          # Events and workshops
│       ├── routes.json          # 42 GPX routes (531KB)
│       ├── programs.json        # Community programs
│       └── photos.json          # Gallery metadata
│
├── StoneBC.xcodeproj/
├── docs/                        # Technical documentation
│   ├── ARCHITECTURE.md          # App architecture overview
│   ├── DESIGN_SYSTEM.md         # BCDesignSystem reference
│   ├── RALLY_RADIO.md           # Radio feature spec
│   ├── DATA_MODEL.md            # Entity schemas
│   ├── GETTING_STARTED.md       # Dev setup guide
│   └── adr/                     # Architecture Decision Records
│
├── CUSTOMIZE_ME/                # Open-source fork guide
│   ├── CONFIG_TEMPLATE.json
│   ├── BIKES/POSTS/EVENTS_TEMPLATE.json
│   └── BUILD_CHECKLIST.md
│
├── inventory/                   # The Quarry POS + bike program
│   ├── pos.html                 # Browser-based inventory + waitlist dashboard
│   ├── bikes.json               # Source of truth for bike data
│   ├── waitlist.json            # Applicants waiting for bikes (source of truth)
│   ├── WAITLIST.md              # Wait list process doc + scannable table
│   ├── INTAKE.md                # Bike intake templates (links to waitlist)
│   └── PARTS.md                 # Parts inventory
│
├── website/                     # Eleventy + Netlify site
├── GPX/                         # 42 route files (GPX + FIT)
├── OpenSource-BikeCoopToolkit/  # CC BY-SA 4.0 co-op guide
├── business-docs/               # LLC registration, EIN, grants
├── Scripts/process_routes.py    # GPX/FIT → JSON converter
├── README.md                    # Fork instructions
├── PROJECT.md                   # Full roadmap
├── CHANGELOG.md                 # Version history
└── WORDPRESS_SETUP.md           # Headless WP guide
```

---

## Tab Structure

| Tab | View | Content |
|-----|------|---------|
| Home | HomeView | Dashboard: featured bikes, recent posts, Rally Radio card, quick links |
| Routes | RoutesView | Black Hills routes with filters (currently 1: 8 Over 7 v2) |
| Bikes | MarketplaceView | The Quarry inventory with status/type filters |
| More | MoreView | Community feed, events, tour guides, gallery, contact |

**Rally Radio** is accessed via a NavigationLink card on the Home tab (not a tab — iOS 26 Liquid Glass hides 5th tabs).

---

## Swiss Army Knife Services (v0.8)

| Service | File | What |
|---------|------|------|
| Altitude Fusion | AltimeterService + LocationService | GPS baseline + barometer deltas |
| Route Analysis | RouteAnalysisService | Pre-computed turns for O(1) navigation |
| Offline Cache | OfflineRouteStorage | Persistent route + snapshot + weather |
| Trail Conditions | TrailforksService | Trailforks API (needs key in config.json) |
| USFS Closures | USFSService | ArcGIS Black Hills NF queries (free) |
| Strava | StravaService | OAuth2, segments, leaderboards |
| Conditions | RouteConditionReporter | Crowdsourced reports + quick-tap UI |
| Emergency | EmergencySafetyService | Satellite SOS, emergency contacts, 911 |
| Ride Export | RideExportService | GPX 1.1 with timestamps/elevation |
| Ride History | RideHistoryService | Persistent log + season summary |
| Route Search | RouteIndexService | SQLite FTS5 full-text search |
| Notifications | EventNotificationService | Local notifications for events + ride windows |
| Offline Maps | MapboxOfflineService | Scaffold (needs Mapbox SPM + token) |

---

## Expedition Journal System (v0.8)

Lewis & Clark-style ride documentation. One leader curates, all riders contribute.

| File | Purpose |
|------|---------|
| ExpeditionJournal.swift | Core models: Journal, Day, Entry, Contribution |
| ExpeditionStorage.swift | Documents dir + iCloud `8o7/` shared drop zone |
| ExpeditionCaptureView.swift | During-ride: text, photo, audio, video + GPS |
| PhotoGeotaggingService.swift | EXIF GPS + Garmin timestamp matching |
| ExpeditionTimelineView.swift | Day-by-day editor with media cards |
| ExpeditionMapView.swift | GPS track + media pins on satellite map |
| ExpeditionExporter.swift | HTML report generation |
| ExpeditionListView.swift | Browse/create journals from tour guides |
| MediaCaptureService.swift | Camera, voice memo, video wrappers |

**Flow:** More tab → My Expeditions → Create from tour guide → Capture during ride → Curate after → Export HTML.

**Collaboration:** iCloud Drive `8o7/` folder for media drops. Rally Radio `0x50` prefix for P2P photo sharing.

---

## Tour Guide System

Multi-day ride guides with day picker, stops timeline, and ride recording checklist.

| File | Purpose |
|------|---------|
| TourGuide.swift | Data model: TourGuide, TourDay, TourStop |
| TourGuideListView.swift | Browse guides with stats and difficulty badges |
| TourGuideDetailView.swift | Day picker, overview, stops timeline, notes |
| RideChecklist.swift | Persistent checklist for recording while riding |
| guides.json | Guide data (bundled) |

**Current Guides:**
- **Brewvet** — 3-day brewery bike tour (Sept 25-27), sag stops with beer pairings
- **8 Over 7** — 3-day bikepacking trip (May 15-17), Spearfish → Sylvan → Custer → Deerfield → Spearfish

**Data pipeline:** Routes in GPX/ → process_routes.py → routes.json (for Routes tab). Guides in guides.json (separate, richer data model with stops/checklist).

---

## Get Involved (ContactView)

- **Volunteer** → VolunteerFormView (TTT: Time/Talent/Treasure, mailto submission)
- **Donate** → DonateFormView (Bicycle/Parts/Monetary, mailto submission)
- **Spread the Word** → opens stonebicyclecoalition.com
- **Trad Diff links** → TD Technology, Rory Stone Photography, BTYBD (external URLs)

---

## Key Patterns

- **Config-driven:** `config.json` controls name, colors, features, data URLs
- **Local-first data:** All JSON bundled; optional WordPress sync on launch
- **Feature flags:** `enableMarketplace`, `enableRadio`, `enableRoutes`, etc.
- **No auth:** Read-only for users; owner manages content via CLI/Claude
- **Open source:** `CUSTOMIZE_ME/` has templates for other co-ops to fork

---

## Business Info

- **LLC:** Business ID DL308353, effective 2025-09-02
- **EIN:** 39-4226443
- **AEP Grant:** $1,000 awarded 2026-03-31
- **Transition path:** LLC → 501(c)(3) Nonprofit → Member-owned Cooperative
- **Location:** Minneluzahan Senior Center, 315 N 4th St, Rapid City, SD 57701

---

## Skills & Testing

- `/test-stonebc` — Full automated QA (build + deploy + 25 Blitz tests)
- `xcodebuild build -scheme StoneBC` — CLI build

---

## Notes for Claude

- **Read this file first**, then `docs/`, then source code
- 40 Swift files across main app + Radio/ subdirectory
- BCDesignSystem.swift has all reusable UI components (FilterChip, badges, PressableButtonStyle)
- AppState is the single source of truth for all data
- Radio uses MultipeerConnectivity — needs real devices for peer testing
- `git add -f` required (parent repo gitignore blocks `*`)
- Never auto-build unless asked (per session-workflow rules)

---

**Last Updated:** 2026-04-10
**Maintained By:** Rory Stone
