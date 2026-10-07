"""Ground: seasonal grass base tiles, dual-grid Wang overlays, animated water.

Outputs (art/env/terrain/):
  grass_<season>.png        128x16  8 seamless 16x16 variants
  <name>.png                64x64   Wang overlay sheet (see env/wang.py for the layout)
  <name>_full.png           64x16   4 variants of the fully covered tile (mask 15)
  water.png                 256x64  4 animation frames, each a full 64x64 Wang sheet
  water_full.png            64x16   4 animation frames of the fully covered water tile
"""
from __future__ import annotations

import numpy as np

import palette as P
from env import colors as X
from env import lib, wang
from env.lib import Canvas, mix, rgba

T = 16
A = wang.APRON


# ================================================================================================
# helpers
# ================================================================================================
class Feature:
    """A small detail (pebble, crack, tuft) that is drawn whole or not at all."""

    def __init__(self, pixels, margin=2):
        self.pixels = [(int(x), int(y), rgba(c)) for x, y, c in pixels]
        self.margin = margin


def _free(occ, pts, pad=1):
    for x, y in pts:
        for yy in range(y - pad, y + pad + 1):
            for xx in range(x - pad, x + pad + 1):
                if 0 <= xx < T and 0 <= yy < T and occ[yy, xx]:
                    return False
    return True


def _mark(occ, pts):
    for x, y in pts:
        if 0 <= x < T and 0 <= y < T:
            occ[y, x] = True


def _inside(pts):
    return all(0 <= x < T and 0 <= y < T for x, y in pts)


# ================================================================================================
# grass base
# ================================================================================================
GRASS = {
    #           base, blade (dark), tip (light), deep (detail tuft), extra
    "spring": dict(r=P.GRASS_SPRING_RAMP, base=3, dark=2, light=4, deep=1),
    "summer": dict(r=P.GRASS_SUMMER_RAMP, base=3, dark=2, light=4, deep=1),
    "autumn": dict(r=P.GRASS_AUTUMN_RAMP, base=3, dark=2, light=4, deep=1),
    "winter": dict(r=P.GRASS_WINTER_RAMP, base=4, dark=3, light=5, deep=2),
}

# blade marks (dx, dy, role) role: d = dark, l = light tip
BLADES = [
    [(0, 0, "d"), (0, 1, "d")],                                   # single blade
    [(0, 0, "d"), (2, 0, "d"), (1, 1, "d")],                      # little V tuft
    [(0, 0, "l"), (0, 1, "d"), (0, 2, "d")],                      # lit blade
    [(0, 0, "d"), (1, 1, "d")],                                   # leaning blade
    [(1, 0, "l"), (0, 1, "d"), (1, 1, "d"), (2, 1, "d")],         # small clump with tip
    [(0, 0, "d"), (1, 0, "l")],                                   # flat blade
]


def grass_tiles(season):
    g = GRASS[season]
    R = lib.ramp(g["r"])
    base, dark, light, deep = R[g["base"]], R[g["dark"]], R[g["light"]], R[g["deep"]]
    tiles = []
    for v in range(8):
        r = lib.rng(1000 + v * 17 + {"spring": 0, "summer": 1, "autumn": 2, "winter": 3}[season])
        cv = Canvas(T, T)
        cv.rect(0, 0, T, T, base)
        occ = np.zeros((T, T), bool)
        if season == "winter":
            _winter_marks(cv, r, occ, v)
        else:
            n = r.choice([5, 6, 6, 7])
            tries = 0
            while n > 0 and tries < 400:
                tries += 1
                shape = r.choice(BLADES)
                ox, oy = r.randrange(T), r.randrange(T)
                pts = [(ox + dx, oy + dy) for dx, dy, _ in shape]
                if not _inside(pts) or not _free(occ, pts, 1):
                    continue
                for (x, y), (_, _, role) in zip(pts, shape):
                    cv.px(x, y, dark if role == "d" else light)
                _mark(occ, pts)
                n -= 1
            # a few lone light flecks (sun on blade tips)
            for _ in range(r.choice([1, 2, 2])):
                for _t in range(50):
                    x, y = r.randrange(T), r.randrange(T)
                    if _free(occ, [(x, y)], 1):
                        cv.px(x, y, light)
                        _mark(occ, [(x, y)])
                        break
        # details on 3 of the 8 variants
        if v == 2:
            _detail_pebble(cv, occ, season, r)
        elif v == 5:
            if season == "winter":
                _detail_tips(cv, occ, r, big=True)
            else:
                _detail_clover(cv, occ, season, r)
        elif v == 7:
            _detail_tuft(cv, occ, R, g, r)
        tiles.append(cv)
    return tiles


