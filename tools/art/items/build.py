"""Item icons, placeable world sprites and crop growth sprites for Wasteland Harvest.

Code-generated pixel art (docs/ART_STYLE.md). Deterministic: fixed seeds, no randomness that
depends on run order, so re-running gives byte-identical PNGs unless a generator changed.

Run:  python3 tools/art/items/build.py          (also run by tools/art/build_all.py)

Writes
  art/items/<id>.png                 16x16 icon for every id in data/items.json (path from its `icon`)
  art/items/<tool>_t2|t3|t4.png      tier variants of hoe / watering_can / axe / pickaxe / scythe
  art/items/world/<id>.png           placeable world sprites (16 wide, 16 or 32 tall, frames side by side)
  art/crops/<crop>/stage_<i>.png     16x32 growth sprites, i = 0..len(stage_days); plus stage_dead.png
  art/items/_preview/, art/crops/_preview/   contact sheets (Godot-ignored via .gdignore)
"""
from __future__ import annotations

import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ART_TOOLS = HERE.parent
for _p in (str(ART_TOOLS), str(HERE)):
    while _p in sys.path:
        sys.path.remove(_p)
    sys.path.insert(0, _p)

import numpy as np  # noqa: E402

import ia_lib as L  # noqa: E402
import ia_common as K  # noqa: E402
import ia_tools  # noqa: E402
import ia_seeds  # noqa: E402
import ia_produce  # noqa: E402
import ia_resources  # noqa: E402
import ia_food  # noqa: E402
import ia_gear  # noqa: E402
import ia_place  # noqa: E402
import ia_crops  # noqa: E402
import ia_sheets  # noqa: E402

REPO = K.REPO
ITEMS_DIR = REPO / "art" / "items"
CROPS_DIR = REPO / "art" / "crops"
TIER_TOOLS = ["hoe", "watering_can", "axe", "pickaxe", "scythe"]
CATEGORY_ORDER = ["Tools", "Seeds", "Crops", "Forage", "Resources", "Food", "Artisan Goods",
                  "Animal Products", "Medicine", "Weapons", "Ammo", "Equipment", "Crafted", "Special"]


def registry():
    reg = {}
    for mod in (ia_tools, ia_seeds, ia_produce, ia_resources, ia_food, ia_gear, ia_place):
        for k, fn in mod.ICONS.items():
            if k in reg:
                raise RuntimeError(f"icon {k} defined twice")
            reg[k] = fn
    return reg


def res_to_path(res: str) -> pathlib.Path:
    assert res.startswith("res://"), res
    return REPO / res[len("res://"):]


def placeholder(label: str) -> np.ndarray:
    """Visible magenta-ish box for an id with no generator (reported as missing)."""
    s = L.Sprite()
    lay = s.layer(L.Ramp(["#5a1e3a", "#8a2e5a", "#b84a7e", "#d878a4"]), "flat")
    lay.rect(3, 3, 12, 12)
    return s.render()


def check(img, name, w=16, h=16, margin=True):
    problems = []
    if img.shape != (h, w, 4):
        problems.append(f"{name}: size {img.shape[1]}x{img.shape[0]} != {w}x{h}")
    a = img[:, :, 3]
    if not (a > 0).any():
        problems.append(f"{name}: empty")
    if margin and ((a[0] > 0).any() or (a[-1] > 0).any() or (a[:, 0] > 0).any() or (a[:, -1] > 0).any()):
        problems.append(f"{name}: touches the 1 px margin")
    return problems


