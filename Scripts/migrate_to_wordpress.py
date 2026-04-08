#!/usr/bin/env python3
"""
migrate_to_wordpress.py — One-time migration of StoneBC JSON data to WordPress

Reads bikes.json, posts.json, and events.json from the iOS app bundle
and creates corresponding WordPress posts via the REST API.

Requirements:
    pip install requests

Usage:
    export WP_URL="https://your-wordpress-site.com"
    export WP_USER="admin"
    export WP_APP_PASSWORD="xxxx xxxx xxxx xxxx"
    python3 migrate_to_wordpress.py

The script uses WordPress Application Passwords for authentication.
Generate one in WP Admin → Users → Your Profile → Application Passwords.
"""

import json
import os
import sys
import requests
from pathlib import Path

# Config
WP_URL = os.environ.get("WP_URL", "").rstrip("/")
WP_USER = os.environ.get("WP_USER", "")
WP_APP_PASSWORD = os.environ.get("WP_APP_PASSWORD", "")
API_BASE = f"{WP_URL}/wp-json/wp/v2"

# Paths relative to this script
SCRIPT_DIR = Path(__file__).parent
APP_DIR = SCRIPT_DIR.parent / "StoneBC"
BIKES_JSON = APP_DIR / "bikes.json"
POSTS_JSON = APP_DIR / "posts.json"
EVENTS_JSON = APP_DIR / "events.json"


def check_config():
    if not all([WP_URL, WP_USER, WP_APP_PASSWORD]):
        print("Error: Set WP_URL, WP_USER, and WP_APP_PASSWORD environment variables.")
        print("Example:")
        print('  export WP_URL="https://stonebikeco.com"')
        print('  export WP_USER="admin"')
        print('  export WP_APP_PASSWORD="xxxx xxxx xxxx xxxx"')
        sys.exit(1)


def wp_post(endpoint, data):
    """POST to WordPress REST API with auth."""
    url = f"{API_BASE}/{endpoint}"
    resp = requests.post(url, json=data, auth=(WP_USER, WP_APP_PASSWORD))
    if resp.status_code in (200, 201):
        return resp.json()
    else:
        print(f"  FAILED ({resp.status_code}): {resp.text[:200]}")
        return None


def migrate_bikes():
    """Migrate bikes.json → sbc_bike custom post type."""
    if not BIKES_JSON.exists():
        print("No bikes.json found, skipping.")
        return

    with open(BIKES_JSON) as f:
        data = json.load(f)

    bikes = data.get("bikes", data) if isinstance(data, dict) else data
    print(f"\nMigrating {len(bikes)} bikes...")

    for bike in bikes:
        result = wp_post("sbc_bike", {
            "title": bike.get("model", "Unknown Bike"),
            "content": bike.get("description", ""),
            "status": "publish",
            "acf": {
                "bike_id": bike.get("id", ""),
                "bike_status": bike.get("status", "available"),
                "bike_type": bike.get("type", "hybrid"),
                "frame_size": bike.get("frameSize", ""),
                "wheel_size": bike.get("wheelSize", ""),
                "bike_color": bike.get("color", ""),
                "condition": bike.get("condition", "good"),
                "sponsor_price": bike.get("sponsorPrice", 0),
                "acquired_via": bike.get("acquiredVia", "donation"),
                "date_added": bike.get("dateAdded", ""),
            }
        })
        status = "OK" if result else "FAIL"
        print(f"  [{status}] {bike.get('id', '?')} — {bike.get('model', '?')}")


def migrate_posts():
    """Migrate posts.json → standard WP posts."""
    if not POSTS_JSON.exists():
        print("No posts.json found, skipping.")
        return

    with open(POSTS_JSON) as f:
        posts = json.load(f)

    print(f"\nMigrating {len(posts)} posts...")

    for post in posts:
        result = wp_post("posts", {
            "title": post.get("title", "Untitled"),
            "content": post.get("body", ""),
            "status": "publish",
            "date": f"{post.get('date', '2026-01-01')}T12:00:00",
        })
        status = "OK" if result else "FAIL"
        print(f"  [{status}] {post.get('id', '?')} — {post.get('title', '?')}")


def migrate_events():
    """Migrate events.json → sbc_event custom post type."""
    if not EVENTS_JSON.exists():
        print("No events.json found, skipping.")
        return

    with open(EVENTS_JSON) as f:
        events = json.load(f)

    print(f"\nMigrating {len(events)} events...")

    for event in events:
        result = wp_post("sbc_event", {
            "title": event.get("title", "Untitled Event"),
            "content": event.get("description", ""),
            "status": "publish",
            "acf": {
                "event_date": event.get("date", ""),
                "event_time": "",
                "event_location": event.get("location", ""),
                "event_category": event.get("category", "social"),
                "is_recurring": event.get("isRecurring", False),
            }
        })
        status = "OK" if result else "FAIL"
        print(f"  [{status}] {event.get('id', '?')} — {event.get('title', '?')}")


if __name__ == "__main__":
    check_config()
    print(f"Migrating to: {WP_URL}")
    migrate_bikes()
    migrate_posts()
    migrate_events()
    print("\nDone! Check your WordPress admin to verify.")
