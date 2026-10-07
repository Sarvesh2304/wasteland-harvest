"""Ruins props (art/env/ruins/): desaturated ruins palette, cold outline #181a16.

Bottom-centre anchored like every upright sprite; contact shadows use the cold outline colour.
Rad-glow green appears only on irradiated things (rad_barrel, rad_puddle).
"""
from __future__ import annotations

import math

import numpy as np

import palette as P
from env import colors as X
from env import lib, shapes
from env.lib import Canvas, mix, rgba

COLD = lib.COLD
CON = lib.ramp(X.CONCRETE_RAMP)
ASPH = lib.ramp(X.ASPHALT_RAMP)
MET = lib.ramp([mix(c, "#6f6f68", 0.25) for c in P.METAL_RAMP])     # cooler, duller metal
RUST = lib.ramp(P.RUST_RAMP)
RUB = lib.ramp(X.RUBBER_RAMP)
ASH = rgba(P.ASH_BROWN)
CREAMS = rgba(P.SIGNAGE_CREAM)
RAD = lib.ramp(X.RAD_RAMP)
GLASS = lib.ramp(["#1c2226", "#283034", "#3a4448", "#6a7a80", "#9aaab0"])


def _shadow(cv, cx, cy, rx, ry):
    cv.shadow(cx, cy, rx, ry, color=P.OUTLINE_COLD)


def _finish(cv, s, sh):
    lib.outline(s, COLD, local=0.6)
    if sh:
        _shadow(cv, *sh)
    cv.blit(s, 0, 0)
    return cv


