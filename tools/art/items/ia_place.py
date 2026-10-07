"""Placeable objects: inventory icons (16x16) and world sprites (art/items/world/<id>.png).

World sprites are 16 px wide, 16 or 32 px tall, bottom-centre anchored: the object's base sits on
the bottom row, with a soft contact shadow (#281a0b at ~35% alpha) offset to the bottom-right.
Animated objects are horizontal strips of equal frames (e.g. idle | working).
Icons of the small objects reuse the world drawing; tall objects get a compact icon drawing.
"""
from __future__ import annotations

import numpy as np

import ia_lib as L
from ia_lib import Ramp
from ia_common import C

WOOD = Ramp(C.WOOD)
WOOD5 = Ramp(C.WOOD[1:])
STONE = Ramp(C.STONE)
IRON = Ramp(C.IRON)
RUST = Ramp(C.RUST)
COPPER = Ramp(C.COPPER)
STEEL = Ramp(C.STEEL)
BLUE = Ramp(C.BLUE_STEEL)
GOLD = Ramp(C.GOLD)
GLASS = Ramp(C.GLASS)
CLAY = Ramp(["#3e1c12", "#5e2c1a", "#7e4026", "#9e5634", "#bc7046", "#d68e5e"])
LAMP = Ramp(["#a0600c", "#d08a18", "#f0b02a", "#ffc948", "#ffe48a", "#fff6d0"])
EMBER = Ramp(["#7a2006", "#b0400a", "#e06a12", "#ff9a2a", "#ffc948", "#fff0a0"])
SMOKE = (122, 112, 100, 150)
SHADOW = dict(alpha=90)


def shadow(img, cx, rx, ry=1.6, dy=0.0):
    h = img.shape[0]
    return L.add_shadow(img, cx + 0.8, h - 0.6 + dy, rx, ry, alpha=90)


def strip(*frames):
    return np.concatenate(frames, axis=1)


def world_to_icon(img, dy=None):
    """Fit a 16x16 world sprite into the icon frame (content moved so it sits inside the 1 px
    margin, shadow removed)."""
    out = img.copy()
    out[(out[:, :, 3] > 0) & (out[:, :, 3] < 255)] = 0
    a = out[:, :, 3] > 0
    ys, xs = np.nonzero(a)
    top, bot = ys.min(), ys.max()
    left, right = xs.min(), xs.max()
    h = bot - top + 1
    w = right - left + 1
    ty = (16 - h) // 2
    tx = (16 - w) // 2
    return L.offset(out[top:bot + 1, left:right + 1], tx, ty, 16, 16)


# ----------------------------------------------------------------------------------------------
# crate chest (16x16)
# ----------------------------------------------------------------------------------------------

def crate_chest_world():
    s, lays = L.icon("""
        ................
        ................
        ................
        ..TTTTTTTTTTTT..
        ..TTTTTTTTTTTT..
        ..tttttttttttt..
        ..mffffllffffm..
        ..mffffllffffm..
        ..mxxxxxxxxxxm..
        ..mffffffffffm..
        ..mffffffffffm..
        ..mxxxxxxxxxxm..
        ..mffffffffffm..
        ..mffffffffffm..
        ..mmmmmmmmmmmm..
        ................
    """, {
        "T": (WOOD5, "flat", {"base": 3, "lit": 4, "dark": 2}),
        "t": (WOOD5, "solid", {"index": 1}),
        "f": (WOOD5, "flat", {"base": 2, "lit": 3, "dark": 1}),
        "x": (WOOD5, "solid", {"index": 0}),
        "m": (Ramp(C.IRON[1:]), "flat", {"base": 2, "lit": 3, "dark": 1}),
        "l": (Ramp(C.BRASS[1:]), "flat", {"base": 2, "lit": 3, "dark": 1, "sep": "outer", "sep_idx": 0}),
    }, render=False)
    s.puts([(4, 3), (8, 4), (11, 3)], C.WOOD[3], WOOD5)   # plank seams on the lid
    img = L.offset(s.render(), 0, 1, 16, 16)
    return shadow(img, 8.0, 7.0)


# ----------------------------------------------------------------------------------------------
# sprinklers (16x16)
# ----------------------------------------------------------------------------------------------

