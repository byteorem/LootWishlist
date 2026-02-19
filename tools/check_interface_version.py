# /// script
# requires-python = ">=3.10"
# dependencies = ["requests"]
# ///
"""
Check if the addon's Interface version matches the latest WoW retail build.

Fetches the latest live and PTR build versions from Wago.tools and compares
them against the ## Interface line in LootWishlist.toc.

Usage:
    uv run tools/check_interface_version.py              # Compare and report (live + PTR)
    uv run tools/check_interface_version.py --live-only  # Only check the live version
    uv run tools/check_interface_version.py --update     # Auto-update the TOC
"""

import os
import re
import sys

import requests

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
TOC_PATH = os.path.join(PROJECT_ROOT, "LootWishlist.toc")

BUILDS_URL = "https://wago.tools/api/builds"

# 12.x = PTR/next expansion, 11.x = current live (update when new xpac goes live)
LIVE_MAJOR = 11
PTR_MAJOR = 12


def version_to_interface(version_str: str) -> int:
    """Convert '11.2.7.65299' -> 110207."""
    parts = version_str.split(".")
    major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])
    return major * 10000 + minor * 100 + patch


def interface_to_display(iface: int) -> str:
    """Convert 110207 -> '11.2.7'."""
    major = iface // 10000
    minor = (iface % 10000) // 100
    patch = iface % 100
    return f"{major}.{minor}.{patch}"


def fetch_latest_builds() -> dict[str, str]:
    """Return {label: version_string} for latest live and PTR builds."""
    resp = requests.get(BUILDS_URL, timeout=30)
    resp.raise_for_status()
    builds = resp.json()["wow"]

    latest_live = None
    latest_ptr = None

    for build in builds:
        ver = build["version"]
        major = int(ver.split(".")[0])
        if major == LIVE_MAJOR and latest_live is None:
            latest_live = ver
        elif major == PTR_MAJOR and latest_ptr is None:
            latest_ptr = ver
        if latest_live and latest_ptr:
            break

    result = {}
    if latest_live:
        result["live"] = latest_live
    if latest_ptr:
        result["ptr"] = latest_ptr
    return result


def parse_toc_interface(toc_text: str) -> list[int]:
    """Extract interface versions from TOC text."""
    match = re.search(r"^## Interface:\s*(.+)$", toc_text, re.MULTILINE)
    if not match:
        return []
    return [int(v.strip()) for v in match.group(1).split(",")]


def update_toc_interface(toc_text: str, new_versions: list[int]) -> str:
    """Replace the Interface line in TOC text."""
    new_line = "## Interface: " + ", ".join(str(v) for v in new_versions)
    return re.sub(r"^## Interface:.*$", new_line, toc_text, count=1, flags=re.MULTILINE)


def main():
    do_update = "--update" in sys.argv
    live_only = "--live-only" in sys.argv

    print("Fetching latest builds from wago.tools...")
    builds = fetch_latest_builds()

    if not builds:
        print("ERROR: Could not fetch any builds.")
        sys.exit(1)

    # Compute interface numbers from latest builds
    latest = {}
    for label, ver in builds.items():
        iface = version_to_interface(ver)
        latest[label] = iface
        print(f"  {label.upper()}: {ver} -> Interface {iface}")

    # Read TOC
    with open(TOC_PATH, "r") as f:
        toc_text = f.read()

    current = parse_toc_interface(toc_text)
    print(f"\nTOC Interface: {', '.join(str(v) for v in current)}")
    print(f"  = {', '.join(interface_to_display(v) for v in current)}")

    # Check live version against TOC
    if live_only:
        if "live" not in latest:
            print("ERROR: Could not determine latest live build.")
            sys.exit(1)

        live_iface = latest["live"]
        if live_iface in current:
            print(f"\nLive interface version {live_iface} ({interface_to_display(live_iface)}) is present in TOC.")
            sys.exit(0)
        else:
            print(f"\nLive interface version is stale!")
            print(f"  Expected: {live_iface} ({interface_to_display(live_iface)})")
            print(f"  TOC has:  {', '.join(str(v) for v in current)}")
            if not do_update:
                print("\nRun with --update to apply.")
                sys.exit(1)

            # Replace the live version in the TOC (keep PTR if present)
            updated = []
            for v in current:
                major = v // 10000
                if major == LIVE_MAJOR:
                    updated.append(live_iface)
                else:
                    updated.append(v)
            if live_iface not in updated:
                updated.append(live_iface)

            new_toc = update_toc_interface(toc_text, updated)
            with open(TOC_PATH, "w") as f:
                f.write(new_toc)
            print(f"\nUpdated {TOC_PATH}")
            sys.exit(0)

    # Full comparison (live + PTR)
    expected = []
    if "ptr" in latest:
        expected.append(latest["ptr"])
    if "live" in latest:
        expected.append(latest["live"])

    needs_update = current != expected
    if not needs_update:
        print("\nInterface versions are up to date.")
        sys.exit(0)

    print(f"\nUpdate needed:")
    print(f"  Current: {', '.join(str(v) for v in current)}")
    print(f"  Latest:  {', '.join(str(v) for v in expected)}")
    print(f"           ({', '.join(interface_to_display(v) for v in expected)})")

    if not do_update:
        print("\nRun with --update to apply.")
        sys.exit(1)

    # Apply update
    new_toc = update_toc_interface(toc_text, expected)
    with open(TOC_PATH, "w") as f:
        f.write(new_toc)

    print(f"\nUpdated {TOC_PATH}")
    sys.exit(0)


if __name__ == "__main__":
    main()