def _rust_blotches(s, rects, seed, density=0.5):
    """Organic rust patches (solid blobs with a lit rim and drip streaks), one per rect."""
    r = lib.rng(seed)
    for (x0, y0, w, h) in rects:
        cx = x0 + w / 2.0
        cy = y0 + h / 2.0
        rx = max(1.2, w / 2.0)
        ry = max(1.0, h / 2.0)
        ph = r.uniform(0, 6.28)
        k = r.choice([2, 3])
        pts = []
        for y in range(y0 - 1, y0 + h + 1):
            for x in range(x0 - 1, x0 + w + 1):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                ang = math.atan2(dy, dx)
                lim = 1.0 + 0.14 * math.sin(k * ang + ph) + 0.06 * math.sin(5 * ang + ph * 2)
                if dx * dx + dy * dy <= lim * lim and s.alpha(x, y) == 255:
                    pts.append((x, y))
        ptset = set(pts)
        for (x, y) in pts:
            c = s.get(x, y)
            edge_tl = (x - 1, y) not in ptset or (x, y - 1) not in ptset
            col = RUST[2] if not edge_tl else RUST[3]
            if (x * 7 + y * 3 + seed) % 11 == 0:
                col = RUST[1]
            s.px(x, y, mix(c, col, 0.78))
        # drips below the patch
        for _ in range(max(1, w // 4)):
            if not pts:
                break
            x = r.choice([p[0] for p in pts])
            ybot = max(p[1] for p in pts if p[0] == x)
            for d in range(1, r.randint(2, 4)):
                if s.alpha(x, ybot + d) == 255:
                    s.px(x, ybot + d, mix(s.get(x, ybot + d), RUST[2], 0.55 - d * 0.1))


def _wheel(s, cx, cy, r, flat=True, rim=True):
    m = s.ellipse_mask(cx, cy, r, r)
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        dx = (x + 0.5 - cx) / r
        dy = (y + 0.5 - cy) / r
        d = dx * dx + dy * dy
        c = RUB[2] if dx + dy < -0.3 else RUB[1]
        if rim and d < 0.3:
            c = MET[3] if dx + dy < 0 else MET[1]
            if d < 0.06:
                c = MET[0]
        s.px(x, y, c)
    if flat:
        for x in range(int(cx - r), int(cx + r) + 1):
            s.px(x, int(cy + r), RUB[0])


# ================================================================================================
# car wrecks (48x32)
# ================================================================================================
def _car(s, R, facing_left=True, pickup=False, seed=0):
    """Sedan / pickup body in 3/4 side view, ground at y=30. R = paint ramp (5)."""
    base = 30
    # body side
    for y in range(15, 27):
        for x in range(2, 46):
            if y < 17 and (x < 4 or x > 43):
                continue
            if y == 15 and (x < 5 or x > 42):
                continue
            c = R[3] if y < 20 else R[2] if y < 24 else R[1]
            if y == 19:
                c = R[4]                                   # body crease highlight
            if y == 20:
                c = R[1]
            s.px(x, y, c)
    # hood / trunk tops (lit surfaces)
    for x in range(4, 16):
        s.px(x, 14, R[4]); s.px(x, 13, R[4] if x > 5 else R[3])
    for x in range(33, 44):
        s.px(x, 14, R[4]); s.px(x, 13, R[3] if not pickup else R[2])
    # cabin
    if not pickup:
        cab_l, cab_r = 15, 34
    else:
        cab_l, cab_r = (27, 40) if facing_left is False else (8, 21)
    for y in range(5, 15):
        f = (y - 5) / 9.0
        xl = int(round(cab_l + 4 - 4 * f))
        xr = int(round(cab_r - 3 + 3 * f))
        for x in range(xl, xr + 1):
            c = R[3]
            if y <= 6:
                c = R[4]                                   # roof top
            s.px(x, y, c)
    # windows (dark, broken)
    for y in range(7, 13):
        f = (y - 5) / 9.0
        xl = int(round(cab_l + 4 - 4 * f)) + 2
        xr = int(round(cab_r - 3 + 3 * f)) - 2
        for x in range(xl, xr + 1):
            if x == (xl + xr) // 2:
                s.px(x, y, R[1])                           # B pillar
                continue
            c = GLASS[1] if y > 8 else GLASS[2]
            s.px(x, y, c)
    r = lib.rng(seed)
    for _ in range(4):
        x = r.randrange(cab_l + 3, cab_r - 3)
        y = r.randrange(7, 10)
        if s.get(x, y)[:3] in (GLASS[1][:3], GLASS[2][:3]):
            s.px(x, y, GLASS[4])                            # broken glass glints
    # wheel arches + wheels (flat, rusted)
    for wx in (11.0, 37.0):
        for y in range(21, 27):
            for x in range(int(wx - 5), int(wx + 6)):
                if (x + 0.5 - wx) ** 2 + (y + 0.5 - 26.5) ** 2 < 28:
                    s.px(x, y, mix(R[0], COLD, 0.4))
        _wheel(s, wx, 26.5, 3.6, flat=True, rim=(wx != 37.0 or seed % 2 == 0))
    # door seams, handle, trim, bumpers, lights
    for y in range(15, 25):
        s.px(24, y, R[1])
    s.px(21, 17, MET[4]); s.px(28, 17, MET[4])
    for x in range(2, 6):
        s.px(x, 22, MET[3]); s.px(x, 23, MET[1])
    for x in range(42, 46):
        s.px(x, 22, MET[3]); s.px(x, 23, MET[1])
    s.px(2, 17, CREAMS); s.px(3, 17, mix(CREAMS, COLD, 0.4))      # headlight
    s.px(45, 17, mix(RUST[3], R[3], 0.3))                         # tail light
    if pickup:
        # open truck bed with junk instead of a trunk lid
        bx0, bx1 = (32, 44) if facing_left is False else (4, 16)
        bx0, bx1 = (4, 15) if facing_left else (33, 44)
        for x in range(bx0, bx1 + 1):
            s.px(x, 13, R[1]); s.px(x, 14, mix(R[0], COLD, 0.3))
        for (x, y, c) in [(bx0 + 2, 12, MET[3]), (bx0 + 3, 12, MET[2]), (bx0 + 6, 11, RUST[3]),
                          (bx0 + 7, 12, RUST[2]), (bx0 + 5, 12, CON[3])]:
            s.px(x, y, c)


def car_wreck(i):
    cv = Canvas(48, 32)
    s = Canvas(48, 32)
    if i == 1:
        R = lib.ramp(X.CAR_RED)
        _car(s, R, seed=3)
        _rust_blotches(s, [(4, 21, 8, 5), (30, 16, 7, 4), (17, 23, 6, 3), (40, 18, 4, 5)], 11)
        # popped hood edge + missing hubcap handled in _car
    else:
        R = lib.ramp(X.CAR_BLUE)
        _car(s, R, facing_left=True, pickup=True, seed=4)
        _rust_blotches(s, [(6, 18, 6, 6), (26, 21, 9, 4), (38, 15, 5, 4)], 12, 0.55)
        # door missing: dark cavity with a seat edge
        for y in range(16, 23):
            for x in range(25, 31):
                s.px(x, y, mix(R[0], COLD, 0.5))
        for x in range(26, 30):
            s.px(x, 19, lib.rgba(X.CLOTH_RED[1]))
    # dead weeds at the wheels
    W = lib.ramp(["#3e3a2c", "#5c5347", "#7a6e58"])
    for (x, y, k) in [(6, 29, 1), (7, 28, 2), (15, 29, 1), (33, 29, 1), (42, 28, 2), (43, 29, 1)]:
        s.px(x, y, W[k])
    return _finish(cv, s, (25.0, 30.6, 22, 1.5))


# ================================================================================================
# barricade, cone, concrete barrier
# ================================================================================================
def barricade():
    cv = Canvas(32, 16)
    s = Canvas(32, 16)
    HZ = lib.ramp(X.HAZARD_YELLOW)
    WD = lib.ramp([mix(c, "#6f6f68", 0.3) for c in P.WOOD_RAMP])
    # A-frame legs
    for x0 in (5, 24):
        for (dx, y0) in [(0, 8), (2, 8)]:
            for y in range(y0, 15):
                xx = x0 + dx + ((y - y0) // 3) * (1 if dx else -1)
                s.px(xx, y, WD[3] if dx == 0 else WD[2])
    # striped plank
    for y in range(4, 9):
        for x in range(2, 30):
            stripe = ((x + (y - 4)) // 3) % 2 == 0
            c = HZ[2] if stripe else mix(COLD, ASPH[3], 0.4)
            if y == 4:
                c = mix(c, CREAMS, 0.35)
            if y == 8:
                c = mix(c, COLD, 0.45)
            s.px(x, y, c)
    # peeling + a rusty warning plate
    for (x, y) in [(9, 6), (10, 6), (19, 5), (22, 7)]:
        s.px(x, y, WD[3])
    for y in range(9, 12):
        for x in range(13, 19):
            s.px(x, y, RUST[3] if y == 9 else RUST[2])
    s.px(15, 10, CREAMS); s.px(16, 10, CREAMS)
    return _finish(cv, s, (17.0, 14.7, 14, 1.2))


def traffic_cone():
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    O = lib.ramp(X.CONE_ORANGE)
    # square base
    for x in range(2, 14):
        s.px(x, 13, ASPH[4] if x < 10 else ASPH[3]); s.px(x, 14, ASPH[2])
    for x in range(3, 13):
        s.px(x, 12, ASPH[4])
    # cone body
    for y in range(2, 12):
        half = 0.8 + (y - 2) * 0.42
        for x in range(int(8 - half), int(8 + half) + 1):
            t = (x + 0.5 - (8 - half)) / (2 * half + 1)
            c = O[3] if t < 0.35 else O[2] if t < 0.7 else O[1]
            if y in (6, 7):
                c = CREAMS if t < 0.6 else mix(CREAMS, COLD, 0.35)   # reflective band
            s.px(x, y, c)
    s.px(8, 1, O[2])
    # scuffs + crack
    s.px(9, 9, O[1]); s.px(6, 10, mix(O[3], CREAMS, 0.3))
    return _finish(cv, s, (9.0, 14.8, 7, 1.2))


def concrete_barrier():
    cv = Canvas(32, 16)
    s = Canvas(32, 16)
    # top face
    for x in range(4, 28):
        s.px(x, 3, CON[5] if x < 20 else CON[4]); s.px(x, 4, CON[4])
    # sloped front: narrow top widening to the foot
    for y in range(5, 15):
        inset = 3 if y < 9 else 2 if y < 11 else 1 if y < 13 else 0
        for x in range(4 - (3 - inset), 28 + (3 - inset)):
            c = CON[3] if y < 10 else CON[2]
            if y == 9 or y == 10:
                c = CON[4] if y == 9 else CON[2]          # the kink of the profile
            if x > 24 + (3 - inset):
                c = mix(c, CON[1], 0.6)
            if y == 14:
                c = CON[1]
            s.px(x, y, c)
    # faded hazard stripe + cracks + chip
    HZ = lib.ramp(X.HAZARD_YELLOW)
    for x in range(6, 26):
        if (x // 3) % 2 == 0:
            s.px(x, 6, mix(HZ[1], CON[3], 0.4)); s.px(x, 7, mix(HZ[1], CON[3], 0.5))
    for (x, y) in [(11, 8), (12, 9), (12, 10), (13, 11), (21, 5), (22, 6)]:
        s.px(x, y, CON[0])
    for (x, y) in [(26, 3), (27, 3), (27, 4)]:
        s.px(x, y, CON[1])
    # rebar loop poking out of the end
    s.px(2, 8, RUST[3]); s.px(1, 9, RUST[2]); s.px(2, 10, RUST[2])
    return _finish(cv, s, (17.0, 14.8, 15, 1.2))


# ================================================================================================
# dumpster, broken street lamp, rubble
# ================================================================================================
def dumpster():
    cv = Canvas(32, 32)
    s = Canvas(32, 32)
    G = lib.ramp(X.DUMPSTER_GREEN)
    # lid (open, propped up at the back)
    for y in range(3, 9):
        for x in range(4, 29):
            c = G[3] if y < 5 else G[2]
            if y == 8:
                c = G[1]
            if x > 25:
                c = mix(c, G[0], 0.4)
            s.px(x, y, c)
    # bin top rim + garbage inside
    for x in range(3, 30):
        s.px(x, 9, G[4]); s.px(x, 10, mix(G[0], COLD, 0.4))
    bags = [(7, 9, ASPH[2]), (8, 9, ASPH[3]), (12, 8, ASPH[3]), (13, 8, ASPH[4]), (14, 9, ASPH[2]),
            (20, 9, CON[3]), (24, 8, ASPH[3]), (25, 9, ASPH[2])]
    for x, y, c in bags:
        s.px(x, y, c)
    # body: front face with ribs, slightly tapered
    for y in range(11, 28):
        for x in range(3, 30):
            c = G[3] if x < 6 else G[2]
            if x > 26:
                c = G[1]
            if (x - 3) % 6 == 0:
                c = G[4] if x < 20 else G[3]                   # vertical ribs
            if (x - 3) % 6 == 1:
                c = G[1]
            if y == 27:
                c = G[0]
            s.px(x, y, c)
    # stenciled marks, rust, a dent
    for x in range(10, 16):
        s.px(x, 17, mix(CREAMS, G[2], 0.45))
    _rust_blotches(s, [(4, 22, 9, 5), (20, 13, 5, 4), (25, 22, 4, 5)], 21, 0.55)
    s.px(17, 20, G[0]); s.px(18, 21, G[0]); s.px(17, 21, G[4])
    # casters
    for wx in (6, 26):
        s.px(wx, 28, MET[2]); s.px(wx + 1, 28, MET[1]); s.px(wx, 29, RUB[1]); s.px(wx + 1, 29, RUB[0])
    # spilled bag at the foot
    for (x, y, c) in [(28, 28, ASPH[3]), (29, 28, ASPH[4]), (29, 29, ASPH[2]), (30, 29, ASPH[2])]:
        s.px(x, y, c)
    return _finish(cv, s, (17.0, 29.8, 15, 1.4))


def streetlamp_broken():
    cv = Canvas(16, 48)
    s = Canvas(16, 48)
    # concrete footing
    for y in range(42, 47):
        for x in range(4, 12):
            c = CON[4] if y == 42 else CON[3] if x < 9 else CON[2]
            if y == 46:
                c = CON[1]
            s.px(x, y, c)
    s.px(10, 43, CON[1]); s.px(11, 44, CON[0])
    # pole, bent over near the top
    for y in range(12, 42):
        s.px(7, y, MET[4]); s.px(8, y, MET[2])
    for (x, y) in [(8, 11), (9, 10), (10, 9), (11, 9), (12, 10)]:
        s.px(x, y, MET[4]); s.px(x, y + 1, MET[2])
    # dangling lamp head (smashed)
    for y in range(12, 17):
        for x in range(11, 15):
            c = MET[3] if x < 13 else MET[1]
            if y >= 15 and x in (12, 13):
                c = GLASS[2] if (x + y) % 2 else GLASS[3]
            s.px(x, y, c)
    s.px(13, 17, GLASS[4]); s.px(12, 18, GLASS[3])               # falling shard
    # peeling paint, rust, a torn notice
    for (x, y) in [(7, 20), (8, 21), (7, 33), (8, 34), (7, 35)]:
        s.px(x, y, RUST[3])
    for y in range(24, 29):
        s.px(6, y, CREAMS if y < 27 else mix(CREAMS, COLD, 0.3))
    s.px(5, 25, mix(CREAMS, COLD, 0.25))
    return _finish(cv, s, (9.0, 46.7, 5, 1.1))


def rubble_pile(i):
    cv = Canvas(32, 32)
    s = Canvas(32, 32)
    chunks = {
        1: [(9.0, 30, 12, 9, 61), (21.0, 30, 13, 11, 62), (15.0, 23, 12, 10, 63),
            (25.0, 22, 7, 6, 64), (6.0, 25, 6, 5, 65)],
        2: [(16.0, 30, 22, 12, 71), (10.0, 21, 10, 8, 72), (21.0, 19, 9, 8, 73), (27.0, 28, 6, 5, 74)],
    }[i]
    for (cx, base, w, h, sd) in chunks:
        layer = Canvas(32, 32)
        shapes.facet_rock(layer, cx, base, w, h, CON, seed=sd, n_facets=5, jag=0.18)
        lib.outline(layer, COLD, local=0.55)
        s.blit(layer, 0, 0)
    # bricks + rebar + dust
    B = lib.ramp([mix(P.RUST_DULL, P.ASH_BROWN, 0.3), P.RUST_DULL, mix(P.RUST_BRIGHT, P.ASH_BROWN, 0.3)])
    for (x, y) in ([(4, 28), (26, 27), (13, 29)] if i == 1 else [(5, 28), (24, 25)]):
        s.px(x, y, B[2]); s.px(x + 1, y, B[2]); s.px(x, y + 1, B[1]); s.px(x + 1, y + 1, B[0])
        s.px(x + 2, y + 1, B[1])
    rebar = [[(14, 14), (12, 8), (13, 5)], [(22, 16), (26, 10)]] if i == 1 else \
        [[(18, 13), (19, 6), (21, 4)], [(9, 15), (6, 11)]]
    for pts in rebar:
        shapes.thick_line(s, pts, 1, [RUST[3]])
        s.px(pts[-1][0], pts[-1][1], RUST[4])
    lib.outline(s, COLD, local=0.55)
    _shadow(cv, 17.0, 30.7, 15, 1.5)
    cv.blit(s, 0, 0)
    return cv


# ================================================================================================
# bus wreck (96x48)
# ================================================================================================
def bus_wreck():
    cv = Canvas(96, 48)
    s = Canvas(96, 48)
    Y = lib.ramp(X.BUS_YELLOW)
    base = 46
    # roof top
    for x in range(5, 91):
        s.px(x, 6, Y[4] if x < 70 else Y[3]); s.px(x, 7, Y[3])
    for x in range(4, 92):
        s.px(x, 8, Y[3])
    # body side
    for y in range(9, 41):
        for x in range(3, 93):
            c = Y[3] if y < 26 else Y[2] if y < 36 else Y[1]
            if y in (26, 32):
                c = mix(COLD, Y[1], 0.4)                  # rub rails
            if y == 27 or y == 33:
                c = Y[4] if y == 27 else Y[3]
            if x > 89:
                c = mix(c, Y[0], 0.4)                       # front face corner shading
            s.px(x, y, c)
    # window row (8 windows), soot above the broken ones
    for k in range(8):
        x0 = 8 + k * 9
        for y in range(12, 22):
            for x in range(x0, x0 + 7):
                c = GLASS[1] if y > 13 else GLASS[2]
                s.px(x, y, c)
        if k in (1, 2, 5):
            for x in range(x0 - 1, x0 + 8):
                for y in (9, 10, 11):
                    if (x + y) % 3:
                        s.px(x, y, mix(s.get(x, y), COLD, 0.55 - (11 - y) * 0.12))
        if k in (0, 3, 6):
            s.px(x0 + 1, 13, GLASS[4]); s.px(x0 + 2, 14, GLASS[3])
    # door at the front (folding panels)
    for y in range(12, 37):
        for x in range(80, 87):
            c = GLASS[2] if y < 24 and x not in (83,) else Y[2]
            if x == 83:
                c = mix(COLD, Y[1], 0.3)
            s.px(x, y, c)
    # destination sign + headlight + bumper
    for x in range(88, 92):
        s.px(x, 10, mix(CREAMS, COLD, 0.2)); s.px(x, 11, mix(CREAMS, COLD, 0.45))
    s.px(92, 30, CREAMS); s.px(92, 31, mix(CREAMS, COLD, 0.4))
    for y in range(36, 40):
        s.px(93, y, MET[2]); s.px(2, y, MET[2])
    # burn / rust patches
    _rust_blotches(s, [(14, 30, 12, 7), (60, 33, 11, 5), (4, 9, 7, 4)], 31, 0.5)
    for (cx0, cy0, rx0, ry0) in [(34.0, 31.0, 5.0, 4.5), (56.0, 10.5, 5.0, 1.6)]:
        for y in range(int(cy0 - ry0) - 1, int(cy0 + ry0) + 2):
            for x in range(int(cx0 - rx0) - 1, int(cx0 + rx0) + 2):
                d = ((x + 0.5 - cx0) / rx0) ** 2 + ((y + 0.5 - cy0) / ry0) ** 2
                if d <= 1.0 and s.alpha(x, y) == 255:
                    s.px(x, y, mix(s.get(x, y), ASH, 0.75 if d < 0.5 else 0.5))
    # wheel wells + flat tyres
    for wx in (18.0, 74.0):
        for y in range(34, 41):
            for x in range(int(wx - 7), int(wx + 8)):
                if (x + 0.5 - wx) ** 2 + (y + 0.5 - 41) ** 2 < 46:
                    s.px(x, y, mix(Y[0], COLD, 0.5))
        _wheel(s, wx, 41.0, 5.0, flat=True)
    # dead grass at the base
    W = lib.ramp(["#3e3a2c", "#5c5347", "#7a6e58"])
    for (x, y, k) in [(8, 45, 1), (9, 44, 2), (30, 45, 1), (52, 45, 2), (53, 44, 1), (88, 45, 1)]:
        s.px(x, y, W[k])
    lib.outline(s, COLD, local=0.6)
    _shadow(cv, 49.0, 46.4, 45, 1.6)
    cv.blit(s, 0, 0)
    return cv


# ================================================================================================
# containers: locker, fridge, supply crate (closed / open frames)
# ================================================================================================
def locker():
    frames = []
    L = lib.ramp(X.LOCKER_GREY)
    for open_ in (False, True):
        cv = Canvas(16, 32)
        s = Canvas(16, 32)
        # cabinet: top face + front
        for x in range(3, 13):
            s.px(x, 2, L[4]); s.px(x, 3, L[3])
        for y in range(4, 30):
            for x in range(3, 13):
                c = L[2] if x > 3 else L[3]
                if x == 12:
                    c = L[1]
                s.px(x, y, c)
        if not open_:
            # door: vents + handle + dent + peeling sticker
            for y in (6, 8, 10):
                for x in range(5, 11):
                    s.px(x, y, L[0])
                    s.px(x, y + 1, L[3])
            s.px(10, 17, MET[4]); s.px(10, 18, MET[2])
            s.px(6, 22, L[0]); s.px(7, 23, L[3])
            for y in range(13, 16):
                s.px(5, y, mix(CREAMS, L[2], 0.3)); s.px(6, y, mix(CREAMS, L[2], 0.45))
            for x in range(3, 13):
                s.px(x, 4, L[3])
        else:
            # dark interior with a shelf and a forgotten item
            for y in range(5, 29):
                for x in range(4, 12):
                    s.px(x, y, mix(L[0], COLD, 0.5) if y > 8 else mix(L[0], COLD, 0.7))
            for x in range(4, 12):
                s.px(x, 12, L[2]); s.px(x, 13, L[0])
            s.px(6, 11, lib.rgba(X.CLOTH_TEAL[2])); s.px(7, 11, lib.rgba(X.CLOTH_TEAL[1]))
            # door swung open toward the viewer, seen edge-on on the left
            for y in range(3, 30):
                s.px(1, y, L[4]); s.px(2, y, L[3])
            s.px(1, 16, MET[4])
        _rust_blotches(s, [(3, 26, 10, 3)], 41 + open_, 0.4)
        frames.append(_finish(cv, s, (9.0, 30.6, 6, 1.2)))
    return lib.hstrip(frames)


def fridge():
    frames = []
    F = lib.ramp(X.FRIDGE_WHITE)
    for open_ in (False, True):
        cv = Canvas(16, 32)
        s = Canvas(16, 32)
        for x in range(3, 13):
            s.px(x, 3, F[4]); s.px(x, 4, F[3])
        for y in range(5, 30):
            for x in range(3, 13):
                c = F[3] if x < 6 else F[2]
                if x == 12:
                    c = F[1]
                if y == 29:
                    c = F[1]
                s.px(x, y, c)
        if not open_:
            for x in range(3, 13):
                s.px(x, 12, F[1])                            # freezer split
            for y in (7, 8, 9):
                s.px(11, y, MET[2])
            for y in range(15, 21):
                s.px(11, y, MET[2])                          # handles
            for x in range(5, 9):
                s.px(x, 18, lib.rgba(X.SIGN_RED[1]))        # faded magnet / note
            s.px(6, 17, CREAMS)
        else:
            for y in range(6, 28):
                for x in range(4, 12):
                    s.px(x, y, mix(F[0], COLD, 0.5))
            for y in (12, 18, 23):
                for x in range(4, 12):
                    s.px(x, y, F[2])
            # leftovers: a can and a jar
            s.px(5, 17, MET[3]); s.px(6, 17, MET[2]); s.px(5, 16, MET[4])
            s.px(9, 22, lib.rgba(X.GLASS_GREEN[2])); s.px(9, 21, lib.rgba(X.GLASS_GREEN[3]))
            for y in range(4, 30):
                s.px(1, y, F[3]); s.px(2, y, F[2])
            s.px(1, 17, MET[2])
        _rust_blotches(s, [(3, 24, 10, 5), (9, 6, 3, 3)], 51 + open_, 0.4)
        frames.append(_finish(cv, s, (9.0, 30.6, 6, 1.2)))
    return lib.hstrip(frames)


def supply_crate():
    frames = []
    O = lib.ramp(["#22281c", "#323a26", "#465034", "#5c6844", "#768258"])   # olive drab
    for open_ in (False, True):
        cv = Canvas(16, 16)
        s = Canvas(16, 16)
        # body
        for y in range(7, 14):
            for x in range(2, 14):
                c = O[3] if x < 4 else O[2]
                if x == 13 or y == 13:
                    c = O[1]
                if y == 10:
                    c = O[1]                      # strap
                s.px(x, y, c)
        for x in (4, 11):
            for y in range(7, 14):
                s.px(x, y, O[1])                   # reinforcing bands
        if not open_:
            for y in range(4, 7):
                for x in range(2, 14):
                    s.px(x, y, O[4] if y == 4 else O[3])
            # stencil + latch
            for x in (6, 7, 9):
                s.px(x, 8, mix(CREAMS, O[2], 0.35))
            s.px(8, 7, MET[4]); s.px(8, 8, MET[2])
        else:
            # lid flipped back + contents
            for y in range(1, 5):
                for x in range(2, 14):
                    s.px(x, y, O[3] if y < 3 else O[2])
            for x in range(3, 13):
                s.px(x, 5, mix(O[0], COLD, 0.4)); s.px(x, 6, mix(O[0], COLD, 0.6))
            for (x, y, c) in [(4, 5, MET[3]), (5, 5, MET[4]), (8, 5, RUST[3]), (9, 6, RUST[2]),
                              (11, 5, CREAMS)]:
                s.px(x, y, c)
        frames.append(_finish(cv, s, (9.0, 14.8, 7, 1.2)))
    return lib.hstrip(frames)


# ================================================================================================
# radiation: barrel + puddle, and the remains
# ================================================================================================
def rad_barrel():
    cv = Canvas(16, 24)
    s = Canvas(16, 24)
    D = lib.ramp(["#2c2a16", "#45401e", "#5e5626", "#7a6e30", "#958840"])    # faded drum paint
    shapes.cylinder(s, 8.0, 21, 5.0, 13, D, ry=2.0, bands=((3, 1), (9, 1)))
    # hazard trefoil (faded) on the drum face
    for (x, y) in [(6, 13), (7, 12), (9, 12), (10, 13), (8, 14), (8, 15), (7, 15), (9, 15)]:
        s.px(x, y, mix(COLD, D[2], 0.2))
    s.px(8, 13, D[4])
    # puncture leaking glowing ooze
    s.px(11, 15, RAD[0]); s.px(11, 16, RAD[3]); s.px(11, 17, RAD[2]); s.px(12, 18, RAD[3])
    s.px(11, 19, RAD[2]); s.px(12, 20, RAD[1])
    _rust_blotches(s, [(3, 17, 5, 4), (9, 8, 3, 3)], 61, 0.45)
    lib.outline(s, COLD, local=0.6)
    # glowing pool at the base (opaque core + translucent glow)
    for y in range(20, 24):
        for x in range(8, 16):
            dx = (x + 0.5 - 12.0) / 3.6
            dy = (y + 0.5 - 22.0) / 1.4
            d = dx * dx + dy * dy
            if d < 1.0:
                c = RAD[3] if d < 0.35 else RAD[2]
                if (x, y) == (11, 21):
                    c = RAD[4]
                s.px(x, y, c)
            elif d < 2.0 and s.alpha(x, y) == 0:
                s.px(x, y, rgba(P.RAD_GLOW, 70))
    _shadow(cv, 8.0, 22.5, 6, 1.2)
    cv.blit(s, 0, 0)
    return cv


def rad_puddle():
    frames = []
    shape = [(16.0, 8.5, 12.0, 4.2), (9.0, 9.5, 5.0, 3.0), (24.0, 7.5, 5.5, 3.0)]
    bubbles = [[(12, 8), (20, 9)], [(12, 7), (21, 8), (8, 10)], [(18, 7), (8, 9)],
               [(17, 8), (24, 7)]]
    for f in range(4):
        cv = Canvas(32, 16)

        def inside(x, y, grow=0.0):
            v = 9.0
            for (cx, cy, rx, ry) in shape:
                d = ((x + 0.5 - cx) / (rx + grow)) ** 2 + ((y + 0.5 - cy) / (ry + grow * 0.6)) ** 2
                v = min(v, d)
            return v
        for y in range(16):
            for x in range(32):
                d = inside(x, y)
                if d <= 1.0:
                    c = RAD[2] if d > 0.62 else RAD[3]
                    if d > 0.88:
                        c = RAD[1]
                    # shimmer bands that drift each frame
                    if d < 0.62 and (x + y * 2 + f * 3) % 9 == 0:
                        c = RAD[4]
                    cv.px(x, y, c)
                elif inside(x, y, 1.6) <= 1.0:
                    cv.px(x, y, rgba(P.RAD_GLOW, 80 if f % 2 == 0 else 64))
        for (x, y) in bubbles[f]:
            cv.px(x, y, RAD[4]); cv.px(x + 1, y, RAD[3]); cv.px(x, y - 1, rgba("#e8ffc8"))
        frames.append(cv)
    return lib.hstrip(frames)


def remains():
    """Non-gory: a faded trench coat spread on the ground, a pair of boots, a cap."""
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    K = lib.ramp(["#3a3428", "#544a38", "#6e6248", "#8a7c5c", "#a69872"])     # faded khaki
    rows = [
        "......kk........",
        "....kKKKKk......",
        "..skKKcKKKs.....",
        ".ssKKKcKKKKss...",
        "sssKKKbKKKKsss..",
        "..dKKKcKKKKd.ss.",
        "..dKKKbKKKKd....",
        "..ddKKcKKKdd....",
        "...ddddddd......",
    ]
    cmap = {"k": K[3], "K": K[2], "c": K[0], "b": MET[4], "s": K[2], "d": K[1]}
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != ".":
                s.px(1 + i, 3 + j, cmap[ch])
    for (x, y) in [(5, 4), (6, 4), (5, 5), (4, 6), (9, 5)]:
        s.px(x, y, K[4])                                      # lit collar + shoulder
    for x in range(4, 12):
        s.px(x, 8, K[1] if x != 7 else MET[3])                # belt + buckle
    BT = lib.ramp(["#1e1814", "#2e241c", "#46362a", "#5e4a38"])
    for (x0, y0) in [(8, 13), (12, 12)]:
        for (dx, dy, k) in [(0, -1, 3), (1, -1, 2), (0, 0, 2), (1, 0, 2), (2, 0, 1),
                            (0, 1, 1), (1, 1, 1), (2, 1, 0)]:
            s.px(x0 + dx, y0 + dy, BT[k])
    return _finish(cv, s, (8.5, 14.8, 6.5, 1.2))


def build(out):
    car_wreck(1).save("ruins/car_wreck_1.png")
    car_wreck(2).save("ruins/car_wreck_2.png")
    barricade().save("ruins/barricade.png")
    traffic_cone().save("ruins/traffic_cone.png")
    dumpster().save("ruins/dumpster.png")
    streetlamp_broken().save("ruins/streetlamp_broken.png")
    rubble_pile(1).save("ruins/rubble_pile_1.png")
    rubble_pile(2).save("ruins/rubble_pile_2.png")
    concrete_barrier().save("ruins/concrete_barrier.png")
    bus_wreck().save("ruins/bus_wreck.png")
    locker().save("ruins/locker.png")
    fridge().save("ruins/fridge.png")
    supply_crate().save("ruins/supply_crate.png")
    rad_barrel().save("ruins/rad_barrel.png")
    rad_puddle().save("ruins/rad_puddle.png")
    remains().save("ruins/remains.png")
