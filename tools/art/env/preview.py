"""Preview mock-ups for the environment art (not shipped game assets).

Usage: python3 tools/art/env/preview.py
Writes PNGs to art/env/_previews/ (that folder carries a .gdignore so Godot never imports it).
Composites the real generated PNGs the same way the engine will: grass base tiles, dual-grid Wang
overlays (visual tiles offset half a cell), then Y-sorted upright sprites anchored bottom-centre.
"""
from __future__ import annotations

import pathlib
import random
import sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

from env import lib  # noqa: E402
from env.lib import Canvas  # noqa: E402

ENV = lib.OUT
PREV = ENV / "_previews"


def load(rel):
    return Canvas.load(ENV / rel)


def sub(cv, x, y, w, h):
    return cv.crop(x, y, w, h)


class Scene:
    """Logical cell grid -> composited image (1x)."""

    def __init__(self, cols, rows, season="spring", seed=1):
        self.cols = cols
        self.rows = rows
        self.season = season
        self.r = random.Random(seed)
        self.cv = Canvas(cols * 16, rows * 16)
        self.sprites = []   # (sort_y, x, y, canvas)

    def grass(self, name=None):
        strip = load(f"terrain/grass_{self.season}.png" if name is None else name)
        for j in range(self.rows):
            for i in range(self.cols):
                v = self.r.randrange(8)
                self.cv.blit(sub(strip, v * 16, 0, 16, 16), i * 16, j * 16)

    def base_full(self, rel):
        strip = load(rel)
        n = strip.w // 16
        for j in range(self.rows):
            for i in range(self.cols):
                v = self.r.randrange(n)
                self.cv.blit(sub(strip, v * 16, 0, 16, 16), i * 16, j * 16)

    def overlay(self, sheet_rel, is_t, full_rel=None, frame=0, animated=False):
        """Dual-grid paint: is_t(i, j) -> bool for logical cell (i, j).

        animated=True: the sheet/full strips are animation frames (water) -> use `frame`.
        """
        sheet = load(sheet_rel)
        full = load(full_rel) if full_rel else None
        ox = frame * 64 if animated else 0

        def t(i, j):
            i = min(max(i, 0), self.cols - 1)
            j = min(max(j, 0), self.rows - 1)
            return is_t(i, j)

        for j in range(self.rows + 1):
            for i in range(self.cols + 1):
                m = (t(i - 1, j - 1) << 3) | (t(i, j - 1) << 2) | (t(i - 1, j) << 1) | t(i, j)
                if m == 0:
                    continue
                if m == 15 and full is not None:
                    n = full.w // 16
                    v = frame if animated else (i * 7 + j * 13 + (i * j) % 5) % n
                    tile = sub(full, v * 16, 0, 16, 16)
                else:
                    tile = sub(sheet, ox + (m % 4) * 16, (m // 4) * 16, 16, 16)
                self.cv.blit(tile, i * 16 - 8, j * 16 - 8)

    def put(self, sprite, cx, cy, frame=None, fw=None):
        """Place an upright sprite so its bottom-centre sits on the bottom edge of cell (cx, cy).

        For multi-cell footprints pass fractional cx (e.g. 3.5 = centred between cells 3 and 4).
        """
        if isinstance(sprite, str):
            sprite = load(sprite)
        if frame is not None:
            sprite = sub(sprite, frame * fw, 0, fw, sprite.h)
        x = int(round((cx + 0.5) * 16 - sprite.w / 2))
        y = (cy + 1) * 16 - sprite.h
        self.sprites.append(((cy + 1) * 16, x, y, sprite))

    def decal(self, sprite, cx, cy):
        if isinstance(sprite, str):
            sprite = load(sprite)
        self.cv.blit(sprite, cx * 16, cy * 16 + 16 - sprite.h)

    def render(self, scale=4):
        out = self.cv.copy()
        for _, x, y, s in sorted(self.sprites, key=lambda e: (e[0], e[1])):
            out.blit(s, x, y)
        im = out.to_image()
        bg = Image.new("RGBA", im.size, (0, 0, 0, 255))
        bg.alpha_composite(im)
        return bg.resize((im.width * scale, im.height * scale), Image.NEAREST)


def save(im, name):
    PREV.mkdir(parents=True, exist_ok=True)
    (PREV / ".gdignore").write_text("")
    p = PREV / name
    im.save(p)
    print("preview:", p)
    return p


def zoom(rel_or_cv, scale=8, bg=(70, 110, 60, 255)):
    cv = load(rel_or_cv) if isinstance(rel_or_cv, str) else rel_or_cv
    im = cv.to_image()
    b = Image.new("RGBA", im.size, bg)
    b.alpha_composite(im)
    return b.resize((im.width * scale, im.height * scale), Image.NEAREST)


if __name__ == "__main__":
    import env.previews as pv  # noqa: E402
    pv.main(sys.argv[1:])
