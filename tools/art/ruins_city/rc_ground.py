"""Ruins base ground (art/env/terrain/ruins_ground.png): 128x16 = 8 seamless 16x16 variants,
same format as terrain/grass_<season>.png. The ruins zone paints it under everything (the open
ground between sidewalks and roads), so it stays low-contrast: dusty ash-brown dirt, a few
pebbles, faint cracks, the odd tuft of dead grass. The base is one flat colour and every
multi-pixel detail sits wholly inside its tile (1 px margin), so any variant tiles against any
other. Variants 2 and 5 are the busier ones (weighted rarer by the renderer, like grass)."""
from __future__ import annotations

import numpy as np

from env import lib
from env.lib import Canvas, mix
from ruins_city.rc_common import CON, DRY, GROUND, RUST, BRICK

T = 16


def _free(occ, pts, pad=1):
    for x, y in pts:
        if not (1 <= x < T - 1 and 1 <= y < T - 1):
            return False
        for yy in range(y - pad, y + pad + 1):
            for xx in range(x - pad, x + pad + 1):
                if 0 <= xx < T and 0 <= yy < T and occ[yy, xx]:
                    return False
    return True


def _put(cv, occ, r, shape, tries=200):
    """shape: list of (dx, dy, colour). Placed wholly inside the tile, away from other marks."""
    w = max(p[0] for p in shape) + 1
    h = max(p[1] for p in shape) + 1
    for _ in range(tries):
        x0 = r.randrange(1, T - w)
        y0 = r.randrange(1, T - h)
        pts = [(x0 + dx, y0 + dy) for dx, dy, _ in shape]
        if _free(occ, pts):
            for (x, y), (_, _, c) in zip(pts, shape):
                cv.px(x, y, c)
                occ[y, x] = True
            return True
    return False


G = GROUND
LIT = mix(CON[4], G[4], 0.25)          # sunlit top of a pebble
PEBBLE = [(0, 0, LIT), (1, 0, mix(CON[3], G[3], 0.2)), (1, 1, G[0]), (0, 1, G[1]), (2, 1, G[1])]
PEBBLE_S = [(0, 0, mix(CON[4], G[4], 0.4)), (0, 1, G[0]), (1, 1, G[1])]
GRIT = [(0, 0, G[5]), (2, 1, G[1]), (1, 2, G[5]), (3, 2, G[1])]
CRACK = [(0, 0, G[0]), (1, 1, G[0]), (2, 1, G[0]), (3, 2, G[0]), (4, 3, G[1]), (2, 2, G[5]),
         (4, 2, G[4])]
CRACK2 = [(0, 2, G[0]), (1, 1, G[0]), (2, 1, G[0]), (3, 0, G[1]), (1, 2, G[5]), (4, 0, G[1])]
GRASS = [(0, 2, DRY[1]), (1, 1, DRY[2]), (1, 2, DRY[0]), (2, 0, DRY[3]), (2, 1, DRY[1]),
         (3, 1, DRY[2]), (3, 2, DRY[0]), (4, 2, DRY[1])]
GRASS_S = [(0, 1, DRY[1]), (1, 0, DRY[3]), (1, 1, DRY[0]), (2, 1, DRY[2])]
CHIP_BRICK = [(0, 0, mix(BRICK[4], G[3], 0.15)), (1, 0, mix(BRICK[3], G[3], 0.15)), (1, 1, G[0]),
              (0, 1, G[1])]
RUST_FLECK = [(0, 0, mix(RUST[3], G[3], 0.3)), (1, 0, mix(RUST[2], G[3], 0.4))]
STONE = [(1, 0, LIT), (2, 0, mix(CON[4], G[3], 0.2)), (0, 1, mix(CON[3], G[3], 0.2)),
         (1, 1, mix(CON[3], G[3], 0.25)), (2, 1, mix(CON[2], G[3], 0.25)), (3, 1, G[0]),
         (1, 2, G[0]), (2, 2, G[0]), (0, 2, G[1])]

LAYOUTS = {
    0: [PEBBLE_S, GRIT],
    1: [CRACK, PEBBLE_S],
    2: [STONE, PEBBLE, CRACK2, GRASS_S, RUST_FLECK],          # busier
    3: [GRIT, GRASS_S],
    4: [PEBBLE, RUST_FLECK],
    5: [GRASS, CRACK, PEBBLE_S, CHIP_BRICK, GRIT],            # busier
    6: [CRACK2, PEBBLE_S],
    7: [CHIP_BRICK, GRIT],
}


def tile(v):
    r = lib.rng(4100 + v * 31)
    cv = Canvas(T, T)
    cv.rect(0, 0, T, T, G[3])
    # faint dust mottling: lone pixels only (no structure that a tile edge could cut)
    for y in range(T):
        for x in range(T):
            k = r.random()
            if k < 0.045:
                cv.px(x, y, G[2])
            elif k < 0.075:
                cv.px(x, y, G[4])
    occ = np.zeros((T, T), bool)
    for shape in LAYOUTS[v]:
        _put(cv, occ, r, shape)
    return cv


def build():
    return {"terrain/ruins_ground.png": lib.hstrip([tile(v) for v in range(8)])}