def _place(occ, r, w, h, margin=2):
    for _ in range(200):
        x = r.randrange(margin, T - w - margin + 1)
        y = r.randrange(margin, T - h - margin + 1)
        pts = [(x + i, y + j) for i in range(w) for j in range(h)]
        if _free(occ, pts, 1):
            _mark(occ, pts)
            return x, y
    return None


def _detail_pebble(cv, occ, season, r):
    S = lib.ramp(P.STONE_RAMP)
    p = _place(occ, r, 3, 3)
    if not p:
        return
    x, y = p
    if season == "winter":
        snow = lib.ramp(X.SNOW_RAMP)
        cv.px(x, y + 1, S[4]); cv.px(x + 1, y + 1, S[3]); cv.px(x + 2, y + 1, S[2])
        cv.px(x, y, snow[4]); cv.px(x + 1, y, snow[3])
        cv.px(x, y + 2, snow[2]); cv.px(x + 1, y + 2, snow[1]); cv.px(x + 2, y + 2, snow[2])
        return
    G = lib.ramp(P.season_grass_ramp(season))
    cv.px(x, y + 1, S[4]); cv.px(x + 1, y + 1, S[3]); cv.px(x + 1, y, S[4])
    cv.px(x + 2, y + 1, S[2])
    cv.px(x, y + 2, G[1]); cv.px(x + 1, y + 2, G[1]); cv.px(x + 2, y + 2, G[2])


def _detail_clover(cv, occ, season, r):
    G = lib.ramp(P.season_grass_ramp(season))
    p = _place(occ, r, 3, 3)
    if not p:
        return
    x, y = p
    if season == "autumn":
        # a fallen rust leaf
        cv.px(x, y + 1, P.AUTUMN["rust"]); cv.px(x + 1, y + 1, P.AUTUMN["amber"])
        cv.px(x + 1, y, P.AUTUMN["amber"]); cv.px(x + 2, y + 1, P.AUTUMN["ember"])
        cv.px(x + 1, y + 2, P.AUTUMN["ember"])
        return
    if season == "summer":
        # a dry seed head
        cv.px(x + 1, y, X.STRAW[3]); cv.px(x, y + 1, X.STRAW[2]); cv.px(x + 1, y + 1, X.STRAW[2])
        cv.px(x + 2, y + 1, X.STRAW[1]); cv.px(x + 1, y + 2, G[1])
        return
    # spring clover: three lit leaves around a dark heart
    cv.px(x + 1, y, G[5]); cv.px(x, y + 1, G[4]); cv.px(x + 2, y + 1, G[4])
    cv.px(x + 1, y + 1, G[1]); cv.px(x + 1, y + 2, G[2])


def _detail_tuft(cv, occ, R, g, r):
    p = _place(occ, r, 4, 3)
    if not p:
        return
    x, y = p
    deep = R[g["deep"]]
    dark = R[g["dark"]]
    for (dx, dy, c) in [(0, 0, deep), (3, 0, deep), (1, 1, deep), (2, 1, deep), (1, 0, dark),
                        (0, 2, dark), (1, 2, deep), (2, 2, deep), (3, 2, dark)]:
        cv.px(x + dx, y + dy, c)


def _winter_marks(cv, r, occ, v):
    W = lib.ramp(P.GRASS_WINTER_RAMP)
    shadow = rgba(X.SNOW_SHADOW)
    # soft drift ripples: short horizontal arcs, shadow under a sparkle
    n = r.choice([3, 4, 4])
    tries = 0
    while n > 0 and tries < 300:
        tries += 1
        ln = r.choice([2, 3, 3, 4])
        x, y = r.randrange(T - ln + 1), r.randrange(T - 1)
        pts = [(x + i, y) for i in range(ln)]
        if not _free(occ, pts, 1):
            continue
        for px, py in pts:
            cv.px(px, py, shadow)
        if r.random() < 0.6:
            cv.px(x + r.randrange(ln), y - 1 if y > 0 else y + 1, W[5])
        _mark(occ, pts)
        n -= 1
    if v in (1, 3, 6):
        _detail_tips(cv, occ, r, big=False)


