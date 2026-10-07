"""Crop growth sprites: art/crops/<crop_id>/stage_<i>.png (16x32, bottom-centre anchored).

Each form (data/crops.json `form`) has six canonical stages:
  0 just planted (sprout on a little soil hump)   1 small   2 medium   3 large
  4 flowering / produce starting                  5 mature, produce clearly visible
Crops with fewer sprites pick a subset (FIVE_STAGE_PICK). Regrowing crops (regrow_days > 0)
always show "flowering, no fruit" on their second-to-last stage. stage_dead.png is a withered
brown take on the large stage. The plant's base sits on row BASE (4 px above the bottom edge);
no soil is drawn except the little hump of stage 0 (the terrain draws the tilled soil).
"""
from __future__ import annotations

import numpy as np

import ia_lib as L
from ia_lib import Ramp
from ia_common import C, CROPS, ramp

W, H = 16, 32
BASE = 28            # row where the plant meets the soil

# six canonical stages; five-sprite crops use this subset per form
FIVE_STAGE_PICK = {
    "root_leafy": [0, 1, 2, 3, 5],
    "bush_flowering": [0, 1, 2, 4, 5],
    "leafy_head": [0, 1, 2, 3, 5],
    "bush_fruit": [0, 1, 2, 4, 5],
    "vine_trellis": [0, 1, 2, 4, 5],
    "tall_stalk": [0, 1, 3, 4, 5],
    "flower": [0, 1, 3, 4, 5],
    "ground_gourd": [0, 1, 3, 4, 5],
    "grain": [0, 1, 2, 4, 5],
}

# ---- leaf stamps ('#' leaf, 'v' vein = lighter) -------------------------------------------
STAMPS = {
    "S": ["##.", ".##", "..#"],
    "M": ["###...", ".####.", "..####", "...###"],
    "M2": ["##....", "####..", ".#####", "...###"],
    "L": ["###.....", "######..", ".#######", "..######", "....####"],
    "XL": ["####......", "#######...", ".########.", "..########", "....######", "......####"],
    "U1": [".#.", "###", "###", ".#."],
    "U2": [".##.", "####", "####", "####", ".##."],
    "U3": ["..##..", ".####.", "######", "######", ".####.", "..##.."],
    "U4": ["..##..", ".####.", "######", "######", "######", ".####.", "..##.."],
    "D": ["######", ".#####", "..####", "...###", "....##"],          # drooping blade
    "B": ["##..", "###.", ".###", "..##", "...#"],                    # blade
    "R1": [".##.", "####", "####", ".##."],                          # round (gourd) leaf
    "UL4": ["##..", "###.", ".###", "..##"],                         # oval leaf leaning up-left
    "UL5": [".##..", "####.", "#####", ".####", "..###", "...#."],
    "UL6": [".##...", "####..", "#####.", "######", ".#####", "..####", "...##."],
    "R2": ["..###..", ".#####.", "#######", "#######", ".#####.", "..#.#.."],
    "R3": ["..####..", ".######.", "########", "########", "########", ".######.", "..#..#.."],
}


def stamp(name, mirror=False):
    rows = STAMPS[name]
    if mirror:
        rows = [r[::-1] for r in rows]
    return rows


