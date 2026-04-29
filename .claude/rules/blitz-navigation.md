# Blitz Playbook — 5-Tab Navigation Smoke + Per-Tab Flows

End-to-end verification of the StoneBC tab structure and the primary
flow on each tab. Use after a non-trivial change touching navigation,
tab content, or shared state. Companion to `blitz-route-saving.md`
(which goes deeper on the Routes import flow).

## Why a playbook (not XCUITest)

XCUITest target setup would require new pbxproj surgery (test product,
scheme target, build configs, host-app dependency) — meaningful work
that Rory should sign off on before adoption. Until then, this Blitz
playbook is the navigation regression net.

## Prerequisites

- StoneBC built and running on a fresh simulator (or with bookmarks /
  imports cleared so empty-states are visible)
- Blitz IDE open with the project loaded
- Home tab is the launch landing — confirm via first `describe_screen`

## Tab inventory (from `TabContainerView.swift:14`)

| # | Tab | Toolbar title | systemImage |
|---|-----|---------------|-------------|
| 0 | Home | (custom hero header) | `house.fill` |
| 1 | Routes | `ROUTES` | `map` |
| 2 | Record | `RECORD` | `record.circle.fill` |
| 3 | Rides | `RIDES` | `bicycle` |
| 4 | More | `MORE` | `ellipsis` |

Routes tab is feature-flagged on `appState.config.features.enableRoutes`.
If the feature is off, the tab won't render — adjust expected indices.

## Smoke flow

### S1. Cold launch lands on Home

- `blitz-iphone` `launch_app` (bundle `com.traddiff.StoneBC`)
- `describe_screen`
- **Expect:** tab bar with 5 tabs; selected tab is "Home"; some bike
  cards or hero element visible.

### S2. Each tab is reachable

For each tab in order — Home → Routes → Record → Rides → More:

- `device_action` tap by the tab's AX label
- `describe_screen`
- **Expect for non-Home tabs:** the tab's title text (`ROUTES`,
  `RECORD`, etc.) is present in the toolbar principal area.
- **Expect for Home:** hero / bike-card content visible.

### S3. Backwards navigation returns to Home

- Tap "Home" again
- `describe_screen`
- **Expect:** Home content visible, no leftover detail-stack pushed.

### S4. Cold-launch state restoration (optional, version-dependent)

- Tap into "More" → some sub-detail screen (e.g. "Locations" or
  "About")
- Force-quit + relaunch via `launch_app`
- `describe_screen`
- **Expect:** lands back on Home (default) — StoneBC does not currently
  persist tab selection. Document if behavior changes in a future PR.

---

## Per-tab flows

Each section is a 60-second sanity check of the tab's headline content.
Run after Smoke S1–S3.

### T1. Home

- **Expect on screen:** featured bikes, recent posts/upcoming events,
  ride summary widgets.
- **Action:** tap the first bike card.
- **Expect:** bike detail view pushed; back-arrow returns to Home.

### T2. Routes

- **Expect on screen:** "ROUTES" header, count of routes, list of
  bundled + imported routes.
- **Action:** tap any route → route detail view loads with map preview,
  cue list, ride defaults.
- **Action:** back → tap import / "+" → GPX import sheet.
  - For the deeper save-and-relaunch verification, follow
    [`blitz-route-saving.md`](blitz-route-saving.md) instead of
    repeating it here.

### T3. Record

- **Expect on screen:** "RECORD" header, recording-mode picker (free /
  follow / scout), Journey Console section.
- **Action:** tap "Free Ride" → recording start screen renders.
- **Action:** back to Record tab without starting.
- **Caveat:** do not actually start a recording on the simulator unless
  you've stubbed location services — runaway sim recording can drain
  battery percentages in test reports.

### T4. Rides

- **Expect on screen:** "RIDES" header, History/Stats segmented control,
  ride history list (or empty-state).
- **Action:** if history is non-empty, tap a ride → ride detail loads
  with map and metrics.
- **Action:** swap segment to "Stats" → aggregate metrics view loads.

### T5. More

- **Expect on screen:** "MORE" header, version label (e.g. "v0.2"),
  list of grouped settings rows (Locations, About, Privacy, etc.).
- **Action:** tap "Locations" → list of cooperative locations renders.
- **Action:** tap "About" → about screen with version + credits.

---

## When a step fails

If `describe_screen` doesn't show the expected element:

1. Re-call `describe_screen` once — NavigationStack push transitions can
   capture an in-flight frame.
2. Use `scan_ui` to dump the AX tree and check for label/identifier
   drift.
3. If a label genuinely changed in code, update this playbook to match
   before fixing the test failure. The playbook is the contract.

## Known WDA gotchas

- Tab bar taps work reliably by AX label; coordinate-based taps are
  flaky on iPad-sized sims.
- `NavigationStack` push transitions occasionally race
  `describe_screen` — see retry guidance above.
- System sheets (action sheets, file picker) are mostly out of WDA
  reach — see `blitz-route-saving.md` for the file-import workaround.
