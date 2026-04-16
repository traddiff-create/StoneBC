# Build

Build the StoneBC iOS app for the simulator.

```bash
cd /Applications/Apps/StoneBC && xcodebuild -project StoneBC.xcodeproj -scheme StoneBC -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -20
```