def scrap_sprinkler_world():
    img = L.icon("""
        ................
        ................
        ................
        ................
        ................
        ................
        ................
        .......nn.......
        ....hhhhhhhh....
        ....hhhhhhhh....
        .......pp.......
        .......gg.......
        .......pp.......
        ......bbbb......
        .....bbbbbb.....
        ................
    """, {
        "p": (Ramp(C.RUST), "cyl", {"axis": 90, "contrast": 2.0}),
        "g": (Ramp(["#5e5646", "#8c826a", "#bcb294", "#ddd4b8"]), "cyl", {"axis": 90}),
        "b": (Ramp(C.RUST[:5]), "flat", {"base": 2, "lit": 3, "dark": 1}),
        "h": (Ramp(C.IRON[1:]), "flat", {"base": 2, "lit": 3, "dark": 1, "sep": "outer", "sep_idx": 0}),
        "n": (Ramp(C.RUST), "flat", {"base": 3, "lit": 4, "dark": 2}),
    })
    img = L.offset(img, 0, 1, 16, 16)
    return shadow(img, 8.0, 4.5)


def quality_sprinkler_world():
    img = L.icon("""
        ................
        ................
        ................
        ................
        ................
        .......nn.......
        ...hhhhhhhhhh...
        ...hhhhhhhhhh...
        ......cccc......
        .....cddddc.....
        .....cdkddc.....
        .....cddddc.....
        ......cccc......
        .....bbbbbb.....
        ....bbbbbbbb....
        ................
    """, {
        "c": (COPPER, "cyl", {"axis": 90, "contrast": 2.0, "gloss": True, "gloss_cut": 0.7}),
        "d": (Ramp(C.CLOTH_WHITE), "flat", {"base": 3, "lit": 4, "dark": 2}),
        "b": (Ramp(C.COPPER[:5]), "flat", {"base": 2, "lit": 3, "dark": 1}),
        "h": (COPPER, "flat", {"base": 3, "lit": 4, "dark": 2, "sep": "outer", "sep_idx": 1}),
        "n": (Ramp(C.BRASS), "flat", {"base": 3, "lit": 4, "dark": 2}),
    }, {"k": ("put", "#a8281a")})
    img = L.offset(img, 0, 1, 16, 16)
    return shadow(img, 8.0, 5.0)


def prewar_sprinkler_world():
    img = L.icon("""
        ................
        ................
        ................
        ................
        .......gg.......
        ..aaa.dddd.aaa..
        ....adddddda....
        .....dddddd.....
        .....GGGGGG.....
        .....dddddd.....
        .....dddddd.....
        ......dddd......
        .....GGGGGG.....
        ....bbbbbbbb....
        ...bbbbbbbbbb...
        ................
    """, {
        "d": (BLUE, "sphere", {"contrast": 2.0, "gloss": True, "gloss_cut": 0.6}),
        "a": (Ramp(C.STEEL[1:]), "flat", {"base": 2, "lit": 3, "dark": 1}),
        "G": (GOLD, "flat", {"base": 3, "lit": 4, "dark": 2}),
        "g": (GOLD, "solid", {"index": 4}),
        "b": (Ramp(C.BLUE_STEEL[:5]), "flat", {"base": 2, "lit": 3, "dark": 1}),
    })
    img = L.offset(img, 0, 1, 16, 16)
    return shadow(img, 8.0, 5.5)


# ----------------------------------------------------------------------------------------------
# oil lamp (16x32, 2 frames: unlit, lit) -- lantern on a wooden post
# ----------------------------------------------------------------------------------------------

LANTERN = """
    .......hh.......
    ......h..h......
    .....cccccc.....
    ....cccccccc....
    .....fGGGGf.....
    .....fGGGGf.....
    .....fGGGGf.....
    .....fGGGGf.....
    ....cccccccc....
    .....cccccc.....
"""


def _lantern(lit: bool, h=32, top=2, post=True):
    s = L.Sprite(16, h)
    if post:
        p = s.layer(WOOD5, "cyl", axis=90, contrast=2.0)
        p.rect(7, top + 10, 8, h - 3)
        foot = s.layer(Ramp(C.STONE[1:]), "flat", base=2, lit=3, dark=1)
        foot.ascii(L.grid("""
            .....######.....
            ....########....
        """), 0, h - 2)
    lays = {
        "h": s.layer(Ramp(C.IRON[1:]), "flat", base=1, lit=2, dark=0),
        "c": s.layer(Ramp(C.IRON[1:]), "flat", base=2, lit=3, dark=1, sep="outer", sep_idx=0),
        "f": s.layer(Ramp(C.IRON[1:]), "solid", index=1),
        "G": s.layer(LAMP if lit else GLASS, "cyl", axis=90, contrast=1.4 if lit else 2.0,
                     bias=1.0 if lit else 0.0),
    }
    L.paint(lays, L.grid(LANTERN), {k: k for k in lays}, 0, top)
    if lit:
        s.puts([(7, top + 5), (8, top + 5), (7, top + 6), (8, top + 6)], C.CLOTH_WHITE[4], LAMP)
        s.puts([(7, top + 4)], LAMP[5], LAMP)
    else:
        s.puts([(7, top + 6), (8, top + 6)], C.WOOD[1], GLASS)
    img = s.render()
    return img


