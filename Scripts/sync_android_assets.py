#!/usr/bin/env python3
"""Sync canonical StoneBC bundle assets into the Android app.

The iOS bundle under StoneBC/ remains the current production content source.
Run with --check in CI to fail when Android assets drift.
"""

from __future__ import annotations

import argparse
import filecmp
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IOS_ASSETS = ROOT / "StoneBC"
ANDROID_ASSETS = ROOT / "android" / "app" / "src" / "main" / "assets"

JSON_ASSETS = [
    "config.json",
    "bikes.json",
    "posts.json",
    "events.json",
    "programs.json",
    "routes.json",
    "guides.json",
    "photos.json",
]

IMAGE_SOURCE = IOS_ASSETS / "GalleryPhotos"
IMAGE_DESTINATION = ANDROID_ASSETS / "images"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify Android assets are already synced without writing files",
    )
    return parser.parse_args()


def validate_json(path: Path) -> None:
    try:
        json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{path}: invalid JSON: {exc}") from exc


def copy_or_check(source: Path, destination: Path, check: bool, drift: list[str]) -> None:
    if not source.exists():
        raise SystemExit(f"Missing source asset: {source}")

    if source.suffix == ".json":
        validate_json(source)

    if check:
        if not destination.exists() or not filecmp.cmp(source, destination, shallow=False):
            drift.append(str(destination.relative_to(ROOT)))
        return

    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def sync_images(check: bool, drift: list[str]) -> None:
    if not IMAGE_SOURCE.exists():
        return

    source_files = sorted(p for p in IMAGE_SOURCE.iterdir() if p.is_file())
    destination_files = sorted(p for p in IMAGE_DESTINATION.iterdir() if p.is_file()) if IMAGE_DESTINATION.exists() else []

    if check:
        source_names = {p.name for p in source_files}
        destination_names = {p.name for p in destination_files}
        for name in sorted(source_names ^ destination_names):
            drift.append(str((IMAGE_DESTINATION / name).relative_to(ROOT)))
        for source in source_files:
            destination = IMAGE_DESTINATION / source.name
            if destination.exists() and not filecmp.cmp(source, destination, shallow=False):
                drift.append(str(destination.relative_to(ROOT)))
        return

    IMAGE_DESTINATION.mkdir(parents=True, exist_ok=True)
    for destination in destination_files:
        if destination.name not in {p.name for p in source_files}:
            destination.unlink()
    for source in source_files:
        shutil.copy2(source, IMAGE_DESTINATION / source.name)


def main() -> int:
    args = parse_args()
    drift: list[str] = []

    for file_name in JSON_ASSETS:
        copy_or_check(
            IOS_ASSETS / file_name,
            ANDROID_ASSETS / file_name,
            args.check,
            drift,
        )

    sync_images(args.check, drift)

    if drift:
        print("Android assets are out of sync:", file=sys.stderr)
        for path in drift:
            print(f"  {path}", file=sys.stderr)
        print("Run: python3 Scripts/sync_android_assets.py", file=sys.stderr)
        return 1

    if not args.check:
        print("Android assets synced from StoneBC bundle assets.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
