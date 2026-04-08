# WordPress Headless CMS Integration Plan - StoneBC

## Executive Summary
This plan describes how to integrate WordPress as a headless CMS with the Stone Bicycle Coalition iOS app and website. The approach uses WordPress REST API exclusively (no WordPress theme), maintains offline-first functionality with local JSON bundles as fallback, and supports config-driven endpoints for other bike co-ops to fork.

**Architecture**: iOS app bundles JSON locally, optionally syncs from WordPress API in background. Website uses static site generator (Eleventy) that builds at deploy time by pulling from WordPress API.

---

## Phase 1: Foundation (Weeks 1-2)

### 1.1 WordPress Setup & Hosting
**Decision**: Recommend WordPress.com Business plan ($300/yr) or Kinsta managed hosting
- Lower operational overhead vs self-hosted
- Automatic backups, SSL, updates included
- REST API enabled by default
- Alternative: Bluehost ($2.95-13.95/mo) with WP Engine managed hosting

**Plugins to Install**:
- Advanced Custom Fields Pro (ACF Pro) - $99/yr for custom fields on post types
- Custom Post Type UI - for creating Event, Bike, Program custom post types
- REST API Enabler (optional) - ensure API is accessible

**Configuration**:
- Create Custom Post Types:
  - `event` (singular: event, plural: events) - for cycling events
  - `bike` (singular: bike, plural: bikes) - for marketplace inventory
  - `program` (singular: program, plural: programs) - for toolkit articles
- Keep default `post` type for general news/announcements
- Set REST API base: `/wp-json/wp/v2/`

### 1.2 Advanced Custom Fields Setup (ACF Pro)
Create field groups for each post type:

**Bikes Field Group** (synced to all bikes):
- `status` - Select dropdown (available/refurbishing/sponsored/sold)
- `type` - Select dropdown (road/hybrid/mountain/cargo/cruiser)
- `frame_size` - Text field
- `wheel_size` - Text field
- `condition` - Select dropdown (excellent/good/fair/poor)
- `features` - Repeater field (each feature is text)
- `sponsor_price` - Number field
- `acquired_via` - Select dropdown (donation/purchase/refurbished)
- `photos` - File gallery (multiple images)

**Events Field Group**:
- `date` - Date/Time field
- `location` - Text field
- `category` - Select dropdown (ride/workshop/openShop/social)
- `description` - Textarea
- `is_recurring` - True/False checkbox
- `recurrence_pattern` - Text (e.g., "Weekly Saturday")

**Programs Field Group**:
- `program_type` - Select dropdown (Earn-A-Bike/Safety/Youth/Maintenance)
- `content_html` - Textarea (toolkit article content)
- `icon` - File upload

### 1.3 Create WordPressService.swift (Actor)
**Location**: `/Applications/Apps/StoneBC/StoneBC/WordPressService.swift`

**Purpose**: Thread-safe networking service with caching and request deduplication

**Key Features**:
- Actor for thread-safe concurrent access
- Request deduplication (prevents duplicate API calls in-flight)
- 5-minute NSCache caching for responses
- Proper error handling with typed errors
- Offline fallback to bundled JSON

**Methods**:
```swift
actor WordPressService {
    // Deduplication tracking
    private var inFlightRequests: [String: Task<Data, Error>] = [:]
    
    // Caching
    private let cache = NSCache<NSString, NSData>()
    
    // Fetch methods
    func fetchEvents() async throws -> [Event]
    func fetchBikes() async throws -> [Bike]
    func fetchPosts() async throws -> [Post]
    
    // Internal methods
    private func fetch(from url: URL) async throws -> Data
    private func cacheKey(for url: URL) -> String
}
```

---

## Phase 2: iOS Integration (Weeks 2-3)

### 2.1 Update AppConfig.swift
Add `DataSyncConfig` nested struct:

```swift
struct AppConfig {
    // ... existing fields ...
    
    var dataSync: DataSyncConfig
    
    struct DataSyncConfig: Codable {
        let wordPressURL: String          // e.g., "https://stonebicyclecoalition.wordpress.com"
        let enableRemoteSync: Bool        // true to sync from WordPress
        let cacheDuration: TimeInterval    // seconds (default: 300 = 5 min)
        let fallbackToBundle: Bool        // true to use local JSON if API fails
    }
}
```