def oil_lamp_world():
    a = shadow(_lantern(False), 8.0, 4.0)
    b = shadow(_lantern(True), 8.0, 4.0)
    return strip(a, b)


def oil_lamp_icon():
    img = _lantern(True, h=16, top=2, post=False)
    return world_to_icon(img)


# ----------------------------------------------------------------------------------------------
# compost bin (16x16)
# ----------------------------------------------------------------------------------------------

def compost_bin_world():
    img = L.icon("""
        ................
        ................
        ................
        ................
        ......dddd......
        ....ddgdddgd....
        ..ssdddddddds...
        ..sxsxsxsxsxsx..
        ..sxsxsxsxsxsx..
        ..sxsxsxsxsxsx..
        ..sxsxsxsxsxsx..
        ..sxsxsxsxsxsx..
        ..sxsxsxsxsxsx..
        ..ssssssssssss..
        ..p..........p..
        ................
    """, {
        "d": (Ramp(C.SOIL[:5]), "inflate", {"contrast": 2.2}),
        "s": (WOOD5, "flat", {"base": 3, "lit": 4, "dark": 2}),
        "x": (WOOD5, "flat", {"base": 1, "lit": 2, "dark": 0}),
        "p": (WOOD5, "solid", {"index": 0}),
    }, {"g": ("put", C.LEAF[4])})
    img = L.offset(img, 0, 1, 16, 16)
    return shadow(img, 8.0, 7.0)


# ----------------------------------------------------------------------------------------------
# smelter (16x32, idle | working): stone furnace with a chimney
# ----------------------------------------------------------------------------------------------

SMELTER = """
    ................
    ................
    ................
    ................
    ................
    ......cccc......
    ......cccc......
    ......cccc......
    ......cccc......
    .....rrrrrr.....
    .....ssssss.....
    .....ssssss.....
    ....ssssssss....
    ....ssssssss....
    ...ssssssssss...
    ...ssssssssss...
    ..ssssssssssss..
    ..ssssssssssss..
    ..ssssssssssss..
    ..sssssMMsssss..
    ..ssssMMMMssss..
    ..sssMMMMMMsss..
    ..sssMMMMMMsss..
    ..sssMMMMMMsss..
    ..sssMMMMMMsss..
    ..ssssssssssss..
    ..ssssssssssss..
    .bbbbbbbbbbbbbb.
    .bbbbbbbbbbbbbb.
    ................
    ................
    ................
"""


def _bricks(lay, x0, x1, y0, y1, offset=0):
    """Mortar lines: every 2nd row is a seam, vertical joints staggered."""
    pts = []
    for y in range(y0, y1 + 1):
        if (y - y0) % 3 == 2:
            pts += [(x, y) for x in range(x0, x1 + 1)]
        else:
            row = (y - y0) // 3
            for x in range(x0, x1 + 1):
                if (x + offset + (2 if row % 2 else 0)) % 4 == 0:
                    pts.append((x, y))
    pts = [(x, y) for (x, y) in pts if lay.mask[y, x]]
    lay.nudge(pts, -1)


def _furnace(rows, working, body_ramp, mouth_rows=None, h=32, smoke_at=None):
    s = L.Sprite(16, h)
    lays = {
        "c": s.layer(Ramp(C.STONE[:5]), "cyl", axis=90, contrast=1.8),
        "r": s.layer(Ramp(C.IRON[1:]), "flat", base=2, lit=3, dark=1, sep="outer", sep_idx=0),
        "s": s.layer(body_ramp, "inflate", contrast=1.6, bevel=3),
        "b": s.layer(Ramp(C.STONE[:5]), "flat", base=2, lit=3, dark=1, sep="outer", sep_idx=0),
        "M": s.layer(EMBER if working else Ramp(C.CHARCOAL), "sphere" if working else "flat",
                     contrast=1.4, bias=1.2 if working else 0.0, base=1, lit=1, dark=0,
                     sep="outer", sep_idx=0),
    }
    L.paint(lays, L.grid(rows), {k: k for k in lays})
    ys, xs = np.nonzero(lays["s"].mask)
    _bricks(lays["s"], xs.min(), xs.max(), ys.min(), ys.max())
    img = s.render()
    if working and smoke_at:
        for (x, y) in smoke_at:
            if img[y, x, 3] == 0:
                img[y, x] = SMOKE
    return img


