# How to Use the Inventory Dashboard

**Live at:** https://inventory.stonebicyclecoalition.com
**Primary user:** Caden (mechanic) · **Admin:** Rory

Last updated: 2026-04-17 (Phase 2 complete — magic-link auth, shared backend, parts catalog, photos, activity log)

---

## 1. Sign In

No shared password. Access is granted per-email.

1. Go to https://inventory.stonebicyclecoalition.com
2. Enter your email (the one Rory added to your allowlist)
3. Check your inbox (from `noreply@traddiff.com`, subject "Sign in to Stone Bicycle Coalition…")
4. Click the **Sign in** button in the email
5. You're in — session lasts 7 days per device

If you never get the email: check spam, then text Rory — your email may not be on the allowlist yet.

**Admin — add or remove users:**
```
cd /Applications/Apps/StoneBC/inventory
netlify env:set ALLOWED_EMAILS "rory@traddiff.com,caden@example.com,..."
netlify deploy --prod --build
```
Comma-separated, no spaces. Deploy picks up the new list. To remove someone, drop them from the list and redeploy.

---

## 2. What the Dashboard Has

Four panels stacked at the top. Each is collapsed by default — click the bar to expand.

| Bar (color) | Content |
|-------------|---------|
| 🔔 **Wait List** (amber) | People waiting for a bike. Shows ID, contact, what size/type they need, priority flag. Read-only here — edit `inventory/waitlist.json` in the repo to add/change applicants. |
| 🔧 **Parts Shelf** (blue) | Inline catalog of parts on the shelf. Click *+ Add part* to log one. Each row is editable: name, category, specs, qty, reorder threshold, cost. A red badge shows the count of parts at/below reorder. |
| 📋 **Activity** (slate) | Last ~50 edits (time · who · what). Useful for answering "when did Caden log this bike?" or "who dropped stock to zero?" |
| **Sync pill** (top-right of header) | Shows Loading / Saving / Saved — confirms your changes landed. |

Main area below those bars is the POS:
- **Left column:** bike list. Click `+` to add a bike (auto-numbered `SBC-XXX`).
- **Right column:** the form for the selected bike — acquisition details, bike specs, photos, refurbishment work, and cost totals.

---

## 3. Daily Workflows

### Logging a new bike (donation or purchase)

1. Open the dashboard.
2. Glance at the **Wait List** first — note if anyone's waiting for the type/size coming in so you can prioritize refurb.
3. Click `+` in the Bikes column. A new `SBC-XXX` appears.
4. Fill in **Acquisition**: date, source (donation/purchase), cost, donor name. Notes field is fine for anything extra.
5. Fill in **Details**: model, type, frame size, wheel size, color, condition. Set **Status** to `refurbishing` while the bike is on the stand.
6. Every edit saves automatically (debounced ~0.4s). Watch the sync pill go Saving → Saved.

### Photos

New "Photos" section is above Refurbishment Work on every bike.

- Click **📷 Add photo** — opens camera on mobile, file picker on desktop
- Image is resized to 1600px and uploaded (max 2MB, max 5 photos per bike)
- Hover a thumbnail to reveal **Delete**; click a thumbnail for the lightbox
- Use for: condition on intake, before/after refurb, any detail worth documenting

### Using parts on a bike

Two steps: log the part row, then decrement stock.

1. In the **Refurbishment Work** table, click **+ Add work item**.
2. Start typing in the **Item** field — autocomplete suggests parts from the catalog (e.g. *"Chain (9-spd)"*).
3. Pick one. A green/amber/red **stock chip** appears in the next column showing shelf qty. The color tells you:
   - **Green** — above reorder threshold
   - **Amber** — at or below threshold (order more soon)
   - **Red** — out or negative (oops)
4. Click the **-1** button next to the chip to take one off the shelf. Server decrements in real time; everyone's view updates.
5. Fill in **Cost** and **Labor Hrs** for the row. Totals at the bottom update automatically.

**Free-text still works.** If you use a part that's not in the catalog, just type whatever. No stock chip will show — that's fine, the row still contributes to the cost totals.

### Adding a new part to the shelf catalog

1. Expand the **Parts Shelf** banner.
2. Click **+ Add part**. A new row with ID `PART-XXXX` appears.
3. Fill the row: Name (e.g. *Brake pads*), Category (dropdown), Specs (e.g. *disc, Shimano*), Qty on shelf, Reorder threshold, Cost each.
4. Saves automatically. Now available in refurb-table autocomplete.

### When a bike is ready to match to an applicant

