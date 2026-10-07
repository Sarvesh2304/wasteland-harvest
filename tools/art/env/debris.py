"""Rocks, salvage and debris (art/env/debris/). Bottom-centre anchored, soft contact shadows.

16x16 unless noted. The ground line is row h-2 (the contact shadow may use the last row).
"""
from __future__ import annotations

import math

import numpy as np

import palette as P
from env import colors as X
from env import lib, shapes
from env.foliage import Puff, canopy
from env.lib import Canvas, mix, rgba
from env.trees import SNOW, draw_branch, limb, snow_cap, wave

STONE = lib.ramp(P.STONE_RAMP)
MET = lib.ramp(P.METAL_RAMP)
RUST = lib.ramp(P.RUST_RAMP)
WOOD = lib.ramp(P.WOOD_RAMP)
BARK = lib.ramp(P.BARK_RAMP)
WARM = lib.WARM
GROUND = 14          # ground row of a 16x16 sprite


def _finish(cv, s, shadow):
    """Composite sprite layer `s` over a contact shadow (cx, cy, rx, ry)."""
    lib.outline(s, WARM, local=0.58)
    cv.shadow(*shadow)
    cv.blit(s, 0, 0)
    return cv


# ================================================================================================
# rocks
# ================================================================================================
def rock_small(i):
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    if i == 1:
        shapes.facet_rock(s, 8.0, GROUND, 11, 9, STONE, seed=22, n_facets=5)
        sh = (9.0, 14.8, 6.5, 1.3)
    elif i == 2:
        shapes.facet_rock(s, 8.0, GROUND, 12, 8, STONE, seed=23, n_facets=5)
        sh = (9.0, 14.8, 7.0, 1.3)
    else:
        shapes.facet_rock(s, 6.5, GROUND, 9, 8, STONE, seed=26, n_facets=4)
        small = Canvas(16, 16)
        shapes.facet_rock(small, 12.0, GROUND, 5, 4, STONE, seed=27, n_facets=3)
        for y in range(16):
            for x in range(16):
                if small.alpha(x, y) == 255 and s.alpha(x, y) == 0:
                    s.px(x, y, small.get(x, y))
        sh = (9.5, 14.8, 7.0, 1.3)
    return _finish(cv, s, sh)


def _lichen(s, pts):
    L = lib.ramp(["#5d7d3a", "#95ac49", "#b9c46a"])
    for x, y, k in pts:
        if s.alpha(x, y) == 255:
            s.px(x, y, L[k])


def rock_large(i):
    cv = Canvas(32, 32)
    s = Canvas(32, 32)
    if i == 1:
        shapes.facet_rock(s, 16.0, 30, 27, 22, STONE, seed=2, n_facets=7)
        _lichen(s, [(8, 13, 1), (9, 13, 2), (9, 14, 1), (10, 13, 1), (8, 14, 0), (14, 11, 1),
                    (15, 11, 2)])
        sh = (17.5, 30.6, 14.5, 1.6)
    else:
        # split boulder: two blocks with a dark cleft
        shapes.facet_rock(s, 11.0, 30, 18, 21, STONE, seed=7, n_facets=6)
        right = Canvas(32, 32)
        shapes.facet_rock(right, 23.0, 30, 15, 15, STONE, seed=3, n_facets=5)
        lib.outline(right, WARM, local=0.58)
        for y in range(32):
            for x in range(32):
                if right.alpha(x, y) == 255 and (s.alpha(x, y) == 0 or x > 19):
                    s.px(x, y, right.get(x, y))
        _lichen(s, [(6, 14, 1), (7, 14, 2), (7, 15, 1), (25, 19, 1), (26, 19, 1)])
        sh = (17.0, 30.6, 15, 1.6)
    return _finish(cv, s, sh)


