#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "requests",
# ]
# ///
"""
Generate compressed static data for LootWishlist addon.
Fetches data from wago.tools DB2 CSV exports and outputs Lua-compatible compressed data.

Usage: uv run scripts/generate-data.py
Output: Data/Compressed.lua
"""

import csv
import io
import json
import zlib
import base64
import requests
from collections import defaultdict

WAGO_BASE = "https://wago.tools/db2"

# Tables we need to fetch
TABLES = [
    "JournalTier",
    "JournalInstance",
    "JournalTierXInstance",
    "JournalEncounter",
    "JournalEncounterItem",
    "JournalItemXDifficulty",
    "Difficulty",
    "Map",
]

# Sort order for difficulty dropdown (matches Encounter Journal)
DIFFICULTY_ORDER = {
    # Dungeons: Normal, Heroic, Mythic, Mythic Keystone
    1: 1,   # Normal
    2: 2,   # Heroic
    23: 3,  # Mythic
    8: 4,   # Mythic Keystone

    # Raids: LFR, Normal, Heroic, Mythic
    17: 10,  # LFR
    14: 11,  # Normal
    15: 12,  # Heroic
    16: 13,  # Mythic

    # Legacy (order by ID as fallback)
    3: 20,   # 10 Player
    4: 21,   # 25 Player
    5: 22,   # 10 Player (Heroic)
    6: 23,   # 25 Player (Heroic)
    7: 24,   # Legacy LFR
    9: 25,   # 40 Player
    24: 30,  # Timewalking Dungeon
    33: 31,  # Timewalking Raid
}


def fetch_csv(table: str) -> list[dict]:
    """Fetch CSV data from wago.tools and parse into list of dicts."""
    url = f"{WAGO_BASE}/{table}/csv"
    print(f"Fetching {table}...")
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()

    reader = csv.DictReader(io.StringIO(resp.text))
    return list(reader)


def compress_and_encode(data: dict) -> str:
    """Compress JSON data with raw DEFLATE and base64 encode."""
    json_str = json.dumps(data, separators=(',', ':'))
    # Use raw DEFLATE (wbits=-15) - WoW's C_EncodingUtil expects this format
    compressor = zlib.compressobj(level=9, wbits=-15)
    compressed = compressor.compress(json_str.encode('utf-8')) + compressor.flush()
    return base64.b64encode(compressed).decode('ascii')


def process_tiers(journal_tiers: list[dict]) -> dict:
    """Process JournalTier into {tierID: {name, order}}."""
    tiers = {}
    for row in journal_tiers:
        tier_id = row.get("ID")
        name = row.get("Name_lang")
        if tier_id and name:
            tiers[tier_id] = {
                "name": name,
                "order": int(tier_id),  # ID is roughly order
            }
    return tiers


