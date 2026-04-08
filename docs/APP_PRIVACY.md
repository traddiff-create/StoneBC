# App Privacy — Nutrition Labels for App Store

## Data Collection Declaration

**Does your app collect data?** No

Stone Bicycle Coalition does not collect any user data. The app:
- Has no user accounts or login
- Does not track location
- Does not use analytics
- Does not use advertising identifiers
- Does not share data with third parties
- All content is bundled locally or fetched from public WordPress endpoints

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

## How to Set in ASC

1. Go to App Store Connect → App → App Privacy
2. Click "Get Started"
3. Select "No, we do not collect data from this app"
4. Save

Or use the `/asc-privacy-nutrition-labels` skill:
```
/asc-privacy-nutrition-labels com.traddiff.StoneBC --no-data-collected
```
