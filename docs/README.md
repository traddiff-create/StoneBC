# StoneBC Technical Documentation

This folder is the engineering reference for the StoneBC app family.

## Start Here

| Document | Purpose |
| --- | --- |
| [Getting Started](GETTING_STARTED.md) | Local setup, build commands, and daily development workflow |
| [Architecture](ARCHITECTURE.md) | iOS app structure, state ownership, navigation, and services |
| [Data Model](DATA_MODEL.md) | Bundled JSON, Swift models, and owner-managed content |
| [Build, Test, Release](BUILD_TEST_RELEASE.md) | CLI builds, simulator runs, QA, archives, and release checklist |
| [Configuration](CONFIGURATION.md) | `config.json`, feature flags, branding, fork setup, and external endpoints |
| [Permissions & Services](PERMISSIONS_SERVICES.md) | Apple framework usage, Info.plist keys, entitlements, and service boundaries |
| [Offline Storage](OFFLINE_STORAGE.md) | Local-first storage, caches, documents, exports, and cleanup responsibilities |
| [Follow My Expedition](FOLLOW_MY_EXPEDITION.md) | Expedition journal architecture, capture flow, offline model, and PDF export |

## Feature Docs

| Document | Area |
| --- | --- |
| [Routes & Route Interop](ROUTES.md) | Route catalog, GPX/TCX/FIT/KML/KMZ/ZIP import/export, provider-gated sharing, navigation |
| [Rally Radio](RALLY_RADIO.md) | MultipeerConnectivity push-to-talk radio |
| [The Quarry Architecture](QUARRY-ARCHITECTURE.md) | Bike marketplace and inventory architecture |
| [Design System](DESIGN_SYSTEM.md) | `BCDesignSystem.swift` tokens and reusable components |
| [App Privacy](APP_PRIVACY.md) | App Store privacy labels and local-only data handling |

## Architecture Decision Records

| ADR | Decision |
| --- | --- |
| [001](adr/001-config-driven-architecture.md) | Config-driven architecture |
| [002](adr/002-multipeer-connectivity-for-radio.md) | MultipeerConnectivity for Rally Radio |
| [003](adr/003-local-first-data-strategy.md) | Local-first data strategy |

## Platform Notes

The production iOS app lives under `StoneBC/` and builds from `app.xcodeproj` with scheme `StoneBC`.

The Android port lives under `android/` and has separate docs:

| Document | Purpose |
| --- | --- |
| [Android README](../android/README.md) | Android app overview |
| [Android Setup](../android/SETUP.md) | Android local setup |
| [Android Architecture](../android/docs/ARCHITECTURE.md) | Compose, Room, and navigation |
| [Android Testing](../android/docs/TESTING.md) | Android QA workflow |

## Documentation Rules

- Keep owner-facing customization details in `CUSTOMIZE_ME/`.
- Keep engineering details in `docs/`.
- Update this index when adding or renaming docs.
- Do not include API keys, tokens, passwords, private endpoints, or personal data in documentation.