def process_instances(journal_instances: list[dict], tier_x_instance: list[dict], maps: list[dict]) -> dict:
    """Process JournalInstance + JournalTierXInstance into {instanceID: {name, tierID, isRaid, order}}.

    Instances can appear in multiple tiers (e.g., both "The War Within" and "Current Season").
    We prefer the expansion tier over "Current Season" (tier 505) to keep instances grouped
    with their actual expansion.
    """

    # Build map ID -> instance type lookup
    map_types = {}
    for row in maps:
        map_id = row.get("ID")
        instance_type = row.get("InstanceType")
        if map_id and instance_type:
            map_types[map_id] = int(instance_type)

    # Build instance -> tier mapping (collect all tiers per instance)
    # Tier 505 = "Current Season" - we want to deprioritize this
    CURRENT_SEASON_TIER = 505

    instance_all_tiers = defaultdict(list)
    instance_orders = {}
    for row in tier_x_instance:
        instance_id = row.get("JournalInstanceID")
        tier_id = row.get("JournalTierID")
        order = row.get("OrderIndex", "0")
        if instance_id and tier_id:
            instance_all_tiers[instance_id].append(int(tier_id))
            # Keep order from first entry (or highest tier)
            if instance_id not in instance_orders:
                instance_orders[instance_id] = int(order)

    # Pick best tier for each instance (prefer non-Current Season)
    instance_tiers = {}
    for instance_id, tiers in instance_all_tiers.items():
        non_season_tiers = [t for t in tiers if t != CURRENT_SEASON_TIER]
        if non_season_tiers:
            # Pick the highest non-season tier (most recent expansion)
            instance_tiers[instance_id] = max(non_season_tiers)
        else:
            # Only in Current Season tier
            instance_tiers[instance_id] = CURRENT_SEASON_TIER

    instances = {}
    for row in journal_instances:
        instance_id = row.get("ID")
        name = row.get("Name_lang")
        map_id = row.get("MapID")

        if not instance_id or not name:
            continue

        tier_id = instance_tiers.get(instance_id)
        if not tier_id:
            continue  # Skip instances not in any tier

        # Determine if raid (InstanceType: 1=dungeon, 2=raid)
        instance_type = map_types.get(map_id, 1)
        is_raid = instance_type == 2

        instances[instance_id] = {
            "name": name,
            "tierID": tier_id,
            "isRaid": is_raid,
            "order": instance_orders.get(instance_id, 0),
        }

    return instances


def process_encounters(journal_encounters: list[dict]) -> dict:
    """Process JournalEncounter into {encounterID: {name, instanceID, order}}."""
    encounters = {}
    for row in journal_encounters:
        encounter_id = row.get("ID")
        name = row.get("Name_lang")
        instance_id = row.get("JournalInstanceID")
        order = row.get("OrderIndex", "0")

        if encounter_id and name and instance_id:
            encounters[encounter_id] = {
                "name": name,
                "instanceID": int(instance_id),
                "order": int(order),
            }
    return encounters


def process_encounter_loot(journal_encounter_items: list[dict]) -> dict:
    """Process JournalEncounterItem into {encounterID: [itemID, ...]}."""
    loot = defaultdict(list)
    for row in journal_encounter_items:
        encounter_id = row.get("JournalEncounterID")
        item_id = row.get("ItemID")

        if encounter_id and item_id:
            item_id_int = int(item_id)
            if item_id_int > 0:  # Skip invalid items
                loot[encounter_id].append(item_id_int)

    # Convert to regular dict
    return {k: v for k, v in loot.items()}


def process_difficulties(difficulty_table: list[dict]) -> dict:
    """Process Difficulty table into {difficultyID: {name, type, track}}."""

    # Map difficulty types/flags to track
    # Based on WoW's difficulty system
    TRACK_MAP = {
        # Dungeons
        1: {"name": "Normal", "type": "dungeon", "track": "adventurer"},
        2: {"name": "Heroic", "type": "dungeon", "track": "champion"},
        23: {"name": "Mythic", "type": "dungeon", "track": "champion"},
        8: {"name": "Mythic Keystone", "type": "dungeon", "track": "hero"},

        # Raids
        17: {"name": "LFR", "type": "raid", "track": "veteran"},
        14: {"name": "Normal", "type": "raid", "track": "champion"},
        15: {"name": "Heroic", "type": "raid", "track": "hero"},
        16: {"name": "Mythic", "type": "raid", "track": "myth"},

        # Legacy raids
        3: {"name": "10 Player", "type": "raid", "track": "champion"},
        4: {"name": "25 Player", "type": "raid", "track": "champion"},
        5: {"name": "10 Player (Heroic)", "type": "raid", "track": "hero"},
        6: {"name": "25 Player (Heroic)", "type": "raid", "track": "hero"},
        7: {"name": "Legacy LFR", "type": "raid", "track": "veteran"},
        9: {"name": "40 Player", "type": "raid", "track": "champion"},

        # Timewalking
        24: {"name": "Timewalking", "type": "dungeon", "track": "adventurer"},
        33: {"name": "Timewalking", "type": "raid", "track": "champion"},

        # Other
        18: {"name": "Event", "type": "event", "track": "adventurer"},
        19: {"name": "Event", "type": "event", "track": "adventurer"},
        20: {"name": "Event Scenario", "type": "event", "track": "adventurer"},
    }

    difficulties = {}
    for row in difficulty_table:
        diff_id = row.get("ID")
        name = row.get("Name_lang")

        if not diff_id:
            continue

        diff_id_int = int(diff_id)

        # Use our mapping if available, otherwise use raw data
        if diff_id_int in TRACK_MAP:
            difficulties[diff_id] = TRACK_MAP[diff_id_int]
        elif name:
            # Fallback: guess based on name
            is_raid = "Raid" in name or "Player" in name or "LFR" in name
            difficulties[diff_id] = {
                "name": name,
                "type": "raid" if is_raid else "dungeon",
                "track": "champion",
            }

    return difficulties


