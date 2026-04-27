# Codex Review — StoneBC Ride/Navigation Plan

**Author:** Claude (Opus 4.7) | **Date:** 2026-04-25 | **Repo:** StoneBC
**Plan under review:** `~/.claude/plans/continue-twinkling-hennessy.md` (or paste in body below)

**How to run this prompt:**
1. Open a fresh ChatGPT-5.5 / Codex conversation.
2. Paste this entire file as the first message.
3. Provide ChatGPT access to the StoneBC source tree (or paste the relevant files when asked).
4. Wait for the pre-flight to confirm the repo before it produces review output.

---

### Pre-flight (DO NOT SKIP)

Before producing any review content, verify you are operating on the correct repository. A previous run of a similar prompt audited the wrong repo and produced confident findings under the wrong filename. Sentinel checks prevent that.

You are reviewing a plan for **StoneBC (Stone Bicycle Coalition)** — a hybrid iOS app (SwiftUI + MapKit + ActivityKit + HealthKit) for a community bike co-op in Rapid City, SD.

1. Confirm `StoneBC/RideJournal.swift` exists at the path you've been given. If it does not, **STOP** and report: *"Wrong repository — this prompt expects StoneBC. The file `StoneBC/RideJournal.swift` was not found. Aborting."*
2. Confirm `StoneBC/RideActivityManager.swift` exists. Same abort if missing.
3. If you find files referencing any of: `MeditationSession`, `Compound.swift`, `OpenMicSlot`, `TicketTailor`, `comedian`, `Photo.swift` (RStone), `SharedModelBridge` (DharmaGit), `SoulCompound` (BTYBD) — **STOP**. You are in the wrong repo (DharmaGit, WRCApp, RStone, or BTYBD), not StoneBC.
4. The Xcode project file is `app.xcodeproj`, NOT `StoneBC.xcodeproj`. If you assume the latter, correct yourself.

Only after all four checks pass, proceed.

---

## Context

StoneBC is being upgraded into an offline-first cycling "field computer" for Black Hills riders. Apple-native APIs only. iOS 17 deployment target. The user is Rory Stone, owner of Trad Diff LLC and Stone Bicycle Coalition.

The ride/navigation stack currently has ~350 added / 90 removed uncommitted lines across 8 files (`LocationService`, `RecordingService`, `RideSession`, `RouteNavigationView`, `RouteRecordingView`, `OfflineRouteStorage`, `OfflineMapService`, `WorkoutService`, `RideActivityManager`, plus `app.xcodeproj/project.pbxproj`).

Claude (Opus 4.7) produced the implementation plan below after a multi-agent audit. Your job is to **independently review the plan**, validate or refute its findings, and call out anything Claude missed.

## Constraints Claude was given

- Apple built-in APIs only (CoreLocation, MapKit, CoreMotion, HealthKit, ActivityKit, AVFoundation, WeatherKit, BackgroundTasks, Network, SwiftData, UserNotifications). No paid SDKs unless flagged optional.
- Local-first, useful with zero cell service.
- Honest about platform limits — especially that MapKit has **no public offline basemap download API**.
- No archive/release work. Build only on `iPhone 17 Pro Max` simulator.

## What I want you to verify

For **each** numbered item below, return one of:
- **CONFIRM** — finding is correct as stated
- **REFINE** — finding is broadly right but my characterization needs a fix (give the fix)
- **REFUTE** — finding is wrong (cite Apple doc URL or code path)
- **MISSED** — additional finding Claude did not surface (provide it)

### A. Bug findings to verify in source

1. **HealthKit duration inflated by paused time.** Claim: `WorkoutService.endWorkout()` calls `builder.endCollection(at: Date())` (wall-clock), and `RecordingService.totalPausedSeconds` is never subtracted. Verify by reading `StoneBC/WorkoutService.swift:86–124` and `StoneBC/RecordingService.swift:238–252`. Confirm or refute.

2. **Manual `.distanceCycling` cumulative sample fights HealthKit's auto-distance-from-route.** Claim: at `WorkoutService.swift:94–103` the code adds an `HKCumulativeQuantitySample` for `.distanceCycling` over the full workout window, but `routeBuilder.finishRoute(with:)` already causes HealthKit to derive distance from the polyline. Verify by checking Apple's `HKWorkoutRouteBuilder` docs and confirming that attaching a route causes auto-distance derivation. Cite the doc page.

3. **`RideSession` foreground timer stalls when phone locks.** Claim: `RideSession.swift:57–61` uses `Timer.scheduledTimer` for `elapsedSeconds`, which stops firing when the app is backgrounded under `UIBackgroundModes=location`, even though CoreLocation deliveries continue. Verify by reading the file and confirming there is no other elapsed-time advancement path.

4. **Tuning constants drift between three services.** Claim: `RecordingService.swift:32–38` uses `maximumHorizontalAccuracyMeters: 75`, `RideSession.swift:39–41` uses `100`, and `WorkoutService.swift:75` uses `< 50`. Verify exact values.

