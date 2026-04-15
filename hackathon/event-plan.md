# Ignite RC Hackathon — Event Plan

**Event:** Ignite Rapid City Hackathon
**Dates:** April 24-26, 2026
**Location:** DLAB, 18 E Main St, Rapid City, SD
**Project:** Community Moments (StoneBC app)
**Rory Stone** — Traditionally Different Technology / Stone Bicycle Coalition

---

## Pre-Event (Apr 15-23)

### This Week (Apr 15-18)
- [ ] Practice 2-min pitch out loud — no slides, just talk + show the phone
- [ ] Fresh build of StoneBC on iPhone 17 Pro (`/pipeline` or manual build)
- [ ] Verify TestFlight build is current — get public link for QR code
- [ ] Generate QR code for TestFlight link → add to one-pager
- [ ] Print 15 copies of one-pager (color if possible, B&W works)
- [ ] Review pitch-deck.html on projector if possible (test at DLAB?)

### Day Before (Apr 23)
- [ ] Coffee with Eric Traub at 10 AM (separate — Bridgewater partnership)
- [ ] Charge laptop, iPhone 17 Pro, Apple Watch
- [ ] Pack: laptop, charger, iPhone, business cards, printed one-pagers
- [ ] Review app — make sure all 56 routes load, community feed shows, Rally Radio works
- [ ] Have pitch-deck.html bookmarked and tested in Chrome fullscreen

---

## Day 1 — Friday, April 24

### 10:00 AM — Vibecoding 101 (OpenAI)
**Goal:** Learn the landscape, understand what tools others will use
- Attend and participate
- Take notes on OpenAI Codex capabilities/limitations
- Identify how Claude Code is different/better for your use case
- Network — introduce yourself to organizers, other founders

### 12:00-5:00 PM — Free Time
**Goal:** Final prep
- Last-minute app polish if needed
- Run through pitch one more time
- Eat lunch (meals start at dinner)

### 5:00 PM — Check-in + Dinner
**Goal:** Network, scope the room
- Register, get badge/materials
- Eat, talk to people
- Identify potential teammates: designers, prompt engineers, cyclists
- Hand out one-pagers casually — "Here's what I'm pitching tonight"

### 6:00 PM — Idea Pitches
**Goal:** Get selected in the top 8. Attract strong teammates.
- **YOUR PITCH (2 minutes):**
  - Open with problem (30 sec)
  - Show the live app on your phone — hand it to someone in front row (30 sec)
  - Explain weekend build plan: AI route advisor + weather safety (30 sec)
  - Close with the ask: "I need teammates who want to build something real" (30 sec)
- **Key move:** Don't use the slide deck for the pitch. Hold up your phone. Walk to judges. Let them tap through the app. The deck is backup if they want a projector.

### 6:00-9:00 PM — Team Formation + Onboarding
**Goal:** Meet your assigned team, set expectations
- Organizers select top 8 and form teams
- Once your team is assigned:
  - Show them the app in TestFlight — have them install it
  - Walk through the codebase briefly (show Claude Code workflow)
  - Assign Saturday tasks based on skills:
    - **Designer:** UI mockups for AI route advisor screen
    - **Prompt engineer / technical:** Help write Claude API integration prompts
    - **Content / tester:** Curate route descriptions, test flows, gather real ride data
    - **Storyteller:** Start planning the Sunday demo narrative
  - Set up comms (group text, Discord, whatever the team prefers)
- **Leave by 9 PM** — rest up for build day

---

## Day 2 — Saturday, April 25

### Full Build Day

**Morning (8 AM - 12 PM) — Feature 1: AI Route Advisor**
- [ ] Wire up Claude API (or OpenAI Codex if team prefers) for route recommendations
- [ ] Build conversational UI: text input → route card output
- [ ] Connect to routes.json — AI picks from real 56 routes
- [ ] Test with various prompts: "easy ride near downtown", "hard gravel route", "family friendly"
- Teammates: UI polish, prompt testing, edge cases

**Lunch Break (12-1 PM)** — Provided by event