# ================================================================================================
# scrap (the "ore" of this world)
# ================================================================================================
def _pipe_end(s, cx, cy, r, R):
    """Pipe seen end-on: ring with a dark bore."""
    m = s.ellipse_mask(cx, cy, r, r)
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        dx = (x + 0.5 - cx) / r
        dy = (y + 0.5 - cy) / r
        d = dx * dx + dy * dy
        if d < 0.3:
            s.px(x, y, R[0])
        else:
            s.px(x, y, R[4] if dx + dy < -0.3 else R[3] if dx + dy < 0.4 else R[2])


def _sheet(s, pts, R, ribs=True):
    """Corrugated sheet polygon with vertical ribs."""
    m = s.poly_mask(pts)
    ys, xs = np.nonzero(m)
    for y, x in zip(ys, xs):
        c = R[3] if x % 2 == 0 else R[2]
        if not ribs:
            c = R[3]
        s.px(x, y, c)
    # lit top edge
    for x in range(s.w):
        col = np.nonzero(m[:, x])[0]
        if len(col):
            s.px(x, col[0], R[4])


JUNK_RAMP = lib.ramp(["#2a1a12", "#47291b", "#653a24", "#7d5236", "#9a7050", "#b8937a"])


def _bolt(s, x, y):
    s.px(x, y, MET[5]); s.px(x + 1, y, MET[3]); s.px(x, y + 1, MET[2])


def scrap_small(i):
    """A scrap heap (the 'ore' node): a rock-like rusty mound with recognisable junk on it."""
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    if i == 1:
        shapes.facet_rock(s, 8.0, GROUND, 12, 8, lib.ramp(P.RUST_RAMP), seed=51, n_facets=5)
        # corrugated sheet edge poking out on top-left
        for k, (x, y) in enumerate([(3, 8), (4, 7), (5, 7), (6, 6), (7, 6)]):
            s.px(x, y, MET[4] if k % 2 == 0 else MET[3])
            s.px(x, y + 1, MET[2])
        _pipe_end(s, 11.5, 10.5, 2.4, MET)
        _bolt(s, 5, 11)
        sh = (9.0, 14.8, 7, 1.3)
    elif i == 2:
        shapes.facet_rock(s, 8.5, GROUND, 12, 8, JUNK_RAMP, seed=52, n_facets=5)
        hub = s.ellipse_mask(6.5, 10.0, 3.6, 3.4)
        ys, xs = np.nonzero(hub)
        for y, x in zip(ys, xs):
            dx = (x + 0.5 - 6.5) / 3.6
            dy = (y + 0.5 - 10.0) / 3.4
            d = dx * dx + dy * dy
            c = MET[4] if d > 0.55 and dx + dy < 0 else MET[2] if d > 0.55 else MET[3]
            if d < 0.15:
                c = MET[1]
            s.px(x, y, c)
        s.px(5, 9, MET[5])
        shapes.thick_line(s, [(9, 7), (13, 5)], 1, [RUST[4]])       # rebar
        s.px(13, 4, RUST[3])
        _bolt(s, 11, 10)
        sh = (9.0, 14.8, 7, 1.3)
    else:
        shapes.facet_rock(s, 8.0, GROUND, 11, 9, lib.ramp(P.METAL_RAMP), seed=53, n_facets=5)
        # rusty gear on the side
        g = s.ellipse_mask(10.5, 9.5, 2.9, 2.9)
        ys, xs = np.nonzero(g)
        for y, x in zip(ys, xs):
            s.px(x, y, RUST[3] if (x + y) % 2 else RUST[2])
        for (x, y) in [(10, 6), (13, 9), (10, 12), (8, 9)]:
            s.px(x, y, RUST[3])
        s.px(10, 9, RUST[0]); s.px(9, 8, RUST[4])
        # rust streaks on the heap
        for (x, y) in [(5, 10), (5, 11), (4, 12), (7, 12)]:
            s.px(x, y, RUST[2])
        shapes.thick_line(s, [(3, 8), (5, 5)], 1, [MET[4]])         # bent rod
        sh = (9.0, 14.8, 7, 1.3)
    return _finish(cv, s, sh)


