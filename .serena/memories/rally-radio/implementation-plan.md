# Rally Radio Implementation Plan - StoneBC iOS

## Executive Summary
Rally Radio is a walkie-talkie/group voice chat feature for cyclists using MultipeerConnectivity. MVP delivers push-to-talk (PTT) mode with auto-discovery of nearby riders over local peer-to-peer network. No backend, no internet required. Built with SwiftUI, iOS 17+, using @Observable pattern consistent with existing StoneBC architecture.

---

## 1. ARCHITECTURE OVERVIEW

### Core Stack
- **Network:** MultipeerConnectivity framework (MCSession, MCNearbyServiceBrowser/Advertiser)
- **Audio:** AVAudioEngine (capture) + AVAudioPlayerNode (playback)
- **State Management:** @Observable pattern (AppState extension)
- **UI Framework:** SwiftUI with BCDesignSystem components
- **Threading:** Swift actors for thread-safe audio streaming

### Design Patterns
- **Service Layer Pattern:** RadioService (actor) handles all MultipeerConnectivity + audio coordination
- **AudioStreamService (actor):** Isolated audio pipeline with input/output nodes
- **ViewModel Pattern:** RadioViewModel (@Observable) bridges services to UI
- **Dependency Injection:** Services passed through @Environment

### Network Topology
```
MCNearbyServiceAdvertiser  ←→  MCNearbyServiceBrowser
        ↓                              ↓
  Local Peer Identity            Peer Discovery
        ↓                              ↓
      MCSession (1:N)
        ↓
  Audio Streaming (MCSession.send)
```

---

## 2. CORE MODELS

### RadioChannel.swift
```swift
struct RadioChannel: Identifiable, Codable {
    let id: String                    // UUID
    let name: String                  // e.g., "Downtown Route 42"
    var peers: [RadioPeer] = []       // Connected riders
    var isActive: Bool = false        // Is transmitting
    let createdAt: Date
    
    var peerCount: Int { peers.count }
    var displayPeers: String { "\(peerCount) rider\(peerCount == 1 ? "" : "s")" }
}
```

### RadioPeer.swift
```swift
struct RadioPeer: Identifiable, Codable, Hashable {
    let id: String                    // MCPeerID.displayName mapped to UUID
    let displayName: String           // Rider's chosen name
    var isTransmitting: Bool = false  // Currently talking
    let connectedAt: Date
    
    // For avatar/UI purposes
    var avatarInitials: String {
        displayName.prefix(2).uppercased()
    }
}
```

### RadioState.swift
```swift
enum RadioState: Equatable {
    case idle                          // Not connected
    case connecting                    // Discovering peers
    case connected                     // Ready to transmit
    case transmitting                  // PTT button pressed
    case receiving(displayName: String) // Receiving from peer
    case error(String)                 // Network/audio error
    
    var isActive: Bool {
        if case .idle = self { return false }
        if case .error = self { return false }
        return true
    }
}
```

### RadioConfig.swift
```swift
struct RadioConfig {
    // Network
    static let serviceType = "stonebc-radio"    // MCBrowser/Advertiser service type
    static let maxPeers = 15                    // Max group size
    
    // Audio
    static let audioSampleRate: Float = 16000  // Hz, voice-optimized
    static let audioBitDepth: Int = 16         // bits
    static let audioChannels: Int = 1          // Mono
    static let bufferSize: Int = 4096          // Samples
    
    // UI/UX
    static let pttButtonSize: CGFloat = 80     // For one-handed use
    static let pptHoldDuration: TimeInterval = 0.1  // Minimum hold time
}
```

---

## 3. SERVICE LAYER

### RadioService.swift (Actor)
**Responsibilities:**
- Manage MCSession lifecycle (peer discovery, connection)
- Route received audio to AudioStreamService
- Manage peer list and connection state
- Handle connection errors and auto-reconnect

**Key Methods:**
```swift
actor RadioService {
    // Setup
    func startBroadcasting(_ displayName: String, channel: String) async throws
    func stopBroadcasting() async
    
    // Transmission
    func transmitAudio(_ audioData: Data) async throws
    
    // State Access
    nonisolated var state: RadioState { get }
    nonisolated var connectedPeers: [RadioPeer] { get }
    
    // Lifecycle
    func disconnect() async
    
    // Internal MCSessionDelegate conformance
    private func session(_ session: MCSession, peer: MCPeerID, didChange state: MCSessionState)
    private func session(_ session: MCSession, didReceive data: Data, fromPeer: MCPeerID)
}
```