def smelter_world():
    idle = _furnace(SMELTER, False, STONE)
    work = _furnace(SMELTER, True, STONE, smoke_at=[(7, 3), (8, 3), (8, 2), (9, 2), (9, 1), (8, 4), (7, 4)])
    return strip(shadow(idle, 8.0, 7.5), shadow(work, 8.0, 7.5))


SMELTER_ICON = """
    ................
    ................
    ......cccc......
    ......cccc......
    .....rrrrrr.....
    ....ssssssss....
    ...ssssssssss...
    ..ssssssssssss..
    ..sssssMMsssss..
    ..ssssMMMMssss..
    ..sssMMMMMMsss..
    ..sssMMMMMMsss..
    ..ssssssssssss..
    ..bbbbbbbbbbbb..
    ................
    ................
"""


def smelter_icon():
    return _furnace(SMELTER_ICON, True, STONE, h=16)


# ----------------------------------------------------------------------------------------------
# kiln (16x32, idle | working): clay beehive dome
# ----------------------------------------------------------------------------------------------

KILN = """
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    .......cc.......
    .......cc.......
    .....ssssss.....
    ....ssssssss....
    ...ssssssssss...
    ..ssssssssssss..
    ..ssssssssssss..
    .ssssssssssssss.
    .ssssssssssssss.
    .ssssssssssssss.
    .sssssMMMMsssss.
    .ssssMMMMMMssss.
    .ssssMMMMMMssss.
    .ssssMMMMMMssss.
    .ssssMMMMMMssss.
    .ssssMMMMMMssss.
    .ssssssssssssss.
    bbbbbbbbbbbbbbbb
    ................
    ................
    ................
    ................
    ................
"""


def kiln_world():
    def fr(working):
        img = _furnace(KILN, working, CLAY, smoke_at=[(7, 8), (8, 7), (8, 6), (9, 5), (9, 4), (8, 8)])
        return L.offset(img, 0, 5, 16, 32)
    return strip(shadow(fr(False), 8.0, 7.5), shadow(fr(True), 8.0, 7.5))


KILN_ICON = """
    ................
    ................
    .......cc.......
    .....ssssss.....
    ....ssssssss....
    ...ssssssssss...
    ..ssssssssssss..
    ..ssssssssssss..
    ..ssssMMMMssss..
    ..sssMMMMMMsss..
    ..sssMMMMMMsss..
    ..sssMMMMMMsss..
    ..ssssssssssss..
    ..bbbbbbbbbbbb..
    ................
    ................
"""


def kiln_icon():
    return _furnace(KILN_ICON, True, CLAY, h=16)


# ----------------------------------------------------------------------------------------------
# recycler (16x32, idle | working): riveted cabinet with a hopper
# ----------------------------------------------------------------------------------------------

RECYCLER = """
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    ...hhhhhhhhhh...
    ...hhhhhhhhhh...
    ....hhhhhhhh....
    .....hhhhhh.....
    ..mmmmmmmmmmmm..
    ..mpmmmmmmmmpm..
    ..mmmmmmmmmmmm..
    ..mmGGGGmmmmmm..
    ..mmGGGGmmLmmm..
    ..mmGGGGmmmmmm..
    ..mmGGGGmmmmmm..
    ..mmmmmmmmmmmm..
    ..mpmmmmmmmmpm..
    ..mmmmmmmmmmmm..
    ..mmmmoooommmm..
    ..mmmmoooommmm..
    ..mmmmmmmmmmmm..
    ..ff........ff..
    ................
    ................
    ................
    ................
"""