def _drum_lying(s, x0, y0, length, r, R):
    """Oil drum lying on its side (axis along x): body then an end cap on the left."""
    for x in range(x0, x0 + length):
        for y in range(int(y0 - r), int(y0 + r) + 1):
            dy = (y + 0.5 - y0) / r
            if abs(dy) > 1:
                continue
            c = R[4] if dy < -0.45 else R[3] if dy < 0.1 else R[2] if dy < 0.6 else R[1]
            if (x - x0) in (2, length - 3):
                c = mix(c, R[0], 0.35)
            s.px(x, y, c)
    end = s.ellipse_mask(x0 + 0.5, y0 + 0.5, r * 0.5, r)
    ys, xs = np.nonzero(end)
    for y, x in zip(ys, xs):
        dy = (y + 0.5 - y0) / r
        s.px(x, y, R[3] if dy < 0 else R[2])
    s.px(x0, int(y0), R[1])


def scrap_large(i):
    cv = Canvas(32, 32)
    s = Canvas(32, 32)
    # dark junk mound base
    mound = s.poly_mask([(2, 30), (5, 22), (10, 18), (17, 16), (24, 18), (29, 23), (30, 30)])
    ys, xs = np.nonzero(mound)
    r = lib.rng(70 + i)
    for y, x in zip(ys, xs):
        k = r.random()
        c = RUST[1] if k < 0.35 else MET[1] if k < 0.6 else RUST[2] if k < 0.85 else MET[2]
        if y > 28:
            c = mix(c, RUST[0], 0.4)
        s.px(x, y, c)
    if i == 1:
        _sheet(s, [(4, 22), (14, 13), (19, 17), (10, 26)], RUST)                    # tilted sheet
        _drum_lying(s, 14, 24, 12, 4.2, lib.ramp(X.PAINT_GREEN + ["#8ca878"]))       # old drum
        for (x, y) in [(22, 21), (23, 21), (24, 25)]:
            s.px(x, y, RUST[3])
        _pipe_end(s, 7.5, 26.5, 2.6, MET)
        shapes.thick_line(s, [(19, 13), (28, 20)], 2, [MET[4], MET[2]])               # pipe
        _pipe_end(s, 19.0, 13.0, 1.8, MET)
    else:
        # car door with a window hole + hubcap + pipes
        door = [(6, 14), (20, 12), (22, 24), (8, 27)]
        dm = s.poly_mask(door)
        ys, xs = np.nonzero(dm)
        CR = lib.ramp(X.CAR_BLUE)
        for y, x in zip(ys, xs):
            c = CR[3] if y < 18 else CR[2]
            if (x * 3 + y * 5) % 13 == 0:
                c = RUST[3]
            s.px(x, y, c)
        win = s.poly_mask([(9, 15), (18, 14), (19, 18), (10, 20)])
        ys, xs = np.nonzero(win)
        for y, x in zip(ys, xs):
            s.px(x, y, CR[0] if y > 16 else mix(CR[0], CR[2], 0.5))
        s.px(17, 22, MET[5]); s.px(18, 22, MET[3])          # handle
        hub = s.ellipse_mask(24.5, 24.5, 4.0, 3.6)
        ys, xs = np.nonzero(hub)
        for y, x in zip(ys, xs):
            d = ((x + 0.5 - 24.5) / 4) ** 2 + ((y + 0.5 - 24.5) / 3.6) ** 2
            s.px(x, y, MET[4] if d > 0.6 and x < 25 else MET[2] if d > 0.6 else MET[3])
        s.px(24, 24, MET[0])
        shapes.thick_line(s, [(3, 25), (8, 20)], 2, [RUST[4], RUST[2]])
        _pipe_end(s, 27.0, 18.5, 2.2, MET)
    return _finish(cv, s, (17.0, 30.6, 14, 1.6))


