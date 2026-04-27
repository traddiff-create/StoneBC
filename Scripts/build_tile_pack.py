#!/usr/bin/env python3
"""
build_tile_pack.py — Stone Bicycle Coalition

Crops two source MBTiles archives (USFS topo + OSM Cycle Map) into the
xyz directory tree expected by `RideMapTileOverlay`, restricted to the
Black Hills + foothills bbox declared in `OfflineTileCoverage.swift`.

Output layout (relative to repo root):

    StoneBC/Resources/tiles/
        usfs/{z}/{x}/{y}.png        # public domain
        osm/{z}/{x}/{y}.png         # CC BY-SA — attribution shown in About
        tile_coverage.json          # bbox + zoom range, read at runtime

Usage:
    python3 Scripts/build_tile_pack.py \
        --usfs path/to/usfs.mbtiles \
        --osm path/to/osm-cycle.mbtiles

Inputs are not checked into the repo — they're large source archives.
Provision them before running. See `_offline-tiles-handoff.md` for
recommended sources (USFS national topo, ThunderForest OpenCycleMap export
or Stamen Terrain export).
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
from pathlib import Path

# Black Hills + foothills coverage. Mirror these in OfflineTileCoverage.swift —
# they should agree. Kept in sync manually for now; could be loaded from a
# shared JSON if drift becomes a problem.
BBOX = {
    "minLat": 43.30,    # Wind Cave / southern Custer SP
    "maxLat": 44.85,    # Belle Fourche / Sturgis / Spearfish Canyon
    "minLon": -104.20,  # Wyoming line
    "maxLon": -102.85,  # Rapid City / Box Elder
    "minZoom": 11,
    "maxZoom": 14,
    "attribution": (
        "USFS Topo (public domain) · "
        "OSM Cycle Map © OpenStreetMap contributors (CC BY-SA)"
    ),
}

REPO_ROOT = Path(__file__).resolve().parent.parent
TILES_DIR = REPO_ROOT / "StoneBC" / "Resources" / "tiles"


def deg2num(lat_deg: float, lon_deg: float, zoom: int) -> tuple[int, int]:
    """Slippy-map tile-number from lat/lon."""
    import math
    lat_rad = math.radians(lat_deg)
    n = 2 ** zoom
    xtile = int((lon_deg + 180.0) / 360.0 * n)
    ytile = int(
        (1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n
    )
    return xtile, ytile


def tile_range(zoom: int) -> tuple[range, range]:
    """xy ranges for the bbox at this zoom."""
    x_min, y_max = deg2num(BBOX["minLat"], BBOX["minLon"], zoom)
    x_max, y_min = deg2num(BBOX["maxLat"], BBOX["maxLon"], zoom)
    return range(x_min, x_max + 1), range(y_min, y_max + 1)


def export_provider(mbtiles_path: Path, provider: str) -> tuple[int, int]:
    """Read tiles from MBTiles and write them as PNGs under tiles/<provider>/.

    MBTiles uses TMS y-numbering (origin at south); slippy maps + iOS use
    XYZ (origin at north). Convert: y_xyz = (2^z - 1) - y_tms.
    """
    if not mbtiles_path.exists():
        raise FileNotFoundError(f"MBTiles not found: {mbtiles_path}")

    out_root = TILES_DIR / provider
    out_root.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(mbtiles_path)
    cursor = conn.cursor()

    total_tiles = 0
    total_bytes = 0

    for z in range(BBOX["minZoom"], BBOX["maxZoom"] + 1):
        x_range, y_range = tile_range(z)
        for x in x_range:
            for y in y_range:
                y_tms = (2 ** z - 1) - y
                cursor.execute(
                    "SELECT tile_data FROM tiles "
                    "WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?",
                    (z, x, y_tms),
                )
                row = cursor.fetchone()
                if row is None:
                    continue
                data = row[0]
                out_path = out_root / str(z) / str(x) / f"{y}.png"
                out_path.parent.mkdir(parents=True, exist_ok=True)
                out_path.write_bytes(data)
                total_tiles += 1
                total_bytes += len(data)

    conn.close()
    return total_tiles, total_bytes


def write_coverage_json() -> None:
    """Emit tile_coverage.json so OfflineTileCoverage can load it at runtime."""
    out = TILES_DIR / "tile_coverage.json"
    out.write_text(json.dumps(BBOX, indent=2) + "\n")


def fmt_bytes(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} TB"


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the StoneBC offline tile pack.")
    parser.add_argument("--usfs", type=Path, required=True, help="USFS topo MBTiles input")
    parser.add_argument("--osm", type=Path, required=True, help="OSM Cycle MBTiles input")
    args = parser.parse_args()

    print(f"Output: {TILES_DIR}")
    print(f"BBox  : {BBOX['minLat']},{BBOX['minLon']} → {BBOX['maxLat']},{BBOX['maxLon']}")
    print(f"Zoom  : {BBOX['minZoom']}–{BBOX['maxZoom']}")
    print()

    grand_tiles = 0
    grand_bytes = 0

    for provider, src in (("usfs", args.usfs), ("osm", args.osm)):
        print(f"[{provider}] reading {src}…")
        tiles, byte_count = export_provider(src, provider)
        print(f"[{provider}] wrote {tiles:,} tiles · {fmt_bytes(byte_count)}")
        grand_tiles += tiles
        grand_bytes += byte_count

    write_coverage_json()
    print()
    print(f"Total : {grand_tiles:,} tiles · {fmt_bytes(grand_bytes)}")
    print(f"Target: ~150 MB (±10%). Pack {'OK' if 130 * 1024 ** 2 <= grand_bytes <= 170 * 1024 ** 2 else 'OUTSIDE TARGET — review zoom/bbox'}")
    print()
    print("Don't forget: add the `Resources/tiles/` folder to the StoneBC")
    print("target's Build Phases > Copy Bundle Resources, or its parent")
    print("group with `folder reference` so iOS preserves the directory tree.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
