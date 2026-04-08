# Changelog

All notable changes to the Stone Bicycle Coalition project will be documented in this file.

---

## [0.5.0] - 2026-04-08

### Added — Lewis & Clark Routes Upgrade (6 Phases)
- **Ride Dashboard** — full cycling cockpit overlay during navigation
  - Compass ring with bearing-to-next-waypoint arrow
  - CMAltimeter barometric pressure, relative altitude, climb rate (ft/min)
  - GPS speed (current/avg/max MPH), course tracking
  - RideSession model: elapsed/moving time, distance, progress %, off-route detection
- **Weather Intelligence** — WeatherKit integration on route detail
  - Current conditions: temp, wind speed/direction, precipitation, UV, humidity
  - Headwind/tailwind/crosswind analysis relative to route bearing
  - Best Ride Window recommendation (scores hourly forecast on wind/rain/temp)
  - 12-hour hourly forecast strip with SF Symbols
- **Offline Toolkit** — works without cell signal
  - ConnectivityService (NWPathMonitor) with offline banner
  - OfflineMapService: MKMapSnapshotter pre-cache + tile warming
  - "Prepare for Offline" button on route detail
  - Cell Coverage dead zone map (60 bundled towers for Black Hills region)
  - Coverage analysis per route: colored polyline (green=coverage, red=dead zone)
  - Carrier filter chips (Verizon/AT&T/T-Mobile/US Cellular)
- **HealthKit Workouts** — ride recording
  - HKWorkoutBuilder for cycling workouts
  - HKWorkoutRouteBuilder attaches GPS trail to Apple Health
  - Auto-starts on ride begin, saves on end
- **Live Activities** — lock screen + Dynamic Island
  - RideActivityAttributes model + RideActivityManager
  - Shows speed, distance, elapsed time, progress, off-route status
  - (Widget Extension target needed for UI rendering)
- **Enhanced Navigation** — premium cycling GPS experience
  - AVSpeechSynthesizer turn-by-turn audio cues
  - Turn detection from trackpoint geometry (angle between segments)
  - Off-route voice warnings, mile marker callouts, ride complete announcement
  - Breadcrumb trail: dashed orange polyline of actual GPS path vs planned route
  - Audio toggle button (speaker icon on map)
  - Map style picker: standard / satellite / hybrid
  - End Ride confirmation dialog with distance/time summary
- **Onboarding Flow** — 5-page first-launch experience
  - Welcome, GPS Navigation, Ride Dashboard, Record Workouts, Ready pages
  - Permission requests for Location and HealthKit
  - Feature checklist on ready page
  - @AppStorage("onboardingComplete") gate
- **PermissionService** — centralized permission tracker
- **HTML Route Map** (`map.html`) — Leaflet.js interactive map of all 41 routes

### Changed
- RouteNavigationView completely rewritten with dashboard + services integration
- LocationService enhanced: speed, course, altitude, location history, session stats
- RouteDetailView: added Weather section, Ride Tools section (Cell Coverage + Offline)
- config.json: added `enableWeather` feature flag
- project.pbxproj: added NSHealthShare/UpdateUsageDescription, NSSupportsLiveActivities, background location mode
- Xcode project renamed from StoneBC.xcodeproj to app.xcodeproj

### New Files (22)
- `AltimeterService.swift` — CMAltimeter wrapper
- `RideSession.swift` — active ride state model
- `RideDashboardView.swift` — compass + altimeter + speed cockpit
- `NavigationAudioService.swift` — AVSpeechSynthesizer nav cues
- `WeatherService.swift` — WeatherKit with 30-min cache
- `RouteWeatherView.swift` — weather section for route detail
- `ConnectivityService.swift` — NWPathMonitor singleton
- `OfflineMapService.swift` — MKMapSnapshotter pre-cache actor
- `OfflineBannerView.swift` — offline banner + .offlineAware() modifier
- `CellCoverageView.swift` — cell tower dead zone map
- `cell_towers.json` — 60 towers for Black Hills/western SD
- `WorkoutService.swift` — HKWorkoutBuilder + RouteBuilder
- `RideActivityAttributes.swift` — ActivityKit model
- `RideActivityManager.swift` — Live Activity lifecycle
- `OnboardingView.swift` — 5-page first-launch flow
- `PermissionService.swift` — location + HealthKit status
- `StoneBC.entitlements` — app entitlements file
- `map.html` — Leaflet.js interactive route map

### QA Results
- 46/47 Blitz tests passed (1 skipped — toolbar button inaccessible to automation)
- Tested: onboarding, routes list/detail/filters, weather, cell coverage, route explorer, navigation dashboard, bikes, community, events, dark mode

---

## [0.4.0] - 2026-04-01

### Added
- **Rally Radio** — Push-to-talk group voice chat for bike rides
  - MultipeerConnectivity (peer-to-peer, no backend, works offline)
  - Push-to-Talk mode (hold to transmit) + Open Mic mode (always-on)
  - Auto-discover nearby riders (5-15 range)
  - 16kHz mono audio via AVAudioEngine
  - Background audio support (screen off)
  - 11 new files in Radio/ subdirectory

