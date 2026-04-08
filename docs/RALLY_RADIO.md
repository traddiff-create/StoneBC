# Rally Radio — Technical Spec

## Overview

Push-to-talk group voice chat for bike rides using MultipeerConnectivity. No backend, no cell service required. Works peer-to-peer over WiFi Direct.

## Architecture

```
RadioView (UI)
    ↕
RadioViewModel (@Observable)
    ↕               ↕
RadioService        AudioStreamService
(MCSession)         (AVAudioEngine)
    ↕
MultipeerConnectivity
(WiFi Direct / Bluetooth)
```

## Modes

| Mode | Behavior |
|------|----------|
| Push-to-Talk | Hold button → transmit, release → stop |
| Open Mic | Toggle on → continuous transmission |

## Audio Format

- 16-bit PCM, 16kHz, mono
- 32 KB/s bandwidth
- 500ms chunks (~16KB per send)
- Voice-optimized (not high-fidelity)

## Peer Discovery

- Service type: `stonebc-radio`
- Protocol: Bonjour over WiFi Direct
- Range: ~30-100m depending on environment
- Max peers: 15
- Auto-accept all invitations
- Auto-reconnect on disconnect

## Data Protocol

Messages are tagged with a single byte prefix:
- `0x41` ("A") — Audio data payload
- `0x54` ("T") — Transmit state (1 byte: 0 or 1)

Audio sent as `.unreliable` (low latency), state sent as `.reliable` (guaranteed).

## State Machine

```
idle → connecting → connected ↔ transmitting
                        ↕
                    open mic (always transmitting)
```

## Permissions Required

| Permission | Info.plist Key | Reason |
|-----------|---------------|--------|
| Microphone | NSMicrophoneUsageDescription | Voice capture |
| Local Network | NSLocalNetworkUsageDescription | Peer discovery |
| Background Audio | UIBackgroundModes: audio | Screen-off operation |
| Bonjour | NSBonjourServices | Service advertisement |

## Files

| File | Lines | Purpose |
|------|-------|---------|
| RadioConfig.swift | 35 | Constants |
| RadioPeer.swift | 20 | Peer model |
| RadioChannel.swift | 18 | Channel model |
| RadioState.swift | 35 | State enum |
| RadioService.swift | 160 | MCSession wrapper |
| AudioStreamService.swift | 150 | AVAudioEngine wrapper |
| RadioViewModel.swift | 130 | State machine |
| RadioView.swift | 200 | Main UI |
| PTTButton.swift | 70 | Push-to-talk button |
| RadioOverlayView.swift | 40 | Floating status |
| AppState+Radio.swift | 20 | Extension |

## Testing

- UI verifiable on simulator (Radio tab renders, button responds)
- Peer discovery requires 2+ physical devices on same network
- Audio transmission requires real microphone (not available on simulator)