class Plant:
    def __init__(self, leaf: Ramp, stem: Ramp, extra: dict | None = None):
        self.s = L.Sprite(W, H)
        self.leaf_r = leaf
        self.stem_r = stem
        self.r = extra or {}

    # -- parts -----------------------------------------------------------------------------
    def leaf(self, name, x, y, mirror=False, ramp_=None, sep=True, vein=True):
        rows = stamp(name, mirror)
        rmp = ramp_ or self.leaf_r
        lay = self.s.layer(rmp, "inflate", contrast=2.2, bevel=2, sep="outer" if sep else None, sep_idx=0,
                           cast=sep)
        lay.ascii(rows, x, y, chars="#")
        if vein:
            # a lighter mid-vein along the leaf's long axis
            ys, xs = np.nonzero(lay.mask)
            if len(xs) >= 6:
                pts = []
                cy = (ys.min() + ys.max()) / 2.0
                for xx in range(xs.min() + 1, xs.max()):
                    col = ys[xs == xx]
                    if len(col) >= 3:
                        pts.append((xx, int(round(col.mean()))))
                lay.nudge(pts[: max(1, len(pts) - 1)], 1)
        return lay

    def blob(self, rows, x, y, rmp, mode="inflate", sep=True, **kw):
        lay = self.s.layer(rmp, mode, sep="outer" if sep else None, sep_idx=0, **kw)
        lay.ascii(L.grid(rows) if isinstance(rows, str) else rows, x, y, chars="#")
        return lay

    def stem(self, pts, rmp=None):
        lay = self.s.layer(rmp or self.stem_r, "flat", base=2, lit=3, dark=1)
        lay.px(*pts)
        return lay

    def vline(self, x, y0, y1, w=1, rmp=None, mode="flat"):
        lay = self.s.layer(rmp or self.stem_r, mode, base=2, lit=3, dark=1, axis=90)
        for y in range(y0, y1 + 1):
            for k in range(w):
                lay.px((x + k, y))
        return lay

    def put(self, x, y, col, rmp=None, after=False):
        self.s.put(x, y, col, rmp, after)

    def render(self, shadow_rx=None):
        img = self.s.render()
        if shadow_rx:
            img = L.add_shadow(img, 8.4, BASE + 1.0, shadow_rx, 1.3, alpha=70)
        return img


SOIL_HUMP = Ramp(["#4a2f18", "#5c3b1f", "#7a5030", "#9a6a3c", "#b8844e"])


def sprout(P: Plant, kind="leaf"):
    """Stage 0: a tiny sprout on a little soil hump."""
    hump = P.s.layer(SOIL_HUMP, "inflate", contrast=2.0, bevel=2)
    hump.ascii(L.grid("""
        .....######.....
        ....########....
    """), 0, BASE - 1, chars="#")
    hump.nudge([(6, BASE - 1), (9, BASE)], -1)
    if kind == "blade":
        P.stem([(7, BASE - 2), (7, BASE - 3), (7, BASE - 4), (8, BASE - 5), (6, BASE - 3), (5, BASE - 4)],
               P.leaf_r)
    elif kind == "round":
        P.stem([(7, BASE - 2), (8, BASE - 2)])
        P.blob(["##..##", "##..##"], 5, BASE - 4, P.leaf_r, "flat", base=3, lit=4, dark=2)
        P.stem([(7, BASE - 3), (8, BASE - 3)])
    else:
        P.stem([(7, BASE - 2), (7, BASE - 3)])
        P.blob(["##...", ".#.##", "...#."], 5, BASE - 5, P.leaf_r, "flat", base=3, lit=4, dark=2)
    return P


# ----------------------------------------------------------------------------------------------
# forms
# ----------------------------------------------------------------------------------------------

def root_leafy(P: Plant, k, root: Ramp, crop_id):
    b = BASE
    if k == 0:
        return sprout(P).render()
    if k == 1:
        P.stem([(7, b), (8, b), (7, b - 1)])
        P.leaf("UL4", 3, b - 5, vein=False)
        P.leaf("UL4", 9, b - 5, mirror=True, vein=False)
        P.leaf("U1", 6, b - 6, vein=False)
        return P.render(3.0)
    if k == 2:
        P.stem([(7, b), (8, b), (7, b - 1), (8, b - 1), (6, b - 2), (9, b - 2)])
        P.leaf("UL5", 1, b - 8, vein=False)
        P.leaf("UL5", 10, b - 8, mirror=True, vein=False)
        P.leaf("U2", 6, b - 10, vein=False)
        P.leaf("S", 4, b - 3, vein=False)
        P.leaf("S", 9, b - 3, mirror=True, vein=False)
        return P.render(4.0)
    # k >= 3: full fan of leaves on short petioles
    P.stem([(6, b), (7, b), (8, b), (9, b), (7, b - 1), (8, b - 1), (6, b - 2), (9, b - 2), (5, b - 3),
            (10, b - 3)])
    P.leaf("UL6", 0, b - 11, vein=False)
    P.leaf("UL6", 10, b - 11, mirror=True, vein=False)
    P.leaf("U3", 5, b - 15, vein=False)
    P.leaf("UL5", 3, b - 9, vein=False)
    P.leaf("UL5", 8, b - 9, mirror=True, vein=False)
    if k == 4:
        P.blob([".####.", "######"], 5, b - 1, root, "sphere", contrast=2.0)
    if k == 5:
        P.blob(L.grid("""
            ..####..
            .######.
            ########
            ########
            .######.
        """), 4, b - 4, root, "sphere", contrast=2.2, gloss=True, gloss_cut=0.7)
    return P.render(5.0)


