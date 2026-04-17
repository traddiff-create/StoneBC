# StoneBC Android — Testing

## At a glance

- **Unit tests:** `./gradlew test` — runs all JVM unit tests in `app/src/test/`
- **Lint:** `./gradlew lintDebug` — Android Lint (wired into CI)
- **UI tests:** Maestro flows in `.maestro/` — 12 flows covering every tab + sub-screen
- **One-command QA:** `/test-android` skill — auto-builds + installs + runs the whole Maestro suite with permissions pre-granted

## Maestro — install once

```bash
curl -Ls "https://get.maestro.mobile.dev" | bash
export PATH="$PATH:$HOME/.maestro/bin"
maestro --version
```

## Running flows locally

```bash
cd /Applications/Apps/StoneBC/android

# One flow
maestro test .maestro/00-launch-and-onboard.yaml

# The whole suite (~3 min)
maestro test .maestro/

# Or use the skill (builds APK, installs, grants permissions, runs suite)
/test-android
```

Debug artifacts land in `~/.maestro/tests/<timestamp>/` — screenshots on every step, full command log, AI failure report.

## Flow inventory

All 12 flows target `com.traddiff.stonebc`. Each non-onboarding flow opens with `launchApp` + `runFlow: subflows/skip-onboarding.yaml` so flows are independently runnable.

| # | File | What it asserts |
|---|---|---|
| 00 | `00-launch-and-onboard.yaml` | Cold launch → swipe through 11 onboarding cards → tap Get Started → land on Home |
| 01 | `01-home-renders.yaml` | Home renders hero, Your Season, Quick Links, Featured Bikes |
| 02 | `02-routes-list.yaml` | Routes tab shows search, difficulty chips, category chips, at least one route card |
| 03 | `03-route-detail.yaml` | Tap route → ELEVATION PROFILE + MAP render, scroll to Start Ride button |
| 04 | `04-record-idle.yaml` | Record tab shows START button + empty "Your first ride" state |
| 05 | `05-bikes-filter.yaml` | Bikes tab (The Quarry) shows STATUS/TYPE chips + inventory; Hybrid filter narrows |
| 06 | `06-more-hub-nav.yaml` | More hub lists every sub-screen; tap each + back to verify titles |
| 07 | `07-expedition-create.yaml` | Expedition Journal opens and shows empty state |
| 08 | `08-rally-radio-disabled.yaml` | Scroll More tab; Rally Radio appears under "IOS ONLY" section |
| 09 | `09-bike-mailto.yaml` | Bike detail renders + "Ask About This Bike" CTA visible |
| 10 | `10-swiss-army-knife.yaml` | Swiss Army Knife shows all 5 tool rows |
| 11 | `11-volunteer-mailto.yaml` | Volunteer form shows Time/Talent/Treasure copy + Open Email CTA |

Current pass rate: **12/12 in ~3m 13s** on Pixel 7 API 34 emulator (arm64-v8a host via Apple silicon).

## Shared subflow — `subflows/skip-onboarding.yaml`

```yaml
- runFlow:
    when:
      visible: "Welcome to StoneBC"
    commands:
      - repeat:
          times: 11
          commands:
            - swipe:
                start: 85%, 50%
                end: 15%, 50%
      - tapOn: "Get Started"
```

Conditional — no-ops if the app is already past onboarding. Gets around the `markComplete()` DataStore-write race that can bite when `launchApp` restarts the app before the suspend fn commits.

## Conventions

- **Tab bar taps:** use `index: 1` to disambiguate from QuickLinks labels on Home. Example: `tapOn: { text: "Routes", index: 1 }`
- **Back navigation:** use `- back` (device back). There is no in-app `Back` id in Compose — the ArrowBack icon has `contentDescription = "Back"` but is unreliable as a Maestro selector
- **Scroll before asserting:** anything below the fold (RECENT POSTS, Start Ride button, Rally Radio) needs `scrollUntilVisible` — plain `assertVisible` only matches what's currently in the viewport
- **Long text substring match:** wrap in regex, e.g. `text: ".*Time.*Talent.*Treasure.*"` — `assertVisible: "Time"` will not match a substring inside wrapped body text
- **No hard sleeps** — Maestro implicitly retries assertions for up to 10s. Trust that before sprinkling `wait`

## Known emulator gotchas

- **Keep sibling apps uninstalled.** Running Dharma Wellness or LakLang alongside StoneBC on the same test emulator triggers system ANRs under Maestro's sustained UI dumps. `adb uninstall` them first:
  ```bash
  adb uninstall com.traddiff.dharma 2>/dev/null
  adb uninstall com.dharma.android 2>/dev/null
  adb uninstall com.traddiff.laklang 2>/dev/null
  ```
- **Disable animations.** Faster + more reliable:
  ```bash
  adb shell settings put global window_animation_scale 0
  adb shell settings put global transition_animation_scale 0
  adb shell settings put global animator_duration_scale 0
  ```
- **`pm clear` before flow 00.** Makes sure onboarding state is fresh:
  ```bash
  adb shell pm clear com.traddiff.stonebc
  ```

The `/test-android` skill handles all three automatically.

## CI

`.github/workflows/android-maestro.yml` runs the full suite on every push to main via `reactivecircus/android-emulator-runner@v2` (API 34, Pixel 7, google_apis, x86_64, no-window). Fails surface the Maestro debug folder as a GitHub Actions artifact for 14 days.

## Adding a new flow

1. Create `.maestro/NN-short-name.yaml` (NN = next number; keeps them alphabetical for suite ordering)
2. Open with `launchApp` + `runFlow: subflows/skip-onboarding.yaml`
3. Prefer `assertVisible` over `assertText`. Prefer text over ids — Compose generally doesn't emit stable ids
4. Run locally until green: `maestro test .maestro/NN-short-name.yaml`
5. Commit both the new flow and any screen-code changes that exposed test-friendly labels (avoid `Modifier.testTag` unless strictly necessary — text is more durable)