def _recycler(rows, working, h=32):
    s = L.Sprite(16, h)
    lays = {
        "h": s.layer(Ramp(C.RUST), "flat", base=3, lit=4, dark=2),
        "m": s.layer(Ramp(C.OLIVE_DRAB), "flat", base=3, lit=4, dark=2, sep="outer", sep_idx=1),
        "G": s.layer(Ramp(C.IRON[1:]), "flat", base=1, lit=2, dark=0),
        "o": s.layer(Ramp(C.CHARCOAL), "solid", index=1),
        "f": s.layer(Ramp(C.IRON[:4]), "solid", index=1),
        "p": s.layer(Ramp(C.IRON[1:]), "solid", index=4),
        "L": s.layer(LAMP if working else Ramp(C.IRON[:4]), "solid", index=3 if working else 1),
    }
    L.paint(lays, L.grid(rows), {k: k for k in lays})
    # gear teeth drawn in the grille window
    ys, xs = np.nonzero(lays["G"].mask)
    if len(xs):
        x0, y0 = xs.min(), ys.min()
        pts = [(x0 + 1, y0), (x0 + 3, y0 + 1), (x0 + 2, y0 + 3), (x0, y0 + 2)] if not working else \
              [(x0 + 2, y0), (x0 + 3, y0 + 2), (x0 + 1, y0 + 3), (x0, y0 + 1)]
        lays["G"].nudge(pts, 2)
    img = s.render()
    if working:
        ys, xs = np.nonzero(lays["o"].mask)
        if len(xs):
            img[ys.max(), xs.min() + 1] = L.rgba(C.COPPER[4])
            img[ys.max() - 1, xs.max() - 1] = L.rgba(C.TIN[4])
    return img


def recycler_world():
    return strip(shadow(_recycler(RECYCLER, False), 8.0, 7.0), shadow(_recycler(RECYCLER, True), 8.0, 7.0))


RECYCLER_ICON = """
    ................
    ................
    ...hhhhhhhhhh...
    ....hhhhhhhh....
    ..mmmmmmmmmmmm..
    ..mpmmmmmmmmpm..
    ..mmGGGGmmmmmm..
    ..mmGGGGmmLmmm..
    ..mmGGGGmmmmmm..
    ..mmGGGGmmmmmm..
    ..mmmmmmmmmmmm..
    ..mmmmoooommmm..
    ..mpmmoooommpm..
    ..mmmmmmmmmmmm..
    ................
    ................
"""


def recycler_icon():
    return _recycler(RECYCLER_ICON, True, h=16)


# ----------------------------------------------------------------------------------------------
# preserves jar (16x32, idle | working)
# ----------------------------------------------------------------------------------------------

def _pjar(working, h=32, top=12, body=14):
    s = L.Sprite(16, h)
    lid = s.layer(WOOD5, "flat", base=3, lit=4, dark=2, sep="outer", sep_idx=0)
    lid.ascii(L.grid("""
        ....########....
        ...##########...
    """), 0, top)
    neck = s.layer(GLASS, "solid", index=2)
    neck.ascii(["....########...."], 0, top + 2)
    jar = s.layer(GLASS, "cyl", axis=90, contrast=2.0, bias=0.6)
    jar.rect(3, top + 3, 12, top + 3 + body - 1)
    jar.px((3, top + 3), (12, top + 3), (3, top + 2 + body), (12, top + 2 + body), add=False)
    fill_top = top + (5 if working else body - 1)
    content = s.layer(Ramp(C.JAM), "cyl", axis=90, contrast=1.8, gloss=True, gloss_cut=0.7)
    for y in range(fill_top, top + 2 + body):
        for x in range(4, 12):
            if jar.mask[y, x]:
                content.px((x, y))
    if working:
        rng = np.random.default_rng(7)
        fruit = [C.CLOTH_RED[4], "#e8a028", C.LEAF[4], C.JAM[4], "#f0c040"]
        for i in range(10):
            x = int(rng.integers(4, 12))
            y = int(rng.integers(fill_top + 1, top + 1 + body))
            if content.mask[y, x]:
                s.put(x, y, fruit[i % len(fruit)], Ramp(C.JAM))
        s.puts([(6, fill_top - 1), (9, fill_top - 2)], C.CLOTH_WHITE[4], GLASS)
    img = s.render()
    return img


def preserves_jar_world():
    return strip(shadow(_pjar(False), 8.0, 6.0), shadow(_pjar(True), 8.0, 6.0))


def preserves_jar_icon():
    return world_to_icon(_pjar(True, h=16, top=1, body=11))


# ----------------------------------------------------------------------------------------------
# copper still (16x32, idle | working)
# ----------------------------------------------------------------------------------------------

STILL = """
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    ......cc........
    .....cccc.......
    ......pppppp....
    ....kkkk...pp...
    ...kkkkkk...p...
    ..kkkkkkkk..cc..
    ..kkkkkkkk.cccc.
    ..kkkkkkkk.cccc.
    ..kkkkkkkk..cc..
    ..kkkkkkkk.cccc.
    ...kkkkkk..cccc.
    ...bbbbbb..jjjj.
    ...bFFFFb..jjjj.
    ...bFFFFb..jjjj.
    ...bbbbbb..jjjj.
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    ................
"""


