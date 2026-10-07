"""Larger settlement props: well, scarecrow, laundry line, market stall, water tower, wind
turbine (art/env/props/). Same conventions as env/props.py."""
from __future__ import annotations

import math

import numpy as np

import palette as P
from env import colors as X
from env import lib, shapes
from env.lib import Canvas, mix, rgba
from env.props import (CANV, CREAM, FIRE, LAMP, MET, RUST, SOIL, STONE, WARM, WATER, WOOD,
                       _finish, _hplank, _nail, _vpost)

ROPE = lib.ramp(X.ROPE)
STRAW = lib.ramp(X.STRAW)


def _dk(c, t=0.62):
    return mix(c, WARM, t)


# ================================================================================================
# well (32x32)
# ================================================================================================
def well():
    cv = Canvas(32, 32)
    s = Canvas(32, 32)
    cx, rx, ry = 16.0, 11.0, 4.0
    base, rim = 29, 20
    # stone drum: staggered courses of stones
    for y in range(rim, base + 1):
        for x in range(int(cx - rx), int(cx + rx)):
            dxe = (x + 0.5 - cx) / rx
            dyb = (y + 0.5 - (base - ry + 1)) / ry
            if y > base - ry + 1 and dxe * dxe + dyb * dyb > 1.0:
                continue
            t = (x + 0.5 - (cx - rx)) / (2 * rx)
            course = (y - rim) // 3
            off = 2 if course % 2 else 0
            mortar_v = (x + off) % 5 == 0
            mortar_h = (y - rim) % 3 == 2
            if mortar_h or mortar_v:
                c = STONE[1] if t > 0.5 else mix(STONE[1], STONE[2], 0.5)
            else:
                c = STONE[4] if t < 0.3 else STONE[3] if t < 0.62 else STONE[2]
                if (y - rim) % 3 == 0 and not mortar_v:
                    c = mix(c, STONE[5], 0.35) if t < 0.6 else c
            s.px(x, y, c)
    # rim ring + dark shaft
    for y in range(int(rim - ry) - 1, int(rim + ry) + 1):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 1):
            dx = (x + 0.5 - cx) / (rx + 0.6)
            dy = (y + 0.5 - rim) / (ry + 0.4)
            d = dx * dx + dy * dy
            if d > 1.0:
                continue
            if d > 0.55:
                c = STONE[5] if dy < 0 and dx < 0.3 else STONE[4] if dy < 0.2 else STONE[3]
                if ((math.atan2(dy, dx) + 3.2) * 4.0) % 1.0 < 0.12:
                    c = STONE[2]
            else:
                c = WATER[0] if dy > -0.35 else mix(WATER[0], WARM, 0.5)
                if abs(dx) < 0.25 and 0.1 < dy < 0.35:
                    c = WATER[2]                      # glint far down
            s.px(x, y, c)
    # posts + roof frame
    for x0 in (5, 25):
        _vpost(s, x0, 6, 22, WOOD)
    # windlass axle with rope + crank
    for x in range(7, 25):
        s.px(x, 10, WOOD[3]); s.px(x, 11, WOOD[1])
    for x in range(13, 19):
        s.px(x, 10, ROPE[2] if x % 2 else ROPE[1]); s.px(x, 11, ROPE[1])
    for (x, y) in [(27, 10), (28, 10), (28, 11), (28, 12), (29, 12)]:
        s.px(x, y, MET[3])
    # rope down to the bucket
    for y in range(12, 15):
        s.px(16, y, ROPE[1])
    for y in range(15, 19):
        for x in range(14, 19):
            c = MET[4] if x == 14 else MET[3] if x < 17 else MET[2]
            if y == 15:
                c = MET[2] if x < 18 else MET[1]
            s.px(x, y, c)
    s.px(15, 16, RUST[3])
    # gable roof of salvaged boards
    for y in range(1, 8):
        half = 2 + (y - 1) * 2.2
        for x in range(int(16 - half), int(16 + half) + 1):
            if not 2 <= x <= 29:
                continue
            k = (x - int(16 - half))
            c = WOOD[4] if x < 16 else WOOD[2]
            if y == 7:
                c = WOOD[1]
            if (k % 4 == 0) and y < 7:
                c = mix(c, WOOD[1], 0.5)
            s.px(x, y, c)
    s.px(15, 0, WOOD[4]); s.px(16, 0, WOOD[3])
    for x in (8, 23):
        _nail(s, x, 5)
    return _finish(cv, s, (17.0, 30.6, 13, 1.6))


