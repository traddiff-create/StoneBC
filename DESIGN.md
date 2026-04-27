# StoneBC RIDR Design Language

> REF. STONE-RIDR-01 · v1.0 · 04 / 2026

StoneBC uses RIDR as a visual language, not as the product name. The app remains Stone Bicycle Coalition, with coalition identity, contact details, local data, routes, radio, imports, forms, and persistence still driven by the existing app architecture and `config.json`.

## North Star

StoneBC should feel like a wrist instrument mounted to handlebars: square, legible, exact, and dark-first. Every visible element must carry data, label data, frame the case, or act as a tappable control.

## Mandates

- Function shapes form. No decorative gradients, soft cards, round badges, or marketing layout.
- Read at a glance. Numerals and route metrics are high contrast; labels are small, uppercase, and monospaced.
- Square the dial. Cards, buttons, inputs, chips, image frames, peer tiles, and badges use 0pt radius. Only decorative screw heads may use 2pt radius.
- One signal per view. Forest green is the primary action/signal, lichen is reserved for the single primary live readout, rust is recording/destructive/body state, and amber is caution.

## Palette

Use `BCColors` tokens only.

- Material: `caseInk`, `caseDial`, `caseSub`, `caseGunmetal`, `caseShadow`, `caseSteelMid`, `caseBrushed`, `caseFrame`.
- Signal: `signalPrimary`, `signalDeep`, `signalLume`, `signalMoss`, `signalAlert`, `signalWarn`, `signalOK`.
- Document: `docBone`, `docPaper`.
- Compatibility aliases such as `brandBlue`, `brandGreen`, and `brandAmber` intentionally resolve to RIDR signal defaults for UI. Configured coalition colors remain available as `coalitionBlue`, `coalitionGreen`, and `coalitionAmber` for fork identity and document/export contexts.

## Typography

Bundled OFL fonts live in `StoneBC/Fonts` and are registered through `UIAppFonts`.

- `StardosStencil-Bold` for display and metric values.
- `JetBrainsMono` for data, units, badges, timers, and micro labels.
- `ArchivoNarrow` for uppercase headings and list names.
- `Archivo` for body text and notes.

Use `Font.ridrDisplayXL`, `ridrDisplayLG`, `ridrDisplayMD`, `ridrDisplaySM`, `ridrDataLG`, `ridrDataMD`, `ridrHeading`, `ridrBody`, `ridrBodySmall`, and `ridrMicro`. Existing `bc*` font aliases map to RIDR fonts.

## Components

Use the shared primitives in `BCDesignSystem.swift`:

- `RIDRCaseFrame` for square instrument borders and optional screws.
- `RIDRStatusHeader` for top status rows.
- `RIDRMetricTile` for labeled values and live cockpit readouts.
- `RIDRTickRow` for instrument ticks.
- `RIDRBadge` for live, PR, condition, category, and neutral badges.
- `RIDRButton` and `BCPrimaryAction` for primary/secondary command rows.
- `RIDRActivityCard` for logbook-style ride/feed rows.
- `RIDRIconTile` and `RIDRAvatarTile` for square icons and initials.

Compatibility components remain valid: `BCSectionHeader`, `BCHairline`, `BCIconTile`, `BCStatusPill`, `BCMetricStrip`, `FilterChip`, `DifficultyBadge`, `CategoryBadge`, `TrailConditionBadge`, `RouteStatRow`, `MetadataItem`, `bcInstrumentCard`, `bcPanelList`, and `bcNavTile`.

## Layout

- Default spacing stays on the 4pt scale: 4, 8, 16, 24, 32, 48.
- Cards and panels are dense, bordered, and square.
- Full-screen cockpit views use dark case surfaces and avoid scrolling when actively recording/navigating.
- Lists behave like bound logbooks: stacked rows separated by hairlines, not floating rounded cards.
- Minimum hit targets remain 44pt.

## Motion

- Numbers snap; do not animate counters.
- Pressed states may dim, but should not bounce.
- Recording/live indicators may pulse only when Reduce Motion allows it.
- Avoid parallax, blur transitions, springy hero motion, and decorative animation.

## Guardrails

- Do not hardcode coalition name, email, location, URLs, or app identity values.
- Do not change models, API contracts, URL schemes, route import, radio behavior, recording behavior, data persistence, or accessibility labels for style-only work.
- Do not introduce Inter, Roboto, rounded avatars, emoji, drop shadows, decorative blobs, or gradient hero art.
- Bone/document surfaces are reserved for share cards, exports, and printed summaries; the app shell is dark-first.
