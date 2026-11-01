"""Town Works buildings (art/buildings/): the clinic before / after, Marta's expanded store, the
west watchtower, the farm greenhouse (restored and ruined wall pieces) and Doc Ama's field tent.

Conventions (docs/ART_STYLE.md; same as the PixelLab buildings and the env props they stand
among): Stardew 3/4 view - a flat south elevation with the roof seen from above, 1 px selective
warm outline, warm contact shadow, light from the top-left, settlement anchor materials. Every
sprite is EXACTLY as wide as its footprint and is drawn with its bottom edge on the bottom of the
footprint (the roof / tower may rise above it). The "before" and "after" of one building share
their geometry (wall, door, windows, sign, roof line) so they read as the same place.
"""
from __future__ import annotations

import math

import numpy as np

import palette as P
from env import colors as X
from env import lib
from env.lib import Canvas, mix, rgba
from env.props import _crate, _barrel_body, _nail

WARM = lib.WARM
WOOD = lib.ramp(P.WOOD_RAMP)
MET = lib.ramp(P.METAL_RAMP)
RUST = lib.ramp(P.RUST_RAMP)
STONE = lib.ramp(P.STONE_RAMP)
WASH = lib.ramp(P.WHITEWASH_RAMP)
RED = lib.ramp(P.MEDIC_RED_RAMP)
GLOW = lib.ramp(P.WINDOW_GLOW_RAMP)
DARKGLASS = lib.ramp(P.WINDOW_DARK_RAMP)
BRASS = lib.ramp(P.BRASS_RAMP)
SWOOD = lib.ramp(P.STORE_WOOD_RAMP)
STAN = lib.ramp(P.STORE_TAN_RAMP)
CANV = lib.ramp(X.CANVAS_RAMP)
CLOTH_RED = lib.ramp(X.CLOTH_RED)
ROPE = lib.ramp(X.ROPE)
TENT = lib.ramp(P.TENT_CANVAS_RAMP)
GRASS = lib.ramp(P.GRASS_SPRING_RAMP)
WEED = lib.ramp(P.LEAF_RAMP)
GGLASS = lib.ramp(P.GREENHOUSE_GLASS_RAMP)
STREAK = rgba(P.GLASS_STREAK)
CREAM = rgba(P.CREAM)
LAMP = rgba(P.LAMPLIGHT)
SOIL = lib.ramp(P.SOIL_RAMP)
INTERIOR = [rgba("#1a1008"), rgba("#24170c"), rgba("#2f1f12")]   # dark inside a building (warm)


def _dk(c, t=0.55):
    return mix(c, WARM, t)


def _hash(*key):
    """Deterministic pseudo-random float in [0, 1) for hand-placed variation."""
    h = 2166136261
    for k in repr(key).encode():
        h = ((h ^ k) * 16777619) & 0xFFFFFFFF
    return h / 2 ** 32


def _finish(s, shadow=None, local=0.6, skip=None):
    """Outline the body `s`, put a warm contact shadow under it, composite the body on top."""
    cv = Canvas(s.w, s.h)
    lib.outline(s, WARM, local=local, skip=skip)
    if shadow:
        cv.shadow(*shadow)
    cv.blit(s, 0, 0)
    return cv


def _rotated(src, angle_deg, pivot):
    """Nearest-neighbour rotation of a small Canvas about `pivot` (crooked signs)."""
    out = Canvas(src.w, src.h)
    a = math.radians(angle_deg)
    ca, sa = math.cos(a), math.sin(a)
    px, py = pivot
    for y in range(src.h):
        for x in range(src.w):
            dx, dy = x + 0.5 - px, y + 0.5 - py
            sx = ca * dx + sa * dy + px
            sy = -sa * dx + ca * dy + py
            ix, iy = int(math.floor(sx)), int(math.floor(sy))
            if 0 <= ix < src.w and 0 <= iy < src.h and src.a[iy, ix, 3]:
                out.a[y, x] = src.a[iy, ix]
    return out


