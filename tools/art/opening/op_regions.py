"""Recolour-region masks for the player sprite (character creation, Milestone E).

The PixelLab player shares its dark browns between hair and trousers/boots, so a plain
colour-keyed palette swap cannot tell them apart. This module classifies every opaque pixel of
every player frame into a region and writes a parallel mask PNG per frame:

    art/characters/player/regions/<action>/<facing>/<n>.png   (24x24, same as the frame)

Mask encoding (one-hot, so the PNGs are readable at a glance):
    red   (255, 0, 0, 255)  hair
    green (0, 255, 0, 255)  skin
    blue  (0, 0, 255, 255)  outfit (the duster jacket)
    clear                   everything else (trousers, boots, shirt, eyes, tools) - kept as drawn

scripts/player_look.gd reads these at runtime and remaps each region onto the chosen ramp.
Classification is by colour family (HSV), and hair vs trousers by position: the dark-brown
pixels in the component that holds the topmost dark-brown row, cut off a head's height below it.
"""
from __future__ import annotations

import colorsys
import pathlib

import numpy as np
from PIL import Image

REPO = pathlib.Path(__file__).resolve().parents[3]
PLAYER = REPO / "art" / "characters" / "player"
OUT = PLAYER / "regions"
ACTIONS = ["idle", "walk", "tool"]
FACINGS = ["south", "north", "east", "west"]

NONE, HAIR, SKIN, OUTFIT = 0, 1, 2, 3
MASK_COLORS = {HAIR: (255, 0, 0, 255), SKIN: (0, 255, 0, 255), OUTFIT: (0, 0, 255, 255)}
HEAD_ROWS = 6          # hair never reaches further than this below the topmost hair row
HAIR_HALF_WIDTH = 4    # hair stays within this many columns of the head's centre
BODY_HALF_WIDTH = 6    # the jacket stays within this many columns of it (tool handles do not)


def colour_family(rgb) -> str:
    h, s, v = colorsys.rgb_to_hsv(*[c / 255.0 for c in rgb])
    hue = h * 360.0
    warm = hue <= 45.0 or hue >= 340.0
    if warm and v >= 0.78 and 0.15 <= s <= 0.56:
        return "skin"
    if (hue <= 25.0 or hue >= 340.0) and v < 0.40 and s >= 0.25 and v > 0.12:
        return "dark"
    if 15.0 <= hue <= 45.0 and s >= 0.38 and v >= 0.44:
        return "outfit"
    return "other"


def classify(arr: np.ndarray) -> np.ndarray:
    h, w = arr.shape[:2]
    regions = np.zeros((h, w), np.uint8)
    fam = [[None] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if arr[y, x, 3] == 0:
                continue
            f = colour_family(tuple(int(c) for c in arr[y, x, :3]))
            fam[y][x] = f
            if f == "skin":
                regions[y, x] = SKIN
    dark = [(y, x) for y in range(h) for x in range(w) if fam[y][x] == "dark"]
    if not dark:
        return regions
    top = min(y for y, _ in dark)
    top_xs = sorted(x for (y, x) in dark if y <= top + 1)
    cx = top_xs[len(top_xs) // 2]
    for y in range(h):
        for x in range(w):
            if fam[y][x] == "outfit" and abs(x - cx) <= BODY_HALF_WIDTH:
                regions[y, x] = OUTFIT
    dark = [(y, x) for (y, x) in dark if abs(x - cx) <= HAIR_HALF_WIDTH]
    # 8-connected component(s) of dark pixels touching the top two dark rows
    dark_set = set(dark)
    seeds = [(y, x) for (y, x) in dark if y <= top + 1]
    seen = set(seeds)
    stack = list(seeds)
    while stack:
        y, x = stack.pop()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                n = (y + dy, x + dx)
                if n in dark_set and n not in seen and n[0] <= top + HEAD_ROWS:
                    seen.add(n)
                    stack.append(n)
    for (y, x) in seen:
        regions[y, x] = HAIR
    return regions


def frames():
    for action in ACTIONS:
        for facing in FACINGS:
            d = PLAYER / action / facing
            for png in sorted(d.glob("*.png"), key=lambda p: int(p.stem)):
                yield action, facing, png


def build() -> list:
    written = []
    for action, facing, png in frames():
        arr = np.array(Image.open(png).convert("RGBA"))
        regions = classify(arr)
        out = np.zeros(arr.shape, np.uint8)
        for region, col in MASK_COLORS.items():
            out[regions == region] = col
        dest = OUT / action / facing / png.name
        dest.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(out, "RGBA").save(dest, optimize=False)
        written.append(dest)
    return written


def preview(path: pathlib.Path) -> None:
    """Every frame beside its mask overlay, 6x, for review."""
    items = list(frames())
    cols = 8
    rows = (len(items) + cols - 1) // cols
    cell = 24 * 6
    sheet = Image.new("RGBA", (cols * cell * 2, rows * cell), (70, 70, 90, 255))
    for i, (action, facing, png) in enumerate(items):
        src = Image.open(png).convert("RGBA")
        mask = Image.open(OUT / action / facing / png.name).convert("RGBA")
        over = src.copy()
        m = np.array(mask)
        o = np.array(over)
        hit = m[:, :, 3] > 0
        o[hit, :3] = (o[hit, :3] * 0.35 + m[hit, :3] * 0.65).astype(np.uint8)
        over = Image.fromarray(o, "RGBA")
        x = (i % cols) * cell * 2
        y = (i // cols) * cell
        sheet.alpha_composite(src.resize((cell, cell), Image.NEAREST), (x, y))
        sheet.alpha_composite(over.resize((cell, cell), Image.NEAREST), (x + cell, y))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)