# ================================================================================================
# weeds, tall grass
# ================================================================================================
WEED_RAMP = {
    "spring": ["#1f3a22", "#2e5530", "#3f7236", "#56913f", "#79ad4c", "#9cc65e"],
    "summer": ["#3e3a18", "#585222", "#76702a", "#948a34", "#b2a446", "#cdbf66"],
    "autumn": ["#3e200e", "#68340f", "#8e4c14", "#b4661c", "#d4892c", "#ecaa48"],
    "winter": ["#3a342c", "#544a3e", "#6e6252", "#8a7c68", "#a6987f", "#c2b69c"],
}


def _leaf(s, x0, y0, ang, ln, R, wide=2):
    """A pointed leaf from (x0, y0) along angle (0 = up)."""
    pts = []
    for i in range(ln):
        f = i / max(1, ln - 1)
        x = x0 + math.sin(ang) * i
        y = y0 - math.cos(ang) * i
        w = wide if f < 0.65 else 1
        for k in range(w):
            px = int(round(x)) + (k if math.cos(ang) > 0.5 else 0)
            py = int(round(y)) + (0 if math.cos(ang) > 0.5 else k)
            lit = (k == 0) == (math.sin(ang) <= 0)
            c = R[4] if lit else R[2]
            if f > 0.8:
                c = R[5] if lit else R[3]
            s.px(px, py, c)
            pts.append((px, py))
    return pts


def weeds(season, i):
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    R = lib.ramp(WEED_RAMP[season])
    r = lib.rng(200 + i * 13 + P.SEASONS.index(season))
    layouts = {
        1: [(-1.0, 6), (-0.45, 8), (0.05, 9), (0.5, 8), (1.0, 6), (-0.2, 6), (0.75, 5)],
        2: [(-0.9, 7), (-0.3, 9), (0.3, 7), (0.85, 7), (0.1, 5)],
        3: [(-1.1, 5), (-0.6, 7), (-0.1, 8), (0.4, 9), (0.9, 6), (1.3, 4)],
    }
    bx, by = 8, GROUND
    for ang, ln in layouts[i]:
        _leaf(s, bx + (0 if abs(ang) < 0.5 else (-1 if ang < 0 else 1)), by, ang, ln, R)
    # dark heart at the base
    for x in range(6, 11):
        s.px(x, by, R[1])
    s.px(7, by - 1, R[2]); s.px(8, by - 1, R[1]); s.px(9, by - 1, R[2])
    if season == "summer" and i != 2:
        s.px(8, by - 9, lib.rgba(X.STRAW[3])); s.px(9, by - 9, lib.rgba(X.STRAW[2]))
    if season == "spring" and i == 3:
        Fy = lib.ramp(X.FLOWER_YELLOW)
        s.px(10, by - 9, Fy[2]); s.px(11, by - 9, Fy[1]); s.px(10, by - 8, Fy[1])
    lib.outline(s, mix(R[0], WARM, 0.4), local=0.5)
    if season == "winter":
        # frost on leaf tips
        for y in range(16):
            for x in range(16):
                if s.alpha(x, y) == 255 and s.alpha(x, y - 1) < 255 and (x + y) % 2 == 0:
                    s.px(x, y, SNOW[3])
    cv.shadow(9.0, 14.8, 5.5, 1.2)
    cv.blit(s, 0, 0)
    return cv


