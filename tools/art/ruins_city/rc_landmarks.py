"""Expedition landmarks (art/env/ruins/): Kael's pickup (arrival / extraction point) and the
subway stairwell (the level's way deeper).

kaels_truck.png  48x32, footprint 3x1. Same side-on 3/4 build as car_wreck_1/2, but intact and
                 cared for, and drawn with the SETTLEMENT conventions (warm outline, warm
                 shadow, warm wood and lamplight) so it reads as friendly in hostile ruins.
subway_stairs.png 32x32, footprint 2x2 (the whole sprite). Seen from above: a stairwell opening
                 in the pavement, steps going down (north) into darkness, concrete knee walls
                 and handrails on three sides, a faded transit sign on the far railing.
"""
from __future__ import annotations

import numpy as np

import palette as P
from env import colors as X
from env import lib
from env.lib import Canvas, mix, rgba
from ruins_city import rc_common as C
from ruins_city.rc_common import (COLD, CON, CREAMS, GLASS, LAMP, PAPER, RUB, RUST, TRANSIT,
                                  TRUCK, WARM, WEED, DRY, hval)

WOOD = lib.ramp(P.WOOD_RAMP)
SMET = lib.ramp(P.METAL_RAMP)              # settlement scrap metal (warm)
CANV = lib.ramp(X.CANVAS_RAMP)
LEAF = lib.ramp(P.LEAF_RAMP)
ROPE = lib.ramp(X.ROPE)
# old green-painted iron railings, weathered toward concrete grey (subway entrance)
SMET_RAIL = lib.ramp([mix(c, X.CONCRETE_RAMP[2], 0.35) for c in X.PAINT_GREEN] +
                     [mix(X.PAINT_GREEN[3], X.CONCRETE_RAMP[5], 0.45)])


# ================================================================================================
# Kael's pickup (48x32)
# ================================================================================================
def _wheel(s, cx, cy, r):
    m = s.ellipse_mask(cx, cy, r, r)
    for y, x in zip(*np.nonzero(m)):
        dx = (x + 0.5 - cx) / r
        dy = (y + 0.5 - cy) / r
        d = dx * dx + dy * dy
        c = RUB[2] if dx + dy < -0.35 else RUB[1]
        if d > 0.78:
            c = RUB[3] if dx + dy < -0.5 else RUB[0]           # tread rim
        if d < 0.32:
            c = SMET[4] if dx + dy < -0.1 else SMET[2]           # hub
            if d < 0.07:
                c = SMET[1]
        s.px(x, y, c)