1. Flip the bike's **Status** to `ready`.
2. On your terminal (Rory): `cd /Applications/Apps/StoneBC && python3 Scripts/match_waitlist.py`
3. Script reads live inventory + wait list, finds type + frame-size matches, writes draft notification emails to `drafts/notify-WL-XXX-SBC-YYY.md`.
4. Review the draft, send from Mac Mail (`info@stonebicyclecoalition.com`).
5. In the dashboard: update the matched applicant — append the bike ID to `matched_bike_ids` and flip `status` to `matched`.
6. When handoff happens: flip bike Status to `sponsored` (paid) or `sold`, flip applicant to `fulfilled`.

---

## 4. Multi-User Behavior

Caden on his phone, Rory on his laptop — same data. Here's how sync works:

- Every save PUTs to the shared backend (Netlify Blobs). No localStorage.
- When you switch back to the tab (window focus), the dashboard pulls fresh state — bikes, wait list, parts, photos, activity.
- If two people edit the same bike simultaneously, the second save wins. For the scale we're at this is fine; if it ever stings we'll add optimistic concurrency control.

---

## 5. For Rory: Backups & Admin

### Backup

Live state lives in Netlify Blobs. To snapshot everything into the repo (for git history = disaster recovery):

```
cd /Applications/Apps/StoneBC
python3 Scripts/dump_blobs.py              # dry-run: prints diff summary
python3 Scripts/dump_blobs.py --write      # write to inventory/*.json
python3 Scripts/dump_blobs.py --write --commit   # also git-commit
```

Mints a 5-minute JWT locally using `SESSION_SECRET` from Netlify env — no emails sent. Reads `/api/bikes`, `/api/waitlist`, `/api/parts`, `/api/activity` and writes them to the repo.

Run weekly as a habit, or wire a GitHub Actions cron later.

### Rotate the session-signing secret

Invalidates all active sessions (everyone logs in again):
```
cd /Applications/Apps/StoneBC/inventory
netlify env:set SESSION_SECRET "$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
netlify deploy --prod --build
```

### Rotate Resend key

If the Resend API key is ever leaked:
```
# Get a new one at resend.com/api-keys, then:
netlify env:set RESEND_API_KEY "re_new_key_here"
netlify deploy --prod --build
```

### Check the live deploy

```
netlify status                    # confirms you're linked
netlify deploy --prod --build     # force redeploy
netlify logs:function bikes       # tail function logs
```

---

## 6. Files (for reference)

| What | Where |
|------|-------|
| Dashboard frontend | `/Applications/Apps/StoneBC/inventory/pos.html` |
| Login page | `/Applications/Apps/StoneBC/inventory/login.html` |
| Wait list source JSON | `/Applications/Apps/StoneBC/inventory/waitlist.json` |
| Wait list human table | `/Applications/Apps/StoneBC/inventory/WAITLIST.md` |
| Bike inventory seed | `/Applications/Apps/StoneBC/inventory/bikes.json` |
| Parts catalog seed | `/Applications/Apps/StoneBC/inventory/parts.json` |
| Matcher script (bike → applicant) | `/Applications/Apps/StoneBC/Scripts/match_waitlist.py` |
| Backup script | `/Applications/Apps/StoneBC/Scripts/dump_blobs.py` |
| Deploy config | `/Applications/Apps/StoneBC/inventory/netlify.toml` |
| Auth edge function | `/Applications/Apps/StoneBC/inventory/netlify/edge-functions/auth.ts` |
| API functions | `/Applications/Apps/StoneBC/inventory/netlify/functions/*.ts` |
| Shared helpers (JWT, store, activity) | `/Applications/Apps/StoneBC/inventory/netlify/lib/*.ts` |

**Netlify project:** `stonebc-inventory` — admin at https://app.netlify.com/projects/stonebc-inventory

**Env vars on the site:**
- `SESSION_SECRET` — 32-byte random, signs JWT sessions
- `ALLOWED_EMAILS` — comma-separated login allowlist
- `RESEND_API_KEY` — for sending magic-link emails

---

## 7. Troubleshooting

| Problem | Fix |
|---------|-----|
| "I never got the sign-in email" | Check spam. If empty, your email isn't allowlisted — text Rory. |
| Sign-in link says "already used" | Each link is one-shot. Request a new one. |
| "Link expired" | Links expire in 15 min. Request a new one. |
| Sync pill stuck on "Saving…" | Bad network. Check wifi. If persistent, refresh the tab (pending edits flush before reload). |
| Stock chip says "0 on shelf" but I still see the part | Somebody decremented too aggressively. Open Parts panel and fix the Qty directly. |
| Dashboard shows someone else's unsaved changes | That's the focus-refresh pulling latest state from the server. Expected. |
| Photo upload says "too large" | Client resize should keep photos under 2MB. If your original is >10MB, try a lower-res camera setting. |
| I can't log in and Rory's not around | Use the Netlify webmail / DNS admin as a fallback. Otherwise, it has to wait. |

**Who to text:** Rory for anything weird with the dashboard or wait list. For parts re-order questions, log the need in notes and discuss later.
