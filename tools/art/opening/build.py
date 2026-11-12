"""Builds the opening's art (Milestone E: title -> intro -> character creation -> montage).

Usage:  python3 tools/art/opening/build.py [section ...]
        sections: regions pages preview   (default: all)
Also runnable from tools/art/build_all.py (main()). Deterministic: re-running produces
byte-identical PNGs unless a generator changed. An output allowlist stops it from writing
anything but its own files, and every page is checked against its size contract.

Writes
  art/characters/player/regions/<action>/<facing>/<n>.png   24x24 recolour-region masks for the
        player sprite (op_regions.py): red hair, green skin, blue outfit. scripts/player_look.gd
        reads them for the character-creation palette swap.
  art/opening/<page>.png    256x112 opaque illustrations, one per intro / montage page
        (op_pages.py): claim, walls, clinic, childhood, town, farewell, farm
  art/opening/_preview/opening.png    review sheet: every page at 2x plus the region masks
        (Godot-ignored folder)
"""
from __future__ import annotations

import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
ART_TOOLS = HERE.parent
for _p in (str(HERE), str(ART_TOOLS)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

import op_pages  # noqa: E402
import op_regions  # noqa: E402

REPO = ART_TOOLS.parents[1]
SECTIONS = ["regions", "pages", "preview"]
PAGE_DIR = "art/opening"
PREVIEW_DIR = "art/opening/_preview"
PAGE_SIZE = (256, 112)


def _allowed(path: pathlib.Path) -> bool:
    rel = path.resolve().relative_to(REPO).as_posix()
    if rel.startswith("art/characters/player/regions/") and rel.endswith(".png"):
        return True
    if rel in {f"{PAGE_DIR}/{name}.png" for name in op_pages.PAGES}:
        return True
    return rel in {f"{PREVIEW_DIR}/opening.png", f"{PREVIEW_DIR}/regions.png", f"{PREVIEW_DIR}/.gdignore"}


def check_page(name: str, arr: np.ndarray) -> None:
    w, h = PAGE_SIZE
    assert arr.shape == (h, w, 4), f"{name}: {arr.shape[1]}x{arr.shape[0]} != {w}x{h}"
    assert (arr[:, :, 3] == 255).all(), f"{name}: a page must be fully opaque"
    assert not (arr[:, :, :3].sum(axis=2) == 0).any(), f"{name}: pure black"


def build_regions() -> None:
    for path in op_regions.build():
        assert _allowed(path), path
    print(f"[opening] regions: {len(list(op_regions.frames()))} masks")


def build_pages() -> None:
    out_dir = REPO / PAGE_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, fn in op_pages.PAGES.items():
        arr = fn()
        check_page(name, arr)
        dest = out_dir / f"{name}.png"
        assert _allowed(dest), dest
        Image.fromarray(arr, "RGBA").save(dest, optimize=False)
    print(f"[opening] pages: {len(op_pages.PAGES)} written to {PAGE_DIR}/")


def build_preview() -> None:
    pdir = REPO / PREVIEW_DIR
    pdir.mkdir(parents=True, exist_ok=True)
    (pdir / ".gdignore").write_text("")
    names = list(op_pages.PAGES)
    scale = 2
    cols = 2
    rows = (len(names) + cols - 1) // cols
    w, h = PAGE_SIZE
    sheet = Image.new("RGBA", (cols * (w * scale + 8) + 8, rows * (h * scale + 8) + 8), (40, 26, 11, 255))
    for i, name in enumerate(names):
        page = Image.open(REPO / PAGE_DIR / f"{name}.png").resize((w * scale, h * scale), Image.NEAREST)
        sheet.alpha_composite(page, (8 + (i % cols) * (w * scale + 8), 8 + (i // cols) * (h * scale + 8)))
    dest = pdir / "opening.png"
    assert _allowed(dest)
    sheet.save(dest)
    regions = pdir / "regions.png"
    assert _allowed(regions)
    op_regions.preview(regions)
    print(f"[opening] preview: {PREVIEW_DIR}/opening.png, regions.png")


def main(sections=None) -> None:
    sections = sections or SECTIONS
    for section in sections:
        {"regions": build_regions, "pages": build_pages, "preview": build_preview}[section]()


if __name__ == "__main__":
    main(sys.argv[1:] or None)
