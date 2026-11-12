"""Crop economics per season: profit per tile per day for a whole season of planting.

Usage: python3 tools/balance/crop_table.py
Reads data/crops.json and data/items.json (sell value = items[yield].value, seed cost =
items[seed].buy_price). Assumes planting on day 1 of the season, replanting single-harvest
crops immediately, a 28-day season, average yield (min..max mean + extra_chance).
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
SEASON = 28


def load(name):
    return json.loads((ROOT / "data" / name).read_text())


def season_run(crop, value, seed_cost):
    grow = sum(crop["stage_days"])
    regrow = int(crop.get("regrow_days", 0))
    mean = (crop.get("yield_min", 1) + crop.get("yield_max", crop.get("yield_min", 1))) / 2 + crop.get("extra_chance", 0)
    seasons = len(crop["seasons"])
    days = SEASON * seasons
    harvests, cost = 0, 0
    if regrow > 0:
        cost = seed_cost
        if grow <= days:
            harvests = 1 + (days - grow) // regrow
    else:
        harvests = days // grow
        cost = harvests * seed_cost
    revenue = harvests * mean * value
    return grow, regrow, harvests, revenue, cost, (revenue - cost) / days


def main():
    crops = {k: v for k, v in load("crops.json").items() if not k.startswith("_")}
    items = load("items.json")
    rows = []
    for cid, crop in crops.items():
        value = items.get(crop["yield_item"], {}).get("value", 0)
        seed = items.get(crop["seed_item"], {})
        seed_cost = seed.get("buy_price", 0)
        grow, regrow, harvests, revenue, cost, per_day = season_run(crop, value, seed_cost)
        rows.append(("/".join(s[:2] for s in crop["seasons"]), cid, grow, regrow, value, seed_cost,
                     harvests, round(revenue), cost, round(per_day, 1), round(value / max(seed_cost, 1), 2)))
    rows.sort(key=lambda r: (r[0], -r[9]))
    print(f"{'season':8}{'crop':16}{'grow':>5}{'regr':>5}{'val':>6}{'seed':>6}{'hv':>4}{'rev':>7}{'cost':>6}{'net/day':>9}{'v/s':>6}")
    for r in rows:
        print(f"{r[0]:8}{r[1]:16}{r[2]:>5}{r[3]:>5}{r[4]:>6}{r[5]:>6}{r[6]:>4}{r[7]:>7}{r[8]:>6}{r[9]:>9}{r[10]:>6}")


if __name__ == "__main__":
    main()
