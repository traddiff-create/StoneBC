# StoneBCWatch

watchOS v0.1 companion to the iPhone app. Receives ride state from the
phone over `WatchConnectivity` and renders a glanceable stats view. PTT
on Watch is stubbed for v0.2.

## Files

- `StoneBCWatchApp.swift` — `@main` entry point with a vertical-page
  TabView of stats and radio.
- `RideStatsWatchView.swift` — distance / moving time / climb / speed,
  with off-route flag and "waiting for iPhone" empty-state.
- `WatchRadioView.swift` — placeholder for Rally Radio PTT (not wired
  in v0.1).
- `WatchConnectivityService.swift` — `WCSession` delegate that decodes
  incoming `[String: Any]` payloads into `WatchRideState`.
- `WatchRideState.swift` — Codable mirror of the iOS-side
  `WatchRideMessage`. Field-for-field identical; keep both in sync
  until extracted into a shared Swift Package.
- `Info.plist` — minimal watchOS app keys (`WKApplication = true`,
  `WKCompanionAppBundleIdentifier = com.traddiff.StoneBC`).

## Adding the Xcode target (one-time)

The Swift sources are ready; the Xcode target wiring is **not** in
`app.xcodeproj/project.pbxproj`. Run these steps in Xcode once:

1. **File → New → Target… → watchOS → App**
   - Product Name: `StoneBCWatch`
   - Bundle Identifier: `com.traddiff.StoneBC.watchkitapp`
     (Xcode will prompt; accept the default which appends `.watchkitapp`
     to the iOS bundle id)
   - Interface: **SwiftUI**
   - Language: Swift
   - **Embed in companion application**: `StoneBC`
   - Tick "Include Notification Scene": **NO** (v0.1 has no
     notifications; you can add it later)

2. Xcode will create a `StoneBCWatch/` folder with template files.
   Replace them with the files in this directory:
   - **Delete** the template `StoneBCWatchApp.swift`,
     `ContentView.swift`, and `Assets.xcassets` group entries that
     ship with the template.
   - **Move** these 5 Swift files into the new target's group, and
     tick `StoneBCWatch` membership in the File Inspector:
     - `StoneBCWatchApp.swift`
     - `RideStatsWatchView.swift`
     - `WatchRadioView.swift`
     - `WatchConnectivityService.swift`
     - `WatchRideState.swift`
   - **Replace** the template `Info.plist` with the one in this
     directory (the only meaningful keys are `WKApplication`,
     `WKCompanionAppBundleIdentifier`, and `UIDeviceFamily = [4]`).

3. Add `WatchRideMessage.swift` (located in the iOS target at
   `StoneBC/WatchRideMessage.swift`) to the Watch target as well —
   it's identical to `WatchRideState.swift` and we should consolidate.
   Pick one to keep; tick **both** target memberships in the File
   Inspector. Once that's done, delete the redundant copy.

4. Confirm the iOS app's `Info.plist` does not need changes — the
   companion-app id in step 1 is what binds the Watch app to the iOS
   app.

5. Build both schemes:
   ```sh
   xcodebuild build -project app.xcodeproj -scheme StoneBC \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
   xcodebuild build -project app.xcodeproj -scheme StoneBCWatch \
     -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
   ```

6. Test on a paired simulator: open Xcode's
   **Window → Devices and Simulators**, pair an Apple Watch sim with
   your iPhone sim, then run `StoneBCWatch`. From the iPhone, start a
   recording — the Watch's stats view should populate within a few
   seconds.

## Wiring the iPhone broadcaster

The phone-side service `PhoneToWatchService` (in
`StoneBC/PhoneToWatchService.swift`) is already in the iOS target.
Wire it into the recording flow once the Watch target is built:

```swift
// In RideRecordingCoordinator (or wherever ride state is updated):
let watch = PhoneToWatchService()

// Each tick (or every 1–5 s):
watch.broadcast(WatchRideMessage(
    distanceMiles: session.distanceMiles,
    movingSeconds: session.movingSeconds,
    elevationGainFeet: session.elevationGainFeet,
    currentSpeedMPH: session.currentSpeedMPH,
    isOffRoute: session.isOffRoute,
    isPaused: session.isPaused,
    timestamp: Date()
))
```

For v0.1, `sendMessage` is fine (live but lossy); for power-saving,
switch to `updateApplicationContext` (last-known-state, persisted).
The service already does the right thing based on reachability.

## v0.1 verification checklist

- [ ] Watch sim pairs with iPhone sim in Xcode
- [ ] Cold launch on Watch shows "Waiting for iPhone…"
- [ ] After phone broadcasts a message, stats populate
- [ ] Off-route flag turns red when `isOffRoute = true`
- [ ] Pause icon appears when `isPaused = true`
- [ ] App backgrounds and foregrounds without crashing

## v0.2 roadmap (separate plan)

- Rally Radio PTT from the Watch (proxies audio through iPhone's MCSession)
- Independent Watch recording (`HKWorkoutSession` on Watch, sync back to phone)
- Complications / Smart Stack widgets
- Standalone watchOS app (no iPhone required)
