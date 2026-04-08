#!/usr/bin/env python3
"""
process_routes.py - Parse GPX and FIT files into routes.json for StoneBC iOS app.

Extracts trackpoints, calculates distance and elevation gain,
classifies difficulty and category based on route characteristics.

Usage: python3 process_routes.py
"""

import xml.etree.ElementTree as ET
import json
import math
import os
import sys

GPX_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "GPX")
OUTPUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "StoneBC", "routes.json")

# Route metadata overrides (name, category, difficulty, region, description)
# Every file gets a clean name and proper metadata
ROUTE_METADATA = {
    # === GPX FILES ===
    "gold-rush-110-rev-finish.gpx": {
        "name": "Gold Rush 110",
        "category": "gravel",
        "region": "Black Hills",
        "description": "Epic gravel adventure through historic gold mining country. The flagship Black Hills gravel race."
    },
    "28_Below_Course.gpx": {
        "name": "28 Below Fat Bike",
        "category": "fatbike",
        "region": "Black Hills",
        "description": "Cold-weather fat bike challenge through snowy Black Hills terrain."
    },
    "Custer 2.gpx": {
        "name": "Custer State Park Loop",
        "category": "road",
        "region": "Custer",
        "description": "Wildlife loop and Needles Highway through Custer State Park. Watch for bison."
    },
    "Wall 35.gpx": {
        "name": "Badlands Prairie 35",
        "category": "gravel",
        "region": "Badlands",
        "description": "Short prairie gravel loop near Wall with Badlands views."
    },
    "Wall 68.gpx": {
        "name": "Badlands Prairie 68",
        "category": "gravel",
        "region": "Badlands",
        "description": "Long prairie gravel route through open Badlands country."
    },
    "Piedmont Hrd.gpx": {
        "name": "Piedmont Ranch Hard",
        "category": "gravel",
        "region": "Piedmont",
        "description": "Challenging gravel through ranch country north of Rapid City."
    },
    "Piedmont Med.gpx": {
        "name": "Piedmont Ranch Medium",
        "category": "gravel",
        "region": "Piedmont",
        "description": "Rolling gravel through ranch country north of Rapid City."
    },
    "Sturgis Med.gpx": {
        "name": "Sturgis Ramble",
        "category": "road",
        "region": "Sturgis",
        "description": "Classic Black Hills road ride through the Sturgis area."
    },
    "Gravel_Pursuit_22__-_60__V1.gpx": {
        "name": "Gravel Pursuit 60",
        "category": "gravel",
        "region": "Black Hills",
        "description": "Official Gravel Pursuit race course — 60 miles of Black Hills gravel."
    },
    "HC to Rock to RC.gpx": {
        "name": "Hill City — Rockerville — Rapid City",
        "category": "road",
        "region": "Black Hills",
        "description": "Scenic road ride connecting Hill City, Rockerville, and Rapid City through the Hills."
    },
    "2022Dakota50v2.gpx": {
        "name": "Dakota 50",
        "category": "gravel",
        "region": "Black Hills",
        "description": "Annual Dakota 50 gravel race with beautiful Black Hills scenery."
    },
    "Fat_Pursuit_60k_2022_FINAL.gpx": {
        "name": "Fat Pursuit 60K",
        "category": "fatbike",
        "region": "Black Hills",
        "description": "Winter fat bike endurance race through snowy Black Hills trails."
    },
    "Sturgis_To_RCHalfie.gpx": {
        "name": "Sturgis to Rapid City",
        "category": "road",
        "region": "Sturgis",
        "description": "Road ride from Sturgis down to Rapid City along the I-90 corridor."
    },
    "Deadwood_Blue__21_.gpx": {
        "name": "Deadwood Blue Loop",
        "category": "gravel",
        "region": "Deadwood",
        "description": "Scenic gravel loop through the gulches and hills around Deadwood."
    },
    "Jenny_Camp.gpx": {
        "name": "Jenny Gulch Gravel",
        "category": "gravel",
        "region": "Black Hills",
        "description": "Deep gravel ride to Jenny Gulch campground through remote Hills terrain."
    },
    "Rush_To_HC_To_Home.gpx": {
        "name": "Rushmore — Hill City — Home",
        "category": "road",
        "region": "Black Hills",
        "description": "Road ride from Mount Rushmore through Hill City and back to Rapid City."
    },
    "Two Day Century.gpx": {
        "name": "Two-Day Century",
        "category": "road",
        "region": "Black Hills",
        "description": "Epic two-day, 100+ mile road ride through the entire Black Hills."
    },
    "spearfish280-2023-08-14.gpx": {
        "name": "Spearfish Canyon Epic",
        "category": "road",
        "region": "Spearfish",
        "description": "Multi-day ride through Spearfish Canyon and surrounding Black Hills country."
    },

    # === NEW MOUNTAIN BIKE + GRAVEL ROUTES (full resolution) ===
    "8_o_7_2024_group.gpx.gpx": {
        "id": "8-o-7-2024-group",
        "name": "8 Over 7",
        "category": "trail",
        "region": "Black Hills",
        "description": "Community group ride of the classic 8-Over-7 singletrack link-up in the Black Hills. Flows through pine forest and technical terrain.",
        "max_points": None,
    },
    "8over7DIRTv.1.gpx.gpx": {
        "id": "8over7-dirt-v1",
        "name": "8 Over 7 Dirt v.1",
        "category": "trail",
        "region": "Black Hills",
        "description": "Dirt variant of the 8-Over-7 route — rugged singletrack threading through high-country Black Hills terrain with sustained climbing.",
        "max_points": None,
    },
    "Black_Hills_Pay_Dirt.gpx": {
        "id": "black-hills-pay-dirt",
        "name": "Black Hills Pay Dirt",
        "category": "gravel",
        "region": "Black Hills",
        "description": "Pay Dirt gravel route through the heart of the Black Hills. Mining history meets modern cycling on remote forest roads.",
        "max_points": None,
    },
    "Dakota_Five-O_Reverse.gpx": {
        "id": "dakota-five-o-reverse",
        "name": "Dakota Five-O Reverse",
        "category": "gravel",
        "region": "Black Hills",
        "description": "Reverse version of the legendary Dakota Five-O race course — 50 miles of Black Hills singletrack, gravel, and mixed terrain.",
        "max_points": None,
    },
    "Great_Plains_Gravel.gpx": {
        "id": "great-plains-gravel",
        "name": "Great Plains Gravel",
        "category": "gravel",
        "region": "Great Plains",
        "description": "Wide-open gravel adventure across the northern Great Plains. Minimal traffic, big sky, and relentless horizon.",
        "max_points": None,
    },
    "Pine_Island_Ponderosa_Escapade.gpx": {
        "id": "pine-island-ponderosa-escapade",
        "name": "Pine Island Ponderosa Escapade",
        "category": "trail",
        "region": "Black Hills",
        "description": "Meandering trail ride through ponderosa pine forest in the southern Black Hills. Technical singletrack with rewarding views.",
        "max_points": None,
    },

    # === FIT FILES ===
    "2020 Dead Swede 60 Mile Course_course.fit": {
        "name": "Dead Swede 60",
        "category": "gravel",
        "region": "Black Hills",
        "description": "60-mile gravel race course through the Black Hills backcountry."
    },
    "BH Expedition .fit": {
        "name": "Black Hills Expedition",
        "category": "gravel",
        "region": "Black Hills",
        "description": "Multi-day bikepacking expedition route through the Black Hills."
    },
    "Brewvet.fit": {
        "name": "Brewvet Rally",
        "category": "gravel",
        "region": "Black Hills",
        "description": "Brewery-to-brewery gravel rally through Black Hills craft beer country."
    },
    "Custer Med.fit": {
        "name": "Custer Medium Loop",
        "category": "road",
        "region": "Custer",
        "description": "Medium road loop through Custer State Park."
    },
    "Dak 50 2021_course.fit": {
        "name": "Dakota 50 (2021 Course)",
        "category": "gravel",
        "region": "Black Hills",
        "description": "2021 edition of the Dakota 50 gravel race course."
    },
    "Deadmans_course.fit": {
        "name": "Deadman's Gravel",
        "category": "gravel",
        "region": "Black Hills",
        "description": "Deadman's Gulch gravel course through rugged Hills terrain."
    },
    "Gmaps Pedometer Track_course.fit": {
        "name": "Rapid City Bike Path",
        "category": "road",
        "difficulty": "easy",
        "region": "Rapid City",
        "description": "Urban bike path route through Rapid City."
    },
    "Hill City 2.fit": {
        "name": "Hill City Short Loop",
        "category": "road",
        "region": "Hill City",
        "description": "Quick road loop around Hill City."
    },
    "Hill City.fit": {
        "name": "Hill City Explorer",
        "category": "road",
        "region": "Hill City",
        "description": "Road ride exploring the Hill City area and surroundings."
    },
    "Hilloween 50_course.fit": {
        "name": "Hilloween 50",
        "category": "gravel",
        "region": "Black Hills",
        "description": "Halloween-themed 50-mile gravel ride through the Black Hills."
    },
    "Lead Med.fit": {
        "name": "Lead-Deadwood Ride",
        "category": "road",
        "region": "Lead",
        "description": "Road ride through the historic mining towns of Lead and Deadwood."
    },
    "Merit _course.fit": {
        "name": "Merit Mine Trail",
        "category": "trail",
        "region": "Black Hills",
        "description": "Trail ride near the old Merit Mine area in the Black Hills."
    },
    "Mickelson-Trail_course.fit": {
        "name": "Mickelson Trail",
        "category": "trail",
        "region": "Black Hills",
        "description": "Section of the George S. Mickelson Trail — converted rail trail through the Hills."
    },
    "Nemo 22_course.fit": {
        "name": "Nemo Loop",
        "category": "gravel",
        "region": "Nemo",
        "description": "Gravel loop through Nemo and surrounding Black Hills forest."
    },
    "Piedmont.fit": {
        "name": "Piedmont Quick Spin",
        "category": "gravel",
        "difficulty": "easy",
        "region": "Piedmont",
        "description": "Short gravel spin through the Piedmont area."
    },
    "Rapid Bike Pack.fit": {
        "name": "Rapid City Bikepacking",
        "category": "gravel",
        "region": "Rapid City",
        "description": "Bikepacking route starting from Rapid City into the Hills."
    },
    "Rochford.fit": {
        "name": "Rochford Loop",
        "category": "gravel",
        "region": "Rochford",
        "description": "Gravel loop through the ghost town of Rochford and surrounding forest."
    },
    "Rush_To_RC.fit": {
        "name": "Rushmore to Rapid City",
        "category": "road",
        "region": "Black Hills",
        "description": "Road ride from Mount Rushmore directly to Rapid City."
    },
    "Spearfish 2.fit": {
        "name": "Spearfish Short Loop",
        "category": "road",
        "region": "Spearfish",
        "description": "Short road loop around Spearfish and the canyon entrance."
    },
    "Spearfish.fit": {
        "name": "Spearfish Canyon Ride",
        "category": "road",
        "region": "Spearfish",
        "description": "Road ride through beautiful Spearfish Canyon."
    },
    "Sturgis.fit": {
        "name": "Sturgis Quick Loop",
        "category": "road",
        "region": "Sturgis",
        "description": "Quick road loop around Sturgis and Fort Meade."
    },
    "Wood To Rc_course.fit": {
        "name": "Woodle Gulch to Rapid City",
        "category": "gravel",
        "region": "Black Hills",
        "description": "Gravel ride from Woodle Gulch area into Rapid City."
    },
}