def main():
    reg = registry()
    problems, missing = [], []
    icons = {}
    for item_id, item in K.ITEMS.items():
        fn = reg.get(item_id)
        if fn is None:
            missing.append(item_id)
            img = placeholder(item_id)
        else:
            img = np.asarray(fn(), np.uint8)
        problems += check(img, item_id)
        L.save(img, res_to_path(item["icon"]))
        icons[item_id] = img
    tiers = {}
    for tool in TIER_TOOLS:
        for t in (2, 3, 4):
            img = np.asarray(ia_tools.TIERED[tool](t), np.uint8)
            problems += check(img, f"{tool}_t{t}")
            L.save(img, ITEMS_DIR / f"{tool}_t{t}.png")
            tiers[f"{tool}_t{t}"] = img
    world = {}
    for pid, fn in ia_place.WORLD.items():
        img = np.asarray(fn(), np.uint8)
        h, w = img.shape[:2]
        if h not in (16, 32) or w % 16:
            problems.append(f"world/{pid}: bad size {w}x{h}")
        L.save(img, ITEMS_DIR / "world" / f"{pid}.png")
        world[pid] = img
    crop_rows = []
    n_crop_files = 0
    for cid, crop in K.CROPS.items():
        stages, dead = ia_crops.build(cid)
        out = CROPS_DIR / cid
        for i, img in enumerate(stages):
            problems += check(img, f"{cid}/stage_{i}", 16, 32, margin=False)
            L.save(img, out / f"stage_{i}.png")
            n_crop_files += 1
        L.save(dead, out / "stage_dead.png")
        n_crop_files += 1
        # remove stale stages from an older, longer chain (and their import sidecars)
        for old in out.glob("stage_*.png"):
            stem = old.stem.split("_", 1)[1]
            if stem.isdigit() and int(stem) >= len(stages):
                old.unlink()
                imp = old.with_name(old.name + ".import")
                if imp.exists():
                    imp.unlink()
        crop_rows.append((cid, stages, dead))

    # ---- contact sheets ----------------------------------------------------------------------
    by_cat = {}
    for item_id, item in K.ITEMS.items():
        by_cat.setdefault(item.get("category", "Other"), []).append((item_id, icons[item_id]))
    groups = []
    for cat in CATEGORY_ORDER + sorted(c for c in by_cat if c not in CATEGORY_ORDER):
        if cat in by_cat:
            items = by_cat[cat]
            if cat == "Tools":
                items = items + [(k, v) for k, v in tiers.items()]
            groups.append((cat, items))
    prev_items = ITEMS_DIR / "_preview"
    prev_crops = CROPS_DIR / "_preview"
    for d in (prev_items, prev_crops):
        d.mkdir(parents=True, exist_ok=True)
        (d / ".gdignore").write_text("")
    ia_sheets.icon_sheet(groups, prev_items / "icons_light.png", ia_sheets.LIGHT_BG)
    ia_sheets.icon_sheet(groups, prev_items / "icons_dark.png", ia_sheets.DARK_BG)
    ia_sheets.world_sheet(list(world.items()), prev_items / "world_sprites.png")
    ia_sheets.crop_sheet(crop_rows, prev_crops / "crops_sheet.png")
    hotbar = [icons[k] for k in ("hoe", "watering_can", "axe", "pickaxe", "scythe", "fishing_rod",
                                 "seed_mutant_potato", "mutant_potato", "wood", "stone", "scrap_metal", "medkit",
                                 "sunbloom", "bloodberry", "cooked_meal", "coffee", "rusty_pipe", "pistol_ammo",
                                 "battery", "rad_crystal", "honey", "blueprint", "crate_chest", "oil_lamp")
              if k in icons]
    ia_sheets.mock_scene(hotbar, crop_rows, REPO / "art/characters/player/rotations/south.png",
                         prev_items / "mock_1x_scaled3.png")

    print(f"[items] {len(K.ITEMS)} item icons ({len(K.ITEMS) - len(missing)} drawn, {len(missing)} placeholder), "
          f"{len(tiers)} tool tier icons, {len(world)} world sprites")
    print(f"[items] {len(crop_rows)} crops, {n_crop_files} crop sprites (incl. stage_dead)")
    if missing:
        print("[items] MISSING generators (placeholder written):", ", ".join(missing))
    for p in problems:
        print("[items] WARN", p)
    return {"missing": missing, "problems": problems}


if __name__ == "__main__":
    main()
