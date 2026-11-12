"""The Northgate seed vault door (art/env/ruins/vault_door.png): 64 x 32 = 2 frames of 32 x 32,
footprint 2 x 2, seen from above.

A raised concrete collar set in the ground, a worn hazard-chevron border, and a heavy two-leaf
steel hatch with a locking wheel across the seam; a keypad and card slot on the collar's
top-left corner, a caged status lamp on its top-right corner and a faded stencilled sprout (it is
a seed reserve) on its front.
  frame 0  sealed: leaves shut, red lamp
  frame 1  open:   both leaves flung back flat onto the collar (undersides up), a dark stairwell
                   going down to the north, green lamp
Ruins side: ruins palette (concrete greys, the vault's cool steel), the cold outline #181a16 and a
cold contact shadow. The status lamps are signal colours (VAULT_LAMP_*), never the rad-glow green.
"""
from __future__ import annotations

import math

import palette as P
from env import colors as X
from env import lib
from env.lib import Canvas, mix, rgba
from townsfolk.tf_buildings import _hash

COLD = lib.COLD
CON = lib.ramp(X.CONCRETE_RAMP)
STEEL = lib.ramp(P.VAULT_STEEL_RAMP)
RED = lib.ramp(P.VAULT_LAMP_RED)
GREEN = lib.ramp(P.VAULT_LAMP_GREEN)
HAZ = rgba(P.HAZARD_STRIPE_YELLOW)
SIGN = rgba(P.SIGNAGE_CREAM)
WEED = lib.ramp(P.RUIN_WEED_RAMP)
RUST = lib.ramp(P.RUST_RAMP)

FW, FH = 32, 32
COLLAR = (1, 1, 30, 28)        # top surface x0, y0, x1, y1 (the front lip is rows 29-30)
HATCH = (8, 7, 23, 22)         # opening x0, y0, x1, y1
BAND = 2                       # hazard band width outside the steel rim


def _collar(s):
    x0, y0, x1, y1 = COLLAR
    for y in range(y0, y1 + 3):
        for x in range(x0, x1 + 1):
            # chamfered corners
            if (x in (x0, x1)) and (y in (y0, y1 + 2)):
                continue
            if y > y1:                                           # front lip (south face)
                c = CON[2] if y == y1 + 1 else CON[1]
                if x == x1:
                    c = CON[0]
                if _hash("lip", x) < 0.15:
                    c = CON[1]
            else:
                c = CON[3]
                if y == y0 or x == x0:
                    c = CON[4]                                   # lit top / left edges
                elif x == x1:
                    c = CON[2]
                n = _hash("con", x, y)
                if n < 0.10:
                    c = CON[2]
                elif n > 0.93:
                    c = CON[4]
            s.px(x, y, c)
    # cracks and a stain
    for (x, y) in ((3, 12), (4, 13), (4, 14), (5, 15), (27, 20), (26, 21), (26, 22), (27, 23), (25, 24)):
        s.px(x, y, CON[1])
    for (x, y) in ((4, 12), (5, 14), (27, 21)):
        s.px(x, y, CON[4])
    for (x, y) in ((22, 25), (23, 25), (23, 26), (24, 26), (22, 26)):
        s.px(x, y, mix(s.get(x, y), RUST[2], 0.45))
    # weeds in the joint between collar and ground
    for (x, y, k) in ((2, 28, 2), (3, 28, 3), (2, 27, 1), (29, 3, 2), (29, 4, 1)):
        s.px(x, y, WEED[k])


