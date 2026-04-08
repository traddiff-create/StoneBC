# Design System — BCDesignSystem.swift

## Colors

| Token | Value | Usage |
|-------|-------|-------|
| `BCColors.brandBlue` | #2563eb | Primary accent, buttons, links, tab tint |
| `BCColors.brandGreen` | #059669 | Success, prices, features |
| `BCColors.brandAmber` | #f59e0b | Warnings, event highlights |
| `BCColors.background` | systemBackground | Page backgrounds |
| `BCColors.cardBackground` | secondarySystemBackground | Card surfaces |
| `BCColors.primaryText` | .primary | Headlines, body |
| `BCColors.secondaryText` | .secondary | Subtitles, metadata |
| `BCColors.tertiaryText` | tertiaryLabel | Hints, timestamps |
| `BCColors.divider` | separator | Section dividers |
| `BCColors.overlayLight/Medium/Strong` | primary opacity 5/10/15% | Subtle backgrounds |

## Spacing

| Token | Value |
|-------|-------|
| `BCSpacing.xs` | 4pt |
| `BCSpacing.sm` | 8pt |
| `BCSpacing.md` | 16pt |
| `BCSpacing.lg` | 24pt |
| `BCSpacing.xl` | 32pt |
| `BCSpacing.xxl` | 48pt |

## Typography

| Token | Size / Weight |
|-------|--------------|
| `.bcHero` | 28 / light |
| `.bcSectionTitle` | 11 / medium |
| `.bcPrimaryText` | 15 / medium |
| `.bcSecondaryText` | 12 / regular |
| `.bcCaption` | 11 / medium monospaced |
| `.bcMicro` | 9 / medium |
| `.bcLabel` | 10 / medium |

## Reusable Components

### FilterChip
Horizontal scrollable filter button with optional count badge.
```swift
FilterChip(title: "Hybrid", count: 2, isSelected: true) { }
```

### DifficultyBadge / CategoryBadge
Colored capsule badges for route difficulty and category.
```swift
DifficultyBadge(difficulty: "moderate")
CategoryBadge(category: "gravel")
```

### StatusBadge / ConditionBadge
Bike status and condition indicators.
```swift
StatusBadge(status: .available)
ConditionBadge(condition: .good)
```

### RouteStatRow / MetadataItem
Icon + label + value rows for specs and metadata.
```swift
RouteStatRow(icon: "arrow.left.arrow.right", label: "Distance", value: "42.5 miles")
```

### PressableButtonStyle
Scale-on-press animation for all tappable elements.
```swift
Button("Tap me") { }.buttonStyle(PressableButtonStyle())
```

## Section Header Pattern

Used consistently across all views:
```swift
Text("SECTION TITLE")
    .font(.system(size: 10, weight: .semibold))
    .tracking(1)
    .foregroundColor(.secondary)
```

## Card Pattern

Standard card layout used in bikes, posts, events:
```swift
content
    .padding(BCSpacing.md)
    .background(BCColors.cardBackground)
    .clipShape(RoundedRectangle(cornerRadius: 12))
```