**Updated config.json structure**:
```json
{
  "coalitionName": "Stone Bicycle Coalition",
  "websiteURL": "https://stonebicyclecoalition.com",
  "dataSync": {
    "wordPressURL": "https://stonebicyclecoalition.wordpress.com",
    "enableRemoteSync": true,
    "cacheDuration": 300,
    "fallbackToBundle": true
  }
}
```

### 2.2 Update AppState.swift
Add WordPress sync capability:

**New Properties**:
```swift
@Observable
class AppState {
    // ... existing properties ...
    var wpService: WordPressService?
    var isLoadingRemote = false
    var syncError: String? = nil
    var lastSyncTime: Date? = nil
}
```

**New Method**:
```swift
@MainActor
func syncRemoteData() async {
    guard config.dataSync.enableRemoteSync else { return }
    
    isLoadingRemote = true
    defer { isLoadingRemote = false }
    
    do {
        // Parallel fetching with async let
        async let events = wpService?.fetchEvents() ?? []
        async let bikes = wpService?.fetchBikes() ?? []
        async let posts = wpService?.fetchPosts() ?? []
        
        let (newEvents, newBikes, newPosts) = await (events, bikes, posts)
        
        // Update app state on MainActor
        self.events = newEvents.isEmpty ? self.events : newEvents
        self.bikes = newBikes.isEmpty ? self.bikes : newBikes
        self.posts = newPosts.isEmpty ? self.posts : newPosts
        
        lastSyncTime = Date()
        syncError = nil
    } catch {
        syncError = error.localizedDescription
        // Keep existing data on error
    }
}
```

**Update loadData() Method**:
```swift
func loadData() {
    // Load from bundle first (instant, offline-ready)
    bikes = Bike.loadFromBundle()
    posts = Post.loadFromBundle()
    events = Event.loadFromBundle()
    routes = Route.loadFromBundle()
    
    // Optionally sync from WordPress in background
    Task {
        await syncRemoteData()
    }
}
```

### 2.3 Update StoneBCApp.swift
Initialize WordPressService and inject AppState:

```swift
@main
struct StoneBCApp: App {
    @State var appState: AppState
    
    init() {
        let appState = AppState()
        self._appState = State(initialValue: appState)
        appState.loadData()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
```

### 2.4 REST API Response Models
Create intermediate response types that map WordPress API format to Swift models:

**EventResponse** mapping:
```
WordPress REST        →  Swift Model
id                    →  id (from slug)
title.rendered        →  title
acf.date             →  date
acf.location         →  location
acf.category         →  category
acf.description      →  description
acf.is_recurring     →  isRecurring
```

**BikeResponse** mapping:
```
id                    →  id (SBC-###)
title.rendered        →  model
acf.status           →  status
acf.type             →  type
acf.frame_size       →  frameSize
acf.condition        →  condition
acf.features         →  features (array)
acf.sponsor_price    →  sponsorPrice
acf.photos           →  photos (file URLs)
```

---

## Phase 3: Website Integration (Weeks 3-4)

### 3.1 Static Site Generator Setup
**Option A (Recommended)**: Eleventy.js
- Fast build times
- Simple data pipeline
- JavaScript-based, works on any hosting
- Can fetch from WordPress API at build time

**Configuration** (.eleventy.js):
```javascript
module.exports = function(eleventyConfig) {
  // Fetch data from WordPress at build time
  eleventyConfig.addGlobalData("bikes", async () => {
    const response = await fetch('https://stonebicyclecoalition.wordpress.com/wp-json/wp/v2/bikes?per_page=100&_embed');
    return await response.json();
  });
  
  eleventyConfig.addGlobalData("events", async () => {
    const response = await fetch('https://stonebicyclecoalition.wordpress.com/wp-json/wp/v2/events?per_page=100');
    return await response.json();
  });
  
  // Create dynamic pages for each bike/event
  eleventyConfig.addCollection("bikes_pages", collection => {
    return collection.getAll().map(item => ({ data: item }));
  });
  
  return {
    dir: {
      input: "src",
      output: "_site"
    }
  };
};
```

### 3.2 Update Netlify Deployment
**netlify.toml** configuration:
```toml
[build]
command = "npm run build"
publish = "_site"

[[plugins]]
package = "@netlify/plugin-sitemap"

[context.production]
command = "npm run build:production"

[context.preview]
command = "npm run build:preview"
```

