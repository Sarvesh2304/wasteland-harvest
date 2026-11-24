"""Review image for the fishing art (not used by the game): art/env/_previews/fishing.png
(Godot-ignored folder), x4.

  top     the 13 fish, then the 3 dishes, at 1x on the inventory's cream, with existing icons
          (fishing rod, potato, potato hash, pumpkin soup, cooked meal, jerky) for comparison
  middle  the same on the dark warm-outline brown, so silhouettes can be checked both ways
  bottom  a pond at 1x: the player on the bank, the bobber's float and dip frames and the three
          splash frames on the game's water tiles
Composited from the PNGs on disk, so it runs after the asset sections.
"""
from __future__ import annotations

from PIL import Image

CELL = 16
FISH = ["mud_minnow", "shellback_crawdad", "rustgill_carp", "sun_perch", "silver_dace", "ash_trout",
        "bog_eel", "sludge_catfish", "frostfin", "iron_pike", "glowfin", "two_headed_perch", "old_mayor"]
DISHES = ["grilled_fish", "fish_stew", "smoked_eel"]
NEIGHBOURS = ["fishing_rod", "mutant_potato", "potato_hash", "pumpkin_soup", "cooked_meal", "mystery_jerky"]


def _img(repo, rel):
    return Image.open(repo / rel).convert("RGBA")


def _frame(img, i, n):
    w = img.width // n
    return img.crop((i * w, 0, i * w + w, img.height))


def _paste(im, img, x, y):
    tmp = Image.new("RGBA", im.size)
    tmp.paste(img, (x, y))
    im.alpha_composite(tmp)


def _tile(repo, name, w, h, variants=4):
    tiles = _img(repo, f"art/env/terrain/{name}.png")
    n = max(1, min(variants, tiles.width // CELL))
    bg = Image.new("RGBA", (w, h))
    for ty in range(0, h, CELL):
        for tx in range(0, w, CELL):
            v = (tx // CELL * 7 + ty // CELL * 3) % n
            bg.alpha_composite(tiles.crop((v * CELL, 0, v * CELL + CELL, CELL)), (tx, ty))
    return bg


def icons(repo, bg):
    names = FISH + [None] + DISHES + [None] + NEIGHBOURS
    W = 8 + sum(12 if n is None else 18 for n in names)
    im = Image.new("RGBA", (W, 24), bg)
    x = 8
    for n in names:
        if n is None:
            x += 12
            continue
        _paste(im, _img(repo, f"art/items/{n}.png"), x, 4)
        x += 18
    return im


def pond(repo, width):
    W, H = width, 4 * CELL
    im = _tile(repo, "grass_summer", W, H, variants=8)
    water = _tile(repo, "water_full", W - 3 * CELL, 3 * CELL)
    im.alpha_composite(water, (3 * CELL, CELL))
    player = _img(repo, "art/characters/player/rotations/east.png")
    _paste(im, player, CELL - 4, 2 * CELL - 21 + 16 - 8)
    bob = _img(repo, "art/fx/bobber.png")
    splash = _img(repo, "art/fx/splash.png")
    # bobber frames: the frame's waterline pixel (4, 5) on a cell centre
    for i, cx in enumerate((5, 7)):
        _paste(im, _frame(bob, i, 2), cx * CELL + 8 - 4, 2 * CELL + 8 - 5)
    for i in range(3):
        _paste(im, _frame(splash, i, 3), (9 + 2 * i) * CELL, 2 * CELL - 4)
    # a cast line from the rod tip to the floating bobber, the way the game draws it (Line2D)
    line = (232, 226, 210, 200)
    x0, y0, x1, y1 = CELL + 14, 2 * CELL - 2, 5 * CELL + 8, 2 * CELL + 4
    for k in range(160):
        t = k / 159
        x = round(x0 + (x1 - x0) * t)
        y = round(y0 + (y1 - y0) * t + 6 * t * (1 - t))
        im.putpixel((x, y), line)
    return im


def build(repo, scale=4):
    light = icons(repo, (255, 236, 180, 255))
    dark = icons(repo, (40, 26, 11, 255))
    parts = [light, dark, pond(repo, light.width)]
    W = max(p.width for p in parts)
    H = sum(p.height for p in parts) + 2 * (len(parts) - 1)
    out = Image.new("RGBA", (W, H), (40, 26, 11, 255))
    y = 0
    for p in parts:
        out.alpha_composite(p, (0, y))
        y += p.height + 2
    return out.resize((W * scale, H * scale), Image.NEAREST)
