"""Settlement props (art/env/props/): warm palette, bottom-centre anchored, warm outlines.

Every sprite stands on its bottom row(s); contact shadows (OUTLINE_WARM ~35%) sit at the base,
offset to the bottom-right. Animated props are horizontal strips of equal frames.
"""
from __future__ import annotations

import math

import numpy as np

import palette as P
from env import colors as X
from env import lib, shapes
from env.lib import Canvas, mix, rgba

WOOD = lib.ramp(P.WOOD_RAMP)
BARK = lib.ramp(P.BARK_RAMP)
MET = lib.ramp(P.METAL_RAMP)
RUST = lib.ramp(P.RUST_RAMP)
STONE = lib.ramp(P.STONE_RAMP)
WATER = lib.ramp(P.WATER_RAMP)
SOIL = lib.ramp(P.SOIL_RAMP)
FIRE = lib.ramp(X.FIRE_RAMP)
CANV = lib.ramp(X.CANVAS_RAMP)
WARM = lib.WARM
LAMP = rgba(P.LAMPLIGHT)
CREAM = rgba(P.CREAM)


def _dk(c, t=0.62):
    return mix(c, WARM, t)


def _vpost(s, x, y0, y1, R, w=2):
    """Vertical post/plank of width w (lit left, dark right)."""
    for y in range(y0, y1 + 1):
        for k in range(w):
            c = R[4] if k == 0 else R[2] if k == w - 1 else R[3]
            s.px(x + k, y, c)


def _hplank(s, x0, x1, y, R, rows=2, grain=True):
    for x in range(x0, x1 + 1):
        for j in range(rows):
            c = R[4] if j == 0 else R[3] if j < rows - 1 else R[2]
            if grain and j == rows // 2 and (x * 7 + y) % 9 == 0:
                c = R[2]
            s.px(x, y + j, c)


def _nail(s, x, y):
    s.px(x, y, MET[4])


def _finish(cv, s, shadow, outline=True, dark=WARM):
    if outline:
        lib.outline(s, dark, local=0.6)
    if shadow:
        cv.shadow(*shadow)
    cv.blit(s, 0, 0)
    return cv


