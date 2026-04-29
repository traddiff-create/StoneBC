# Blitz Playbook — Route Saving (GPX Import → Persist → Reload)

End-to-end UI verification of the user-route persistence flow. Companion
to `StoneBCTests/UserRouteStoreTests.swift` and
`StoneBCTests/OfflineRouteStorageTests.swift` (which cover the same
layer headlessly). This playbook drives the live UI via the `blitz-iphone`
MCP server, so the simulator must be running with a fresh install.

## Why this exists

The XCTest suite exercises the persistence layer in isolation with
dependency-injected directories. This playbook complements that by
exercising the **UI surface** — file picker → import → save → relaunch
→ verify — which the unit tests cannot reach.

Blitz MCP is a **workstation tool**: it requires a Mac with Blitz, a
booted simulator, and a built/installed app. It is not a CI step.

## Prerequisites

- Blitz IDE open with the StoneBC project loaded
- iPhone simulator booted (any iPhone running iOS 17+)
- Fresh debug install of StoneBC (delete and reinstall, or use a fresh
  simulator clone, so user routes start empty)
- The fixture `StoneBCTests/Fixtures/sample.gpx` accessible to the
  simulator's Files app — easiest is to drag the file onto the
  simulator window or place it in the simulator's Documents folder
  via `xcrun simctl`

## Tooling cheat-sheet

| What you need | MCP call |
|---|---|
| App build status | `blitz-macos` `app_get_state` |
| List sims | `blitz-macos` `simulator_list_devices` |
| Launch app | `blitz-iphone` `launch_app` (bundle: `com.traddiff.StoneBC`) |
| See current screen | `blitz-iphone` `describe_screen` |
| Inspect AX tree | `blitz-iphone` `scan_ui` |
| Tap / swipe / type | `blitz-iphone` `device_action` |
| Screenshot | `blitz-iphone` `get_screenshot` |

## Steps

### 1. Confirm clean build

- **Tool:** `blitz-macos` `app_get_state`
- **Expect:** `state: built` for `com.traddiff.StoneBC`. If not built,
  trigger a build via Blitz before continuing.

### 2. Boot + launch

- **Tool:** `blitz-iphone` `launch_app` with bundle `com.traddiff.StoneBC`
- **After:** `describe_screen`
- **Expect:** Home tab visible, tab bar shows Home / Routes / Record /
  Rides / More.

### 3. Navigate to Routes → Import

- **Tool:** `blitz-iphone` `device_action` (tap by AX label "Routes")
- **After:** `describe_screen`
- **Expect:** RoutesView title bar visible, list of bundled routes.
- **Tool:** `device_action` to open the GPX import sheet (look for an
  "Import" toolbar button or "+" button — confirm via `scan_ui`).
- **After:** `describe_screen`
- **Expect:** GPX Import sheet visible.

### 4. Pick the fixture file

- **Tool:** `device_action` to tap "Choose File" / file picker entry.
- **Note:** WDA cannot drive system file pickers reliably (see
  `wrcapp/test-results/blitz-2026-04-25.md` "WDA limitations"). Workaround:
  pre-stage `sample.gpx` at the simulator's Documents path before the
  run, then tap the file row in the picker.
- **After:** `describe_screen`
- **Expect:** Import sheet shows parsed route metadata — name "Sample
  Test Route", trackpoint count 3, distance > 0.

### 5. Save the route

- **Tool:** `device_action` (tap "Save" or "Add Route" — confirm label).
- **After:** `describe_screen`
- **Expect:** Routes list now shows "Sample Test Route" at the top.

### 6. Force-quit + relaunch

- **Tool:** `blitz-iphone` `launch_app` with the same bundle (Blitz
  re-launches via cold start, validating disk persistence).
- **Alternative:** terminate via simctl, then re-launch.
- **After:** `describe_screen` → navigate back to Routes tab.
- **Expect:** "Sample Test Route" still present at top of list — this
  confirms `UserRouteStore.persist()` wrote to disk and `load()` re-read
  it on the next process. (XCTest covers this headlessly; the playbook
  verifies the same property on the actual app target.)

### 7. Cleanup

- **Tool:** `device_action` to swipe-delete or open the route detail and
  tap "Remove from imports".
- **After:** `describe_screen`
- **Expect:** Route removed from the list.
- Verify via second relaunch that deletion also persisted.

## Known WDA gotchas

- System file pickers — pre-stage files instead of driving the picker.
- Segmented pickers — `device_action` taps may register on the wrong
  segment; verify with `scan_ui` before each action.
- NavigationStack push transitions — `describe_screen` immediately after
  a tap may capture the in-flight transition. Add a short wait or
  re-call `describe_screen` once.

## After running

If any step's after-state diverges from the expected description above,
update this playbook before fixing the divergence — the playbook is the
contract for "Routes flow works."
