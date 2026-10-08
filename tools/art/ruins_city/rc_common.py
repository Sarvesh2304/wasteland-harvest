"""Shared ramps and drawing helpers for the ruined-city kit (docs/ART_STYLE.md rules apply).

Ruins conventions (same as tools/art/env/ruins.py): desaturated ruins palette, cold outline
#181a16 on silhouettes, cold contact shadows (~35 %) offset to the bottom-right, light from the
top-left. Rad-glow green is never used here: nothing in this kit is irradiated.
"""
from __future__ import annotations

import hashlib

import numpy as np

import palette as P
from env import colors as X
from env import lib
from env.lib import Canvas, mix, rgba

COLD = lib.COLD
WARM = lib.WARM
CLEAR = lib.CLEAR

# -- ramps (darkest -> lightest) ----------------------------------------------------------------
CON = lib.ramp(X.CONCRETE_RAMP)
ASPH = lib.ramp(X.ASPHALT_RAMP)
MET = lib.ramp([mix(c, "#6f6f68", 0.25) for c in P.METAL_RAMP])   # cooler, duller metal (= env.ruins)
RUST = lib.ramp(P.RUST_RAMP)
RUB = lib.ramp(X.RUBBER_RAMP)
BRICK = lib.ramp(P.RUIN_BRICK_RAMP)
BRICK_D = lib.ramp(P.RUIN_BRICK_DARK_RAMP)
TRIM = lib.ramp(P.RUIN_STONE_TRIM_RAMP)
SIDING = lib.ramp(P.RUIN_SIDING_RAMP)
SHINGLE = lib.ramp(P.RUIN_SHINGLE_RAMP)
BLOCK = lib.ramp(P.RUIN_BLOCK_RAMP)
GLASS = lib.ramp(P.RUIN_GLASS_RAMP)
VINE = lib.ramp(P.RUIN_VINE_RAMP)
WEED = lib.ramp(P.RUIN_WEED_RAMP)
DRY = lib.ramp(P.RUIN_DRYGRASS_RAMP)
GROUND = lib.ramp(P.RUIN_GROUND_RAMP)
CHAR = lib.ramp(P.CHAR_RAMP)
PAPER = lib.ramp(P.PAPER_RAMP)
BONE = lib.ramp(P.BONE_RAMP)
TRUCK = lib.ramp(P.TRUCK_PAINT_RAMP)
TRANSIT = lib.ramp(P.TRANSIT_SIGN_RAMP)
# weathered, greyed planks (boarded windows, beams): the settlement wood ramp pulled toward concrete
WOODG = lib.ramp([mix(c, P.CONCRETE_LIGHT, 0.38) for c in P.WOOD_RAMP])
WOOD = lib.ramp(P.WOOD_RAMP)
CREAMS = rgba(P.SIGNAGE_CREAM)
ASH = rgba(P.ASH_BROWN)
ASH_PALE = rgba(P.ASH_PALE)
LAMP = rgba(P.LAMPLIGHT)


def dk(c, t=0.6):
    """Local dark shade of a material (toward the cold outline)."""
    return mix(c, COLD, t)


def hval(*key):
    """Deterministic hash of a key -> float in [0, 1) (independent of Python's hash seed)."""
    h = hashlib.blake2s(repr(key).encode(), digest_size=4).digest()
    return int.from_bytes(h, "little") / 2 ** 32


def shadow(cv, cx, cy, rx, ry, alpha=lib.SHADOW_ALPHA):
    cv.shadow(cx, cy, rx, ry, alpha=alpha, color=P.OUTLINE_COLD)


def finish(cv, s, sh=None, dark=COLD, local=0.6, skip=None):
    """Outline the body `s`, drop a contact shadow on `cv`, composite the body on top."""
    lib.outline(s, dark, local=local, skip=skip)
    if sh:
        cv.shadow(*sh, color=P.OUTLINE_COLD if dark == COLD else P.OUTLINE_WARM)
    cv.blit(s, 0, 0)
    return cv


def darken(s, x, y, c=COLD, t=0.5):
    """Pull an existing opaque pixel toward `c` (soot, grime, stains)."""
    if s.alpha(x, y) == 255:
        s.px(x, y, mix(s.get(x, y), c, t))


# ------------------------------------------------------------------------------------------------
# tiny pixel font (3x5, a few wide glyphs) for faded signage
# ------------------------------------------------------------------------------------------------
FONT = {
    "A": [".#.", "#.#", "###", "#.#", "#.#"],
    "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": [".##", "#..", "#..", "#..", ".##"],
    "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"],
    "F": ["###", "#..", "##.", "#..", "#.."],
    "G": [".##", "#..", "#.#", "#.#", ".##"],
    "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["#", "#", "#", "#", "#"],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"],
    "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
    "N": ["#..#", "##.#", "#.##", "#..#", "#..#"],
    "O": [".#.", "#.#", "#.#", "#.#", ".#."],
    "P": ["##.", "#.#", "##.", "#..", "#.."],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"],
    "S": [".##", "#..", ".#.", "..#", "##."],
    "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"],
    "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "W": ["#...#", "#...#", "#.#.#", "##.##", "#...#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."],
    "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "0": ["###", "#.#", "#.#", "#.#", "###"],
    "1": [".#", "##", ".#", ".#", ".#"],
    "2": ["##.", "..#", ".#.", "#..", "###"],
    "3": ["##.", "..#", ".#.", "..#", "##."],
    "4": ["#.#", "#.#", "###", "..#", "..#"],
    "5": ["###", "#..", "##.", "..#", "##."],
    "7": ["###", "..#", ".#.", ".#.", ".#."],
    "8": [".#.", "#.#", ".#.", "#.#", ".#."],
    " ": ["..", "..", "..", "..", ".."],
}


