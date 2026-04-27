# Build, Test, Release

## Required Toolchain

Use stable Xcode, not an RC build.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

The iOS target is `iOS 17.0+`. The project file is `app.xcodeproj`; the app scheme is `StoneBC`.

## Build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -scheme StoneBC \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

Use `-project app.xcodeproj` only when a script or CI environment cannot infer the project.

## Run on Simulator

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -scheme StoneBC \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'

xcrun simctl boot "iPhone 17 Pro Max" 2>/dev/null || true
xcrun simctl install booted \
  ~/Library/Developer/Xcode/DerivedData/app-*/Build/Products/Debug-iphonesimulator/StoneBC.app
xcrun simctl launch booted com.traddiff.StoneBC
```

## Lint

```bash
swiftlint lint --config .swiftlint.yml
```

If SwiftLint is not installed locally, install it outside the repo or run the build-only verification.

## Test Strategy

There is no conventional XCTest suite in the current iOS target. Verification is a mix of compiler builds, simulator smoke tests, and real-device tests for hardware-dependent features.

| Area | Minimum Verification |
| --- | --- |
| Swift compile safety | `xcodebuild build -scheme StoneBC` |
| JSON content | Launch app and verify bundle data loads without `AppState.loadErrors` |
| Route files | Import/export GPX, TCX, FIT, KML/KMZ, and ZIP bundle fixtures; open route detail and start navigation |
| Follow My Expedition | Create expedition, add text/photo/audio/video/check-in, relaunch, export PDF |
| Rally Radio | Two physical devices, same local network or peer discovery path |
| HealthKit rides | Physical device with Health permission |
| Location and navigation | Physical device or simulator location route |
| Background audio/location | Physical device screen-lock test |

## Archive

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild archive \
  -scheme StoneBC \
  -archivePath build/StoneBC.xcarchive
```

Use `ExportOptions.plist` for export workflows. Confirm the bundle identifier, team, version, and entitlements before archiving.

## Release Checklist

Before shipping:

- Build succeeds on stable Xcode.
- No secrets are present in `config.json`, docs, or staged files.
- `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` are updated in `app.xcodeproj`.
- `StoneBC/config.json` has production branding, contact, and feature flags.
- App Store privacy answers match [App Privacy](APP_PRIVACY.md).
- Camera, microphone, location, local network, HealthKit, motion, and Photos prompts are accurate.
- Expedition PDF export works after airplane-mode capture.
- Route device bundle export works in airplane mode.
- Provider route uploads are gated when credentials/network are unavailable.
- Rally Radio is tested on physical devices if touched.
- Route navigation and recording are tested on physical device if touched.
- Any bike inventory status changes follow the waitlist matcher rule in `AGENTS.md`.

## Git Notes

The parent `/Applications/.gitignore` blocks broad file additions. When staging files from this repo, use forced adds:

```bash
git add -f docs/BUILD_TEST_RELEASE.md
git add -f StoneBC/ChangedFile.swift
```

Do not force-push `main` or `master`.
