# Offline Storage

StoneBC is local-first. The app should launch, browse bundled content, record rides, navigate existing routes, capture expedition logs, and export expedition reports without network access.

## Storage Map

| Data | Storage | Owner |
| --- | --- | --- |
| App config | Bundle `StoneBC/config.json` | App owner |
| Bikes | Bundle `StoneBC/bikes.json` | App owner / inventory workflow |
| Posts | Bundle `StoneBC/posts.json` | App owner |
| Events | Bundle `StoneBC/events.json` | App owner |
| Programs | Bundle `StoneBC/programs.json` | App owner |
| Routes | Bundle `StoneBC/routes.json` | GPX processing workflow |
| Tour guides | Bundle `StoneBC/guides.json` | App owner |
| Imported routes | Documents `Routes/userRoutes.json` via `UserRouteStore` | User |
| Ride history | Local app storage via `RideHistoryService` | User |
| Ride journals | `UserDefaults` via `RideJournalService` | User |
| Expedition journals | Documents `Expeditions/<journalId>/journal.json` | User |
| Expedition media | Documents `Expeditions/<journalId>/media/dayN/` | User |
| Expedition exports | Documents `Expeditions/<journalId>/exports/` | User |
| iCloud media drop zone | Ubiquity Documents `8o7/`, fallback Documents `8o7/` | User |
| Offline route cache | App cache/documents through offline route services | User |
| HealthKit workouts | Local Health database | User |

## Bundle Data

Bundle data is the reliable baseline. `AppState.loadData()` decodes bundle JSON synchronously on launch, then optional network sync can replace some in-memory arrays.

Rules:

- Keep bundle JSON valid at all times.
- Do not rely on network data for first launch.
- Keep route trackpoints compact enough for app launch and MapKit rendering.
- Owner-managed files should remain reviewable in git.

## UserDefaults

Use `UserDefaults` only for small user preferences and lightweight records:

- Onboarding flag
- Ride journal metadata
- Tour-guide UI preferences

Do not store large media, GPX blobs, or secrets in `UserDefaults`.

## Documents Directory

Use Documents for user-created artifacts that should survive app restarts and be shareable:

```text
Documents/
  Routes/
    userRoutes.json
  Expeditions/
    <journalId>/
      journal.json
      media/
        day1/
        day2/
      gps/
      contributions/
      exports/
        expedition.html
        expedition-log.pdf
```

`ExpeditionStorage` is the owner for expedition file layout.

`UserRouteStore` is the owner for imported route persistence. `AppState.loadImportedRoutes()` migrates the legacy `UserDefaults` `importedRoutes` value into `Documents/Routes/userRoutes.json` on first launch after the route interop migration.

## Caches

Use caches for derived assets that can be recreated:

- Map snapshots
- Offline route preview artifacts
- Temporary share files
- Route and ride export files created for the native share sheet

Cached files should not be the only copy of user-generated content.

## Offline Route Behavior

Routes work offline from bundled trackpoints. Map tile rendering depends on MapKit cache and any installed offline tile support. Route detail and navigation must degrade cleanly when tiles or weather are unavailable.

Route file import/export also works offline. `RouteInterchangeService` reads GPX, TCX, FIT, KML/KMZ, and ZIP bundles locally and can write GPX, TCX, FIT, KML, or a device bundle ZIP without network access. Garmin, Wahoo, and Ride with GPS uploads require network and provider credentials, but the device bundle remains the fallback.

## Follow My Expedition Offline Behavior

Expedition capture does not require network:

- Journal mutations update local state.
- Autosave writes `journal.json`.
- Photos, video, and audio are stored in local expedition media folders.
- PDF export writes to local `exports/`.
- Sharing uses the native share sheet after local export is created.

## Cleanup Responsibilities

The app can compute expedition storage size with `ExpeditionStorage.storageUsed(journalId:)`.

Future cleanup UI should:

- Delete whole expeditions through `ExpeditionStorage.delete(id:)`.
- Remove orphaned media when deleting individual entries.
- Keep exports reproducible from `journal.json` and media.
- Never delete HealthKit workouts when deleting app-local ride summaries unless the user explicitly requests it.
