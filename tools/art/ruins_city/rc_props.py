"""Ruins props and decals (art/env/ruins/), bottom-anchored, cold outline, cold shadows.

filing_cabinet.png  32x24  2 frames of 16x24: closed, searched (drawers out, papers spilled)
manhole.png         32x16  2 frames of 16x16: closed, open (walkable floor decor)
car_burnt.png       48x32  footprint 3x1: burnt-out sedan shell on bare rims
bones.png           32x16  2 variants: skeletal remains (somber; darker than remains.png)
pavement_decor.png  64x16  4 flat decals: weedy crack, glass shards, road-arrow fragment, papers
shopping_cart.png   16x16  rusty wire cart
tire_pile.png       16x16  stack of old tyres
oil_drum.png        16x24  rusty steel drum (NOT radioactive: no glow)
"""
from __future__ import annotations

import numpy as np

import palette as P
from env import colors as X
from env import lib, shapes
from env.lib import Canvas, mix, rgba
from ruins_city import rc_common as C
from ruins_city.rc_common import (ASH, ASH_PALE, ASPH, BONE, CHAR, COLD, CON, CREAMS, DRY, GLASS,
                                  MET, PAPER, RUB, RUST, WEED, hval)

OFFICE = lib.ramp([mix(c, P.ASH_BROWN, 0.3) for c in X.LOCKER_GREY])   # warm-grey office steel


def _finish(cv, s, sh):
    lib.outline(s, COLD, local=0.6)
    if sh:
        C.shadow(cv, *sh)
    cv.blit(s, 0, 0)
    return cv


# ================================================================================================
# filing cabinet (2 frames of 16x24)
# ================================================================================================
def _paper(s, x, y, w=3, h=2, k=0):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            s.px(xx, yy, PAPER[3] if yy == y else PAPER[2])
    s.px(x + w - 1, y + h - 1, PAPER[1])
    if k:
        s.px(x + 1, y + h - 1 if h > 1 else y, PAPER[0])          # a line of old type


def filing_cabinet():
    frames = []
    R = OFFICE
    X0, X1 = 3, 12
    TOP = 4
    BASE = 21
    for searched in (False, True):
        cv = Canvas(16, 24)
        s = Canvas(16, 24)
        for x in range(X0, X1 + 1):
            s.px(x, TOP, R[4]); s.px(x, TOP + 1, R[3])            # top face
        for y in range(TOP + 2, BASE + 1):
            for x in range(X0, X1 + 1):
                c = R[2] if x > X0 else R[3]
                if x == X1:
                    c = R[1]
                s.px(x, y, c)
        drawers = [(TOP + 2 + 4 * i) for i in range(4)]            # top row of each drawer
        for i, dy in enumerate(drawers):
            for x in range(X0 + 1, X1):
                s.px(x, dy, R[1])                                  # drawer seam
            s.px(7, dy + 1, CREAMS); s.px(8, dy + 1, mix(CREAMS, R[2], 0.4))    # label slot
            s.px(7, dy + 2, R[4]); s.px(8, dy + 2, R[4])                          # handle
            s.px(7, dy + 3, R[0]); s.px(8, dy + 3, R[0])
        C.darken(s, 5, 15, COLD, 0.3); C.darken(s, 6, 16, R[4], 0.3)              # a dent
        if searched:
            # top and third drawers pulled out toward us: their open tops show, fronts drop 3 px
            for dy in (drawers[0], drawers[2]):
                for y in range(dy, dy + 3):
                    for x in range(X0 + 1, X1):
                        c = mix(R[0], COLD, 0.4)
                        if y == dy + 1 and (x - X0) % 3 == 1:
                            c = PAPER[2]                           # folder tabs
                        if y == dy and x in (X0 + 1, X1 - 1):
                            c = R[3]                               # drawer side walls
                        s.px(x, y, c)
                for y in range(dy + 3, dy + 7):
                    for x in range(X0, X1 + 1):
                        c = R[3] if y == dy + 3 else R[2]
                        if x == X1:
                            c = R[1]
                        s.px(x, y, c)
                s.px(7, dy + 5, R[4]); s.px(8, dy + 5, R[4])
                s.px(7, dy + 4, mix(CREAMS, R[2], 0.3))
            s.px(5, drawers[0], PAPER[3]); s.px(5, drawers[0] - 1, PAPER[3])       # sheet sticking up
            s.px(6, drawers[0] - 1, PAPER[2])
        C.rust_streak(s, X0 + 1, BASE - 3, 3, 0.5)
        sh = (8.5, BASE + 1.3, 6.0, 1.1)
        _finish(cv, s, sh)
        if searched:
            for (x, y, w, h, k) in [(1, 21, 3, 2, 1), (10, 22, 3, 1, 0), (12, 20, 3, 2, 1),
                                    (5, 22, 2, 1, 0)]:
                _paper(cv, x, y, w, h, k)
            cv.px(14, 16, PAPER[3]); cv.px(14, 17, PAPER[2])      # a sheet drifting down
        frames.append(cv)
    return lib.hstrip(frames)


