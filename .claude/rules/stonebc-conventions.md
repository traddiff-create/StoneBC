# StoneBC Project Conventions

## App Structure
- 5-tab layout: Home, Routes, Bikes, Radio, More
- All data loads through AppState (@Observable)
- Config-driven via config.json — never hardcode coalition name, email, or colors
- Radio/ subdirectory for all Rally Radio files

## Data Management
- Owner manages content — no user-generated content
- Bikes: edit inventory/bikes.json → copy to StoneBC/bikes.json
- Posts: edit StoneBC/posts.json directly
- Events: edit StoneBC/events.json directly
- Routes: GPX → process_routes.py → routes.json

## Bike Wait List ↔ Inventory (always linked)
When touching `inventory/` or bike status, always check:
- `inventory/waitlist.json` — people waiting for a bike (source of truth)
- `inventory/WAITLIST.md` — human-readable table + process
- `Scripts/match_waitlist.py` — run after flipping any bike to `status: "ready"`; drafts notification emails into `drafts/notify-WL-XXX-SBC-YYY.md`

Rules:
- **Before accepting/sourcing a donation:** glance at WAITLIST.md to know what sizes/types are actively needed. Prefer bikes that fit waiting applicants.
- **When flipping a bike to `ready`:** run the matcher (`python3 Scripts/match_waitlist.py` from StoneBC root). Never skip this step.
- **After sending a notify email:** update the applicant in `waitlist.json` — append bike ID to `matched_bike_ids`, flip `status` to `matched`, add a history entry.
- **Send channel:** replies + notifications go from `info@stonebicyclecoalition.com` via Mac Mail (Hover mailbox).

## UI Patterns
- Use BCDesignSystem components (FilterChip, badges, PressableButtonStyle)
- Section headers: 10pt semibold, tracking 1, secondary color
- Cards: BCSpacing.md padding, cardBackground, 12pt cornerRadius
- Lists: LazyVStack with BCSpacing.md horizontal padding

## Git
- Always `git add -f` (parent gitignore blocks *)
- Conventional commits (feat/fix/docs/refactor)

## Testing
- Use /test-stonebc for full QA (build + 25 Blitz tests)
- Tab bar y-coordinate: ~900 on Pro Max, ~820 on Pro