def _still(rows, working, h=32, dy=7):
    s = L.Sprite(16, h)
    lays = {
        "c": s.layer(COPPER, "flat", base=3, lit=4, dark=2),
        "p": s.layer(COPPER, "flat", base=3, lit=4, dark=2),
        "k": s.layer(COPPER, "sphere", contrast=2.0, gloss=True, gloss_cut=0.6, sep="outer", sep_idx=1),
        "b": s.layer(Ramp(C.STONE[:5]), "flat", base=2, lit=3, dark=1),
        "F": s.layer(EMBER if working else Ramp(C.CHARCOAL), "flat", base=3 if working else 1,
                     lit=4 if working else 2, dark=2 if working else 0),
        "j": s.layer(WOOD5, "cyl", axis=90, contrast=1.8, sep="outer", sep_idx=0),
    }
    L.paint(lays, L.grid(rows), {k: k for k in lays})
    img = s.render()
    if working:
        ys, xs = np.nonzero(lays["j"].mask)
        x = xs.min() + 1
        y = ys.min() - 1
        if img[y, x, 3] == 0:
            img[y, x] = L.rgba(C.HONEY[4])
    return L.offset(img, 0, dy, 16, h) if dy else img


def still_world():
    return strip(shadow(_still(STILL, False), 8.0, 7.0), shadow(_still(STILL, True), 8.0, 7.0))


STILL_ICON = """
    ................
    ................
    ......cc........
    .....cccc.......
    ......pppppp....
    ....kkkk...pp...
    ...kkkkkk...p...
    ..kkkkkkkk..cc..
    ..kkkkkkkk.cccc.
    ..kkkkkkkk..cc..
    ...kkkkkk..jjjj.
    ...bbbbbb..jjjj.
    ...bFFFFb..jjjj.
    ...bbbbbb..jjjj.
    ................
    ................
"""


def still_icon():
    return world_to_icon(_still(STILL_ICON, True, h=16, dy=0))


# ----------------------------------------------------------------------------------------------
# bee box (16x32): two stacked hive boxes with a roof
# ----------------------------------------------------------------------------------------------

HIVE_PAINT = Ramp(["#5e5446", "#8a7e66", "#b8ac8c", "#d8ceae", "#f0e8cc"])

BEEBOX = """
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    ................
    .......rr.......
    .....rrrrrr.....
    ...rrrrrrrrrr...
    .rrrrrrrrrrrrrr.
    ..wwwwwwwwwwww..
    ..wwwwwwwwwwww..
    ..wwwwwwwwwwww..
    ..wwwwwwwwwwww..
    ..xxxxxxxxxxxx..
    ..yyyyyyyyyyyy..
    ..yyyyyyyyyyyy..
    ..yyyyyyyyyyyy..
    ..yyyyyyyyyyyy..
    ..yyyyeeeeyyyy..
    ..ssssssssssss..
    ..ss........ss..
    ................
    ................
    ................
    ................
    ................
    ................
"""


def _beebox(rows, h=32, dy=6):
    s = L.Sprite(16, h)
    lays = {
        "r": s.layer(Ramp(C.RUST[1:]), "flat", base=2, lit=3, dark=1),
        "w": s.layer(HIVE_PAINT, "flat", base=3, lit=4, dark=2, sep="outer", sep_idx=1),
        "x": s.layer(HIVE_PAINT, "solid", index=1),
        "y": s.layer(Ramp(["#5a4a1e", "#86702a", "#b49638", "#d8b850", "#eed27a"]), "flat", base=3, lit=4, dark=2),
        "e": s.layer(Ramp(C.CHARCOAL), "solid", index=1),
        "s": s.layer(WOOD5, "flat", base=2, lit=3, dark=1),
    }
    L.paint(lays, L.grid(rows), {k: k for k in lays})
    # plank seams
    for lay_key in ("w", "y"):
        ys, xs = np.nonzero(lays[lay_key].mask)
        if len(xs):
            mid = (ys.min() + ys.max()) // 2
            lays[lay_key].nudge([(x, mid) for x in range(xs.min(), xs.max() + 1)], -1)
    img = s.render()
    return L.offset(img, 0, dy, 16, h) if dy else img


def bee_box_world():
    img = _beebox(BEEBOX)
    bee_y, bee_k = L.rgba("#ffc948"), L.rgba("#281a0b")
    for (x, y) in ((13, 14), (2, 18)):
        img[y, x] = bee_y
        img[y, x + 1] = bee_k
    return shadow(img, 8.0, 7.0)


