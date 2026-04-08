# The Quarry — Inventory Architecture

## Data Flow

```
WordPress Admin (manage bikes)
        │
        ▼ WP REST API
        │ /wp-json/wp/v2/sbc_bike
        │
   ┌────┴────────────────┐
   │                     │
   ▼                     ▼
iOS App              Website
(5-min poll +        (Eleventy build
 pull-to-refresh)     or client-side)
```

## WordPress Custom Post Type: `sbc_bike`

### ACF Fields (to create after Business plan upgrade)

| Field Name     | Type     | Maps To (Swift)       | Notes |
|---------------|----------|-----------------------|-------|
| bike_id       | Text     | Bike.id               | SBC-001 format |
| bike_status   | Select   | Bike.status           | available, refurbishing, sponsored, sold |
| bike_type     | Select   | Bike.type             | road, hybrid, mountain, cargo, cruiser |
| frame_size    | Text     | Bike.frameSize        | e.g. "56cm", "18in", "L" |
| wheel_size    | Text     | Bike.wheelSize        | e.g. "700c", "27.5in", "26in" |
| bike_color    | Text     | Bike.color            | Free text |
| condition     | Select   | Bike.condition        | excellent, good, fair, poor |
| sponsor_price | Number   | Bike.sponsorPrice     | Integer dollars |
| acquired_via  | Select   | Bike.acquiredVia      | donation, purchase, trade |
| features      | Repeater | Bike.features         | Array of strings |

- **Title** (WP native) → `Bike.model`
- **Content** (WP native) → `Bike.description`
- **Featured Image** (WP native) → `Bike.photos[0]`
- **Date Published** (WP native) → `Bike.dateAdded`

## iOS App Integration

### Files
- `WordPressService.swift` — Actor-based WP REST API client, 5-min cache, request dedup
- `AppState.swift` — Periodic sync (5 min) + manual refresh
- `config.json` — `dataURLs.wordpressBase` set to `https://stonebicyclecoalition.com/wp-json/wp/v2`

### Sync Strategy
1. App launch → loads bundled `bikes.json` immediately (offline-first)
2. `startPeriodicSync()` runs `syncFromWordPress()` every 5 minutes
3. Pull-to-refresh on MarketplaceView triggers immediate sync
4. WordPressService caches responses for 5 min, deduplicates concurrent requests
5. If WP is unreachable, bundled data remains — no crashes

### Data Freshness
- **Best case:** Bike added in WP admin → visible in iOS app within 5 minutes
- **Worst case:** Cache miss + network delay → ~15 seconds
- **Offline:** Bundled data always available

## Website Integration

### Eleventy (build-time)
- `src/_data/wp.js` fetches from WP REST API at build time
- Set `WP_API_URL=https://stonebicyclecoalition.com` in Netlify env vars
- Bike data available as `wp.bikes` in templates

### Client-side (quarry.js)
- Can also fetch client-side for real-time updates without rebuild
- Falls back to bundled `bikes.json` if WP unavailable

## Setup Checklist (after WP Business upgrade)

1. [ ] Install plugins: ACF, Custom Post Type UI, ACF to REST API
2. [ ] Create `sbc_bike` custom post type (CPT UI)
3. [ ] Create ACF field group "Bike Details" with fields above
4. [ ] Assign field group to `sbc_bike` post type
5. [ ] Enter the 4 sample bikes from `inventory/bikes.json`
6. [ ] Verify API: `curl https://stonebicyclecoalition.com/wp-json/wp/v2/sbc_bike`
7. [ ] Set Netlify env var `WP_API_URL`
8. [ ] Build and test iOS app against live API
9. [ ] Update bundled `bikes.json` with real inventory data