# ================================================================================================
# manhole (2 frames of 16x16, flat)
# ================================================================================================
def _cover(cv, cx, cy, r, R):
    m = cv.ellipse_mask(cx, cy, r, r)
    for y, x in zip(*np.nonzero(m)):
        dx = (x + 0.5 - cx) / r
        dy = (y + 0.5 - cy) / r
        d = dx * dx + dy * dy
        c = R[2]
        if d > 0.68:
            c = R[3] if dx + dy < 0 else R[1]                      # rim
        elif (x + y) % 3 == 0 or (x - y) % 3 == 0:
            c = R[3] if dx + dy < 0.2 else R[2]                    # cast grip pattern
        else:
            c = R[1]
        if hval("mh", x, y) < 0.12 and d < 0.68:
            c = RUST[2]
        cv.px(x, y, c)


def manhole():
    R = lib.ramp([mix(c, ASPH[2], 0.3) for c in P.METAL_RAMP[:5]])
    frames = []
    for open_ in (False, True):
        cv = Canvas(16, 16)
        cx, cy, r = 7.5, 7.5, 6.2
        ring = cv.ellipse_mask(cx, cy, r + 1.0, r + 1.0)
        for y, x in zip(*np.nonzero(ring)):
            cv.px(x, y, mix(COLD, ASPH[1], 0.4))                  # the seat in the pavement
        if not open_:
            _cover(cv, cx, cy, r, R)
        else:
            hole = cv.ellipse_mask(cx, cy, r, r)
            for y, x in zip(*np.nonzero(hole)):
                dy = (y + 0.5 - cy) / r
                c = COLD
                if dy < -0.55:
                    c = mix(CON[1], COLD, 0.5)                     # far inner wall
                cv.px(x, y, c)
            for x in range(5, 11):
                cv.px(x, 4, RUST[3] if x in (5, 10) else RUST[2])  # top ladder rung
            cv.px(5, 5, RUST[1]); cv.px(10, 5, RUST[1])
            lid = Canvas(16, 16)
            _cover(lid, 11.0, 11.5, 4.6, R)
            sh = Canvas(16, 16)
            sh.shadow(11.6, 12.4, 4.6, 4.2, color=P.OUTLINE_COLD)
            cv.blit(sh, 0, 0)
            cv.blit(lid, 0, 0)
        frames.append(cv)
    return lib.hstrip(frames)