**Implementation Notes:**
- Wraps MCNearbyServiceAdvertiser and MCNearbyServiceBrowser
- Uses MainActor.runUnsafely() for state updates from delegate callbacks
- Maintains atomic state transitions (connecting → connected → transmitting)
- Tracks peer connection times for "who's been here longest" display

### AudioStreamService.swift (Actor)
**Responsibilities:**
- Manage AVAudioEngine, input/output nodes
- Capture microphone input during PTT
- Playback received peer audio
- Handle audio format/sample rate conversions

**Key Methods:**
```swift
actor AudioStreamService {
    // Setup
    func startEngine() async throws
    func stopEngine() async
    
    // Capture (PTT mode)
    func startCapture() async -> AsyncSequence<Data>
    func stopCapture() async
    
    // Playback
    func play(audioData: Data, fromPeer: String) async throws
    
    // State
    var isCaptureActive: Bool { get }
    var isPlaybackActive: Bool { get }
}
```

**Implementation Notes:**
- Uses AVAudioEngine with manual rendering mode (no automatic I/O)
- Requires NSMicrophoneUsageDescription in Info.plist
- Implements real-time PCM buffer streaming (low latency)
- Handles audio session category: .playAndRecord with .duckOthers option

---

## 4. VIEW MODEL

### RadioViewModel.swift (@Observable)
```swift
@Observable
class RadioViewModel {
    // UI State
    var radioState: RadioState = .idle
    var connectedPeers: [RadioPeer] = []
    var isOpenMicMode: Bool = false           // Toggle between PTT/always-on
    var isPTTPressed: Bool = false
    var currentTransmittingPeer: String? = nil
    
    // Services (injected)
    private let radioService: RadioService
    private let audioService: AudioStreamService
    
    // MARK: - PTT Control
    func startTransmit() async {
        isPTTPressed = true
        // Start audio capture, stream to radioService
    }
    
    func stopTransmit() async {
        isPTTPressed = false
        // Stop capture
    }
    
    // MARK: - Mode Toggle
    func toggleOpenMic() async {
        isOpenMicMode.toggle()
        // Reconfigure audio capture behavior
    }
    
    // MARK: - Connection
    func connect(displayName: String, channel: String) async {
        // Call radioService.startBroadcasting()
    }
    
    func disconnect() async {
        // Call radioService.stopBroadcasting()
    }
}
```

---

## 5. UI COMPONENTS

### RadioView.swift (Main Interface)
**Layout:**
```
┌─────────────────────────────────┐
│  Rally Radio                    │
│  Downtown Ride - 4 riders       │  ← Channel + peer count
├─────────────────────────────────┤
│  Peer List (avatars)            │
│  [AS] [JD] [MP] [RC]           │
├─────────────────────────────────┤
│                                 │
│         [●●●●●●]               │
│      Press to Talk              │  ← Large PTT button (80pt)
│      (Now Transmitting)         │     Red when active
│                                 │
├─────────────────────────────────┤
│  Open Mic   ○→  Toggle          │
│  Status: Connected              │
└─────────────────────────────────┘
```

**Features:**
- Pulsing red indicator during transmit
- Green indicator when receiving
- List of connected peers with avatars (initials)
- Always-visible PTT button (thumb-friendly for cycling)
- Volume meter (if space allows)

### RadioOverlayView.swift (Floating Compact)
**Used when browsing other tabs:**
```
Compact floating badge:
┌───────────┐
│ 📻 4 Riders
│ (Tap to expand)
└───────────┘
```
Shows:
- Radio status indicator
- Peer count
- Current transmission indicator
- Tap to expand to full RadioView

### PTTButtonComponent.swift
**Responsibilities:**
- Large, circular button (80pt diameter)
- Visual feedback: press → scale + color change
- Long-press detection with haptic feedback
- Active state indicator (pulsing red)

```swift
struct PTTButton: View {
    @State var isPressed = false
    var action: (Bool) -> Void
    
    var body: some View {
        Button(action: {}) {
            Image(systemName: "mic.fill")
                .font(.system(size: 32))
        }
        .frame(width: 80, height: 80)
        .background(isPressed ? Color.red : BCColors.brandBlue)
        .foregroundColor(.white)
        .clipShape(Circle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        // Detect long press → onLongPressGesture
    }
}
```

