# Data Model — StoneBC

## Entities

### Bike (from The Quarry POS)

```swift
struct Bike: Identifiable, Codable {
    let id: String              // SBC-### format
    let status: BikeStatus      // available | refurbishing | sponsored | sold
    let model: String           // "Trek 7100 Hybrid"
    let type: BikeType          // road | hybrid | mountain | cargo | cruiser
    let frameSize: String       // "56cm", "18in", "M"
    let wheelSize: String       // "700c", "27.5in", "26in"
    let color: String
    let condition: BikeCondition // excellent | good | fair | poor
    let features: [String]      // ["Fenders", "Kickstand"]
    let photos: [String]        // Photo filenames
    let sponsorPrice: Int       // Dollars
    let description: String
    let dateAdded: String       // ISO 8601
    let acquiredVia: String     // "donation" | "found" | "purchased"
}
```

**Source:** `inventory/bikes.json` → bundled as `StoneBC/bikes.json`
**Pricing:** breakEven × 1.15, rounded to nearest $5

### Post

```swift
struct Post: Identifiable, Codable {
    let id: String
    let title: String
    let body: String            // Markdown
    let imageURL: String?
    let date: String            // ISO 8601
    let category: PostCategory? // featured | news | event | announcement
}
```

**Source:** `StoneBC/posts.json` (owner-authored)

### Event

```swift
struct Event: Identifiable, Codable {
    let id: String
    let title: String
    let date: String
    let location: String
    let category: String        // ride | workshop | openShop | social
    let description: String
    let isRecurring: Bool
}
```

**Source:** `StoneBC/events.json`

### Route

```swift
struct Route: Identifiable, Codable {
    let id: String
    let name: String
    let difficulty: String      // easy | moderate | hard | expert
    let category: String        // road | gravel | fatbike | trail
    let distanceMiles: Double
    let elevationGainFeet: Int
    let region: String
    let description: String
    let startCoordinate: Coordinate
    let trackpoints: [[Double]] // [[lat, lon, ele], ...]
    let cuePoints: [CuePoint]
    let gpxURL: String?
    let rideDefaults: RouteRideDefaults?
    var isImported: Bool
}
```

**Source:** GPX/FIT → `Scripts/process_routes.py` → `StoneBC/routes.json` (531KB, 42 routes)

Route author defaults are optional and decode safely when absent from older route JSON:

```swift
struct RouteRideDefaults: Codable, Hashable {
    let enabledOverlays: [RouteRideOverlay]?
    let recommendedRecordingMode: RouteRecordingMode?
    let offlinePriority: Bool?
    let cueVisibility: Bool?
    let safetyCheckInEnabled: Bool?
    let prepNotes: [String]?
}
```

Rider-local customization stays out of route JSON and is stored under `routeRidePreferences.<routeId>` or `routeRidePreferences.free`:

```swift
struct RouteRidePreferences: Codable, Hashable {
    var enabledOverlays: Set<RouteRideOverlay>
    var defaultRecordingMode: RouteRecordingMode
    var prepDismissed: Bool
    var saveToHistory: Bool
    var saveAsRoute: Bool
    var submitToCoop: Bool
}
```

Recording modes are `free`, `follow`, and `scout`. `follow` links a ride to an existing route; `scout` biases the post-ride review flow toward route cleanup and co-op submission.

Runtime route and ride file interchange is normalized through these app-local models:

```swift
enum RouteFileFormat { case gpx, tcx, fit, kml, kmz, zip }
enum RouteAssetKind { case plannedRoute, completedRide }

struct RouteTrackPoint {
    let latitude: Double
    let longitude: Double
    let elevationMeters: Double?
    let timestamp: Date?
}

struct RouteCoursePoint {
    let name: String
    let kind: RouteCoursePointKind
    let latitude: Double
    let longitude: Double
    let generated: Bool
}

struct RouteImportCandidate {
    let format: RouteFileFormat
    let assetKind: RouteAssetKind
    let route: Route
    let completedRide: CompletedRide?
}
```

`RouteInterchangeService` creates these candidates from GPX, TCX/TPX extension fields, FIT, KML/KMZ, and ZIP bundles. Planned routes are persisted as user routes; completed activities are persisted as ride history or optionally saved as routes.

### AppConfig

```swift
struct AppConfig: Codable {
    let coalitionName: String
    let shortName: String
    let tagline: String
    let websiteURL: String
    let email: String
    let phone: String?
    let instagramHandle: String?
    let location: LocationInfo?
    let colors: BrandColors
    let features: FeatureFlags
    let dataURLs: DataURLs?
    let apiKeys: APIKeys?
}
```

`APIKeys` currently supports optional public IDs/configuration for Trailforks, Strava, Garmin, Wahoo, and Ride with GPS. Provider secrets and OAuth tokens do not belong in this model; tokens are stored in Keychain.

**Source:** `StoneBC/config.json` — the single file other co-ops edit to customize

### TourGuide

```swift
struct TourGuide: Codable, Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let type: GuideType
    let totalDays: Int
    let totalMiles: Double
    let totalElevation: Int
    let difficulty: String
    let category: String
    let region: String
    let notes: [String]
    let checklist: [ChecklistItem]?
    let enabledSections: [TourGuideSection]?
    let overlayDefaults: TourGuideOverlayDefaults?
    let stopTags: [String]?
    let gearProfile: String?
    let safetyNotes: [String]?
    let days: [TourDay]
}
```

**Source:** `StoneBC/guides.json`

### ExpeditionJournal

```swift
struct ExpeditionJournal: Codable, Identifiable {
    let id: String
    let guideId: String
    let name: String
    let leaderName: String
    var status: JournalStatus
    var trackingMode: ExpeditionTrackingMode?
    let startDate: Date
    var endDate: Date?
    var days: [JournalDay]
    var contributions: [MediaContribution]
    var coverPhotoId: String?
}
```

**Source:** user-created local files under `Documents/Expeditions/<journalId>/journal.json`

Expedition days contain entries plus water, food, shelter, sunset, weather, mileage, elevation, GPX, and summary fields. Media files live beside the journal under `media/dayN/`.

## Data Flow

```
Owner workflow:
  POS (pos.html) → export bikes.json → copy to bundle
  Write posts.json manually or via Claude
  Events managed in events.json or WordPress
  Guides managed in guides.json

App launch:
  AppState.init() → load all JSON from bundle
  Task { syncFromWordPress() } → optional remote update

User-created:
  Imported routes → Documents/Routes/userRoutes.json
  Ride history → local app storage + optional HealthKit
  Route ride preferences → UserDefaults keyed by route ID
  Follow My Expedition → Documents/Expeditions
```

## Filtering

- Bikes: by status (available/refurbishing/sponsored) and type (road/hybrid/mountain/cargo/cruiser)
- Routes: by difficulty (easy/moderate/hard/expert), category (road/gravel/fatbike/trail), browse mode, and sort order
- Posts: sorted newest-first, no user filtering
- Sold bikes hidden from marketplace (status != .sold)

## Related Docs

- [Configuration](CONFIGURATION.md)
- [Offline Storage](OFFLINE_STORAGE.md)
- [Follow My Expedition](FOLLOW_MY_EXPEDITION.md)