# ================================================================================================
# burnt-out car (48x32)
# ================================================================================================
def car_burnt():
    cv = Canvas(48, 32)
    s = Canvas(48, 32)
    R = CHAR
    base = 29                                                     # sits low on bare rims
    for y in range(16, 27):
        for x in range(2, 46):
            if y < 18 and (x < 4 or x > 43):
                continue
            c = R[3] if y < 20 else R[2] if y < 24 else R[1]
            if y == 20:
                c = R[4]
            s.px(x, y, c)
    for x in range(4, 16):
        s.px(x, 15, R[3]); s.px(x, 14, R[2] if x > 9 else R[4])  # hood buckled
    for x in range(33, 44):
        s.px(x, 15, R[4]); s.px(x, 14, R[3])
    for y in range(6, 16):                                        # cabin, roof sagging
        f = (y - 6) / 9.0
        xl = int(round(19 - 4 * f))
        xr = int(round(31 + 3 * f))
        for x in range(xl, xr + 1):
            if y == 6 and 23 <= x <= 27:
                continue
            c = R[3]
            if y <= 7:
                c = R[4]
            s.px(x, y, c)
    s.px(24, 7, R[2]); s.px(25, 7, R[2]); s.px(26, 7, R[2])
    for y in range(8, 15):                                        # empty window frames
        f = (y - 6) / 9.0
        xl = int(round(19 - 4 * f)) + 2
        xr = int(round(31 + 3 * f)) - 2
        for x in range(xl, xr + 1):
            if x == (xl + xr) // 2:
                continue
            s.px(x, y, COLD if y > 9 else mix(COLD, R[1], 0.5))
    for (x, y) in [(18, 12), (19, 11), (20, 12), (21, 11), (27, 12), (28, 11), (29, 12)]:
        s.px(x, y, RUST[2])                                       # seat springs
    # heat discolouration: rust-orange scorch and pale ash
    for (x0, y0, w, h, col, t) in [(5, 17, 9, 4, RUST[2], 0.55), (28, 21, 8, 4, RUST[3], 0.45),
                                   (36, 16, 6, 3, ASH_PALE, 0.5), (12, 22, 6, 3, ASH_PALE, 0.4),
                                   (20, 8, 5, 2, RUST[3], 0.35)]:
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                if hval("scorch", x, y) < 0.75:
                    C.darken(s, x, y, col, t)
    for y in range(17, 25):
        s.px(25, y, R[1])                                         # door seam
    for x in range(2, 6):
        s.px(x, 23, MET[1])
    for x in range(43, 46):
        s.px(x, 23, MET[1])
    for wx in (11.0, 37.0):                                       # wheel wells + bare rims
        for y in range(21, 28):
            for x in range(int(wx - 5), int(wx + 6)):
                if (x + 0.5 - wx) ** 2 + (y + 0.5 - 27.0) ** 2 < 28:
                    s.px(x, y, COLD)
        m = s.ellipse_mask(wx, 26.5, 3.0, 3.0)
        for y, x in zip(*np.nonzero(m)):
            dx = (x + 0.5 - wx) / 3.0
            dy = (y + 0.5 - 26.5) / 3.0
            c = MET[2] if dx + dy < -0.2 else MET[1]
            if dx * dx + dy * dy < 0.2:
                c = MET[0]
            s.px(x, y, c)
        for x in range(int(wx - 3), int(wx + 3)):
            s.px(x, 28, R[0])
    for (x, y, k) in [(8, 28, 1), (15, 28, 2), (33, 28, 1), (42, 28, 2)]:
        s.px(x, y, DRY[k])
    return _finish(cv, s, (25.0, 29.6, 22, 1.5))


# ================================================================================================
# bones (2 variants of 16x16)
# ================================================================================================
def _skull(s, x, y, facing=1):
    pts = [(1, 0, 3), (2, 0, 3), (3, 0, 2), (0, 1, 3), (1, 1, 4), (2, 1, 3), (3, 1, 2),
           (0, 2, 2), (1, 2, 0), (2, 2, 2), (3, 2, 0), (1, 3, 2), (2, 3, 1), (3, 3, 1)]
    for (dx, dy, k) in pts:
        xx = x + (dx if facing > 0 else 3 - dx)
        s.px(xx, y + dy, BONE[k] if k else mix(COLD, BONE[0], 0.3))


