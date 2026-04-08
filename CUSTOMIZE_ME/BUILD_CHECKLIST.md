# Fork & Customize Checklist

## 1. Fork the Repository
- [ ] Fork on GitHub
- [ ] Clone your fork locally

## 2. Update Your Identity
- [ ] Edit `StoneBC/config.json` with your co-op name, email, location, colors
- [ ] Change bundle ID in Xcode: Signing & Capabilities > `com.yourorg.YourApp`
- [ ] Update app display name in Xcode project settings

## 3. Add Your Data
- [ ] Replace `StoneBC/bikes.json` with your inventory (see BIKES_TEMPLATE.json)
- [ ] Replace `StoneBC/posts.json` with your announcements (see POSTS_TEMPLATE.json)
- [ ] Replace `StoneBC/events.json` with your events (see EVENTS_TEMPLATE.json)
- [ ] Optionally add local cycling routes to `StoneBC/routes.json`

## 4. Customize Colors (Optional)
Edit `config.json` > `colors` with hex values:
- `brandBlue` — primary accent (tabs, buttons, links)
- `brandGreen` — success/price color
- `brandAmber` — warning/event highlight

## 5. Toggle Features (Optional)
Set any to `false` in `config.json` > `features`:
- `enableMarketplace` — hide the Bikes tab
- `enableCommunityFeed` — hide the Community tab
- `enableRoutes` — hide the Routes tab
- `enableEvents` — hide events in More tab
- `enableGallery` — hide gallery in More tab

## 6. WordPress Integration (Optional)
If your website runs WordPress with custom post types:
- Set `dataURLs.wordpressBase` to your WP REST API base URL
- Configure ACF fields for `sbc_bike` and `sbc_event` post types
- App will sync on launch, fall back to bundled JSON if offline

## 7. Build & Test
```bash
# Open in Xcode
open StoneBC.xcodeproj

# Build for simulator
xcodebuild build -scheme StoneBC -destination 'generic/platform=iOS Simulator'

# Run tests
xcodebuild test -scheme StoneBC
```

## 8. Submit to App Store
- [ ] Add your Apple Developer Team in Xcode
- [ ] Create app record in App Store Connect
- [ ] Archive and upload
- [ ] Submit for review

## Bike ID Format
The default format is `SBC-001`, `SBC-002`, etc. Change the prefix in your
`bikes.json` to match your co-op's shortName (e.g., `YBC-001`).

## Status Values
Bikes support these statuses:
- `available` — ready for a rider
- `refurbishing` — in the shop, not yet available
- `sponsored` — claimed/reserved by a sponsor
- `sold` — no longer available (hidden from list)

## Post Categories
Posts support these categories:
- `featured` — pinned/highlighted
- `news` — general updates
- `event` — event announcements
- `announcement` — important notices

## Need Help?
- Original project: https://github.com/traddiff-create/TradDiff
- Stone Bicycle Coalition: https://stonebicyclecoalition.com
- Email: stonebicyclecoalition@gmail.com