def haversine(lat1, lon1, lat2, lon2):
    """Calculate distance between two GPS points in miles."""
    R = 3959  # Earth radius in miles
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    c = 2 * math.asin(math.sqrt(a))
    return R * c


def meters_to_feet(m):
    return m * 3.28084


def parse_gpx(filepath):
    """Parse a GPX file and extract trackpoints."""
    tree = ET.parse(filepath)
    root = tree.getroot()

    # Handle GPX namespace
    ns = ""
    if root.tag.startswith("{"):
        ns = root.tag.split("}")[0] + "}"

    trackpoints = []

    # Try tracks first
    for trk in root.findall(f".//{ns}trk"):
        for trkseg in trk.findall(f"{ns}trkseg"):
            for trkpt in trkseg.findall(f"{ns}trkpt"):
                lat = float(trkpt.get("lat"))
                lon = float(trkpt.get("lon"))
                ele_elem = trkpt.find(f"{ns}ele")
                ele = float(ele_elem.text) if ele_elem is not None else None
                trackpoints.append({"lat": lat, "lon": lon, "ele": ele})

    # Try routes if no tracks found
    if not trackpoints:
        for rte in root.findall(f".//{ns}rte"):
            for rtept in rte.findall(f"{ns}rtept"):
                lat = float(rtept.get("lat"))
                lon = float(rtept.get("lon"))
                ele_elem = rtept.find(f"{ns}ele")
                ele = float(ele_elem.text) if ele_elem is not None else None
                trackpoints.append({"lat": lat, "lon": lon, "ele": ele})

    return trackpoints


