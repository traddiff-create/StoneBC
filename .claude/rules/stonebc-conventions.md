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