def tallgrass(season, i):
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    R = lib.ramp(WEED_RAMP[season])
    if season == "spring":
        R = lib.ramp(P.GRASS_SPRING_RAMP)
    blades = {
        1: [(2, -0.35, 9), (4, -0.2, 12), (5, 0.1, 13), (7, -0.05, 14), (8, 0.25, 12),
            (10, 0.15, 13), (11, 0.4, 10), (13, 0.5, 8), (6, -0.5, 8), (9, -0.15, 10)],
        2: [(3, -0.45, 8), (4, -0.1, 11), (6, 0.05, 13), (7, -0.25, 12), (9, 0.2, 14),
            (10, 0.0, 11), (12, 0.35, 10), (8, 0.45, 9)],
    }[i]
    for k, (bx, ang, ln) in enumerate(blades):
        x, y = float(bx), float(GROUND)
        a = ang
        for j in range(ln):
            f = j / ln
            c = R[2] if k % 3 == 0 else R[3]
            if f > 0.55:
                c = R[4] if k % 2 else R[3]
            if f > 0.85:
                c = R[5] if k % 2 else R[4]
            s.px(int(round(x)), int(round(y)), c)
            if j < 3:
                s.px(int(round(x)) + 1, int(round(y)), R[2])
            x += math.sin(a)
            y -= math.cos(a)
            a += ang * 0.12
        # seed heads in summer/autumn
        if season in ("summer", "autumn") and k % 3 == 1:
            hx, hy = int(round(x)), int(round(y))
            st = lib.ramp(X.STRAW)
            s.px(hx, hy, st[3]); s.px(hx, hy + 1, st[2]); s.px(hx + 1, hy + 1, st[1])
    for x in range(4, 13):
        s.px(x, GROUND, R[1])
    lib.outline(s, mix(R[0], WARM, 0.4), local=0.5)
    if season == "winter":
        for y in range(16):
            for x in range(16):
                if s.alpha(x, y) == 255 and s.alpha(x, y - 1) < 255:
                    s.px(x, y, SNOW[4] if (x % 2) else SNOW[3])
    cv.shadow(9.0, 14.8, 6, 1.2)
    cv.blit(s, 0, 0)
    return cv


# ================================================================================================
# small debris
# ================================================================================================
def twig(i):
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    R = BARK
    if i == 1:
        shapes.thick_line(s, [(2, 12), (8, 11), (14, 12)], 2, [R[3], R[1]])
        shapes.thick_line(s, [(8, 11), (11, 8)], 1, [R[3]])
        s.px(12, 7, R[2]); s.px(4, 11, R[4])
    else:
        shapes.thick_line(s, [(3, 10), (12, 13)], 2, [R[3], R[1]])
        shapes.thick_line(s, [(6, 11), (5, 8)], 1, [R[3]])
        shapes.thick_line(s, [(9, 12), (12, 10)], 1, [R[2]])
        s.px(3, 10, WOOD[4]); s.px(3, 11, WOOD[3])          # snapped end
    return _finish(cv, s, (8.5, 14.6, 6.5, 1.1))


def pebble(i):
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    parts = [(6.0, GROUND, 5, 4, 41), (10.5, GROUND, 4, 3, 42), (8.5, GROUND - 3, 3, 3, 43)] \
        if i == 1 else [(8.0, GROUND, 6, 4, 44), (12.0, GROUND, 3, 3, 45), (4.0, GROUND, 3, 2, 46)]
    for cx, base, w, h, sd in parts:
        layer = Canvas(16, 16)
        shapes.facet_rock(layer, cx, base, w, h, STONE, seed=sd, n_facets=3)
        lib.outline(layer, WARM, local=0.58)
        s.blit(layer, 0, 0)
    cv.shadow(8.5, 14.8, 6, 1.0)
    cv.blit(s, 0, 0)
    return cv


