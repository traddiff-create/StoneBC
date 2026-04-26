# Repo Config — StoneBC (Stone Bicycle Coalition)

**Used by:** every prompt in `/Applications/Apps/_shared/codex-prompts/` when running an audit against this repo.

**How to use:** copy the "Sentinel Tells" block below into the `{{...}}` placeholders of any audit prompt before pasting into Codex.

---

## Sentinel Tells

| Field | Value |
|---|---|
| `REPO_NAME` | StoneBC (Stone Bicycle Coalition) |
| `REPO_PURPOSE` | Hybrid — iOS app (SwiftUI + MapKit + ActivityKit), Android (Kotlin/Compose), website (Eleventy + Netlify), open-source bike co-op toolkit. Local-first with bundled JSON + optional WordPress sync. |
| `POSITIVE_TELL_PATH` | `StoneBC/RideJournal.swift` |
| `POSITIVE_TELL_PATH_2` | `StoneBC/RideActivityManager.swift` |
| `CONTAMINATION_SYMBOLS` | `MeditationSession`, `Compound.swift`, `OpenMicSlot`, `TicketTailor`, `comedian`, `Photo.swift` (RStone path), `SharedModelBridge` (DharmaGit), `SoulCompound` (BTYBD) |
| `CONTAMINATION_REPO_NAME` | DharmaGit, WRCApp, RStone, or BTYBD (sibling iOS+Android repos) |

---

## Audit Source Maps

### iOS

| Concern | Path |
|---|---|
| iOS source root | `StoneBC/` |
| Ride feature files | `StoneBC/Ride*.swift` (RideJournal, RideStatsView, RideActivityManager, RideShareSheetView, RideExportService, RideJournalService, RideDashboardView, RideChecklist, RideJournalDetailView) |
| App state | `StoneBC/AppState.swift` (search for `@Observable`) |
| Tests | `StoneBCTests/` (verify path) |
| Xcode project | `app.xcodeproj` (note: NOT named StoneBC.xcodeproj) |
| Schemes | `StoneBC` |

### Android

| Concern | Path |
|---|---|
| Android source root | `android/app/src/main/` |
| Ride share util | `android/.../RideShareUtil.kt` |
| applicationId | check `android/app/build.gradle.kts` |
| Tests | `android/app/src/test/` |

### Website

| Concern | Path |
|---|---|
| Eleventy site | `OpenSource-BikeCoopToolkit/` (or wherever Eleventy lives) |
| Deploy | Netlify, stonebicyclecoalition.com |

### Data

| Concern | Path |
|---|---|
| Bundled JSON | `StoneBC/` (search for `*.json`) |
| Config | `config.json` — feature flags, branding, contact, data URLs |
| Route data | `GPX/` (GPX/FIT → JSON via Python) |

### Backend

| Concern | Value |
|---|---|
| Backend type | optional WordPress REST API sync (local-first default) |
| Voice chat | MultipeerConnectivity (peer-to-peer, no backend) |

---

## Build Commands

```bash
# iOS — note: project file is `app.xcodeproj`, not `StoneBC.xcodeproj`
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project "app.xcodeproj" \
  -scheme "StoneBC" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build

# Android
./gradlew :app:assembleDebug
```

---

## Per-repo audit history

| Date | Audit | Output file | Hallucination rate | Notes |
|---|---|---|---|---|
| | | | | |

---

## Special considerations

- **Project file naming** — iOS Xcode project is `app.xcodeproj`, NOT `StoneBC.xcodeproj`. Codex will assume the latter; correct it.
- **My Rides feature shipped recently** (commit 6971942) — first parity audit candidate. Both iOS and Android implementations are present.
- **Config-driven app** — meant to be forked by other bike co-ops. Audits should not hardcode StoneBC-specific values into recommendations; preserve `config.json` extension points.
- **Local-first + optional sync** — backend is optional. Most audits should treat the backend as out-of-scope unless explicitly asked.
- **Voice chat uses MultipeerConnectivity** — no server. Security audits should focus on the peer authentication / pairing flow.
