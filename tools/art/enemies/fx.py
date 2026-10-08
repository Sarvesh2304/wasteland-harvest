"""Combat FX sprites (art/fx/). Translucency is allowed here (ART_STYLE §1: deliberate effects).

  slash.png         4 frames 32x32 (128x32). EAST-facing melee swoosh: the arc's pivot is the
                    frame's left-middle (the swinger's hand); it sweeps top -> bottom through the
                    right half. Rotate in code for other directions.
  bolt.png          10x3 crossbow bolt pointing east (metal tip, wood shaft, fletching).
  shot.png          5x2 bullet / pellet tracer, hot head on the right (east).
  stone_shot.png    4x4 slingshot stone.
  muzzle_flash.png  3 frames 12x12 (36x12) pointing east; the barrel sits at the left-middle.
  hit_spark.png     3 frames 12x12 (36x12), centred impact flash.
  blood_splat.png   4 variants 16x16 (64x16): blood stains seen from above (ground decals).
  ichor_splat.png   4 variants 16x16 (64x16): sickly green ichor stains (bloaters, irradiated gore).
  alert_mark.png    7x11 "!" (red-orange, dark outline) popped over an enemy that spots you.
  question_mark.png 7x11 "?" (pale yellow) when an enemy loses track of you.
"""
from __future__ import annotations

import math

import palette as P
from enemies import pix
from enemies.pix import Canvas, mix, ramp, rgba

WHITE = rgba(P.FX_WHITE)
CREAM = rgba(P.CREAM)
LAMP = rgba(P.LAMPLIGHT)
AMBER = rgba(P.AMBER)
GOLD = rgba(P.AUTUMN["gold"])
EMBER = rgba(P.AUTUMN["rust"])
SMOKE = rgba(P.STONE_RAMP[3])
COLD = pix.COLD


# ------------------------------------------------------------------------------------------------
def slash():
    """Crescent swoosh. Per frame: the blade head angle and how much trail is still visible."""
    frames = []
    pivot = (0.5, 16.0)
    r_mid = 17.0
    # (head angle deg, trail length deg, thickness, brightness)
    spec = [(-38, 34, 4.5, 0.9), (22, 92, 7.5, 1.0), (52, 104, 5.5, 0.72), (64, 84, 3.2, 0.42)]
    for (head, trail, thick, bright) in spec:
        cv = Canvas(32, 32)
        for y in range(32):
            for x in range(32):
                dx = x + 0.5 - pivot[0]
                dy = y + 0.5 - pivot[1]
                r = math.hypot(dx, dy)
                ang = math.degrees(math.atan2(dy, dx))
                behind = head - ang                       # 0 at the head, grows along the trail
                if behind < -2 or behind > trail:
                    continue
                t = max(0.0, behind) / trail              # 0 head .. 1 tail
                half = thick * (1.0 - t * 0.85) * 0.5 + 0.35
                # the crescent bulges outward at the head (wider outer edge)
                off = r - (r_mid + 1.6 * (1 - t))
                if abs(off) > half:
                    continue
                edge = abs(off) / half                    # 0 centre line .. 1 rim
                heat = (1.0 - t) * (1.0 - 0.55 * edge) * bright
                if behind < 0:
                    heat *= 0.6
                if heat > 0.62:
                    c, a = WHITE, 255
                elif heat > 0.45:
                    c, a = CREAM, 240
                elif heat > 0.28:
                    c, a = LAMP, 210
                elif heat > 0.14:
                    c, a = AMBER, 150
                elif heat > 0.05:
                    c, a = AMBER, 80
                else:
                    continue
                cv.px(x, y, rgba(c, a))
        frames.append(cv)
    return pix.hstrip(frames)


def bolt():
    W = rgba(P.WOOD_RAMP[4])
    Wd = rgba(P.WOOD_RAMP[3])
    M = ramp(P.METAL_RAMP)
    F1 = rgba(P.CREAM)
    F2 = rgba(P.RUST_RAMP[3])
    rows = ["fF.......M",
            "Fwwwwwwwmt",
            "fF.......M"]
    cmap = {"f": F2, "F": F1, "w": W, "m": M[2], "t": M[5], "M": M[1]}
    cv = pix.part(rows, cmap)
    cv.px(5, 1, Wd)                                   # a darker grain knot
    return cv


