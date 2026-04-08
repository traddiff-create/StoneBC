# Changelog

All notable changes to the Stone Bicycle Coalition project will be documented in this file.

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
