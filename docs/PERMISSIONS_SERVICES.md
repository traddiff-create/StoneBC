# Permissions & Services

StoneBC uses Apple frameworks for local-first ride tracking, media capture, radio, and Health integration. This document maps each capability to its code boundary and permission requirement.

## Info.plist Keys

Most usage descriptions are generated from `app.xcodeproj` build settings, while `StoneBC/Info.plist` carries additional static keys such as URL schemes, Bonjour services, Health share usage, and background modes.

| Permission / Capability | Key | Used By |
| --- | --- | --- |
| Camera | `NSCameraUsageDescription` | Expedition photo capture |
| Microphone | `NSMicrophoneUsageDescription` | Rally Radio, expedition voice memos |
| Location when in use | `NSLocationWhenInUseUsageDescription` | Routes, ride recording, Follow My Expedition |
| Motion | `NSMotionUsageDescription` | Altimeter and climb metrics |
| Health read | `NSHealthShareUsageDescription` | HealthKit ride import/history |
| Health write | `NSHealthUpdateUsageDescription` | Saving rides as cycling workouts |
| Local network | `NSLocalNetworkUsageDescription` | Rally Radio peer discovery |
| Photos add-only | `NSPhotoLibraryAddUsageDescription` | Saving share cards/photos |
| Live Activities | `NSSupportsLiveActivities` | Ride live activity |
| Background modes | `UIBackgroundModes` | Audio and location |
| Bonjour services | `NSBonjourServices` | `_stonebc-radio._tcp` |
| Document types | `CFBundleDocumentTypes`, `UTImportedTypeDeclarations` | GPX, TCX, FIT, KML/KMZ, ZIP import from Files/share sheet |
| Open in place | `LSSupportsOpeningDocumentsInPlace` | Security-scoped route file access |

## URL Scheme

The app registers `stonebc://`.

Current deep link:

```text
stonebc://auth?token=<token>&email=<email>
```

Route provider OAuth callbacks also use the app scheme:

```text
stonebc://wahoo-callback?code=<code>
stonebc://rwgps-callback?code=<code>
```

`StoneBCApp.handleDeepLink(_:)` validates the token through `MemberAuthService` before storing the member session.

## Location

Key files:

- `LocationService.swift`
- `RouteNavigationView.swift`
- `RouteRecordingView.swift`
- `ExpeditionTimelineView.swift`

Tracking modes:

| Mode | Accuracy | Distance Filter | Background |
| --- | --- | --- | --- |
| Foreground | Best | 10 m | No |
| Ride | Best | 8 m | Yes |
| Expedition High Detail | Best | 10 m | Yes |
| Expedition Balanced | Nearest 10 m | 25 m | Yes |
| Expedition Battery Saver | 100 m | 100 m | Yes |
| Expedition Check-In | 1 km | 500 m | No |

Location data is used locally for map display, route progress, ride records, and expedition entries. The app does not upload location data to a StoneBC server.

## HealthKit

Key files:

- `WorkoutService.swift`
- `HealthKitRideImporter.swift`
- `RideHistoryService.swift`

HealthKit writes completed rides as cycling workouts and can read cycling workouts for ride history. Health data stays in the local HealthKit store unless the user shares it through Apple-controlled surfaces.

## ActivityKit

Key files:

- `RideActivityAttributes.swift`
- `RideActivityManager.swift`
- `RideLiveActivityWidget.swift`

Live Activities display route progress and ride status during active navigation or recording.

## MultipeerConnectivity

Key files:

- `Radio/RadioService.swift`
- `Radio/AudioStreamService.swift`
- `Radio/RadioViewModel.swift`
- `Radio/RadioView.swift`

Rally Radio uses peer-to-peer discovery and transport. Audio is transmitted between nearby devices and is not stored by the app.

## WeatherKit

Key files:

- `WeatherService.swift`
- `RouteWeatherView.swift`

Weather requires network access and appropriate Apple configuration. Weather failures should degrade to unavailable weather UI without blocking offline route or expedition workflows.

## Route File Interchange

Key files:

- `RouteInterchangeService.swift`
- `GPXImportView.swift`
- `UserRouteStore.swift`
- `RideHistoryService.swift`

Route and ride files are imported with security-scoped Files access. GPX, TCX, FIT, KML/KMZ, and ZIP parsing happens locally. ZIP bundle entries are path-validated before reading, and imported route persistence goes to the app Documents directory rather than `UserDefaults`.

## Connected Route Providers

Key files:

- `RouteProviderService.swift`
- `ConnectedAppsView`
- `StoneBCApp.handleDeepLink(_:)`

Garmin, Wahoo, and Ride with GPS actions require network and configured provider credentials. Tokens are stored in Keychain through `RouteProviderKeychain`; secrets must never be stored in source, docs, `config.json`, or `UserDefaults`.

## Photos, Camera, Audio, Video

Key files:

- `MediaCaptureService.swift`
- `ExpeditionCaptureView.swift`
- `RideShareSheetView.swift`

Captured expedition media is saved under the app Documents directory. Share-card image saves use Photos add-only permission.

## Security Boundaries

- Do not hardcode secrets in source or docs.
- Do not expose tokens in error messages.
- Validate user inputs at file-import, form, and network boundaries.
- Treat `config.json` as public bundle content.
- Store provider OAuth tokens only in Keychain.
