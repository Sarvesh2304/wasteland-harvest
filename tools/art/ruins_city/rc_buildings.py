"""Ruined building masses (art/env/ruins/ruin_*.png): big single sprites, bottom-anchored.

Each sprite's footprint is its bottom W x H cells (solid); everything above overhangs north.
Same projection as art/buildings/: a flat south-facing front elevation plus a sliver of roof seen
from above (flat roofs show a foreshortened roof band behind the front parapet; the house shows
its front roof slope). Light from the top-left: protruding trim gets a lit top edge and a dark
line under it, openings are darkest under their lintel and along their left jamb.

  ruin_shopfront  64x64   4x2  two-storey red-brick corner shop: smashed shop window under a
                               torn awning, faded MARKET sign, boarded door behind rubble
  ruin_house      64x64   4x2  clapboard suburban house: shingle roof with a caved-in hole and
                               bare rafters, brick chimney, collapsing porch, boarded door
  ruin_garage     64x48   4x2  painted-block auto garage: one rusted roll-up door down, one
                               jammed half open over a junk pile, GARAGE sign, rooftop vent
  ruin_office     80x112  5x3  concrete office block: window-ribbon grid, a logo on the
                               parapet, the upper corner sheared off showing slabs and rebar,
                               lobby glass smashed and the entrance buried in rubble
  ruin_apartment  96x96   6x3  sooty brick tenement: stone trim, rusted fire escape, a burnt-
                               out top floor where the roof fell in, rubble-choked stoop
No door is enterable: every doorway is boarded, collapsed or blocked by rubble.
"""
from __future__ import annotations

import numpy as np

import palette as P
from env import colors as X
from env import lib, shapes
from env.lib import Canvas, mix, rgba
from ruins_city import rc_common as C
from ruins_city.rc_common import (ASH, ASPH, BLOCK, BRICK, BRICK_D, CHAR, COLD, CON, CREAMS,
                                  DRY, GLASS, MET, PAPER, RUB, RUST, SHINGLE, SIDING, TRIM,
                                  VINE, WEED, WOODG, hval)

CLOTH_R = lib.ramp([mix(c, P.CONCRETE_DARK, 0.35) for c in X.CLOTH_RED])     # faded awning red
CLOTH_T = lib.ramp([mix(c, P.CONCRETE_DARK, 0.3) for c in X.CLOTH_TEAL])     # faded curtain
CLOTH_M = lib.ramp([mix(c, P.CONCRETE_DARK, 0.45) for c in X.CLOTH_RED])     # faded rose curtain
SIGN_RED = lib.ramp([mix(c, P.CONCRETE_DARK, 0.45) for c in X.SIGN_RED])      # sign board
SIGN_BLUE = lib.ramp([mix(c, P.CONCRETE_DARK, 0.2) for c in X.CAR_BLUE])      # sign board
INTERIOR = mix(CHAR[1], COLD, 0.3)                                             # dark rooms