def _detail_tips(cv, occ, r, big):
    tip = rgba(X.WINTER_GRASS_TIP)
    tipd = rgba(X.WINTER_GRASS_TIP_DARK)
    shapes = [[(0, 0, tip), (0, 1, tipd)], [(0, 0, tip), (2, 0, tip), (1, 1, tipd), (0, 1, tipd)]]
    if big:
        shapes = [[(0, 0, tip), (2, 0, tip), (3, 1, tip), (0, 1, tipd), (1, 1, tipd), (2, 1, tipd),
                   (1, 0, tipd)]]
    for _ in range(80):
        s = r.choice(shapes)
        x, y = r.randrange(1, T - 4), r.randrange(1, T - 3)
        pts = [(x + dx, y + dy) for dx, dy, _ in s]
        if _free(occ, pts, 1):
            for dx, dy, c in s:
                cv.px(x + dx, y + dy, c)
            _mark(occ, pts)
            # snow pile at its foot
            cv.px(x - 1, y + 2, X.SNOW_RAMP[2]) if x > 0 else None
            return


# ================================================================================================
# Wang overlay terrains
# ================================================================================================
class Terrain:
    name = "terrain"
    seed = 0
    feature_margin = 2

    def ground(self, v):
        raise NotImplementedError

    def features(self, v):
        return []

    def edge(self, x, y, d, col):
        return col

    # ------------------------------------------------------------------------------------------
    def tile(self, mask, v=0, frame=0):
        self.frame = frame
        cvm = wang.cov(mask)
        d = wang.distances(cvm)
        g = self.ground(v)
        out = Canvas(T, T)
        cov = cvm[A:A + T, A:A + T]
        for y in range(T):
            for x in range(T):
                if cov[y, x]:
                    out.a[y, x] = g[y, x]
        # discrete features: keep whole, away from edges
        mind = np.minimum(np.minimum(d["n"], d["s"]), np.minimum(d["w"], d["e"]))
        for f in self.features(v):
            ok = True
            for x, y, _ in f.pixels:
                if not (0 <= x < T and 0 <= y < T) or not cov[y, x] or mind[y, x] <= f.margin:
                    ok = False
                    break
            if ok:
                for x, y, c in f.pixels:
                    out.px(x, y, c)
        for y in range(T):
            for x in range(T):
                if not cov[y, x]:
                    continue
                dd = {k: d[k][y, x] for k in d}
                out.a[y, x] = self.edge(x, y, dd, tuple(int(t) for t in out.a[y, x]))
        return out

    def sheet(self, frame=0):
        tiles = [self.tile(m, 0, frame) for m in range(16)]
        return lib.grid_sheet(tiles, 4)

    def full(self, frame=None):
        if frame is None:
            return lib.hstrip([self.tile(15, v) for v in range(4)])
        return self.tile(15, 0, frame)


def _ground(color):
    g = np.zeros((T, T, 4), np.uint8)
    g[:, :] = rgba(color)
    return g


# ------------------------------------------------------------------------------------------------
class Dirt(Terrain):
    """Packed bare earth / footpath: slightly sunken, shadowed top edge, light bottom lip."""
    name = "dirt"
    R = lib.ramp(P.DIRT_RAMP)

    def ground(self, v):
        R = self.R
        g = _ground(R[3])
        r = lib.rng(31)
        occ = np.zeros((T, T), bool)
        placed = 0
        while placed < 7:
            x, y = r.randrange(T - 1), r.randrange(T)
            if not _free(occ, [(x, y), (x + 1, y)], 1):
                continue
            k = r.random()
            if k < 0.45:
                g[y, x] = R[2]
            elif k < 0.75:
                g[y, x] = R[2]
                g[y, x + 1] = R[2]
            else:
                g[y, x] = R[4]
            _mark(occ, [(x, y), (x + 1, y)])
            placed += 1
        return g

    def features(self, v):
        R = self.R
        r = lib.rng(400 + v)
        out = []
        for _ in range([1, 2, 1, 3][v]):
            x, y = r.randrange(1, T - 3), r.randrange(1, T - 3)
            k = r.random()
            if k < 0.5:   # small pebble with its shadow
                out.append(Feature([(x, y, R[5]), (x + 1, y, R[4]), (x, y + 1, R[2]),
                                    (x + 1, y + 1, R[2])]))
            elif k < 0.8:  # dry crack
                out.append(Feature([(x, y, R[2]), (x + 1, y + 1, R[2]), (x + 2, y + 1, R[2])]))
            else:          # clod
                out.append(Feature([(x, y, R[4]), (x + 1, y, R[4]), (x, y + 1, R[2]),
                                    (x + 1, y + 1, R[2]), (x + 2, y + 1, R[2])]))
        return out

    def edge(self, x, y, d, col):
        R = self.R
        if d["n"] == 1:
            return R[1]
        if d["w"] == 1 or d["nw"]:
            return R[2]
        if d["s"] == 1:
            return R[4]
        if d["e"] == 1 or d["ne"]:
            return mix(col, R[2], 0.5)
        return col


