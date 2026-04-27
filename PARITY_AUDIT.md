# StoneBC iOS-Android Parity Audit

**Date:** 2026-04-27
**Scope:** Current iOS v0.8 behavior versus Android parity branch
**Method:** Source review, JSON asset comparison, Android build, Android JVM tests

## Executive Summary

**Overall status: IN PROGRESS — Android is buildable and close, but not full iOS feature-depth parity.**

- Android is not greenfield: the Compose app, Room journal storage, route maps, ride recording service, Fastlane, CI, and Maestro flows already exist.
- This parity pass adds KMP shared contracts, canonical asset sync, a lowercase Play package ID, route-linked recording metadata, Android Keystore-backed Strava token storage, and JVM parity tests.
- Remaining gaps are feature-depth issues, mostly around advanced iOS route tooling and expedition/tour-guide affordances.

## Current Findings

| Area | Status | Notes |
|---|---|---|
| Build | PASS | `./gradlew :app:assembleDebug` succeeds. |
| Shared contracts | PASS | `:shared` owns config/content/route/ride models; app model files are aliases. |
| Data assets | PASS | Android JSON is synced from `StoneBC/` by `Scripts/sync_android_assets.py`. |
| Package identity | PASS | Play package normalized to `com.stonebicyclecoalition.stonebc`. |
| Token storage | PASS | Strava tokens use Android Keystore-backed encrypted values; legacy plain prefs are migrated then cleared. |
| Unit tests | PASS | Asset parity and route-recording metadata tests added under `android/app/src/test`. |
| Maestro tests | NEEDS RUN | Flow expectations updated for empty current bike inventory and route-to-record navigation. |

## Remaining Parity Gaps

| Priority | Gap | Android work needed |
|---|---|---|
| P1 | Route detail depth | Add iOS-style Overview / Prep / Ride / History sections, route preferences, offline readiness, share/export affordances. |
| P1 | Route interop | Android has GPX export for rides, but not iOS-level GPX/TCX/FIT/KML/KMZ/ZIP route import/export. |
| P1 | Journey Console parity | Android record flow now has Free/Follow/Scout entry points, but not the full iOS safety/offline/power/camp review surface. |
| P2 | Swiss Army Knife | Weather, Trailforks, USFS, and Strava screens are present, but several are gated by missing public config or route-detail integration. |
| P2 | Tour guide depth | Shared model now accepts iOS guide metadata, but Android UI still shows a thinner guide experience. |
| P2 | Expedition export depth | Android Room journal exists; compare field-level export against iOS PDF/HTML expectations before release. |

## Verification

Run from repo root unless noted:

```bash
python3 Scripts/sync_android_assets.py --check
cd android
./gradlew :app:testDebugUnitTest :app:assembleDebug
./gradlew lintDebug
maestro test .maestro/
```

The first two Android checks passed locally on 2026-04-27. Maestro remains the final release-candidate gate.