def parse_fit(filepath):
    """Parse a FIT file and extract trackpoints using fitdecode."""
    try:
        import fitdecode
    except ImportError:
        print(f"    SKIPPED: fitdecode not installed (pip3 install fitdecode)")
        return []

    trackpoints = []
    with fitdecode.FitReader(filepath) as fit:
        for frame in fit:
            if not isinstance(frame, fitdecode.FitDataMessage):
                continue
            if frame.name == 'record':
                lat_raw = frame.get_value('position_lat')
                lon_raw = frame.get_value('position_long')
                if lat_raw is not None and lon_raw is not None:
                    # FIT uses semicircles — convert to degrees
                    lat = lat_raw * (180.0 / 2**31)
                    lon = lon_raw * (180.0 / 2**31)
                    ele = frame.get_value('altitude') or frame.get_value('enhanced_altitude')
                    trackpoints.append({"lat": lat, "lon": lon, "ele": ele})

    return trackpoints


def calculate_stats(trackpoints):
    """Calculate distance and elevation gain from trackpoints."""
    total_distance = 0.0
    elevation_gain = 0.0

    for i in range(1, len(trackpoints)):
        prev = trackpoints[i - 1]
        curr = trackpoints[i]

        # Distance
        total_distance += haversine(prev["lat"], prev["lon"], curr["lat"], curr["lon"])

        # Elevation gain (only count ascents)
        if prev["ele"] is not None and curr["ele"] is not None:
            diff = curr["ele"] - prev["ele"]
            if diff > 0:
                elevation_gain += diff

    return round(total_distance, 1), round(meters_to_feet(elevation_gain))