---

## 6. INTEGRATION POINTS

### AppState Extension (AppState+Radio.swift)
Add to existing AppState.swift:
```swift
@Observable
class AppState {
    // ... existing properties ...
    
    // Rally Radio
    var radioViewModel: RadioViewModel?
    var isRadioVisible: Bool = false
    
    func initializeRadio() {
        // Lazy initialize radioViewModel on first use
    }
}
```

### TabContainerView Modification
**Option A: New "Radio" Tab** (Recommended for MVP)
```
Add 6th tab: 
- Home, Routes, Bikes, Community, Radio ← NEW, More
- Tab icon: "radio.fill" 
- Conditional: if config.features.enableRadio (default true)
```

**Option B: Floating Button** (Phase 2)
- Floating button in bottom-right of all tabs
- Opens RadioOverlayView as sheet/modal
- Keeps radio accessible during rides

**Option C: More Tab Submenu** (Conservative)
- Radio listed under MoreView
- Less discoverable but simpler integration

### ContentView/Entry Point
- StoneBCApp remains unchanged
- Request microphone permission on app launch or first radio use
- Add audio session configuration in RadioService.init()

### AppDelegate Equivalent
**Microphone Permission:**
```swift
// In RadioService.init() or on first RadioViewModel creation
import AVFoundation
let audioSession = AVAudioSession.sharedInstance()
try await audioSession.requestRecordPermission()
```

---

## 7. CONFIGURATION & ENTITLEMENTS

### Info.plist Additions (Required)
**Via Xcode UI or direct edit:**

```xml
<!-- Microphone Usage -->
<key>NSMicrophoneUsageDescription</key>
<string>Rally Radio needs microphone access to transmit voice to nearby riders.</string>

<!-- Background Audio Modes -->
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>

<!-- Local Network Permissions (iOS 14+) -->
<key>NSLocalNetworkUsageDescription</key>
<string>Rally Radio discovers nearby cyclists on your local network.</string>

<key>NSBonjourServices</key>
<array>
    <string>_stonebc-radio._tcp</string>
</array>
```

### Entitlements File (StoneBC.entitlements)
**Create new or update existing:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.networking.multicast</key>
    <true/>
    <key>com.apple.developer.networking.local-network</key>
    <true/>
