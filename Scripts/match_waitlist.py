#!/usr/bin/env python3
"""
match_waitlist.py — Match ready bikes to waiting applicants.

Reads inventory/bikes.json + inventory/waitlist.json, finds candidate
matches, and drafts notification emails into drafts/notify-*.md for Rory
to review + send from info@stonebicyclecoalition.com.

Usage:
    cd /Applications/Apps/StoneBC
    python3 Scripts/match_waitlist.py

Exit codes:
    0  ran cleanly (may or may not have matches)
    1  missing input files or bad JSON
"""

from __future__ import annotations

import json
import re
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BIKES_JSON = ROOT / "inventory" / "bikes.json"
WAITLIST_JSON = ROOT / "inventory" / "waitlist.json"
DRAFTS_DIR = ROOT / "drafts"

SENDER = "info@stonebicyclecoalition.com"


def parse_frame_size_in(frame_size: str, bike_type: str) -> float | None:
    """Return bike frame size in inches, or None if unparseable.

    Conventions:
      - Mountain / BMX / kids: inches (e.g. "18in", "20\"", "18")
      - Road / gravel: centimeters (e.g. "56cm") → converted to inches
      - Letter sizes (S/M/L/XL) can't be converted numerically; return None
    """
    if not frame_size:
        return None
    s = frame_size.strip().lower()

    cm_match = re.match(r"^(\d+(?:\.\d+)?)\s*cm$", s)
    if cm_match:
        return float(cm_match.group(1)) / 2.54

    in_match = re.match(r'^(\d+(?:\.\d+)?)\s*(?:in|")?$', s)
    if in_match:
        value = float(in_match.group(1))
        if bike_type in {"road", "gravel"} and value > 40:
            return value / 2.54
        return value

    return None


def bike_matches_need(bike: dict, need: dict) -> bool:
    if bike.get("status") != "ready":
        return False
    if bike.get("type") != need.get("bike_type"):
        return False

    bike_size = parse_frame_size_in(bike.get("frameSize", ""), bike.get("type", ""))
    if bike_size is None:
        return False

    lo = float(need.get("frame_size_min_in", 0))
    hi = float(need.get("frame_size_max_in", 99))
    tolerance = 1.0
    return (lo - tolerance) <= bike_size <= (hi + tolerance)


def load_json(path: Path) -> dict:
    if not path.exists():
        print(f"ERROR: missing {path}", file=sys.stderr)
        sys.exit(1)
    try:
        return json.loads(path.read_text())
    except json.JSONDecodeError as e:
        print(f"ERROR: invalid JSON in {path}: {e}", file=sys.stderr)
        sys.exit(1)


def build_draft(applicant: dict, need: dict, bike: dict, other_riders: list[str] | None = None) -> str:
    rider = need.get("rider", "you")
    first_name = applicant["name"].split()[0] if applicant.get("name") else "there"
    model = bike.get("model", "bike")
    frame = bike.get("frameSize", "")
    color = bike.get("color", "")
    features = ", ".join(bike.get("features", []))
    description = bike.get("description", "")
    sponsor_price = bike.get("sponsorPrice")

    price_line = f"\n- Sponsor price: ${sponsor_price}" if sponsor_price else ""
    features_line = f"\n- {features}" if features else ""
    other_line = (
        f"\n\n_Note: this bike's frame also falls within range for: {', '.join(other_riders)}. "
        f"Reviewer may want to edit this draft accordingly._"
        if other_riders
        else ""
    )

    return f"""# Notify — {applicant['id']} × {bike['id']}

**To:** {applicant.get('email') or '(add email)'}
**From:** {SENDER}
**Subject:** We may have a bike for {rider}

Hi {first_name},

Good news — we just finished refurbishing a bike that looks like it could
be a great fit for {rider}:

- **{model}**
- {frame} frame, {color}{features_line}
- {description}{price_line}

If you're still looking and this sounds like the right bike, reply to this
email and we'll set up a time for you to come by, try it out, and take it
home if it feels good. If it's not quite right, no worries — we'll keep
watching for a better match.

Ride safe,
Stone Bicycle Coalition
{SENDER}
stonebicyclecoalition.com

---

_Match reason: bike.type={bike.get('type')} matches need.bike_type={need.get('bike_type')};
bike frame {frame} in applicant range {need.get('frame_size_min_in')}"–{need.get('frame_size_max_in')}"._{other_line}
"""


def main() -> int:
    bikes_data = load_json(BIKES_JSON)
    waitlist_data = load_json(WAITLIST_JSON)

    bikes = bikes_data.get("bikes", [])
    applicants = waitlist_data.get("applicants", [])

    ready_bikes = [b for b in bikes if b.get("status") == "ready"]
    active_applicants = [a for a in applicants if a.get("status") == "active"]

    print(f"Bikes in inventory: {len(bikes)} ({len(ready_bikes)} ready)")
    print(f"Active wait list entries: {len(active_applicants)}")
    print()

    if not ready_bikes:
        print("No bikes with status='ready'. Nothing to match.")
        return 0
    if not active_applicants:
        print("No active applicants. Nothing to match.")
        return 0

    DRAFTS_DIR.mkdir(exist_ok=True)
    matches_found = 0

    for applicant in active_applicants:
        already_matched = set(applicant.get("matched_bike_ids", []))
        for bike in ready_bikes:
            if bike["id"] in already_matched:
                continue

            candidate_needs = [n for n in applicant.get("needs", []) if bike_matches_need(bike, n)]
            if not candidate_needs:
                continue

            bike_size = parse_frame_size_in(bike.get("frameSize", ""), bike.get("type", ""))
            best_need = min(
                candidate_needs,
                key=lambda n: abs(bike_size - (n["frame_size_min_in"] + n["frame_size_max_in"]) / 2),
            )
            rider = best_need.get("rider", "rider")
            other_riders = [n.get("rider") for n in candidate_needs if n is not best_need]

            print(
                f"MATCH: {bike['id']} ({bike.get('type')}, "
                f"{bike.get('frameSize')}) → {applicant['id']} "
                f"({applicant['name']}, best fit: {rider})"
            )
            if other_riders:
                print(f"       also eligible for: {', '.join(other_riders)}")

            draft_path = DRAFTS_DIR / f"notify-{applicant['id']}-{bike['id']}.md"
            draft_path.write_text(build_draft(applicant, best_need, bike, other_riders))
            print(f"       drafted: {draft_path.relative_to(ROOT)}")
            matches_found += 1

    print()
    if matches_found:
        print(f"{matches_found} draft(s) written to {DRAFTS_DIR.relative_to(ROOT)}/")
        print(
            "Next: review each draft, send from Hover webmail, then update "
            "waitlist.json (append bike ID to matched_bike_ids, flip status "
            "to 'matched')."
        )
    else:
        print("No matches found today.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