def bush_flowering(P: Plant, k, flower: Ramp, tuber: Ramp):
    b = BASE
    if k == 0:
        return sprout(P).render()
    if k == 1:
        P.stem([(7, b), (7, b - 1), (8, b - 2)])
        P.leaf("S", 4, b - 4)
        P.leaf("S", 9, b - 5, mirror=True)
        P.leaf("U1", 6, b - 7)
        return P.render(3.0)
    if k == 2:
        P.stem([(7, b), (8, b), (7, b - 1)])
        P.leaf("M", 2, b - 6)
        P.leaf("M", 8, b - 7, mirror=True)
        P.leaf("U2", 5, b - 10)
        P.leaf("R1", 8, b - 4)
        P.leaf("R1", 3, b - 3)
        return P.render(4.5)
    P.stem([(6, b), (7, b), (8, b), (9, b), (7, b - 1), (8, b - 1)])
    P.leaf("L", 0, b - 9)
    P.leaf("L", 8, b - 10, mirror=True)
    P.leaf("U3", 2, b - 14)
    P.leaf("U3", 8, b - 15)
    P.leaf("U2", 5, b - 16)
    P.leaf("R2", 4, b - 7)
    P.leaf("R1", 10, b - 4)
    P.leaf("R1", 1, b - 4)
    if k >= 4:
        for (x, y) in ((4, b - 15), (9, b - 17), (12, b - 12), (2, b - 10), (7, b - 12)):
            P.blob(["##", "##"], x, y, flower, "flat", base=3, lit=4, dark=2)
            P.put(x + 1, y + 1, "#f0c040", flower)
    if k == 5:
        P.blob([".###.", "#####", "#####"], 2, b - 2, tuber, "inflate", contrast=2.2)
        P.blob([".###", "####", "###."], 10, b - 2, tuber, "inflate", contrast=2.2)
    return P.render(6.0)


def leafy_head(P: Plant, k, light: Ramp):
    b = BASE
    if k == 0:
        return sprout(P).render()
    if k == 1:
        P.leaf("S", 4, b - 3)
        P.leaf("S", 9, b - 3, mirror=True)
        P.leaf("U1", 6, b - 5)
        P.leaf("R1", 6, b - 2)
        return P.render(3.0)
    if k == 2:
        P.leaf("M", 1, b - 6)
        P.leaf("M", 9, b - 6, mirror=True)
        P.leaf("U2", 6, b - 9)
        P.leaf("R2", 4, b - 5)
        return P.render(4.5)
    if k == 3:
        P.leaf("L", 0, b - 9)
        P.leaf("L", 8, b - 9, mirror=True)
        P.leaf("U3", 2, b - 12)
        P.leaf("U3", 8, b - 12)
        P.leaf("U3", 5, b - 13)
        P.leaf("R3", 4, b - 6)
        return P.render(6.0)
    P.leaf("XL", 0, b - 11)
    P.leaf("XL", 6, b - 11, mirror=True)
    P.leaf("U4", 1, b - 16)
    P.leaf("U4", 9, b - 16)
    P.leaf("U4", 5, b - 17)
    P.leaf("U3", 3, b - 11)
    P.leaf("U3", 7, b - 11)
    P.leaf("R3", 4, b - 6)
    # pale ruffled ribs
    for (x, y) in ((7, b - 14), (7, b - 13), (7, b - 9), (8, b - 8), (4, b - 9), (11, b - 9)):
        P.put(x, y, L.to_hex(light[3]), light)
    return P.render(7.0)


