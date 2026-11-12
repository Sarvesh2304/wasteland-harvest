"""Review image for the living-settlement art (not used by the game):
art/env/_previews/living.png (Godot-ignored folder), x4.

  top     a town-square mock on spring grass, 1x pixels: the mayor's house with its mast, the
          trading post, the open market stall with Tully in front (and the plain stall beside it
          for comparison), the festival booth, food table, bunting, both lantern frames (lit one
          on a dusk-tinted patch), seed packets in the grass, the four tinted race goats, the
          player for scale. Everything stands on its footprint the way the game places it
          (bottom-centre on the footprint's bottom edge), depth-sorted by that edge.
  middle  the vault door, sealed and open, on ruins ground beside a manhole and the player
  bottom  the two item icons beside existing icons, on the inventory's cream
Composited from the PNGs on disk, so it runs after the asset sections.
"""
from __future__ import annotations

from PIL import Image

CELL = 16
GOAT_TINTS = ["#e8e2d2", "#b98a5a", "#8f8f9c", "#d6c27a"]    # scripts/festivals.gd GOAT_TINTS


def _tile(repo, name, w, h, variants=8):
    tiles = Image.open(repo / f"art/env/terrain/{name}.png").convert("RGBA")
    n = max(1, min(variants, tiles.width // CELL))
    bg = Image.new("RGBA", (w, h))
    for ty in range(0, h, CELL):
        for tx in range(0, w, CELL):
            v = (tx // CELL * 7 + ty // CELL * 3) % n
            bg.alpha_composite(tiles.crop((v * CELL, 0, v * CELL + CELL, CELL)), (tx, ty))
    return bg


def _img(repo, rel):
    return Image.open(repo / rel).convert("RGBA")


def _frame(img, i, n):
    w = img.width // n
    return img.crop((i * w, 0, i * w + w, img.height))


def _tint(img, hexcol):
    r, g, b = int(hexcol[1:3], 16), int(hexcol[3:5], 16), int(hexcol[5:7], 16)
    px = img.load()
    out = img.copy()
    po = out.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            po[x, y] = (p[0] * r // 255, p[1] * g // 255, p[2] * b // 255, p[3])
    return out


def _paste(im, img, x, y):
    tmp = Image.new("RGBA", im.size)
    tmp.paste(img, (x, y))
    im.alpha_composite(tmp)


def square(repo):
    W, H = 22 * CELL, 14 * CELL
    im = _tile(repo, "grass_spring", W, H)
    # a dusk patch under the lit lantern so its glow reads
    dusk = Image.new("RGBA", (3 * CELL, 3 * CELL), (27, 34, 56, 110))
    im.alpha_composite(dusk, (17 * CELL, 8 * CELL))
    stall_open = _img(repo, "art/env/props/market_stall_open.png")
    lantern = _img(repo, "art/env/props/festival_lantern.png")
    goats = _img(repo, "art/fx/race_goat.png")
    tully = _img(repo, "art/characters/caravan_trader/rotations/south.png")
    player = _img(repo, "art/characters/player/rotations/south.png")
    packet = _img(repo, "art/env/props/seed_packet.png")
    # (image, footprint x, footprint bottom row (cell), footprint width in cells)
    items = [
        (_img(repo, "art/buildings/mayor_house_antenna.png"), 1, 5, 4),
        (_img(repo, "art/buildings/trading_post.png"), 6, 5, 3),
        (stall_open, 10, 5, 3),
        (_img(repo, "art/env/props/market_stall.png"), 14, 5, 3),
        (_img(repo, "art/buildings/festival_table.png"), 7, 10, 2),
        (_img(repo, "art/buildings/festival_booth.png"), 11, 10, 2),
        (_frame(lantern, 0, 2), 5, 10, 1),
        (_frame(lantern, 1, 2), 18, 10, 1),
        (packet, 3, 12, 1), (packet, 16, 13, 1), (packet, 20, 6, 1),
    ]
    sprites = []
    for (img, fx, bottom, fw) in items:
        x = fx * CELL + (fw * CELL - img.width) // 2
        sprites.append((bottom * CELL, x, bottom * CELL - img.height, img))
    # characters: feet (lowest opaque row 20 of a 24 x 24 frame) on the cell's bottom edge
    for (img, cx, cy) in ((tully, 11, 5), (player, 9, 11)):
        sprites.append(((cy + 1) * CELL, cx * CELL + 8 - 12, (cy + 1) * CELL - 21, img))
    # race goats crossing the bottom-right, one frame each, tinted like the game
    for i in range(4):
        g = _tint(_frame(goats, i, 4), GOAT_TINTS[i])
        x, y = 15 * CELL + i * 9, 11 * CELL + i * 6
        sprites.append((y + 16, x, y, g))
    for (_, x, y, img) in sorted(sprites, key=lambda t: (t[0], t[1])):
        _paste(im, img, x, y)
    # bunting hangs over the square (no footprint, drawn above everything)
    bunting = _img(repo, "art/env/props/bunting.png")
    for k in range(3):
        _paste(im, bunting, 6 * CELL + k * 64, 8 * CELL - 16)
    return im


def ruins(repo):
    W, H = 22 * CELL, 3 * CELL
    im = _tile(repo, "ruins_ground", W, H)
    vault = _img(repo, "art/env/ruins/vault_door.png")
    _paste(im, _frame(vault, 0, 2), 2 * CELL, 8)
    _paste(im, _frame(vault, 1, 2), 5 * CELL, 8)
    _paste(im, _img(repo, "art/env/ruins/manhole.png"), 8 * CELL, 2 * CELL)
    _paste(im, _img(repo, "art/characters/player/rotations/south.png"), 7 * CELL + 4, 2 * CELL - 4)
    _paste(im, _img(repo, "art/env/ruins/oil_drum.png"), 11 * CELL, 8)
    return im


def icons(repo):
    W, H = 22 * CELL, 24
    im = Image.new("RGBA", (W, H), (255, 236, 180, 255))
    names = ["vault_seeds", "festival_ribbon", None, "keycard", "seed_mixed", "canned_beans",
             "bottle_caps", "radio_part", "lore_note"]
    x = 8
    for n in names:
        if n is None:
            x += 12
            continue
        _paste(im, _img(repo, f"art/items/{n}.png"), x, 4)
        x += 20
    return im


def build(repo, scale=4):
    parts = [square(repo), ruins(repo), icons(repo)]
    W = max(p.width for p in parts)
    H = sum(p.height for p in parts) + 2 * (len(parts) - 1)
    out = Image.new("RGBA", (W, H), (40, 26, 11, 255))
    y = 0
    for p in parts:
        out.alpha_composite(p, (0, y))
        y += p.height + 2
    return out.resize((W * scale, H * scale), Image.NEAREST)
