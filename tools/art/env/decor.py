"""Ground decor decals (art/env/decor/): non-interactive 16x16 transparent overlays drawn over
grass to break repetition. Flat on the ground (no contact shadow); details stay 1px inside the
tile so neighbouring decals never touch."""
from __future__ import annotations

import palette as P
from env import colors as X
from env import lib
from env.lib import Canvas, mix, rgba

SNOW = lib.ramp(X.SNOW_RAMP)
STONE = lib.ramp(P.STONE_RAMP)
DIRT = lib.ramp(P.DIRT_RAMP)


def _grass(season):
    return lib.ramp(P.season_grass_ramp(season))


def _flower(cv, x, y, petals, center, stem, kind="plus"):
    """A tiny flower: kind plus (5px cross), dot (2x2) or bell (3px)."""
    hi, mid, lo = petals
    if kind == "plus":
        cv.px(x, y - 1, hi); cv.px(x - 1, y, mid); cv.px(x + 1, y, lo); cv.px(x, y + 1, lo)
        cv.px(x, y, center)
        cv.px(x, y + 2, stem)
    elif kind == "dot":
        cv.px(x, y, hi); cv.px(x + 1, y, mid); cv.px(x, y + 1, mid); cv.px(x + 1, y + 1, lo)
        cv.px(x, y + 2, stem)
    elif kind == "bell":
        cv.px(x, y, hi); cv.px(x + 1, y, mid); cv.px(x, y + 1, lo)
        cv.px(x + 1, y + 1, stem); cv.px(x + 1, y + 2, stem)
    elif kind == "single":
        cv.px(x, y, hi); cv.px(x, y + 1, stem)


def _leafpair(cv, x, y, G):
    cv.px(x - 1, y, G[2]); cv.px(x + 1, y, G[1])


FLOWER_SETS = {
    "spring": [
        # (kind, petals, positions)
        ("plus", X.FLOWER_BLUE[::-1], [(4, 5), (10, 9), (6, 11)]),
        ("dot", X.FLOWER_YELLOW[::-1], [(3, 4), (9, 6), (11, 11), (5, 10)]),
        ("plus", X.FLOWER_WHITE[::-1], [(5, 4), (11, 6), (8, 11)]),
        ("bell", X.BLOSSOM_RAMP[2::-1][:3], [(4, 6), (10, 4), (7, 10), (12, 11)]),
    ],
    "summer": [
        ("dot", X.FLOWER_YELLOW[::-1], [(4, 5), (10, 8), (6, 11)]),
        ("plus", ["#ffdf7a", "#ec7a1c", "#c2410f"], [(5, 4), (11, 10)]),
        ("single", X.FLOWER_WHITE[::-1], [(3, 5), (6, 3), (9, 7), (12, 5), (5, 10), (10, 12)]),
        ("plus", X.FLOWER_RED[::-1], [(4, 6), (10, 10)]),
    ],
    "autumn": [
        ("plus", ["#b8a0d8", "#8a6ab0", "#5a4480"], [(4, 5), (10, 9), (7, 12)]),     # asters
        ("dot", X.FLOWER_RED[::-1], [(4, 4), (10, 7), (6, 11)]),
        ("bell", ["#ffdc78", "#e8b030", "#b8801a"], [(3, 6), (9, 4), (11, 10)]),
        ("single", X.FLOWER_WHITE[::-1], [(4, 4), (8, 6), (12, 4), (6, 10), (11, 11)]),
    ],
}


def flowers(season, i):
    cv = Canvas(16, 16)
    if season == "winter":
        return snow_clump(i)
    G = _grass(season)
    kind, petals, pos = FLOWER_SETS[season][i - 1]
    petals = [rgba(c) for c in petals]
    for (x, y) in pos:
        _leafpair(cv, x, y + 2 if kind != "bell" else y + 2, G)
        _flower(cv, x, y, petals, mix(petals[0], rgba(P.LAMPLIGHT), 0.5) if kind == "plus"
                else petals[1], G[1], kind)
    return cv


