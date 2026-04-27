# Testing

StoneBC currently relies on build verification, manual simulator checks, and real-device QA for hardware-dependent flows.

## Quick Build Verification

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -scheme StoneBC \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

## Manual Smoke Test

Run on simulator:

1. Launch the app.
2. Complete onboarding.
3. Confirm Home loads.
4. Open Routes and verify List and Map browser modes render.
5. Select a route and open Overview, Prep, Ride, and History.
6. Toggle a ride overlay, leave the route, return, and verify the toggle persisted.
7. Open Record and verify Free Ride, Follow Route, and Scout Route modes render.
8. Select Follow Route, pick a route, and open the recording UI.
9. Open Rides and verify empty/history state.
10. Open More and confirm Connected Apps renders.
11. Open Follow My Expedition and create a journal.
12. Add a text/check-in entry.
13. Export a PDF log.

## Real-Device Test Matrix

| Feature | Why Device Is Needed |
| --- | --- |
| GPS navigation | Simulator location is not enough for accuracy, heading, and background behavior |
| Ride recording | HealthKit, route building, motion, and lock-screen behavior |
| Rally Radio | Multipeer discovery and microphone behavior |
| Voice memo | Microphone permission and audio session behavior |
| Background audio/location | Requires physical screen-lock and OS lifecycle behavior |
| Camera | Simulator camera is not representative |
| Live Activities | Lock screen and Dynamic Island behavior |

## Follow My Expedition QA

Run once online and once in airplane mode:

1. Create expedition from a guide.
2. Select Battery Saver.
3. Add `Water`, `Food`, `Shelter`, and `Sunset` notes.
4. Add a photo, voice memo, video, and text-only reflection.
5. Relaunch and confirm entries persist.
6. Export PDF and share to Files.
7. Open PDF and verify all notes and media labels render.

## Route QA

- Switch Routes between List and Map modes.
- Verify List and Map share filters, sort order, selection, imported route behavior, and empty states.
- Import GPX, TCX, FIT, KML/KMZ, and ZIP bundle fixtures from Files.
- Confirm planned routes can be saved to My Routes.
- Confirm completed activities can be saved to ride history and saved as routes.
- Export a bundled route as a device bundle ZIP.
- Export single-format GPX, TCX, FIT, and KML files.
- Export a completed ride as GPX Activity, TCX History, FIT Activity, and KML.
- Open route detail and verify Overview, Prep, Ride, and History sections.
- Verify readiness rows for route data, offline data, tiles, weather, cue sheet, cell coverage, and warnings.
- Toggle ride overlays and verify preferences persist per route.
- Start navigation and confirm route line, progress, and off-route warning respect overlay state.
- Start Follow Route recording from route detail.
- Start Free Ride, Follow Route, and Scout Route from the Record tab.
- Pause, resume, stop, and open the post-ride review hub.
- Verify post-ride review can save history only, save as route, submit to co-op, export/share GPX content, and open journal prompt.
- Toggle offline route cache where available.
- Verify WeatherKit failures do not block route detail.
- Verify provider send actions show gated/offline/auth-required states when credentials or network are unavailable.

## Rally Radio QA

Use two physical devices:

1. Install same build on both devices.
2. Put devices on the same Wi-Fi or peer discovery path.
3. Open Rally Radio on both.
4. Confirm peers connect.
5. Hold PTT on device A and listen on device B.
6. Repeat B to A.
7. Test open mic.
8. Lock one screen and confirm expected background audio behavior.

## Regression Notes

When touching shared services, test all dependent flows:

| Service | Dependent Features |
| --- | --- |
| `LocationService` | Route navigation, route recording, Follow My Expedition |
| `MediaCaptureService` | Expedition photo/audio/video capture |
| `AppState` | All bundle data and WordPress sync |
| `BCDesignSystem` | All major UI surfaces |
| `RideHistoryService` | Rides tab, HealthKit import, ride share |

## Automation Gap

The iOS app should eventually add focused XCTest coverage for:

- JSON decoding fixtures
- GPX parse/export round trips
- TCX, FIT, KML/KMZ, and ZIP import/export round trips
- Path-traversal ZIP rejection
- Planned route vs completed ride classification
- Expedition model encoding/decoding
- PDF export non-empty output
- AppConfig fallback behavior
- Ride stat formatting