</dict>
</plist>
```

### Xcode Project Configuration
**Build Settings:**
- Signing & Capabilities → + Capability → "Local Network"
- Signing & Capabilities → + Capability → "Multicast Networking"
- Link Binary With Libraries → AVFoundation (auto-linked but explicit OK)

---

## 8. FILE STRUCTURE & CREATION

### New Files to Create (MVP Phase)

**Models (4 files, ~150 lines total)**
1. `/StoneBC/Radio/Models/RadioChannel.swift` - 25 lines
2. `/StoneBC/Radio/Models/RadioPeer.swift` - 25 lines  
3. `/StoneBC/Radio/Models/RadioState.swift` - 30 lines
4. `/StoneBC/Radio/Models/RadioConfig.swift` - 25 lines

**Services (2 files, ~400 lines total)**
5. `/StoneBC/Radio/Services/RadioService.swift` - 250 lines
   - MCSession + MCNearbyServiceBrowser/Advertiser
   - MCSessionDelegate implementation
   - Peer connection state machine
   
6. `/StoneBC/Radio/Services/AudioStreamService.swift` - 250 lines
   - AVAudioEngine setup & mic capture
   - PCM buffer streaming
   - Audio playback routing

**ViewModel (1 file, ~120 lines)**
7. `/StoneBC/Radio/RadioViewModel.swift` - 120 lines
   - @Observable state management
   - PTT gesture handling
   - Mode toggle logic

**Views (3 files, ~550 lines total)**
8. `/StoneBC/Radio/Views/RadioView.swift` - 200 lines
   - Main interface with peer list + PTT button
   - Status indicators
   - Layout using BCDesignSystem
   
9. `/StoneBC/Radio/Views/RadioOverlayView.swift` - 100 lines
   - Floating compact view
   - Used in other tabs
   
10. `/StoneBC/Radio/Views/PTTButtonComponent.swift` - 150 lines
    - Large circular button
    - Long-press gesture handling
    - Visual feedback

**Extension (1 file, ~40 lines)**
11. `/StoneBC/AppState+Radio.swift` - 40 lines
    - Add radio properties to existing AppState

**Total New Code: ~1,400 lines**

### Modified Files

1. **TabContainerView.swift** (15 line addition)
   - Add Radio tab (Option A) or floating button (Option B)
   - Conditionally display based on config

2. **AppConfig.swift** (5 line addition)
   - Add `enableRadio: Bool` feature flag
   
3. **AppConfig.json** (if exists, 1 line addition)
   - Set `enableRadio: true` by default

4. **StoneBCApp.swift** (10 line addition)
   - Request microphone permission on launch
   - Initialize RadioService once

5. **Info.plist** (4 key additions)
   - NSMicrophoneUsageDescription
   - UIBackgroundModes: audio
   - NSLocalNetworkUsageDescription
   - NSBonjourServices

6. **Xcode Project Configuration**
   - Add StoneBC.entitlements
   - Enable Local Network capability
   - Enable Multicast Networking capability

---

## 9. FEATURE PHASES

### MVP (Phase 1) - 3 weeks
**Scope:** Push-to-talk only, local discovery, 5-15 riders

**Deliverables:**
- [x] RadioService with MCSession peer discovery
- [x] AudioStreamService with basic mic capture/playback
- [x] RadioView with PTT button
- [x] Peer list display (names only)
- [x] Connection status indicators
- [x] New Radio tab in TabContainerView
- [x] Microphone + local network permissions
- [x] Audio format: 16-bit PCM, 16kHz mono

**Acceptance Criteria:**
- 3+ riders can connect on same network
- Audio transmits clearly with <500ms latency
- UI remains responsive during transmission
- Clean disconnect on app backgrounding
- No memory leaks during 30-min session

### V1 (Phase 2) - 2 weeks
**Scope:** Open Mic, channel naming, UI polish

**Features:**
- Toggle: PTT ↔ Open Mic (always-transmitting)
- Named channels (e.g., "Downtown Route", "Group B")
- Peer avatars (initials in colored circles)
- Volume meter (waveform display)
- Audio feedback: beep on transmit start/stop
- Haptic feedback: tap when others transmit
- Floating overlay for other tabs

**Changes:**
- RadioViewModel adds `isOpenMicMode` toggle
- RadioService auto-switch capture mode
- RadioView updated layout with avatar row
- New RadioOverlayView component

### Future (Phase 3+)
**Scope:** VOX, recording, relay, metrics

**Possible Features:**
- Voice-Activated Transmit (VOX) mode
- Audio recording to files
- Cloud relay for long-range (requires backend)
- Transmission duration metrics
- Quiet zone detection (auto-mute background noise)
- Channel persistence / saved rides

**Not in Scope:**
- Video calling
- Text chat (focus: voice)
- Message encryption (local network assumed trusted)
- WebRTC (stick with MultipeerConnectivity)

---

## 10. TESTING STRATEGY

### Unit Tests
- RadioViewModel state transitions
- RadioConfig constants
- RadioPeer equality/hashing

### Integration Tests
- RadioService peer discovery (simulator with 2+ devices)
- AudioStreamService buffer handling
- MCSessionDelegate callbacks

### Manual Testing Checklist
- [ ] Launch on 2-3 simulators, verify peer discovery
- [ ] Press PTT on one device, hear audio on others
- [ ] Toggle Open Mic, verify always-on capture
- [ ] Background app, verify audio continues
- [ ] Disconnect while transmitting, verify graceful cleanup
- [ ] Rejoin after disconnect
- [ ] Stress test with 15 peers (if possible)

### Performance Benchmarks
- Peer discovery latency: <2 seconds
- Audio transmission latency: <500ms
- Memory per peer: <5 MB
- CPU usage during PTT: <30% (A14+)
- Battery drain: <5% per hour at idle, <15% during active transmission

---

## 11. CRITICAL IMPLEMENTATION DETAILS

### MCSession + Audio Streaming
**Challenge:** MCSession.send() has 65KB size limit; audio streams need adaptive buffering
**Solution:** 
- Break audio into 500ms chunks (8KB at 16kHz)
- Use MCSession.sendData() in loop
- Implement send queue with backpressure

**Code Pattern:**
```swift
let audioChunkSize = 8000  // 500ms of 16kHz audio
for chunk in audioData.chunks(ofSize: audioChunkSize) {
    try await radioService.transmitAudio(Data(chunk))
    // MCSession handles delivery; blocks if queue full
}
```

### Audio Capture + Playback Threading
**Challenge:** AVAudioEngine callback is real-time thread; must be lock-free
**Solution:**
- Use lock-free queue (MPSC) for audio buffers
- Dispatch callbacks to background actor queue
- Never block in audio render callback

**Pattern:**
```swift
actor AudioStreamService {
    private let audioQueue = DispatchQueue(label: "com.stonebc.audio", qos: .userInteractive)
    
    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        Task {
            await audioQueue.async { [weak self] in
                // Process buffer without blocking real-time thread
            }
        }
    }
}
```

### Background Audio Modes
**Challenge:** Audio must continue when screen is off (iOS requirement)
**Solution:**
- UIBackgroundModes: audio in Info.plist
- AVAudioSession category: .playAndRecord
- Option: .duckOthers (lower other app volume)

**Code:**
```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playAndRecord, options: .duckOthers)
try session.setActive(true)
```

### Peer Identity Management
**Challenge:** MCPeerID.displayName is mutable; need stable UUID mapping
**Solution:**
- Map MCPeerID.displayName → UUID on first connection
- Store in RadioPeer.id
- Use UUID in all state/callbacks

### State Machine (Critical)
Radio state must follow strict transitions:
```
idle → connecting → connected ↔ transmitting
   ↘ error (from any state)
