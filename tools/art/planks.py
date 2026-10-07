"""Plank decking for docks and footbridges (art/env/terrain/planks_h.png, planks_v.png).

Each sheet is 64x16: four seamless 16x16 variants. planks_v has boards running north-south
(laid across an east-west walkway: the town dock, creek footbridges); planks_h has boards running
east-west (for north-south walkways). Shared palette: tools/art/palette.py's WOOD_RAMP.

Run: python3 tools/art/planks.py
"""
from __future__ import annotations

import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import palette as P  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "env", "terrain")
T = 16
BOARD = 4  # px per board


def _hex(c: str) -> tuple:
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


W = [_hex(c) for c in P.WOOD_RAMP]  # 0 darkest .. 5 lightest


def _tile_v(seed: int) -> Image.Image:
    """Boards running north-south: 4 boards side by side, each 4px wide."""
    rnd = random.Random(seed)
    im = Image.new("RGBA", (T, T))
    px = im.load()
    for b in range(T // BOARD):
        tone = rnd.choice([2, 3, 3, 4])
        seam = rnd.randint(3, 12) if rnd.random() < 0.6 else -1  # a board end inside this tile
        for x in range(b * BOARD, b * BOARD + BOARD):
            for y in range(T):
                edge = x == b * BOARD  # dark gap on the west side of every board
                if edge:
                    c = W[0]
                elif x == b * BOARD + 1:
                    c = W[tone + 1] if tone < 5 else W[5]  # lit left edge
                else:
                    c = W[tone]
                if y == seam:
                    c = W[1]
                px[x, y] = c
        # grain: a couple of darker streaks along the board
        for _ in range(2):
            gx = b * BOARD + rnd.randint(2, 3)
            gy = rnd.randint(0, T - 4)
            for y in range(gy, gy + rnd.randint(2, 4)):
                px[gx, y % T] = W[max(tone - 1, 1)]
        # nails near the seam (or top/bottom)
        ny = seam + 1 if seam >= 0 and seam < T - 1 else rnd.choice([1, 14])
        px[b * BOARD + 2, ny] = W[0]
    return im


def _tile_h(seed: int) -> Image.Image:
    return _tile_v(seed).transpose(Image.Transpose.ROTATE_90)


def build() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("planks_v", _tile_v), ("planks_h", _tile_h)):
        sheet = Image.new("RGBA", (T * 4, T))
        for i in range(4):
            sheet.paste(fn(1000 + i * 17), (i * T, 0))
        path = os.path.join(OUT, name + ".png")
        sheet.save(path)
        print("wrote", path)


if __name__ == "__main__":
    build()
