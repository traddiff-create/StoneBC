# ADR 001: Config-Driven Architecture for Open Source Reuse

**Date:** 2026-03-31
**Status:** Accepted

## Context

Stone Bicycle Coalition wants other bike co-ops to be able to fork and customize the app without modifying Swift code.

## Decision

All forkable aspects are driven by `config.json`:
- Organization name, tagline, contact info
- Brand colors (hex strings)
- Feature flags (enable/disable marketplace, radio, routes, etc.)
- Optional WordPress data URLs

## Consequences

- Other co-ops edit one JSON file + replace data files to customize
- No Swift code changes needed for basic customization
- Feature flags allow co-ops to disable features they don't need
- Colors are parsed from hex at runtime (slight overhead, negligible)
