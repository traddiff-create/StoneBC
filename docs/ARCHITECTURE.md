# Architecture — StoneBC iOS App

## Pattern: MVVM with @Observable

```
┌─────────────────────────────────────────────┐
│                   Views                      │
│  HomeView · MarketplaceView · RadioView     │
│  RoutesView · CommunityFeedView · MoreView  │
└──────────────────┬──────────────────────────┘
                   │ @Environment
┌──────────────────▼──────────────────────────┐
│              AppState (@Observable)           │
│  bikes[] · posts[] · events[] · routes[]     │
│  config · filtering · radioViewModel         │
└──────┬───────────────────────┬──────────────┘
       │                       │
┌──────▼──────┐   ┌───────────▼──────────────┐
│ Data Layer  │   │    Radio Layer            │
│ Bundle JSON │   │ RadioService (MCSession)  │
│ WordPressSvc│   │ AudioStreamService (AVAudio)│
└─────────────┘   └──────────────────────────┘
```

## State Flow

1. `StoneBCApp` creates `ContentView`
2. `ContentView` creates `AppState` and injects via `.environment()`
3. `AppState.init()` loads all JSON from bundle
4. `ContentView.task` calls `appState.syncFromWordPress()` (fire-and-forget)
5. `TabContainerView` reads `AppState` from environment
6. All child views access `AppState` via `@Environment(AppState.self)`

## Navigation

```
TabContainerView (TabView, 5 tabs)
├── HomeView (NavigationStack)
│   ├── BikeDetailView (via featured bikes)
│   └── PostDetailView (via recent posts)
├── RoutesView (NavigationStack)
│   └── RouteDetailView (map + elevation)
├── MarketplaceView (NavigationStack)
│   ├── BikeFilterBar (filter chips)
│   └── BikeDetailView (specs + contact CTA)
├── RadioView (NavigationStack)
│   └── PTTButton (long-press gesture)
└── MoreView (NavigationStack)
    ├── CommunityFeedView → PostDetailView
    ├── CommunityView (events + programs)
    ├── GalleryView
    └── ContactView
```

## Data Strategy

| Source | When | Fallback |
|--------|------|----------|
| Bundled JSON | Always loaded on init | — |
| WordPress REST API | On launch (if configured) | Bundled JSON |
| The Quarry POS | Owner exports → bundle | Previous bikes.json |

## Key Decisions

- **No auth** — app is read-only for users
- **No backend** — all data bundled or optional WordPress
- **Config-driven** — `config.json` controls everything forkable
- **MultipeerConnectivity** for Rally Radio — no server needed
- **@Observable** over Combine — simpler, iOS 17+ only