def simplify_trackpoints(trackpoints, max_points=500):
    """Reduce trackpoints for app bundle size using nth-point sampling."""
    if len(trackpoints) <= max_points:
        return trackpoints

    step = len(trackpoints) / max_points
    simplified = []
    for i in range(max_points):
        idx = int(i * step)
        simplified.append(trackpoints[idx])

    # Always include last point
    if simplified[-1] != trackpoints[-1]:
        simplified.append(trackpoints[-1])

    return simplified


def classify_difficulty(distance_miles, elevation_feet):
    """Classify route difficulty based on distance and elevation."""
    if distance_miles > 80 or elevation_feet > 6000:
        return "expert"
    elif distance_miles > 40 or elevation_feet > 3000:
        return "hard"
    elif distance_miles > 20 or elevation_feet > 1500:
        return "moderate"
    else:
        return "easy"


def main():
    routes = []
    all_files = sorted(os.listdir(GPX_DIR))
    gpx_files = [f for f in all_files if f.lower().endswith(".gpx")]
    fit_files = [f for f in all_files if f.lower().endswith(".fit")]

    print(f"Found {len(gpx_files)} GPX files + {len(fit_files)} FIT files = {len(gpx_files) + len(fit_files)} total")

    for filename in gpx_files + fit_files:
        filepath = os.path.join(GPX_DIR, filename)
        print(f"  Processing: {filename}")

        try:
            if filename.lower().endswith(".gpx"):
                trackpoints = parse_gpx(filepath)
            else:
                trackpoints = parse_fit(filepath)
        except Exception as e:
            print(f"    ERROR: {e}")
            continue

        if not trackpoints or len(trackpoints) < 5:
            print(f"    SKIPPED: Insufficient trackpoints ({len(trackpoints)})")
            continue

        distance, elevation = calculate_stats(trackpoints)
        meta = ROUTE_METADATA.get(filename, {})

        # Generate ID from filename (or use metadata override)
        base_id = os.path.splitext(filename)[0].lower().replace(" ", "-").replace("_", "-")
        route_id = meta.get("id", base_id)

        # Simplify trackpoints — use per-route max_points if set (None = full resolution)
        max_pts = meta.get("max_points", 500)
        simplified = simplify_trackpoints(trackpoints, max_points=max_pts) if max_pts is not None else trackpoints

        # Format trackpoints as compact arrays [lat, lon, ele]
        compact_trackpoints = []
        for tp in simplified:
            compact_trackpoints.append([
                round(tp["lat"], 6),
                round(tp["lon"], 6),
                round(tp["ele"], 1) if tp["ele"] is not None else 0
            ])

        # Start coordinate
        start = trackpoints[0]
        start_coord = {
            "latitude": round(start["lat"], 6),
            "longitude": round(start["lon"], 6)
        }

        # Auto-classify if no metadata
        difficulty = meta.get("difficulty", classify_difficulty(distance, elevation))
        name = meta.get("name", os.path.splitext(filename)[0].replace("_", " ").replace("-", " ").title())

        route = {
            "id": route_id,
            "name": name,
            "difficulty": difficulty,
            "category": meta.get("category", "gravel"),
            "distanceMiles": distance,
            "elevationGainFeet": elevation,
            "region": meta.get("region", "Black Hills"),
            "description": meta.get("description", f"Cycling route in the Black Hills region."),
            "startCoordinate": start_coord,
            "trackpoints": compact_trackpoints,
        }

        routes.append(route)
        print(f"    OK: {name} - {distance}mi, {elevation}ft gain, {len(compact_trackpoints)} pts ({difficulty})")

    # Sort by name
    routes.sort(key=lambda r: r["name"])

    # Write output
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    with open(OUTPUT, "w") as f:
        json.dump(routes, f, indent=2)

    print(f"\nWrote {len(routes)} routes to {OUTPUT}")
    print(f"File size: {os.path.getsize(OUTPUT) / 1024:.1f} KB")


if __name__ == "__main__":
    main()