def shot():
    rows = [".aLCW",
            "aLCWW"]
    return pix.part(rows, {"a": rgba(GOLD, 170), "L": LAMP, "C": CREAM, "W": WHITE})


def stone_shot():
    S = ramp(P.STONE_RAMP)
    rows = [".43.",
            "4532",
            "3221",
            ".11."]
    return pix.part(rows, {"1": S[0], "2": S[1], "3": S[2], "4": S[3], "5": S[5]})


def _burst(cv, cx, cy, rays, core_r, colors):
    """Rays: list of (angle deg, length, width). colors: hot -> cool, with alphas."""
    for y in range(cv.h):
        for x in range(cv.w):
            dx = x + 0.5 - cx
            dy = y + 0.5 - cy
            d = math.hypot(dx, dy)
            best = 9.0
            if d <= core_r:
                best = d / max(core_r, 0.01) * 0.3
            for (ang, length, width) in rays:
                a = math.radians(ang)
                along = dx * math.cos(a) + dy * math.sin(a)
                across = abs(-dx * math.sin(a) + dy * math.cos(a))
                if 0 <= along <= length:
                    w = width * (1 - along / length) + 0.3
                    if across <= w:
                        best = min(best, along / length * 0.7 + across / max(w, 0.01) * 0.3)
            if best > 1.0:
                continue
            k = min(len(colors) - 1, int(best * len(colors)))
            cv.px(x, y, colors[k])


def muzzle_flash():
    frames = []
    hot = [WHITE, CREAM, rgba(LAMP), rgba(GOLD), rgba(EMBER, 200)]
    f0 = Canvas(12, 12)
    _burst(f0, 1.0, 6.0, [(0, 10.5, 2.2), (-35, 6.0, 1.2), (35, 6.0, 1.2), (-75, 3.5, 0.8),
                          (75, 3.5, 0.8)], 2.6, hot)
    f1 = Canvas(12, 12)
    _burst(f1, 1.0, 6.0, [(0, 7.5, 1.6), (-30, 4.5, 0.9), (30, 4.5, 0.9)], 2.0,
           [CREAM, rgba(LAMP), rgba(GOLD, 230), rgba(EMBER, 180)])
    f2 = Canvas(12, 12)
    for (x, y, r, a) in ((4.0, 5.5, 2.2, 120), (6.5, 6.5, 1.8, 90), (8.5, 5.0, 1.4, 60)):
        for yy in range(12):
            for xx in range(12):
                if math.hypot(xx + 0.5 - x, yy + 0.5 - y) <= r:
                    f2.px(xx, yy, rgba(SMOKE, a))
    f2.px(2, 6, rgba(EMBER, 220))
    f2.px(5, 4, rgba(GOLD, 200))
    frames = [f0, f1, f2]
    return pix.hstrip(frames)


def hit_spark():
    f0 = Canvas(12, 12)
    _burst(f0, 6.0, 6.0, [(a, 5.5 if a % 90 == 0 else 3.5, 1.1 if a % 90 == 0 else 0.7)
                          for a in range(0, 360, 45)], 2.2, [WHITE, CREAM, rgba(LAMP), rgba(GOLD, 220)])
    f1 = Canvas(12, 12)
    _burst(f1, 6.0, 6.0, [(a + 22, 6.0, 0.6) for a in range(0, 360, 60)], 0.9,
           [CREAM, rgba(LAMP), rgba(GOLD, 220), rgba(EMBER, 170)])
    f2 = Canvas(12, 12)
    for (x, y, c) in ((1, 5, GOLD), (10, 3, LAMP), (9, 10, EMBER), (2, 10, GOLD), (6, 0, LAMP),
                      (5, 11, EMBER), (11, 7, GOLD)):
        f2.px(x, y, rgba(c, 210))
    return pix.hstrip([f0, f1, f2])


