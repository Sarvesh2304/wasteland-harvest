"""Dual-grid Wang corner geometry shared by every terrain overlay.

Sheet layout (docs/ART_STYLE.md §4): 64x64 = 4x4 tiles, tile at column c, row r is corner mask
m = r*4 + c, with m = NW*8 + NE*4 + SW*2 + SE*1 (bit set = that corner is the terrain).

Geometry rules that make *any* combination seamless:
  * the boundary between two corners is the tile's half-way line (x=8 / y=8), displaced by a
    small organic wobble that is pinned to 0 within PIN px of the tile border, so every edge
    crosses a tile border at exactly the half-way line;
  * corners are rounded (convex caps cut, concave pockets filleted) with the SAME radius, so
    the cut of one terrain is exactly the fillet of its complement (no grass gaps between two
    different overlay terrains meeting at a cell boundary);
  * the wobble and radius are shared by ALL terrains and do not depend on the mask, so coverage
    is monotonic in the corner bits (soil_wet with a subset of soil's bits never leaks outside
    soil) and two terrains always meet without gaps.
Coverage is computed on the tile plus an APRON of neighbouring pixels (predicted exactly, see
`verify()`), so rim/lip decoration on tile borders agrees with the neighbouring tile.
"""
from __future__ import annotations

import random

import numpy as np

T = 16
HALF = 8
APRON = 3
PIN = 3          # wobble forced to 0 in rows/cols [0, PIN) and [T-PIN, T)
RADIUS = 8.0     # corner rounding (convex cut == concave fillet)

# Vertical boundary displacement per row (+1 = boundary one pixel further east) and horizontal
# boundary displacement per column (+1 = one pixel further south). Hand-tuned after comparing
# several candidates in mock-ups: one gentle 3px bump per half-line pair reads organic without
# turning into a regular crenellation.
WOBBLE_X = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0]
WOBBLE_Y = [0, 0, 0, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

NW, NE, SW, SE = 8, 4, 2, 1


def bits(mask):
    return bool(mask & NW), bool(mask & NE), bool(mask & SW), bool(mask & SE)


def coverage(mask, apron=APRON, radius=RADIUS, wob_x=WOBBLE_X, wob_y=WOBBLE_Y):
    """Boolean (T+2a, T+2a) coverage; index [y + a, x + a] for tile pixel (x, y)."""
    nw, ne, sw, se = bits(mask)
    quad = {(0, 0): nw, (1, 0): ne, (0, 1): sw, (1, 1): se}
    n = T + 2 * apron
    cov = np.zeros((n, n), dtype=bool)
    for gy in range(n):
        y = gy - apron
        for gx in range(n):
            x = gx - apron
            inside = 0 <= x < T and 0 <= y < T
            bx = HALF + (wob_x[y] if 0 <= y < T else 0)
            by = HALF + (wob_y[x] if 0 <= x < T else 0)
            east = 1 if x >= bx else 0
            south = 1 if y >= by else 0
            here = quad[(east, south)]
            c = here
            if inside and radius > 0:
                a = (x + 0.5 - bx) if east else (bx - x - 0.5)
                d = (y + 0.5 - by) if south else (by - y - 0.5)
                qh = quad[(1 - east, south)]
                qv = quad[(east, 1 - south)]
                qd = quad[(1 - east, 1 - south)]
                corner = a < radius and d < radius and \
                    (radius - a) ** 2 + (radius - d) ** 2 > radius ** 2
                if corner:
                    if here and not qh and not qv:
                        c = False                       # round a convex cap
                    elif not here and qh and qv and qd:
                        c = True                        # fillet a concave pocket
            cov[gy, gx] = c
    # symmetric clean-up of 1px artefacts where wobble meets a rounded corner: lone protrusions
    # are removed and 1px notches filled (complement-symmetric, interior only)
    lo, hi = apron + PIN, apron + T - PIN
    src = cov.copy()
    for gy in range(lo, hi):
        for gx in range(lo, hi):
            n = int(src[gy - 1, gx]) + int(src[gy + 1, gx]) + int(src[gy, gx - 1]) + int(src[gy, gx + 1])
            if src[gy, gx] and n <= 1:
                cov[gy, gx] = False
            elif not src[gy, gx] and n >= 3:
                cov[gy, gx] = True
    return cov


_CACHE = {}


def cov(mask):
    if mask not in _CACHE:
        _CACHE[mask] = coverage(mask)
    return _CACHE[mask]


def distances(cv, apron=APRON, maxd=APRON + 1):
    """Per covered tile pixel: distance (1..maxd) to the first uncovered pixel N/S/W/E.

    Returns dict of four (T, T) int arrays; 99 = farther than `maxd` / uncovered pixel.
    """
    out = {}
    for name, (dx, dy) in {"n": (0, -1), "s": (0, 1), "w": (-1, 0), "e": (1, 0)}.items():
        d = np.full((T, T), 99, dtype=int)
        for y in range(T):
            for x in range(T):
                if not cv[y + apron, x + apron]:
                    continue
                for k in range(1, maxd + 1):
                    gx = x + apron + dx * k
                    gy = y + apron + dy * k
                    if not (0 <= gx < cv.shape[1] and 0 <= gy < cv.shape[0]):
                        break
                    if not cv[gy, gx]:
                        d[y, x] = k
                        break
        out[name] = d
    # diagonal neighbours (for inner-corner rims)
    for name, (dx, dy) in {"nw": (-1, -1), "ne": (1, -1), "sw": (-1, 1), "se": (1, 1)}.items():
        d = np.zeros((T, T), dtype=bool)
        for y in range(T):
            for x in range(T):
                if cv[y + apron, x + apron] and not cv[y + apron + dy, x + apron + dx]:
                    d[y, x] = True
        out[name] = d
    return out


def verify(trials=300, seed=7):
    """Assert every tile's apron prediction equals its real neighbours' coverage."""
    r = random.Random(seed)
    n = 9
    for _ in range(trials):
        corners = [[r.random() < 0.5 for _ in range(n + 1)] for _ in range(n + 1)]
        world = np.zeros((n * T, n * T), dtype=bool)
        masks = {}
        for ty in range(n):
            for tx in range(n):
                m = (corners[ty][tx] * NW) | (corners[ty][tx + 1] * NE) | \
                    (corners[ty + 1][tx] * SW) | (corners[ty + 1][tx + 1] * SE)
                masks[(tx, ty)] = m
                world[ty * T:(ty + 1) * T, tx * T:(tx + 1) * T] = \
                    cov(m)[APRON:APRON + T, APRON:APRON + T]
        for ty in range(1, n - 1):
            for tx in range(1, n - 1):
                c = cov(masks[(tx, ty)])
                ref = world[ty * T - APRON:(ty + 1) * T + APRON, tx * T - APRON:(tx + 1) * T + APRON]
                if not np.array_equal(c, ref):
                    raise AssertionError(f"wang apron mismatch for mask {masks[(tx, ty)]}")
    # complementary masks must tile the plane exactly (no gaps, no overlaps)
    for m in range(16):
        if m in (6, 9):
            continue  # checkerboard diagonals: both sides are separate rounded caps by design
        a = cov(m)[APRON:APRON + T, APRON:APRON + T]
        b = cov(15 - m)[APRON:APRON + T, APRON:APRON + T]
        if (a & b).any() or not (a | b).all():
            raise AssertionError(f"wang complement mismatch for mask {m}")
    # monotonic in bits
    for m in range(16):
        for s in range(16):
            if s & m == s:
                if (cov(s) & ~cov(m)).any():
                    raise AssertionError(f"wang not monotonic: {s} vs {m}")
    return True
