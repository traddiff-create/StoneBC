# StoneBC — Stone Bicycle Coalition App Architecture

## Overview
Cycling community app for Rapid City, SD. Bike inventory, routes, peer-to-peer voice chat.
Bundle: com.traddiff.StoneBC | ASC ID: 6761507730
LLC: DL308353 | EIN: 39-4226443 | Xero org: !g-vRq

## Tech Stack
- Swift 5 / SwiftUI / MapKit / CoreLocation
- MultipeerConnectivity (Rally Radio voice chat — no backend)
- Config-driven: config.json controls name, colors, features, data URLs
- Optional WordPress headless CMS integration (blocked on WP Business upgrade)

## Architecture
- MVVM + @Observable AppState (single source of truth)
- Config-driven: all app behavior configurable via config.json
- BCDesignSystem components (FilterChip, badges, PressableButtonStyle)
- 5-tab layout: Home, Routes, Bikes (The Quarry), Radio (Rally Radio), More

## Key Features
- 42 Black Hills cycling routes (GPX → JSON via Python)
- The Quarry: bike inventory/sponsorship system (bikes.json)
- Rally Radio: peer-to-peer voice chat (MultipeerConnectivity, no server)
- Lewis & Clark historical routes (6-phase overhaul planned)
- $1,000 AEP grant awarded — Pedal for Empathy May 2

## Build
- xcodebuild build -scheme StoneBC
- /test-stonebc for full QA (build + 25 Blitz tests)
- git add -f required (parent gitignore blocks *)

## Current Version: 0.5 (Prepare for Submission)