### Changed
- Tab structure: Radio replaces Community in main 5 tabs
- Community Feed moved to More tab (still accessible)
- AppConfig: added `enableRadio` feature flag

---

## [0.3.0] - 2026-04-01

### Added
- **Technical documentation suite**
  - docs/ARCHITECTURE.md — app architecture overview
  - docs/DESIGN_SYSTEM.md — BCDesignSystem reference
  - docs/RALLY_RADIO.md — radio feature spec
  - docs/DATA_MODEL.md — entity schemas
  - docs/GETTING_STARTED.md — developer setup guide
  - docs/adr/ — 3 Architecture Decision Records
  - .claude/rules/stonebc-conventions.md — project-specific conventions
- Updated CLAUDE.md with complete v0.2 project structure

---

## [0.2.0] - 2026-04-01

### Added
- **Bike Marketplace (The Quarry)** — Browse/filter refurbished bikes
  - MarketplaceView with status/type filter chips
  - BikeDetailView with specs, features, contact CTA (mailto:)
  - Bike model derived from POS system schema
  - StatusBadge + ConditionBadge components
- **Community Feed** — Owner-authored bulletin board
  - CommunityFeedView with post cards
  - PostDetailView with markdown rendering
  - 5 sample posts with category badges
- **Tab Navigation** — 5-tab TabView replacing hero drill-down
  - Home (dashboard), Routes, Bikes, Community, More
- **Config System** — JSON-driven for open-source reuse
  - AppConfig model with feature flags, branding, data URLs
  - config.json bundled in app
- **WordPress Integration** — Optional headless CMS sync
  - WordPressService actor with caching and request dedup
  - WP REST API → Swift model mapping
- **Open Source Packaging**
  - CUSTOMIZE_ME/ with templates and BUILD_CHECKLIST.md
  - README.md with fork instructions
- **Dashboard Home** — Featured bikes, recent posts, quick links
- **AppState** — Central @Observable state management
- Data files: bikes.json, posts.json, config.json bundled

### Changed
- HomeView refactored from hero page to dashboard tab
- ContactView email updated to coalition address
- Version bumped to 0.2

---

## [0.1.1] - 2026-01-22

### Added
- **South Dakota Cooperative Law Research**
  - SDCL Chapters 47-15 through 47-20
  - Formation requirements and conversion options
- **Open Source Toolkit Templates** (10 templates)
- **Project Documentation** (PROJECT.md, CHANGELOG.md)

---

## [0.1.0] - 2025-09-02

### Added
- **LLC Formation**
  - Filed Articles of Organization with South Dakota Secretary of State
  - Business ID: DL308353
  - Effective Date: September 2, 2025

- **IRS Registration**
  - Obtained EIN: 39-4226443
  - Tax Classification: Partnership (Form 1065)

- **Initial Documentation**
  - Created `claude.md` - organization reference document
  - Drafted nonprofit articles (pending filing)
  - Business plan document

- **Route Library**
  - Added 40+ GPX files for local cycling routes and events
  - Coverage: Black Hills region (Spearfish, Hill City, Sturgis, Custer, etc.)

- **Website Assets**
  - Added 40+ site photos
  - Created QR code for marketing

- **Open Source Toolkit Structure**
  - Created folder structure for open-source bike co-op documentation
  - Defined project goals and documentation checklist

### Planned
- Nonprofit 501(c)(3) filing

---

## [0.2.0] - 2025-01-22

### Added
- **South Dakota Cooperative Law Research**
  - Researched SDCL Chapters 47-15 through 47-20
  - Documented formation requirements, conversion options
  - Created `SD-Cooperative-Law-Guide.md`

- **Open Source Toolkit Templates**
  - `Bicycle-Cooperative-Bylaws-Template.md` - Comprehensive bylaws template
  - `Earn-A-Bike-Program-Template.md` - Full 6-session curriculum
  - `Shop-Setup-Guide.md` - Space, layout, and safety requirements
  - `Essential-Tool-List.md` - Tiered tool lists with budgets
  - `Membership-Structure-Template.md` - 5 membership models
  - `Volunteer-Management-Guide.md` - Recruitment, training, retention, forms
  - `Parts-Sourcing-Partnership-Guide.md` - Police, university, business partnerships
  - `Grant-Writing-Guide.md` - Full proposal templates, funder list, budget samples
  - `Bicycle-Safety-Curriculum.md` - All ages, multiple formats, instructor guides
  - `Youth-Program-Framework.md` - Complete youth program guide with safety, forms, curriculum

- **Project Documentation**
  - Created `PROJECT.md` - Full project overview and roadmap
  - Created `CHANGELOG.md` - Version tracking

- **Updated `claude.md`**
  - Added toolkit structure and progress tracking
  - Added SD cooperative law findings
  - Updated folder structure
  - Expanded resources section

---

## Future Releases

### [0.3.0] - Planned
- Multi-state legal guides
- Additional program templates
- Website launch

### [1.0.0] - Planned
- Full open-source toolkit release
- Complete legal formation guides for multiple structures
- All program templates finalized
