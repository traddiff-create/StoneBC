# ADR 003: Local-First Data Strategy

**Date:** 2026-03-31
**Status:** Accepted

## Context

The app needs to work reliably for riders who may be in areas with poor connectivity.

## Decision

All data is bundled as JSON in the app. WordPress sync is optional and fires on launch as a background task. If sync fails, the app silently uses bundled data.

## Data Sources

| Data | Primary | Optional Sync |
|------|---------|--------------|
| Bikes | bikes.json (bundle) | WordPress custom post type |
| Posts | posts.json (bundle) | WordPress posts endpoint |
| Events | events.json (bundle) | WordPress custom post type |
| Routes | routes.json (bundle), Documents user route library | None (static) |
| Config | config.json (bundle) | None (static) |

## Consequences

- App works fully offline
- Content updates require a new app build (unless WordPress configured)
- No real-time data — acceptable for this use case
- WordPress integration is additive, not required
- Route file import/export remains local-first; provider APIs are optional enhancements
