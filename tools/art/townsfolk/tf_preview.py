"""Review images for the townsfolk / Town Works art (not used by the game).

  art/characters/townsfolk_preview.png  Marta and Mayor Harlan (PixelLab) above Brask, Wren and
                                        Doc Ama: idle S / N / E / W, then the walk S and walk E
                                        cycles, on spring grass, x5
  art/buildings/_works_preview.png      every Town Works sprite placed on its footprint the way the
                                        game places it (bottom edge on the footprint's bottom edge,
                                        centred), on grass, depth-sorted, with townsfolk for scale:
                                        the greenhouse restored (with crops) and ruined, the clinic
                                        ruined with Doc's tent and rebuilt, store.png beside
                                        store_expanded, the watchtower; x3
Composited from the PNGs on disk, so run it after the other sections.
"""
from __future__ import annotations

from PIL import Image

REFS = ["marta", "mayor_harlan"]
NEW = ["brask", "wren", "doc_ama"]
DIRS = ["south", "north", "east", "west"]
CELL = 16


def _grass(repo, w, h, season="spring"):
    tiles = Image.open(repo / f"art/env/terrain/grass_{season}.png").convert("RGBA")
    bg = Image.new("RGBA", (w, h))
    for ty in range(0, h, CELL):
        for tx in range(0, w, CELL):
            v = (tx // CELL * 7 + ty // CELL * 3) % 8
            bg.alpha_composite(tiles.crop((v * CELL, 0, v * CELL + CELL, CELL)), (tx, ty))
    return bg


def _frame(repo, cid, act, d, i):
    return Image.open(repo / f"art/characters/{cid}/{act}/{d}/{i}.png").convert("RGBA")


def characters(repo, scale=5):
    cols = [("idle", d, 0) for d in DIRS] + [None] + [("walk", "south", i) for i in range(4)] + \
           [None] + [("walk", "east", i) for i in range(4)]
    rows = REFS + NEW
    gap = 4
    w = sum(24 if c else gap for c in cols) + 2 * gap
    h = len(rows) * 24 + (len(rows) + 1) * 2 + gap
    im = _grass(repo, w, h)
    for r, cid in enumerate(rows):
        y = gap + r * 26 + (gap if r >= len(REFS) else 0)
        x = gap
        for c in cols:
            if c is None:
                x += gap
                continue
            im.alpha_composite(_frame(repo, cid, *c), (x, y))
            x += 24
    return im.resize((w * scale, h * scale), Image.NEAREST)


def works(repo, scale=3):
    B = repo / "art/buildings"

    def png(name):
        return Image.open(B / f"{name}.png").convert("RGBA")

    W, H = 25 * CELL, 15 * CELL
    im = _grass(repo, W, H)
    dirt = Image.open(repo / "art/env/terrain/dirt_full.png").convert("RGBA")
    crop = Image.open(repo / "art/crops/sunbloom/stage_3.png").convert("RGBA")
    crop2 = Image.open(repo / "art/crops/mutant_potato/stage_3.png").convert("RGBA")
    draws = []          # (sort_y, x, y, image)

    def place(img, cx, cy, fw, fh):
        """Bottom edge on the bottom of footprint (cx, cy, fw x fh cells), centred."""
        bx = cx * CELL + (fw * CELL - img.width) // 2
        by = (cy + fh) * CELL - img.height
        draws.append(((cy + fh) * CELL, bx, by, img))

    def person(cid, d, cx, cy):
        img = _frame(repo, cid, "idle", d, 0)
        draws.append(((cy + 1) * CELL - 3, cx * CELL - 4, (cy + 1) * CELL - 4 - 21, img))

    # -- the greenhouse, restored (crops inside) and ruined (weedy, empty) --
    for (gx, ruined) in ((1, False), (14, True)):
        gy = 2
        suf = "_ruined" if ruined else ""
        back, side, front = png("greenhouse_back" + suf), png("greenhouse_side" + suf), \
            png("greenhouse_front" + suf)
        side_e = side.transpose(Image.FLIP_LEFT_RIGHT)
        if not ruined:
            for r in range(1, 5):
                for c in range(1, 7):
                    v = (r * 3 + c) % 4
                    im.alpha_composite(dirt.crop((v * CELL, 0, v * CELL + CELL, CELL)),
                                       ((gx + c) * CELL, (gy + r) * CELL))
        place(back, gx, gy, 8, 1)
        for r in range(1, 5):
            region = (0, (r - 1) * CELL, CELL, r * CELL)
            place(side.crop(region), gx, gy + r, 1, 1)
            place(side_e.crop(region), gx + 7, gy + r, 1, 1)
            if not ruined:
                for c in range(1, 7):
                    place(crop if (r + c) % 2 else crop2, gx + c, gy + r, 1, 1)
        place(front, gx, gy + 5, 8, 1)
    person("player", "north", 4, 7)
    person("mayor_harlan", "south", 20, 7)
    # -- the clinic, ruined with Doc's tent beside it, and rebuilt --
    place(png("town_clinic_ruined"), 1, 10, 4, 3)
    place(png("doc_tent"), 5, 11, 2, 2)
    person("doc_ama", "south", 7, 12)
    place(png("town_clinic"), 9, 10, 4, 3)
    # -- the store before / after, the watchtower --
    place(png("store"), 14, 11, 3, 2)
    place(png("store_expanded"), 18, 11, 3, 2)
    person("marta", "south", 17, 13)
    place(png("watchtower"), 22, 11, 2, 2)
    person("brask", "east", 21, 13)
    person("wren", "west", 13, 13)
    for (_, x, y, img) in sorted(draws, key=lambda d: (d[0], d[1])):
        im.alpha_composite(img, (x, y)) if x >= 0 and y >= 0 else _paste_clip(im, img, x, y)
    return im.resize((W * scale, H * scale), Image.NEAREST)


def _paste_clip(im, img, x, y):
    cx0, cy0 = max(0, -x), max(0, -y)
    part = img.crop((cx0, cy0, img.width, img.height))
    im.alpha_composite(part, (max(0, x), max(0, y)))


def caravan(repo, scale=5):
    """art/characters/caravan_preview.png: Marta, Brask and Tully (caravan_trader) side by side,
    idle S / N / E / W then the walk east cycle; under them Tully's walk south and walk west
    cycles. Spring grass, x5."""
    gap = 4
    cols = [("idle", d, 0) for d in DIRS] + [None] + [("walk", "east", i) for i in range(4)]
    rows = [("marta", cols), ("brask", cols), ("caravan_trader", cols),
            ("caravan_trader", [("walk", "south", i) for i in range(4)] + [None] +
             [("walk", "west", i) for i in range(4)])]
    w = 8 * 24 + 3 * gap
    h = len(rows) * 24 + (len(rows) + 1) * 2 + 2 * gap
    im = _grass(repo, w, h)
    for r, (cid, cells) in enumerate(rows):
        y = gap + r * 26 + (gap if r == len(rows) - 1 else 0)
        x = gap
        for c in cells:
            if c is None:
                x += gap
                continue
            im.alpha_composite(_frame(repo, cid, *c), (x, y))
            x += 24
    return im.resize((w * scale, h * scale), Image.NEAREST)
