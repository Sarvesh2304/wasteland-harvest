"""Builds the living-settlement art (Milestone D, docs/LIVING_SETTLEMENT.md section 7).

Usage:  python3 tools/art/living/build.py [section ...]
        sections: stall buildings festival fx ruins items preview   (default: all)
Also runnable from tools/art/build_all.py (main()). Deterministic: no randomness anywhere (all
variation is hand-placed or hash-based), so re-running produces byte-identical PNGs unless a
generator changed. An output allowlist stops it from writing anything but its own files, and
every sprite is checked against the size / anchoring contract below before it is written.

Writes
  art/env/props/market_stall_open.png    48x56  footprint 3x1; market_stall.png's pixels,
                                                bottom-aligned, dressed (lv_stall.py)
  art/buildings/trading_post.png          48x44  footprint 3x2 (lv_buildings.py)
  art/buildings/mayor_house_antenna.png   64x72  mayor_house.png's pixels, bottom-aligned, + mast
  art/buildings/festival_booth.png        32x40  footprint 2x1
  art/env/props/bunting.png               64x16  no footprint; ends at the same height
  art/buildings/festival_table.png        32x24  footprint 2x1 (lv_festival.py)
  art/env/props/festival_lantern.png      32x32  2 frames of 16x32: unlit, lit
  art/env/props/seed_packet.png           16x16
  art/fx/race_goat.png                    96x16  4 frames of 24x16, running left (lv_goats.py)
  art/env/ruins/vault_door.png            64x32  2 frames of 32x32: sealed, open (lv_vault.py)
  art/items/vault_seeds.png, festival_ribbon.png   16x16 icons (lv_items.py, items kit)
  art/env/_previews/living.png            review image (lv_preview.py; Godot-ignored folder)
Tully himself is built by tools/art/townsfolk/build.py (tf_tully.py).
"""
from __future__ import annotations

import pathlib
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
ART_TOOLS = HERE.parent
for _p in (str(ART_TOOLS / "items"), str(ART_TOOLS)):
    if _p not in sys.path:
        sys.path.insert(0, _p)        # tools/art (palette, env, enemies, townsfolk, living) + items kit

import numpy as np  # noqa: E402

REPO = ART_TOOLS.parents[1]
SECTIONS = ["stall", "buildings", "festival", "fx", "ruins", "items", "preview"]

# rel path -> (width, height, frames, bottom-anchored?, translucent pixels allowed?)
SPECS = {
    "art/env/props/market_stall_open.png": (48, 56, 1, True, True),
    "art/buildings/trading_post.png": (48, 44, 1, True, True),
    "art/buildings/mayor_house_antenna.png": (64, 72, 1, False, True),   # source PNG has 6 clear rows below
    "art/buildings/festival_booth.png": (32, 40, 1, True, True),
    "art/env/props/bunting.png": (64, 16, 1, False, False),
    "art/buildings/festival_table.png": (32, 24, 1, True, True),
    "art/env/props/festival_lantern.png": (32, 32, 2, True, True),
    "art/env/props/seed_packet.png": (16, 16, 1, True, True),
    "art/fx/race_goat.png": (96, 16, 4, True, False),
    "art/env/ruins/vault_door.png": (64, 32, 2, True, True),
    "art/items/vault_seeds.png": (16, 16, 1, False, False),
    "art/items/festival_ribbon.png": (16, 16, 1, False, False),
}
PREVIEW = "art/env/_previews/living.png"
OUTPUTS = set(SPECS) | {PREVIEW}


def check(rel, arr):
    """Hard checks: exact size, alpha 0/255 unless translucency is allowed (glows, shadows),
    no pure black, every frame non-empty and (for things that stand on the ground) reaching the
    bottom two rows; icons keep their 1 px clear margin."""
    w, h, frames, bottom, translucent = SPECS[rel]
    assert arr.shape == (h, w, 4), f"{rel}: {arr.shape[1]}x{arr.shape[0]} != {w}x{h}"
    a = arr[:, :, 3]
    if not translucent:
        assert set(np.unique(a)) <= {0, 255}, f"{rel}: translucent pixels"
    assert not ((a == 255) & (arr[:, :, :3].sum(axis=2) == 0)).any(), f"{rel}: pure black"
    fw = w // frames
    for i in range(frames):
        fa = a[:, i * fw:(i + 1) * fw]
        assert (fa == 255).any(), f"{rel}: frame {i} empty"
        if bottom:
            assert (fa[-2:] > 0).any(), f"{rel}: frame {i} does not stand on the bottom edge"
    if rel.startswith("art/items/"):
        assert not (a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any()), \
            f"{rel}: touches the 1 px margin"


def write(rel, img):
    """Save a Canvas (env.lib / enemies.pix), a numpy RGBA array or a PIL image."""
    from PIL import Image
    if rel not in OUTPUTS:
        raise RuntimeError(f"living: refusing to write {rel} (not one of this kit's outputs)")
    if hasattr(img, "to_image"):
        img = img.to_image()
    elif isinstance(img, np.ndarray):
        arr = img.astype(np.uint8).copy()
        arr[arr[:, :, 3] == 0] = 0
        img = Image.fromarray(arr, "RGBA")
    if rel in SPECS:
        check(rel, np.asarray(img))
    path = REPO / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=False)
    return path


def build_stall():
    from living import lv_stall
    write("art/env/props/market_stall_open.png", lv_stall.market_stall_open(REPO))


def build_buildings():
    from living import lv_buildings as B
    write("art/buildings/trading_post.png", B.trading_post())
    write("art/buildings/mayor_house_antenna.png", B.mayor_house_antenna(REPO))
    write("art/buildings/festival_booth.png", B.festival_booth())


def build_festival():
    from living import lv_festival as F
    write("art/env/props/bunting.png", F.bunting())
    write("art/buildings/festival_table.png", F.festival_table())
    write("art/env/props/festival_lantern.png", F.festival_lantern())
    write("art/env/props/seed_packet.png", F.seed_packet())


def build_fx():
    from living import lv_goats
    write("art/fx/race_goat.png", lv_goats.race_strip())


def build_ruins():
    from living import lv_vault
    write("art/env/ruins/vault_door.png", lv_vault.vault_door())


def build_items():
    from living import lv_items
    for name, fn in lv_items.ICONS.items():
        write(f"art/items/{name}.png", fn())


def build_preview():
    from living import lv_preview
    write(PREVIEW, lv_preview.build(REPO))


def main(argv=None):
    """argv: section filters. None (how tools/art/build_all.py calls it) = build all; the command
    line is only parsed when this file is run as a script."""
    argv = [] if argv is None else argv
    wanted = [a for a in argv if a in SECTIONS] or SECTIONS
    for name in wanted:
        t0 = time.time()
        {"stall": build_stall, "buildings": build_buildings, "festival": build_festival,
         "fx": build_fx, "ruins": build_ruins, "items": build_items,
         "preview": build_preview}[name]()
        print(f"[living] {name:10s} done in {time.time() - t0:5.1f}s")


if __name__ == "__main__":
    main(sys.argv[1:])