# ================================================================================================
# crates & barrels
# ================================================================================================
def _crate(s, x0, y0, w, top_h, front_h, R=WOOD):
    """Wooden crate: plank top face + framed front with a diagonal brace."""
    # top face: boards seen from above
    for j in range(top_h):
        for i in range(w):
            c = R[5] if j == 0 else R[4]
            if j == top_h - 1:
                c = R[3]
            if i in (w // 3, 2 * w // 3) and j < top_h - 1:
                c = R[3]
            s.px(x0 + i, y0 + j, c)
    fy = y0 + top_h
    for j in range(front_h):
        for i in range(w):
            frame = i in (0, 1, w - 2, w - 1) or j in (0, front_h - 1)
            if frame:
                c = R[3] if i < w - 2 else R[2]
                if i == 0:
                    c = R[4]
                if j == front_h - 1:
                    c = R[2] if i < w - 2 else R[1]
            else:
                # horizontal boards with dark seams
                c = R[3] if (j % 3) else R[2]
                if i > w - 4:
                    c = mix(c, R[1], 0.4)
            s.px(x0 + i, fy + j, c)
    # diagonal brace (bottom-left -> top-right) inside the frame
    n = w - 4
    for k in range(n):
        x = x0 + 2 + k
        y = fy + front_h - 2 - int(round(k * (front_h - 3) / max(1, n - 1)))
        s.px(x, y, R[4])
        s.px(x, y + 1, R[2]) if y + 1 < fy + front_h - 1 else None
    for (dx, dy) in [(1, 1), (w - 2, 1), (1, front_h - 2), (w - 2, front_h - 2)]:
        _nail(s, x0 + dx, fy + dy)


def crate():
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    _crate(s, 2, 2, 12, 3, 9)
    return _finish(cv, s, (9.0, 14.7, 7, 1.3))


def crate_stack():
    cv = Canvas(16, 32)
    s = Canvas(16, 32)
    _crate(s, 2, 17, 12, 3, 9)
    up = Canvas(16, 32)
    _crate(up, 3, 5, 11, 3, 9)
    lib.outline(up, WARM, local=0.6)
    lib.outline(s, WARM, local=0.6)
    s.blit(up, 0, 0)
    # the upper crate shades the lower crate's top
    for x in range(3, 15):
        if s.get(x, 18)[:3] in (WOOD[5][:3], WOOD[4][:3]):
            s.px(x, 18, mix(s.get(x, 18), WOOD[1], 0.45))
    cv.shadow(9.0, 30.7, 7, 1.3)
    cv.blit(s, 0, 0)
    return cv


def _barrel_body(s, cx, base, rx, top, R, hoops=(3, 8, 13)):
    for y in range(top, base + 1):
        bulge = 0.6 * math.sin(math.pi * (y - top) / max(1, base - top))
        r = rx + bulge
        for x in range(int(cx - r - 1), int(cx + r + 1)):
            t = (x + 0.5 - (cx - r)) / (2 * r)
            if t < 0 or t > 1:
                continue
            c = R[3] if t < 0.18 else R[4] if t < 0.4 else R[3] if t < 0.62 else R[2] if t < 0.84 \
                else R[1]
            # staves
            if int(t * 6) != int((t + 1.0 / (2 * r)) * 6) and 0.1 < t < 0.95:
                c = mix(c, R[1], 0.45)
            if (base - y) in hoops or (base - y) - 1 in hoops:
                hc = MET[3] if t < 0.4 else MET[2] if t < 0.75 else MET[1]
                if (base - y) - 1 in hoops:
                    hc = mix(hc, WARM, 0.3)
                c = hc
            s.px(x, y, c)


def barrel():
    cv = Canvas(16, 24)
    s = Canvas(16, 24)
    _barrel_body(s, 8.0, 22, 5.0, 8, WOOD, hoops=(2, 7, 12))
    # lid
    for y in range(5, 11):
        for x in range(2, 15):
            dx = (x + 0.5 - 8.0) / 5.6
            dy = (y + 0.5 - 7.6) / 2.3
            d = dx * dx + dy * dy
            if d > 1:
                continue
            c = MET[3] if d > 0.62 else (WOOD[5] if dx < -0.1 else WOOD[4])
            if d <= 0.62 and abs(dx) < 0.08:
                c = WOOD[3]
            s.px(x, y, c)
    s.px(10, 7, MET[1]); s.px(11, 7, MET[2])     # bung
    return _finish(cv, s, (9.0, 22.7, 6.5, 1.3))


def water_barrel():
    cv = Canvas(16, 24)
    s = Canvas(16, 24)
    _barrel_body(s, 8.0, 22, 5.0, 9, WOOD, hoops=(2, 7, 11))
    # open top: rim + water surface
    for y in range(6, 12):
        for x in range(2, 15):
            dx = (x + 0.5 - 8.0) / 5.6
            dy = (y + 0.5 - 8.6) / 2.4
            d = dx * dx + dy * dy
            if d > 1:
                continue
            if d > 0.6:
                c = WOOD[4] if dy < 0 or dx < 0 else WOOD[2]
            else:
                c = WATER[3] if dy < 0.1 else WATER[2]
                if dy < -0.25:
                    c = WATER[1]          # inner rim shadow on the water
            s.px(x, y, c)
    s.px(6, 9, WATER[5]); s.px(7, 9, WATER[4]); s.px(10, 10, WATER[4])
    # tin ladle hooked over the rim
    s.px(11, 7, MET[4]); s.px(12, 7, MET[3]); s.px(12, 8, MET[2]); s.px(13, 9, MET[3])
    s.px(13, 10, MET[2]); s.px(14, 10, MET[1])
    # wet streak down the staves
    for y in range(12, 18):
        s.px_if(5, y, mix(s.get(5, y), WATER[1], 0.35))
    return _finish(cv, s, (9.0, 22.7, 6.5, 1.3))


# ================================================================================================
# bench, signs, mailbox, planter
# ================================================================================================
def bench():
    cv = Canvas(32, 16)
    s = Canvas(32, 16)
    W_ = WOOD
    # backrest posts + rail (behind the seat)
    _vpost(s, 5, 2, 9, W_)
    _vpost(s, 25, 2, 9, W_)
    for x in range(3, 29):
        s.px(x, 3, W_[5] if x % 5 else W_[4]); s.px(x, 4, W_[4]); s.px(x, 5, W_[2])
    # legs
    for x0 in (4, 26):
        _vpost(s, x0, 10, 14, W_)
    # seat: two boards seen from above + front edge
    for x in range(2, 30):
        s.px(x, 8, W_[5] if (x * 3) % 7 else W_[4])
        s.px(x, 9, W_[4])
        s.px(x, 10, W_[4] if x % 6 else W_[3])
        s.px(x, 11, W_[2])
    # stretcher between the legs
    for x in range(6, 26):
        s.px(x, 13, W_[2])
    for x in (3, 28):
        _nail(s, x, 9)
    # a salvaged cushion (patched cloth) on the seat
    C = lib.ramp(X.CLOTH_TEAL)
    for x in range(14, 21):
        s.px(x, 7, C[3] if x < 19 else C[2]); s.px(x, 8, C[2] if x < 19 else C[1])
    s.px(16, 7, lib.rgba(X.CLOTH_MUSTARD[3])); s.px(17, 7, lib.rgba(X.CLOTH_MUSTARD[2]))
    return _finish(cv, s, (17.0, 14.7, 14, 1.3))


def sign_post():
    cv = Canvas(16, 32)
    s = Canvas(16, 32)
    _vpost(s, 7, 6, 30, WOOD)
    # upper board pointing right
    for y in range(7, 12):
        for x in range(1, 14):
            if x == 13 and y in (7, 11):
                continue
            c = WOOD[4] if y == 7 else WOOD[3] if y < 11 else WOOD[2]
            s.px(x, y, c)
    s.px(14, 9, WOOD[3])
    # lower board pointing left
    for y in range(14, 18):
        for x in range(3, 15):
            if x == 3 and y in (14, 17):
                continue
            c = WOOD[4] if y == 14 else WOOD[3] if y < 17 else WOOD[2]
            s.px(x, y, c)
    s.px(2, 15, WOOD[3]); s.px(2, 16, WOOD[2])
    # painted marks (faded cream "text") + an arrow
    paint = mix(CREAM, WOOD[3], 0.25)
    for x in (3, 4, 6, 8, 9):
        s.px(x, 9, paint)
    s.px(11, 8, paint); s.px(11, 9, paint); s.px(11, 10, paint); s.px(12, 9, paint)
    red = lib.rgba(X.SIGN_RED[2])
    for x in (6, 7, 10, 11, 12):
        s.px(x, 15, red if x < 9 else paint)
    for x in (5, 6, 8, 11):
        s.px(x, 16, mix(paint, WOOD[3], 0.3))
    _nail(s, 8, 9); _nail(s, 8, 15)
    # grass tuft at the foot
    G = lib.ramp(P.GRASS_SPRING_RAMP)
    s.px(5, 30, G[2]); s.px(6, 29, G[3]); s.px(10, 30, G[2]); s.px(10, 29, G[4])
    return _finish(cv, s, (9.0, 30.7, 4, 1.1))


def mailbox():
    cv = Canvas(16, 24)
    s = Canvas(16, 24)
    _vpost(s, 7, 12, 22, WOOD)
    G = lib.ramp(X.PAINT_GREEN)
    # box seen from the side: rounded top, door at the left end
    for y in range(5, 12):
        for x in range(2, 14):
            if y == 5 and x in (2, 3, 12, 13):
                continue
            if y == 6 and x in (2, 13):
                continue
            c = G[3] if y <= 6 else G[2] if y < 10 else G[1]
            if x == 2 or (y == 5 and x == 4):
                c = G[3]
            if x == 3:
                c = mix(G[1], WARM, 0.2)          # door seam
            if (x * 5 + y * 3) % 11 == 0 and x > 4:
                c = RUST[3]                         # rust spots
            s.px(x, y, c)
    s.px(5, 6, mix(G[3], CREAM, 0.4)); s.px(6, 6, mix(G[3], CREAM, 0.3))       # top sheen
    s.px(1, 9, MET[4]); s.px(1, 8, MET[3])                                      # door latch
    # red flag (raised)
    red = lib.ramp(X.SIGN_RED)
    for y in range(2, 9):
        s.px(13, y, MET[2])
    for (x, y, c) in [(14, 2, red[2]), (15, 2, red[1]), (14, 3, red[1]), (15, 3, red[0])]:
        s.px(x, y, c)
    # little painted number
    s.px(8, 8, CREAM); s.px(9, 8, CREAM); s.px(9, 9, CREAM)
    return _finish(cv, s, (9.0, 22.7, 4, 1.1))


def planter():
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    # flowers first (behind the box front)
    G = lib.ramp(P.GRASS_SPRING_RAMP)
    stems = [(4, 4), (7, 2), (10, 3), (12, 5)]
    for (x, ytop) in stems:
        for y in range(ytop + 2, 9):
            s.px(x, y, G[2])
        s.px(x - 1, ytop + 4, G[3]); s.px(x + 1, ytop + 5, G[2])
    pet = [lib.ramp(X.FLOWER_YELLOW), lib.ramp(X.BLOSSOM_RAMP[1:]), lib.ramp(X.FLOWER_WHITE),
           lib.ramp(["#c2410f", "#ec7a1c", "#ffb72d"])]
    for (x, ytop), pr in zip(stems, pet):
        s.px(x, ytop, pr[2]); s.px(x - 1, ytop + 1, pr[1]); s.px(x + 1, ytop + 1, pr[0])
        s.px(x, ytop + 2, pr[0]); s.px(x, ytop + 1, LAMP)
    # box: soil top + plank front
    for x in range(2, 14):
        s.px(x, 8, SOIL[2] if x % 3 else SOIL[3])
        s.px(x, 9, SOIL[1])
    for y in range(10, 15):
        for x in range(1, 15):
            c = WOOD[4] if y == 10 else WOOD[3] if y < 14 else WOOD[2]
            if y == 12:
                c = WOOD[2]
            if x == 1:
                c = WOOD[4]
            if x >= 13:
                c = mix(c, WOOD[1], 0.5)
            s.px(x, y, c)
    for x in (1, 14):
        s.px(x, 8, WOOD[4] if x == 1 else WOOD[2]); s.px(x, 9, WOOD[3] if x == 1 else WOOD[1])
    _nail(s, 2, 11); _nail(s, 13, 11)
    return _finish(cv, s, (9.0, 14.8, 7, 1.2))


# ================================================================================================
# fire pit (4-frame flame strip) & lamp post (unlit / lit)
# ================================================================================================
FLAMES = [
    # per frame: list of (x, top_y) flame tongues (bottom fixed at y=11)
    [(6, 5), (8, 3), (10, 6)],
    [(6, 4), (8, 4), (10, 5), (9, 2)],
    [(5, 6), (7, 3), (9, 4), (11, 6)],
    [(6, 5), (8, 2), (10, 4)],
]
SPARKS = [[(9, 1)], [(6, 1), (11, 2)], [(10, 0)], [(7, 0), (12, 3)]]


def fire_pit():
    frames = []
    for f in range(4):
        cv = Canvas(16, 16)
        s = Canvas(16, 16)
        # ash bed + crossed logs
        for x in range(4, 13):
            s.px(x, 12, mix(STONE[1], BARK[0], 0.5))
            s.px(x, 11, mix(STONE[1], BARK[0], 0.3))
        shapes.thick_line(s, [(4, 12), (11, 9)], 2, [BARK[3], BARK[1]])
        shapes.thick_line(s, [(5, 9), (12, 12)], 2, [BARK[2], BARK[0]])
        # flames
        for (x, ty) in FLAMES[f]:
            for y in range(ty, 12):
                t = (y - ty) / max(1, 11 - ty)
                wdt = 0 if t < 0.25 else 1 if t < 0.7 else 1
                for dx in range(-wdt, wdt + 1):
                    c = FIRE[2] if t < 0.3 else FIRE[3] if t < 0.65 else FIRE[4]
                    if abs(dx) == wdt and wdt > 0:
                        c = FIRE[2] if t > 0.5 else FIRE[1]
                    s.px(x + dx, y, c)
        for x in range(7, 10):
            s.px(x, 10, FIRE[5])
        s.px(8, 9, FIRE[5])
        for (x, y) in SPARKS[f]:
            s.px(x, y, rgba(X.EMBER))
        # stone ring: front stones overlap the fire base
        ring = [(2, 11, 0), (3, 13, 1), (6, 14, 1), (10, 14, 1), (13, 13, 1), (14, 11, 0),
                (12, 9, 0), (4, 9, 0)]
        for (x, y, front) in ring:
            for (dx, dy, k) in [(0, 0, 4), (1, 0, 3), (2, 0, 3), (0, 1, 3), (1, 1, 2), (2, 1, 1)]:
                if front or dy == 0 or True:
                    s.px(x + dx - 1, y + dy - 1, STONE[k])
        lib.outline(s, WARM, local=0.6)
        # warm light on the ring stones (frame-dependent flicker)
        glow = mix(STONE[4], LAMP, 0.45 if f % 2 == 0 else 0.35)
        for (x, y) in [(3, 12), (6, 13), (10, 13), (12, 12)]:
            s.px(x, y, glow)
        cv.shadow(9.0, 14.6, 7, 1.2)
        cv.blit(s, 0, 0)
        frames.append(cv)
    return lib.hstrip(frames)


def lamp_post():
    frames = []
    for lit in (False, True):
        cv = Canvas(16, 48)
        s = Canvas(16, 48)
        # base: a salvaged concrete block with a couple of wedge stones
        for y in range(41, 47):
            for x in range(4, 12):
                c = STONE[4] if y == 41 else STONE[3] if x < 9 else STONE[2]
                if y == 46:
                    c = STONE[1]
                if x == 4 and y > 41:
                    c = STONE[4]
                s.px(x, y, c)
        for (x, y, c) in [(2, 46, STONE[3]), (3, 46, STONE[2]), (3, 45, STONE[4]),
                          (12, 46, STONE[2]), (13, 46, STONE[1]), (12, 45, STONE[3])]:
            s.px(x, y, c)
        s.px(9, 43, STONE[1]); s.px(10, 44, STONE[1])       # chip
        # pole: salvaged pipe with joints
        for y in range(5, 41):
            s.px(6, y, MET[4]); s.px(7, y, MET[3]); s.px(8, y, MET[1])
            if y in (18, 30):
                s.px(6, y, MET[5]); s.px(7, y, MET[4]); s.px(8, y, MET[2])
        for (x, y) in [(7, 24), (8, 25), (7, 36)]:
            s.px(x, y, RUST[3])
        # curved arm to the right
        for (x, y) in [(7, 4), (8, 3), (9, 3), (10, 3), (11, 3), (12, 4)]:
            s.px(x, y, MET[4]); s.px(x, y + 1, MET[2])
        s.px(6, 4, MET[3])
        # hook + chain
        s.px(12, 6, MET[2]); s.px(12, 7, MET[3])
        # lantern (x 10..14, y 8..15): cap, glass, base
        for x in range(10, 15):
            s.px(x, 8, MET[3] if x < 13 else MET[2])
        s.px(11, 7, MET[4]); s.px(12, 7, MET[3]); s.px(13, 7, MET[2])
        for y in range(9, 14):
            for x in range(10, 15):
                frame = x in (10, 14)
                if frame:
                    s.px(x, y, MET[3] if x == 10 else MET[1])
                    continue
                if lit:
                    c = CREAM if (x == 12 and 10 <= y <= 12) else LAMP if x < 13 else \
                        mix(LAMP, FIRE[3], 0.5)
                    if y == 13:
                        c = FIRE[3]
                else:
                    c = mix(WARM, MET[2], 0.45) if x < 13 else mix(WARM, MET[1], 0.5)
                    if x == 11 and y in (9, 10):
                        c = MET[4]                   # glass glint
                s.px(x, y, c)
        for x in range(10, 15):
            s.px(x, 14, MET[2] if x < 13 else MET[1])
        s.px(12, 15, MET[1])
        lib.outline(s, WARM, local=0.6)
        if lit:
            # soft glow halo (deliberately translucent)
            for y in range(4, 19):
                for x in range(5, 16):
                    d = math.hypot((x + 0.5 - 12.5) / 1.0, (y + 0.5 - 11.0) / 1.15)
                    if s.alpha(x, y) == 0 and d < 5.2:
                        a = 90 if d < 3.8 else 45
                        s.px(x, y, rgba(P.LAMPLIGHT, a))
        cv.shadow(9.0, 46.7, 6, 1.2)
        cv.blit(s, 0, 0)
        frames.append(cv)
    return lib.hstrip(frames)


def build(out):
    crate().save("props/crate.png")
    crate_stack().save("props/crate_stack.png")
    barrel().save("props/barrel.png")
    water_barrel().save("props/water_barrel.png")
    bench().save("props/bench.png")
    sign_post().save("props/sign_post.png")
    mailbox().save("props/mailbox.png")
    planter().save("props/planter.png")
    fire_pit().save("props/fire_pit.png")
    lamp_post().save("props/lamp_post.png")
    import env.props_big as big
    big.build(out)
