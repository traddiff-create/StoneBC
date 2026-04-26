# RideWidgetExtension

Lock Screen + Dynamic Island UI for the StoneBC ride Live Activity. Renders the
elapsed-time counter locally via `Text(timerInterval:pauseTime:)` so the main
app does not push every-second updates to ActivityKit.

## Files

- `RideWidgetBundle.swift` — `WidgetBundle` entry point with `@main`.
- `RideLiveActivityWidget.swift` — `ActivityConfiguration<RideActivityAttributes>` with
  Lock Screen + Dynamic Island variants (compact, expanded, minimal).
- `Info.plist` — `NSExtension` keys for the WidgetKit extension point.

## Adding the Xcode target (one-time)

The Swift sources are ready; the Xcode target wiring is not yet committed to
`app.xcodeproj/project.pbxproj`. Run these steps in Xcode once:

1. **File → New → Target… → Widget Extension**
   - Product Name: `RideWidgetExtension`
   - Bundle Identifier: `com.traddiff.StoneBC.RideWidget`
   - Include Live Activity: **YES** (the template wires `NSSupportsLiveActivities`)
   - Project: `StoneBC` (host app)
   - Embed in Application: `StoneBC`

2. Xcode will create `RideWidgetExtension/` with template Swift files. Replace
   them with the files in this directory:
   - Delete the template `RideWidgetExtensionBundle.swift` and `RideWidgetExtensionLiveActivity.swift`
   - Move `RideWidgetBundle.swift` and `RideLiveActivityWidget.swift` into the
     new target's group, and add them to the target's Compile Sources phase
   - Replace the template `Info.plist` with the one in this directory
     (the only meaningful key is `NSExtension.NSExtensionPointIdentifier`).

3. Add `RideActivityAttributes.swift` to the new target as well — it is
   shared between the main app and the widget. In Xcode's File Inspector,
   tick **both** the `StoneBC` and `RideWidgetExtension` target memberships.

4. Confirm the main app's `Info.plist` has:
   ```xml
   <key>NSSupportsLiveActivities</key>
   <true/>
   ```
   (the Widget Extension template adds this if missing).

5. Build both schemes:
   ```sh
   xcodebuild build -project app.xcodeproj -scheme StoneBC \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
   xcodebuild build -project app.xcodeproj -scheme RideWidgetExtension \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
   ```

6. Test on a real device: start a ride from `RouteNavigationView`, lock the
   screen, and verify the Live Activity appears with a live-counting timer.
   Pause the ride — the timer should freeze. Resume — it counts again.

## Verification checklist

- [ ] Lock Screen view renders speed, distance, and live timer
- [ ] Dynamic Island compact / minimal show the timer correctly
- [ ] Off-route flag promotes `relevanceScore` (orange keyline tint)
- [ ] `Text(timerInterval:pauseTime:)` freezes during pause
- [ ] Backgrounding the app for >30 s keeps the activity rendering (staleDate
      offset is `RideTuning.liveActivityStaleSeconds`)
- [ ] Console.app shows fewer than 12 `Activity.update` calls per minute on a
      steady ride (5 s throttle floor in `RideActivityManager`)
