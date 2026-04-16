# Changelog

All notable changes to the Stone Bicycle Coalition project will be documented in this file.

---

## [0.8.1] - 2026-04-16

### Fixed
- **Route navigation crash** — `CMAltimeter.startRelativeAltitudeUpdates()` was killing the app on iOS 17+ because `NSMotionUsageDescription` was not declared. Added to `INFOPLIST_KEY_*` in both Debug and Release build configs.
- **Missing permission prompts** — added `NSCameraUsageDescription` (ExpeditionCaptureView) and `NSPhotoLibraryAddUsageDescription` (expedition photo saves) so those features will surface system prompts on first use.
- **Route navigation hardening** — `RouteNavigationView.onAppear` now guards on `route.isNavigable` and dismisses cleanly for empty/invalid routes.

---

## [0.8.0] - 2026-04-15

### Swiss Army Knife Upgrade + Expedition Journal

#### Foundation Hardening (Phase 1)
- **Route validation** — defensive guards for empty/invalid trackpoints, coordinate bounds checking. All 56 routes load without crash
- **Performance** — windowed search in RideSession (O(100) vs O(13K) for Great Plains Gravel's 13,718 trackpoints)
- **Altitude fusion** — GPS baseline + CMAltimeter barometer for accurate fused elevation display
- **Off-route detection** — warn at 50m, critical alert at 150m with differentiated UI and audio
- **Persistent route cache** — OfflineRouteStorage saves route data + snapshots + weather to disk
- **Turn analysis** — RouteAnalysisService pre-computes all turn points for O(1) lookup during navigation

#### Trail Intelligence (Phase 2)
- **TrailforksService** — trail conditions API client with 4-hour cache (free tier, needs API key in config.json)
- **USFSService** — USFS ArcGIS Black Hills NF closure queries (free, no key needed)
- **StravaService** — OAuth2 flow, segment exploration, leaderboards with 7-day cache (free tier)
- **RouteConditionReporter** — local-first crowdsourced condition reports with quick-tap UI
- **TrailConditionBadge** — condition badges on route cards (green/orange/red)

#### Safety & Community (Phases 3-4)
- **EmergencySafetyService** — satellite SOS detection (iPhone 14+), emergency contacts, 911 deep link
- **RideExportService** — GPX 1.1 export with timestamps/elevation for sharing and Strava upload
- **Rally Radio presets** — 10 voice-free safety messages (trail muddy, mechanical, regrouping, etc.)
- **RideHistoryService** — persistent ride log with season summary (total miles/elevation/rides)
- **Season summary card** — ride stats on Home tab dashboard

#### Infrastructure
- **RouteIndexService** — SQLite FTS5 full-text search with prefix matching across all routes
- **EventNotificationService** — local notifications for favorited route events + weekly best ride window
- **MapboxOfflineService** — scaffold for offline vector tiles with setup guide (needs SPM package)

#### Expedition Journal (New Feature)
- **Lewis & Clark-style ride documentation** for multi-day bikepacking trips
- **ExpeditionJournal** — data models for journal, days, entries, media, contributions
- **ExpeditionStorage** — Documents directory persistence + iCloud Drive `8o7/` shared drop zone
- **ExpeditionCaptureView** — during-ride quick-log: text, photo (camera + library), voice memo, video. Auto-attaches GPS + timestamp. Works fully offline
- **PhotoGeotaggingService** — EXIF GPS extraction via ImageIO, timestamp-to-Garmin-track matching for Fuji photos, batch geotagging with confidence scoring
- **ExpeditionTimelineView** — day picker, entry cards with media, day summary editor, Garmin GPX import, floating action button
- **ExpeditionMapView** — GPS track polyline + media pins (blue=leader, green=contribution, amber=featured) on hybrid satellite map
- **ExpeditionExporter** — self-contained dark-theme HTML report with photo gallery, day narratives, contributor credits
- **ExpeditionListView** — browse journals, create new from tour guides
- **Collaboration model** — one leader curates, all riders contribute via iCloud folder or Rally Radio

#### Stats
- 25 new Swift files
- ~7,800 lines added
- $0-400/year API costs (most APIs have free tiers)

---

## [0.7.0] - 2026-04-10

### Tour Guide System & Get Involved

#### Tour Guides (New Feature)
- **Multi-day tour guide system** — data model for guides with days, stops, and ride recording checklists
- **Brewvet guide** — 3-day brewery bike tour (Sept 25-27) with sag stops, beer pairings, and tour notes
- **8 Over 7 guide** — 3-day bikepacking trip (May 15-17) Spearfish → Sylvan Lake → Custer → Deerfield → Spearfish. Based on Zach's route intel
- **Ride recording checklist** — persistent tappable checklist for capturing photos, notes, and safety info while riding. Categories: capture (blue), note (orange), safety (red)
- **TourGuideListView** — browse guides with stats, difficulty badges, and event dates
- **TourGuideDetailView** — day picker, day overview, stops timeline with colored dots and mileage markers

#### Get Involved (ContactView Overhaul)
- **Volunteer form** — TTT model (Time/Talent/Treasure) adapted for bike co-op with mailto submission
- **Donate form** — Bicycle/Parts & Tools/Monetary with condition picker and drop-off logistics
- **Spread the Word** — links to stonebicyclecoalition.com
- **Trad Diff links** — TD Technology, Rory Stone Photography, BTYBD with real URLs
- **Address removed** — dropped hardcoded address from contact section

#### Routes
- **8 Over 7 v2 (2021)** — imported 102.9mi, 10,563ft gain, 1,292 trackpoints
- **Routes trimmed** — app ships with single imported route (8 Over 7 v2)
- **Brewvet route files** — Northern and Southern TCX/FIT files added for future map rendering

#### Events
- **Events cleaned up** — removed placeholder events, kept only real Pedal for Empathy (May 2, 2026)

---

## [0.6.0] - 2026-04-09

### Rally Radio — Security, Reliability & UX Overhaul

#### Security (Critical)
- **DTLS encryption enabled** — MCSession `encryptionPreference` changed from `.none` to `.required`. All voice data now encrypted in transit
- **Peer validation** — discoveryInfo verification ensures only StoneBC apps with matching protocol version can connect. Rejects unknown peers
- **Invitation gating** — advertiser rejects invitations when at max peers or no active session

#### Reliability
- **Audio interruption handling** — AVAudioSession interruption observer recovers gracefully from phone calls, Siri, and other audio interruptions. Auto-resumes open mic after interruption ends
- **Auto-reconnect tracking** — disconnected peers tracked with haptic feedback (warning on disconnect, success on reconnect). Browser stays active for automatic re-discovery
- **Production logging** — all 20+ `print()` statements replaced with `os.log` Logger (privacy-safe, filterable)
- **Thread safety** — AudioStreamService state flags (`isCapturing`, `isPlaybackReady`) synchronized with NSLock

#### UX & Navigation
- **Radio moved to Home tab** — iOS 26 Liquid Glass tab bar hides 5th tab. Rally Radio now accessible via prominent card on Home screen with antenna icon and "Push-to-talk for group rides" subtitle
- **4-tab layout** — Tab bar reduced from 5 to 4 tabs (Home, Routes, Bikes, More) for Liquid Glass compatibility
- **Honest state display** — removed fake 2-second "connecting" delay. Shows "Searching..." until actual peer connects

#### Onboarding
- **Rally Radio onboarding page** — new page 4 with microphone permission request. 6-page flow: Welcome → Location → Sensors → Rally Radio → HealthKit → Ready
- **Microphone permission** — PermissionService gains `requestMicrophone()` and `microphoneGranted` tracking
- **Ready page checklist** — now includes "Rally Radio Microphone" status

#### Infrastructure Fix
- **Info.plist created** — `NSBonjourServices` was incorrectly declared as a string via build settings (requires array). Created proper `StoneBC/Info.plist` with array-type keys for Bonjour services and background modes. This was the root cause of Local Network permission never being triggered
- **Deprecated API fix** — `.allowBluetooth` replaced with `.allowBluetoothHFP`

### Changed
- TabContainerView: 4 tabs (removed Radio tab, added to Home as NavigationLink)
- HomeView: added Rally Radio card in quick links section
- OnboardingView: 6 pages (added Rally Radio microphone page)
- PermissionService: added microphone permission support
- RadioConfig: added `appIdentifier`, `protocolVersion`, `reconnectTimeout` constants
- app.xcodeproj: INFOPLIST_FILE points to StoneBC/Info.plist, removed broken INFOPLIST_KEY_ array entries

### New Files
- `StoneBC/Info.plist` — proper array-type keys (NSBonjourServices, UIBackgroundModes)

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