def _hazard(s):
    hx0, hy0, hx1, hy1 = HATCH
    for y in range(hy0 - 1 - BAND, hy1 + 2 + BAND):
        for x in range(hx0 - 1 - BAND, hx1 + 2 + BAND):
            inside = hx0 - 1 <= x <= hx1 + 1 and hy0 - 1 <= y <= hy1 + 1
            if inside:
                continue
            stripe = ((x + y) // 2) % 2 == 0
            c = HAZ if stripe else CON[1]
            if stripe and _hash("worn", x, y) < 0.22:
                c = mix(HAZ, CON[3], 0.6)                         # worn paint
            if y == hy0 - 1 - BAND or x == hx0 - 1 - BAND:
                c = mix(c, CON[4], 0.25)
            s.px(x, y, c)


def _rim(s):
    hx0, hy0, hx1, hy1 = HATCH
    for x in range(hx0 - 1, hx1 + 2):
        s.px(x, hy0 - 1, STEEL[2])
        s.px(x, hy1 + 1, STEEL[4])
    for y in range(hy0 - 1, hy1 + 2):
        s.px(hx0 - 1, y, STEEL[2])
        s.px(hx1 + 1, y, STEEL[4] if y > hy0 else STEEL[3])
    for (x, y) in ((hx0 - 1, hy0 - 1), (hx1 + 1, hy0 - 1), (hx0 - 1, hy1 + 1), (hx1 + 1, hy1 + 1)):
        s.px(x, y, STEEL[5])                                     # bolt heads at the corners


def _leaf(s, x0, y0, w, h, underside=False, mirror=False):
    """One steel leaf. Top side: plate with a raised X stiffener, rivets round the edge.
    Underside: darker, three ribs, a rubber gasket round the edge."""
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            i, j = x - x0, y - y0
            if underside:
                c = STEEL[3] if i < w - 2 else STEEL[2]
                if i in (0, w - 1) or j in (0, h - 1):
                    c = STEEL[0]                                  # rubber gasket
                elif j in (h // 4, h // 2, 3 * h // 4):
                    c = STEEL[4]                                  # rib top
                elif j - 1 in (h // 4, h // 2, 3 * h // 4):
                    c = STEEL[2]                                  # rib shadow
            else:
                c = STEEL[3]
                if j == 0 or i == 0:
                    c = STEEL[4]
                if j == h - 1 or i == w - 1:
                    c = STEEL[2]
                # a raised frame inset 1 px, and two raised cross bars
                if 0 < i < w - 1 and 0 < j < h - 1:
                    if i == 1 or j == 1:
                        c = STEEL[4]
                    elif i == w - 2 or j == h - 2:
                        c = STEEL[1]
                    elif j in (h // 3, 2 * h // 3):
                        c = STEEL[4]
                    elif j - 1 in (h // 3, 2 * h // 3):
                        c = STEEL[1]
                    elif 2 <= i <= w - 3 and (i + j) % 4 == 0:
                        c = mix(STEEL[3], STEEL[2], 0.5)            # tread-plate texture
            s.px(x, y, c)
    if not underside:
        for j in (1, h - 2):                                       # rivets at the corners
            for i in (1, w - 2):
                s.px(x0 + i, y0 + j, STEEL[5])
    # hinges on the outer edge (left leaf: x0 side; right leaf: far side)
    hx = x0 if not mirror else x0 + w - 1
    for hy in (y0 + 2, y0 + h - 3):
        s.px(hx, hy, STEEL[1]); s.px(hx, hy + 1, STEEL[0])


def _wheel(s, cx, cy):
    """Locking hand-wheel across the seam: a dark shadow ring, a bright rim, four spokes, hub."""
    for y in range(cy - 5, cy + 6):
        for x in range(cx - 5, cx + 6):
            d = math.hypot(x - cx, y - cy)
            if 3.5 < d <= 4.4:
                s.px(x, y, STEEL[0])
            elif 2.5 < d <= 3.5:
                lit = (x - cx) + (y - cy) < 0
                s.px(x, y, STEEL[5] if lit else STEEL[3])
            elif d <= 2.5:
                s.px(x, y, STEEL[1])
    for k in (-2, -1, 1, 2):
        s.px(cx + k, cy, STEEL[4] if k < 0 else STEEL[3])
        s.px(cx, cy + k, STEEL[4] if k < 0 else STEEL[3])
    s.px(cx, cy, STEEL[5])


def _keypad(s):
    x0, y0 = 3, 2
    for y in range(y0, y0 + 5):
        for x in range(x0, x0 + 4):
            c = STEEL[2]
            if y == y0 or x == x0:
                c = STEEL[3]
            if x == x0 + 3 or y == y0 + 4:
                c = STEEL[1]
            s.px(x, y, c)
    for (x, y) in ((x0 + 1, y0 + 1), (x0 + 2, y0 + 1), (x0 + 1, y0 + 2), (x0 + 2, y0 + 2)):
        s.px(x, y, SIGN)                                          # four worn buttons
    s.px(x0 + 1, y0 + 3, STEEL[0]); s.px(x0 + 2, y0 + 3, STEEL[0])   # card slot


def _lamp(s, cv, R, glow_alpha):
    x0, y0 = 25, 2
    for y in range(y0, y0 + 4):                                   # cage housing 4 x 4
        for x in range(x0, x0 + 4):
            s.px(x, y, STEEL[1] if (x + y) % 2 else STEEL[2])
    s.px(x0 + 1, y0 + 1, R[3]); s.px(x0 + 2, y0 + 1, R[2])
    s.px(x0 + 1, y0 + 2, R[2]); s.px(x0 + 2, y0 + 2, R[1])
    # soft coloured spill on the concrete round the lamp (drawn on the base canvas, translucent)
    cx, cy = x0 + 2.0, y0 + 2.0
    for y in range(FH):
        for x in range(FW):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if 2.8 < d <= 6.0:
                a = int(glow_alpha * (1 - (d - 2.8) / 3.2))
                if a > 8:
                    cv.append((x, y, R[2][:3] + (a,)))


def _stencil(s):
    """A faded stencilled sprout on the collar's front edge (it is a seed reserve)."""
    pts = [(15, 27), (15, 26), (15, 25), (14, 24), (13, 24), (16, 24), (17, 23), (14, 25), (16, 25)]
    for (x, y) in pts:
        s.px(x, y, mix(SIGN, CON[3], 0.45))


STAIR = [rgba("#0b0c0b"), rgba("#121412"), lib.ramp(P.CHAR_RAMP)[2], lib.ramp(P.CHAR_RAMP)[3],
         CON[1], CON[2], CON[3]]          # far / deep -> near the rim


def _stairs(s):
    """The opening: the north wall's face in shadow at the top, then five steps going down to
    the north, each tread a shade lighter than the one beyond it, a dark drop under each nosing."""
    hx0, hy0, hx1, hy1 = HATCH
    for y in range(hy0, hy1 + 1):
        j = y - hy0
        for x in range(hx0, hx1 + 1):
            if j < 3:
                c = STAIR[0] if j < 2 else STAIR[1]                # north wall, deep in shadow
            else:
                k = (j - 3) // 3                                   # step 0 (deep) .. 4 (near)
                r = (j - 3) % 3
                base = min(len(STAIR) - 1, k + 2)
                c = STAIR[base - 2] if r == 0 else (STAIR[base] if r == 1 else STAIR[base - 1])
            if x in (hx0, hx1):
                c = mix(c, STAIR[0], 0.5)                          # side walls
            s.px(x, y, c)
    # handrail down the left wall
    for y in range(hy0 + 3, hy1 + 1):
        t = (y - hy0) / (hy1 - hy0)
        s.px(hx0 + 1, y, mix(STAIR[1], STEEL[3], t))


def frame(open_):
    s = Canvas(FW, FH)
    _collar(s)
    _hazard(s)
    _rim(s)
    hx0, hy0, hx1, hy1 = HATCH
    w = (hx1 - hx0 + 1) // 2
    h = hy1 - hy0 + 1
    if not open_:
        _leaf(s, hx0, hy0, w, h)
        _leaf(s, hx0 + w, hy0, w, h, mirror=True)
        for y in range(hy0, hy1 + 1):                              # the seam
            s.px(hx0 + w - 1, y, STEEL[1])
            s.px(hx0 + w, y, STEEL[0])
        _wheel(s, hx0 + w - 1, hy0 + h // 2 - 1)
    else:
        _stairs(s)
    _keypad(s)
    _stencil(s)
    glow = []
    _lamp(s, glow, GREEN if open_ else RED, 80)
    leaves = Canvas(FW, FH)
    if open_:
        # both leaves flung back flat, undersides up, hinged on the rim's outer edges
        _leaf(leaves, hx0 - w, hy0, w, h, underside=True)
        _leaf(leaves, hx1 + 1, hy0, w, h, underside=True, mirror=True)
        lib.outline(leaves, COLD, local=0.5)
    lib.outline(s, COLD, local=0.55)
    cv = Canvas(FW, FH)
    cv.shadow(16.5, FH - 0.8, 15, 1.0, alpha=110, color=P.OUTLINE_COLD)
    cv.blit(s, 0, 0)
    for (x, y, c) in glow:
        if cv.a[y, x, 3] == 255:
            cv.px(x, y, c)
    cv.blit(leaves, 0, 0)
    return cv


def vault_door():
    return lib.hstrip([frame(False), frame(True)])