def kaels_truck():
    cv = Canvas(48, 32)
    s = Canvas(48, 32)
    R = TRUCK
    # -- lower body side (y 15..25), crease highlight, rocker -----------------------------------
    for y in range(15, 26):
        for x in range(2, 46):
            if y < 17 and (x < 3 or x > 44):
                continue
            c = R[3] if y < 19 else R[2]
            if y == 18:
                c = R[4]                                   # body crease catches the light
            if y == 19:
                c = R[1]
            if y >= 24:
                c = R[1]
            s.px(x, y, c)
    # hood top (lit surface) + grille face at the front
    for x in range(3, 15):
        s.px(x, 14, R[5] if x < 12 else R[4]); s.px(x, 13, R[4])
    for x in range(4, 14):
        s.px(x, 12, R[5] if x > 5 else R[4])
    for y in range(13, 22):
        s.px(2, y, SMET[2] if y % 2 else SMET[1])          # grille slats seen at the nose
    # -- cab (x 14..27) --------------------------------------------------------------------------
    for y in range(4, 15):
        f = (y - 4) / 10.0
        xl = int(round(18 - 4 * f))                       # raked windshield
        xr = 27
        for x in range(xl, xr + 1):
            c = R[3]
            if y <= 5:
                c = R[5] if x < 24 else R[4]              # roof top
            if x == xr:
                c = R[2]
            s.px(x, y, c)
    # windows: intact glass with a clean diagonal glint
    for y in range(7, 13):
        f = (y - 4) / 10.0
        xl = int(round(18 - 4 * f)) + 1
        for x in range(xl, 26):
            if x == 21:
                s.px(x, y, R[2])                          # B pillar
                continue
            c = GLASS[3] if y < 9 else GLASS[2]
            if (x - xl) + (y - 7) in (2, 3) or (x - 22) + (y - 7) == 1:
                c = GLASS[5]
            s.px(x, y, c)
    # -- pickup bed (x 28..45): rail, wooden stake sides (warm, cared for) ------------------------
    for x in range(28, 46):
        s.px(x, 14, R[4]); s.px(x, 13, R[2])
    for x in range(29, 45):
        for y in range(8, 13):
            c = WOOD[4] if y == 8 else WOOD[3]
            if y == 12:
                c = WOOD[2]
            if (x - 29) % 5 == 4:
                c = WOOD[2] if y > 8 else WOOD[3]         # stake / board seams
            s.px(x, y, c)
        s.px(x, 10, mix(s.get(x, 10), WOOD[1], 0.35))     # gap between the side boards
    for x in (29, 44):
        for y in range(7, 13):
            s.px(x, y, WOOD[2] if x == 44 else WOOD[4])   # corner stakes
    # cargo: a crate, a tarp bundle roped down, a jerrycan, a spare tyre
    for y in range(3, 8):
        for x in range(30, 36):
            c = WOOD[4] if y == 3 else WOOD[3]
            if x == 35:
                c = WOOD[2]
            if y == 5 and 30 < x < 35:
                c = WOOD[2]
            s.px(x, y, c)
    s.px(31, 4, SMET[4]); s.px(34, 6, SMET[4])
    for y in range(2, 8):
        for x in range(36, 43):
            dx = (x + 0.5 - 39.5) / 3.6
            dy = (y + 0.5 - 7.0) / 5.0
            if dx * dx + dy * dy <= 1.0:
                c = CANV[3] if dx < 0.1 else CANV[2]
                if dy < -0.55:
                    c = CANV[4]
                s.px(x, y, c)
    for y in range(3, 8):
        s.px(39, y, ROPE[1])                              # rope over the tarp
    G = lib.ramp(X.PAINT_GREEN)
    for y in range(4, 8):
        s.px(43, y, G[2]); s.px(44, y, G[1])               # jerrycan
    s.px(43, 3, G[3]); s.px(44, 3, SMET[3])
    # -- lantern on a pole at the back of the bed ------------------------------------------------
    for y in range(1, 13):
        s.px(46, y, WOOD[2])                              # pole
    s.px(45, 1, WOOD[3]); s.px(44, 1, WOOD[3])            # hook arm
    s.px(44, 2, SMET[2])
    for y in range(3, 9):
        for x in range(42, 46):
            edge = x in (42, 45) or y in (3, 8)
            c = SMET[3] if edge else LAMP
            if y == 3 and x in (43, 44):
                c = SMET[4]
            s.px(x, y, c)
    s.px(43, 5, rgba(P.CREAM)); s.px(43, 6, rgba(P.CREAM))  # flame core
    # -- trim: bumpers, bull bar, lights, door seam, handle, a riveted patch panel ---------------
    for y in range(20, 23):
        s.px(1, y, SMET[3])
    for x in range(1, 5):
        s.px(x, 22, SMET[4]); s.px(x, 23, SMET[2])
    for x in range(43, 47):
        s.px(x, 22, SMET[4]); s.px(x, 23, SMET[2])
    s.px(3, 16, CREAMS); s.px(3, 17, mix(CREAMS, R[2], 0.4))          # headlight
    s.px(45, 16, mix(RUST[4], R[3], 0.2))                              # tail light
    for y in range(15, 24):
        s.px(21, y, R[1])                                              # door seam
    s.px(24, 16, SMET[4])                                              # handle
    for y in range(16, 20):
        for x in range(31, 37):
            s.px(x, y, SMET[3] if y < 19 else SMET[2])                 # scrap patch panel
    for (x, y) in [(31, 16), (36, 16), (31, 19), (36, 19)]:
        s.px(x, y, SMET[5])
    # a little honest road dust low on the body, no rot
    for x in range(3, 45):
        if hval("dust", x) < 0.4:
            s.px(x, 24, mix(s.get(x, 24), rgba(P.ASH_BROWN), 0.4))
    # wheel arches + inflated tyres
    for wx in (11.0, 37.0):
        for y in range(19, 26):
            for x in range(int(wx - 6), int(wx + 7)):
                if (x + 0.5 - wx) ** 2 + (y + 0.5 - 25.5) ** 2 < 34:
                    s.px(x, y, mix(R[0], WARM, 0.3))
        _wheel(s, wx, 26.0, 4.3)
    # -- antenna with a strip of green cloth tied on, streaming in the wind ----------------------
    lib.outline(s, WARM, local=0.6)
    for y in range(3, 13):
        cv_y = y
        s.px(5, cv_y, SMET[2] if y > 4 else SMET[4])
    for (x, y, k) in [(6, 4, 3), (7, 4, 4), (8, 5, 3), (9, 5, 2), (6, 5, 2), (7, 5, 3),
                      (10, 6, 3), (8, 6, 2)]:
        s.px(x, y, LEAF[k])
    # warm glow around the lantern (translucent, never over opaque pixels)
    for y in range(0, 13):
        for x in range(37, 48):
            d = ((x + 0.5 - 44.0) / 5.2) ** 2 + ((y + 0.5 - 5.5) / 5.4) ** 2
            if d < 1.0 and s.alpha(x, y) == 0:
                s.px(x, y, rgba(P.LAMPLIGHT, 84 if d < 0.35 else 52 if d < 0.7 else 28))
    cv.shadow(25.0, 30.4, 22.5, 1.6)
    cv.blit(s, 0, 0)
    return cv