# ------------------------------------------------------------------------------------------------
def _splat(seed, R, accent=None):
    """Ground stain seen from above: a lobed main pool, satellite drops, a darker core."""
    cv = Canvas(16, 16)
    r = pix.rng(seed)
    cx, cy = 8.0 + r.uniform(-0.8, 0.8), 8.0 + r.uniform(-0.6, 0.6)
    lobes = [(cx, cy, r.uniform(3.4, 4.4), r.uniform(2.4, 3.2))]
    for _ in range(r.randint(3, 5)):
        a = r.uniform(0, math.tau)
        d = r.uniform(2.0, 3.6)
        lobes.append((cx + math.cos(a) * d, cy + math.sin(a) * d * 0.8,
                      r.uniform(1.2, 2.2), r.uniform(1.0, 1.8)))
    drops = []
    for _ in range(r.randint(4, 7)):
        a = r.uniform(0, math.tau)
        d = r.uniform(5.0, 7.0)
        drops.append((int(cx + math.cos(a) * d), int(cy + math.sin(a) * d * 0.75)))
    field = [[min(((x + 0.5 - a) / c) ** 2 + ((y + 0.5 - b) / e) ** 2 for (a, b, c, e) in lobes)
              for x in range(16)] for y in range(16)]
    for y in range(16):
        for x in range(16):
            v = field[y][x]
            if v > 1.0:
                continue
            c = R[1] if v < 0.35 else R[2]
            if v > 0.7:
                c = R[3] if (x + 0.5 < cx and y + 0.5 < cy) else R[2]
            if v < 0.12:
                c = R[0]
            cv.px(x, y, c)
    for (x, y) in drops:
        if 0 < x < 15 and 0 < y < 15:
            cv.px(x, y, R[2])
            if r.random() < 0.4:
                cv.px(x + 1, y, R[1])
    if accent:
        for _ in range(3):
            x = int(cx + r.uniform(-2.5, 2.5))
            y = int(cy + r.uniform(-1.8, 1.8))
            if cv.alpha(x, y):
                cv.px(x, y, accent)
    return cv


def blood_splat():
    R = ramp(P.BLOOD_STAIN_RAMP)
    return pix.hstrip([_splat(s, R) for s in (101, 202, 303, 404)])


def ichor_splat():
    R = ramp(P.ICHOR_RAMP)
    return pix.hstrip([_splat(s, [R[0], R[1], R[2], R[3]], accent=rgba(P.RAD_GLOW))
                       for s in (111, 222, 333, 444)])


# ------------------------------------------------------------------------------------------------
def _mark(shape, fill, shade, light):
    """shape: rows of '#'; fill with a lit top-left / shaded bottom-right, 1 px cold outline,
    plus a 1 px drop shadow to the bottom-right inside a 7x11 canvas."""
    h = len(shape)
    w = max(len(r) for r in shape)
    cv = Canvas(7, 11)
    ox, oy = 1, 1
    pts = {(x, y) for y, row in enumerate(shape) for x, ch in enumerate(row) if ch == "#"}
    for (x, y) in pts:
        c = fill
        if (x - 1, y) not in pts or (x, y - 1) not in pts:
            c = light
        if (x + 1, y) not in pts and (x, y + 1) not in pts:
            c = shade
        cv.px(ox + x, oy + y, c)
    pix.outline(cv, COLD, local=1.0, diag=True)
    return cv


def alert_mark():
    A = ramp(P.ALERT_RAMP)
    shape = ["###",
             "###",
             "###",
             "###",
             ".#.",
             "...",
             "###",
             "###"]
    cv = _mark(shape, A[2], A[1], A[3])
    return _center(cv)


def question_mark():
    shape = [".###.",
             "##.##",
             "...##",
             "..##.",
             "..#..",
             ".....",
             "..#..",
             "..#.."]
    return _center(_mark(shape, rgba(P.CREAM), rgba(P.LAMPLIGHT), rgba(P.FX_WHITE)))


def _center(cv):
    b = pix.bbox(cv)
    w = b[2] - b[0] + 1
    h = b[3] - b[1] + 1
    out = Canvas(7, 11)
    out.blit(cv, (7 - w) // 2 - b[0], (11 - h) // 2 - b[1])
    return out


def build(repo):
    out = repo / "art" / "fx"
    out.mkdir(parents=True, exist_ok=True)
    for name, fn in (("slash", slash), ("bolt", bolt), ("shot", shot), ("stone_shot", stone_shot),
                     ("muzzle_flash", muzzle_flash), ("hit_spark", hit_spark),
                     ("blood_splat", blood_splat), ("ichor_splat", ichor_splat),
                     ("alert_mark", alert_mark), ("question_mark", question_mark)):
        fn().save(out / f"{name}.png")