# ------------------------------------------------------------------------------------------------
# Tilled soil: two chunky furrow rows per tile (period 8). Rows from the top of each furrow:
#   lit back slope, crest (with clods), body x3, shaded front slope, groove, shade.
FURROW = [4, 4, 3, 3, 3, 2, 1, 2]
FURROW_WAVE_A = [0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0]
FURROW_WAVE_B = [1, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1]


class Soil(Terrain):
    """Tilled farmland: chunky horizontal furrow rows, raised bed with a dark front face."""
    name = "soil"
    R = lib.ramp(P.SOIL_RAMP)
    wet = False

    def ground(self, v):
        R = self.R
        g = _ground(R[3])
        r = lib.rng(77)
        for x in range(T):
            for y in range(T):
                wave = FURROW_WAVE_A[x] if y < 8 else FURROW_WAVE_B[x]
                p = (y - wave) % 8
                g[y, x] = R[FURROW[p]]
        # crest clods / crumbs (shared by all variants so tiles stay seamless)
        for band in (0, 8):
            wave = FURROW_WAVE_A if band == 0 else FURROW_WAVE_B
            x = r.randrange(3)
            while x < T:
                y = (band + 1 + wave[x]) % T
                g[y, x] = R[5]
                if x + 1 < T and r.random() < 0.6:
                    g[y, x + 1] = R[5] if not self.wet else R[4]
                x += r.choice([4, 5, 6])
            # body clods: a lit lump over its own shadow
            x = r.randrange(2, 6)
            while x < T - 1:
                y = (band + 3 + wave[x]) % T
                g[y, x] = R[4]
                g[(y + 1) % T, x] = R[2]
                x += r.choice([5, 6, 7])
            # crumbs breaking the groove
            x = r.randrange(4)
            while x < T:
                y = (band + 6 + wave[x]) % T
                g[y, x] = R[2]
                x += r.choice([3, 4, 5])
        if self.wet:
            sheen = rgba(X.WET_SHEEN)
            for (x, y) in [(3, 1), (4, 1), (11, 9), (7, 12)]:
                wave = FURROW_WAVE_A if y < 8 else FURROW_WAVE_B
                g[(y + wave[x]) % T, x] = sheen
        return g

    def features(self, v):
        R = self.R
        r = lib.rng(500 + v)
        out = []
        for _ in range([0, 1, 2, 1][v]):
            x = r.randrange(1, T - 3)
            band = r.choice([0, 8])
            wave = FURROW_WAVE_A if band == 0 else FURROW_WAVE_B
            y = band + 2 + wave[x]
            out.append(Feature([(x, y, R[5]), (x + 1, y, R[4]), (x, y + 1, R[2]),
                                (x + 1, y + 1, R[2])], margin=1))
        return out

    def edge(self, x, y, d, col):
        R = self.R
        if d["s"] == 1:
            return R[0]
        if d["s"] == 2:
            return R[1]
        if d["n"] == 1:
            return R[4]
        if d["w"] == 1 or d["nw"]:
            return R[4]
        if d["e"] == 1 or d["ne"]:
            return R[1]
        if d["e"] == 2:
            return mix(col, R[1], 0.5)
        return col


class SoilWet(Soil):
    """Watered farmland: same furrows (same geometry) darker, with a slight wet sheen."""
    name = "soil_wet"
    R = lib.ramp(P.SOIL_WET_RAMP)
    wet = True


# ------------------------------------------------------------------------------------------------
def _torus_voronoi(seeds):
    lab = np.zeros((T, T), int)
    for y in range(T):
        for x in range(T):
            best = None
            for i, (sx, sy, wgt) in enumerate(seeds):
                dx = min(abs(x - sx), T - abs(x - sx))
                dy = min(abs(y - sy), T - abs(y - sy))
                dd = (dx * dx + dy * dy * 1.35) * wgt
                if best is None or dd < best[0]:
                    best = (dd, i)
            lab[y, x] = best[1]
    return lab


