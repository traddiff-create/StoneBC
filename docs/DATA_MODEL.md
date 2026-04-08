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
}
```

**Source:** GPX/FIT → `Scripts/process_routes.py` → `StoneBC/routes.json` (531KB, 42 routes)

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
}
```

**Source:** `StoneBC/config.json` — the single file other co-ops edit to customize

## Data Flow

```
Owner workflow:
  POS (pos.html) → export bikes.json → copy to bundle
  Write posts.json manually or via Claude
  Events managed in events.json or WordPress

App launch:
  AppState.init() → load all JSON from bundle
  Task { syncFromWordPress() } → optional remote update
```

## Filtering

- Bikes: by status (available/refurbishing/sponsored) and type (road/hybrid/mountain/cargo/cruiser)
- Routes: by difficulty (easy/moderate/hard/expert) and category (road/gravel/fatbike/trail)
- Posts: sorted newest-first, no user filtering
- Sold bikes hidden from marketplace (status != .sold)