# ================================================================================================
# shared surfaces
# ================================================================================================
def clapboard(s, x0, y0, x1, y1, R, board=3, seed=0, worn=0.0, missing=()):
    """Horizontal clapboard wall: each board's top row catches the light, its bottom row sits in
    the shadow of the board above. `R` = 5-step ramp. `worn` fraction of pixels showing bare
    wood through the paint. `missing` = [(x0, x1, board_index)] holes (left transparent)."""
    for y in range(y0, y1 + 1):
        k = (y - y0) % board
        bi = (y - y0) // board
        for x in range(x0, x1 + 1):
            if any(a <= x <= b and bi == n for (a, b, n) in missing):
                continue
            c = R[3] if k == 0 else (R[2] if k < board - 1 else R[1])
            if x == x0:
                c = mix(c, R[4], 0.5)
            joint = (x - x0 + bi * 11 + seed * 5) % 19 == 0
            if joint and k > 0:
                c = R[1]
            if worn and _hash("worn", seed, x // 2, y) < worn:
                c = mix(WOOD[3] if k == 0 else WOOD[2], c, 0.35)
            s.px(x, y, c)


def corrugated(s, x0, y0, x1, y1, R, seed=0, panel=12, tints=None, course=9):
    """Corrugated metal sheets seen from above: vertical ribs (lit / shaded columns), sheets of
    `panel` px wide with a slightly different tint each, horizontal overlaps every `course` rows
    down the slope (the upper sheet's lip catches the light, the lower one sits in its shadow),
    and the last rows above the eave a touch darker."""
    for x in range(x0, x1 + 1):
        pi = (x - x0) // panel
        tint = tints[pi % len(tints)] if tints else None
        stagger = (pi % 2) * (course // 2)
        for y in range(y0, y1 + 1):
            rib = (x - x0) % 3
            c = R[4] if rib == 0 else (R[3] if rib == 1 else R[2])
            if (x - x0) % panel == panel - 1:
                c = R[1]                                    # vertical seam
            k = (y - y0 + stagger) % course
            if k == course - 1:
                c = mix(c, R[5], 0.55)                      # lip of the upper sheet
            elif k == 0 and y > y0:
                c = mix(c, R[1], 0.45)                      # shadow under the lip
            if y >= y1 - 1:
                c = mix(c, R[1], 0.3)
            if tint is not None:
                c = mix(c, tint[0], tint[1])
            s.px(x, y, c)


def glass_window(s, x0, y0, w, h, lit=True, frame=None, mull=True, broken=False, seed=0):
    """Framed window. Lit: warm lamplight with a hot core and amber edges; unlit: dark glass with
    a cool sky glint. `broken` knocks jagged holes into unlit glass."""
    F = frame or WOOD
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            edge = x in (x0, x0 + w - 1) or y in (y0, y0 + h - 1)
            if edge:
                c = F[3] if (y == y0 or x == x0) else F[1]
            else:
                gx = (x - x0 - 1) / max(1, w - 3)
                gy = (y - y0 - 1) / max(1, h - 3)
                if lit:
                    d = math.hypot(gx - 0.4, (gy - 0.55) * 1.2)
                    c = GLOW[3] if d < 0.32 else GLOW[2] if d < 0.62 else GLOW[1]
                    if y == y0 + 1:
                        c = mix(c, GLOW[0], 0.45)          # the head of the frame shades the top
                else:
                    c = DARKGLASS[1] if gy > 0.35 else DARKGLASS[2]
                    if (x - x0) + (y - y0) in (3, 4) and gy < 0.6:
                        c = DARKGLASS[3]                    # sky glint
                    if broken and _hash("crack", seed, x, y) < 0.42 and gy > 0.15:
                        c = INTERIOR[0]
            s.px(x, y, c)
    if mull:
        mx = x0 + w // 2
        my = y0 + h // 2
        for y in range(y0 + 1, y0 + h - 1):
            s.px(mx, y, F[2])
        for x in range(x0 + 1, x0 + w - 1):
            s.px(x, my, F[2])
    # sill
    for x in range(x0 - 1, x0 + w + 1):
        s.px(x, y0 + h, F[4] if x < x0 + w else F[2])
        s.px(x, y0 + h + 1, F[1])


def plank_door(s, x0, y0, w, h, R=None, ajar=False):
    """Plank door in a frame. `ajar`: hangs open a crack - dark gap on the hinge side."""
    R = R or WOOD
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            frame = x in (x0, x0 + w - 1) or y == y0
            if frame:
                c = R[1] if x == x0 + w - 1 else R[2]
            else:
                k = (x - x0 - 1) % 3
                c = R[4] if k == 0 else R[3] if k == 1 else R[2]
                if y in (y0 + 3, y0 + h - 4):
                    c = R[2]                                # ledger boards
            s.px(x, y, c)
    if ajar:
        for y in range(y0 + 1, y0 + h):
            s.px(x0 + 1, y, INTERIOR[1])
            s.px(x0 + 2, y, INTERIOR[0])
    else:
        s.px(x0 + w - 3, y0 + h // 2, BRASS[3])            # knob
        s.px(x0 + w - 3, y0 + h // 2 + 1, BRASS[1])


def rubble(s, pts):
    """Loose debris at a wall base: (x, y, kind) with kind 'stone' | 'board' | 'chip'."""
    for (x, y, kind) in pts:
        if kind == "stone":
            s.px(x, y, STONE[4]); s.px(x + 1, y, STONE[3]); s.px(x + 2, y, STONE[2])
            s.px(x, y + 1, STONE[3]); s.px(x + 1, y + 1, STONE[2]); s.px(x + 2, y + 1, STONE[1])
        elif kind == "board":
            for k in range(6):
                s.px(x + k, y - (k // 3), WASH[2] if k % 4 else WOOD[2])
                s.px(x + k, y + 1 - (k // 3), WOOD[1])
        elif kind == "chip":
            s.px(x, y, STONE[3]); s.px(x + 1, y, STONE[2])


def weeds(s, x, y, h=3, R=None):
    """A small weed tuft standing on row y."""
    R = R or WEED
    pat = [(0, 0, 1), (0, -1, 3), (-1, 0, 2), (1, 0, 2), (1, -1, 4)]
    if h >= 3:
        pat += [(0, -2, 4), (-1, -1, 3)]
    if h >= 4:
        pat += [(1, -3, 5), (0, -3, 5)]
    for (dx, dy, k) in pat:
        s.px(x + dx, y + dy, R[k])


# ================================================================================================
# the clinic (64 x 56, footprint 4 x 3) - before and after
# ================================================================================================
CLINIC_W, CLINIC_H = 64, 56
C_EAVE = 27          # bottom row of the roof's fascia
C_WALL = (3, 60)     # wall x range
C_BASE = 52          # first foundation row
C_DOOR = (21, 38, 10, 14)        # x, y, w, h
C_WIN_R = (39, 33, 14, 12)
C_WIN_L = (8, 34, 8, 9)
C_SIGN = (18, 29, 16, 8)


def _clinic_roof_shape(x, y):
    """Inside test for the roof trapezoid (ridge narrower than the eave)."""
    if y < 4 or y > C_EAVE:
        return False
    inset = max(0, 3 - (y - 4) // 3)
    return inset <= x <= CLINIC_W - 1 - inset


def clinic(ruined):
    s = Canvas(CLINIC_W, CLINIC_H)
    # ---- walls --------------------------------------------------------------------------------
    wx0, wx1 = C_WALL
    missing = [(44, 50, 1), (9, 13, 5), (54, 57, 3), (27, 31, 6)] if ruined else ()
    wash = WASH if not ruined else [mix(c, P.ASH_BROWN, 0.25) for c in WASH]
    clapboard(s, wx0, C_EAVE + 1, wx1, C_BASE - 1, wash, seed=3,
              worn=0.22 if ruined else 0.04, missing=missing)
    if ruined:   # interior through the missing boards: darkness and a stud
        for (a, b, n) in missing:
            for y in range(C_EAVE + 1 + n * 3, C_EAVE + 4 + n * 3):
                for x in range(a, b + 1):
                    c = INTERIOR[0] if (x + y) % 5 else INTERIOR[1]
                    if x == (a + b) // 2:
                        c = WOOD[1]
                    s.px(x, y, c)
    # eave shadow on the top of the wall
    for x in range(wx0, wx1 + 1):
        for k, t in ((0, 0.55), (1, 0.3)):
            y = C_EAVE + 1 + k
            if s.alpha(x, y):
                s.px(x, y, mix(s.get(x, y), WARM, t))
    # corner posts + base trim
    for x0 in (wx0, wx1 - 1):
        for y in range(C_EAVE + 1, C_BASE):
            s.px(x0, y, WOOD[3] if x0 == wx0 else WOOD[2])
            s.px(x0 + 1, y, WOOD[2] if x0 == wx0 else WOOD[1])
    for x in range(wx0, wx1 + 1):
        s.px(x, C_BASE - 1, WOOD[2])
    # stone foundation
    for y in range(C_BASE, CLINIC_H):
        for x in range(wx0 - 1, wx1 + 2):
            course = (y - C_BASE)
            joint = (x + (course % 2) * 3) % 6 == 0
            c = STONE[4] if course == 0 else STONE[3] if course == 1 else STONE[2]
            if joint:
                c = STONE[1]
            if x >= wx1:
                c = mix(c, STONE[1], 0.4)
            s.px(x, y, c)
    # ---- windows / door -----------------------------------------------------------------------
    x, y, w, h = C_WIN_R
    if ruined:
        glass_window(s, x, y, w, h, lit=False, broken=True, seed=5,
                     frame=[mix(c, P.ASH_BROWN, 0.3) for c in WOOD])
    else:
        glass_window(s, x, y, w, h, lit=True)
    x, y, w, h = C_WIN_L
    glass_window(s, x, y, w, h, lit=not ruined, mull=True,
                 frame=WOOD if not ruined else [mix(c, P.ASH_BROWN, 0.3) for c in WOOD])
    if ruined:   # boarded: two planks nailed across
        for (yy, dy) in ((y + 2, 0), (y + 6, -1)):
            for k in range(w + 3):
                xx = x - 2 + k
                yy2 = yy + (k * dy) // (w + 2)
                s.px(xx, yy2, WOOD[4] if k % 5 else WOOD[3])
                s.px(xx, yy2 + 1, WOOD[2])
            _nail(s, x - 1, yy)
            _nail(s, x + w, yy + dy)
    x, y, w, h = C_DOOR
    plank_door(s, x, y, w, h, ajar=ruined,
               R=WOOD if not ruined else [mix(c, P.ASH_BROWN, 0.3) for c in WOOD])
    for k in range(-1, w + 1):                               # stone step
        s.px(x + k, C_BASE, STONE[5] if k < w - 1 else STONE[3])
    # ---- sign over the door -------------------------------------------------------------------
    s.blit(_clinic_sign(ruined), 0, 0)
    # ---- roof -----------------------------------------------------------------------------------
    roof = Canvas(CLINIC_W, CLINIC_H)
    tints = [(rgba("#8a8a84"), 0.0), (RUST[3], 0.18), (rgba("#a8a296"), 0.25), (RUST[2], 0.1),
             (rgba("#b8b0a0"), 0.3)]
    if ruined:
        tints = [(RUST[3], 0.35), (RUST[2], 0.45), (rgba("#6f6f68"), 0.3), (RUST[3], 0.5),
                 (RUST[2], 0.3)]
    corrugated(roof, 0, 6, CLINIC_W - 1, C_EAVE - 2, MET + [MET[5]], seed=1, panel=13,
               tints=tints)
    # trim to the trapezoid
    for yy in range(CLINIC_H):
        for xx in range(CLINIC_W):
            if roof.alpha(xx, yy) and not _clinic_roof_shape(xx, yy):
                roof.a[yy, xx] = 0
    # the far slope, just visible above the ridge (faces away from the light)
    for xx in range(4, CLINIC_W - 4):
        roof.px(xx, 2, mix(MET[2], RUST[1], 0.4 if ruined else 0.1))
        roof.px(xx, 3, mix(MET[1], RUST[1], 0.4 if ruined else 0.1))
    # ridge cap (fresh board) and fascia (eave board)
    for xx in range(CLINIC_W):
        if _clinic_roof_shape(xx, 5):
            roof.px(xx, 4, WOOD[5] if not ruined else WOOD[3])
            roof.px(xx, 5, WOOD[3] if not ruined else WOOD[2])
        roof.px(xx, C_EAVE - 1, WOOD[4] if not ruined else mix(WOOD[3], P.ASH_BROWN, 0.3))
        roof.px(xx, C_EAVE, WOOD[2] if not ruined else WOOD[1])
    if not ruined:
        # a run of fresh boards patching the right third of the roof
        for yy in range(7, C_EAVE - 1):
            for xx in range(44, 58):
                if not _clinic_roof_shape(xx, yy):
                    continue
                k = (yy - 7) % 4
                c = WOOD[5] if k == 0 else WOOD[4] if k < 3 else WOOD[3]
                if (xx + (yy // 4) * 5) % 9 == 0 and k:
                    c = WOOD[3]
                roof.px(xx, yy, c)
        for yy in (8, 12, 16, 20):
            _nail(roof, 45, yy)
            _nail(roof, 56, yy)
    else:
        _cave_in(roof)
    s.blit(roof, 0, 0)
    # ---- chimney (stove pipe) ---------------------------------------------------------------
    _stovepipe(s, 50, 13, bent=ruined)
    # ---- rubble at the base (ruined) ------------------------------------------------------------
    if ruined:
        # a fallen roof sheet leaning on the wall right of the door, boards and stones piled
        for k in range(11):
            for j in range(4):
                c = (MET[4], MET[3], MET[2], RUST[2])[j]
                s.px(32 + k // 3 + j, 44 + k, c)
        rubble(s, [(3, 52, "stone"), (6, 53, "stone"), (10, 54, "board"), (14, 53, "stone"),
                   (30, 54, "stone"), (36, 54, "board"), (44, 54, "stone"), (48, 53, "board"),
                   (55, 53, "stone"), (58, 52, "stone"), (19, 55, "chip"), (52, 55, "chip"),
                   (41, 55, "chip")])
        for (wx, wy, hh) in ((2, 55, 4), (17, 55, 3), (39, 55, 3), (61, 55, 3), (25, 55, 2),
                             (51, 55, 2)):
            weeds(s, wx, wy, hh)
    else:
        # wall lantern beside the door (night glow comes from the game's NightLight)
        lx, ly = 33, 39
        s.px(lx, ly - 1, MET[1]); s.px(lx + 1, ly - 1, MET[1])
        s.px(lx, ly, BRASS[3]); s.px(lx + 1, ly, BRASS[2])
        s.px(lx, ly + 1, GLOW[3]); s.px(lx + 1, ly + 1, GLOW[2])
        s.px(lx, ly + 2, GLOW[2]); s.px(lx + 1, ly + 2, GLOW[1])
        s.px(lx, ly + 3, BRASS[2]); s.px(lx + 1, ly + 3, BRASS[1])
    out = _finish(s, shadow=(33.0, 55.2, 33, 1.6))
    return out


def _clinic_sign(ruined):
    """White board with a red cross over the door. Ruined: faded, cracked, hanging from one nail."""
    x0, y0, w, h = C_SIGN
    sign = Canvas(CLINIC_W, CLINIC_H)
    board = [mix(c, P.ASH_BROWN, 0.35) for c in WASH] if ruined else WASH
    red = [mix(c, "#c9a39a", 0.55) for c in RED] if ruined else RED
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            edge = x in (x0, x0 + w - 1) or y in (y0, y0 + h - 1)
            c = board[2] if edge else board[4]
            if not edge and (y == y0 + h - 2 or x == x0 + w - 2):
                c = board[3]
            sign.px(x, y, c)
    cx = x0 + w // 2 - 1          # 2 px wide bars, centred
    cy = y0 + 1
    for y in range(cy, cy + 6):
        sign.px(cx, y, red[3]); sign.px(cx + 1, y, red[2])
    for x in range(cx - 2, cx + 4):
        sign.px(x, cy + 2, red[3] if x < cx + 2 else red[2])
        sign.px(x, cy + 3, red[2])
    sign.px(cx, cy, red[4])
    if ruined:
        # a crack running down from the top edge, paint flaked off one arm
        for (x, y) in ((x0 + 10, y0), (x0 + 10, y0 + 1), (x0 + 11, y0 + 2), (x0 + 11, y0 + 3),
                       (x0 + 12, y0 + 4)):
            sign.px(x, y, board[0])
        sign.px(cx + 3, cy + 2, board[4])
        sign.px(cx + 3, cy + 3, board[3])
        sign = _rotated(sign, -11, (x0 + 1.5, y0 + 0.5))
        _nail(sign, x0 + 1, y0)
        sign.px(x0 + w - 2, y0 - 1, WOOD[2])                # the lost nail's empty hook
    else:
        _nail(sign, x0 + 2, y0 + 1)
        _nail(sign, x0 + w - 3, y0 + 1)
    lib.outline(sign, WARM, local=0.6)
    return sign


def _cave_in(roof):
    """Ruined clinic: the middle of the roof has fallen in. Through the hole you look down into
    the room - the inside of the back wall at the top, the littered floor below - with a snapped
    rafter hanging into it, a sagging ridge, and torn, curled sheet edges around it."""
    hole = np.zeros((CLINIC_H, CLINIC_W), bool)
    cx, cy = 26.5, 15.5
    for y in range(4, C_EAVE - 2):
        for x in range(8, 46):
            dx = (x + 0.5 - cx) / 16.0
            dy = (y + 0.5 - cy) / 9.0
            wob = 0.18 * math.sin(x * 1.3 + y * 0.7) + 0.12 * math.sin(x * 0.45 - y * 1.9)
            if dx * dx + dy * dy < 1.0 + wob:
                hole[y, x] = True
    ys, xs = np.nonzero(hole)
    top = ys.min()
    # interior: back wall (inner face, dark boards) above, floor with debris below
    for y, x in zip(ys, xs):
        if y < top + 5:
            k = (y - top) % 3
            c = INTERIOR[2] if k == 0 else INTERIOR[1]
            if (x * 7) % 13 == 0:
                c = INTERIOR[0]
        else:
            c = INTERIOR[0] if (x + 2 * y) % 6 else INTERIOR[1]
        roof.a[y, x] = c
    # fallen sheets and boards on the floor (lit, so they read as debris, not as holes)
    for (x0, y0, n, kind) in ((15, 19, 7, "sheet"), (30, 17, 6, "board"), (24, 21, 5, "sheet"),
                              (36, 20, 4, "board")):
        for k in range(n):
            x, y = x0 + k, y0 - (k // 3 if kind == "board" else 0)
            if hole[y, x]:
                if kind == "sheet":
                    roof.px(x, y, MET[3] if k % 3 else MET[4])
                    if hole[y + 1, x]:
                        roof.px(x, y + 1, RUST[1])
                else:
                    roof.px(x, y, WOOD[3])
                    if hole[y + 1, x]:
                        roof.px(x, y + 1, WOOD[1])
    # torn, bent sheet edges: lit lip on the far side of the hole, rusty curl on the near side
    pad = np.pad(hole, 1)
    up, down = pad[:-2, 1:-1], pad[2:, 1:-1]
    left, right = pad[1:-1, :-2], pad[1:-1, 2:]
    body = roof.a[:, :, 3] > 0
    lip = ~hole & (down | right) & body
    curl = ~hole & (up | left) & body
    for y, x in zip(*np.nonzero(lip)):
        roof.px(x, y, MET[5] if _hash("lip", x, y) < 0.55 else MET[4])
    for y, x in zip(*np.nonzero(curl)):
        roof.px(x, y, RUST[1] if _hash("curl", x, y) < 0.5 else RUST[2])
    # two rafters still spanning the hole, one snapped and hanging into it
    for rx in (17, 34):
        for y in range(top - 1, C_EAVE - 2):
            x = rx + (1 if y > 16 else 0)
            if hole[y, x] or hole[y, x + 1]:
                roof.px(x, y, WOOD[3])
                roof.px(x + 1, y, WOOD[1])
    for k in range(7):                       # upper stub of the snapped rafter
        x, y = 26, top + k
        if hole[y, x]:
            roof.px(x, y, WOOD[3]); roof.px(x + 1, y, WOOD[1])
    for k in range(6):                       # its broken end, dropped and angled into the room
        x, y = 24 - k // 2, 14 + k
        if hole[y, x]:
            roof.px(x, y, WOOD[4]); roof.px(x + 1, y, WOOD[2])
    # the sagging ridge beam
    for x in range(6, 50):
        sag = int(round(2.5 * math.sin(math.pi * (x - 6) / 44.0)))
        y = 4 + sag
        roof.px(x, y, WOOD[3])
        roof.px(x, y + 1, WOOD[1])


def _stovepipe(s, x, base_y, bent=False):
    """Tin stove pipe rising out of the roof with a little conical cap."""
    pts = [(x, base_y - k) for k in range(10)]
    if bent:
        pts = [(x, base_y), (x, base_y - 1), (x, base_y - 2), (x + 1, base_y - 3),
               (x + 2, base_y - 4), (x + 3, base_y - 4), (x + 4, base_y - 5)]
    for (px_, py_) in pts:
        s.px(px_, py_, MET[4])
        s.px(px_ + 1, py_, MET[3])
        s.px(px_ + 2, py_, MET[2])
    tx, ty = pts[-1]
    if not bent:
        for k, c in enumerate((MET[3], MET[4], MET[3], MET[2], MET[1])):
            s.px(tx - 1 + k, ty - 1, c)
        s.px(tx, ty - 2, MET[4]); s.px(tx + 1, ty - 2, MET[3]); s.px(tx + 2, ty - 2, MET[2])
        for k in range(3):
            s.px(tx + k, ty, MET[1])                       # dark gap under the cap
    else:
        s.px(tx + 3, ty, RUST[2]); s.px(tx + 3, ty + 1, RUST[1])
    for k in range(4):                                     # flashing collar on the roof
        s.px(x - 1 + k, base_y + 1, MET[2] if k else MET[3])



# ================================================================================================
# Marta's store, expanded (48 x 48, footprint 3 x 2)
# ================================================================================================
STORE_W, STORE_H = 48, 48
CORAL = [rgba("#7a3324"), rgba("#a8492f"), rgba("#cf6a4a"), rgba("#e88866")]  # store.png roof cap


def store_expanded():
    """The same shop as store.png grown up: wine-brown boards, the tan trim band and the coral
    roof cap carried over; new: a striped canvas awning, a big hand-painted sign on the roof, a
    plank porch with produce crates and barrels, a wider lit front."""
    s = Canvas(STORE_W, STORE_H)
    W = SWOOD
    # ---- front wall (boards, vertical seams), y 24..43 -------------------------------------------
    for y in range(24, 44):
        for x in range(1, 47):
            k = (x - 1) % 5
            c = W[4] if k == 0 else W[3] if k < 3 else W[2]
            if k == 4:
                c = W[1]
            if x <= 2:
                c = W[5] if x == 1 else W[4]
            if x >= 45:
                c = W[1]
            s.px(x, y, c)
    # ---- big display window (left) with jars and a hanging bunch ---------------------------------
    glass_window(s, 4, 28, 14, 10, lit=True, frame=STAN, mull=False)
    for (jx, jc) in ((6, X.GLASS_GREEN), (9, X.GLASS_BROWN), (13, X.GLASS_GREEN), (15, X.GLASS_BROWN)):
        g = lib.ramp(jc)
        s.px(jx, 35, g[1]); s.px(jx, 34, g[2]); s.px(jx + 1, 35, g[0]); s.px(jx + 1, 34, g[1])
        s.px(jx, 33, MET[3])
    for x in range(5, 17):
        s.px(x, 36, STAN[1])                                  # display shelf
    for (hx, hy) in ((8, 29), (11, 29)):
        s.px(hx, hy, rgba(P.SPRING["green"])); s.px(hx, hy + 1, LEAF_DARK)
    # ---- door, open: warm interior and a sack inside ---------------------------------------------
    dx0, dy0, dw, dh = 21, 30, 8, 14
    for y in range(dy0, dy0 + dh):
        for x in range(dx0, dx0 + dw):
            frame = x in (dx0, dx0 + dw - 1) or y == dy0
            if frame:
                c = STAN[3] if (x == dx0 or y == dy0) else STAN[1]
            else:
                d = (y - dy0) / dh
                c = GLOW[2] if d < 0.45 else GLOW[1] if d < 0.8 else mix(GLOW[0], WARM, 0.3)
                if x == dx0 + 1:
                    c = mix(c, WARM, 0.35)
            s.px(x, y, c)
    for x in range(dx0 + 1, dx0 + 3):                         # the open door leaf, edge-on
        for y in range(dy0 + 1, dy0 + dh):
            s.px(x, y, W[4] if x == dx0 + 1 else W[2])
    # ---- right window ----------------------------------------------------------------------------
    glass_window(s, 32, 28, 12, 9, lit=True, frame=STAN)
    # ---- awning: red / cream stripes sloping out, scalloped valance (cf. market_stall.png) --------
    red = CLOTH_RED
    for y in range(18, 25):
        inset = max(0, 2 - (y - 18) // 2)
        for x in range(inset, STORE_W - inset):
            stripe = (x // 4) % 2 == 0
            if stripe:
                c = red[3] if y < 22 else red[2]
            else:
                c = CANV[4] if y < 22 else CANV[3]
            if y == 18:
                c = mix(c, CREAM, 0.35)
            if x >= STORE_W - 6:
                c = mix(c, WARM, 0.18)
            s.px(x, y, c)
    for x in range(STORE_W):
        stripe = (x // 4) % 2 == 0
        k = x % 4
        depth = 2 if k in (1, 2) else 1
        for d in range(depth):
            c = (red[1] if stripe else CANV[2]) if d == depth - 1 else (red[2] if stripe else CANV[3])
            s.px(x, 25 + d, c)
    # shadow the awning throws on the wall
    for x in range(1, 47):
        for k, t in ((0, 0.5), (1, 0.25)):
            y = 27 + k
            if s.alpha(x, y) == 255 and not (4 <= x <= 17 and y >= 28) and not (32 <= x <= 43 and y >= 28):
                s.px(x, y, mix(s.get(x, y), WARM, t))
    # ---- facade above the awning: tan trim band (as store.png) and the dark cornice --------------
    for y in range(12, 18):
        for x in range(1, 47):
            if y in (12, 17):
                c = W[1] if y == 17 else W[2]
            else:
                bar = (x - 1) % 4
                c = STAN[3] if bar == 0 else STAN[2] if bar == 1 else W[1] if bar == 2 else W[0]
                if y == 13 and bar < 2:
                    c = STAN[4]
                if y == 16 and bar < 2:
                    c = STAN[1]
            s.px(x, y, c)
    # roof cap: dark band with the coral top edge (the old store's)
    for y in range(8, 12):
        for x in range(0, 48):
            if y == 8:
                c = CORAL[3] if 6 <= x < 41 else CORAL[2]
                if x in (0, 47):
                    c = CORAL[1]
            elif y == 9:
                c = CORAL[1]
            else:
                c = W[1] if (x + y) % 7 else W[0]
            s.px(x, y, c)
    # ---- the hand-painted sign on the roof (no readable text) ------------------------------------
    sign = Canvas(STORE_W, STORE_H)
    for x0 in (10, 36):                                       # two posts behind it
        for y in range(6, 9):
            sign.px(x0, y, WOOD[2]); sign.px(x0 + 1, y, WOOD[1])
    bx0, by0, bw, bh = 5, 0, 38, 8
    for y in range(by0, by0 + bh):
        for x in range(bx0, bx0 + bw):
            edge = x in (bx0, bx0 + bw - 1) or y in (by0, by0 + bh - 1)
            c = STAN[1] if edge else (CANV[4] if y < by0 + 3 else CANV[3])
            if edge and (y == by0 or x == bx0):
                c = STAN[2]
            sign.px(x, y, c)
    paint = rgba(P.MEDIC_RED_RAMP[1])
    # a painted sunbloom at the left: petals + seed head
    for (px_, py_, c) in ((8, 2, LAMP), (10, 2, LAMP), (8, 4, LAMP), (10, 4, LAMP), (9, 3, WOOD[1]),
                          (9, 1, GLOW[1]), (9, 5, GLOW[1]), (7, 3, GLOW[1]), (11, 3, GLOW[1]),
                          (9, 6, rgba(P.LEAF_GREEN))):
        sign.px(px_, py_, c)
    # brush-stroke lettering: a cursive wave of loops, deliberately not any real letters
    wave = [3, 2, 2, 3, 4, 4, 3, 3, 2, 3, 4, 4, 3, 2, 2, 3]
    for k, y in enumerate(wave):
        x = 15 + k
        sign.px(x, y, paint)
        if k in (2, 6, 9, 13):
            sign.px(x, y + 1, paint)
            sign.px(x, y + 2, paint)
    for k, y in enumerate([4, 3, 3, 4, 5, 5]):
        sign.px(32 + k, y, paint)
    sign.px(33, 2, paint)                                     # a dot over the second word
    for x in range(15, 38):                                    # underline flourish
        if x % 6 not in (4, 5):
            sign.px(x, 6, mix(paint, CANV[3], 0.45))
    # a painted crate at the right
    for (px_, py_) in ((39, 3), (40, 3), (41, 3), (39, 4), (41, 4), (39, 5), (40, 5), (41, 5)):
        sign.px(px_, py_, WOOD[2])
    sign.px(40, 4, WOOD[4])
    lib.outline(sign, WARM, local=0.6)
    # ---- porch deck + goods out front ------------------------------------------------------------
    for y in range(44, 48):
        for x in range(0, 48):
            k = (y - 44)
            c = WOOD[4] if k == 0 else WOOD[3] if k < 3 else WOOD[2]
            if (x + (y - 44) * 7) % 12 == 0 and k:
                c = WOOD[2]
            s.px(x, y, c)
    body = _finish(s, shadow=None)
    body.blit(sign, 0, 0)
    # goods on the porch: two low crates of produce and a sack (left), a barrel of grain and a
    # crate of greens (right); kept below the window sills so the lit front still shows
    layers = []
    for (x0, y0, cols, w) in ((2, 41, PRODUCE[0], 7), (9, 42, PRODUCE[1], 6), (37, 42, PRODUCE[2], 6)):
        g = Canvas(STORE_W, STORE_H)
        _produce_crate(g, x0, y0, cols, w=w)
        layers.append(g)
    sack = Canvas(STORE_W, STORE_H)
    for (x, y, c) in ((16, 41, CANV[3]), (17, 41, CANV[2]), (15, 42, CANV[4]), (16, 42, CANV[3]),
                      (17, 42, CANV[2]), (18, 42, CANV[1]), (15, 43, CANV[3]), (16, 43, CANV[3]),
                      (17, 43, CANV[2]), (18, 43, CANV[1]), (15, 44, CANV[2]), (16, 44, CANV[2]),
                      (17, 44, CANV[1]), (18, 44, CANV[1]), (16, 40, ROPE[1]), (17, 40, ROPE[0])):
        sack.px(x, y, c)
    layers.append(sack)
    barrel = Canvas(STORE_W, STORE_H)
    _barrel_body(barrel, 43.0, 46, 2.8, 38, WOOD, hoops=(2, 5))
    for y in range(36, 40):                                     # open top heaped with grain
        for x in range(40, 48):
            ddx = (x + 0.5 - 43.0) / 3.4
            ddy = (y + 0.5 - 38.0) / 1.6
            if ddx * ddx + ddy * ddy <= 1:
                rim = ddx * ddx + ddy * ddy > 0.5
                barrel.px(x, y, (WOOD[4] if ddy < 0 else WOOD[2]) if rim else
                          (STRAW_G[3] if ddy < 0.0 else STRAW_G[2]))
    layers.insert(0, barrel)
    out = body
    for layer in layers:
        lib.outline(layer, WARM, local=0.6)
        out.blit(layer, 0, 0)
    out.shadow(24.0, 47.4, 24, 1.0)
    return out


LEAF_DARK = rgba(P.LEAF_RAMP[1])
STRAW_G = lib.ramp(X.STRAW)
PRODUCE = [
    ["#5a3a28", "#8c5a38", "#b07850"],      # mutant potatoes
    ["#8a6a10", "#e1b030", "#ffd860"],      # sunbloom heads
    ["#3e5a2a", "#5d7d3a", "#95ac49"],      # greens
]


def _produce_crate(s, x0, y0, cols, w=8):
    """Low open crate heaped with round produce (front face = slats)."""
    R = lib.ramp(cols)
    h = 6
    for y in range(y0 + 2, y0 + h + 2):
        for x in range(x0, x0 + w):
            k = (y - y0 - 2)
            c = WOOD[4] if k in (0, 3) else WOOD[3] if k in (1, 4) else WOOD[2]
            if x == x0:
                c = mix(c, WOOD[5], 0.4)
            if x == x0 + w - 1:
                c = WOOD[1]
            s.px(x, y, c)
    for i in range(w - 1):
        for (dy, k) in ((1, 1), (0, 2)):
            if (i + dy) % 2 == 0 or dy == 1:
                s.px(x0 + i, y0 + dy, R[k])
    for i in range(1, w - 2, 2):
        s.px(x0 + i, y0 - 1, R[2])
        s.px(x0 + i + 1, y0 - 1, R[1])
    s.px(x0 + 1, y0, mix(R[2], CREAM, 0.4))


# ================================================================================================
# the west watchtower (32 x 64, footprint 2 x 2)
# ================================================================================================
TOWER_W, TOWER_H = 32, 64


def _beam(s, x0, y0, x1, y1, R, w=2, lit=True):
    """A timber from (x0, y0) to (x1, y1), w px thick, lit on its left / top edge."""
    pts = lib.line_points(x0, y0, x1, y1)
    steep = abs(y1 - y0) >= abs(x1 - x0)
    for (x, y) in pts:
        for k in range(w):
            c = (R[4] if k == 0 else R[2] if k == w - 1 else R[3]) if lit else \
                (R[2] if k == 0 else R[1])
            if steep:
                s.px(x + k, y, c)
            else:
                s.px(x, y + k, c)


def watchtower():
    """Four braced timber legs (front pair on the footprint's front row, back pair a row further
    back), a ladder up the front, a railed lookout platform under a plank roof and a hanging
    lantern (its night glow comes from the game)."""
    s = Canvas(TOWER_W, TOWER_H)
    back = Canvas(TOWER_W, TOWER_H)
    W = WOOD
    WD = [mix(c, WARM, 0.32) for c in W]                     # timbers in the tower's own shade
    # -- back legs (behind everything, in shade) --
    _beam(back, 8, 24, 6, 47, WD, w=2)
    _beam(back, 22, 24, 24, 47, WD, w=2)
    for x in range(7, 25):
        back.px(x, 38, WD[2]); back.px(x, 39, WD[1])
    lib.outline(back, WARM, local=0.6)
    # -- front legs (splayed out toward the ground), one X brace per tier, ties --
    _beam(s, 5, 23, 1, 62, W, w=2)
    _beam(s, 25, 23, 29, 62, W, w=2)
    for (y, a, b) in ((40, 3, 28), (58, 1, 30)):
        for x in range(a, b + 1):
            s.px(x, y, W[4]); s.px(x, y + 1, W[2])
    for (x0, y0, x1, y1) in ((7, 25, 25, 39), (24, 25, 6, 39), (5, 43, 27, 57), (26, 43, 4, 57)):
        for (x, y) in lib.line_points(x0, y0, x1, y1):
            s.px(x, y, W[4])
            s.px(x, y + 1, W[1])
    for (x, y) in ((6, 25), (25, 25), (4, 41), (27, 41), (2, 58), (29, 58)):
        _nail(s, x, y)
    # stone footings
    for (fx, fw) in ((0, 4), (28, 4)):
        for x in range(fx, fx + fw):
            s.px(x, 62, STONE[4] if x < fx + 2 else STONE[3])
            s.px(x, 63, STONE[2])
    # -- the ladder up the front --
    for y in range(22, 63):
        s.px(13, y, W[4]); s.px(18, y, W[2])
        if (y - 23) % 4 == 0:
            for x in range(14, 18):
                s.px(x, y, W[5] if x < 16 else W[4])
                s.px(x, y + 1, W[1])
    # -- platform: floor beam, railing, corner posts up to the roof --
    for y in range(20, 24):
        for x in range(1, 31):
            c = W[5] if y == 20 else W[4] if y == 21 else W[2] if y == 22 else W[1]
            if (x + 3) % 7 == 0 and y in (21, 22):
                c = W[2]
            s.px(x, y, c)
    for x0 in (2, 28):
        for y in range(7, 20):
            s.px(x0, y, W[4] if x0 == 2 else W[3]); s.px(x0 + 1, y, W[2] if x0 == 2 else W[1])
    for x in range(2, 30):
        s.px(x, 13, W[5] if x < 28 else W[3]); s.px(x, 14, W[2])     # top rail
        s.px(x, 17, W[4]); s.px(x, 18, W[1])                          # mid rail
    for x0 in (9, 15, 22):                                            # balusters
        for y in range(15, 20):
            s.px(x0, y, W[4]); s.px(x0 + 1, y, W[2])
    # the inside of the lookout, seen through the railing (shade under the roof)
    for y in range(8, 13):
        for x in range(4, 28):
            s.px(x, y, mix(W[0], WARM, 0.3) if y < 10 else W[1])
    for y in range(15, 20):
        for x in range(4, 28):
            if s.alpha(x, y) == 0:
                s.px(x, y, mix(W[1], WARM, 0.2))
    # -- plank roof (low hip, seen from above) --
    for y in range(0, 8):
        inset = max(0, 6 - y)
        for x in range(inset, TOWER_W - inset):
            k = y % 3
            c = W[5] if k == 0 else W[4] if k == 1 else W[3]
            if x > 22:
                c = mix(c, W[1], 0.25)
            if (x + y * 5) % 8 == 0 and k:
                c = W[2]
            if y == 7:
                c = W[1]
            s.px(x, y, c)
    for x in range(10, 22):                                   # ridge cap
        s.px(x, 0, MET[4] if x < 18 else MET[3])
    # -- the lantern, hung from the eave at the front right --
    lx = 24
    s.px(lx, 8, MET[1]); s.px(lx, 9, MET[2])
    for (dx, dy, c) in ((-1, 10, BRASS[3]), (0, 10, BRASS[3]), (1, 10, BRASS[2]),
                        (-1, 11, GLOW[3]), (0, 11, GLOW[4]), (1, 11, GLOW[2]),
                        (-1, 12, GLOW[2]), (0, 12, GLOW[3]), (1, 12, GLOW[1]),
                        (-1, 13, BRASS[2]), (0, 13, BRASS[2]), (1, 13, BRASS[1])):
        s.px(lx + dx, dy, c)
    lib.outline(s, WARM, local=0.6)
    out = Canvas(TOWER_W, TOWER_H)
    out.shadow(16.5, 63.0, 15, 1.5)
    out.blit(back, 0, 0)
    out.blit(s, 0, 0)
    return out


# ================================================================================================
# the farm greenhouse: wall pieces for an 8 x 6 footprint (restored and ruined)
# ================================================================================================
# The walls ring the footprint: north wall = row 0 (greenhouse_back, 128x32, bottom 16 px on the
# row), west / east walls = columns 0 / 7 on rows 1-4 (greenhouse_side, 16x64; the game mirrors it
# for the east wall and draws it as one 16x16 slice per row), south wall = row 5 (greenhouse_front,
# 128x24, bottom 16 px on the row) with a door gap at column 3 (x 48-63). The wall line runs down
# the middle of the edge cells: the side band is x 4-10 of its column (117-123 on the east), and
# the back / front walls end in 7 px corner posts on exactly those columns, so the pieces meet.
GH_W = 128
GH_BAND = (4, 10)            # side band columns (west strip); east = 127 - x
GH_POSTS = (24, 40, 56, 72, 88, 104)     # intermediate post centres (cell centres)
GH_DOOR = (48, 63)
GH_GLASS_A = 140             # pane alpha (spec: ~120-170)
GH_STREAK_A = 205


def _gh_ramps(ruined):
    frame = lib.ramp(P.GH_FRAME_RAMP)
    brick = lib.ramp(P.GH_BRICK_RAMP)
    if ruined:
        frame = [mix(MET[k], WARM, 0.25) for k in range(5)]      # bare, darkened steel...
        brick = [mix(c, P.ASH_BROWN, 0.3) for c in brick]
    return frame, brick


def _rust_mottle(s, frame, seed):
    """...eaten by rust in clustered patches and run-off streaks (ruined greenhouse frame)."""
    keys = {tuple(c[:3]): k for k, c in enumerate(frame)}
    for y in range(s.h):
        for x in range(s.w):
            k = keys.get(tuple(int(v) for v in s.a[y, x, :3])) if s.a[y, x, 3] == 255 else None
            if k is None:
                continue
            r = _hash("rust", seed, x // 2, y // 3)
            streak = _hash("runoff", seed, x) < 0.18
            if r < 0.55 or streak:
                s.a[y, x] = RUST[min(4, k)] if r < 0.3 else mix(RUST[min(4, k)], frame[k], 0.4)


def _gh_pane(s, x0, y0, x1, y1, seed, alpha=GH_GLASS_A, ruined=False):
    """One pane of glass (translucent). Restored: pale blue-green, a little denser low down where
    it reflects the ground, with white diagonal highlight streaks. Ruined: mostly gone - only a
    jagged shard or two left in the corners."""
    G = GGLASS
    w, h = x1 - x0 + 1, y1 - y0 + 1
    if not ruined:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                t = (y - y0) / max(1, h - 1)
                c = G[3] if t < 0.25 else G[2] if t < 0.75 else G[1]
                a = alpha if t < 0.75 else min(170, alpha + 22)
                s.px(x, y, rgba(c, a))
        if _hash("streak", seed) < 0.75:
            off = int(_hash("off", seed) * max(1, w - 2))
            for k in range(min(w, h)):
                for d in (0, 2):
                    x = x0 + off + k - d
                    y = y1 - k - 1
                    if x0 <= x <= x1 and y0 <= y <= y1 and (d == 0 or k % 2 == 0):
                        s.px(x, y, rgba(STREAK, GH_STREAK_A if d == 0 else 150))
        return
    # ruined: shards anchored to the frame (bottom corners mostly), jagged hypotenuse
    corners = []
    r = _hash("shard", seed)
    if r < 0.45:
        corners.append(("bl", 0.55 + 0.4 * _hash("sz", seed)))
    if 0.25 < r < 0.7:
        corners.append(("tr", 0.35 + 0.3 * _hash("sz2", seed)))
    if r > 0.8:
        corners.append(("br", 0.45))
    for (corner, size) in corners:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                u = (x - x0) / max(1, w - 1)
                v = (y - y0) / max(1, h - 1)
                if corner == "bl":
                    d = u + (1 - v)
                elif corner == "br":
                    d = (1 - u) + (1 - v)
                else:
                    d = (1 - u) + v
                jag = 0.12 * math.sin(x * 2.3 + y * 1.7 + seed)
                if d < size + jag:
                    c = G[2] if d < size * 0.6 else G[3]
                    s.px(x, y, rgba(c, GH_GLASS_A + 10))
                    if abs(d - (size + jag)) < 0.09:
                        s.px(x, y, rgba(STREAK, 190))       # the broken edge glints


def _gh_post(s, x0, x1, y0, y1, F, cap=True):
    """A square frame post: lit left column, shaded right column, a cap on top."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = F[4] if x == x0 else F[1] if x == x1 else F[3] if x - x0 < (x1 - x0 + 1) // 2 + 1 else F[2]
            s.px(x, y, c)
    if cap:
        for x in range(x0, x1 + 1):
            s.px(x, y0, F[4] if x < x1 else F[2])


def _gh_brick(s, x0, x1, y0, y1, B, ruined, seed=0):
    for y in range(y0, y1 + 1):
        course = (y - y0) // 2
        for x in range(x0, x1 + 1):
            joint_v = (x + course * 3) % 6 == 0
            top = (y - y0) % 2 == 0
            c = B[3] if top else B[2]
            if y == y0:
                c = B[4]
            if joint_v and y > y0:
                c = B[1]
            if y == y1:
                c = B[1]
            if ruined and _hash("brick", seed, x // 3, course) < 0.12 and y > y0:
                c = B[0]                                         # a brick fallen out
            s.px(x, y, c)


def _gh_weeds(s, xs, y, seed):
    for x in xs:
        weeds(s, x, y, 3 if _hash("wh", seed, x) < 0.6 else 4)


def _gh_wall(width_px, height, sill_y, base_y, posts, door, ruined, seed, vent=False, plate=False):
    """A south-facing glass wall (back or front piece): top rail, panes split by a transom,
    intermediate posts at cell centres, corner posts on the side-band columns, sill rail and a
    brick plinth down to the bottom row."""
    F, B = _gh_ramps(ruined)
    s = Canvas(width_px, height)
    glass = Canvas(width_px, height)
    L, R_ = GH_BAND[0], GH_W - 1 - GH_BAND[0]               # outer faces of the corner posts
    top = 1
    transom = top + 3 + (sill_y - top - 3) // 2
    # plinth
    _gh_brick(s, L, R_, sill_y + 2, base_y, B, ruined, seed)
    # panes between posts
    cols = [GH_BAND[1]] + [p for p in posts] + [GH_W - 1 - GH_BAND[1]]
    for i in range(len(cols) - 1):
        a = cols[i] + 2
        b = cols[i + 1] - 2
        if door and a <= door[1] and b >= door[0]:
            continue
        for (y0, y1) in ((top + 3, transom - 1), (transom + 1, sill_y - 1)):
            sx0, sx1 = a, b
            if door:                                        # panes stop at the door posts
                if a < door[0] <= b:
                    sx1 = door[0] - 5
                if a <= door[1] < b:
                    sx0 = door[1] + 5
            if sx1 <= sx0:
                continue
            _gh_pane(glass, sx0, y0, sx1, y1, seed * 97 + i * 7 + y0, ruined=ruined)
    # frame: top rail, transom, sill rail
    for x in range(L, R_ + 1):
        if door and door[0] - 4 <= x <= door[1] + 4:
            continue
        s.px(x, top, F[4]); s.px(x, top + 1, F[3]); s.px(x, top + 2, F[1])
        s.px(x, transom, F[3])
        s.px(x, sill_y, F[4]); s.px(x, sill_y + 1, F[2])
    # posts
    for c in posts:
        if door and door[0] - 4 <= c <= door[1] + 4:
            continue
        _gh_post(s, c - 1, c + 1, top, sill_y + 1, F)
    if door:
        for (a, b) in ((door[0] - 4, door[0] - 1), (door[1] + 1, door[1] + 4)):
            _gh_post(s, a, b, 0, base_y, F)
    _gh_post(s, GH_BAND[0], GH_BAND[1], 0, base_y, F)
    _gh_post(s, GH_W - 1 - GH_BAND[1], GH_W - 1 - GH_BAND[0], 0, base_y, F)
    if vent and not ruined:
        # a top-hung vent panel propped open: shorter, darker, with a strut
        vx0, vx1 = 74, 86
        for y in range(top + 3, transom):
            for x in range(vx0, vx1 + 1):
                glass.a[y, x] = 0
        for x in range(vx0, vx1 + 1):
            s.px(x, top + 3, F[3])
            for y in range(top + 4, top + 7):
                glass.px(x, y, rgba(GGLASS[3], 175))
            s.px(x, top + 7, F[2])
        for y in range(top + 8, transom):
            for x in range(vx0, vx1 + 1):
                glass.px(x, y, rgba(GGLASS[0], 110))           # the opening, darker
        s.px(vx1 - 2, top + 8, F[2]); s.px(vx1 - 2, top + 9, F[1])   # strut
    if ruined:
        _rust_mottle(s, F, seed)
    if plate:
        px0, py0 = 57, sill_y + 3
        plate_cv = Canvas(width_px, height)
        for y in range(py0, py0 + 4):
            for x in range(px0, px0 + 14):
                edge = y in (py0, py0 + 3) or x in (px0, px0 + 13)
                plate_cv.px(x, y, BRASS[2] if edge else BRASS[3])
        for x in range(px0 + 2, px0 + 12):
            if x % 3 != 1:
                plate_cv.px(x, py0 + 1 + (x % 2), BRASS[1])     # engraved marks, not letters
        plate_cv.px(px0 + 1, py0 + 1, BRASS[4]); plate_cv.px(px0 + 12, py0 + 1, BRASS[4])
        if ruined:
            plate_cv = _rotated(plate_cv, 16, (px0 + 1.5, py0 + 1.5))
        lib.outline(plate_cv, WARM, local=0.6)
        s.blit(plate_cv, 0, 0)
    return s, glass


def _gh_ruin(s, glass, which, seed):
    """Ruined greenhouse extras: bent / missing bars, a fallen strut, weeds at the base."""
    F, B = _gh_ramps(True)
    h = s.h
    if which == "back":
        # a transom bar bent down, a missing stretch of top rail, a fallen strut across two panes
        for x in range(30, 37):
            s.px(x, 1, F[1])                                  # a dented stretch of top rail
        for x in range(44, 52):
            s.a[1:4, x] = 0
        for (x, y) in lib.line_points(92, 3, 110, 22):
            s.px(x, y, F[3]); s.px(x + 1, y, F[1])
        for (x, y) in lib.line_points(58, 12, 66, 15):
            s.px(x, y, F[2])
        _gh_weeds(s, (8, 20, 37, 53, 79, 100, 119), h - 1, seed)
    elif which == "front":
        for (x, y) in lib.line_points(14, 2, 33, 15):
            s.px(x, y, F[3]); s.px(x, y + 1, F[1])
        for x in range(96, 104):
            s.a[1:4, x] = 0
        _gh_weeds(s, (6, 30, 43, 70, 92, 113, 121), h - 1, seed)


def greenhouse_back(ruined=False):
    s, glass = _gh_wall(GH_W, 32, 23, 31, GH_POSTS, None, ruined, seed=11, vent=True, plate=True)
    if ruined:
        _gh_ruin(s, glass, "back", 11)
    out = Canvas(GH_W, 32)
    out.blit(glass, 0, 0)
    lib.outline(s, WARM, local=0.6)
    out.blit(s, 0, 0)
    return out


def greenhouse_front(ruined=False):
    s, glass = _gh_wall(GH_W, 24, 15, 23, GH_POSTS, GH_DOOR, ruined, seed=23)
    if ruined:
        _gh_ruin(s, glass, "front", 23)
    out = Canvas(GH_W, 24)
    out.blit(glass, 0, 0)
    lib.outline(s, WARM, local=0.6)
    out.blit(s, 0, 0)
    for y in range(24):                                     # the doorway stays clear
        for x in range(GH_DOOR[0], GH_DOOR[1] + 1):
            out.a[y, x] = 0
    return out


def greenhouse_side(ruined=False):
    """West wall, rows 1-4, seen from above: two frame rails with the glass between them and a
    post at the middle of every row (each 16 px slice is drawn and sorted on its own row)."""
    F, B = _gh_ramps(ruined)
    s = Canvas(16, 64)
    glass = Canvas(16, 64)
    a, b = GH_BAND
    for y in range(64):
        s.px(a, y, F[3]); s.px(a + 1, y, F[2])
        s.px(b - 1, y, F[3]); s.px(b, y, F[1])
        for x in range(a + 2, b - 1):
            if not ruined:
                glass.px(x, y, rgba(GGLASS[2] if x == a + 2 else GGLASS[1], GH_GLASS_A + 15))
    if not ruined:
        for y in range(2, 64, 16):                                   # glints along the glass
            for k in range(3):
                glass.px(a + 3, y + k, rgba(STREAK, GH_STREAK_A))
    for row in range(4):
        cy = row * 16 + 7
        _gh_post(s, a, b, cy - 1, cy + 1, F)
    if ruined:
        _rust_mottle(s, F, 31)
        # glass gone except a few shards; one rail broken; a strut fallen across; weeds
        for (x, y) in ((a + 2, 12), (a + 2, 13), (a + 3, 13), (a + 2, 40), (a + 2, 41), (a + 3, 41),
                       (a + 4, 41), (a + 3, 54)):
            glass.px(x, y, rgba(GGLASS[2], GH_GLASS_A + 10))
        glass.px(a + 2, 11, rgba(STREAK, 190))
        for y in range(27, 33):
            s.a[y, b - 1:b + 1] = 0
        s.px(b - 1, 26, F[4]); s.px(b, 33, F[0])
        for (x, y) in lib.line_points(1, 45, 13, 52):
            s.px(x, y, F[3]); s.px(x, y + 1, F[1])
        for (wx, wy) in ((3, 15), (12, 31), (2, 47), (11, 63)):
            weeds(s, wx, wy, 3)
    lib.outline(s, WARM, local=0.6)
    out = Canvas(16, 64)
    out.blit(glass, 0, 0)
    out.blit(s, 0, 0)
    return out


# ================================================================================================
# Doc Ama's field tent (32 x 32, footprint 2 x 2)
# ================================================================================================
def doc_tent():
    """A sun-faded army wall tent: house-shaped canvas front with the door flap tied open on a cot
    and a lamp, both roof planes seen from above (the lit west one, the shaded east one), a white
    flag with a red cross on the front pole, guy ropes, and a medicine crate beside it. It stands
    by the ruined clinic until the clinic is rebuilt."""
    s = Canvas(32, 32)
    T = TENT
    ax, ay = 11, 12            # front apex
    L, R_ = 1, 21              # front face x range
    eave, base = 21, 29
    depth = 7
    # roof planes: between the front slope lines and the same lines `depth` px further back (up)
    for y in range(ay - depth, eave + 1):
        for x in range(L, R_ + 1):
            front = ay + abs(x - ax)                 # y of the front slope line at x
            if front - depth <= y < front:
                lit = x <= ax
                k = front - y
                c = (T[4] if lit else T[2]) if k > 1 else (T[3] if lit else T[1])
                if lit and k == depth:
                    c = mix(T[4], CREAM, 0.35)                  # back edge catches the light
                if (x - y) % 6 == 0 and lit or (x + y) % 6 == 0 and not lit:
                    c = mix(c, T[1], 0.35)                      # canvas seams
                s.px(x, y, c)
    for y in range(ay - depth, ay):                           # ridge pole along the top
        s.px(ax, y, T[4])
    # front face: low walls and the gable
    for y in range(ay, base + 1):
        for x in range(L, R_ + 1):
            if y < ay + abs(x - ax):
                continue
            c = T[3] if x < ax else T[2]
            if y >= eave + 1:
                c = T[3] if x < ax else T[2]
                if y == eave + 1:
                    c = mix(c, WARM, 0.3)                       # shadow under the eave line
            if x in (L, R_):
                c = T[1]
            s.px(x, y, c)
    # open doorway with the flaps tied back
    for y in range(ay + 5, base + 1):
        hw = 1 + (y - ay - 5) * 0.32
        for x in range(int(round(ax - hw)), int(round(ax + hw)) + 1):
            s.px(x, y, INTERIOR[0] if y < base - 1 else INTERIOR[1])
    for y in range(ay + 7, base):
        t = (y - ay - 7) / max(1, base - ay - 8)
        xl = int(round(ax - 2 - 3.5 * t))
        xr = int(round(ax + 2 + 3.5 * t))
        s.px(xl, y, T[4]); s.px(xr, y, T[1])                   # the rolled-back flaps
    s.px(ax - 4, 22, ROPE[1]); s.px(ax + 4, 22, ROPE[1])      # flap ties
    for x in range(ax - 2, ax + 3):                           # a cot inside
        s.px(x, base - 2, CANV[4] if x < ax + 1 else CANV[3])
    s.px(ax + 1, base - 5, GLOW[3]); s.px(ax + 1, base - 4, GLOW[1])   # lamp
    # guy ropes and pegs
    for (x0, y0, x1, y1) in ((L, eave - 1, 0, base), (R_, eave - 1, R_ + 2, base)):
        for (x, y) in lib.line_points(x0, y0, x1, y1):
            if s.alpha(x, y) == 0:
                s.px(x, y, ROPE[0])
    s.px(0, base + 1, WOOD[2]); s.px(R_ + 2, base + 1, WOOD[2])
    # front pole with the red-cross flag
    for y in range(0, ay + 1):
        s.px(ax, y, WOOD[4] if y > 0 else BRASS[3])
    for y in range(1, 7):
        for x in range(ax + 1, ax + 9):
            droop = 1 if x > ax + 6 else 0
            c = WASH[4] if y < 6 else WASH[2]
            if x == ax + 8:
                c = WASH[2]
            s.px(x, y + droop, c)
    for (x, y) in ((ax + 4, 2), (ax + 4, 3), (ax + 4, 4), (ax + 4, 5), (ax + 3, 3), (ax + 5, 3),
                   (ax + 3, 4), (ax + 5, 4), (ax + 2, 3), (ax + 2, 4), (ax + 6, 3), (ax + 6, 4)):
        s.px(x, y, RED[3] if x <= ax + 4 else RED[2])
    body = _finish(s, shadow=(13.0, 30.2, 12, 1.4))
    # the medicine crate beside it (front right): white panel with a red cross
    crate = Canvas(32, 32)
    _crate(crate, 22, 20, 9, 3, 8)
    for y in range(25, 30):
        for x in range(24, 29):
            crate.px(x, y, WASH[4] if (x, y) != (28, 29) else WASH[3])
    for (x, y) in ((26, 25), (26, 26), (26, 27), (26, 28), (26, 29), (24, 27), (25, 27), (27, 27),
                   (28, 27)):
        crate.px(x, y, RED[3])
    lib.outline(crate, WARM, local=0.6)
    body.shadow(27.5, 31.2, 5, 0.9)
    body.blit(crate, 0, 0)
    return body

def build():
    out = {
        "town_clinic_ruined": clinic(True),
        "town_clinic": clinic(False),
        "store_expanded": store_expanded(),
        "watchtower": watchtower(),
        "greenhouse_back": greenhouse_back(False),
        "greenhouse_side": greenhouse_side(False),
        "greenhouse_front": greenhouse_front(False),
        "greenhouse_back_ruined": greenhouse_back(True),
        "greenhouse_side_ruined": greenhouse_side(True),
        "greenhouse_front_ruined": greenhouse_front(True),
        "doc_tent": doc_tent(),
    }
    return out