def process_instance_difficulties(
    journal_instances: list[dict],
    item_x_difficulty: list[dict],
    encounter_items: list[dict],
    encounters: dict,
    instances: dict,
    maps: list[dict]
) -> dict:
    """
    Process to determine which difficulties are valid for each instance.
    Uses JournalItemXDifficulty junction table + DifficultyMask field.

    Strategy:
    1. Build enc_item_id -> encounter_id -> instance_id mapping
    2. For items with DifficultyMask=-1, apply default difficulties based on instance type
    3. For items with specific masks, use JournalItemXDifficulty entries
    """

    # Build map ID -> instance type lookup
    map_types = {}
    for row in maps:
        map_id = row.get("ID")
        instance_type = row.get("InstanceType")
        if map_id and instance_type:
            map_types[map_id] = int(instance_type)

    # Build encounter -> instance mapping
    encounter_to_instance = {}
    for enc_id, enc_data in encounters.items():
        encounter_to_instance[int(enc_id)] = enc_data["instanceID"]

    # Build enc_item_id -> encounter_id mapping (note: uses ID, not ItemID)
    enc_item_to_encounter = {}
    enc_item_diff_masks = {}
    for row in encounter_items:
        enc_item_id = row.get("ID")
        encounter_id = row.get("JournalEncounterID")
        diff_mask = row.get("DifficultyMask", "0")
        if enc_item_id and encounter_id:
            enc_item_to_encounter[int(enc_item_id)] = int(encounter_id)
            enc_item_diff_masks[int(enc_item_id)] = int(diff_mask)

    # Build item_x_diff lookup (enc_item_id -> [diff_ids])
    enc_item_to_diffs = defaultdict(set)
    for row in item_x_difficulty:
        enc_item_id = row.get("JournalEncounterItemID")
        diff_id = row.get("DifficultyID")
        if enc_item_id and diff_id:
            enc_item_to_diffs[int(enc_item_id)].add(int(diff_id))

    # Default difficulties by instance type
    # Dungeon (InstanceType=1): Normal, Heroic, Mythic, M+
    # Raid (InstanceType=2): LFR, Normal, Heroic, Mythic
    DEFAULT_DUNGEON_DIFFS = [1, 2, 23, 8]  # Normal, Heroic, Mythic, M+
    DEFAULT_RAID_DIFFS = [17, 14, 15, 16]   # LFR, Normal, Heroic, Mythic

    # Collect difficulties per instance
    instance_diffs = defaultdict(set)

    for enc_item_id, encounter_id in enc_item_to_encounter.items():
        instance_id = encounter_to_instance.get(encounter_id)
        if not instance_id:
            continue

        diff_mask = enc_item_diff_masks.get(enc_item_id, 0)

        # Get explicit difficulties from junction table
        explicit_diffs = enc_item_to_diffs.get(enc_item_id, set())

        if diff_mask == -1 or (diff_mask == 0 and not explicit_diffs):
            # Modern content: use default difficulties based on instance type
            inst_data = instances.get(str(instance_id))
            if inst_data:
                is_raid = inst_data.get("isRaid", False)
                default_diffs = DEFAULT_RAID_DIFFS if is_raid else DEFAULT_DUNGEON_DIFFS
                instance_diffs[str(instance_id)].update(default_diffs)
        elif explicit_diffs:
            # Older content with explicit difficulty entries
            instance_diffs[str(instance_id)].update(explicit_diffs)

    # Convert sets to sorted lists using custom difficulty order
    result = {}
    for inst_id, diffs in instance_diffs.items():
        result[inst_id] = sorted(list(diffs), key=lambda d: DIFFICULTY_ORDER.get(d, 100 + d))

    return result


