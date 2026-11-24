"""Builds the fishing art (docs/FISHING.md section 9).

Usage:  python3 tools/art/fishing/build.py [section ...]
        sections: fish dishes fx preview   (default: all)
Also runnable from tools/art/build_all.py (main()). Deterministic: no randomness anywhere (every
pixel is hand-placed or derived from fixed shapes), so re-running produces byte-identical PNGs
unless a generator changed. An output allowlist stops it from writing anything but its own
files, and every sprite is checked against the size / margin contract below before it is written.

Writes
  art/items/<fish>.png        16x16  the 13 fish of docs/FISHING.md section 5 (fi_fish.py, items kit)
  art/items/grilled_fish.png, fish_stew.png, smoked_eel.png   16x16 dishes (fi_dishes.py, items kit)
  art/fx/bobber.png           16x8   2 frames of 8x8: float, dip (fi_fx.py)
  art/fx/splash.png           48x16  3 frames of 16x16: rising, full, falling (fi_fx.py)
  art/env/_previews/fishing.png       review image (fi_preview.py; Godot-ignored folder)

The item icons are also registered in tools/art/items/build.py's icon registry, so the items
pipeline writes the same bytes (not placeholders) once the ids are in data/items.json.
"""
from __future__ import annotations

import pathlib
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
ART_TOOLS = HERE.parent
for _p in (str(ART_TOOLS / "items"), str(ART_TOOLS)):
    if _p not in sys.path:
        sys.path.insert(0, _p)        # tools/art (palette, the fishing package) + the items kit

import numpy as np  # noqa: E402

REPO = ART_TOOLS.parents[1]
SECTIONS = ["fish", "dishes", "fx", "preview"]

FISH_IDS = ["mud_minnow", "shellback_crawdad", "rustgill_carp", "sun_perch", "silver_dace", "ash_trout",
            "bog_eel", "sludge_catfish", "frostfin", "iron_pike", "glowfin", "two_headed_perch", "old_mayor"]
DISH_IDS = ["grilled_fish", "fish_stew", "smoked_eel"]

# rel path -> (width, height, frames, translucent pixels allowed?)
SPECS = {f"art/items/{i}.png": (16, 16, 1, False) for i in FISH_IDS + DISH_IDS}
SPECS.update({
    "art/fx/bobber.png": (16, 8, 2, True),
    "art/fx/splash.png": (48, 16, 3, True),
})
PREVIEW = "art/env/_previews/fishing.png"
OUTPUTS = set(SPECS) | {PREVIEW}


def check(rel, arr):
    """Hard checks: exact size, alpha 0/255 unless translucency is allowed (ripples), no pure
    black, every frame non-empty; icons keep their 1 px clear margin."""
    w, h, frames, translucent = SPECS[rel]
    assert arr.shape == (h, w, 4), f"{rel}: {arr.shape[1]}x{arr.shape[0]} != {w}x{h}"
    a = arr[:, :, 3]
    if not translucent:
        assert set(np.unique(a)) <= {0, 255}, f"{rel}: translucent pixels"
    assert not ((a == 255) & (arr[:, :, :3].sum(axis=2) == 0)).any(), f"{rel}: pure black"
    fw = w // frames
    for i in range(frames):
        assert (a[:, i * fw:(i + 1) * fw] == 255).any(), f"{rel}: frame {i} empty"
    if rel.startswith("art/items/"):
        assert not (a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any()), \
            f"{rel}: touches the 1 px margin"


def write(rel, img):
    """Save a numpy RGBA array or a PIL image (transparent pixels zeroed, like the items kit)."""
    from PIL import Image
    if rel not in OUTPUTS:
        raise RuntimeError(f"fishing: refusing to write {rel} (not one of this kit's outputs)")
    if isinstance(img, np.ndarray):
        arr = img.astype(np.uint8).copy()
        arr[arr[:, :, 3] == 0] = 0
        img = Image.fromarray(arr, "RGBA")
    if rel in SPECS:
        check(rel, np.asarray(img))
    path = REPO / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=False)
    return path


def build_fish():
    from fishing import fi_fish
    assert list(fi_fish.ICONS) == FISH_IDS
    for name, fn in fi_fish.ICONS.items():
        write(f"art/items/{name}.png", fn())


def build_dishes():
    from fishing import fi_dishes
    assert list(fi_dishes.ICONS) == DISH_IDS
    for name, fn in fi_dishes.ICONS.items():
        write(f"art/items/{name}.png", fn())


def build_fx():
    from fishing import fi_fx
    write("art/fx/bobber.png", fi_fx.bobber())
    write("art/fx/splash.png", fi_fx.splash())


def build_preview():
    from fishing import fi_preview
    write(PREVIEW, fi_preview.build(REPO))


def main(argv=None):
    """argv: section filters. None (how tools/art/build_all.py calls it) = build all; the command
    line is only parsed when this file is run as a script."""
    argv = [] if argv is None else argv
    wanted = [a for a in argv if a in SECTIONS] or SECTIONS
    for name in wanted:
        t0 = time.time()
        {"fish": build_fish, "dishes": build_dishes, "fx": build_fx, "preview": build_preview}[name]()
        print(f"[fishing] {name:8s} done in {time.time() - t0:5.1f}s")


if __name__ == "__main__":
    main(sys.argv[1:])
