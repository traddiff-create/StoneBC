# Follow My Expedition

Follow My Expedition is the offline-first expedition journal system for solo backpacking, bikepacking, and multi-day ride documentation. It captures field notes and media during the trip, then exports a shareable PDF expedition log after the trip.

## Goals

- Work fully offline for days.
- Capture useful field evidence quickly: water, food, shelter, weather, sunset, hazards, gear, wildlife, reflections, photos, audio, video, and GPS.
- Preserve battery with selectable tracking modes.
- Store all journey data locally first.
- Produce a clean PDF expedition log from local data.

## Entry Points

| UI | Path |
| --- | --- |
| More tab | `MoreView` -> `ExpeditionListView` |
| Tour guide journal tools | `TourGuideDetailView` -> `ExpeditionListView` |
| New expedition sheet | `NewExpeditionSheet` |
| Timeline/detail | `ExpeditionTimelineView` |
| Quick capture | `ExpeditionCaptureView` |
| Map | `ExpeditionMapView` |

## Core Files

| File | Responsibility |
| --- | --- |
| `ExpeditionJournal.swift` | Codable models for journals, days, entries, moments, tracking modes, and contributions |
| `ExpeditionStorage.swift` | Local Documents persistence, media layout, GPX files, iCloud drop-zone import, export directories |
| `ExpeditionListView.swift` | Browse and create journals |
| `ExpeditionTimelineView.swift` | Day picker, tracking control, field log editor, entries, autosave, PDF share |
| `ExpeditionCaptureView.swift` | Quick capture for text, photo, library photo, video, voice, moment tags, GPS |
| `MediaCaptureService.swift` | Photo/audio/video file writes |
| `ExpeditionMapView.swift` | GPX tracks and entry pins |
| `ExpeditionExporter.swift` | HTML and PDF export |
| `LocationService.swift` | Expedition-specific battery/accuracy tracking modes |

## Data Model

```swift
struct ExpeditionJournal: Codable, Identifiable {
    let id: String
    let guideId: String
    let name: String
    let leaderName: String
    var status: JournalStatus
    var trackingMode: ExpeditionTrackingMode?
    let startDate: Date
    var endDate: Date?
    var days: [JournalDay]
    var contributions: [MediaContribution]
    var coverPhotoId: String?
}
```

Each `JournalDay` stores:

- Entries
- Imported GPX filename and cached trackpoints
- Summary
- Actual miles and elevation
- Weather note
- Water note
- Food note
- Shelter note
- Sunset note

Each `JournalEntry` stores:

- Timestamp
- Optional coordinate
- Optional text
- Optional media filename and type
- Optional moment kind
- Source
- Featured flag

## Moment Kinds

| Kind | Use |
| --- | --- |
| `checkIn` | General location/status update |
| `water` | Water source, filter status, liters remaining |
| `food` | Meal, resupply, calories, ration state |
| `shelter` | Camp, bivy, wind, ground conditions |
| `sunset` | Light, final miles, photo-worthy moment |
| `weather` | Storms, wind, exposure, temperature |
| `hazard` | Trail damage, injury, dangerous crossing |
| `gear` | Failure, repair, setup lesson |
| `wildlife` | Wildlife sighting |
| `reflection` | Narrative field note |

## Tracking Modes

| Mode | Location Mode | Use |
| --- | --- | --- |
| High Detail | Best accuracy, 10 m filter | Short trips, richer track |
| Balanced | 10 m accuracy, 25 m filter | Default |
| Battery Saver | 100 m accuracy, 100 m filter | Long days |
| Check-In Only | 1 km accuracy, 500 m filter, no background | Intentional check-ins |

The selected mode is stored on the journal and applied by `ExpeditionTimelineView.startLocationTracking()`.

## Capture Flow

1. User opens a journal day.
2. `ExpeditionTimelineView` starts location tracking based on journal tracking mode.
3. User taps `+`.
4. `ExpeditionCaptureView` receives the latest coordinate.
5. User chooses a moment tag and optional text/media.
6. Media writes to `Documents/Expeditions/<journalId>/media/dayN/`.
7. The new entry is appended to the selected day.
8. Timeline schedules a debounced save through `ExpeditionStorage.save(_:)`.

## Autosave

Timeline edits call `scheduleSave()`, which debounces writes to avoid saving on every keystroke. On disappear, the timeline cancels pending debounce work and writes the current snapshot.

## PDF Export

PDF export runs from the timeline menu:

```text
Timeline menu -> Share PDF Log
```

`ExpeditionExporter.savePDF(journal:)` writes:

```text
Documents/Expeditions/<journalId>/exports/expedition-log.pdf
```

The PDF includes:

- Expedition title, date range, leader, tracking mode
- Day stats
- Water, food, shelter, sunset, and weather notes
- Day summary
- Timestamped entries
- Moment tags
- Coordinates
- Photo thumbnails when available
- Audio/video attachment labels

## HTML Export

HTML export remains available through `ExpeditionExporter.saveHTML(journal:)`. It writes `expedition.html` in the same export directory.

## Storage Layout

```text
Documents/
  Expeditions/
    <journalId>/
      journal.json
      media/
        day1/
          IMG_<timestamp>.jpg
          VID_<timestamp>.mov
          voice_<timestamp>.m4a
      gps/
        day1.gpx
      contributions/
      exports/
        expedition.html
        expedition-log.pdf
```

## Known Technical Gaps

- Imported GPX action is scaffolded in the timeline but still needs the file importer flow wired to `ExpeditionStorage.saveGPX`.
- Entry deletion/editing UI is not implemented.
- Individual media cleanup is not implemented when entries are removed.
- Live follower sharing is not implemented; the current system creates local share artifacts after capture.
- PDF map rendering is not included yet; PDF currently uses entries, logistics, and photos.

## Test Checklist

- Create an expedition from a tour guide.
- Change tracking mode and confirm it persists after relaunch.
- Add a water-only check-in with GPS.
- Add a photo note.
- Add a video note from Photos.
- Record and save a voice memo.
- Fill daily water/food/shelter/sunset/weather notes.
- Mark expedition complete and confirm `endDate` is set.
- Export PDF in airplane mode.
- Reopen the app and verify entries/media remain available.