5. **`OfflineMapService` "tile warming" via `MKMapSnapshotter` is a misconception.** Claim: there is no Apple-documented contract that `MKMapSnapshotter` populates the live `MKMapView` / SwiftUI `Map` HTTP tile cache for later offline display. Verify by citing the Apple `MKMapSnapshotter` doc page; if you find an Apple guarantee that snapshotter requests warm the live cache, **REFUTE** with citation.

6. **Live Activity `staleDate: nil` is the wrong default.** Claim: `RideActivityManager.swift:39, 70, 92` all pass `staleDate: nil`. Verify and confirm Apple's `Activity.update(_:)` doc recommends a real staleDate.

7. **Privacy strings are present in `INFOPLIST_KEY_*` build settings, not in the bare `Info.plist`.** Claim: `app.xcodeproj/project.pbxproj` carries `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`, `INFOPLIST_KEY_NSMotionUsageDescription`, `INFOPLIST_KEY_NSHealthShareUsageDescription`, `INFOPLIST_KEY_NSHealthUpdateUsageDescription`, etc. Verify and confirm there is **no** App Store rejection risk on privacy-string grounds.

### B. Apple API claims to verify against current docs

8. **MapKit has no public offline basemap download API.** Cite the official MapKit framework page or the WWDC 2024/2025 MapKit session(s). If a public API now exists for offline regions, refute and provide the symbol.

9. **`MKTileOverlay` with `file://` URLs is the supported pattern for bundled offline raster tiles.** Confirm with doc citation.

10. **`MKDirections` is online-only (no offline routing).** Confirm.

11. **`CMMotionActivity` does not classify cycling.** Confirm — only walking/running/automotive/stationary/cycling? Apple has hinted at cycling classification on Apple Watch; clarify whether it exists on iPhone CMMotionActivity in iOS 17/18.

12. **`HKWorkoutSession` is watchOS-only; iPhone uses `HKWorkoutBuilder` directly.** Confirm.

13. **`AVSpeechSynthesizer` runs in background under `UIBackgroundModes=audio` with `AVAudioSession.Category.playback` + `.mixWithOthers`.** Confirm; if there are gotchas with `.duckOthers`, surface them.

14. **`CLLocationUpdate.liveUpdates(_:)` (iOS 17+) is production-safe for 8-hour rides.** Confirm or surface known issues.

15. **`BGProcessingTask` is NOT for live recording — only post-ride cleanup.** Confirm.

### C. Architecture / strategy review

16. **Is bundling a static raster tile pack at z=11..14 covering Black Hills core under 80 MB realistic?** Sanity-check tile counts at those zooms for a ~5,000 km² region.

17. **Is USFS topo (public domain) or OSM Cycle (CC BY-SA, attribution) the right primary source for the bundled pack?** Surface licensing landmines.

18. **Is the proposed P0-3 fix (lock-screen elapsed time via `Text(timerInterval:)`) actually how Live Activities solve this in production?** Cite the ActivityKit doc or WWDC session.

19. **The plan keeps `RecordingService` and `RideSession` as separate `@Observable` classes that share state via `RideTuning` constants and `onAutoPause`/`onAutoResume` events.** Is this the right factoring or should they be merged? Argue both sides.

20. **Live Activity update cadence under iOS 18 budgeting.** Apple throttles `Activity.update`. The plan throttles to 1 Hz from CLLocation events. Confirm 1 Hz is safe; if Apple's guidance is lower (e.g., 0.5 Hz max), flag.

### D. Anything Claude missed

Open-ended. Read the plan, then list anything you would add as a P0/P1/P2 item that Claude did not surface — especially:

- App Store / privacy review traps Claude did not flag.
- WatchOS / Apple Watch opportunities for cycling that Apple ships natively.
- WidgetKit (home screen widgets) for "last ride summary" — Claude only mentioned ActivityKit Live Activities.
- iOS 18-specific APIs Claude did not use (e.g. Control Center toggles, Predictive Code, etc.).
- Anything about `MFMessageComposeViewController` / `UIActivityViewController` for the GPX share path.

---

## Plan content (paste of `~/.claude/plans/continue-twinkling-hennessy.md`)

> **Action:** Read the plan from `~/.claude/plans/continue-twinkling-hennessy.md` if available. If you cannot access that path, ask Rory to paste it in; do not invent content.

---

## Output format

Return **one** review document with these sections:

```
# StoneBC Ride/Nav Plan — Independent Review

## Sentinel pre-flight
[CONFIRMED | ABORTED — reason]

## A. Bug findings (1–7)
1. CONFIRM/REFINE/REFUTE/MISSED — short reason
2. ...

## B. Apple API claims (8–15)
8. CONFIRM/REFINE/REFUTE — citation URL or doc page
...

## C. Architecture / strategy (16–20)
...

## D. Missed items
- ...

## Net verdict
[Plan is ready to implement | Plan needs revision before P0 / before P1 / before P2 — list what to revise]
```

Keep each item under 150 words. No invented Apple symbols, no invented file paths.