def junk(i):
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    if i == 1:     # old tyre lying flat (the hole shows the ground)
        RB = lib.ramp(X.RUBBER_RAMP)
        outer, inner = shapes.ring(s, 8.0, 10.5, 6.6, 4.0, 2.6, RB)
        # tread notches + side wall
        for x in range(2, 15):
            y = 13
            if s.alpha(x, y) == 255 and x % 2 == 0:
                s.px(x, y, RB[0])
        for x in range(3, 13):
            if s.alpha(x, 14) == 255:
                s.px(x, 14, RB[0])
        # a weed poking through the hole
        G = lib.ramp(P.GRASS_SPRING_RAMP)
        s.px(8, 10, G[3]); s.px(8, 9, G[4]); s.px(9, 9, G[3]); s.px(7, 8, G[4])
        lib.outline(s, WARM, local=0.58)
        # keep the hole open (only the weed inside)
        cv.shadow(9.0, 14.6, 7, 1.3)
        cv.blit(s, 0, 0)
        return cv
    if i == 2:     # rusted tin cans: two standing, one tipped over
        CN = lib.ramp(X.CAN_RAMP + ["#d8c4a4"])
        RED = lib.ramp(X.SIGN_RED)

        def can(x0, top, h):
            # rim + open top
            s.px(x0, top, CN[3]); s.px(x0 + 1, top, CN[4]); s.px(x0 + 2, top, CN[2])
            for y in range(top + 1, top + h):
                s.px(x0, y, CN[3]); s.px(x0 + 1, y, CN[2]); s.px(x0 + 2, y, CN[1])
            # faded label band
            s.px(x0, top + 2, RED[2]); s.px(x0 + 1, top + 2, RED[1]); s.px(x0 + 2, top + 2, RED[0])
            s.px(x0 + 1, top + 1, CN[0])
        can(3, 8, 6)
        can(7, 9, 5)
        # tipped can lying on its side, open end facing us
        for x in range(10, 14):
            s.px(x, 12, CN[3] if x < 13 else CN[2])
            s.px(x, 13, CN[2] if x < 13 else CN[1])
            s.px(x, 14, CN[1])
        s.px(11, 13, RED[1]); s.px(12, 13, RED[0])
        s.px(13, 12, CN[0]); s.px(13, 13, CN[0])
        for (x, y) in [(3, 11), (8, 13), (4, 13)]:
            s.px(x, y, RUST[3])
        return _finish(cv, s, (9.0, 14.8, 7, 1.2))
    # broken glass bottles
    GG = lib.ramp(X.GLASS_GREEN)
    GB = lib.ramp(X.GLASS_BROWN)
    # standing green bottle, neck broken
    for y in range(7, GROUND + 1):
        for x in range(4, 7):
            c = GG[2] if x == 4 else GG[1] if x == 5 else GG[0]
            s.px(x, y, c)
    s.px(5, 6, GG[1]); s.px(5, 5, GG[2]); s.px(4, 8, GG[3]); s.px(4, 9, GG[3])
    # brown bottle lying down
    for x in range(8, 14):
        s.px(x, 12, GB[2] if x < 12 else GB[1])
        s.px(x, 13, GB[1] if x < 12 else GB[0])
    s.px(14, 12, GB[1]); s.px(15, 12, GB[2])
    s.px(9, 12, GB[3])
    # shards glinting on the ground
    for (x, y, c) in [(2, 14, GG[3]), (7, 14, GG[2]), (12, 10, GB[3]), (13, 14, GG[3])]:
        s.px(x, y, c)
    return _finish(cv, s, (8.5, 14.8, 6.5, 1.1))


def log_large():
    cv = Canvas(32, 16)
    s = Canvas(32, 16)
    R = BARK
    y0, r = 9.5, 4.6
    for x in range(4, 30):
        for y in range(int(y0 - r), int(y0 + r) + 1):
            dy = (y + 0.5 - y0) / r
            if abs(dy) > 1:
                continue
            c = R[4] if dy < -0.55 else R[3] if dy < -0.05 else R[2] if dy < 0.55 else R[1]
            if (x * 5 + y * 7) % 11 == 0:
                c = mix(c, R[0], 0.4)
            s.px(x, y, c)
    # bark ridges along the log
    for x in range(6, 29, 4):
        s.px(x, int(y0) - 1, R[2]); s.px(x + 1, int(y0) - 1, R[2])
    # cut end (left) with rings
    end = s.ellipse_mask(4.5, y0 + 0.5, 2.6, r)
    ys, xs = np.nonzero(end)
    for y, x in zip(ys, xs):
        dy = (y + 0.5 - y0) / r
        dx = (x + 0.5 - 4.5) / 2.6
        d = dx * dx + dy * dy
        c = WOOD[5] if d < 0.25 else WOOD[4] if d < 0.6 else WOOD[3]
        if 0.3 < d < 0.42:
            c = WOOD[3]
        s.px(x, y, c)
    s.px(4, int(y0), WOOD[2])
    # branch stub + moss
    shapes.thick_line(s, [(20, 6), (22, 2)], 2, [R[3], R[1]])
    G = lib.ramp(["#3f6a2e", "#5d8a3a", "#85a84a"])
    for (x, y, k) in [(12, 5, 1), (13, 5, 2), (14, 5, 1), (13, 6, 0), (25, 6, 1), (26, 6, 0)]:
        s.px(x, y, G[k])
    return _finish(cv, s, (17.5, 14.6, 14, 1.4))


