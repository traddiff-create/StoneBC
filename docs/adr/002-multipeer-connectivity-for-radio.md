# ADR 002: MultipeerConnectivity for Rally Radio

**Date:** 2026-04-01
**Status:** Accepted

## Context

Riders need hands-free voice communication during group rides. Many Black Hills routes have no cell service.

## Options Considered

1. **MultipeerConnectivity** — P2P, no backend, works offline
2. **WebRTC + signaling server** — works anywhere, requires backend
3. **Push to Talk framework (iOS 16+)** — native UI, requires backend
4. **SharePlay / GroupActivities** — requires FaceTime call, not standalone

## Decision

MultipeerConnectivity. It requires zero backend infrastructure, works without cell service, and handles 5-15 peers adequately.

## Trade-offs

- (+) No backend, no cost, no cell service needed
- (+) Auto-discovery via Bonjour
- (-) Limited range (~30-100m)
- (-) No relay through intermediate peers
- (-) Audio requires real devices (not testable on simulator)

## Consequences

- Rally Radio works out of the box for group rides
- Cannot support remote riders (future: add WebRTC option)
- Feature-flagged so co-ops can disable if unwanted