class Cobble(Terrain):
    """Town stone path: rounded light cobbles set in packed earth; calm contrast."""
    name = "cobble"
    S = lib.ramp(P.STONE_RAMP)
    D = lib.ramp(P.DIRT_RAMP)
    SEEDS = [(2, 2, 1.0), (10, 3, 1.0), (6, 8, 1.0), (14, 9, 1.0), (2, 13, 1.0), (10, 14, 1.0)]

    def _layout(self):
        if not hasattr(self, "_lab"):
            self._lab = _torus_voronoi(self.SEEDS)
        return self._lab

    def gap(self):
        return mix(self.S[2], self.D[2], 0.35)

    def ground(self, v):
        S = self.S
        lab = self._layout()
        g = _ground(S[4])
        gap = self.gap()
        tones = [S[4], mix(S[4], S[3], 0.3), mix(S[4], S[5], 0.2), mix(S[4], self.D[4], 0.25),
                 S[4], mix(S[4], S[3], 0.15)]
        for y in range(T):
            for x in range(T):
                me = lab[y, x]
                if me != lab[y, (x + 1) % T] or me != lab[(y + 1) % T, x]:
                    g[y, x] = gap
                    continue
                c = tones[me]
                up = lab[(y - 1) % T, x] != me
                lf = lab[y, (x - 1) % T] != me
                dn2 = lab[(y + 2) % T, x] != me
                rt2 = lab[y, (x + 2) % T] != me
                if up:
                    c = S[5]
                elif lf:
                    c = mix(c, S[5], 0.5)
                elif dn2:
                    c = S[3]
                elif rt2:
                    c = mix(c, S[3], 0.6)
                g[y, x] = c
        # round the stones: stone pixels touching gaps on two sides become gap / shade
        g2 = g.copy()
        for y in range(T):
            for x in range(T):
                if tuple(g[y, x]) == gap:
                    continue
                n = sum(tuple(g[(y + dy) % T, (x + dx) % T]) == gap
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if n >= 2:
                    g2[y, x] = gap
        return g2

    def features(self, v):
        S = self.S
        out = []
        if v == 1:
            out.append(Feature([(6, 9, S[3]), (7, 10, S[3])], margin=1))          # hairline crack
        if v == 2:
            g = rgba(P.SPRING["moss"])
            out.append(Feature([(9, 7, g), (10, 7, mix(g, self.gap(), 0.4))], margin=1))
        if v == 3:
            out.append(Feature([(3, 4, S[5]), (4, 4, S[5])], margin=1))           # worn shine
        return out

    def edge(self, x, y, d, col):
        S, D = self.S, self.D
        if d["s"] == 1 or d["e"] == 1 or d["se"]:
            return mix(S[1], D[1], 0.5)
        if d["n"] == 1 or d["w"] == 1 or d["nw"] or d["ne"] or d["sw"]:
            return self.gap()
        return col


# ------------------------------------------------------------------------------------------------
class Gravel(Terrain):
    """Placed gravel path: granular lit pebbles with tiny shadows on a grit bed."""
    name = "gravel"
    R = lib.ramp(X.GRAVEL_RAMP)
    D = lib.ramp(P.DIRT_RAMP)

    def ground(self, v):
        R, D = self.R, self.D
        g = _ground(R[2])
        r = lib.rng(61)
        occ = np.zeros((T, T), bool)
        shapes = [
            [(0, 0, 4), (1, 0, 3), (1, 1, 1)],
            [(0, 0, 4), (1, 1, 1)],
            [(0, 0, 5), (1, 0, 4), (0, 1, 3), (1, 1, 1)],
            [(0, 0, 3), (1, 1, 1)],
            [(0, 0, 4), (0, 1, 1)],
        ]
        placed = 0
        tries = 0
        while placed < 24 and tries < 2000:
            tries += 1
            sh = r.choice(shapes)
            ox, oy = r.randrange(T), r.randrange(T)
            pts = [((ox + dx) % T, (oy + dy) % T) for dx, dy, _ in sh]
            if any(occ[py, px] for px, py in pts):
                continue
            warm = r.random() < 0.3
            for (px, py), (_, _, k) in zip(pts, sh):
                c = R[k]
                if warm and k >= 3:
                    c = mix(c, D[k], 0.45)
                g[py, px] = c
            for px, py in pts:
                occ[py, px] = True
            placed += 1
        return g

    def edge(self, x, y, d, col):
        R = self.R
        if d["n"] == 1 or d["nw"]:
            return R[0]
        if d["w"] == 1:
            return R[1]
        if d["s"] == 1:
            return R[4]
        if d["e"] == 1 or d["ne"]:
            return R[1]
        return col


# ------------------------------------------------------------------------------------------------
class Sand(Terrain):
    """Riverbank sand: pale, soft wind ripples, a few shell/pebble specks."""
    name = "sand"
    R = lib.ramp(X.SAND_RAMP)

    def ground(self, v):
        R = self.R
        g = _ground(R[3])
        ripples = [(1, 2, 4), (9, 4, 3), (4, 9, 4), (12, 11, 3), (7, 14, 3)]
        for x0, y0, ln in ripples:
            for i in range(ln):
                g[y0 % T, (x0 + i) % T] = R[2]
            g[(y0 - 1) % T, (x0 + 1) % T] = R[4]
            if ln > 3:
                g[(y0 - 1) % T, (x0 + 2) % T] = R[4]
        for (x, y) in [(14, 1), (2, 6), (10, 8), (6, 12)]:
            g[y, x] = R[2]
        return g

    def features(self, v):
        R = self.R
        out = []
        if v == 1:
            out.append(Feature([(5, 4, R[5]), (6, 4, R[4]), (5, 5, R[1])]))     # shell
        if v == 2:
            S = lib.ramp(P.STONE_RAMP)
            out.append(Feature([(9, 9, S[4]), (10, 9, S[3]), (9, 10, R[1]), (10, 10, R[1])]))
        if v == 3:
            w = lib.ramp(P.WOOD_RAMP)
            out.append(Feature([(3, 11, w[3]), (4, 11, w[3]), (5, 12, w[2]), (6, 12, w[2]),
                                (4, 12, R[1])]))                                  # driftwood bit
        return out

    def edge(self, x, y, d, col):
        R = self.R
        if d["n"] == 1:
            return R[2]
        if d["w"] == 1 or d["nw"]:
            return mix(R[2], R[3], 0.5)
        if d["s"] == 1:
            return R[4]
        if d["e"] == 1:
            return mix(R[2], R[3], 0.5)
        return col


# ------------------------------------------------------------------------------------------------
class Asphalt(Terrain):
    """Ruins road: dark, fine aggregate, cracks, worn paint flecks; crumbling raised edge."""
    name = "asphalt"
    R = lib.ramp(X.ASPHALT_RAMP)

    def ground(self, v):
        R = self.R
        g = _ground(R[3])
        r = lib.rng(33)
        for y in range(T):
            for x in range(T):
                k = r.random()
                if k < 0.07:
                    g[y, x] = R[4]
                elif k < 0.13:
                    g[y, x] = R[2]
        return g

    def features(self, v):
        R = self.R
        y1 = rgba(X.PAINT_FADED_YELLOW)
        cr = rgba(X.PAINT_FADED_CREAM)
        out = []
        if v == 0:
            out.append(Feature([(4, 5, R[1]), (5, 5, R[1]), (6, 6, R[1]), (7, 6, R[1]),
                                (8, 7, R[1]), (6, 7, R[4]), (8, 8, R[4])]))
        if v == 1:   # a few worn paint flecks
            out.append(Feature([(6, 7, mix(y1, R[3], 0.35)), (7, 7, mix(y1, R[3], 0.55)),
                                (9, 8, mix(y1, R[3], 0.5))], margin=1))
        if v == 2:   # shallow patch repair
            out.append(Feature([(6, 6, R[2]), (7, 6, R[2]), (8, 6, R[2]), (5, 7, R[2]),
                                (6, 7, R[2]), (7, 7, R[1]), (8, 7, R[2]), (9, 7, R[2]),
                                (6, 8, R[2]), (7, 8, R[2]), (8, 8, R[4])]))
        if v == 3:   # branching crack + cream fleck
            out.append(Feature([(3, 3, R[1]), (4, 4, R[1]), (4, 5, R[1]), (5, 6, R[1]),
                                (6, 6, R[1]), (7, 7, R[1]), (4, 6, R[4]), (6, 7, R[4]),
                                (6, 4, R[1]), (7, 3, R[1])]))
            out.append(Feature([(11, 11, mix(cr, R[3], 0.4)), (12, 12, mix(cr, R[3], 0.6))]))
        return out

    def edge(self, x, y, d, col):
        R = self.R
        if d["s"] == 1:
            return R[0]
        if d["s"] == 2:
            return R[1]
        if d["n"] == 1:
            return R[5]
        if d["w"] == 1 or d["nw"]:
            return R[4]
        if d["e"] == 1 or d["ne"]:
            return R[1]
        return col


# ------------------------------------------------------------------------------------------------
class Concrete(Terrain):
    """Ruins concrete: one bevelled slab per tile (joints on the tile borders), cracks, stains."""
    name = "concrete"
    R = lib.ramp(X.CONCRETE_RAMP)

    def ground(self, v):
        R = self.R
        g = _ground(R[3])
        r = lib.rng(44)
        for y in range(T):
            for x in range(T):
                if r.random() < 0.06:
                    g[y, x] = R[4] if r.random() < 0.5 else R[2]
        for i in range(T):
            g[0, i] = R[1]          # joint
            g[i, 0] = R[1]
            g[1, i] = R[4] if i > 0 else R[1]   # lit slab edge
            g[i, 1] = R[4] if i > 0 else R[1]
            g[T - 1, i] = R[2] if i > 0 else R[1]
            g[i, T - 1] = R[2] if i > 0 else R[1]
        g[1, 1] = R[5]
        return g

    def features(self, v):
        R = self.R
        ash = lib.ramp([P.ASH_BROWN])[0]
        out = []
        if v == 1:   # hairline crack
            pts = [(4, 5), (5, 6), (6, 6), (7, 7), (8, 8), (9, 8)]
            out.append(Feature([(x, y, mix(R[1], R[3], 0.3)) for x, y in pts], margin=1))
        if v == 2:   # faint ash stain
            out.append(Feature([(7, 9, mix(ash, R[3], 0.45)), (8, 9, mix(ash, R[3], 0.6)),
                                (6, 10, mix(ash, R[3], 0.55)), (7, 10, mix(ash, R[3], 0.4)),
                                (8, 10, mix(ash, R[3], 0.55))]))
        if v == 3:   # small spall
            out.append(Feature([(10, 10, R[2]), (11, 10, R[1]), (10, 11, R[1]), (11, 11, R[2]),
                                (9, 10, R[4])], margin=1))
        return out

    def edge(self, x, y, d, col):
        R = self.R
        if d["s"] == 1:
            return R[0]
        if d["s"] == 2:
            return R[1]
        if d["n"] == 1:
            return R[5]
        if d["w"] == 1 or d["nw"]:
            return R[4]
        if d["e"] == 1 or d["ne"]:
            return R[1]
        return col


# ------------------------------------------------------------------------------------------------
class RubbleGround(Terrain):
    """Ruins debris ground: dusty grit with broken concrete chunks, brick and rust bits."""
    name = "rubble_ground"
    R = lib.ramp(X.RUBBLE_BASE_RAMP)
    C = lib.ramp(X.CONCRETE_RAMP)

    def _chunk(self, x, y, w, h, kind):
        C, R = self.C, self.R
        px = []
        if kind == "conc":
            for j in range(h):
                for i in range(w):
                    if (i, j) in ((0, 0), (w - 1, h - 1)):
                        continue
                    c = C[3]
                    if j == 0 or i == 0:
                        c = C[4]
                    if j == h - 1 or i == w - 1:
                        c = C[1]
                    px.append((x + i, y + j, c))
            px.append((x + 1, y + h, R[0]))
            px.append((x + w - 1, y + h, R[0]))
        elif kind == "brick":
            b = lib.ramp([mix(P.RUST_DULL, P.ASH_BROWN, 0.35), mix(P.RUST_DULL, P.ASH_BROWN, 0.1)])
            px += [(x, y, b[1]), (x + 1, y, b[1]), (x, y + 1, b[0]), (x + 1, y + 1, b[0]),
                   (x + 2, y + 1, R[0])]
        elif kind == "rebar":
            b = lib.ramp(P.RUST_RAMP)
            px += [(x, y, b[3]), (x + 1, y, b[2]), (x + 2, y + 1, b[2]), (x + 3, y + 1, b[1])]
        return px

    def ground(self, v):
        R = self.R
        g = _ground(R[2])
        r = lib.rng(55)
        for y in range(T):
            for x in range(T):
                k = r.random()
                if k < 0.08:
                    g[y, x] = R[3]
                elif k < 0.15:
                    g[y, x] = R[1]
        for x, y, c in self._chunk(2, 2, 4, 3, "conc") + self._chunk(9, 9, 3, 2, "conc") + \
                self._chunk(11, 3, 0, 0, "brick") + self._chunk(3, 11, 0, 0, "rebar"):
            if 0 <= x < T and 0 <= y < T:
                g[y, x] = c
        return g

    def features(self, v):
        out = []
        layouts = [
            [],
            [(6, 6, 4, 3, "conc")],
            [(5, 9, 3, 3, "conc"), (12, 6, 0, 0, "rebar")],
            [(7, 5, 5, 3, "conc"), (4, 12, 0, 0, "brick")],
        ]
        for x, y, w, h, k in layouts[v]:
            out.append(Feature(self._chunk(x, y, w, h, k), margin=1))
        return out

    def edge(self, x, y, d, col):
        R = self.R
        if d["n"] == 1 or d["nw"]:
            return R[1]
        if d["w"] == 1:
            return mix(R[1], R[2], 0.5)
        if d["s"] == 1:
            return R[0]
        if d["e"] == 1 or d["ne"]:
            return R[1]
        return col


# ------------------------------------------------------------------------------------------------
class Water(Terrain):
    """Animated water: drifting ripple glints; shore = dark wet-earth lip + light foam line."""
    name = "water"
    W = lib.ramp(P.WATER_RAMP)
    E = lib.ramp(P.SOIL_WET_RAMP)
    # ripple sites: (x, y, length, phase)
    SITES = [(1, 2, 4, 0), (9, 3, 3, 2), (5, 7, 4, 1), (12, 9, 4, 3), (2, 12, 3, 2),
             (9, 14, 3, 0), (14, 6, 2, 1)]
    GLINTS = [(7, 1, 1), (13, 12, 3), (3, 9, 0), (11, 6, 2)]

    def ground(self, v):
        W = self.W
        f = self.frame
        g = _ground(W[2])
        # faint darker depth streaks (static)
        for (x, y, ln) in [(4, 4, 5), (11, 12, 4), (0, 9, 3)]:
            for i in range(ln):
                g[y, (x + i) % T] = mix(W[2], W[1], 0.55)
        for (x, y, ln, ph) in self.SITES:
            st = (f + ph) % 4
            if st == 0:
                continue
            if st == 1:
                seg = [(x + 1, W[3]), (x + 2, W[3])]
            elif st == 2:
                seg = [(x + i, W[3]) for i in range(ln)] + [(x + 1, W[4])]
                if ln >= 4:
                    seg.append((x + 2, W[4]))
            else:
                seg = [(x + 2, W[3]), (x + 3, mix(W[3], W[2], 0.5))]
            for xx, c in seg:
                g[y % T, xx % T] = c
        for (x, y, ph) in self.GLINTS:
            if (f + ph) % 4 == 0:
                g[y, x] = W[6]
                g[y, (x + 1) % T] = W[5]
        return g

    def edge(self, x, y, d, col):
        W, E = self.W, self.E
        f = self.frame
        lip = E[2]
        foam = W[5]
        bright = rgba(P.FOAM)
        sparkle = ((x + y * 3 + f * 2) % 7) == 0
        if d["n"] == 1:
            return E[3]
        if d["n"] == 2:
            return E[1]
        if d["s"] == 1 or d["w"] == 1 or d["e"] == 1:
            return lip
        if d["nw"] or d["ne"] or d["sw"] or d["se"]:
            return lip
        if d["n"] == 3 or d["s"] == 2 or d["w"] == 2 or d["e"] == 2:
            return bright if sparkle else foam
        if d["n"] == 4 or d["s"] == 3 or d["w"] == 3 or d["e"] == 3:
            return W[4] if (x + y + f) % 3 else W[3]
        return col


TERRAINS = [Dirt(), Soil(), SoilWet(), Cobble(), Gravel(), Sand(), Asphalt(), Concrete(),
            RubbleGround()]


def water_sheets():
    w = Water()
    sheets = [w.sheet(frame=f) for f in range(4)]
    fulls = [w.full(frame=f) for f in range(4)]
    return lib.hstrip(sheets), lib.hstrip(fulls)


def build(out):
    for season in P.SEASONS:
        lib.hstrip(grass_tiles(season)).save(f"terrain/grass_{season}.png")
    for t in TERRAINS:
        t.frame = 0
        t.sheet().save(f"terrain/{t.name}.png")
        t.full().save(f"terrain/{t.name}_full.png")
    sheet, full = water_sheets()
    sheet.save("terrain/water.png")
    full.save("terrain/water_full.png")
