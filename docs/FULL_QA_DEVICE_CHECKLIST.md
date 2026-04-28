# StoneBC Full QA and Device Checklist

## Simulator Automation

Run the full collect-first automation pass from the repository root:

```bash
Scripts/run_full_qa.sh
```

The runner writes logs, screenshots, and `summary.md` under `qa-results/`. It keeps running after failures so the first pass captures the full failure set. Use this faster variant while iterating on fixes:

```bash
Scripts/run_full_qa.sh --skip-long-ride
```

After collecting failures, patch them in one batch, rerun targeted failing commands, then rerun `Scripts/run_full_qa.sh`.

## Physical Device Pass

Target hardware:

- iPhone 17 Pro
- Paired Apple Watch Ultra

Before testing:

- Back up any real ride, expedition, or journal data that should survive reinstall/reset.
- Install a Debug build of `StoneBC` and the companion watch app.
- Keep the Mac attached for Xcode device logs.

Manual flows:

- First launch and onboarding.
- One-button free ride recording.
- 15-minute real activity or stationary outdoor ride with location available.
- Stop and save, then stop and discard on a separate ride.
- Watch pulse display while the iPhone ride is active.
- Watch `I'm OK` check-in.
- Watch dictated adventure note into the active expedition journal.
- Watch SOS handoff into the iPhone emergency flow.
- Lock/background iPhone during recording, then reopen and verify the ride is still coherent.

Pass criteria:

- No app crashes or watchdog terminations.
- Ride distance, elapsed time, save/discard, exports, and history screens remain coherent.
- Watch app never asks for GPS, HealthKit, workout recording, or extended runtime permissions.
- Watch stale/no-phone state is clear when the phone app is stopped or unreachable.
- Device logs do not show repeated WatchConnectivity, location, HealthKit, or file persistence failures.
