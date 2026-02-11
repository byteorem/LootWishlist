# /// script
# requires-python = ">=3.10"
# dependencies = ["requests"]
# ///
"""
Export static EJ data from Wago.tools DB2 CSVs into Data/StaticData.lua.

Usage:
    uv run tools/export_static_data.py           # Skip if data unchanged
    uv run tools/export_static_data.py --force    # Always regenerate
    uv run tools/export_static_data.py --check    # Check freshness (no write)
"""

import csv
import hashlib
import io
import os
import re
import sys

import requests

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
OUTPUT_PATH = os.path.join(PROJECT_ROOT, "Data", "StaticData.lua")

BASE_URL = "https://wago.tools/db2"
TABLES = [
    "JournalTier",
    "JournalTierXInstance",
    "JournalInstance",
    "JournalEncounter",
    "Map",
    "MapDifficulty",
    "Difficulty",
]

# Tiers to exclude
EXCLUDE_TIER_IDS = set()

# Difficulty IDs to explicitly exclude
EXCLUDE_DIFFICULTY_IDS = {
    8,    # Mythic Keystone (not in EJ dropdown)
    18,   # Event
    19,   # Event
    232,  # Event
    205,  # Follower
    216,  # Quest
    220,  # Story
    236,  # Lorewalking
    241,  # Lorewalking
}

# Only include dungeon (1) and raid (2) instance types for difficulties
VALID_DIFFICULTY_INSTANCE_TYPES = {1, 2}


def download_csv(table_name: str) -> str:
    url = f"{BASE_URL}/{table_name}/csv"
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    return resp.text


def parse_csv(text: str) -> list[dict]:
    reader = csv.DictReader(io.StringIO(text))
    return list(reader)


def get_stored_hash() -> str | None:
    if not os.path.exists(OUTPUT_PATH):
        return None
    with open(OUTPUT_PATH, "r") as f:
        first_line = f.readline()
    m = re.match(r"^-- Hash: ([a-f0-9]+)", first_line)
    return m.group(1) if m else None