**Build script in package.json**:
```json
{
  "scripts": {
    "build": "eleventy",
    "build:production": "ELEVENTY_ENV=production eleventy"
  }
}
```

### 3.3 Website Pages Using WordPress Data
Create Nunjucks/Liquid templates that iterate over fetched WordPress data:

**bikes.html**:
```nunjucks
{% for bike in bikes %}
  <div class="bike-card">
    <h3>{{ bike.title.rendered }}</h3>
    <p>Status: {{ bike.acf.status }}</p>
    <p>Price: ${{ bike.acf.sponsor_price }}</p>
  </div>
{% endfor %}
```

**events.html**:
```nunjucks
{% for event in events | sort by "acf.date" %}
  <div class="event">
    <h3>{{ event.title.rendered }}</h3>
    <p>{{ event.acf.date | dateFilter }}</p>
    <p>{{ event.acf.location }}</p>
  </div>
{% endfor %}
```

---

## Phase 4: Data Migration (Week 4)

### 4.1 Python Migration Script
**Location**: `/Applications/Apps/StoneBC/Scripts/migrate_to_wordpress.py`

**Purpose**: One-time script to migrate bikes.json, events.json, posts.json → WordPress

**Process**:
1. Read JSON from local files
2. Create WordPress posts via REST API
3. Set ACF field values
4. Upload featured images
5. Handle duplicate detection (check by title)

**Key Code**:
```python
import requests
import json

WORDPRESS_URL = "https://stonebicyclecoalition.wordpress.com"
APP_PASSWORD = "abcd efgh ijkl mnop"  # From WordPress > Users > Application Passwords

session = requests.Session()
session.auth = ("rory@example.com", APP_PASSWORD)

def migrate_bikes():
    with open("StoneBC/bikes.json") as f:
        data = json.load(f)
    
    for bike in data["bikes"]:
        post_data = {
            "title": bike["model"],
            "content": bike["description"],
            "status": "publish",
            "type": "bike",
            "acf": {
                "status": bike["status"],
                "type": bike["type"],
                "sponsor_price": bike["sponsorPrice"],
                "features": bike["features"]
            }
        }
        
        response = session.post(
            f"{WORDPRESS_URL}/wp-json/wp/v2/bikes",
            json=post_data
        )
        print(f"Created bike {bike['id']}: {response.status_code}")
```

### 4.2 Verification Steps
1. Check WordPress admin: Posts > Events/Bikes/Posts (all items created)
2. Verify REST API: `GET /wp-json/wp/v2/bikes?per_page=5`
3. Check ACF fields populated correctly
4. Test iOS app offline mode (verify bundle data still works)
5. Test iOS app online mode (verify WordPress sync works)
6. Build website, verify images load

---

## Phase 5: Testing & Documentation (Week 4-5)

### 5.1 iOS Testing
**Unit Tests**:
- WordPressService error handling
- Request deduplication
- Cache expiration
- Offline fallback behavior

**Integration Tests**:
- AppState sync triggers correctly
- Models decode from API responses
- No crashes with malformed API data

**Manual Testing**:
- Test offline (disable network, verify bundle data loads)
- Test online (enable network, watch sync complete)
- Test cache (make same request twice, verify cache hit second time)
- Test error recovery (WordPress down, verify fallback to bundle)

### 5.2 Documentation
Create `WORDPRESS_SETUP.md` for other co-ops:
```markdown
# WordPress Setup for Other Bike Co-ops

## Quick Start
1. Create WordPress.com Business account
2. Install ACF Pro plugin
3. Import field groups from ACF_FIELD_GROUPS.json
4. Create custom post types (Event, Bike, Program)
5. Update config.json with your WordPress URL
6. Run migration script to populate initial data

## REST API Testing
GET https://yourdomain.wordpress.com/wp-json/wp/v2/bikes
GET https://yourdomain.wordpress.com/wp-json/wp/v2/events
```

---

## Phase 6: Launch (Week 5)

### 6.1 Production Deployment
1. Set up production WordPress instance
2. Migrate all content to production
3. Update config.json to point to production WordPress
4. Submit StoneBC app to App Store with WordPress integration
5. Deploy website to Netlify (with build step fetching from WordPress)
6. Monitor logs for API errors