def stump_large():
    cv = Canvas(32, 32)
    s = Canvas(32, 32)
    R = BARK
    cx = 16.0
    hx = 10
    ytop, ybase = 16, 29
    for y in range(ytop, ybase + 1):
        for x in range(int(cx - hx), int(cx + hx)):
            t = (x + 0.5 - (cx - hx)) / (2 * hx)
            c = R[3] if t < 0.2 else R[2] if t < 0.6 else R[1]
            if (x * 3 + y * 5) % 9 == 0 and 0.1 < t < 0.95:
                c = R[1] if t < 0.6 else R[0]
            if t < 0.08 and y % 3 == 0:
                c = R[4]
            s.px(x, y, c)
    # roots spreading
    for pts, w in [([(6, 29), (2, 30)], 2), ([(9, 28), (5, 25)], 2), ([(24, 29), (29, 30)], 2),
                   ([(23, 27), (27, 25)], 2), ([(14, 29), (13, 31)], 1)]:
        shapes.thick_line(s, pts, w, [R[3], R[1]])
    # big cut face with rings
    fy, ry = ytop, 4.6
    for y in range(int(fy - ry) - 1, int(fy + ry) + 1):
        for x in range(int(cx - hx), int(cx + hx)):
            dx = (x + 0.5 - cx) / hx
            dy = (y + 0.5 - fy) / ry
            d = math.sqrt(dx * dx + dy * dy)
            if d > 1.0:
                continue
            if d > 0.86:
                c = R[3] if dx < 0.2 else R[2]
            elif any(abs(d - rr) < 0.06 for rr in (0.25, 0.45, 0.65)):
                c = WOOD[3]
            else:
                c = WOOD[5] if dx < -0.1 else WOOD[4]
            s.px(x, y, c)
    # a wedge crack and a cluster of little mushrooms
    for (x, y) in [(18, 15), (19, 16), (20, 16), (21, 17)]:
        s.px(x, y, WOOD[2])
    MU = lib.ramp(["#5a3a28", "#a0583a", "#d48a5a", "#f0c49a"])
    for (x, y, k) in [(7, 24, 2), (8, 24, 3), (7, 25, 1), (9, 26, 2), (10, 26, 3), (9, 27, 1)]:
        s.px(x, y, MU[k])
    return _finish(cv, s, (17.5, 30.6, 14, 1.6))


# ================================================================================================
def build(out):
    for i in (1, 2, 3):
        rock_small(i).save(f"debris/rock_small_{i}.png")
        scrap_small(i).save(f"debris/scrap_small_{i}.png")
        junk(i).save(f"debris/junk_{i}.png")
        for s in P.SEASONS:
            weeds(s, i).save(f"debris/weeds_{s}_{i}.png")
    for i in (1, 2):
        rock_large(i).save(f"debris/rock_large_{i}.png")
        scrap_large(i).save(f"debris/scrap_large_{i}.png")
        twig(i).save(f"debris/twig_{i}.png")
        pebble(i).save(f"debris/pebble_{i}.png")
        for s in P.SEASONS:
            tallgrass(s, i).save(f"debris/tallgrass_{s}_{i}.png")
    log_large().save("debris/log_large.png")
    stump_large().save("debris/stump_large.png")