def snow_clump(i):
    """Winter 'flowers': small soft snow mounds with cool shading."""
    cv = Canvas(16, 16)
    layouts = {
        1: [(5, 6, 3, 2), (10, 10, 2, 1)],
        2: [(8, 8, 4, 2)],
        3: [(4, 10, 2, 1), (9, 5, 3, 2), (11, 11, 2, 1)],
        4: [(6, 7, 3, 2), (11, 6, 1, 1), (4, 12, 2, 1)],
    }[i]
    for (cx, cy, rx, ry) in layouts:
        for y in range(cy - ry, cy + 1):
            for x in range(cx - rx, cx + rx + 1):
                dx = (x - cx) / (rx + 0.5)
                dy = (y - cy) / (ry + 0.5)
                if dx * dx + dy * dy > 1.0:
                    continue
                c = SNOW[4] if dx < 0.2 and dy < -0.2 else SNOW[3]
                if dx > 0.45:
                    c = SNOW[2]
                cv.px(x, y, c)
        for x in range(cx - rx, cx + rx + 1):
            cv.px(x, cy + 1, SNOW[1] if x > cx - rx else SNOW[2])
    return cv


TUFTS = {
    1: [(4, 6), (10, 10)],
    2: [(7, 8)],
    3: [(3, 11), (9, 5), (12, 12)],
}


def tuft(season, i):
    cv = Canvas(16, 16)
    G = _grass(season)
    if season == "winter":
        tip = rgba(X.WINTER_GRASS_TIP)
        tipd = rgba(X.WINTER_GRASS_TIP_DARK)
        for (x, y) in TUFTS[i]:
            for (dx, h) in [(-2, 2), (-1, 3), (0, 4), (1, 2), (2, 3)]:
                for k in range(h):
                    cv.px(x + dx, y - k, tip if k == h - 1 else tipd)
            for dx in range(-3, 4):
                cv.px(x + dx, y + 1, SNOW[3] if abs(dx) < 2 else SNOW[2])
            cv.px(x - 1, y, SNOW[4]); cv.px(x + 1, y, SNOW[4])
        return cv
    dark, mid, lit = G[1], G[2], G[4]
    for (x, y) in TUFTS[i]:
        for (dx, dy, c) in [(-2, 0, mid), (-1, -1, dark), (-1, 0, dark), (0, -2, lit), (0, -1, mid),
                            (0, 0, dark), (1, -1, mid), (1, 0, dark), (2, -1, lit), (2, 0, mid)]:
            cv.px(x + dx, y + dy, c)
    return cv


def specks(i):
    cv = Canvas(16, 16)
    pts = {
        1: [(4, 5, STONE[4]), (5, 5, STONE[2]), (10, 9, STONE[3]), (6, 11, DIRT[2]),
            (12, 4, DIRT[1]), (11, 12, STONE[4]), (12, 12, STONE[2])],
        2: [(3, 9, DIRT[2]), (7, 4, STONE[4]), (8, 4, STONE[2]), (9, 10, DIRT[1]), (10, 10, DIRT[2]),
            (13, 7, STONE[3]), (5, 13, STONE[4])],
    }[i]
    for x, y, c in pts:
        cv.px(x, y, c)
    return cv


def leaves_autumn(i):
    cv = Canvas(16, 16)
    cols = [rgba(P.AUTUMN["rust"]), rgba(P.AUTUMN["amber"]), rgba(P.AUTUMN["gold"]),
            rgba(P.AUTUMN["ember"])]
    layouts = {
        1: [(3, 4, 0), (9, 6, 2), (6, 10, 1), (12, 12, 3)],
        2: [(4, 8, 1), (10, 3, 3), (11, 10, 0)],
    }[i]
    for (x, y, k) in layouts:
        c = cols[k]
        d = mix(c, lib.WARM, 0.35)
        # a 3px leaf with a darker vein tip
        cv.px(x, y, c); cv.px(x + 1, y, c); cv.px(x + 1, y + 1, d); cv.px(x, y - 1, mix(c, P.CREAM, 0.25))
    return cv


def build(out):
    for s in P.SEASONS:
        for i in (1, 2, 3, 4):
            flowers(s, i).save(f"decor/flowers_{s}_{i}.png")
        for i in (1, 2, 3):
            tuft(s, i).save(f"decor/tuft_{s}_{i}.png")
    for i in (1, 2):
        specks(i).save(f"decor/specks_{i}.png")
        leaves_autumn(i).save(f"decor/leaves_autumn_{i}.png")