def generate_lua(compressed_data: dict) -> str:
    """Generate Lua file content with compressed data."""
    lines = [
        "-- LootWishlist Compressed Static Data",
        "-- Generated by scripts/generate-data.py",
        "-- DO NOT EDIT MANUALLY - regenerate with the script",
        "",
        "local _, ns = ...",
        "ns.CompressedData = {",
    ]

    for key, value in compressed_data.items():
        # Split long base64 strings for readability
        lines.append(f'    {key} = "{value}",')

    lines.append("}")
    lines.append("")

    return "\n".join(lines)


def main():
    print("Fetching data from wago.tools...")

    # Fetch all tables
    data = {}
    for table in TABLES:
        data[table] = fetch_csv(table)
        print(f"  {table}: {len(data[table])} rows")

    print("\nProcessing data...")

    # Process encounters first (needed for instance difficulties)
    encounters = process_encounters(data["JournalEncounter"])
    print(f"  Encounters: {len(encounters)}")

    # Process each data type
    tiers = process_tiers(data["JournalTier"])
    print(f"  Tiers: {len(tiers)}")

    instances = process_instances(
        data["JournalInstance"],
        data["JournalTierXInstance"],
        data["Map"]
    )
    print(f"  Instances: {len(instances)}")

    encounter_loot = process_encounter_loot(data["JournalEncounterItem"])
    print(f"  EncounterLoot: {len(encounter_loot)} encounters with loot")

    difficulties = process_difficulties(data["Difficulty"])
    print(f"  Difficulties: {len(difficulties)}")

    instance_diffs = process_instance_difficulties(
        data["JournalInstance"],
        data["JournalItemXDifficulty"],
        data["JournalEncounterItem"],
        encounters,
        instances,
        data["Map"]
    )
    print(f"  InstanceDifficulties: {len(instance_diffs)}")

    print("\nCompressing data...")

    compressed = {
        "Tiers": compress_and_encode(tiers),
        "Instances": compress_and_encode(instances),
        "Encounters": compress_and_encode(encounters),
        "EncounterLoot": compress_and_encode(encounter_loot),
        "Difficulties": compress_and_encode(difficulties),
        "InstanceDifficulties": compress_and_encode(instance_diffs),
    }

    # Calculate sizes
    total_uncompressed = sum(
        len(json.dumps(d, separators=(',', ':')))
        for d in [tiers, instances, encounters, encounter_loot, difficulties, instance_diffs]
    )
    total_compressed = sum(len(v) for v in compressed.values())

    print(f"\nSize summary:")
    print(f"  Uncompressed JSON: {total_uncompressed:,} bytes")
    print(f"  Compressed+Base64: {total_compressed:,} bytes")
    print(f"  Compression ratio: {total_compressed/total_uncompressed:.1%}")

    # Generate Lua file
    lua_content = generate_lua(compressed)

    output_path = "Data/Compressed.lua"
    with open(output_path, "w") as f:
        f.write(lua_content)

    print(f"\nWrote {output_path} ({len(lua_content):,} bytes)")


if __name__ == "__main__":
    main()