BEEBOX_ICON = """
    ................
    ................
    .......rr.......
    .....rrrrrr.....
    ...rrrrrrrrrr...
    .rrrrrrrrrrrrrr.
    ..wwwwwwwwwwww..
    ..wwwwwwwwwwww..
    ..xxxxxxxxxxxx..
    ..yyyyyyyyyyyy..
    ..yyyyyyyyyyyy..
    ..yyyyeeeeyyyy..
    ..ssssssssssss..
    ..ss........ss..
    ................
    ................
"""


def bee_box_icon():
    img = _beebox(BEEBOX_ICON, h=16, dy=0)
    img = world_to_icon(img)
    return img


# ----------------------------------------------------------------------------------------------
# storm rod (16x32): lightning rod with a battery cabinet at its base
# ----------------------------------------------------------------------------------------------

RADROD = """
    .......t........
    .......t........
    ......ttt.......
    .......p........
    .....ccccc......
    .......p........
    .....ccccc......
    .......p........
    .......p........
    .......p........
    .......p........
    .......p........
    .......p........
    .......p........
    .......p........
    .......p........
    .......p........
    .......p........
    .......p........
    ....bbbbbbb.....
    ...bbbbbbbbb....
    ...bwwwwwwwb....
    ...bkykykykb....
    ...bwwwwwwwb....
    ...bbbbbbbbb....
    ...bbbLbbbbb....
    ...bbbbbbbbb....
    ...bbbbbbbbb....
    ...bbbbbbbbb....
    ....f.....f.....
    ................
    ................
"""


def _radrod(rows, h=32, dy=2):
    s = L.Sprite(16, h)
    lays = {
        "p": s.layer(Ramp(C.IRON[1:]), "flat", base=2, lit=3, dark=1),
        "t": s.layer(COPPER, "flat", base=4, lit=5, dark=3),
        "c": s.layer(COPPER, "flat", base=3, lit=4, dark=2, sep="outer", sep_idx=0),
        "b": s.layer(Ramp(C.OLIVE_DRAB), "flat", base=3, lit=4, dark=2, sep="outer", sep_idx=1),
        "w": s.layer(Ramp(C.HAZMAT[1:]), "solid", index=3),
        "k": s.layer(Ramp(C.CHARCOAL), "solid", index=1),
        "y": s.layer(Ramp(C.HAZMAT[1:]), "solid", index=3),
        "L": s.layer(LAMP, "solid", index=4),
        "f": s.layer(Ramp(C.IRON[:4]), "solid", index=1),
    }
    L.paint(lays, L.grid(rows), {k: k for k in lays})
    img = s.render()
    return L.offset(img, 0, dy, 16, h) if dy else img


def rad_rod_world():
    return shadow(_radrod(RADROD), 8.0, 6.0)


RADROD_ICON = """
    .......t........
    ......ttt.......
    .......p........
    .....ccccc......
    .......p........
    .....ccccc......
    .......p........
    .......p........
    ....bbbbbbb.....
    ...bbbbbbbbb....
    ...bkykykykb....
    ...bbbbbbbbb....
    ...bbbLbbbbb....
    ...bbbbbbbbb....
    ................
    ................
"""


def rad_rod_icon():
    return world_to_icon(_radrod(RADROD_ICON, h=16, dy=0))


# ----------------------------------------------------------------------------------------------
# scrap gnome (16x16)
# ----------------------------------------------------------------------------------------------

def scrap_gnome_world():
    img = L.icon("""
        ................
        ................
        .......h........
        ......hh........
        ......hhh.......
        .....hhhhh......
        ....hhhhhhh.....
        .....ffff.......
        ....bffffb......
        ....bbbbbb......
        ...abtttbba.....
        ...attttttta....
        ....tttttt......
        ....tttttt......
        ....kk..kk......
        ................
    """, {
        "h": (Ramp(["#5a1e0a", "#8a2e10", "#c4461a", "#e8662a", "#f8964e"]), "flat", {"base": 3, "lit": 4, "dark": 2}),
        "f": (Ramp(C.SKIN_RAMPS[0] if hasattr(C, "SKIN_RAMPS") else ["#7d5236", "#a06c48", "#c48a5e", "#dca77a"]), "flat", {"base": 2, "lit": 3, "dark": 1}),
        "b": (Ramp(C.CLOTH_WHITE), "flat", {"base": 3, "lit": 4, "dark": 2, "sep": "outer", "sep_idx": 1}),
        "t": (Ramp(C.TIN), "cyl", {"axis": 90, "contrast": 2.0, "gloss": True, "gloss_cut": 0.7}),
        "a": (Ramp(C.RUST[1:]), "flat", {"base": 2, "lit": 3, "dark": 1}),
        "k": (Ramp(C.LEATHER[1:]), "flat", {"base": 1, "lit": 2, "dark": 0}),
    }, {"e": ("put", "#281a0b")})
    img = L.offset(img, 1, 1, 16, 16)
    img[9, 6] = L.rgba("#281a0b")
    return shadow(img, 8.0, 4.0)