def bush_fruit(P: Plant, k, fruit: Ramp, flower: Ramp, kind):
    b = BASE
    if k == 0:
        return sprout(P).render()
    if k == 1:
        P.stem([(7, b), (7, b - 1), (7, b - 2), (8, b - 3)])
        P.leaf("S", 4, b - 5)
        P.leaf("S", 9, b - 6, mirror=True)
        P.leaf("U1", 6, b - 8)
        return P.render(3.0)
    if k == 2:
        P.stem([(7, b), (7, b - 1), (7, b - 2), (7, b - 3), (8, b - 4), (6, b - 5)])
        P.leaf("M", 1, b - 8)
        P.leaf("M", 9, b - 9, mirror=True)
        P.leaf("U2", 5, b - 13)
        P.leaf("M2", 3, b - 5)
        P.leaf("M2", 8, b - 5, mirror=True)
        return P.render(4.5)
    P.stem([(7, b), (8, b), (7, b - 1), (7, b - 2), (8, b - 3), (7, b - 4)])
    P.leaf("L", 0, b - 13)
    P.leaf("L", 8, b - 14, mirror=True)
    P.leaf("U3", 1, b - 18)
    P.leaf("U3", 9, b - 18)
    P.leaf("U3", 5, b - 20)
    P.leaf("M", 1, b - 8)
    P.leaf("M", 9, b - 8, mirror=True)
    P.leaf("U2", 6, b - 11)
    if k == 4:
        for (x, y) in ((3, b - 16), (10, b - 15), (6, b - 18), (12, b - 10), (2, b - 9), (8, b - 9)):
            P.blob(["##", "##"], x, y, flower, "flat", base=3, lit=4, dark=2)
            P.put(x, y, L.to_hex(flower[4]), flower)
    if k == 5:
        if kind == "berry":
            for (x, y) in ((2, b - 15), (10, b - 16), (6, b - 13), (12, b - 9), (2, b - 8), (8, b - 6)):
                lay = P.blob([".##.", "####", "####", ".##."], x, y, fruit, "sphere", contrast=2.0)
                lay.set([(x + 1, y + 1)], len(fruit) - 1)
        else:  # hanging peppers
            for (x, y) in ((3, b - 14), (10, b - 15), (6, b - 10), (11, b - 8), (2, b - 7)):
                P.stem([(x + 1, y - 1)], P.stem_r)
                lay = P.blob(["##", "##", "##", ".#"], x, y, fruit, "cyl", axis=90, contrast=2.0)
                lay.set([(x, y)], len(fruit) - 1)
    return P.render(6.0)


