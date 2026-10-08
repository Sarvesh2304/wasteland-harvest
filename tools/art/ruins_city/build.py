"""Builds the ruined-city kit (Milestone C) into art/env/.

Usage:  python3 tools/art/ruins_city/build.py [section ...]
        sections: ground walls landmarks buildings props preview   (default: all)
Also runnable from tools/art/build_all.py (main()). Deterministic: fixed seeds / hash-based
variation everywhere, so re-running produces byte-identical PNGs unless a generator changed.

Writes (paths under art/env/):
  terrain/ruins_ground.png            128x16  8 seamless 16x16 base-ground variants
  fences/ruin_wall_brick.png          64x128  fence-sheet format (16 connection frames of 16x32)
  fences/ruin_wall_concrete.png       64x128  ditto
  ruins/ruin_shopfront.png  64x64   footprint 4x2      ruins/ruin_house.png   64x64  4x2
  ruins/ruin_garage.png     64x48   footprint 4x2      ruins/ruin_office.png  80x112 5x3
  ruins/ruin_apartment.png  96x96   footprint 6x3
  ruins/subway_stairs.png   32x32   2x2                ruins/kaels_truck.png  48x32  3x1
  ruins/filing_cabinet.png  32x24   2 frames 16x24 (closed, searched), 1x1
  ruins/manhole.png         32x16   2 frames (closed, open), walkable decor
  ruins/car_burnt.png       48x32   3x1                ruins/shopping_cart.png 16x16 1x1
  ruins/tire_pile.png       16x16   1x1                ruins/oil_drum.png      16x24 1x1
  ruins/pavement_decor.png  64x16   4 flat decal variants
  ruins/bones.png           32x16   2 variants
  _previews/ruins_city.png  mock street scene (1x composited, saved x4)
Every sprite is bottom-anchored: its footprint is the bottom W x H cells.
"""
from __future__ import annotations

import importlib
import pathlib
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
ART_TOOLS = HERE.parent
if str(ART_TOOLS) not in sys.path:
    sys.path.insert(0, str(ART_TOOLS))            # tools/art (palette.py, env and ruins_city)

SECTIONS = {
    "ground": "ruins_city.rc_ground",
    "walls": "ruins_city.rc_walls",
    "landmarks": "ruins_city.rc_landmarks",
    "buildings": "ruins_city.rc_buildings",
    "props": "ruins_city.rc_props",
}

# The only files this pipeline may write (all new; never an existing env asset).
OUTPUTS = {
    "terrain/ruins_ground.png",
    "fences/ruin_wall_brick.png", "fences/ruin_wall_concrete.png",
    "ruins/ruin_shopfront.png", "ruins/ruin_house.png", "ruins/ruin_garage.png",
    "ruins/ruin_office.png", "ruins/ruin_apartment.png",
    "ruins/subway_stairs.png", "ruins/kaels_truck.png",
    "ruins/filing_cabinet.png", "ruins/manhole.png", "ruins/car_burnt.png",
    "ruins/shopping_cart.png", "ruins/tire_pile.png", "ruins/oil_drum.png",
    "ruins/pavement_decor.png", "ruins/bones.png", "ruins/dumpster_open.png",
}


def write(rel, canvas):
    if rel not in OUTPUTS:
        raise RuntimeError(f"ruins_city: refusing to write {rel} (not one of this kit's outputs)")
    from env import lib
    return canvas.save(lib.OUT / rel)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    wanted = [a for a in argv if a in SECTIONS or a == "preview"] or list(SECTIONS) + ["preview"]
    for name in wanted:
        t0 = time.time()
        if name == "preview":
            from ruins_city import rc_preview
            rc_preview.build()
        else:
            mod = importlib.import_module(SECTIONS[name])
            for rel, cv in mod.build().items():
                write(rel, cv)
        print(f"[ruins_city] {name:9s} done in {time.time() - t0:5.1f}s")


if __name__ == "__main__":
    main()