# ----------------------------------------------------------------------------------------------
# paths (icons only)
# ----------------------------------------------------------------------------------------------

def gravel_path_icon():
    dirt = Ramp(["#6b4a2c", "#8a6238", "#a87c48", "#c4995e", "#dcb77a"])
    peb = Ramp(C.STONE)
    s = L.Sprite()
    base = s.layer(dirt, "flat", base=2, lit=3, dark=1)
    base.rect(2, 3, 13, 13)
    base.px((2, 3), (13, 3), (2, 13), (13, 13), add=False)
    rng = np.random.default_rng(11)
    for _ in range(16):
        x = int(rng.integers(2, 13))
        y = int(rng.integers(3, 13))
        lay = s.layer(peb, "flat", base=3, lit=5, dark=2)
        lay.px((x, y), (x + 1, y))
        if rng.random() < 0.5:
            lay.px((x, y + 1))
    return s.render()


def cobble_path_icon():
    st = Ramp(C.STONE)
    s = L.Sprite()
    mortar = s.layer(Ramp(["#5c4a36", "#6e5a42", "#806a50", "#94805e"]), "solid", index=1)
    mortar.rect(2, 3, 13, 13)
    stones = [((2, 3), (5, 6)), ((7, 3), (10, 5)), ((12, 3), (13, 6)), ((2, 8), (4, 10)), ((6, 7), (9, 10)),
              ((11, 8), (13, 11)), ((2, 12), (6, 13)), ((8, 12), (13, 13))]
    for (a_, b_) in stones:
        lay = s.layer(st, "inflate", contrast=2.0, bevel=2, bias=0.8)
        lay.rect(a_[0], a_[1], b_[0], b_[1])
        lay.px((a_[0], a_[1]), (b_[0], a_[1]), (a_[0], b_[1]), (b_[0], b_[1]), add=False)
    return s.render()


def sprinkler_icon(world_fn):
    """Sprinkler icon: the object plus a few water droplets so it reads as a sprinkler."""
    img = world_to_icon(world_fn())
    drop = L.rgba(C.WATER[5])
    drop_d = L.rgba(C.WATER[3])
    a = img[:, :, 3] > 0
    ys, xs = np.nonzero(a)
    top = ys.min()
    for (x, y, c) in ((xs.min() - 1, top + 1, drop), (xs.max() + 1, top + 1, drop),
                      (xs.min(), top - 1, drop_d), (xs.max(), top - 1, drop_d)):
        if 0 <= x < 16 and 0 <= y < 16 and img[y, x, 3] == 0:
            img[y, x] = c
    return img


WORLD = {
    "crate_chest": crate_chest_world, "scrap_sprinkler": scrap_sprinkler_world,
    "quality_sprinkler": quality_sprinkler_world, "prewar_sprinkler": prewar_sprinkler_world,
    "oil_lamp": oil_lamp_world, "compost_bin": compost_bin_world, "smelter": smelter_world,
    "kiln": kiln_world, "recycler": recycler_world, "preserves_jar": preserves_jar_world,
    "still": still_world, "bee_box": bee_box_world, "rad_rod": rad_rod_world,
    "scrap_gnome": scrap_gnome_world,
}

ICONS = {
    "crate_chest": lambda: world_to_icon(crate_chest_world()),
    "scrap_sprinkler": lambda: sprinkler_icon(scrap_sprinkler_world),
    "quality_sprinkler": lambda: sprinkler_icon(quality_sprinkler_world),
    "prewar_sprinkler": lambda: sprinkler_icon(prewar_sprinkler_world),
    "oil_lamp": oil_lamp_icon, "compost_bin": lambda: world_to_icon(compost_bin_world()),
    "smelter": smelter_icon, "kiln": kiln_icon, "recycler": recycler_icon,
    "preserves_jar": preserves_jar_icon, "still": still_icon, "bee_box": bee_box_icon,
    "rad_rod": rad_rod_icon, "gravel_path": gravel_path_icon, "cobble_path": cobble_path_icon,
    "scrap_gnome": lambda: world_to_icon(scrap_gnome_world()),
}
