#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["requests"]
# ///
"""Explore wago.tools data structure."""

import csv
import io
import requests
from collections import defaultdict

WAGO_BASE = "https://wago.tools/db2"

def fetch_csv(table: str) -> list[dict]:
    url = f"{WAGO_BASE}/{table}/csv"
    print(f"Fetching {table}...")
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    reader = csv.DictReader(io.StringIO(resp.text))
    return list(reader)

# Fetch key tables
tiers = fetch_csv("JournalTier")
instances = fetch_csv("JournalInstance")
tier_x_instance = fetch_csv("JournalTierXInstance")
difficulties = fetch_csv("Difficulty")
item_x_diff = fetch_csv("JournalItemXDifficulty")

print("\n" + "="*60)
print("JOURNAL TIERS (Expansions)")
print("="*60)
print(f"Columns: {list(tiers[0].keys())}")
for t in sorted(tiers, key=lambda x: int(x.get('ID', 0))):
    print(f"  ID={t.get('ID'):3s} Name={t.get('Name_lang')}")

print("\n" + "="*60)
print("DIFFICULTIES")
print("="*60)
print(f"Columns: {list(difficulties[0].keys())}")
for d in difficulties[:20]:
    print(f"  ID={d.get('ID'):3s} Name={d.get('Name_lang')}")

print("\n" + "="*60)
print("TIER X INSTANCE (by expansion)")
print("="*60)
by_tier = defaultdict(list)
for row in tier_x_instance:
    by_tier[row.get('JournalTierID')].append(row.get('JournalInstanceID'))

# Show last 3 tiers
tier_ids = sorted(by_tier.keys(), key=int, reverse=True)[:3]
for tid in tier_ids:
    tier_name = next((t.get('Name_lang') for t in tiers if t.get('ID') == tid), '?')
    print(f"\nTier {tid} ({tier_name}): {len(by_tier[tid])} instances")
    for inst_id in by_tier[tid][:8]:
        inst_name = next((i.get('Name_lang') for i in instances if i.get('ID') == inst_id), '?')
        print(f"    {inst_id}: {inst_name}")

print("\n" + "="*60)
print("ITEM X DIFFICULTY (sample)")
print("="*60)
print(f"Columns: {list(item_x_diff[0].keys())}")
for row in item_x_diff[:10]:
    print(f"  ItemID={row.get('JournalEncounterItemID')} DiffID={row.get('DifficultyID')}")

# Check JournalEncounterItem table - what's the ID column?
enc_items = fetch_csv("JournalEncounterItem")
print("\n" + "="*60)
print("JOURNAL ENCOUNTER ITEM (sample)")
print("="*60)
print(f"Columns: {list(enc_items[0].keys())}")
for row in enc_items[:10]:
    print(f"  ID={row.get('ID')} ItemID={row.get('ItemID')} EncounterID={row.get('JournalEncounterID')}")

# Check if JournalItemXDifficulty uses ID or ItemID
print("\n" + "="*60)
print("CROSS-REFERENCE: JournalItemXDifficulty.JournalEncounterItemID")
print("="*60)
# Find a sample encounter item and see if its ID appears in item_x_diff
sample_enc_item = enc_items[100]  # Pick a sample
sample_id = sample_enc_item.get('ID')
sample_item_id = sample_enc_item.get('ItemID')
print(f"Sample JournalEncounterItem: ID={sample_id}, ItemID={sample_item_id}")

# Look for this ID in JournalItemXDifficulty
matches_by_id = [r for r in item_x_diff if r.get('JournalEncounterItemID') == sample_id]
matches_by_item_id = [r for r in item_x_diff if r.get('JournalEncounterItemID') == sample_item_id]
print(f"  Matches by JournalEncounterItem.ID: {len(matches_by_id)}")
print(f"  Matches by JournalEncounterItem.ItemID: {len(matches_by_item_id)}")
if matches_by_id:
    print(f"  First match: DifficultyID={matches_by_id[0].get('DifficultyID')}")

# Now check a specific TWW encounter for difficulties
print("\n" + "="*60)
print("TWW PRIORY OF THE SACRED FLAME (ID 1267)")
print("="*60)
encounters = fetch_csv("JournalEncounter")
priory_encounters = [e for e in encounters if e.get('JournalInstanceID') == '1267']
print(f"Found {len(priory_encounters)} encounters:")
for e in priory_encounters:
    print(f"  Encounter ID={e.get('ID')} Name={e.get('Name_lang')}")

# Find loot for first encounter - check DifficultyMask
if priory_encounters:
    enc_id = priory_encounters[0].get('ID')
    print(f"\nLoot for encounter {enc_id} (with DifficultyMask):")
    loot = [i for i in enc_items if i.get('JournalEncounterID') == enc_id]
    for l in loot[:5]:
        item_enc_id = l.get('ID')
        item_id = l.get('ItemID')
        diff_mask = l.get('DifficultyMask', '0')
        # Find difficulties for this item
        diffs = [d.get('DifficultyID') for d in item_x_diff if d.get('JournalEncounterItemID') == item_enc_id]
        print(f"  EncItemID={item_enc_id} ItemID={item_id} DiffMask={diff_mask} Difficulties={diffs}")