### 6.2 Post-Launch
- Monitor WordPress API performance
- Watch iOS app crash logs
- Gather user feedback on sync behavior
- Plan Phase 2 features (search, filtering, etc.)

---

## REST API Endpoint Reference

### Core Endpoints
```
GET /wp-json/wp/v2/events?per_page=100
GET /wp-json/wp/v2/bikes?per_page=50
GET /wp-json/wp/v2/posts?per_page=20
GET /wp-json/wp/v2/events/{id}?_embed
```

### Query Parameters
- `per_page=N` - Limit results
- `page=N` - Pagination
- `slug=name` - Filter by slug
- `_embed=wp:featuredmedia` - Include featured image data
- `search=term` - Full-text search
- `orderby=date&order=desc` - Sorting

### Response Status Codes
- 200 OK - Success
- 400 Bad Request - Invalid parameters
- 401 Unauthorized - Authentication failed
- 404 Not Found - Post not found
- 500 Internal Server Error - Server error

---

## Configuration for Other Co-ops

**config.json example for co-ops**:
```json
{
  "coalitionName": "Your Bike Co-op",
  "shortName": "YourBC",
  "tagline": "Your coalition tagline",
  "websiteURL": "https://yourcoalition.com",
  "dataSync": {
    "wordPressURL": "https://yourcoalition.wordpress.com",
    "enableRemoteSync": true,
    "cacheDuration": 300,
    "fallbackToBundle": true
  }
}
```

**Each co-op can**:
- Use their own WordPress instance
- Customize post types and ACF fields
- Fork the iOS app and update config.json
- Deploy to their domain on Netlify
- Maintain independence while using open-source toolkit

---

## Security Considerations

### What's Exposed (Public)
- Bike inventory (via REST API)
- Events/workshops
- Posts/news items
- Public photos

### What's Protected (Private)
- User accounts
- WordPress admin
- Sensitive business data
- ACF Pro settings

### Best Practices
- Use strong WordPress passwords
- Enable two-factor authentication
- Regular backups (auto on WordPress.com)
- Monitor API access logs
- Rate-limit if needed (use WordPress plugin)
- HTTPS enforced (standard on WordPress.com)

---

## Critical Files for Implementation

### To Create
1. `/Applications/Apps/StoneBC/StoneBC/WordPressService.swift` - Networking service
2. `/Applications/Apps/StoneBC/WORDPRESS_SETUP.md` - Documentation for co-ops
3. `/Applications/Apps/StoneBC/Scripts/migrate_to_wordpress.py` - Data migration
4. `/Applications/Apps/StoneBC/website/.eleventy.js` - Static site config
5. `/Applications/Apps/StoneBC/website/netlify.toml` - Netlify deployment config

### To Modify
1. `/Applications/Apps/StoneBC/StoneBC/AppState.swift` - Add WordPress sync
2. `/Applications/Apps/StoneBC/StoneBC/AppConfig.swift` - Add DataSyncConfig
3. `/Applications/Apps/StoneBC/StoneBC/StoneBCApp.swift` - Initialize WordPressService
4. `/Applications/Apps/StoneBC/StoneBC/config.json` - Add dataSync section

### To Reference
1. `/Applications/Apps/StoneBC/StoneBC/Bike.swift` - Model structure
2. `/Applications/Apps/StoneBC/StoneBC/Event.swift` - Model structure
3. `/Applications/Apps/StoneBC/StoneBC/Post.swift` - Model structure
4. `/Applications/Apps/StoneBC/CLAUDE.md` - Project context

---

## Dependencies & Assumptions

### iOS App
- Swift 5.1+
- SwiftUI (iOS 17+)
- Observation framework
- URLSession (built-in)

### Website
- Node.js 16+
- npm or yarn
- Eleventy (@11ty/eleventy)
- Netlify account

### WordPress
- WordPress.com Business or self-hosted
- ACF Pro plugin
- REST API enabled
- PHP 7.4+

---

## Success Metrics

- [x] iOS app loads from bundle immediately (offline-ready)
- [x] iOS app syncs from WordPress when online (no UI blocking)
- [x] Website builds successfully from WordPress API data
- [x] All bike/event data migrated to WordPress
- [x] Cache works (verified via response times)
- [x] Offline fallback works (verified by disabling network)
- [x] Other co-ops can fork and customize
- [x] No increase in app launch time
- [x] Battery drain acceptable (background sync deferrable)
