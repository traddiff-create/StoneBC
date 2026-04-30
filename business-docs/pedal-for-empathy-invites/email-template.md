# Pedal for Empathy — Tier 1 Email Template

This is the master copy. The send script (`send.mjs`) renders it per recipient, swapping `{{first_name}}` and `{{personal_line}}` from `recipients.json`.

---

## Subject

`Pedal for Empathy — Saturday May 2, 10:30 at Hanson-Larsen`

## Body (HTML rendered email)

> Hi {{first_name_or_hey}},
>
> {{personal_line}}
>
> Quick rundown in case it helps:
>
> - **What:** Pedal for Empathy — community bike ride + bike-path cleanup
> - **When:** Saturday, May 2, 2026 — 10:30 AM
> - **Where:** Coffee + donuts at Hanson-Larsen Memorial Park, then ride out
> - **Who:** Family-friendly, all levels, free
> - **Partners:** City Parks & Rec, Acme Bikes, Minneluzahan Senior Center, Nell's Gourmet
>
> We were picked out of 600+ applicants nationwide for an American Empathy Project grant to make this happen. Part of the grant goes to Feeding South Dakota.
>
> RSVP (and please share with anyone you think would love it): https://mobilize.us/s/JFgFN6
>
> Thanks — would mean a lot to see you there.
>
> Rory
> Stone Bicycle Coalition
> stonebicyclecoalition.com

---

## Personalization rules

- If `first_name` is empty → "Hi there,"
- If `first_name` is set → "Hi {{first_name}},"
- `personal_line` always renders before the rundown — keeps it personal, not bulk

## What NOT to change

- Date/time/location facts come from `aep-grant-tracking.md` and the invite list — keep them in lockstep across all SBC mailings.
- The "600+ applicants" line is the talking point in `pedal-for-empathy-invite-list.md` (line 147). Reuse verbatim.
- Mobilize URL `https://mobilize.us/s/JFgFN6` is the canonical RSVP link.