# ================================================================================================
# scarecrow (16x32)
# ================================================================================================
def scarecrow():
    cv = Canvas(16, 32)
    s = Canvas(16, 32)
    _vpost(s, 7, 11, 30, WOOD)
    # arm stick
    for x in range(1, 15):
        s.px(x, 14, WOOD[4] if x < 8 else WOOD[3]); s.px(x, 15, WOOD[2])
    # ragged shirt
    C = lib.ramp(X.CLOTH_RED)
    for y in range(13, 24):
        for x in range(4, 12):
            hem = y >= 22 and (x % 2 == (y % 2))
            if hem:
                continue
            c = C[3] if x < 7 else C[2] if x < 10 else C[1]
            if y == 13:
                c = C[3] if x < 10 else C[2]
            s.px(x, y, c)
    for x in range(2, 14):        # sleeves along the arms
        if 4 <= x <= 11:
            continue
        s.px(x, 13, C[3] if x < 8 else C[2]); s.px(x, 14, C[2] if x < 8 else C[1])
    # patch + buttons
    Mu = lib.ramp(X.CLOTH_MUSTARD)
    for (x, y) in [(9, 17), (10, 17), (9, 18), (10, 18)]:
        s.px(x, y, Mu[2])
    s.px(9, 17, Mu[3])
    s.px(7, 16, MET[4]); s.px(7, 19, MET[4])
    # straw poking out of cuffs and hem
    for (x, y, k) in [(1, 13, 3), (0, 14, 2), (1, 15, 2), (14, 13, 3), (15, 14, 2), (14, 15, 1),
                      (5, 23, 3), (6, 24, 2), (9, 24, 2), (10, 23, 3), (8, 24, 3)]:
        s.px(x, y, STRAW[k])
    # sack head with stitched face
    for y in range(5, 12):
        for x in range(5, 11):
            if (y in (5, 11)) and x in (5, 10):
                continue
            c = CANV[3] if x < 8 else CANV[2]
            if y == 5:
                c = CANV[4] if x < 9 else CANV[3]
            s.px(x, y, c)
    s.px(6, 7, WARM); s.px(9, 7, WARM)                       # button eyes
    for x in (6, 7, 8, 9):
        s.px(x, 9, CANV[1] if x % 2 else CANV[0])            # stitched smile
    s.px(5, 12, ROPE[1]); s.px(10, 12, ROPE[1]); s.px(7, 12, ROPE[2]); s.px(8, 12, ROPE[1])
    # rusty cooking pot as a hat
    for y in range(2, 6):
        for x in range(4, 12):
            if y == 2 and x in (4, 11):
                continue
            c = MET[4] if x < 7 else MET[3] if x < 10 else MET[2]
            if y == 5:
                c = MET[2] if x < 10 else MET[1]
            if (x * 3 + y) % 5 == 0:
                c = RUST[3]
            s.px(x, y, c)
    s.px(12, 4, MET[3]); s.px(13, 4, MET[2])                # pot handle
    # a can dangling from the arm (bird scarer)
    s.px(2, 16, MET[2]); s.px(2, 17, MET[4]); s.px(3, 17, MET[3]); s.px(2, 18, MET[3])
    s.px(3, 18, MET[2])
    return _finish(cv, s, (9.0, 30.7, 4, 1.1))