# ================================================================================================
# subway stairs (32x32, footprint 2x2)
# ================================================================================================
def subway_stairs():
    cv = Canvas(32, 32)
    s = Canvas(32, 32)
    # pavement apron around the opening (ground level, flat): joints + wear
    for y in range(8, 32):
        for x in range(1, 31):
            c = CON[3]
            if (x - 1) % 10 == 0 or (y - 8) % 12 == 0:
                c = CON[2]
            s.px(x, y, c)
    # the opening: x 7..24, y 11..29 ---------------------------------------------------------
    OX0, OX1, OY0, OY1 = 7, 24, 11, 29
    # far (north) inner wall, facing us, falling away into the dark
    for y in range(OY0, OY0 + 4):
        for x in range(OX0, OX1 + 1):
            s.px(x, y, mix(CON[1], COLD, 0.35 + 0.15 * (y - OY0)))
    # steps: 2 px tread + 1 px riser, darker the deeper they go (north)
    nsteps = 5
    for k in range(nsteps):
        y0 = OY1 - 2 - 3 * k                      # tread top row of step k (k = 0 nearest)
        t = k / (nsteps - 1)
        tread = mix(CON[4], COLD, 0.15 + 0.78 * t)
        tread2 = mix(CON[3], COLD, 0.2 + 0.75 * t)
        riser = mix(CON[1], COLD, 0.45 + 0.5 * t)
        for x in range(OX0, OX1 + 1):
            s.px(x, y0, tread)
            s.px(x, y0 + 1, tread2)
            s.px(x, y0 + 2, riser if k > 0 else tread2)
        # worn centre of each tread (feet), chipped nosing
        for x in range(OX0 + 6, OX1 - 5):
            s.px(x, y0, mix(tread, CON[5], 0.25 * (1 - t)))
    # shadow cast by the west knee wall over the left side of the steps
    for y in range(OY0, OY1 + 1):
        for x in range(OX0, OX0 + 2):
            s.px(x, y, mix(s.get(x, y), COLD, 0.45 if x == OX0 else 0.25))
    # knee walls: west, east, north (concrete, top faces lit)
    for y in range(8, OY1 + 1):
        for x in list(range(3, OX0)) + list(range(OX1 + 1, 29)):
            c = CON[4] if x in (3, OX1 + 1) else CON[3]
            if x in (OX0 - 1, 28):
                c = CON[2]
            s.px(x, y, c)
    for y in range(8, OY0):
        for x in range(3, 29):
            s.px(x, y, CON[4] if y == 8 else CON[3])
    for x in range(OX0, OX1 + 1):
        s.px(x, OY0 - 1, CON[2])
    # the knee walls' faces where they meet the ground at the south end (front faces)
    for x in list(range(3, OX0)) + list(range(OX1 + 1, 29)):
        s.px(x, OY1 + 1, CON[2]); s.px(x, OY1 + 2, CON[1])
    # handrails: pipe on top of the side walls (posts as darker knuckles), rusted
    for y in range(6, OY1 + 1):
        s.px(4, y, SMET_RAIL[3]); s.px(27, y, SMET_RAIL[2])
    for y in (10, 17, 24):
        s.px(4, y, SMET_RAIL[1]); s.px(27, y, SMET_RAIL[1])
        C.rust_streak(s, 5, y + 1, 3, 0.5)
    # far railing with the transit sign (faces south, readable)
    for x in range(3, 29):
        s.px(x, 1, SMET_RAIL[3])
    for x in (4, 27):
        for y in range(1, 10):
            s.px(x, y, SMET_RAIL[2] if x == 27 else SMET_RAIL[3])
    for y in range(1, 8):
        for x in range(2, 30):
            c = TRANSIT[2] if y < 7 else TRANSIT[1]
            if y == 1:
                c = TRANSIT[3]
            if x == 29:
                c = TRANSIT[1]
            s.px(x, y, c)
    C.text(s, 4, 2, "SUBWAY", mix(CREAMS, TRANSIT[2], 0.12), fade={5: 0.4}, drop={4: 1})
    for x in range(2, 30):
        if hval("signchip", x) < 0.18:
            s.px(x, 7, mix(TRANSIT[1], RUST[2], 0.5))       # enamel chipped to rust
    C.rust_streak(s, 12, 8, 2, 0.4)
    # litter on the top step and the apron: a newspaper, a can; weeds in the joints
    for (x, y, c) in [(12, 27, PAPER[3]), (13, 27, PAPER[2]), (13, 28, PAPER[1]), (19, 26, PAPER[2]),
                      (20, 26, PAPER[1])]:
        s.px(x, y, c)
    C.tuft(s, 2, 31, "dry")
    C.tuft(s, 29, 20, "weed")
    s.px(30, 30, WEED[2])
    lib.outline(s, COLD, local=0.6)
    # faint light rising from below on the deepest visible step edges (translucent)
    for x in range(OX0 + 4, OX1 - 3):
        if hval("glow", x) < 0.6:
            yy = OY1 - 2 - 3 * (nsteps - 1)
            s.px(x, yy, rgba(P.SIGNAGE_CREAM, 46))
    for x in range(OX0 + 7, OX1 - 6):
        s.px(x, OY0 + 5, rgba(P.SIGNAGE_CREAM, 30))
    cv.blit(s, 0, 0)
    return cv




def build():
    return {"ruins/kaels_truck.png": kaels_truck(), "ruins/subway_stairs.png": subway_stairs()}