def vine_trellis(P: Plant, k, fruit: Ramp, flower: Ramp, kind):
    b = BASE
    if k == 0:
        return sprout(P).render()
    stake = Ramp(C.WOOD[1:])
    top = {1: b - 13, 2: b - 20, 3: b - 24, 4: b - 25, 5: b - 25}[k]
    P.vline(7, top, b, w=2, rmp=stake, mode="cyl")
    tie = P.s.layer(stake, "flat", base=3, lit=4, dark=2)
    tie.px((6, top), (7, top), (8, top), (9, top))
    if k >= 3:
        tie.px((5, top), (10, top))
    twine = "#bca878"
    if k == 1:
        P.leaf("S", 3, b - 5)
        P.leaf("S", 9, b - 7, mirror=True)
        P.leaf("U1", 4, b - 9)
        return P.render(3.0)
    if k == 2:
        P.leaf("M", 1, b - 7)
        P.leaf("M", 9, b - 11, mirror=True)
        P.leaf("M", 2, b - 15)
        P.leaf("U2", 9, b - 18)
        P.leaf("S", 9, b - 4, mirror=True)
        for y in (b - 6, b - 12):
            P.put(7, y, twine)
            P.put(8, y, twine)
        return P.render(4.5)
    leaves = [("L", 0, b - 8, False), ("L", 8, b - 12, True), ("M", 1, b - 15, False), ("M", 9, b - 19, True),
              ("M", 2, b - 22, False), ("U2", 9, b - 25, False), ("S", 10, b - 5, True), ("M2", 3, b - 4, False)]
    for (nm, x, y, mr) in leaves:
        P.leaf(nm, x, y, mirror=mr)
    for y in (b - 7, b - 14, b - 20):
        P.put(7, y, twine)
        P.put(8, y, twine)
    if k == 4:
        for (x, y) in ((3, b - 12), (11, b - 15), (4, b - 19), (11, b - 8), (3, b - 4)):
            P.blob(["##", "#."], x, y, flower, "flat", base=3, lit=4, dark=2)
    if k == 5:
        if kind == "tomato":
            for (x, y) in ((2, b - 12), (10, b - 16), (3, b - 19), (10, b - 8), (4, b - 5)):
                lay = P.blob([".##.", "####", "####", ".##."], x, y, fruit, "sphere", contrast=2.0)
                lay.set([(x + 1, y + 1)], len(fruit) - 1)
                P.put(x + 1, y - 1, L.to_hex(C.LEAF[3]))
                P.put(x + 2, y - 1, L.to_hex(C.LEAF[2]))
        else:  # grape bunches
            for (x, y) in ((2, b - 13), (10, b - 18), (10, b - 9), (3, b - 21)):
                lay = P.blob(["###", "###", "###", ".#."], x, y, fruit, "flat", base=3, lit=4, dark=2)
                lay.nudge([(x + 1, y), (x, y + 1), (x + 2, y + 2), (x + 1, y + 3)], -1)
                lay.set([(x, y), (x + 2, y + 1), (x + 1, y + 2)], len(fruit) - 1)
    return P.render(5.0)


def tall_stalk(P: Plant, k, ear: Ramp, husk: Ramp, tassel: Ramp):
    b = BASE
    stalk = P.stem_r
    if k == 0:
        return sprout(P, "blade").render()
    if k == 1:
        P.vline(7, b - 6, b, w=1, rmp=stalk)
        P.leaf("B", 3, b - 8, vein=False)
        P.leaf("B", 8, b - 6, mirror=True, vein=False)
        return P.render(2.5)
    height = {2: 13, 3: 20, 4: 26, 5: 26}[k]
    P.vline(7, b - height, b, w=2, rmp=stalk, mode="cyl")
    blades = [("D", 1, b - 7, False), ("D", 9, b - 10, True)]
    if k >= 3:
        blades += [("D", 1, b - 14, False), ("D", 9, b - 17, True)]
    if k >= 4:
        blades += [("B", 2, b - 22, False), ("B", 10, b - 23, True)]
    if k == 2:
        blades += [("B", 3, b - 13, False), ("B", 9, b - 13, True)]
    for (nm, x, y, mr) in blades:
        P.leaf(nm, x, y, mirror=mr, vein=False)
    if k >= 4:
        t = P.s.layer(tassel, "flat", base=2, lit=3, dark=1)
        t.px((7, b - 27), (8, b - 27), (6, b - 28), (9, b - 28), (7, b - 28), (8, b - 26), (5, b - 27), (10, b - 27))
    if k == 5:
        for (x, y, mr) in ((9, b - 15, False), (2, b - 19, True)):
            rows_e = [".##.", "####", "####", "####", ".##."]
            e = P.blob(rows_e, x + (1 if not mr else 0), y, ear, "cyl", axis=90, contrast=1.8)
            e.nudge([(x + 1 + (1 if not mr else 0), y + 2), (x + 2 + (1 if not mr else 0), y + 3)], 1)
            hk = P.s.layer(husk, "flat", base=2, lit=3, dark=1, sep="outer", sep_idx=0)
            if not mr:
                hk.px((x, y + 3), (x, y + 4), (x + 1, y + 5), (x + 4, y + 3), (x + 4, y + 4), (x + 3, y + 5),
                      (x + 2, y + 5))
            else:
                hk.px((x + 4, y + 3), (x + 4, y + 4), (x + 3, y + 5), (x - 0, y + 3), (x, y + 4), (x + 1, y + 5),
                      (x + 2, y + 5))
    return P.render(4.0)


