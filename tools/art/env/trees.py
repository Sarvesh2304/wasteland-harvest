"""Trees, stumps, saplings and bushes (art/env/trees/).

All are upright sprites anchored bottom-centre: the trunk base sits on the bottom row(s) of the
image, centred horizontally; a soft contact shadow is offset to the bottom-right.
"""
from __future__ import annotations

import math

import numpy as np

import palette as P
from env import colors as X
from env import lib
from env.foliage import Puff, canopy, scatter_blossoms
from env.lib import Canvas, mix, rgba

BARK = lib.ramp(P.BARK_RAMP)
WOOD = lib.ramp(P.WOOD_RAMP)
SNOW = lib.ramp(X.SNOW_RAMP)
WARM = lib.WARM

SEASON_CANOPY = {
    "spring": X.CANOPY_SPRING,
    "summer": X.CANOPY_SUMMER,
    "autumn": X.CANOPY_AUTUMN,
}


def _dark(c, t=0.62):
    return mix(c, WARM, t)


# ================================================================================================
# trunks & branches
# ================================================================================================
def draw_trunk(cv, cx, top, base, half, flare=2, ramp=None, seed=0, roots=True):
    """Vertical trunk centred on cx (float, e.g. 24.0), from `top` to `base` (ground row).

    half = half-width in px (trunk spans cx-half .. cx+half-1).
    """
    R = ramp or BARK
    r = lib.rng(seed)
    x0 = int(round(cx - half))
    x1 = int(round(cx + half - 1))
    for y in range(top, base + 1):
        extra = 0
        if y >= base - 2:
            extra = flare if y == base else max(0, flare - 1)
        for x in range(x0 - extra, x1 + extra + 1):
            t = (x - (x0 - extra)) / max(1, (x1 + extra) - (x0 - extra))
            if t < 0.2:
                c = R[3] if x > x0 - extra else R[4]
            elif t < 0.5:
                c = R[3] if (x + y) % 5 else R[2]
            elif t < 0.8:
                c = R[2]
            else:
                c = R[1]
            cv.px(x, y, c)
    # bark furrows: short vertical dark streaks
    for _ in range(max(2, (base - top) // 4)):
        x = r.randrange(x0 + 1, x1)
        y = r.randrange(top, max(top + 1, base - 3))
        ln = r.randrange(2, 5)
        for k in range(ln):
            if cv.alpha(x, y + k) == 255:
                cv.px(x, y + k, R[1] if x < (x0 + x1) / 2 else R[0])
    if roots:
        cv.px(x0 - flare - 1, base, R[2])
        cv.px(x0 - flare - 2, base, R[1])
        cv.px(x1 + flare + 1, base, R[1])
        cv.px(x1 + flare + 2, base, R[0])


def draw_branch(cv, x, y, ang, length, thick, ramp, depth, rng, out=None, min_len=3):
    """Recursive branch; ang in radians from straight up (negative = left)."""
    R = ramp
    pts = []
    fx, fy = float(x), float(y)
    for i in range(int(length)):
        fx += math.sin(ang) * 1.0
        fy -= math.cos(ang) * 1.0
        ang += rng.uniform(-0.08, 0.08)
        pts.append((fx, fy))
        t = max(1, int(round(thick * (1 - 0.5 * i / max(1, length)))))
        for ox in range(t):
            px = int(round(fx)) + ox - t // 2
            py = int(round(fy))
            c = R[3] if ox == 0 and t > 1 else (R[2] if ox < t - 1 else R[1])
            if t == 1:
                c = R[2]
            cv.px(px, py, c)
            if out is not None:
                out.append((px, py))
    if depth <= 0 or length < min_len:
        return pts
    ex, ey = pts[-1] if pts else (x, y)
    n = 2 if rng.random() < 0.8 else 3
    for k in range(n):
        spread = rng.uniform(0.35, 0.7)
        na = ang + (spread if k == 0 else -spread if k == 1 else rng.uniform(-0.2, 0.2))
        draw_branch(cv, ex, ey, na, length * rng.uniform(0.55, 0.75), max(1, thick - 1), R,
                    depth - 1, rng, out, min_len)
    return pts


def snow_on_top(cv, color_top, color_under=None, prob=1.0, seed=0, max_y=None, thick=1):
    """Lay snow on every upward-facing opaque pixel (pixel above transparent)."""
    r = lib.rng(seed)
    a = cv.a.copy()
    op = a[:, :, 3] == 255
    h, w = op.shape
    for y in range(1, h):
        if max_y is not None and y > max_y:
            break
        for x in range(w):
            if op[y, x] and not op[y - 1, x] and r.random() < prob:
                cv.px(x, y - 1, color_top)
                if thick > 1 and y - 2 >= 0 and not op[y - 2, x] and r.random() < 0.5:
                    cv.px(x, y - 2, color_top)
                if color_under is not None:
                    cv.px(x, y, color_under)


def snow_cap(cv, depth_at, x0=0, x1=None, top_limit=None, seed=0, outline=True):
    """Pile snow on the top surface of a sprite.

    depth_at(x) -> snow thickness in px for column x (0 = none). The snow follows the existing
    silhouette's top edge, is lit on the left, cool blue-grey toward the right, gets a darker
    under-lip, and its exposed top is outlined in cool grey (snow's own dark shade).
    """
    S = SNOW
    x1 = cv.w - 1 if x1 is None else x1
    op = cv.a[:, :, 3] == 255
    tops = {}
    for x in range(x0, x1 + 1):
        ys = np.nonzero(op[:, x])[0]
        if len(ys) == 0:
            continue
        y0 = int(ys[0])
        if top_limit is not None and y0 > top_limit:
            continue
        tops[x] = y0
    if not tops:
        return
    xs = sorted(tops)
    mid = (xs[0] + xs[-1]) / 2.0
    half = max(1.0, (xs[-1] - xs[0]) / 2.0)
    for x in xs:
        d = depth_at(x)
        if d <= 0:
            continue
        y0 = tops[x]
        rel = (x - mid) / half
        for k in range(d):
            y = y0 + k
            if not op[y, x] if y < cv.h else True:
                break
            c = S[4] if rel < 0.1 else S[3]
            if k == d - 1 and d > 1:
                c = S[2] if rel < 0.3 else S[1]
            if k == 0 and rel > 0.55:
                c = S[3]
            cv.px(x, y, c)
        if outline:
            if y0 - 1 >= 0 and cv.alpha(x, y0 - 1) < 255:
                cv.px(x, y0 - 1, S[0] if rel > 0.3 else S[1])
    # snow's exposed side outline
    if outline:
        for x in xs:
            for side in (-1, 1):
                nx = x + side
                if nx in tops or not (0 <= nx < cv.w):
                    continue
                y0 = tops[x]
                if cv.alpha(nx, y0) < 255:
                    cv.px(nx, y0, S[1] if side < 0 else S[0])


def wave(x, pattern):
    return pattern[x % len(pattern)]


# ================================================================================================
# ashwood (48x64 deciduous)
# ================================================================================================
ASH_PUFFS = [
    (24, 12, 10.0), (14, 17, 8.5), (34, 17, 8.5),
    (9, 27, 7.2), (39, 27, 7.2), (24, 24, 11.5),
    (14, 36, 8.5), (34, 36, 8.5), (24, 38, 8.5),
]


def _ash_puffs(ramp_for):
    out = []
    for i, (x, y, r) in enumerate(ASH_PUFFS):
        out.append(Puff(x, y, r, ramp=ramp_for(i), bumps=int(r * 1.2), phase=i * 1.7, amp=0.09))
    return out


def ashwood(season):
    W, H = 48, 64
    cv = Canvas(W, H)
    cv.shadow(25.5, 62.0, 11, 2.2)
    trunk = Canvas(W, H)
    cx = 24.0
    base = 62
    if season == "winter":
        _ash_winter(trunk, cx, base)
    else:
        draw_trunk(trunk, cx, 30, base, 3, flare=2, seed=11)
        # two thick limbs into the crown (visible through gaps)
        rng = lib.rng(5)
        draw_branch(trunk, 22, 36, -0.55, 9, 3, BARK, 0, rng)
        draw_branch(trunk, 26, 37, 0.6, 8, 3, BARK, 0, rng)
        lib.outline(trunk, WARM, local=0.55)
    cv.blit(trunk, 0, 0)
    if season != "winter":
        if season == "autumn":
            rr = [X.CANOPY_AUTUMN, X.CANOPY_AUTUMN_GOLD]
            pattern = [1, 0, 1, 0, 1, 1, 0, 1, 0]
            ramp_for = (lambda i: rr[pattern[i]])
            base_ramp = X.CANOPY_AUTUMN
        else:
            base_ramp = SEASON_CANOPY[season]
            ramp_for = (lambda i: None)
        puffs = _ash_puffs(ramp_for)
        crown, lab = canopy(W, 50, puffs, base_ramp, seed=21, leaf_amp=0.17, ao=0.32)
        # canopy shadow on the trunk below it
        for y in range(44, 50):
            for x in range(18, 31):
                if crown.alpha(x, y) == 0 and cv.alpha(x, y) == 255 and \
                        any(crown.alpha(x, yy) == 255 for yy in range(y - 4, y)):
                    cv.px(x, y, mix(cv.get(x, y), BARK[0], 0.55))
        if season == "spring":
            B = lib.ramp(X.BLOSSOM_RAMP)
            scatter_blossoms(crown, lab, None, (B[3], B[2], B[1]), 9,
                             region=lambda x, y: y < 40, seed=3)
        if season == "autumn":
            # a few falling leaves near the crown
            for (x, y, c) in [(5, 47, P.AUTUMN["rust"]), (42, 50, P.AUTUMN["gold"]),
                              (38, 55, P.AUTUMN["amber"])]:
                crown.px(x, y, c) if y < 50 else None
                if y >= 50:
                    cv.px(x, y, c)
        cv.blit(crown, 0, 0)
    return cv


def limb(cv, pts, t0, t1, R, snow=None):
    """Tapered polyline branch. pts in image coords; thickness t0 -> t1 (px)."""
    segs = list(zip(pts[:-1], pts[1:]))
    total = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in segs) or 1.0
    run = 0.0
    for (ax, ay), (bx, by) in segs:
        ln = math.hypot(bx - ax, by - ay)
        steps = max(1, int(ln * 2))
        flat = abs(bx - ax) > abs(by - ay) * 0.7
        for i in range(steps + 1):
            f = i / steps
            x = ax + (bx - ax) * f
            y = ay + (by - ay) * f
            t = t0 + (t1 - t0) * ((run + ln * f) / total)
            w = max(1, int(round(t)))
            xs = int(round(x - (w - 1) / 2.0))
            for k in range(w):
                c = R[3] if (k == 0 and w > 1) else (R[1] if k == w - 1 and w > 1 else R[2])
                cv.px(xs + k, int(round(y)), c)
                if snow is not None and flat:
                    snow.add((xs + k, int(round(y))))
        run += ln


WINTER_LIMBS = [
    # (points, thick_start, thick_end)
    ([(22, 33), (18, 25), (13, 18), (9, 13)], 3.2, 1.6),
    ([(18, 25), (11, 23), (5, 20)], 2.0, 1.0),
    ([(13, 18), (13, 11), (11, 6)], 1.8, 1.0),
    ([(9, 13), (5, 10), (3, 8)], 1.2, 1.0),
    ([(24, 32), (24, 23), (23, 14), (24, 4)], 3.0, 1.0),
    ([(24, 23), (28, 17), (30, 10)], 1.8, 1.0),
    ([(23, 14), (19, 9), (18, 3)], 1.3, 1.0),
    ([(26, 33), (31, 26), (36, 19), (40, 13)], 3.2, 1.6),
    ([(31, 26), (38, 24), (43, 21)], 2.0, 1.0),
    ([(36, 19), (35, 12), (37, 6)], 1.6, 1.0),
    ([(40, 13), (44, 10)], 1.2, 1.0),
    # twigs
    ([(5, 20), (2, 19)], 1, 1), ([(5, 20), (4, 16)], 1, 1), ([(11, 6), (9, 3)], 1, 1),
    ([(11, 6), (13, 2)], 1, 1), ([(3, 8), (2, 5)], 1, 1), ([(24, 4), (22, 1)], 1, 1),
    ([(24, 4), (26, 1)], 1, 1), ([(30, 10), (33, 7)], 1, 1), ([(30, 10), (29, 5)], 1, 1),
    ([(18, 3), (16, 1)], 1, 1), ([(43, 21), (46, 19)], 1, 1), ([(43, 21), (44, 17)], 1, 1),
    ([(37, 6), (39, 3)], 1, 1), ([(37, 6), (35, 2)], 1, 1), ([(44, 10), (46, 7)], 1, 1),
    ([(13, 18), (8, 17)], 1, 1), ([(36, 19), (41, 18)], 1, 1),
]


def winter_bark():
    return lib.ramp([mix(P.BARK_RAMP[0], P.WINTER["branch"], 0.2),
                     mix(P.BARK_RAMP[1], P.WINTER["branch"], 0.35),
                     mix(P.BARK_RAMP[2], P.WINTER["branch"], 0.5),
                     mix(P.BARK_RAMP[3], P.WINTER["branch"], 0.55),
                     mix(P.BARK_RAMP[4], P.WINTER["branch"], 0.5)])


def _ash_winter(cv, cx, base):
    R = winter_bark()
    draw_trunk(cv, cx, 30, base, 3, flare=2, ramp=R, seed=11)
    snow = set()
    for pts, t0, t1 in WINTER_LIMBS:
        limb(cv, pts, t0, t1, R, snow)
    lib.outline(cv, WARM, local=0.55)
    # snow sits on the flatter limbs' upper side only
    for (x, y) in sorted(snow):
        if cv.alpha(x, y - 1) < 255 or cv.get(x, y - 1)[:3] == WARM[:3]:
            above = cv.get(x, y - 2)
            cv.px(x, y - 1, SNOW[4])
    # a soft drift at the foot
    for x in range(16, 34):
        d = abs(x + 0.5 - 25)
        if d < 8:
            cv.px(x, base + 1, SNOW[3] if d < 5 else SNOW[2])
            if d < 4 and cv.alpha(x, base) == 255:
                cv.px(x, base, SNOW[2])


# ================================================================================================
# pine (32x64 evergreen)
# ================================================================================================
PINE_SEASON = {"spring": X.PINE_RAMP, "summer": X.PINE_SUMMER_RAMP,
               "autumn": X.PINE_AUTUMN_RAMP, "winter": X.PINE_RAMP}
# tiers top -> bottom: (apex_y, bottom_y, half_width)
PINE_TIERS = [(1, 15, 6.0), (7, 24, 9.0), (14, 34, 11.5), (22, 44, 13.5), (31, 54, 15.0)]


def _tier_mask(ay, by, hw, W, H, ti):
    m = np.zeros((H, W), bool)
    for y in range(ay, by + 3):
        t = min(1.0, (y - ay) / max(1, by - ay))
        half = 0.8 + (hw - 0.8) * (t ** 0.9)
        for x in range(W):
            dx = x + 0.5 - 16.0
            if abs(dx) > half:
                continue
            # drooping fringe: points every 4px hang 1-2px below the tier line
            k = (x + ti) % 4
            limit = by + (1 if k in (0, 1) else 0)
            if abs(dx) > hw * 0.7:
                limit += 1 if k in (0, 1) else 0
            if y > limit:
                continue
            m[y, x] = True
    return m


def pine(season):
    W, H = 32, 64
    R = lib.ramp(PINE_SEASON[season])
    cv = Canvas(W, H)
    cv.shadow(17.0, 62.0, 8, 2.0)
    trunk = Canvas(W, H)
    pb = lib.ramp(["#2a160c", "#432414", "#5e3a20", "#7a5030", "#93694a"])
    draw_trunk(trunk, 16.0, 48, 62, 2, flare=1, ramp=pb, seed=3)
    lib.outline(trunk, WARM, local=0.55)
    cv.blit(trunk, 0, 0)
    fol = Canvas(W, H)
    noise = lib.value_noise(W, H, 12, 24, 31, wrap=False)
    snowy = season == "winter"
    for ti in range(len(PINE_TIERS) - 1, -1, -1):          # bottom tier first
        ay, by, hw = PINE_TIERS[ti]
        m = _tier_mask(ay, by, hw, W, H, ti)
        # the upper tier's skirt shades this tier's top rows: darken what is already there
        for y in range(H):
            for x in range(W):
                if not m[y, x]:
                    continue
                if fol.alpha(x, y + 1) == 255 and not m[min(H - 1, y + 1), x]:
                    pass
        layer = Canvas(W, H)
        for y in range(H):
            for x in range(W):
                if not m[y, x]:
                    continue
                t = min(1.0, (y - ay) / max(1, by - ay))
                dx = x + 0.5 - 16.0
                v = 0.62 - dx / (hw + 3) * 0.75 + (0.5 - t) * 0.5 + (noise[y, x] - 0.5) * 0.3
                # needle strokes
                if (x + 2 * y) % 5 == 0 and dx < 2:
                    v += 0.22
                if (x - 2 * y) % 5 == 0 and dx > -2:
                    v -= 0.22
                bottom = not m[min(H - 1, y + 1), x] or not m[min(H - 1, y + 2), x]
                if bottom:
                    v -= 0.35
                k = 1 + int(np.clip(v * 4.4, 0, 5))
                layer.px(x, y, R[k])
        # shadow this tier casts on the tier below (already on fol)
        for y in range(H - 1, 0, -1):
            for x in range(W):
                if m[y, x] and not m[min(H - 1, y + 1), x]:
                    for k in (1, 2):
                        yy = y + k
                        if yy < H and fol.alpha(x, yy) == 255:
                            fol.px(x, yy, mix(fol.get(x, yy), R[0], 0.55 if k == 1 else 0.3))
        fol.blit(layer, 0, 0)
    lib.outline(fol, mix(R[0], WARM, 0.4), local=0.5)
    if snowy:
        S = SNOW
        thick = [2, 3, 3, 2, 1, 2, 3, 4, 3, 2, 2, 3, 1, 2, 3, 3, 2]
        for ti, (ay, by, hw) in enumerate(PINE_TIERS):
            upper_by = PINE_TIERS[ti - 1][1] if ti > 0 else ay - 1
            m = _tier_mask(ay, by, hw, W, H, ti)
            for x in range(W):
                # first visible row of this tier in this column
                ys = [y for y in range(max(ay, 0), by + 3) if m[y, x] and
                      (ti == 0 or not _tier_mask(*PINE_TIERS[ti - 1], W, H, ti - 1)[y, x])]
                if not ys:
                    continue
                y0 = ys[0]
                dx = x + 0.5 - 16.0
                d = wave(x + ti * 3, thick)
                if abs(dx) > hw * 0.82:
                    d = max(1, d - 2)
                for k in range(d):
                    y = y0 + k
                    if y not in ys:
                        break
                    c = S[4] if dx < -1 else S[3] if dx < 5 else S[2]
                    if k == d - 1 and d > 1:
                        c = S[2] if dx < 2 else S[1]
                    fol.px(x, y, c)
                # cool outline above exposed snow
                if y0 - 1 >= 0 and fol.alpha(x, y0 - 1) < 255:
                    fol.px(x, y0 - 1, S[1] if dx < 2 else S[0])
        # a cap on the very top
        for (x, y, c) in [(15, 0, S[1]), (16, 0, S[0]), (15, 1, S[4]), (16, 1, S[3])]:
            fol.px(x, y, c)
    cv.blit(fol, 0, 0)
    return cv


# ================================================================================================
# dead tree (32x48)
# ================================================================================================
def deadtree():
    W, H = 32, 48
    R = lib.ramp(X.DEADWOOD_RAMP)
    cv = Canvas(W, H)
    cv.shadow(17.0, 46.0, 7, 1.8)
    t = Canvas(W, H)
    draw_trunk(t, 16.0, 12, 46, 2, flare=2, ramp=R, seed=7)
    # broken, splintered top
    for (x, y, c) in [(14, 11, R[3]), (15, 10, R[4]), (16, 9, R[3]), (17, 11, R[2]),
                      (15, 9, R[4]), (16, 8, R[2])]:
        t.px(x, y, c)
    rng = lib.rng(12)
    draw_branch(t, 15, 26, -1.0, 8, 2, R, 1, rng, min_len=4)
    draw_branch(t, 17, 20, 0.95, 9, 2, R, 1, rng, min_len=4)
    draw_branch(t, 15, 16, -0.6, 7, 1, R, 0, rng)
    draw_branch(t, 17, 33, 1.2, 5, 2, R, 0, rng)          # snapped stub
    # hollow + peeled bark
    t.px(16, 30, R[0]); t.px(16, 31, R[0]); t.px(17, 31, R[1])
    for y in range(18, 24):
        t.px(14, y, R[4])
    lib.outline(t, WARM, local=0.55)
    cv.blit(t, 0, 0)
    return cv


# ================================================================================================
# stumps (16x16)
# ================================================================================================
def stump(kind):
    """16x16 cut stump: bark sides, a big readable cut face with rings, roots."""
    W, H = 16, 16
    cv = Canvas(W, H)
    cv.shadow(9.0, 14.6, 6.5, 1.4)
    pine_k = kind == "pine"
    pb = BARK if not pine_k else lib.ramp(["#2a160c", "#432414", "#5e3a20", "#7a5030", "#93694a"])
    cw = WOOD if not pine_k else lib.ramp(["#5a3818", "#80522a", "#a8733c", "#c8955a", "#e0b878",
                                          "#f0d29a"])
    hx = 5 if not pine_k else 4          # half width of the trunk
    cx = 8.0
    s = Canvas(W, H)
    ytop, ybase = 7, 13
    for y in range(ytop, ybase + 1):
        for x in range(int(cx - hx), int(cx + hx)):
            t = (x + 0.5 - (cx - hx)) / (2 * hx)
            c = pb[3] if t < 0.22 else pb[2] if t < 0.62 else pb[1]
            if (x * 5 + y * 3) % 7 == 0 and 0.15 < t < 0.9:
                c = pb[1] if t < 0.6 else pb[0]
            s.px(x, y, c)
    # root flare
    for (x, y, c) in [(int(cx - hx) - 1, ybase, pb[2]), (int(cx - hx) - 2, ybase, pb[1]),
                      (int(cx - hx) - 1, ybase - 1, pb[2]),
                      (int(cx + hx), ybase, pb[1]), (int(cx + hx) + 1, ybase, pb[0]),
                      (int(cx + hx), ybase - 1, pb[1])]:
        s.px(x, y, c)
    # cut face
    ry = 2.6 if not pine_k else 2.3
    fy = ytop
    for y in range(fy - 3, fy + 3):
        for x in range(int(cx - hx), int(cx + hx)):
            dx = (x + 0.5 - cx) / hx
            dy = (y + 0.5 - fy) / ry
            d = math.sqrt(dx * dx + dy * dy)
            if d > 1.0:
                continue
            if d > 0.78:
                c = pb[3] if dx < 0.2 else pb[2]          # bark rim
            elif 0.42 < d < 0.58:
                c = cw[3]                                  # growth ring
            elif d < 0.2:
                c = cw[3]
            else:
                c = cw[5] if dx < 0 else cw[4]
            s.px(x, y, c)
    # radial check crack
    s.px(int(cx) + 1, fy, cw[2]); s.px(int(cx) + 2, fy + 1, cw[2])
    if pine_k:
        s.px(int(cx - hx) + 1, ybase - 2, lib.rgba(P.LAMPLIGHT))    # resin bead
        s.px(int(cx - hx) + 1, ybase - 1, lib.rgba(X.FIRE_RAMP[3]))
    lib.outline(s, WARM, local=0.55)
    cv.blit(s, 0, 0)
    return cv


# ================================================================================================
# saplings
# ================================================================================================
def sapling(stage, season):
    ramp = SEASON_CANOPY.get(season, X.CANOPY_SPRING)
    if stage == 0:
        W, H = 16, 16
        cv = Canvas(W, H)
        cv.shadow(8.5, 14.8, 3.5, 1.0)
        s = Canvas(W, H)
        stem = lib.ramp(X.BARK_RAMP_COOL)
        for y in range(9, 15):
            s.px(8, y, stem[3] if y < 12 else stem[2])
        # soil mound
        for x in range(6, 11):
            s.px(x, 14, lib.rgba(P.SOIL_RAMP[3]) if x < 9 else lib.rgba(P.SOIL_RAMP[2]))
        if season == "winter":
            s.px(8, 8, stem[3]); s.px(7, 9, stem[2]); s.px(9, 7, stem[3])
            lib.outline(s, WARM, local=0.55)
            s.px(8, 7, SNOW[4]); s.px(9, 6, SNOW[4]); s.px(7, 8, SNOW[3])
        else:
            L = lib.ramp(ramp)
            leaves = [(5, 9, 4), (6, 9, 5), (6, 10, 3), (7, 10, 3),
                      (10, 7, 5), (11, 7, 4), (9, 8, 4), (10, 8, 3), (11, 8, 2),
                      (8, 6, 5), (8, 7, 4), (7, 7, 3)]
            for x, y, k in leaves:
                s.px(x, y, L[k])
            lib.outline(s, mix(L[0], WARM, 0.4), local=0.5)
        cv.blit(s, 0, 0)
        return cv
    if stage == 1:
        W, H = 16, 32
        cv = Canvas(W, H)
        cv.shadow(9.0, 30.6, 4, 1.1)
        s = Canvas(W, H)
        stem = lib.ramp(X.BARK_RAMP_COOL)
        for y in range(14, 31):
            s.px(7, y, stem[3])
            s.px(8, y, stem[2])
        s.px(6, 30, stem[2]); s.px(9, 30, stem[1])
        rng = lib.rng(31)
        draw_branch(s, 8, 22, 0.75, 4, 1, stem, 0, rng)
        draw_branch(s, 7, 19, -0.8, 4, 1, stem, 0, rng)
        lib.outline(s, WARM, local=0.55)
        if season == "winter":
            draw_branch(s, 7, 14, -0.3, 4, 1, stem, 0, rng)
            draw_branch(s, 8, 14, 0.4, 4, 1, stem, 0, rng)
            snow_on_top(s, SNOW[4], None, prob=1.0, seed=2)
            cv.blit(s, 0, 0)
            return cv
        cv.blit(s, 0, 0)
        puffs = [Puff(8, 9, 5.2, phase=0.3), Puff(4.5, 15, 3.6, phase=1.1),
                 Puff(11.5, 17, 3.8, phase=2.2), Puff(8, 13, 4.5, phase=0.7)]
        if season == "autumn":
            for k, p in enumerate(puffs):
                p.ramp = X.CANOPY_AUTUMN_GOLD if k % 2 else X.CANOPY_AUTUMN
        crown, lab = canopy(W, 24, puffs, ramp, seed=5, leaf_amp=0.14, ao=0.25)
        cv.blit(crown, 0, 0)
        return cv
    # stage 2: young tree 32x48
    W, H = 32, 48
    cv = Canvas(W, H)
    cv.shadow(17.0, 46.2, 7, 1.6)
    t = Canvas(W, H)
    draw_trunk(t, 16.0, 22, 46, 2, flare=1, seed=4)
    rng = lib.rng(41)
    if season == "winter":
        R = winter_bark()
        t = Canvas(W, H)
        draw_trunk(t, 16.0, 24, 46, 2, flare=1, ramp=R, seed=4)
        snow = set()
        for pts, t0, t1 in [([(15, 26), (11, 20), (7, 15)], 2.0, 1.0),
                            ([(17, 25), (21, 19), (25, 14)], 2.0, 1.0),
                            ([(16, 24), (16, 15), (15, 7)], 2.0, 1.0),
                            ([(11, 20), (6, 19)], 1, 1), ([(21, 19), (26, 19)], 1, 1),
                            ([(7, 15), (5, 11)], 1, 1), ([(25, 14), (27, 10)], 1, 1),
                            ([(16, 15), (20, 11)], 1, 1), ([(15, 7), (13, 4)], 1, 1),
                            ([(15, 7), (17, 4)], 1, 1), ([(16, 15), (12, 11)], 1, 1)]:
            limb(t, pts, t0, t1, R, snow)
        lib.outline(t, WARM, local=0.55)
        for (x, y) in sorted(snow):
            if t.alpha(x, y - 1) < 255 or t.get(x, y - 1)[:3] == WARM[:3]:
                t.px(x, y - 1, SNOW[4])
        cv.blit(t, 0, 0)
        return cv
    draw_branch(t, 15, 30, -0.6, 6, 2, BARK, 0, rng)
    draw_branch(t, 17, 31, 0.6, 6, 2, BARK, 0, rng)
    lib.outline(t, WARM, local=0.55)
    cv.blit(t, 0, 0)
    puffs = [Puff(16, 10, 8.0, phase=0.2), Puff(9, 16, 6.5, phase=1.3), Puff(23, 16, 6.5, phase=2.0),
             Puff(16, 18, 8.5, phase=0.9), Puff(10, 25, 6.0, phase=1.7), Puff(22, 25, 6.0, phase=2.6),
             Puff(16, 27, 6.0, phase=0.4)]
    if season == "autumn":
        for k, p in enumerate(puffs):
            p.ramp = X.CANOPY_AUTUMN_GOLD if k % 2 == 0 else X.CANOPY_AUTUMN
    crown, lab = canopy(W, 36, puffs, ramp, seed=8, leaf_amp=0.16, ao=0.3)
    if season == "spring":
        B = lib.ramp(X.BLOSSOM_RAMP)
        scatter_blossoms(crown, lab, None, (B[3], B[2], B[1]), 4, region=lambda x, y: y < 26,
                         seed=9)
    cv.blit(crown, 0, 0)
    return cv


# ================================================================================================
# bushes
# ================================================================================================
BUSH_RAMP = {"spring": X.CANOPY_SPRING, "summer": X.CANOPY_SUMMER, "autumn": X.CANOPY_AUTUMN,
             "winter": ["#1a2a24", "#24382e", "#2f4838", "#3e5a44", "#516e52", "#6a8462",
                        "#86a074"]}


def bush(season, large=False):
    if large:
        W, H = 32, 32
        puffs = [Puff(16, 9, 7.5, phase=0.1), Puff(8, 14, 6.5, phase=1.2), Puff(24, 14, 6.5, phase=2.1),
                 Puff(16, 16, 8.0, phase=0.8), Puff(9, 22, 6.5, phase=1.6),
                 Puff(23, 22, 6.5, phase=2.4), Puff(16, 23, 7.0, phase=0.5)]
        shadow = (17.0, 30.3, 12, 1.8)
        crown_h = 31
    else:
        W, H = 16, 16
        puffs = [Puff(8, 6.5, 4.6, phase=0.4), Puff(4.6, 9.5, 3.8, phase=1.4),
                 Puff(11.4, 9.5, 3.8, phase=2.3), Puff(8, 10.5, 4.6, phase=0.9)]
        shadow = (9.0, 14.6, 6.5, 1.4)
        crown_h = 15
    ramp = BUSH_RAMP[season]
    if season == "autumn":
        for k, p in enumerate(puffs):
            p.ramp = X.CANOPY_AUTUMN if k % 3 else X.CANOPY_AUTUMN_GOLD
    cv = Canvas(W, H)
    cv.shadow(*shadow)
    crown, lab = canopy(W, crown_h, puffs, ramp, seed=17 if large else 13, leaf_amp=0.15, ao=0.3)
    if season == "spring":
        F = lib.ramp(X.FLOWER_WHITE)
        scatter_blossoms(crown, lab, None, (F[2], F[1], F[0]), 5 if large else 2,
                         region=lambda x, y: y < crown_h - 4, seed=21)
    if season == "summer":
        Bm = lib.ramp(["#5a1e2a", "#8a3040", "#c05060"])   # dusty berries
        scatter_blossoms(crown, lab, None, (Bm[2], Bm[1], Bm[0]), 4 if large else 2,
                         region=lambda x, y: y < crown_h - 4, seed=23)
    if season == "winter":
        pat = [3, 3, 4, 3, 2, 3, 4, 4, 3, 2, 3] if large else [2, 3, 3, 2, 2, 3, 2]
        snow_cap(crown, lambda x: wave(x, pat), seed=5)
    cv.blit(crown, 0, 0)
    return cv


# ================================================================================================
def build(out):
    for s in P.SEASONS:
        ashwood(s).save(f"trees/ashwood_{s}.png")
        pine(s).save(f"trees/pine_{s}.png")
        for st in range(3):
            sapling(st, s).save(f"trees/sapling_{st}_{s}.png")
        bush(s).save(f"trees/bush_{s}.png")
        bush(s, large=True).save(f"trees/bush_large_{s}.png")
    deadtree().save("trees/deadtree.png")
    stump("ashwood").save("trees/ashwood_stump.png")
    stump("pine").save("trees/pine_stump.png")