def lua_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main():
    force = "--force" in sys.argv
    check_only = "--check" in sys.argv

    # Download all CSVs
    print("Downloading CSVs from wago.tools...")
    raw_csvs = {}
    for table in TABLES:
        print(f"  {table}...")
        raw_csvs[table] = download_csv(table)

    # Compute hash of concatenated CSV content
    hasher = hashlib.sha256()
    for table in TABLES:
        hasher.update(raw_csvs[table].encode())
    new_hash = hasher.hexdigest()

    # Check mode: compare hashes and exit
    if check_only:
        stored_hash = get_stored_hash()
        if stored_hash == new_hash:
            print(f"Static data is up to date (hash: {new_hash[:12]}...).")
            sys.exit(0)
        else:
            print("STALE: Data/StaticData.lua does not match upstream sources.")
            print(f"  Stored hash: {stored_hash or '(missing)'}")
            print(f"  Current hash: {new_hash}")
            print("  Regenerate with: uv run tools/export_static_data.py --force")
            sys.exit(1)

    # Staleness check
    if not force:
        stored_hash = get_stored_hash()
        if stored_hash == new_hash:
            print("Static data is up to date.")
            return

    print("Parsing CSV data...")
    data = {table: parse_csv(raw_csvs[table]) for table in TABLES}

    # Build lookup maps
    # Maps
    map_by_id = {}
    for row in data["Map"]:
        map_id = int(row["ID"])
        instance_type = int(row["InstanceType"])
        map_by_id[map_id] = {"instanceType": instance_type}

    # Difficulties
    difficulty_by_id = {}
    for row in data["Difficulty"]:
        diff_id = int(row["ID"])
        name = row["Name_lang"]
        instance_type = int(row["InstanceType"])
        order = int(row["OrderIndex"])
        difficulty_by_id[diff_id] = {
            "id": diff_id,
            "name": name,
            "instanceType": instance_type,
            "order": order,
        }

    # Filter difficulties: only dungeon/raid instance types, exclude specific IDs
    valid_difficulties = {}
    for diff_id, diff in difficulty_by_id.items():
        if diff_id in EXCLUDE_DIFFICULTY_IDS:
            continue
        if diff["instanceType"] not in VALID_DIFFICULTY_INSTANCE_TYPES:
            continue
        valid_difficulties[diff_id] = diff

    # MapDifficulty: map ID -> list of valid difficulty IDs
    map_difficulties = {}
    for row in data["MapDifficulty"]:
        map_id = int(row["MapID"])
        diff_id = int(row["DifficultyID"])
        if diff_id in valid_difficulties:
            map_difficulties.setdefault(map_id, set()).add(diff_id)

    # JournalInstance
    instance_by_id = {}
    for row in data["JournalInstance"]:
        inst_id = int(row["ID"])
        name = row["Name_lang"]
        map_id = int(row["MapID"])
        flags = int(row["Flags"])
        should_display_difficulty = not bool(flags & 0x2)

        map_info = map_by_id.get(map_id, {})
        instance_type = map_info.get("instanceType", 0)
        is_raid = instance_type == 2

        # Get valid difficulties for this instance's map
        inst_diffs = []
        if map_id in map_difficulties:
            for diff_id in sorted(map_difficulties[map_id]):
                d = valid_difficulties[diff_id]
                inst_diffs.append({"id": diff_id, "name": d["name"], "order": d["order"]})
            inst_diffs.sort(key=lambda x: x["order"])

        instance_by_id[inst_id] = {
            "id": inst_id,
            "name": name,
            "isRaid": is_raid,
            "shouldDisplayDifficulty": should_display_difficulty,
            "mapID": map_id,
            "difficulties": inst_diffs,
        }

    # JournalTier
    tiers = []
    for row in data["JournalTier"]:
        tier_id = int(row["ID"])
        if tier_id in EXCLUDE_TIER_IDS:
            continue
        name = row["Name_lang"]
        expansion = int(row["Expansion"])
        tiers.append({"id": tier_id, "name": name, "expansion": expansion})

    # Sort newest first (highest expansion value first)
    tiers.sort(key=lambda t: t["expansion"], reverse=True)

    # JournalTierXInstance: tier -> instances
    tier_instances = {}
    for row in data["JournalTierXInstance"]:
        tier_id = int(row["JournalTierID"])
        inst_id = int(row["JournalInstanceID"])
        order = int(row["OrderIndex"])

        if tier_id in EXCLUDE_TIER_IDS:
            continue
        if inst_id not in instance_by_id:
            continue

        inst = instance_by_id[inst_id]
        entry = {"id": inst_id, "name": inst["name"], "order": order}

        tier_instances.setdefault(tier_id, {"raid": [], "dungeon": []})
        key = "raid" if inst["isRaid"] else "dungeon"
        tier_instances[tier_id][key].append(entry)

    # Sort instances within each tier by order
    for tier_id in tier_instances:
        tier_instances[tier_id]["raid"].sort(key=lambda x: x["order"])
        tier_instances[tier_id]["dungeon"].sort(key=lambda x: x["order"])

    # JournalEncounter: instance -> encounters
    encounters_by_instance = {}
    for row in data["JournalEncounter"]:
        enc_id = int(row["ID"])
        name = row["Name_lang"]
        inst_id = int(row["JournalInstanceID"])
        order = int(row["OrderIndex"])

        encounters_by_instance.setdefault(inst_id, []).append({
            "id": enc_id,
            "name": name,
            "order": order,
        })

    for inst_id in encounters_by_instance:
        encounters_by_instance[inst_id].sort(key=lambda x: x["order"])

    # Generate Lua output
    print("Generating Data/StaticData.lua...")
    lines = []
    lines.append(f'-- Hash: {new_hash}')
    lines.append("-- Generated by tools/export_static_data.py — DO NOT EDIT")
    lines.append("")
    lines.append("local _, ns = ...")
    lines.append("")
    lines.append("ns.StaticData = {")

    # Tiers
    lines.append("    tiers = {")
    for tier in tiers:
        lines.append(f'        {{name = "{lua_escape(tier["name"])}", journalTierID = {tier["id"]}}},')
    lines.append("    },")

    # Instances
    lines.append("    instances = {")
    for inst_id in sorted(instance_by_id.keys()):
        inst = instance_by_id[inst_id]
        is_raid = "true" if inst["isRaid"] else "false"
        sdd = "true" if inst["shouldDisplayDifficulty"] else "false"
        lines.append(
            f'        [{inst_id}] = {{name = "{lua_escape(inst["name"])}", '
            f"isRaid = {is_raid}, shouldDisplayDifficulty = {sdd}, "
            f'mapID = {inst["mapID"]}}},')
    lines.append("    },")

    # Tier instances
    lines.append("    tierInstances = {")
    for tier in tiers:
        tid = tier["id"]
        if tid not in tier_instances:
            continue
        ti = tier_instances[tid]
        lines.append(f"        [{tid}] = {{")
        lines.append("            raid = {")
        for entry in ti["raid"]:
            lines.append(
                f'                {{id = {entry["id"]}, name = "{lua_escape(entry["name"])}", '
                f'order = {entry["order"]}}},')
        lines.append("            },")
        lines.append("            dungeon = {")
        for entry in ti["dungeon"]:
            lines.append(
                f'                {{id = {entry["id"]}, name = "{lua_escape(entry["name"])}", '
                f'order = {entry["order"]}}},')
        lines.append("            },")
        lines.append("        },")
    lines.append("    },")

    # Instance difficulties
    lines.append("    instanceDifficulties = {")
    for inst_id in sorted(instance_by_id.keys()):
        inst = instance_by_id[inst_id]
        diffs = inst["difficulties"]
        if not diffs:
            continue
        entries = ", ".join(
            f'{{id = {d["id"]}, name = "{lua_escape(d["name"])}", order = {d["order"]}}}'
            for d in diffs
        )
        lines.append(f"        [{inst_id}] = {{{entries}}},")
    lines.append("    },")

    # Encounters
    lines.append("    encounters = {")
    for inst_id in sorted(encounters_by_instance.keys()):
        encs = encounters_by_instance[inst_id]
        entries = ", ".join(
            f'{{id = {e["id"]}, name = "{lua_escape(e["name"])}", order = {e["order"]}}}'
            for e in encs
        )
        lines.append(f"        [{inst_id}] = {{{entries}}},")
    lines.append("    },")

    # Difficulties (flat lookup)
    lines.append("    difficulties = {")
    for diff_id in sorted(valid_difficulties.keys()):
        d = valid_difficulties[diff_id]
        lines.append(
            f'        [{diff_id}] = {{name = "{lua_escape(d["name"])}", order = {d["order"]}}},')
    lines.append("    },")

    lines.append("}")
    lines.append("")

    # Write output
    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w") as f:
        f.write("\n".join(lines))

    print(f"Written to {OUTPUT_PATH}")
    print(f"  {len(tiers)} tiers")
    print(f"  {len(instance_by_id)} instances")
    print(f"  {sum(len(v) for v in encounters_by_instance.values())} encounters")
    print(f"  {len(valid_difficulties)} difficulties")


if __name__ == "__main__":
    main()
