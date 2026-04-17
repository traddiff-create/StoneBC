# Bike Intake Log

Copy the blank entry below for each new bike. Fill in what you know — leave blanks for later.

## → First, check the wait list

Before sourcing or accepting a donation: **[open WAITLIST.md](./WAITLIST.md)** to see what sizes/types are actively needed. Match real needs first; it saves refurb hours.

## → After flipping to `ready`

1. Copy the key fields from this log into `inventory/bikes.json` (id, status, model, type, frameSize, wheelSize, color, condition, features, description).
2. Also copy into `StoneBC/bikes.json` (app bundle mirror).
3. Run the matcher: `python3 Scripts/match_waitlist.py` from StoneBC root.
4. Review any drafts in `drafts/notify-WL-*.md`, send from Mac Mail (`info@stonebicyclecoalition.com`).
5. Update the matched applicant in `waitlist.json` — append bike ID to `matched_bike_ids`, flip `status` to `matched`.

---

## NEXT ID: SBC-001

---

### Blank Template

```
### SBC-XXX
- **Date In:**
- **Source:** donation / purchase
- **Cost:** $
- **Donor/Seller:**
- **Model:**
- **Type:** road / mountain / hybrid / cruiser / kids / bmx / gravel / electric
- **Frame Size:**
- **Wheel Size:**
- **Color:**
- **Condition In:** good / fair / poor
- **Notes:**
- **Status:** available / refurbishing / ready / sponsored / sold

#### Refurb Work
| Date | Item | Cost | Labor Hrs |
|------|------|------|-----------|
|      |      |      |           |

#### Totals
- Parts: $
- Labor: hrs × $25 = $
- Paint/Cosmetic: $
- **Break-even:** $
- **Sponsor Price:** $
```

---

## Intake Entries

_None yet. First real bike goes here — copy the template above and number it `SBC-001`._
