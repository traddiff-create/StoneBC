# How to Use the Inventory Dashboard

**Primary user:** Caden (mechanic)
**Backup / admin:** Rory

---

## 1. Access

**URL (primary):** https://inventory.stonebicyclecoalition.com
**URL (fallback, works immediately):** https://stonebc-inventory.netlify.app

**Login (HTTP Basic Auth popup):**
- Username: `caden`
- Password: `QuarryBike2026`

> **Rotate the password:** run `netlify env:set SITE_PASSWORD <new>` from `/Applications/Apps/StoneBC/inventory/`. Tell Caden the new one in person or via Signal — don't email it.

**DNS record (one-time, add at Hover):**

| Type  | Hostname    | Target                          | TTL |
|-------|-------------|----------------------------------|-----|
| CNAME | `inventory` | `stonebc-inventory.netlify.app` | 1hr |

After the CNAME is added, Netlify auto-provisions SSL in ~15–60 min.

---

## 2. What the Dashboard Shows

### Top banner: 🔔 Wait List
- Shows the count of active applicants waiting for a bike.
- Click to expand — shows who's waiting, their contact info, what size/type they need.
- **Priority riders** (e.g. kids, urgent cases) are highlighted in amber.
- Read-only from the dashboard. Edits happen in `inventory/waitlist.json` in the repo.

### Main area: The Quarry POS
- Left column: list of bikes.
- Right column: form to edit the selected bike — specs, donor, refurb work, costs.
- Buttons top-right:
  - **Export bikes.json** — download the current inventory as JSON (send to Rory for commit).
  - **Export INTAKE.md** — download a printable intake log.
  - **Reset** — wipe ALL bikes in this browser (won't affect anyone else — Phase 1 is per-device).

> ⚠️ **Phase 1 limitation:** the bike list lives in your browser's localStorage. If Caden and Rory both edit, they see different lists. Phase 2 (shared backend via Netlify Functions + Blobs) comes next session.

---

## 3. Workflows

### When a bike comes in (donation or purchase)

1. Open the dashboard.
2. **First glance up at the Wait List** — if someone's waiting for the exact type/size, note it. Prioritize refurb.
3. Click `+` to add a new bike. It auto-assigns the next `SBC-XXX` ID.
4. Fill in:
   - Acquisition: date, source, cost, donor name
   - Details: model, type, frame size, wheel size, color, condition
   - Status: set to `refurbishing` while it's on the stand
5. Log refurb items as you go — each row captures date, item, cost, hours. Totals auto-calculate.
6. When done, flip **Status** to `ready`.

### When a bike is ready → notify the wait list

1. Flip the bike's Status to `ready` in the dashboard.
2. Click **Export bikes.json** — download it.
3. Send it to Rory (email / Signal / drop in iCloud).
4. Rory commits it to the repo, then runs:
   ```
   cd /Applications/Apps/StoneBC
   python3 Scripts/match_waitlist.py
   ```
5. Matcher generates a draft notification email in `drafts/notify-WL-XXX-SBC-YYY.md`.
6. Rory reviews, sends from `info@stonebicyclecoalition.com` via Mac Mail.
7. When the applicant comes in to pick up the bike:
   - Flip bike Status to `sponsored` (payment received) or `sold`.
   - Update the applicant in `waitlist.json`: append the bike ID to `matched_bike_ids`, flip `status` to `fulfilled`.

### When someone new asks for a bike

1. Caden: if someone walks in or messages the shop, collect their info (name, phone, email, height, bike type + size they need, priority notes) and pass it to Rory.
2. Rory: add them to `inventory/waitlist.json` using the next ID (`WL-YYYY-NNN`), draft a reply in `drafts/sbc-replies-YYYY-MM-DD.md`, send from `info@stonebicyclecoalition.com`.
3. Next dashboard reload shows them in the wait list panel.

---

## 4. Contact

- **Dashboard breaks / can't log in:** text Rory.
- **Bike question / applicant match judgment call:** text Rory.
- **Donation coming in while Rory's out:** accept it, log it as `refurbishing`, add notes — Rory will review later.

---

## 5. What's Coming Next (Phase 2)

- **Shared backend:** Netlify Functions + Blobs — Caden and Rory will see the same bike list in real time. No more export/commit dance.
- **Magic-link login:** no more shared password. Caden gets a one-click email link; Rory has admin.
- **Photo upload:** attach bike photos directly from the dashboard.
- **Applicant add form:** Caden can log new walk-in applicants without waiting for Rory.

Rough timeline: ~half-day of work, separate session — flag Rory when you want to ship it.

---

## 6. Files (for reference)

| What | Where |
|------|-------|
| Dashboard source | `/Applications/Apps/StoneBC/inventory/pos.html` |
| Wait list data | `/Applications/Apps/StoneBC/inventory/waitlist.json` |
| Wait list process doc | `/Applications/Apps/StoneBC/inventory/WAITLIST.md` |
| Bike inventory data | `/Applications/Apps/StoneBC/inventory/bikes.json` |
| Intake log | `/Applications/Apps/StoneBC/inventory/INTAKE.md` |
| Matcher script | `/Applications/Apps/StoneBC/Scripts/match_waitlist.py` |
| Deploy config | `/Applications/Apps/StoneBC/inventory/netlify.toml` |
| Auth edge function | `/Applications/Apps/StoneBC/inventory/netlify/edge-functions/auth.ts` |

**Netlify project:** `stonebc-inventory` (team: traddiff) — admin URL https://app.netlify.com/projects/stonebc-inventory