# ================================================================================================
# facade fills
# ================================================================================================
def fill_brick(s, x0, y0, x1, y1, R, blen=5, mortar=None, seed=0, contrast=1.0):
    """Running bond, 3 px courses (2 px brick + 1 px mortar), bricks blen px + 1 px joint. Calm:
    a flat base with soft joints and a scatter of lighter / darker bricks."""
    mortar = mortar or mix(R[2], R[3], 0.35)
    per = blen + 1
    for y in range(y0, y1 + 1):
        course = (y - y0) // 3
        k = (y - y0) % 3
        off = per // 2 if course % 2 else 0
        for x in range(x0, x1 + 1):
            u = x - x0 + off
            if k == 2 or u % per == blen:
                c = mortar
            else:
                v = hval("fb", seed, u // per, course)
                c = R[3]
                if v < 0.12 * contrast:
                    c = mix(R[3], R[4], 0.55)
                elif v < 0.24 * contrast:
                    c = mix(R[3], R[2], 0.6)
                if k == 0 and v < 0.12 * contrast:
                    c = mix(R[4], R[5], 0.3)
            s.px(x, y, c)


def fill_siding(s, x0, y0, x1, y1, R, seed=0):
    """Horizontal clapboards: 3 px pitch (lit lap edge, board, shadow under the next lap)."""
    for y in range(y0, y1 + 1):
        k = (y - y0) % 3
        for x in range(x0, x1 + 1):
            c = R[4] if k == 0 else R[3] if k == 1 else R[2]
            if x == x0:
                c = mix(c, R[5], 0.3)
            s.px(x, y, c)


def fill_block(s, x0, y0, x1, y1, R, seed=0):
    """Concrete block: 7x3 blocks + 1 px joints, half-bond stagger."""
    for y in range(y0, y1 + 1):
        row = (y - y0) // 4
        k = (y - y0) % 4
        off = 4 if row % 2 else 0
        for x in range(x0, x1 + 1):
            u = x - x0 + off
            if k == 3 or u % 8 == 7:
                c = mix(R[2], R[3], 0.4)
            else:
                c = R[3] if k else mix(R[3], R[4], 0.5)
                if hval("blk", seed, u // 8, row) < 0.12:
                    c = mix(c, R[2], 0.5)
            s.px(x, y, c)


def fill_concrete(s, x0, y0, x1, y1, R=CON, lit=False):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = R[4] if lit else R[3]
            if hval("fc", x, y) < 0.05:
                c = R[2] if not lit else R[3]
            s.px(x, y, c)


def ledge(s, x0, x1, y, R=TRIM, depth=2):
    """Projecting stone band: lit top row(s), a dark shadow line under it on the wall."""
    for x in range(x0, x1 + 1):
        s.px(x, y, R[4] if x < x1 - 1 else R[3])
        for d in range(1, depth):
            s.px(x, y + d, R[3] if x < x1 - 1 else R[2])
        s.px(x, y + depth, mix(s.get(x, y + depth), COLD, 0.45))


def grime(s, x0, x1, ybot, h=4, strength=0.55):
    """Dirt and damp creeping up from the ground line, ragged per column."""
    for x in range(x0, x1 + 1):
        hh = h + int(hval("grime_b", x) * 3) - 1
        for k in range(hh):
            C.darken(s, x, ybot - k, mix(ASH, COLD, 0.5), strength * (1 - k / hh))


# ================================================================================================
# openings
# ================================================================================================
def window(s, x0, y0, w, h, kind, seed=0, frame=TRIM, sill=True, lintel=True):
    """A window opening with its stone sill/lintel. kinds: glass, broken, boarded, curtain,
    burnt, blinds, dark."""
    x1, y1 = x0 + w - 1, y0 + h - 1
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = GLASS[1]
            if kind in ("glass", "blinds"):
                c = GLASS[2] if y > y0 + 1 else GLASS[1]
            if kind in ("broken", "burnt", "dark", "boarded", "curtain"):
                c = INTERIOR if kind != "dark" else GLASS[0]
            if x == x0 or y == y0:
                c = mix(c, COLD, 0.45)                    # jamb / lintel shadow
            s.px(x, y, c)
    if kind == "glass":
        for k in range(min(w, h)):
            x = x0 + 1 + k
            y = y1 - 1 - k
            if x0 < x < x1 and y0 < y < y1 and k % 4 < 2:
                s.px(x, y, GLASS[4])
        s.px(x0 + 1, y0 + 1, GLASS[5])
        if w >= 6:
            for y in range(y0, y1 + 1):
                s.px(x0 + w // 2, y, mix(frame[2], COLD, 0.2))    # mullion
    elif kind == "broken":
        # shards left in the corners of the frame, catching the light
        for (dx, dy, c) in [(1, 1, GLASS[4]), (2, 1, GLASS[3]), (1, 2, GLASS[3]),
                            (w - 2, h - 2, GLASS[3]), (w - 3, h - 2, GLASS[2]), (w - 2, 1, GLASS[3])]:
            s.px(x0 + dx, y0 + dy, c)
        if w >= 6:
            for y in range(y0, y0 + h // 2):
                s.px(x0 + w // 2, y, mix(frame[2], COLD, 0.3))   # snapped mullion
    elif kind == "blinds":
        for y in range(y0 + 1, y1):
            if (y - y0) % 2 == 0:
                for x in range(x0 + 1, x1):
                    if hval("blind", seed, y, x // 3) > 0.2:
                        s.px(x, y, mix(PAPER[1], GLASS[2], 0.45))
    elif kind == "curtain":
        side = 1 if hval("cur", seed) < 0.5 else 0
        R = CLOTH_T if hval("curc", seed) < 0.5 else CLOTH_M
        cw = max(2, w // 2 - 1)
        cx0 = x0 + 1 if side else x1 - cw
        for x in range(cx0, cx0 + cw):
            ln = h - 2 - int(hval("rag", seed, x) * (h // 2))
            for y in range(y0 + 1, y0 + 1 + ln):
                s.px(x, y, R[2] if (x - cx0) % 2 == 0 else R[1])
            s.px(x, y0 + 1, R[3])
    elif kind == "burnt":
        C.soot(s, x0 - 2, y0 - 6, w + 4, 7, 0.75, seed)
        s.px(x0 + 1, y1 - 1, CHAR[3]); s.px(x0 + 2, y1 - 1, CHAR[2])
    elif kind == "boarded":
        planks = [(y0 + 1, y0 + 2), (y0 + h // 2, y0 + h // 2 - 1), (y1 - 2, y1 - 1)]
        for i, (ya, yb) in enumerate(planks):
            if h < 7 and i == 1:
                continue
            C.plank(s, x0 - 1, ya, x1 + 1, yb, w=2)
    if lintel:
        for x in range(x0 - 1, x1 + 2):
            s.px(x, y0 - 1, frame[3] if x < x1 + 1 else frame[2])
    if sill:
        for x in range(x0 - 1, x1 + 2):
            s.px(x, y1 + 1, frame[4] if x < x1 + 1 else frame[3])
            s.px(x, y1 + 2, mix(s.get(x, y1 + 2), COLD, 0.4))


def boarded_door(s, x0, y0, w, h, R=WOODG, seed=0):
    """Door recess nailed shut with planks (vertical boards + a cross brace)."""
    x1, y1 = x0 + w - 1, y0 + h - 1
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = R[3] if (x - x0) % 3 else R[2]
            if (x - x0) % 3 == 1:
                c = R[4] if y < y0 + 2 else R[3]
            if hval("door", seed, x) < 0.2 and y > y0 + h // 2 + int(hval("dl", seed, x) * 4):
                c = INTERIOR                                 # a board broken off at the bottom
            s.px(x, y, c)
    for x in range(x0, x1 + 1):
        s.px(x, y0, mix(COLD, R[1], 0.4))
    C.plank(s, x0, y0 + 3, x1, y0 + h - 4, w=2)
    C.plank(s, x0, y0 + h // 2, x1, y0 + h // 2, w=2)


def rubble_heap(cv, cx, base, w, h, seed, bricks=True, R=CON):
    """A heap of broken concrete chunks (facet rocks) with brick bits and rebar; drawn on its own
    layer with a cold outline, then composited onto cv."""
    layer = Canvas(cv.w, cv.h)
    r = lib.rng(seed)
    n = max(2, int(w // 6))
    for i in range(n):
        f = (i + 0.5) / n
        x = cx - w / 2.0 + w * f + r.uniform(-1.5, 1.5)
        cw = r.uniform(w / n * 1.1, w / n * 1.6)
        ch = h * (1.0 - abs(f - 0.5) * 1.1) * r.uniform(0.75, 1.0)
        sub = Canvas(cv.w, cv.h)
        shapes.facet_rock(sub, x, base - (0 if abs(f - 0.5) > 0.25 else 0), max(4, cw),
                          max(3, ch), R, seed=seed * 7 + i, n_facets=4, jag=0.2)
        lib.outline(sub, COLD, local=0.55)
        layer.blit(sub, 0, 0)
    if bricks:
        B = BRICK
        for i in range(max(2, int(w // 8))):
            x = int(cx - w / 2.0 + r.uniform(1, w - 3))
            y = int(base - r.uniform(0, h * 0.5))
            layer.px(x, y, B[4]); layer.px(x + 1, y, B[3]); layer.px(x, y + 1, B[2])
            layer.px(x + 1, y + 1, B[1])
    for i in range(max(1, int(w // 14))):
        x = int(cx + r.uniform(-w / 3.0, w / 3.0))
        y = int(base - h * r.uniform(0.4, 0.8))
        shapes.thick_line(layer, [(x, y), (x + r.choice([-2, 2]), y - 3)], 1, [RUST[3]])
    cv.blit(layer, 0, 0)


def roof_hole(s, x0, y0, x1, y1, beams, R=WOODG):
    """Collapsed roof section seen from above: dark void with joists / rafters across it."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            d = min(x - x0, x1 - x, y - y0, y1 - y)
            s.px(x, y, mix(INTERIOR, COLD, 0.35) if d > 0 else mix(INTERIOR, CHAR[3], 0.5))
    for (bx, broken) in beams:
        top = y0
        bot = y1 if not broken else y0 + (y1 - y0) // 2 + int(broken)
        for y in range(top, bot + 1):
            s.px(bx, y, R[3] if y < bot else CHAR[3])
            s.px(bx + 1, y, R[1])


def tufts_along(s, x0, x1, y, seed, every=9):
    for x in range(x0, x1 + 1):
        v = hval("tufts", seed, x)
        if v < 1.0 / every:
            C.tuft(s, x, y, "weed" if v < 0.5 / every else "dry")


# ================================================================================================
# ruin_shopfront (64x64, footprint 4x2)
# ================================================================================================
def ruin_shopfront():
    W, H = 64, 64
    cv = Canvas(W, H)
    s = Canvas(W, H)
    B = BRICK
    G = H - 2                                  # ground row of the facade
    # roof band behind the front parapet (flat tar roof), back parapet line
    for x in range(2, 62):
        s.px(x, 2, TRIM[3])
        for y in range(3, 9):
            s.px(x, y, mix(ASPH[2], ASPH[3], 0.5) if hval("tar", x, y) > 0.1 else ASPH[4])
    roof_hole(s, 38, 3, 55, 8, [(41, False), (46, 1), (51, False)])
    # facade brick
    fill_brick(s, 1, 9, 62, G, B, seed=1)
    ledge(s, 1, 62, 9, TRIM, depth=2)                         # parapet coping
    ledge(s, 1, 62, 30, TRIM, depth=1)                        # cornice over the shop
    # broken parapet above the roof hole: brick stepped down
    for x in range(40, 54):
        drop = 3 + int(2 * hval("pp", x // 2)) + (2 if 44 <= x <= 49 else 0)
        for y in range(2, 9 + drop):
            if y >= 9:
                if y < 9 + drop:
                    s.a[y, x] = 0 if y < 9 + drop - 1 else s.a[y, x]
    for x in range(40, 54):
        drop = 3 + int(2 * hval("pp", x // 2)) + (2 if 44 <= x <= 49 else 0)
        top = 9 + drop - 1
        # interior seen through the break: dark room behind, beam end
        for y in range(9, top):
            s.px(x, y, mix(INTERIOR, COLD, 0.2))
        s.px(x, top, B[4])
    # corner pilasters (stone)
    for (px0, px1) in ((1, 3), (60, 62)):
        for y in range(10, G + 1):
            for x in range(px0, px1 + 1):
                s.px(x, y, TRIM[3] if x == px0 else TRIM[2])
                if (y - 10) % 6 == 5:
                    s.px(x, y, mix(TRIM[2], COLD, 0.3))
    # upper floor windows
    window(s, 9, 14, 8, 11, "boarded", seed=1)
    window(s, 28, 14, 8, 11, "curtain", seed=2)
    window(s, 47, 14, 8, 11, "burnt", seed=3)
    # sign board with MARKET (faded, one letter gone, one hanging)
    for y in range(32, 39):
        for x in range(6, 58):
            c = SIGN_RED[1] if y < 38 else SIGN_RED[0]
            if y == 32:
                c = SIGN_RED[2]
            s.px(x, y, c)
    tw = C.text_width("MARKET")
    C.text(s, 32 - tw // 2, 33, "MARKET", mix(CREAMS, SIGN_RED[1], 0.1), skip={3},
           fade={1: 0.35}, drop={4: 1})
    for x in range(6, 58):
        if hval("sgn", x) < 0.15:
            s.px(x, 38, mix(SIGN_RED[0], RUST[2], 0.5))
    C.rust_streak(s, 8, 39, 4, 0.5); C.rust_streak(s, 55, 39, 5, 0.5)
    # ground floor: shop window, door, kick plate
    for y in range(42, 57):
        for x in range(6, 37):
            c = INTERIOR
            if y < 44 or x < 8:
                c = mix(INTERIOR, COLD, 0.4)
            s.px(x, y, c)
    # remains of the shop inside: a toppled shelf, cans
    for x in range(12, 22):
        s.px(x, 52, mix(MET[2], INTERIOR, 0.4)); s.px(x + 1, 51, mix(MET[3], INTERIOR, 0.5))
    s.px(26, 55, MET[3]); s.px(29, 54, mix(PAPER[2], INTERIOR, 0.3))
    # jagged glass left in the big frame
    for (x, y, c) in [(7, 44, GLASS[4]), (8, 44, GLASS[3]), (7, 45, GLASS[3]), (9, 44, GLASS[2]),
                      (35, 44, GLASS[3]), (34, 44, GLASS[2]), (35, 45, GLASS[2]),
                      (7, 55, GLASS[3]), (8, 55, GLASS[2]), (35, 55, GLASS[4]), (34, 55, GLASS[3]),
                      (35, 54, GLASS[3])]:
        s.px(x, y, c)
    for x in range(5, 38):
        s.px(x, 41, TRIM[3]); s.px(x, 57, TRIM[4]); s.px(x, 58, TRIM[2])
    for y in range(41, 58):
        s.px(5, y, TRIM[3]); s.px(37, y, TRIM[2]); s.px(21, y, mix(TRIM[2], COLD, 0.25))
    # door: recessed, boarded, rubble in front
    for y in range(43, G + 1):
        for x in range(41, 55):
            s.px(x, y, mix(INTERIOR, COLD, 0.3))
    boarded_door(s, 43, 45, 10, G - 44, seed=4)
    for x in range(40, 56):
        s.px(x, 42, TRIM[3])
    # torn awning: rusted frame + tattered faded stripes hanging over the shop window
    for x in range(4, 39):
        s.px(x, 39, RUST[2]); s.px(x, 40, RUST[1])
    for x in range(4, 39):
        k = x - 4
        ln = 3 + int(hval("awn", k // 2) * 5)
        if 16 <= x <= 21:
            ln = 1                                        # torn away
        col = CLOTH_R if (k // 3) % 2 == 0 else lib.ramp([mix(CREAMS, P.CONCRETE_DARK, 0.4),
                                                            mix(CREAMS, P.CONCRETE_DARK, 0.25),
                                                            CREAMS, CREAMS])
        for d in range(ln):
            c = col[2] if d == 0 else col[1]
            if d == ln - 1 and ln > 2:
                c = col[0]
            s.px(x, 41 + d, c)
    for x in (4, 21, 38):
        s.px(x, 39, MET[4])
        C.rust_streak(s, x, 41, 3, 0.4)
    grime(s, 1, 62, G, 4)
    # vines up the left pilaster and the right pier
    C.vine(s, [(3, G), (4, 50), (2, 40), (4, 30), (3, 22), (6, 16)], seed=11)
    C.vine(s, [(58, G), (57, 48), (59, 40), (57, 33)], seed=12)
    lib.outline(s, COLD, local=0.6)
    # bottom-centre shadow, then heaps and weeds in front
    C.shadow(cv, 33.0, G + 1.4, 31.0, 1.4)
    cv.blit(s, 0, 0)
    rubble_heap(cv, 48.0, G + 1, 18, 9, seed=31)
    rubble_heap(cv, 13.0, G + 1, 10, 4, seed=32, bricks=True)
    for x in (24, 31, 58):
        C.tuft(cv, x, G + 1, "dry")
    return cv


# ================================================================================================
# ruin_house (64x64, footprint 4x2)
# ================================================================================================
def ruin_house():
    W, H = 64, 64
    cv = Canvas(W, H)
    s = Canvas(W, H)
    G = H - 2
    # chimney (behind the roof ridge): umber brick, broken top
    fill_brick(s, 11, 1, 17, 14, BRICK_D, blen=3, seed=5)
    for x in range(11, 18):
        s.px(x, 0, BRICK_D[4])
    s.a[0, 15:18] = 0                                     # broken chimney top
    s.a[1, 16:18] = 0
    s.px(15, 1, BRICK_D[4])
    # roof: front slope of shingles, ridge at y 5, eaves at y 26; hips slant out to the sides
    R = SHINGLE
    for y in range(5, 27):
        t = (y - 5) / 21.0
        xl = int(round(7 - 6 * t))
        xr = int(round(56 + 6 * t))
        course = (y - 5) // 3
        for x in range(xl, xr + 1):
            k = (y - 5) % 3
            u = x + (2 if course % 2 else 0)
            c = R[3] if k else R[4]
            if k == 2:
                c = R[2]
            if u % 4 == 0 and k != 0:
                c = mix(R[2], R[1], 0.4)                  # tab gaps
            if x <= xl + 1:
                c = mix(c, R[5], 0.35)                    # lit left hip
            if x >= xr - 1:
                c = mix(c, R[1], 0.4)
            if hval("shg", x // 2, course) < 0.06:
                c = mix(R[1], ASH, 0.3)                   # missing tab
            s.px(x, y, c)
    for x in range(7, 57):
        s.px(x, 4, R[5]); s.px(x, 5, R[4])                # ridge cap
    # caved-in hole with bare rafters, shingles hanging off its lip
    roof_hole(s, 33, 9, 50, 21, [(36, False), (41, 3), (46, False)], R=WOODG)
    for x in range(33, 51):
        if hval("lip", x) < 0.45:
            s.px(x, 22, R[2]); s.px(x, 23, R[1]) if hval("lip2", x) < 0.4 else None
    for y in range(13, 22):
        s.px(32, y, R[4])                                 # torn shingle edge catches light
    # gutter at the eaves, broken and hanging at the right end
    for x in range(1, 52):
        s.px(x, 27, RUST[2] if hval("gut", x) < 0.3 else MET[2]); s.px(x, 28, MET[1])
    for k in range(6):
        s.px(52 + k, 28 + k, MET[2])
    # wall: clapboard siding, peeling to grey boards
    fill_siding(s, 2, 29, 61, G - 3, SIDING)
    for (px0, py0, pw, ph) in [(4, 46, 6, 5), (52, 31, 5, 4), (23, 30, 4, 3), (40, 50, 7, 4)]:
        for y in range(py0, py0 + ph):
            for x in range(px0, px0 + pw):
                if hval("peel", x, y) < 0.7:
                    k = (y - 29) % 3
                    s.px(x, y, WOODG[3] if k < 2 else WOODG[2])
    for y in range(29, G - 2):
        s.px(2, y, SIDING[5]); s.px(61, y, SIDING[1])     # corner boards
    # foundation
    for y in range(G - 2, G + 1):
        for x in range(2, 62):
            s.px(x, y, CON[3] if y == G - 2 else CON[2])
    # windows with shutters
    window(s, 7, 34, 9, 10, "broken", seed=6, frame=lib.ramp(P.STONE_RAMP))
    window(s, 47, 34, 9, 10, "boarded", seed=7, frame=lib.ramp(P.STONE_RAMP))
    for y in range(34, 44):
        s.px(5, y, SIDING[2]); s.px(4, y, SIDING[3])
    for k in range(9):                                     # a shutter hanging by one hinge
        s.px(57 + k // 3, 34 + k, SIDING[2]); s.px(58 + k // 3, 34 + k, SIDING[1])
    # porch: roof (collapsing on the right), posts, deck and steps
    for y in range(G - 6, G - 2):
        for x in range(20, 44):
            s.px(x, y, WOODG[3] if y == G - 6 else WOODG[2])
    for (sx0, sy) in [(27, G - 2), (28, G - 1), (29, G)]:
        for x in range(sx0, 64 - sx0 - 7):
            s.px(x, sy, WOODG[4] if x < 64 - sx0 - 8 else WOODG[2])
    boarded_door(s, 28, 38, 8, G - 7 - 37, seed=8)
    for x in range(26, 38):
        s.px(x, 37, mix(SIDING[1], COLD, 0.3))
    for y in range(32, G - 5):
        s.px(21, y, WOODG[4]); s.px(22, y, WOODG[2])      # porch post (standing)
    for x in range(19, 34):
        s.px(x, 31, SHINGLE[4]); s.px(x, 32, SHINGLE[3]); s.px(x, 33, SHINGLE[2])
    for k in range(13):                                    # right half slumped to the deck
        x = 34 + k
        y = 31 + k // 2 + k // 4
        s.px(x, y, SHINGLE[4]); s.px(x, y + 1, SHINGLE[3]); s.px(x, y + 2, SHINGLE[1])
    for k in range(6):
        s.px(44 - k // 2, G - 7 - k, WOODG[3])            # snapped post leaning
    grime(s, 2, 61, G - 3, 3, 0.4)
    C.vine(s, [(3, G - 3), (4, 45), (3, 36), (5, 30)], seed=21)
    C.vine(s, [(60, G - 3), (59, 47), (60, 40)], seed=22)
    lib.outline(s, COLD, local=0.6)
    C.shadow(cv, 33.0, G + 1.4, 30.5, 1.4)
    cv.blit(s, 0, 0)
    for (x, k) in [(5, "dry"), (12, "weed"), (17, "dry"), (48, "dry"), (55, "weed")]:
        C.tuft(cv, x, G + 1, k, h=4 if k == "dry" else 3)
    rubble_heap(cv, 50.0, G + 1, 8, 4, seed=41, bricks=False)
    return cv


# ================================================================================================
# ruin_garage (64x48, footprint 4x2)
# ================================================================================================
def ruin_garage():
    W, H = 64, 48
    cv = Canvas(W, H)
    s = Canvas(W, H)
    G = H - 2
    # flat roof band + parapets, a rusty vent unit on the roof
    for x in range(2, 62):
        s.px(x, 3, BLOCK[3])
        for y in range(4, 9):
            s.px(x, y, ASPH[3] if hval("gtar", x, y) > 0.08 else ASPH[4])
    for y in range(0, 7):
        for x in range(12, 21):
            c = MET[3] if y < 2 else MET[2]
            if y >= 2 and x % 2 == 0:
                c = MET[1]                                 # louvres
            if x == 20:
                c = MET[1]
            s.px(x, y, c)
    C.rust_streak(s, 13, 2, 4, 0.6); C.rust_streak(s, 18, 2, 3, 0.5)
    roof_hole(s, 46, 4, 58, 8, [(49, False), (54, 1)])
    # facade: painted block
    fill_block(s, 1, 9, 62, G, BLOCK, seed=3)
    ledge(s, 1, 62, 9, BLOCK, depth=1)
    # collapsed right corner: block wall broken down in steps, room dark behind
    for x in range(50, 63):
        cut = 10 + int((x - 50) * 0.9) + (2 if hval("gc", x // 2) < 0.5 else 0)
        for y in range(0, cut):
            s.a[y, x] = 0
        for y in range(cut, min(cut + 2, G)):
            s.px(x, y, BLOCK[4] if y == cut else BLOCK[3])
    # sign board: GARAGE
    for y in range(11, 18):
        for x in range(14, 46):
            c = SIGN_BLUE[2] if y < 17 else SIGN_BLUE[1]
            if y == 11:
                c = SIGN_BLUE[3]
            s.px(x, y, c)
    tw = C.text_width("GARAGE")
    C.text(s, 30 - tw // 2, 12, "GARAGE", mix(CREAMS, SIGN_BLUE[2], 0.1), fade={5: 0.5})
    C.rust_streak(s, 15, 18, 4, 0.5); C.rust_streak(s, 44, 18, 3, 0.5)
    # roll-up door 1: down, rusted, dented
    def roll(x0, x1, y0, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                c = MET[3] if (y - y0) % 2 == 0 else MET[2]
                if x == x0:
                    c = mix(c, MET[4], 0.4)
                s.px(x, y, c)
    for y in range(19, G + 1):
        for x in (3, 26):
            s.px(x, y, CON[2]); s.px(x + 1, y, CON[1])
    roll(5, 25, 20, G)
    C.darken(s, 15, 33, COLD, 0.4); C.darken(s, 16, 34, COLD, 0.4); C.darken(s, 15, 34, MET[4], 0.4)
    for (rx, ry, rw, rh) in [(6, 36, 6, 6), (18, 24, 5, 4), (20, 40, 5, 5)]:
        for y in range(ry, ry + rh):
            for x in range(rx, rx + rw):
                if hval("rr", x, y) < 0.65:
                    C.darken(s, x, y, RUST[2], 0.6)
    for x in range(5, 26):
        s.px(x, 19, mix(CON[1], COLD, 0.3))
    # roll-up door 2: jammed half open, dark bay with a junk pile
    for y in range(19, G + 1):
        for x in (28, 50):
            s.px(x, y, CON[2]); s.px(x + 1, y, CON[1])
    for y in range(20, G + 1):
        for x in range(30, 50):
            s.px(x, y, INTERIOR if y > 31 else mix(INTERIOR, COLD, 0.3))
    roll(30, 49, 20, 31)
    for x in range(30, 50):
        s.px(x, 32, MET[1])
    for k in range(10):                                    # the door's bottom slat sagging
        s.px(38 + k, 32 + k // 4, MET[2])
    # breach in the collapsed corner: broken block edges around a dark hole, a fallen joist
    for y in range(21, 37):
        for x in range(53, 61):
            r = ((x + 0.5 - 57.0) / 4.2) ** 2 + ((y + 0.5 - 29.0) / 8.5) ** 2
            if r < 1.0 + 0.25 * (hval("br", x, y) - 0.5):
                s.px(x, y, INTERIOR if r < 0.7 else mix(INTERIOR, BLOCK[1], 0.5))
    for y in range(21, 37):
        for x in range(52, 62):
            if s.get(x, y)[:3] == BLOCK[3][:3] or s.get(x, y)[:3] == mix(BLOCK[3], BLOCK[4], 0.5)[:3]:
                if s.get(x + 1, y) == INTERIOR or s.get(x, y + 1) == INTERIOR:
                    s.px(x, y, BLOCK[4])                    # lit broken edge
    for k in range(9):
        s.px(53 + k, 24 + k // 2, WOODG[3]); s.px(53 + k, 25 + k // 2, WOODG[1])
    grime(s, 1, 62, G, 4)
    C.vine(s, [(2, G), (3, 34), (1, 24), (3, 14)], seed=31)
    lib.outline(s, COLD, local=0.6)
    C.shadow(cv, 33.0, G + 1.4, 31.0, 1.4)
    cv.blit(s, 0, 0)
    # junk in the open bay: tyres and blocks, plus a tyre leaning on the wall
    rubble_heap(cv, 40.0, G + 1, 16, 8, seed=51, bricks=False, R=lib.ramp(X.CONCRETE_RAMP))
    t = Canvas(W, H)
    shapes.ring(t, 33.5, G - 1.5, 3.4, 2.0, 1.6, RUB)
    lib.outline(t, COLD, local=0.6)
    cv.blit(t, 0, 0)
    for (x, k) in [(8, "dry"), (21, "weed"), (55, "dry"), (60, "weed")]:
        C.tuft(cv, x, G + 1, k)
    return cv


# ================================================================================================
# ruin_office (80x112, footprint 5x3)
# ================================================================================================
def ruin_office():
    W, H = 80, 112
    cv = Canvas(W, H)
    s = Canvas(W, H)
    G = H - 2
    piers = [1 + 15 * k for k in range(6)]          # 3 px piers at 1, 16, 31, 46, 61, 76
    # roof band + parapet
    for x in range(2, 78):
        s.px(x, 2, CON[4])
        for y in range(3, 8):
            s.px(x, y, ASPH[3] if hval("otar", x, y) > 0.1 else ASPH[4])
    fill_concrete(s, 1, 8, 78, G)
    ledge(s, 1, 78, 8, CON, depth=2)
    # parapet band with the company logo + name
    for y in range(11, 18):
        for x in range(1, 79):
            s.px(x, y, CON[3] if y < 17 else CON[2])
    lc = mix(CREAMS, CON[3], 0.15)
    for (dx, dy) in [(1, 0), (2, 0), (3, 0), (0, 1), (4, 1), (0, 2), (4, 2), (0, 3), (4, 3),
                     (1, 4), (2, 4), (3, 4), (2, 1), (2, 2), (2, 3)]:
        s.px(6 + dx, 12 + dy, lc)                         # ringed-bar logo
    C.text(s, 13, 12, "NOVACORP", lc, fade={5: 0.3, 6: 0.5}, drop={7: 1})
    # storeys: spandrels + window ribbons
    floors = [(18, 32), (37, 51), (56, 70), (75, 88)]  # (window top, window bottom)
    kinds = [
        ["glass", "broken", "blinds", "glass", "burnt"],
        ["broken", "glass", "dark", "blinds", "broken"],
        ["blinds", "burnt", "glass", "broken", "glass"],
        ["glass", "boarded", "broken", "glass", "dark"],
    ]
    for f, (wy0, wy1) in enumerate(floors):
        for b in range(5):
            x0 = piers[b] + 3
            window(s, x0, wy0, 12, wy1 - wy0 + 1, kinds[f][b], seed=100 + f * 5 + b,
                   frame=CON, sill=False, lintel=False)
        for x in range(1, 79):
            s.px(x, wy1 + 1, CON[4]); s.px(x, wy1 + 2, CON[3])   # spandrel lip
        for x in range(1, 79):
            s.px(x, wy0 - 1, mix(CON[2], COLD, 0.35))            # shadow under the slab edge
    for p in piers:
        for y in range(11, 91):
            s.px(p, y, CON[4]); s.px(p + 1, y, CON[3]); s.px(p + 2, y, CON[2])
    # lobby: canopy, smashed glass wall, entrance buried in rubble
    for y in range(90, 94):
        for x in range(1, 79):
            s.px(x, y, CON[4] if y == 90 else CON[3] if y < 93 else CON[1])
    for y in range(94, G + 1):
        for x in range(4, 76):
            c = INTERIOR
            if y < 96:
                c = mix(INTERIOR, COLD, 0.4)
            s.px(x, y, c)
        for x in (4, 18, 32, 47, 61, 75):
            s.px(x, y, MET[2] if x > 4 else MET[3])
    for (x, y, c) in [(5, 95, GLASS[4]), (6, 95, GLASS[3]), (5, 96, GLASS[3]), (19, 95, GLASS[3]),
                      (60, 95, GLASS[3]), (62, 95, GLASS[4]), (63, 95, GLASS[3]), (74, 96, GLASS[3]),
                      (70, 108, GLASS[3]), (71, 108, GLASS[2]), (8, 108, GLASS[3])]:
        s.px(x, y, c)
    for (x0, x1) in ((1, 3), (76, 78)):
        for y in range(94, G + 1):
            for x in range(x0, x1 + 1):
                s.px(x, y, CON[4] if x == x0 else CON[2])
    # sheared-off upper right corner, stepped floor by floor: roof gone over the middle bays,
    # the top storey gone further right, two storeys gone at the corner. Jagged edges, slab ends
    # sticking out with rebar, dark gutted rooms behind.
    def cut(x):
        j = int(3 * hval("oc", x // 2)) + int(3 * hval("oc2", x)) - 1
        if x < 40:
            return 0
        if x < 52:
            return 11 + j                                  # parapet and roof broken off
        if x < 64:
            return 34 + j                                  # top storey gone, its floor slab left
        if x < 77:
            return 53 + j                                  # two storeys gone
        return 50 + j                                      # the corner column stub
    for x in range(40, 80):
        c0 = cut(x)
        for y in range(0, c0):
            s.a[y, x] = 0
        for y in range(c0, min(c0 + 4, G)):
            s.px(x, y, CON[4] if y == c0 else mix(INTERIOR, COLD, 0.15))
    for (x0, x1, y) in [(52, 66, 35), (64, 79, 54)]:     # floor slabs jutting from the break
        for x in range(x0, min(x1, 79) + 1):
            s.px(x, y - 1, CON[4]); s.px(x, y, CON[3]); s.px(x, y + 1, CON[1])
    for (x, y, dx) in [(54, 33, 1), (60, 33, -1), (67, 52, 1), (73, 52, 1), (45, 10, -1), (49, 10, 1)]:
        shapes.thick_line(s, [(x, y), (x + dx, y - 3)], 1, [RUST[3]])
        s.px(x + dx, y - 4, RUST[4])
    # weathering: rust streaks below window frames, a vine up the left pier
    for x in (9, 24, 38, 54, 68):
        C.rust_streak(s, x, 33, 3, 0.4); C.rust_streak(s, x + 3, 52, 3, 0.35)
    C.vine(s, [(2, G), (3, 92), (2, 80), (4, 66), (2, 58)], seed=61)
    C.vine(s, [(77, G), (77, 92), (78, 84)], seed=62)
    grime(s, 1, 78, G, 4)
    lib.outline(s, COLD, local=0.6)
    C.shadow(cv, 41.0, G + 1.4, 39.0, 1.4)
    cv.blit(s, 0, 0)
    rubble_heap(cv, 40.0, G + 1, 22, 12, seed=71)
    rubble_heap(cv, 70.0, G + 1, 12, 6, seed=72, bricks=False)
    for (x, k) in [(10, "dry"), (25, "weed"), (55, "dry")]:
        C.tuft(cv, x, G + 1, k)
    return cv


# ================================================================================================
# ruin_apartment (96x96, footprint 6x3)
# ================================================================================================
def ruin_apartment():
    W, H = 96, 96
    cv = Canvas(W, H)
    s = Canvas(W, H)
    G = H - 2
    B = BRICK_D
    # roof band + stair bulkhead
    for x in range(2, 94):
        s.px(x, 4, TRIM[3])
        for y in range(5, 10):
            s.px(x, y, ASPH[3] if hval("atar", x, y) > 0.1 else ASPH[4])
    fill_brick(s, 8, 0, 21, 9, B, blen=4, seed=9)
    for x in range(8, 22):
        s.px(x, 0, TRIM[4])
    # facade
    fill_brick(s, 1, 10, 94, G, B, blen=5, seed=7, mortar=mix(B[2], B[3], 0.5))
    # cornice: projecting stone with a dentil row
    for x in range(1, 95):
        s.px(x, 10, TRIM[4]); s.px(x, 11, TRIM[3]); s.px(x, 12, TRIM[2] if x % 3 else TRIM[1])
        s.px(x, 13, mix(s.get(x, 13), COLD, 0.5))
    # storeys
    cols = [6, 21, 36, 53, 68, 83]
    rows = [(17, 27), (36, 46), (55, 65)]
    kinds = [
        ["burnt", "curtain", "broken", "burnt", "burnt", "dark"],
        ["glass", "boarded", "curtain", "broken", "glass", "curtain"],
        ["curtain", "glass", "broken", "boarded", "dark", "glass"],
    ]
    for r, (y0, y1) in enumerate(rows):
        for c, x0 in enumerate(cols):
            window(s, x0, y0, 7, y1 - y0 + 1, kinds[r][c], seed=200 + r * 6 + c)
        ledge(s, 1, 94, y1 + 6, TRIM, depth=1) if r < 2 else None
    # ground floor: two windows each side, the stoop and a rubble-choked door
    for x0 in (6, 21, 68, 83):
        window(s, x0, 75, 7, 10, "boarded" if x0 in (21, 68) else "broken", seed=300 + x0)
    for y in range(72, G + 1):
        for x in range(41, 55):
            s.px(x, y, mix(INTERIOR, COLD, 0.25))
    for x in range(39, 57):
        s.px(x, 71, TRIM[4]); s.px(x, 72, TRIM[2])
    for y in range(72, G + 1):
        s.px(39, y, TRIM[3]); s.px(40, y, TRIM[2]); s.px(55, y, TRIM[3]); s.px(56, y, TRIM[2])
    C.plank(s, 41, 75, 54, 84, w=2)                       # doorway nailed shut behind the rubble
    C.plank(s, 41, 84, 54, 76, w=2)
    C.plank(s, 41, 79, 54, 79, w=2)
    for (k, y) in enumerate((G - 2, G - 1, G)):
        for x in range(38 - k, 58 + k):
            s.px(x, y, TRIM[4] if x < 57 + k else TRIM[2])
    # the top floor burnt out and the roof fallen in over the middle bays
    def top_cut(x):
        if 30 <= x <= 72:
            d = min(x - 30, 72 - x)
            return int(10 + min(d * 0.8, 12) + 3 * hval("acut", x // 2))
        return 0
    for x in range(30, 73):
        c0 = top_cut(x)
        for y in range(0, c0):
            s.a[y, x] = 0
        for y in range(c0, min(c0 + 3, G)):
            s.px(x, y, B[4] if y == c0 else mix(INTERIOR, CHAR[3], 0.4))
    for (bx, by0, by1) in [(38, 22, 28), (49, 25, 30), (61, 21, 27)]:
        for y in range(by0, by1):
            s.px(bx, y, CHAR[3]); s.px(bx + 1, y, CHAR[2])
    C.soot(s, 28, 6, 46, 18, 0.55, seed=5)
    # rusted fire escape over the right bays: landings, railings, stairs
    FE = lib.ramp([mix(c, P.RUST_DULL, 0.35) for c in P.METAL_RAMP[:4]] + [P.RUST_BRIGHT])
    for (ly, broken) in ((29, False), (48, False), (67, True)):
        for x in range(64, 92):
            if broken and x > 85:
                continue
            s.px(x, ly, FE[3]); s.px(x, ly + 1, FE[1])
            if x % 3 == 0:
                for y in range(ly - 5, ly):
                    s.px(x, y, FE[2])
        for x in range(64, 92 if not broken else 86):
            s.px(x, ly - 5, FE[3])
    for (ya, yb) in ((30, 47), (49, 66)):
        for k in range(yb - ya):
            x = 88 - int(k * 18 / (yb - ya))
            s.px(x, ya + k, FE[2]); s.px(x + 1, ya + k, FE[1])
    for k in range(7):                                    # the last flight hangs loose
        s.px(70 - k // 2, 69 + k, FE[2])
    for x in (66, 78, 90):
        C.rust_streak(s, x, 31, 5, 0.45); C.rust_streak(s, x, 50, 5, 0.45)
    grime(s, 1, 94, G - 3, 4)
    C.vine(s, [(2, G - 3), (3, 80), (2, 70), (4, 58), (3, 50), (5, 42)], seed=81)
    C.vine(s, [(30, G - 3), (31, 82), (29, 74)], seed=82)
    lib.outline(s, COLD, local=0.6)
    C.shadow(cv, 49.0, G + 1.4, 47.0, 1.4)
    cv.blit(s, 0, 0)
    rubble_heap(cv, 47.5, G + 1, 16, 10, seed=91)
    rubble_heap(cv, 18.0, G + 1, 9, 4, seed=92)
    for (x, k) in [(8, "dry"), (31, "weed"), (63, "dry"), (79, "weed"), (90, "dry")]:
        C.tuft(cv, x, G + 1, k)
    return cv


def build():
    return {
        "ruins/ruin_shopfront.png": ruin_shopfront(),
        "ruins/ruin_house.png": ruin_house(),
        "ruins/ruin_garage.png": ruin_garage(),
        "ruins/ruin_office.png": ruin_office(),
        "ruins/ruin_apartment.png": ruin_apartment(),
    }
