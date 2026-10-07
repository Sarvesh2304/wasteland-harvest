"""The farmhouse front step (art/buildings/bed.png): a worn woven doormat on a plank step.

The "bed" building kind is the cell where the player turns in for the night; since the farmhouse
has no interior yet, it's drawn as the front door's step and mat rather than a bed standing in the
yard (2026-10-07). Shared palette: tools/art/palette.py.

Run: python3 tools/art/doormat.py
"""
from __future__ import annotations

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import palette as P  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def _hex(c: str, a: int = 255) -> tuple:
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def build() -> None:
    wood = [_hex(c) for c in P.WOOD_RAMP]
    cloth = [_hex(c) for c in P.CLOTH_RAMP]
    rust = [_hex(c) for c in P.RUST_RAMP]
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = im.load()
    # Plank step: rows 3..14, two boards, dark outline, lit top edge.
    for y in range(3, 15):
        for x in range(1, 15):
            c = wood[3] if y < 9 else wood[2]
            if y == 3:
                c = wood[4]
            if y in (8, 9):
                c = wood[1] if y == 9 else c
            if x in (1, 14) or y == 14:
                c = wood[0]
            px[x, y] = c
    # Drop shadow under the step.
    for x in range(2, 15):
        px[x, 15] = (0, 0, 0, 70)
    # Woven mat: rows 5..12, cols 3..12, rust border with a cloth weave.
    for y in range(5, 13):
        for x in range(3, 13):
            border = y in (5, 12) or x in (3, 12)
            if border:
                px[x, y] = rust[2]
            else:
                px[x, y] = cloth[2] if (x + y) % 2 == 0 else cloth[3]
    # A worn patch and frayed corner.
    for x, y in [(6, 8), (7, 8), (7, 9), (8, 9)]:
        px[x, y] = cloth[1]
    px[12, 12] = wood[2]
    px[3, 5] = rust[3]
    out = os.path.join(ROOT, "art", "buildings", "bed.png")
    im.save(out)
    print("wrote", out)


if __name__ == "__main__":
    build()
