"""Expected sell value of one search of each container kind, per ruins tier.

Usage: python3 tools/balance/loot_table.py
Reads data/loot_tables.json and data/items.json. Each search makes `rolls[tier]` (mean of
the range) weighted draws; "nothing" is a weight that yields no item. Value = item sell value
(items.json "value"); quest items and weapons count at their listed value.
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]


def main():
    tables = json.loads((ROOT / "data/loot_tables.json").read_text())["tables"]
    items = json.loads((ROOT / "data/items.json").read_text())
    print(f"{'container':16}" + "".join(f"{'tier ' + str(t):>9}" for t in range(1, 5)))
    for kind, table in tables.items():
        row = []
        for tier in range(1, 5):
            entries = [e for e in table["entries"] if e.get("min_tier", 1) <= tier and e.get("max_tier", 9) >= tier]
            total = sum(e["weight"] for e in entries) + table.get("nothing", 0)
            ev = sum(e["weight"] / total * (e["min"] + e["max"]) / 2 * items.get(e["item"], {}).get("value", 0)
                     for e in entries) if total else 0
            # A tier without its own roll range uses the nearest lower tier's (scripts/loot_db.gd).
            rolls = table.get("rolls", {})
            known = [int(k) for k in rolls if int(k) <= tier]
            lo, hi = rolls[str(max(known))] if known else [1, 1]
            row.append(ev * (lo + hi) / 2)
        print(f"{kind:16}" + "".join(f"{v:>9.0f}" for v in row))


if __name__ == "__main__":
    main()
