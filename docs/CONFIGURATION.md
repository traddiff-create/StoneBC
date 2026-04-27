# Configuration

StoneBC is intended to be forked by other bike co-ops. Runtime identity, feature availability, contact links, and optional remote data sources are driven by `StoneBC/config.json`.

## Config Loader

`AppConfig.load()` reads `config.json` from the app bundle. If decoding fails, `AppConfig.default` is used so the app still launches.

Key file: `StoneBC/AppConfig.swift`

## Schema

```json
{
  "coalitionName": "Stone Bicycle Coalition",
  "shortName": "SBC",
  "tagline": "Building Community Through Cycling",
  "websiteURL": "https://stonebicyclecoalition.com",
  "email": "info@stonebicyclecoalition.com",
  "phone": null,
  "instagramHandle": "stone_bicycle_coalition",
  "location": {
    "name": "Minneluzahan Senior Center",
    "address": "315 N 4th St",
    "city": "Rapid City",
    "state": "SD",
    "zip": "57701"
  },
  "colors": {
    "brandBlue": "#2563eb",
    "brandGreen": "#059669",
    "brandAmber": "#f59e0b"
  },
  "features": {
    "enableMarketplace": true,
    "enableCommunityFeed": true,
    "enableRoutes": true,
    "enableEvents": true,
    "enableGallery": true,
    "enableRadio": true
  },
  "dataURLs": {
    "wordpressBase": null,
    "bikes": null,
    "events": null,
    "posts": null
  },
  "apiKeys": {
    "trailforks": null,
    "stravaClientId": null,
    "stravaRedirectURI": null,
    "garminClientId": null,
    "wahooClientId": null,
    "rideWithGPSClientId": null
  }
}
```

## Feature Flags

| Flag | Controls |
| --- | --- |
| `enableMarketplace` | Bike marketplace / The Quarry surface |
| `enableCommunityFeed` | Community feed section |
| `enableRoutes` | Routes tab |
| `enableEvents` | Events and programs |
| `enableGallery` | Photo gallery |
| `enableRadio` | Rally Radio availability |

When a flag hides UI, keep the underlying bundled data valid. `AppState` still decodes bundle files at launch.

## Branding Rules

Do not hardcode co-op name, email, public website, location, or brand colors in feature code. Read from `AppState.config` or use centralized design tokens.

Current `BCDesignSystem.swift` contains fixed default colors. If another co-op needs runtime color changes, the next step is to bridge `AppConfig.colors` into `BCColors`.

## Optional WordPress Sync

`dataURLs.wordpressBase` enables a public WordPress REST sync for bikes, posts, and events.

Expected behavior:

1. Bundled JSON loads first.
2. `AppState.syncFromWordPress()` fetches public remote content.
3. Successful responses replace in-memory bundled content.
4. Network errors leave bundled content in place.

No user token or secret should be needed for public content sync.

## API Keys

`AppConfig.APIKeys` exists for optional integrations such as Trailforks, Strava, Garmin, Wahoo, and Ride with GPS.

Do not commit real API keys or secrets in `config.json`. Provider client IDs may be public, but client secrets, access tokens, refresh tokens, and private endpoints must not be bundled.

Route provider integrations use `RouteProviderManager` and store OAuth tokens in Keychain. Provider upload must remain feature-gated when credentials or approvals are missing; local file import/export must continue to work offline.

## Fork Checklist

1. Copy templates from `CUSTOMIZE_ME/`.
2. Edit `StoneBC/config.json`.
3. Replace bundle content files: `bikes.json`, `posts.json`, `events.json`, `programs.json`, `photos.json`, `guides.json`, and `routes.json` as needed.
4. Change `PRODUCT_BUNDLE_IDENTIFIER` in `app.xcodeproj`.
5. Change app icons in `StoneBC/Assets.xcassets`.
6. Update App Store metadata in `docs/APP_STORE_METADATA.md`.
7. Run the build command in [Build, Test, Release](BUILD_TEST_RELEASE.md).