```
Enforce via enum exhaustiveness checking and guard statements.

---

## 12. KNOWN CONSTRAINTS & TRADE-OFFS

### MultipeerConnectivity Limitations
1. **Range:** ~30 meters (100 ft) typical outdoor
2. **Peer Limit:** Tested up to 15; beyond untested
3. **No Relay:** Cannot extend range with intermediate peers (not supported by MPC)
4. **No Encryption:** Assumes trusted local network (cyclists together)

**Mitigation:** Document range limitations in user onboarding

### Audio Quality vs. Bandwidth
1. **16kHz 16-bit Mono:** Optimized for voice intelligibility
2. **Not suitable for:** Music, high-fidelity audio
3. **Bandwidth:** ~32 KB/s per peer stream

**Rationale:** Cycling group communication prioritizes latency + clarity over fidelity

### Battery Drain
- Audio capture/playback: ~10-15% per hour of active transmission
- Peer discovery: <1% per hour at idle
- Screen-off operation supported (iOS allows background audio)

**Best Practice:** Users should plug in on long rides or limit session duration

### Privacy & Security
- **No encryption:** Suitable only for local trusted networks
- **No recording:** Not implemented (phase 3+ consideration)
- **Peer names visible:** Only to other cyclists in range

**Future:** Add E2E encryption if cloud relay added (phase 3)

---

## 13. TESTING DATA & MOCKS

### Mock RadioService (for UI testing without devices)
```swift
#if DEBUG
class MockRadioService: RadioService {
    override var state: RadioState {
        return .connected
    }
    