# Check JournalInstance table for difficulty info
print("\n" + "="*60)
print("JOURNAL INSTANCE TABLE (sample TWW)")
print("="*60)
inst_data = [i for i in instances if i.get('ID') == '1267']
if inst_data:
    print(f"Columns: {list(inst_data[0].keys())}")
    print(f"Priory: {inst_data[0]}")

# Check an older instance (e.g., from Dragonflight) for comparison
print("\n" + "="*60)
print("DRAGONFLIGHT INSTANCE FOR COMPARISON")
print("="*60)
df_instances = [i for i in instances if i.get('ID') in ['1201', '1203']]  # Algeth'ar Academy or similar
for inst in df_instances:
    print(f"Instance {inst.get('ID')}: {inst.get('Name_lang')}")
    inst_encounters = [e for e in encounters if e.get('JournalInstanceID') == inst.get('ID')]
    if inst_encounters:
        enc_id = inst_encounters[0].get('ID')
        enc_loot = [i for i in enc_items if i.get('JournalEncounterID') == enc_id]
        for l in enc_loot[:3]:
            item_enc_id = l.get('ID')
            diffs = [d.get('DifficultyID') for d in item_x_diff if d.get('JournalEncounterItemID') == item_enc_id]
            print(f"  Item {l.get('ItemID')}: DiffMask={l.get('DifficultyMask')} Diffs={diffs}")

# Check a classic dungeon
print("\n" + "="*60)
print("CLASSIC DEADMINES (ID 63) FOR COMPARISON")
print("="*60)
dm_encounters = [e for e in encounters if e.get('JournalInstanceID') == '63']
if dm_encounters:
    enc_id = dm_encounters[0].get('ID')
    print(f"Encounter: {dm_encounters[0].get('Name_lang')}")
    dm_loot = [i for i in enc_items if i.get('JournalEncounterID') == enc_id]
    for l in dm_loot[:5]:
        item_enc_id = l.get('ID')
        diffs = [d.get('DifficultyID') for d in item_x_diff if d.get('JournalEncounterItemID') == item_enc_id]
        print(f"  Item {l.get('ItemID')}: DiffMask={l.get('DifficultyMask')} Diffs={diffs}")

# Check TWW Raid - Nerub-ar Palace (1273)
print("\n" + "="*60)
print("TWW RAID: NERUB-AR PALACE (ID 1273)")
print("="*60)
nap_encounters = [e for e in encounters if e.get('JournalInstanceID') == '1273']
print(f"Found {len(nap_encounters)} encounters:")
for e in nap_encounters[:3]:
    print(f"  Encounter ID={e.get('ID')} Name={e.get('Name_lang')}")

if nap_encounters:
    enc_id = nap_encounters[0].get('ID')
    nap_loot = [i for i in enc_items if i.get('JournalEncounterID') == enc_id]
    print(f"\nFirst 5 items from {nap_encounters[0].get('Name_lang')}:")
    for l in nap_loot[:5]:
        item_enc_id = l.get('ID')
        diffs = [d.get('DifficultyID') for d in item_x_diff if d.get('JournalEncounterItemID') == item_enc_id]
        print(f"  Item {l.get('ItemID')}: DiffMask={l.get('DifficultyMask')} Diffs={diffs}")

# Check older raid - Vault of the Incarnates (1200)
print("\n" + "="*60)
print("DF RAID: VAULT OF THE INCARNATES (ID 1200)")
print("="*60)
voti_encounters = [e for e in encounters if e.get('JournalInstanceID') == '1200']
if voti_encounters:
    enc_id = voti_encounters[0].get('ID')
    voti_loot = [i for i in enc_items if i.get('JournalEncounterID') == enc_id]
    print(f"First 5 items from {voti_encounters[0].get('Name_lang')}:")
    for l in voti_loot[:5]:
        item_enc_id = l.get('ID')
        diffs = [d.get('DifficultyID') for d in item_x_diff if d.get('JournalEncounterItemID') == item_enc_id]
        print(f"  Item {l.get('ItemID')}: DiffMask={l.get('DifficultyMask')} Diffs={diffs}")

# How many instances have DiffMask=-1 items?
print("\n" + "="*60)
print("SUMMARY: DifficultyMask usage")
print("="*60)
mask_counts = defaultdict(int)
for item in enc_items:
    mask = item.get('DifficultyMask', '0')
    mask_counts[mask] += 1
for mask, count in sorted(mask_counts.items(), key=lambda x: -x[1])[:10]:
    print(f"  DifficultyMask={mask}: {count} items")