# ================================================================================================
# laundry line (48x32)
# ================================================================================================
def laundry_line():
    cv = Canvas(48, 32)
    s = Canvas(48, 32)
    for x0 in (3, 43):
        _vpost(s, x0, 5, 30, WOOD)
        for x in range(x0 - 2, x0 + 4):
            s.px(x, 5, WOOD[4]); s.px(x, 6, WOOD[2])

    def rope_y(x):
        t = (x - 23.5) / 19.0
        return 7 + int(round(3.2 * (1 - t * t)))
    for x in range(5, 43):
        s.px(x, rope_y(x), ROPE[1])

    def hang(x0, w, h, R, kind):
        top = max(rope_y(x) for x in range(x0, x0 + w))
        for y in range(top, top + h):
            for x in range(x0, x0 + w):
                if kind == "shirt":
                    body = x0 + 2 <= x < x0 + w - 2
                    sleeve = y < top + 4
                    if not (body or sleeve):
                        continue
                if kind == "pants":
                    leg_gap = (x == x0 + w // 2) and y > top + 3
                    if leg_gap:
                        continue
                if kind == "sock" and x > x0 + 1 and y < top + 3:
                    continue
                c = R[3] if x < x0 + w * 0.45 else R[2]
                if y == top:
                    c = R[3]
                if y >= top + h - 1 or x == x0 + w - 1:
                    c = R[1]
                s.px(x, y, c)
        if kind == "towel":
            for x in range(x0, x0 + w):
                s.px(x, top + 2, R[0]); s.px(x, top + h - 3, R[0])
        if kind == "shirt":
            s.px(x0 + w // 2, top + 2, CREAM); s.px(x0 + w // 2, top + 5, CREAM)
        # clothespins
        s.px(x0 + 1, top - 1, WOOD[4]); s.px(x0 + w - 2, top - 1, WOOD[3])
    hang(7, 9, 10, lib.ramp(X.CLOTH_TEAL), "shirt")
    hang(18, 6, 11, lib.ramp(X.CLOTH_BLUE), "pants")
    hang(26, 7, 8, lib.ramp(["#6a5a40", "#a89878", "#e0d4b4", "#fff2d4"]), "towel")
    hang(35, 3, 6, lib.ramp(X.CLOTH_MUSTARD), "sock")
    hang(39, 3, 5, lib.ramp(X.CLOTH_RED), "sock")
    lib.outline(s, WARM, local=0.6)
    cv.shadow(5.0, 30.7, 3, 1.1)
    cv.shadow(45.0, 30.7, 3, 1.1)
    # the clothes' soft shadow on the grass
    for x in range(8, 41):
        if x % 1 == 0:
            cv.px(x + 2, 30, rgba(P.OUTLINE_WARM, 34))
    cv.blit(s, 0, 0)
    return cv


# ================================================================================================
# market stall (48x48)
# ================================================================================================
def market_stall():
    cv = Canvas(48, 48)
    s = Canvas(48, 48)
    # back wall in shade under the awning
    for y in range(14, 30):
        for x in range(5, 43):
            c = mix(WOOD[1], WARM, 0.25) if (x % 6) else WOOD[0]
            if y < 17:
                c = mix(c, WARM, 0.35)
            s.px(x, y, c)
    # a shelf with jars + dried herbs hanging
    for x in range(7, 41):
        s.px(x, 21, WOOD[3]); s.px(x, 22, WOOD[1])
    jars = [(9, X.GLASS_GREEN), (13, X.GLASS_BROWN), (17, X.GLASS_GREEN), (30, X.GLASS_BROWN),
            (34, X.GLASS_GREEN), (38, X.GLASS_BROWN)]
    for x, gr in jars:
        g = lib.ramp(gr)
        s.px(x, 18, g[1]); s.px(x, 19, g[2]); s.px(x, 20, g[1]); s.px(x + 1, 19, g[1])
        s.px(x + 1, 20, g[0]); s.px(x, 17, MET[3])
    for x in (22, 25, 27):
        for y in range(16, 20):
            s.px(x, y, STRAW[1] if y < 19 else rgba(P.SPRING["green"]))
    # posts
    for x0 in (3, 43):
        _vpost(s, x0, 9, 45, WOOD)
    # counter top with produce
    for y in range(28, 31):
        for x in range(2, 46):
            c = WOOD[5] if y == 28 else WOOD[4]
            if y == 30:
                c = WOOD[2]
            s.px(x, y, c)
    produce = [
        (7, ["#5a3a28", "#8c5a38", "#b07850"], "pile"),      # mutant potatoes
        (16, ["#8a6a10", "#e1b030", "#ffd860"], "pile"),     # sunbloom
        (25, ["#5a2a2a", "#8a3a34", "#b85a48"], "pile"),     # ironroot
        (34, ["#3e5a2a", "#5d7d3a", "#95ac49"], "pile"),     # greens
    ]
    for x0, cols, _ in produce:
        R = lib.ramp(cols)
        # basket
        for x in range(x0, x0 + 7):
            s.px(x, 27, ROPE[1]); s.px(x, 28, ROPE[2] if x % 2 else ROPE[1])
        # heap of round produce
        for (dx, dy) in [(1, 25), (3, 25), (5, 25), (2, 23), (4, 23), (3, 21)]:
            s.px(x0 + dx, dy + 1, R[1]); s.px(x0 + dx + 1, dy + 1, R[1])
            s.px(x0 + dx, dy, R[2]); s.px(x0 + dx + 1, dy, R[1])
            s.px(x0 + dx, dy, R[2])
        s.px(x0 + 3, 21, R[2]); s.px(x0 + 2, 23, R[2]); s.px(x0 + 1, 25, R[2])
        s.px(x0 + 3, 20, mix(R[2], CREAM, 0.4))
    # counter front: planks + a painted price board
    for y in range(31, 46):
        for x in range(2, 46):
            c = WOOD[3] if (y - 31) % 4 else WOOD[2]
            if x == 2:
                c = WOOD[4]
            if x >= 44:
                c = WOOD[1]
            if y == 45:
                c = WOOD[1]
            s.px(x, y, c)
    for y in range(34, 40):
        for x in range(18, 30):
            c = CANV[4] if y == 34 else CANV[3]
            if y == 39 or x == 29:
                c = CANV[1]
            s.px(x, y, c)
    for x in (20, 21, 23, 26, 27):
        s.px(x, 36, lib.rgba(X.SIGN_RED[1]))
    for x in (20, 22, 23, 25):
        s.px(x, 37, mix(WARM, CANV[2], 0.4))
    # awning: striped, patched canvas sloping down to a scalloped valance
    red = lib.ramp(X.CLOTH_RED)
    for y in range(3, 15):
        inset = max(0, 6 - (y - 3) // 2)
        for x in range(1 + inset, 47 - inset):
            stripe = ((x - 1) // 4) % 2 == 0
            if stripe:
                c = red[3] if y < 10 else red[2]
            else:
                c = CANV[4] if y < 10 else CANV[3]
            if y == 3:
                c = mix(c, CREAM, 0.3)
            if x > 40:
                c = mix(c, WARM, 0.2)
            s.px(x, y, c)
    # valance scallops
    for x in range(1, 47):
        stripe = ((x - 1) // 4) % 2 == 0
        k = (x - 1) % 4
        depth = 2 if k in (1, 2) else 1
        for d in range(depth):
            c = (red[1] if stripe else CANV[2]) if d == depth - 1 else (red[2] if stripe else CANV[3])
            s.px(x, 15 + d, c)
    # patches sewn onto the awning
    for (x0, y0, w, h, R) in [(10, 6, 4, 3, lib.ramp(X.CLOTH_TEAL)),
                              (30, 8, 5, 3, lib.ramp(X.CLOTH_MUSTARD)),
                              (22, 4, 3, 2, lib.ramp(X.CLOTH_BLUE))]:
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                s.px(x, y, R[2] if y < y0 + h - 1 else R[1])
        for x in range(x0, x0 + w, 2):
            s.px(x, y0, R[3])
    return _finish(cv, s, (25.0, 46.6, 22, 1.6))


# ================================================================================================
# water tower (48x96) - the settlement landmark
# ================================================================================================
def water_tower():
    W, H = 48, 96
    cv = Canvas(W, H)
    s = Canvas(W, H)
    M = MET
    Rr = RUST
    # back legs (darker, set back)
    for (xb, xt) in [(15, 17), (32, 30)]:
        for y in range(46, 88):
            f = (y - 46) / 42.0
            x = int(round(xt + (xb - xt) * f))
            s.px(x, y, M[1]); s.px(x + 1, y, M[0])
    # cross bracing between back legs
    for y0, y1 in [(52, 66), (66, 80)]:
        for k in range(0, 15):
            t = k / 14
            yy = int(y0 + (y1 - y0) * t)
            s.px(int(17 + 13 * t), yy, M[1])
            s.px(int(30 - 13 * t), yy, M[1])
    # central down-pipe + valve
    for y in range(47, 94):
        s.px(23, y, M[3]); s.px(24, y, M[2]); s.px(25, y, M[1])
    for x in range(21, 28):
        s.px(x, 80, Rr[2]); s.px(x, 81, Rr[1])
    s.px(27, 79, Rr[3]); s.px(28, 79, Rr[3]); s.px(28, 78, M[3])
    # front legs (splayed)
    for (xb, xt) in [(7, 11), (39, 35)]:
        for y in range(46, 95):
            f = (y - 46) / 48.0
            x = int(round(xt + (xb - xt) * f))
            s.px(x, y, M[4]); s.px(x + 1, y, M[3]); s.px(x + 2, y, M[1])
            if y % 12 == 0:
                s.px(x + 1, y, Rr[3])
        # foot plate
        for x in range(xb - 1, xb + 5):
            s.px(x, 94, STONE[3]); s.px(x, 95, STONE[2])
    # front X-bracing (thin rods) and struts
    for (y0, y1) in [(50, 68), (68, 88)]:
        xl0 = 11 - (y0 - 46) * 4 / 48.0 + 2
        xr0 = 35 + (y0 - 46) * 4 / 48.0
        xl1 = 11 - (y1 - 46) * 4 / 48.0 + 2
        xr1 = 35 + (y1 - 46) * 4 / 48.0
        n = 40
        for k in range(n + 1):
            t = k / n
            s.px(int(round(xl0 + (xr1 - xl0) * t)), int(round(y0 + (y1 - y0) * t)), M[2])
            s.px(int(round(xr0 + (xl1 - xr0) * t)), int(round(y0 + (y1 - y0) * t)), M[2])
        for x in range(int(xl1), int(xr1) + 1):
            s.px(x, y1, M[3]); s.px(x, y1 + 1, M[1])
    # ladder up the right front leg
    for y in range(50, 94):
        f = (y - 46) / 48.0
        x = int(round(35 + 4 * f)) + 3
        s.px(x, y, M[4]); s.px(x + 3, y, M[2])
        if y % 3 == 0:
            s.px(x + 1, y, M[3]); s.px(x + 2, y, M[3])
    # tank body
    cx, rx = 24.0, 19.0
    top, bot = 16, 44
    for y in range(top, bot + 1):
        for x in range(int(cx - rx), int(cx + rx)):
            t = (x + 0.5 - (cx - rx)) / (2 * rx)
            dyb = (y + 0.5 - (bot - 3)) / 4.0
            dxe = (x + 0.5 - cx) / rx
            if y > bot - 3 and dxe * dxe + dyb * dyb > 1.0:
                continue
            c = M[3] if t < 0.1 else M[4] if t < 0.3 else M[3] if t < 0.55 else M[2] if t < 0.8 \
                else M[1]
            # vertical seams + rivet rows
            if int(t * 8) != int((t + 1 / (2 * rx)) * 8):
                c = mix(c, M[0], 0.4)
            if y in (24, 34) and x % 2 == 0:
                c = mix(c, M[5], 0.5)
            s.px(x, y, c)
    # rust streaks bleeding down from the seams/rivets
    r = lib.rng(77)
    for _ in range(14):
        x = r.randrange(int(cx - rx) + 2, int(cx + rx) - 2)
        y = r.randrange(top + 2, top + 14)
        ln = r.randrange(4, 14)
        for k in range(ln):
            if s.alpha(x, y + k) == 255 and y + k < bot - 1:
                c = s.get(x, y + k)
                s.px(x, y + k, mix(c, Rr[3] if k < ln * 0.6 else Rr[2], 0.65))
    # faded painted band with blocky stencil letters
    for x in range(int(cx - rx) + 1, int(cx + rx) - 1):
        for y in (27, 28, 29, 30, 31):
            c = s.get(x, y)
            s.px(x, y, mix(c, rgba(P.SIGNAGE_CREAM), 0.5 if y in (27, 31) else 0.62))
    stencil = mix(Rr[1], M[1], 0.3)
    glyphs = {  # 3x3 blocky glyphs: W A T E R
        0: ["x.x", "x.x", "xxx"], 1: [".x.", "x.x", "xxx"], 2: ["xxx", ".x.", ".x."],
        3: ["xxx", "xx.", "xxx"], 4: ["xx.", "xxx", "x.x"]}
    for gi in range(5):
        gx = 15 + gi * 4
        for j, row in enumerate(glyphs[gi]):
            for i, ch in enumerate(row):
                if ch == "x" and (gi * 3 + i + j) % 7 != 0:      # worn, some flaked
                    s.px(gx + i, 28 + j, stencil)
    # catwalk ring + railing
    for x in range(3, 46):
        s.px(x, 45, M[4] if x < 30 else M[3]); s.px(x, 46, M[1])
        if x % 4 == 0:
            for y in (41, 42, 43, 44):
                s.px(x, y, M[2])
    for x in range(3, 46):
        s.px(x, 41, M[3])
    # conical roof
    for y in range(3, 17):
        half = 2 + (y - 3) * (rx + 1 - 2) / 13.0
        for x in range(int(cx - half), int(cx + half) + 1):
            t = (x + 0.5 - (cx - half)) / (2 * half + 1)
            c = Rr[3] if t < 0.3 else Rr[2] if t < 0.65 else Rr[1]
            if (x - int(cx)) % 5 == 0 and y > 5:
                c = mix(c, Rr[0], 0.4)          # roof panel seams
            if y == 16:
                c = Rr[1]
            if t < 0.3 and y % 4 == 0:
                c = Rr[4]
            s.px(x, y, c)
    # vent cap + weathervane
    for (x, y, c) in [(23, 2, M[4]), (24, 2, M[3]), (25, 2, M[2]), (24, 1, M[3]), (24, 0, M[2]),
                      (22, 3, M[2]), (26, 3, M[1])]:
        s.px(x, y, c)
    lib.outline(s, WARM, local=0.6)
    for (fx) in (9, 41):
        cv.shadow(fx + 1.0, 95.0, 5, 1.0)
    cv.shadow(25.0, 93.4, 3, 0.9)
    cv.blit(s, 0, 0)
    return cv


# ================================================================================================
# wind turbine (32x64 frames x4)
# ================================================================================================
def wind_turbine():
    frames = []
    for f in range(4):
        cv = Canvas(32, 64)
        s = Canvas(32, 64)
        # lattice tower
        for y in range(18, 63):
            t = (y - 18) / 44.0
            xl = int(round(14 - 6 * t))
            xr = int(round(17 + 6 * t))
            s.px(xl, y, MET[4]); s.px(xr, y, MET[2])
        for k, y0 in enumerate(range(20, 60, 8)):
            for i in range(9):
                tt = i / 8
                y = int(y0 + 8 * tt)
                t0 = (y - 18) / 44.0
                xl = 14 - 6 * t0
                xr = 17 + 6 * t0
                x = xl + (xr - xl) * (tt if k % 2 == 0 else 1 - tt)
                s.px(int(round(x)), y, MET[2])
            yb = y0
            t0 = (yb - 18) / 44.0
            for x in range(int(round(14 - 6 * t0)), int(round(17 + 6 * t0)) + 1):
                s.px(x, yb, MET[3])
        # concrete footing
        for x in range(6, 26):
            s.px(x, 62, STONE[3] if x < 18 else STONE[2]); s.px(x, 63, STONE[1])
        # tail vane (painted sheet) behind the nacelle
        for y in range(11, 17):
            for x in range(19, 27):
                if y < 11 + (x - 19) * 0.3 or y > 16 - (x - 19) * 0.25:
                    continue
                c = lib.rgba(X.CLOTH_MUSTARD[1]) if x < 24 else lib.rgba(X.CLOTH_MUSTARD[0])
                if (x * 3 + y) % 7 == 0:
                    c = RUST[3]
                s.px(x, y, c)
        for x in range(17, 20):
            s.px(x, 13, MET[3])
        # nacelle (salvaged alternator housing)
        for y in range(12, 18):
            for x in range(12, 19):
                c = MET[4] if y == 12 else MET[3] if x < 16 else MET[2]
                if y == 17:
                    c = MET[1]
                s.px(x, y, c)
        s.px(17, 14, RUST[3]); s.px(13, 16, RUST[2])
        lib.outline(s, WARM, local=0.6)
        # rotor: 3 blades rotating 30 degrees per frame (period 120 = 4 frames)
        rotor = Canvas(32, 64)
        hx, hy = 12.5, 14.5
        blade_cols = [(MET[5], MET[3], MET[1]), (RUST[4], RUST[3], RUST[1]),
                      (MET[5], MET[3], MET[1])]
        for b in range(3):
            ang = math.radians(f * 30 + b * 120 + 15)
            ux, uy = math.cos(ang), math.sin(ang)
            nx, ny = -uy, ux
            L = 11.5
            for i10 in range(15, int(L * 10)):
                i = i10 / 10.0
                f2 = i / L
                half = 1.6 if f2 < 0.55 else 1.6 - (f2 - 0.55) * 2.2
                for k10 in range(-int(half * 10), int(half * 10) + 1, 4):
                    k = k10 / 10.0
                    px = int(round(hx + ux * i + nx * k))
                    py = int(round(hy + uy * i + ny * k))
                    lit, mid, dark = blade_cols[b]
                    # the leading edge (one side) catches the light
                    side = (nx * -0.6 + ny * -0.8) * k
                    c = lit if side > 0.4 else mid if side > -0.4 else dark
                    rotor.px(px, py, c)
        lib.outline(rotor, WARM, local=0.6)
        # hub
        for (x, y, c) in [(12, 14, MET[5]), (13, 14, MET[3]), (12, 15, MET[3]), (13, 15, MET[1])]:
            rotor.px(x, y, c)
        s.blit(rotor, 0, 0)
        cv.shadow(17.0, 63.0, 10, 1.0)
        cv.blit(s, 0, 0)
        frames.append(cv)
    return lib.hstrip(frames)


def build(out):
    well().save("props/well.png")
    scarecrow().save("props/scarecrow.png")
    laundry_line().save("props/laundry_line.png")
    market_stall().save("props/market_stall.png")
    water_tower().save("props/water_tower.png")
    wind_turbine().save("props/wind_turbine.png")