def bones(i):
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    stain = Canvas(16, 16)
    stain.shadow(8.0, 11.0, 6.5, 2.6, alpha=70, color=P.OUTLINE_COLD)
    cv.blit(stain, 0, 0)
    if i == 1:
        _skull(s, 2, 7, 1)
        for k in range(4):                                       # ribs (curved pairs)
            y = 8 + k * 2 // 1 - k // 2
            for x in range(7, 12):
                if (x + k) % 5 != 0:
                    s.px(x, 7 + k + (1 if x in (7, 11) else 0), BONE[2] if x < 10 else BONE[1])
        for x in range(7, 12):
            s.px(x, 6, BONE[3])                                  # spine
        for k in range(6):
            s.px(9 + k, 12 + (k // 3), BONE[3] if k < 5 else BONE[2])   # femur
        s.px(9, 11, BONE[3]); s.px(14, 13, BONE[2]); s.px(15, 14, BONE[1])
        for (x, y) in [(5, 13), (6, 13), (12, 4), (13, 5)]:
            s.px(x, y, BONE[2])                                  # small bones
    else:
        K = lib.ramp([mix(c, COLD, 0.35) for c in X.CLOTH_BLUE])  # rotted dark coat
        for y in range(6, 13):
            for x in range(4, 13):
                dx = (x + 0.5 - 8.5) / 4.6
                dy = (y + 0.5 - 9.5) / 3.6
                if dx * dx + dy * dy < 1.0 and hval("coat", x, y) < 0.85:
                    s.px(x, y, K[1] if (x + y) % 4 else K[0])
        for x in range(5, 12):
            s.px(x, 6, K[2])
        _skull(s, 10, 3, -1)
        for (x, y, k) in [(3, 9, 3), (2, 10, 2), (3, 11, 2), (13, 11, 3), (14, 12, 2), (13, 12, 1)]:
            s.px(x, y, BONE[k])                                  # hand bones from the sleeves
        for (x, y, k) in [(6, 13, 3), (7, 13, 2), (8, 14, 2), (9, 14, 1), (11, 13, 2)]:
            s.px(x, y, BONE[k])                                  # shin bones
        s.px(2, 13, RUST[3]); s.px(3, 13, RUST[2]); s.px(2, 14, RUST[1])   # an old tin
    return _finish(cv, s, None)


# ================================================================================================
# pavement decals (4 variants of 16x16, transparent, flat)
# ================================================================================================
def pavement_decor():
    tiles = []
    dark = mix(COLD, ASPH[1], 0.35)
    # 1: crack with weeds poking through
    cv = Canvas(16, 16)
    path = [(2, 4), (4, 5), (5, 7), (7, 8), (9, 8), (10, 10), (12, 11), (13, 13)]
    for (ax, ay), (bx, by) in zip(path[:-1], path[1:]):
        for (x, y) in lib.line_points(ax, ay, bx, by):
            cv.px(x, y, dark)
    for (x, y) in lib.line_points(7, 8, 8, 4) + lib.line_points(10, 10, 12, 9):
        cv.px(x, y, dark)
    C.tuft(cv, 6, 8, "weed"); C.tuft(cv, 11, 11, "weed"); C.tuft(cv, 3, 5, "dry")
    tiles.append(cv)
    # 2: scattered glass shards
    cv = Canvas(16, 16)
    for (x, y, k) in [(3, 4, 5), (4, 4, 3), (4, 5, 2), (9, 3, 4), (10, 6, 5), (11, 6, 3),
                      (6, 9, 4), (7, 9, 2), (12, 11, 5), (12, 12, 3), (13, 11, 2), (3, 12, 4),
                      (8, 13, 3), (2, 8, 3)]:
        cv.px(x, y, GLASS[k])
    tiles.append(cv)
    # 3: faded painted arrow fragment (worn paint, flaked off in places, shaft broken off)
    cv = Canvas(16, 16)
    paint = mix(rgba(X.PAINT_FADED_CREAM), CON[3], 0.2)
    for y in range(2, 14):
        if y <= 7:
            half = y - 2                                        # arrow head widening downward
            xs = range(8 - half, 8 + half + 1)
        else:
            xs = range(7, 10)                                   # shaft
        for x in xs:
            if hval("arrow", x, y) < (0.8 if y < 11 else 0.45):
                cv.px(x, y, paint)
    tiles.append(cv)
    # 4: scattered papers
    cv = Canvas(16, 16)
    _paper(cv, 2, 3, 4, 3, 1)
    _paper(cv, 9, 6, 3, 2, 0)
    _paper(cv, 5, 10, 4, 3, 1)
    _paper(cv, 11, 12, 3, 2, 1)
    for (x, y) in [(3, 4), (4, 4), (6, 11), (7, 11)]:
        cv.px(x, y, PAPER[0])                                   # lines of type
    tiles.append(cv)
    return lib.hstrip(tiles)


# ================================================================================================
# shopping cart, tyre pile, oil drum
# ================================================================================================
def shopping_cart():
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    W = lib.ramp([mix(c, CON[2], 0.2) for c in P.METAL_RAMP])
    for y in range(4, 11):                                       # wire basket, tapering
        x0 = 2 + (y - 4) // 3
        for x in range(x0, 13):
            edge = y in (4, 10) or x in (x0, 12)
            if edge or (x + y) % 3 == 0:
                c = W[4] if y == 4 else W[3] if edge else W[2]
                if hval("cart", x, y) < 0.15:
                    c = RUST[3]
                s.px(x, y, c)
    s.px(5, 6, CON[1]); s.px(6, 6, ASPH[3]); s.px(6, 7, ASPH[2]); s.px(7, 6, ASPH[4])  # junk
    for y in range(2, 6):
        s.px(13, y, W[3])
    s.px(13, 2, RUST[3]); s.px(14, 2, RUST[2])                    # handle
    for x in range(3, 13):
        s.px(x, 11, W[2])                                         # chassis
    s.px(4, 12, W[1]); s.px(11, 12, W[1])
    for (x, y) in [(3, 13), (11, 13)]:
        s.px(x, y, RUB[2]); s.px(x + 1, y, RUB[1]); s.px(x, y + 1, RUB[1]); s.px(x + 1, y + 1, RUB[0])
    C.shadow(cv, 8.0, 14.6, 6.0, 1.0)
    for y in range(16):                                          # outline only the solid parts
        for x in range(16):
            if s.alpha(x, y) and s.alpha(x, y + 1) == 0 and y >= 10:
                cv.px(x, y + 1, COLD)
    cv.blit(s, 0, 0)
    return cv


def tire_pile():
    """Three old tyres stacked flat, each a bulging 3-row wall (lit shoulder, tread, shaded
    shoulder) offset from the one below; the top tyre shows its rim ring and dark hole."""
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    T = lib.ramp([mix(c, CON[2], 0.22) for c in X.RUBBER_RAMP])      # dusty rubber
    for k, (cx, y0) in enumerate([(8, 12), (7, 9), (8, 6)]):         # bottom tyre first
        rows = [(4, T[3]), (5, T[2]), (4, T[1])]
        for j, (half, col) in enumerate(rows):
            y = y0 + j
            for x in range(cx - half, cx + half + 1):
                c = col
                if j == 1 and (x + k) % 2 == 0:
                    c = T[0]                                        # tread blocks
                if x == cx - half and j < 2:
                    c = T[4]
                s.px(x, y, c)
    for y in range(2, 7):                                            # top ring + hole
        for x in range(3, 14):
            dx = (x + 0.5 - 8.5) / 4.8
            dy = (y + 0.5 - 4.6) / 2.1
            if dx * dx + dy * dy > 1.0:
                continue
            if (dx / 0.45) ** 2 + (dy / 0.5) ** 2 <= 1.0:
                c = COLD
            else:
                c = T[4] if dy < 0 and dx < 0.3 else T[3] if dx < 0.4 else T[2]
            s.px(x, y, c)
    s.px(12, 10, RUST[2]); s.px(4, 13, RUST[2])
    return _finish(cv, s, (8.5, 14.8, 6.5, 1.1))


def oil_drum():
    cv = Canvas(16, 24)
    s = Canvas(16, 24)
    D = lib.ramp([mix(c, P.RUST_DULL, 0.3) for c in X.CAR_BLUE])    # faded blue paint, rusting
    shapes.cylinder(s, 8.0, 21, 5.0, 14, D, ry=2.0, bands=((4, 1), (10, 1)))
    C.darken(s, 10, 15, COLD, 0.35); C.darken(s, 11, 16, COLD, 0.3)   # a dent
    s.px(6, 6, MET[4]); s.px(7, 6, MET[2])                                 # bung cap
    for (x0, y0, w, h) in [(3, 15, 5, 5), (9, 9, 3, 4), (4, 9, 2, 3)]:
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                if hval("od", x, y) < 0.7:
                    C.darken(s, x, y, RUST[2], 0.7)
    C.rust_streak(s, 9, 13, 5, 0.5)
    return _finish(cv, s, (8.5, 22.5, 6, 1.2))


def build():
    return {
        "ruins/filing_cabinet.png": filing_cabinet(),
        "ruins/manhole.png": manhole(),
        "ruins/car_burnt.png": car_burnt(),
        "ruins/bones.png": lib.hstrip([bones(1), bones(2)]),
        "ruins/pavement_decor.png": pavement_decor(),
        "ruins/shopping_cart.png": shopping_cart(),
        "ruins/tire_pile.png": tire_pile(),
        "ruins/oil_drum.png": oil_drum(),
        "ruins/dumpster_open.png": dumpster_open(),
    }


# ================================================================================================
# dumpster, searched state (32x32): pairs with the existing ruins/dumpster.png (closed)
# ================================================================================================
def dumpster_open():
    """Lid flung up against the back, bags dragged over the rim, trash spilled at the foot. The
    bin body (rim row 9 downward) is copied pixel-for-pixel from ruins/dumpster.png so the two
    states swap in place."""
    from env.lib import OUT
    closed = Canvas.load(OUT / "ruins" / "dumpster.png")
    G = lib.ramp(X.DUMPSTER_GREEN)
    cv = Canvas(32, 32)
    lid = Canvas(32, 32)
    for y in range(0, 9):                     # lid standing up: its ribbed underside faces us
        for x in range(5, 28):
            c = G[1] if (x - 5) % 5 else G[0]
            if y == 0:
                c = G[3]
            if x == 5:
                c = G[2]
            lid.px(x, y, c)
    for x in range(6, 27):
        if hval("lidrust", x) < 0.3:
            C.darken(lid, x, 6, RUST[2], 0.6); C.darken(lid, x, 7, RUST[2], 0.5)
    lib.outline(lid, COLD, local=0.6)
    cv.blit(lid, 0, 0)
    body = Canvas(32, 32)
    body.a[9:, :] = closed.a[9:, :]
    cv.blit(body, 0, 0)
    # rummaged bags hauled over the rim
    bag = Canvas(32, 32)
    for (cx, cy, rx, ry) in [(10.0, 8.5, 3.2, 2.2), (21.0, 8.0, 3.6, 2.4), (15.5, 7.5, 2.4, 1.8)]:
        m = bag.ellipse_mask(cx, cy, rx, ry)
        for y, x in zip(*np.nonzero(m)):
            dx = (x + 0.5 - cx) / rx
            dy = (y + 0.5 - cy) / ry
            bag.px(x, y, ASPH[4] if dx + dy < -0.4 else ASPH[3] if dx < 0.4 else ASPH[2])
    bag.px(21, 6, ASPH[5]); bag.px(14, 6, PAPER[2]); bag.px(24, 9, RUST[3])
    lib.outline(bag, COLD, local=0.6)
    cv.blit(bag, 0, 0)
    # spilled at the foot (left side; the closed sprite already has a bag on the right)
    spill = Canvas(32, 32)
    for (x, y, c) in [(2, 29, ASPH[3]), (3, 29, ASPH[4]), (4, 29, ASPH[3]), (2, 30, ASPH[2]),
                      (3, 30, ASPH[2]), (4, 30, ASPH[1])]:
        spill.px(x, y, c)
    lib.outline(spill, COLD, local=0.6)
    cv.blit(spill, 0, 0)
    for (x, y, w, h, k) in [(6, 30, 2, 1, 0), (9, 29, 3, 1, 1)]:
        _paper(cv, x, y, w, h, k)
    cv.px(7, 29, MET[3]); cv.px(8, 29, MET[2])            # a can
    return cv
