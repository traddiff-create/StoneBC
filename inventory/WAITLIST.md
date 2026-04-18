# Bike Wait List — Applicants

Human-readable mirror of `waitlist.json`. Edit the JSON first, then update this table.

**Next ID:** `WL-2026-006`

---

## Active

| ID | Added | Name | Contact | Needs | Priority Notes |
|----|-------|------|---------|-------|----------------|
| WL-2026-001 | 2026-04-17 | Gina Scotto | 910-367-6779 | **Daughter (priority):** MTB, 19–21" frame (5'10"). **Gina:** MTB, 17–19" frame (5'8"). | Unemployed; bikes stolen 2026; daughter spending more time indoors |
| WL-2026-002 | 2026-03-31 | Harry Elthie | sonnyelthie622@gmail.com | Comfortable bike (back issues), upright frame preferred | Confirmed interested Apr 9. Follow-up sent Apr 17 asking height/type |
| WL-2026-003 | 2026-03-31 | Amelia | ammacct22@gmail.com | Wants to ride again — no specifics yet | Confirmed interested Mar 31. Follow-up sent Apr 17 asking height/type |
| WL-2026-004 | 2026-04-12 | Chance Davis | chancedavis1102@gmail.com | MTB or beach cruiser for transportation/commuting; has existing MTB needing repair | Reply sent Apr 17, offered Tuesday open shop |
| WL-2026-005 | 2026-03-31 | Christopher Bradley | yeet.combat@gmail.com | Fat tire bike for year-round commuting + hauling | Second outreach sent Apr 17. No reply to first (Mar 31) |

---

## Matched / Fulfilled

_None yet._

---

## Stale / Withdrawn

_None yet._

---

## Pending Actions

1. ~~**Chance Davis**~~ — Reply sent Apr 17. Awaiting response (height, ride distance, Tuesday shop visit)
2. ~~**Harry Elthie**~~ — Follow-up sent Apr 17. Awaiting response (height, bike type)
3. ~~**Amelia**~~ — Follow-up sent Apr 17. Awaiting response (height, bike type)
4. ~~**Christopher Bradley**~~ — Second outreach sent Apr 17. If no reply by May 1, flip to stale
5. **Darlene Piekkola** — NOT a waitlist applicant. Bike/parts DONOR (Mar 30). Follow up on donation intake. See Gmail thread "Bikes and parts" with photos.

---

## Process

1. **New applicant comes in** (Facebook, contact form, walk-in, email):
   - Add an entry to `waitlist.json` using the next ID
   - Mirror the row into the **Active** table above
   - Draft a reply in `drafts/sbc-replies-YYYY-MM-DD.md` (use the voice from prior drafts)
   - Send from `info@stonebicyclecoalition.com` (Hover webmail)
2. **Bike becomes ready** (status flips to `ready` in `inventory/bikes.json`):
   - Run `python3 Scripts/match_waitlist.py` from the StoneBC root
   - Script generates draft notification emails in `drafts/notify-WL-XXX-SBC-YYY.md`
   - Review, edit, send
   - Update applicant `status` to `matched` and append bike ID to `matched_bike_ids` in `waitlist.json`
3. **Bike handed off:**
   - Flip applicant `status` to `fulfilled`
   - Move row from Active to Matched/Fulfilled table
4. **No response after 2 attempts over 30 days:**
   - Flip applicant `status` to `stale`
   - Move row to Stale/Withdrawn

---

## Schema Notes

- Each applicant can have multiple `needs` (e.g., Gina needs two bikes — one for her daughter, one for herself)
- `frame_size_min_in` / `frame_size_max_in` are in **inches** (mountain/BMX/kids convention)
- For road/gravel bikes that use cm sizing, the matcher converts automatically
- `accessory_needs` is a free list — helmets, locks, lights, pumps, etc.