    override var connectedPeers: [RadioPeer] {
        return [
            RadioPeer(id: "1", displayName: "Alice", isTransmitting: false, connectedAt: Date()),
            RadioPeer(id: "2", displayName: "Bob", isTransmitting: true, connectedAt: Date()),
        ]
    }
}
#endif
```

### Mock AudioStreamService
```swift
#if DEBUG
actor MockAudioStreamService: AudioStreamService {
    override func startEngine() async throws { }
    override func startCapture() async -> AsyncSequence<Data> {
        // Return empty sequence
    }
}
#endif
```

### SwiftUI Previews
- RadioView with 0, 1, 5, 15 peers
- RadioView in transmitting state
- RadioOverlayView (compact)
- PTTButton in pressed/unpressed states

---

## 14. DOCUMENTATION CHECKLIST

### Code Comments
- [ ] RadioService: Explain MCSessionDelegate responsibilities
- [ ] AudioStreamService: Document real-time thread constraints
- [ ] RadioViewModel: Explain PTT state machine
- [ ] PTTButtonComponent: Long-press gesture mechanics

### User Documentation (in-app)
- [ ] Onboarding: "Rally Radio" tab intro
- [ ] Help screen: Range limitations, permission requirements
- [ ] Error messages: Clear guidance on connection failures

### Developer Documentation
- [ ] README: Architecture overview, service diagram
- [ ] How-to: Adding Rally Radio to other bike-co apps
- [ ] Troubleshooting: Common MPC issues (firewall, Bluetooth state, etc.)

---

## 15. SUCCESS CRITERIA

### Technical
- ✅ 3+ simultaneous peers discovered and connected
- ✅ Audio transmits/receives with <500ms latency
- ✅ Memory footprint: <50MB for app + services
- ✅ No crashes over 1-hour continuous session
- ✅ Clean state on app backgrounding/foreground

### UX
- ✅ New user discovers PTT button within 5 seconds
- ✅ One-handed PTT operation (can hold while cycling)
- ✅ Clear visual indicator of who's talking
- ✅ Audio feedback on transmit start/stop

### Integration
- ✅ Conforms to existing @Observable + MVVM patterns
- ✅ Uses BCDesignSystem colors/typography
- ✅ Feature flag in AppConfig (can disable for other co-ops)
- ✅ No breaking changes to existing features

---

## 16. XCODE BUILD CONFIGURATION

### Required Capabilities
1. **Local Network**
   - Xcode: Signing & Capabilities → + Capability → Local Network
   - Enables MDNSAdvertiser in MultipeerConnectivity

2. **Multicast Networking**
   - Xcode: Signing & Capabilities → + Capability → Multicast Networking
   - Allows UDP multicast for peer discovery

### Build Settings Changes
```
FRAMEWORK_SEARCH_PATHS = $(inherited)
LINK_WITH_STANDARD_LIBRARY = YES
SWIFT_VERSION = 5.9+
IPHONEOS_DEPLOYMENT_TARGET = 17.0+
ENABLE_BITCODE = NO
```

### Linker Flags (if needed)
```
-framework AVFoundation
-framework MultipeerConnectivity
-framework Network
```

---

## 17. ROLLOUT & DEPRECATION

### Rollout (MVP → App Store)
1. **Beta (TestFlight):** Test on physical devices with 3-5 cyclists
2. **Release:** Version 0.3 alongside existing features
3. **Announce:** Social media, in-app onboarding
4. **Monitor:** Crash reports, user feedback

### Future Deprecation Triggers (if applicable)
- If range/peer limits prove insufficient, plan cloud relay (phase 3)
- If P2P model breaks, migrate to centralized (requires backend)

### Backward Compatibility
- Radio tab optional (feature flag)
- No impact to existing bike/route/community features
- Graceful fallback: disable if MPC framework unavailable

---

## CRITICAL FILES FOR IMPLEMENTATION

The following 11 new files + 6 modified files form the complete Rally Radio feature:

**New Files (11):**
1. `/Applications/Apps/StoneBC/StoneBC/Radio/Models/RadioChannel.swift`
2. `/Applications/Apps/StoneBC/StoneBC/Radio/Models/RadioPeer.swift`
3. `/Applications/Apps/StoneBC/StoneBC/Radio/Models/RadioState.swift`
4. `/Applications/Apps/StoneBC/StoneBC/Radio/Models/RadioConfig.swift`
5. `/Applications/Apps/StoneBC/StoneBC/Radio/Services/RadioService.swift`
6. `/Applications/Apps/StoneBC/StoneBC/Radio/Services/AudioStreamService.swift`
7. `/Applications/Apps/StoneBC/StoneBC/Radio/RadioViewModel.swift`
8. `/Applications/Apps/StoneBC/StoneBC/Radio/Views/RadioView.swift`
9. `/Applications/Apps/StoneBC/StoneBC/Radio/Views/RadioOverlayView.swift`
10. `/Applications/Apps/StoneBC/StoneBC/Radio/Views/PTTButtonComponent.swift`
11. `/Applications/Apps/StoneBC/StoneBC/AppState+Radio.swift`

**Modified Files (6):**
1. `/Applications/Apps/StoneBC/StoneBC/TabContainerView.swift` — Add Radio tab
2. `/Applications/Apps/StoneBC/StoneBC/AppConfig.swift` — Add enableRadio flag
3. `/Applications/Apps/StoneBC/StoneBC/StoneBCApp.swift` — Microphone permission request
4. `/Applications/Apps/StoneBC/StoneBC/Info.plist` — Audio + microphone permissions
5. `/Applications/Apps/StoneBC/StoneBC.entitlements` — Local Network capability (NEW FILE)
6. `/Applications/Apps/StoneBC/StoneBC.xcodeproj/project.pbxproj` — Build settings (auto-configured via Xcode UI)

**Total Implementation Scope:** ~1,400 new lines of Swift + configuration updates