def flower(P: Plant, k, petal: Ramp, centre: Ramp):
    b = BASE
    if k == 0:
        return sprout(P).render()
    if k == 1:
        P.vline(7, b - 6, b)
        P.leaf("S", 4, b - 5)
        P.leaf("S", 8, b - 7, mirror=True)
        return P.render(3.0)
    height = {2: 13, 3: 19, 4: 20, 5: 17}[k]
    P.vline(7, b - height, b, w=2, rmp=P.stem_r, mode="cyl")
    P.leaf("M", 1, b - 8)
    P.leaf("M", 9, b - 10, mirror=True)
    if k >= 3:
        P.leaf("M", 1, b - 15)
        P.leaf("M", 9, b - 17, mirror=True)
    if k == 2:
        P.leaf("S", 5, b - 15)
        return P.render(4.0)
    if k == 3:
        P.blob([".##.", "####", "####", ".##."], 6, b - height - 3, P.leaf_r, "sphere", contrast=2.0)
        return P.render(5.0)
    if k == 4:
        bud = P.blob([".####.", "######", "######", "######", ".####."], 5, b - height - 4, P.leaf_r, "sphere",
                     contrast=2.0)
        for (x, y) in ((5, b - height - 4), (7, b - height - 5), (10, b - height - 4), (8, b - height - 5)):
            P.put(x, y, L.to_hex(petal[3]), petal)
        P.put(6, b - height - 5, L.to_hex(petal[4]), petal)
        return P.render(5.0)
    # mature: big face
    top = b - height - 10
    face = P.blob(L.grid("""
        ...#.##.#...
        ..########..
        .##########.
        ############
        ############
        ############
        ############
        .##########.
        ..########..
        ...#.##.#...
    """), 2, top, petal, "inflate", contrast=2.0, bevel=2)
    face.nudge([(4, top + 1), (8, top + 1), (3, top + 4), (12, top + 5), (5, top + 8), (10, top + 8)], -1)
    P.blob(L.grid("""
        .####.
        ######
        ######
        ######
        .####.
    """), 5, top + 2, centre, "sphere", contrast=1.8)
    for (x, y) in ((6, top + 3), (8, top + 4), (7, top + 5), (9, top + 3)):
        P.put(x, y, L.to_hex(centre[1]), centre)
    return P.render(5.0)


def ground_gourd(P: Plant, k, fruit: Ramp, kind):
    b = BASE
    if k == 0:
        return sprout(P, "round").render()
    if k == 1:
        P.leaf("R1", 3, b - 4)
        P.leaf("R1", 9, b - 5)
        P.leaf("R1", 6, b - 3)
        return P.render(4.0)
    if k == 2:
        P.leaf("R2", 0, b - 7)
        P.leaf("R2", 9, b - 8)
        P.leaf("R2", 5, b - 10)
        P.leaf("R1", 5, b - 3)
        return P.render(6.0)
    P.leaf("R3", 0, b - 9)
    P.leaf("R3", 8, b - 10)
    P.leaf("R2", 4, b - 13)
    P.leaf("R2", 10, b - 5)
    P.leaf("R2", 0, b - 4)
    tendril = L.to_hex(C.STEM[3])
    for (x, y) in ((13, b - 12), (14, b - 13), (14, b - 14), (13, b - 15)):
        P.put(x, y, tendril, after=True)
    if k == 3:
        P.blob(["##", "##"], 7, b - 7, Ramp(C.FLOWER_YELLOW), "flat", base=3, lit=4, dark=2)
    if k == 4:
        P.blob([".###.", "#####", ".###."], 5, b - 3, Ramp(C.LEAF_FRESH[1:]), "sphere", contrast=2.0)
    if k == 5:
        if kind == "pumpkin":
            lay = P.blob(L.grid("""
                ...###.###...
                .###########.
                #############
                #############
                #############
                .###########.
                ..#########..
            """), 1, b - 6, fruit, "sphere", contrast=2.2, gloss=True, gloss_cut=0.75)
            lay.nudge([(4, b - 5), (4, b - 4), (4, b - 3), (4, b - 2), (7, b - 6), (7, b - 5), (7, b - 4),
                       (7, b - 3), (7, b - 2), (10, b - 5), (10, b - 4), (10, b - 3), (10, b - 2)], -1)
            P.stem([(7, b - 7), (6, b - 8)], Ramp(C.LEAF[0:5]))
        else:
            lay = P.blob(L.grid("""
                ..########..
                .##########.
                ############
                ############
                ############
                .##########.
                ...######...
            """), 2, b - 6, fruit, "sphere", contrast=2.0, gloss=True, gloss_cut=0.55, bias=0.4)
            lay.nudge([(4, b - 5), (5, b - 4), (5, b - 3), (4, b - 2), (8, b - 6), (8, b - 5), (8, b - 4),
                       (8, b - 3), (8, b - 2), (11, b - 5), (11, b - 4), (11, b - 3)], -2)
    return P.render(7.0)