**Afternoon (1-5 PM) — Feature 2: Ride Safety & Weather**
- [ ] Integrate weather API (WeatherKit or Open-Meteo — Open-Meteo is free, no API key)
- [ ] Add weather overlay to route detail view (temp, wind, precipitation)
- [ ] Build "Good day to ride?" assessment combining weather + route difficulty
- [ ] Display safety tips (hydration, wind warnings, storm alerts)
- Teammates: Map overlay design, weather data formatting, testing

**Evening (5-9 PM) — Polish & Demo Prep**
- [ ] Bug fixes from afternoon testing
- [ ] Polish UI transitions and loading states
- [ ] Start building Sunday demo script
- [ ] Practice the 3-5 minute final presentation with team
- [ ] Take screenshots/screen recordings as backup

---

## Day 3 — Sunday, April 26

### Morning (8 AM - 12 PM) — Final Polish
- [ ] Fix any remaining bugs
- [ ] Final UI polish pass
- [ ] Test full demo flow end-to-end on iPhone 17 Pro
- [ ] Prepare demo script — assign speaking parts to team
- [ ] Practice full presentation 2-3 times with team

### 12:00-2:00 PM — Last Prep
- [ ] Lunch (provided)
- [ ] Final run-through of demo
- [ ] Ensure iPhone is charged, app is fresh build
- [ ] Have backup: simulator on laptop, screenshots, screen recording

### 2:00-3:30 PM — Final Pitches & Judging
**Goal:** Score 8+ in all 4 categories

**Demo Script (3-5 minutes):**

1. **Problem + Solution** (30 sec) — Brief recap, don't repeat Friday pitch
2. **Live App Demo** (90 sec) — Walk judges through existing features on iPhone
   - Open routes, show map with elevation
   - Show community feed
   - Quick Rally Radio demo (teammate holds second phone?)
3. **Weekend Build Demo** (90 sec) — Show what you built THIS WEEKEND
   - AI Route Advisor: type "easy ride near downtown" → show recommendation
   - Weather overlay: show conditions on a route map
   - "Good day to ride?" assessment
4. **Impact & Vision** (30 sec) — AEP grant, Pedal for Empathy May 2, open-source for all bike co-ops
5. **Team Reflection** (30 sec) — Each teammate says one thing they learned/built

**Scoring targets:**
| Category | Target | How |
|----------|--------|-----|
| Technical execution (1-10) | 9-10 | Live demo on device, production code, no crashes |
| Problem-solution fit (1-10) | 9-10 | Real nonprofit, real grant, real event May 2 |
| Innovation & feasibility (1-10) | 8-9 | AI features are novel for cycling, built in 48 hrs |
| Demo & presentation (1-10) | 8-9 | Polished, team involvement, story arc |

### 3:30-4:00 PM — Judges Deliberation
- Breathe. Talk to other teams. Network.

### 4:00-5:00 PM — Winners Announced
- If you win: thank team, thank organizers, mention Pedal for Empathy May 2
- Win or lose: collect contact info from teammates and other founders
- Follow up with organizers about Wildfire Labs accelerator

---

## Post-Event (Apr 27+)

### Regardless of Outcome
- [ ] Send thank-you email to teammates
- [ ] Post about the hackathon on StoneBC Instagram
- [ ] Merge any hackathon code into main branch
- [ ] If AI route advisor works well, ship it in next TestFlight build
- [ ] Follow up with Wildfire Labs / Elevate RC contacts
- [ ] Update MASTERPROJ with hackathon results

### If Selected for Top 8 but Didn't Win
- Still have new features, new contacts, and event visibility
- Use the experience in Trad Diff marketing ("Hackathon participant, built X in 48 hours")

### If Won
- $1,000 prize → StoneBC operations or Pedal for Empathy event fund
- PR opportunity: "Local startup wins Ignite RC Hackathon"
- Elevate RC / Wildfire Labs connection for future accelerator

---

## Emergency Fallbacks

| Problem | Fallback |
|---------|----------|
| App crashes during demo | Pre-recorded screen recording on laptop |
| No WiFi for API calls | Pre-cache AI responses, show cached results |
| Team no-shows on Saturday | You + Claude Code can build both features solo |
| Pitch not selected in top 8 | Offer to join another team, network, learn |
| Weather API down | Hardcode sample weather data for demo |
