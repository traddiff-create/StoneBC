# App Privacy — Nutrition Labels for App Store

## Data Collection Declaration

**Does your app collect data?** No

Stone Bicycle Coalition does not collect any user data. The app:
- Does not require login for public content
- Stores optional member-login credentials locally on the device
- Does not send user location, ride history, expedition journals, media, audio, or Health data to a StoneBC server
- Does not use analytics
- Does not use advertising identifiers
- Does not share data with third parties
- All content is bundled locally or fetched from public WordPress endpoints

The app does process sensitive data locally when the user enables specific features: location for ride tracking/navigation/expedition entries, microphone for Rally Radio and voice memos, camera/photos for expedition capture, and HealthKit for ride history. This is local processing, not collection by StoneBC.

## Privacy Nutrition Label Answers

When setting up in App Store Connect, select:

### Data Types: **None**

The app does not collect any of the following:
- [ ] Contact Info (name, email, phone, address)
- [ ] Health & Fitness
- [ ] Financial Info
- [ ] Location
- [ ] Sensitive Info
- [ ] Contacts
- [ ] User Content
- [ ] Browsing History
- [ ] Search History
- [ ] Identifiers (user ID, device ID)
- [ ] Usage Data (product interaction, advertising data)
- [ ] Diagnostics (crash data, performance data)
- [ ] Other Data

### Rally Radio Note
Rally Radio transmits audio peer-to-peer between nearby devices using MultipeerConnectivity. Audio is never recorded, stored, or sent to any server. This is real-time voice communication that exists only in transit — no audio data is persisted. This does not constitute "data collection" per Apple's definition.

### Network Requests
The optional WordPress sync fetches publicly available content (bikes, events, posts) from a WordPress REST API. No user data is sent in these requests. No cookies, tokens, or identifiers are transmitted.

Connected route provider actions for Garmin, Wahoo, and Ride with GPS are optional and user-initiated. They require provider credentials and account authorization before upload behavior is enabled. Tokens are stored in Keychain and are not included in bundled configuration.

### Route File Interop Note
Imported route and ride files are parsed locally. User-imported routes are saved in the app Documents directory, and exported GPX/TCX/FIT/KML/ZIP bundles are shared only when the user invokes the native share sheet.

### Follow My Expedition Note
Expedition journals, media, GPS coordinates, field notes, and PDF/HTML exports are written to the user's local app Documents directory. Sharing happens only through the native iOS share sheet when the user chooses to export or share.

### HealthKit Note
Ride workouts are saved to and read from the user's local HealthKit store after permission. StoneBC does not receive HealthKit data.

## How to Set in ASC

1. Go to App Store Connect → App → App Privacy
2. Click "Get Started"
3. Select "No, we do not collect data from this app"
4. Save

Or use the `/asc-privacy-nutrition-labels` skill:
```
/asc-privacy-nutrition-labels com.traddiff.StoneBC --no-data-collected
```