def text_width(s):
    return sum(len(FONT[ch][0]) + 1 for ch in s) - 1


def text(cv, x, y, s, color, skip=(), fade=None, drop=None):
    """Draw `s` with its top-left at (x, y). `skip` = indices of missing letters; `fade` =
    {index: t} pulls a letter toward the board colour it sits on; `drop` = {index: dy} lets a
    letter hang crooked (shifted down)."""
    fade = fade or {}
    drop = drop or {}
    cx = x
    for i, ch in enumerate(s):
        g = FONT[ch]
        if i not in skip:
            for j, row in enumerate(g):
                for k, v in enumerate(row):
                    if v != "#":
                        continue
                    xx, yy = cx + k, y + j + drop.get(i, 0)
                    c = color
                    if i in fade:
                        c = mix(color, cv.get(xx, yy), fade[i])
                    cv.px(xx, yy, c)
        cx += len(g[0]) + 1
    return cx - 1


# ------------------------------------------------------------------------------------------------
# weathering details
# ------------------------------------------------------------------------------------------------
def rust_streak(s, x, y0, length, t0=0.6, col=None):
    """Vertical rust run-off below a metal fixing; fades as it runs down."""
    col = col or RUST[2]
    for k in range(length):
        t = t0 * (1.0 - k / max(1, length))
        if t > 0.08:
            darken(s, x, y0 + k, col, t)


def soot(s, x0, y0, w, h, strength=0.65, seed=0):
    """Fire soot rising above an opening: darkest at the bottom (y0 + h - 1), ragged top."""
    for x in range(x0, x0 + w):
        cut = int(h * (0.55 + 0.45 * hval("soot", seed, x)))
        edge = min(abs(x - x0), abs(x0 + w - 1 - x))
        if edge == 0:
            cut = int(cut * 0.55)
        for k in range(cut):
            y = y0 + h - 1 - k
            t = strength * (1.0 - k / max(1, cut)) ** 0.8
            darken(s, x, y, COLD, t)


def vine(s, pts, seed=0, leaves=True):
    """Dead climbing vine along a polyline (list of (x, y), bottom first); twigs + dry leaves."""
    path = []
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        for p in lib.line_points(ax, ay, bx, by):
            if not path or path[-1] != p:
                path.append(p)
    for i, (x, y) in enumerate(path):
        s.px_if(x, y, VINE[1] if i % 3 else VINE[0])
        if s.alpha(x, y) == 255 and i % 2 == 0 and hval("vl", seed, i) < 0.5:
            s.px_if(x - 1, y, VINE[2])
    if leaves:
        for i, (x, y) in enumerate(path):
            r = hval("vleaf", seed, i)
            if r < 0.22:
                dx = -1 if r < 0.11 else 1
                s.px_if(x + dx, y, VINE[3] if dx < 0 else VINE[2])
                if r < 0.06:
                    s.px_if(x + dx, y - 1, VINE[2])
            elif r < 0.30:
                s.px_if(x + 1, y + 1, DRY[1])


def tuft(s, x, y, kind="weed", h=3):
    """Small weed / dead-grass tuft standing on ground row y (drawn upward)."""
    R = WEED if kind == "weed" else DRY
    pat = [(-1, 0, 1), (-1, -1, 2), (0, 0, 1), (0, -1, 2), (0, -2, 3), (1, 0, 1), (1, -1, 2),
           (2, -1, 3), (-2, 0, 2)]
    if h > 3:
        pat += [(0, -3, 3), (-1, -2, 2)]
    for (dx, dy, k) in pat:
        s.px(x + dx, y + dy, R[k])


def plank(s, x0, y0, x1, y1, R=None, w=2, nails=True):
    """A nailed board from (x0, y0) to (x1, y1) (roughly horizontal), w px thick, lit top row."""
    R = R or WOODG
    pts = lib.line_points(x0, y0, x1, y1)
    for i, (x, y) in enumerate(pts):
        for k in range(w):
            c = R[4] if k == 0 else R[2] if k == w - 1 else R[3]
            if (x * 7 + y * 3) % 11 == 0 and k == w // 2:
                c = R[2]
            s.px(x, y + k, c)
    if nails:
        s.px(pts[0][0] + 1, pts[0][1], MET[4])
        s.px(pts[-1][0] - 1, pts[-1][1], MET[4])


def chips(s, pts, R=None):
    """Loose rubble chips: list of (x, y, size) -> tiny lit-top lumps."""
    R = R or CON
    for (x, y, k) in pts:
        if k == 1:
            s.px(x, y, R[3])
        elif k == 2:
            s.px(x, y, R[4]); s.px(x + 1, y, R[2])
        else:
            s.px(x, y, R[4]); s.px(x + 1, y, R[3]); s.px(x, y + 1, R[2]); s.px(x + 1, y + 1, R[1])
            s.px(x + 2, y + 1, R[1])