def grain(P: Plant, k, gold: Ramp, green: Ramp):
    b = BASE
    if k == 0:
        return sprout(P, "blade").render()
    # (x at base, height, lean direction) -- stalks 1 px wide with gaps so outlines separate them
    stalks = {
        1: [(5, 5, -1), (7, 7, 0), (9, 6, 1)],
        2: [(4, 9, -1), (6, 11, 0), (8, 12, 0), (10, 10, 1)],
        3: [(3, 13, -1), (5, 15, 0), (7, 16, 0), (9, 15, 0), (11, 13, 1)],
        4: [(3, 16, -1), (5, 18, 0), (7, 19, 0), (9, 18, 0), (11, 16, 1)],
        5: [(3, 17, -1), (5, 19, 0), (7, 20, 0), (9, 19, 0), (11, 17, 1)],
    }[k]
    stalk_r = green if k < 5 else Ramp(C.STRAW[:5])
    head_r = None
    if k == 4:
        head_r = Ramp(["#4e5a20", "#6e7a2a", "#929a38", "#b4b44c", "#d0cc6a"])
    elif k == 5:
        head_r = gold
    order = sorted(stalks, key=lambda t: abs(t[0] - 7), reverse=True)
    for (x, hgt, lean) in order:
        lay = P.s.layer(stalk_r, "flat", base=2, lit=3, dark=1, sep="outer", sep_idx=0)
        pts = []
        for i in range(hgt):
            xx = x + (lean if i > hgt * 0.55 else 0)
            pts.append((xx, b - i))
        lay.px(*pts)
        # a side blade on the taller stalks
        if hgt >= 9:
            bx = x - 1 if lean <= 0 else x + 1
            lay.px((bx, b - hgt // 3), (bx - (1 if lean <= 0 else -1), b - hgt // 3 - 1))
        if head_r is not None:
            tx, ty = pts[-1]
            h = P.s.layer(head_r, "flat", base=3, lit=4, dark=2, sep="outer", sep_idx=0)
            h.px((tx, ty), (tx, ty - 1), (tx, ty - 2), (tx, ty - 3), (tx + 1, ty - 1), (tx + 1, ty - 3),
                 (tx, ty - 4))
            h.nudge([(tx + 1, ty - 1), (tx, ty - 2)], -1)
            if k == 5:
                P.put(tx - 1, ty - 4, L.to_hex(head_r[3]), head_r, after=True)   # awn
    return P.render(4.0 + k * 0.4)


# ----------------------------------------------------------------------------------------------
# per-crop setup
# ----------------------------------------------------------------------------------------------

LEAF_RAMPS = {
    "default": Ramp(C.LEAF_FRESH[:5]),
    "dark": Ramp(C.LEAF[0:5]),
    "frost": Ramp(["#22404a", "#2e5a62", "#46807e", "#6aa49a", "#9ccabe"]),
    "kale": None,
}
STEM_R = Ramp(C.STEM)


def crop_ramps(crop_id):
    cols = CROPS[crop_id]["colors"]
    return ramp(cols[0], 6, base_index=2, step=0.08), ramp(cols[1], 6, base_index=2, step=0.07)


def draw(crop_id, k, dead=False):
    crop = CROPS[crop_id]
    form = crop["form"]
    c0, c1 = crop_ramps(crop_id)
    leaf = LEAF_RAMPS["default"]
    if crop_id in ("ironroot", "ash_beet"):
        leaf = LEAF_RAMPS["dark"]
    if crop_id == "frostroot":
        leaf = LEAF_RAMPS["frost"]
    if crop_id == "cleanleaf_kale":
        leaf = ramp(crop["colors"][0], 5, step=0.08)
    stem = STEM_R
    if dead:
        leaf = Ramp(C.LEAF_DRY[:5])
        stem = Ramp(C.LEAF_DRY[:5])
    P = Plant(leaf, stem)
    if form == "root_leafy":
        return root_leafy(P, k, c0 if not dead else Ramp(C.LEAF_DRY[:5]), crop_id)
    if form == "bush_flowering":
        fl = Ramp(C.FLOWER_WHITE) if not dead else Ramp(C.LEAF_DRY[1:])
        return bush_flowering(P, k, fl, c0)
    if form == "leafy_head":
        return leafy_head(P, k, c1 if not dead else Ramp(C.LEAF_DRY))
    if form == "bush_fruit":
        kind = "berry" if crop_id == "bloodberry" else "pepper"
        fl = Ramp(C.FLOWER_WHITE)
        return bush_fruit(P, k, c0, fl, kind)
    if form == "vine_trellis":
        kind = "tomato" if crop_id == "blister_tomato" else "grape"
        fl = Ramp(C.FLOWER_YELLOW) if kind == "tomato" else Ramp(C.LEAF_FRESH[2:])
        return vine_trellis(P, k, c0, fl, kind)
    if form == "tall_stalk":
        husk = Ramp(["#4e5a24", "#6e7a30", "#8c9440", "#aaae58", "#c8c47a"]) if not dead else Ramp(C.LEAF_DRY[1:])
        return tall_stalk(P, k, c0, husk, c1)
    if form == "flower":
        return flower(P, k, c0 if not dead else Ramp(C.LEAF_DRY[1:]), c1 if not dead else Ramp(C.LEAF_DRY))
    if form == "ground_gourd":
        kind = "pumpkin" if "pumpkin" in crop_id else "melon"
        return ground_gourd(P, k, c0, kind)
    if form == "grain":
        return grain(P, k, c0, Ramp(C.LEAF_FRESH[:5]) if not dead else Ramp(C.LEAF_DRY[:5]))
    raise ValueError(f"unknown crop form {form!r} for {crop_id}")


def stage_list(crop_id):
    """Canonical stage index for each sprite of this crop."""
    crop = CROPS[crop_id]
    n = len(crop["stage_days"]) + 1
    if n == 6:
        return [0, 1, 2, 3, 4, 5]
    if n == 5:
        return FIVE_STAGE_PICK[crop["form"]]
    # generic fallback: spread the six canonical stages over n sprites
    return [int(round(i * 5 / (n - 1))) for i in range(n)]


def dead_sprite(crop_id):
    form = CROPS[crop_id]["form"]
    k = 3 if form not in ("ground_gourd",) else 3
    img = draw(crop_id, k, dead=True)
    # droop: drop the top half of the plant by one pixel for a wilted look
    a = img[:, :, 3] > 0
    ys = np.nonzero(a.any(axis=1))[0]
    if len(ys):
        top = ys.min()
        mid = (top + BASE) // 2
        out = img.copy()
        out[top + 1:mid + 1] = img[top:mid]
        out[top] = 0
        img = out
    return img


def build(crop_id):
    """Returns ([stage images...], dead image)."""
    stages = [draw(crop_id, k) for k in stage_list(crop_id)]
    return stages, dead_sprite(crop_id)
