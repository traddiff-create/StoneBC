#!/usr/bin/env python3
"""
dump_blobs.py — Backup the Netlify Blobs state of the inventory dashboard
to the repo so git history serves as disaster-recovery.

Reads: https://inventory.stonebicyclecoalition.com/api/{bikes,waitlist,parts,activity}
Writes: inventory/bikes.json, inventory/waitlist.json, inventory/parts.json,
        inventory/activity.json

Auth: mints a short-lived (5-min) JWT locally using SESSION_SECRET from the
Netlify site env, then sends it as the sbc_session cookie. No email sends.

Usage:
    cd /Applications/Apps/StoneBC
    python3 Scripts/dump_blobs.py              # dry run (prints diff summary)
    python3 Scripts/dump_blobs.py --write      # write files to disk
    python3 Scripts/dump_blobs.py --write --commit  # write + git commit

Exit codes:
    0 = success (or no changes on dry run)
    1 = auth / network error
    2 = write error
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INVENTORY = ROOT / "inventory"
API_BASE = "https://stonebc-inventory.netlify.app"
BACKUP_ACTOR = "rory@traddiff.com"

RESOURCES = [
    ("bikes", "bikes.json"),
    ("waitlist", "waitlist.json"),
    ("parts", "parts.json"),
    ("activity", "activity.json"),
]


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def mint_jwt(secret: str, email: str, ttl_seconds: int = 300) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    now = int(time.time())
    payload = {"email": email, "sub": email, "iat": now, "exp": now + ttl_seconds}
    header_b64 = b64url(json.dumps(header, separators=(",", ":")).encode())
    payload_b64 = b64url(json.dumps(payload, separators=(",", ":")).encode())
    msg = f"{header_b64}.{payload_b64}".encode()
    sig = hmac.new(secret.encode(), msg, hashlib.sha256).digest()
    return f"{header_b64}.{payload_b64}.{b64url(sig)}"


def get_session_secret() -> str:
    try:
        result = subprocess.run(
            ["netlify", "env:get", "SESSION_SECRET"],
            capture_output=True,
            text=True,
            cwd=INVENTORY,
            check=True,
        )
    except FileNotFoundError:
        die("netlify CLI not found. Install with `brew install netlify-cli`.")
    except subprocess.CalledProcessError as e:
        die(f"Could not read SESSION_SECRET via netlify CLI:\n{e.stderr}")
    secret = result.stdout.strip().splitlines()[-1].strip()
    if not secret or secret.lower() in {"undefined", "none", ""}:
        die("SESSION_SECRET is empty. Run this script from inventory/ or `netlify link` first.")
    return secret


def fetch_resource(resource: str, cookie: str) -> dict:
    url = f"{API_BASE}/api/{resource}?t={int(time.time())}"
    req = urllib.request.Request(url, headers={"cookie": cookie})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        if e.code == 404 and resource == "activity":
            # activity endpoint may not exist yet on first run
            return {"entries": []}
        die(f"GET /api/{resource} failed: HTTP {e.code} {e.reason}")
    except urllib.error.URLError as e:
        die(f"Network error fetching /api/{resource}: {e.reason}")


def diff_summary(old_text: str, new_text: str) -> str:
    if old_text == new_text:
        return "unchanged"
    old_lines = old_text.count("\n")
    new_lines = new_text.count("\n")
    delta = new_lines - old_lines
    return f"{old_lines} → {new_lines} lines ({'+' if delta >= 0 else ''}{delta})"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--write", action="store_true", help="Actually write files (default is dry-run)")
    p.add_argument("--commit", action="store_true", help="git add + commit after writing")
    args = p.parse_args()

    secret = get_session_secret()
    jwt = mint_jwt(secret, BACKUP_ACTOR)
    cookie = f"sbc_session={jwt}"

    print(f"Dumping Blobs from {API_BASE}")
    print(f"  Actor: {BACKUP_ACTOR}  (JWT, 5-min TTL)")
    print(f"  Target dir: {INVENTORY}")
    print(f"  Mode: {'WRITE' if args.write else 'dry-run'}")
    print()

    changes = []
    for key, filename in RESOURCES:
        remote = fetch_resource(key, cookie)
        new_text = json.dumps(remote, indent=2, sort_keys=False) + "\n"
        target = INVENTORY / filename
        old_text = target.read_text() if target.exists() else ""
        summary = diff_summary(old_text, new_text)
        print(f"  {filename}: {summary}")
        if args.write and old_text != new_text:
            tmp = target.with_suffix(target.suffix + ".tmp")
            tmp.write_text(new_text)
            tmp.replace(target)
            changes.append(filename)

    if not args.write:
        print("\nDry run. Pass --write to apply.")
        return 0

    if not changes:
        print("\nNo files changed; nothing to commit.")
        return 0

    print(f"\nWrote {len(changes)} file(s): {', '.join(changes)}")

    if args.commit:
        paths = [str(INVENTORY / f) for f in changes]
        rel = [f"inventory/{f}" for f in changes]
        subprocess.run(["git", "add", "-f", *paths], cwd=ROOT, check=True)
        msg = (
            "chore(inventory): backup Blobs snapshot\n\n"
            f"Automated dump of live state for: {', '.join(rel)}\n\n"
            "Generated by Scripts/dump_blobs.py"
        )
        subprocess.run(["git", "commit", "-m", msg], cwd=ROOT, check=True)
        print("Committed. Run `git push` when ready.")

    return 0


def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    sys.exit(main())
