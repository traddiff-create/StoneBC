# TestFlight Beta — StoneBC v0.87 (build 5)

Copy-paste source for App Store Connect TestFlight fields. Update the
build number for each successive upload; keep the version string in
sync with `MARKETING_VERSION` in `app.xcodeproj/project.pbxproj`.

---

## App Store Connect → App Information

**Subtitle (≤30 chars)**
Community bike co-op, on a bike

**Promotional Text (≤170 chars, editable any time)**
Routes, rides, and Rally Radio for the Stone Bicycle Coalition in Rapid City. Find a route, record a ride, talk to your group — no cell service needed.

**Description (≤4000 chars)**
Stone Bicycle Coalition is the companion app for the community bike co-op based at the Minneluzahan Senior Center in Rapid City, South Dakota.

Browse 42 curated Black Hills cycling routes with elevation profiles and turn-by-turn cues. Import your own GPX, TCX, FIT, or KML files and they're saved on your phone, ready to ride offline.

Record rides with full GPS tracking, elevation gain, and Apple Health integration. Your ride history shows distance, moving time, average speed, and a map of every track. Review by season, by route, or by all-time.

Rally Radio uses peer-to-peer Wi-Fi and Bluetooth — no cellular tower or internet required — to give your riding group push-to-talk voice chat across miles of remote trail. Hand it to a Bluetooth headset and you can talk hands-free on the bike.

Browse The Quarry, the co-op's adopt-a-bike inventory, and see what's available, on the way, or already homed. Read the community feed for shop hours, group ride announcements, and volunteer opportunities. Plan multi-day expeditions with the Lewis & Clark-style Tour Guide system, then capture photos, voice memos, and notes during the ride for a shareable journal.

Open source under CC BY-SA 4.0. Fork the repo at github.com/traddiff-create/StoneBC to spin up the app for your own bike co-op — config-driven branding, no code changes required.

**Keywords (≤100 chars, comma-separated)**
bicycle,bike,gravel,gpx,routes,bikepacking,radio,trail,rapid city,black hills,co-op

**Support URL**
https://stonebicyclecoalition.com

**Marketing URL**
https://stonebicyclecoalition.com

---

## TestFlight → Test Information (per build)

**What to Test (≤4000 chars)**
StoneBC v0.87 build 5 — first TestFlight build. Thanks for testing.

Focus areas:
1. **Routes.** Tap the Routes tab, then the + button → import a GPX. Save it, force-quit the app, relaunch. The imported route should still be in the list. Tap into it; the map and elevation profile should load.
2. **Recording a ride.** From the Record tab, pick Free Ride and tap Start. Ride for 5+ minutes with the phone in your pocket — the screen will lock. Stop when you're done. Open the Rides tab; the ride should have distance, moving time, elevation gain, average speed, and a track on the map.
3. **Rally Radio.** Two devices on the same Wi-Fi or personal hotspot. From Home, open Rally Radio. Both phones should see each other in the peer list. Hold the PTT button on one, talk — the other should hear you. Try a Bluetooth headset and confirm hands-free PTT works.
4. **Permissions.** First launch will prompt for Location, Motion, Microphone, and Apple Health. Each prompt has a sentence explaining why — please flag any that feel unclear or scary.
5. **Anything that feels off.** Layout glitches, freezes, weird empty-states, copy errors. Screenshots help.

Known limitations in this build:
- Live Activity (Lock Screen / Dynamic Island ride widget) is not present. The widget extension target ships in a future build.
- No Apple Watch app yet.
- The Quarry inventory is read-only; ordering / waitlist is by emailing info@stonebicyclecoalition.com.

How to send feedback:
- TestFlight → tap Send Beta Feedback (or take a screenshot in TestFlight)
- Email: info@stonebicyclecoalition.com
- Crashes: tap Send when iOS prompts — they come straight to us.

**Beta App Description (review only, ≤4000 chars)**
StoneBC is the iOS app for the Stone Bicycle Coalition, a community bike co-op based in Rapid City, South Dakota. The app provides curated cycling routes, ride recording with HealthKit integration, peer-to-peer voice chat (Rally Radio) for group rides without cell service, and a community feed. Testers are members of the co-op and local riders; they will exercise GPX import, ride recording with location services, Bluetooth audio routing for the radio feature, and Apple Health workout writes.

**Feedback Email**
info@stonebicyclecoalition.com

---

## TestFlight → Beta App Review Information (external testers only)

Only required if/when you add **external** testers. Internal testers
(your team's Apple IDs) do not require Beta App Review.

**Contact Email**
info@stonebicyclecoalition.com

**Contact Phone**
[Rory — fill in]

**Demo Account**
Not required — the app has no login wall. Public-first. All features are
reachable without authentication.

**Notes for Reviewer**
The app uses MultipeerConnectivity (Bonjour service `_stonebc-radio._tcp`) for peer-to-peer voice chat in the "Rally Radio" feature. This requires two devices on the same local network — for review, please test the app's primary flows (Routes, Record, Rides, Home) on a single device. The Rally Radio screen will show "Looking for nearby riders" with no peers, which is the correct state for solo review.

The app reads/writes Apple Health workouts, reads CoreLocation in foreground and background (UIBackgroundModes: location, audio), and uses CoreMotion for barometer-based elevation. All usage descriptions are in Info.plist.

The app is open source under CC BY-SA 4.0; the source repo is github.com/traddiff-create/StoneBC.

---

## Internal tester invite list (track here)

| Tester | Apple ID email | Status |
|---|---|---|
| Rory Stone | traddiff@gmail.com | — |
| _add more_ | | |

---

## After this build

When you upload v0.88 build 1, only the "What to Test" section needs
updating — the Description / Promotional / Keywords carry over until
you change them in App Information.
