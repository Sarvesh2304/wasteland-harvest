"""Living-settlement buildings (art/buildings/): the player's trading post, the mayor's house with
its scrap radio mast, and the festival booth.

Same contract as the Town Works buildings (docs/ART_STYLE.md section 8, structures.gd
_bottom_align): exactly as wide as the footprint, standing on its bottom edge, roof / sign / mast
rising above it; 1 px selective warm outline, warm contact shadow, light from the top-left.
Drawn on env.lib canvases with the townsfolk kit's surface helpers (clapboard, corrugated tin,
crates) so they sit with store_expanded.png and the PixelLab buildings.
"""
from __future__ import annotations

import math

import palette as P
from env import colors as X
from env import lib
from env.lib import Canvas, mix, rgba
from env.props import _crate, _barrel_body
from townsfolk.tf_buildings import INTERIOR, _hash, corrugated, _produce_crate

WARM = lib.WARM
PW = lib.ramp(P.POST_WOOD_RAMP)       # trading post boards (shack.png's plum-brown)
TIN = lib.ramp(P.POST_TIN_RAMP)       # trading post roof (storage_shed.png's grey tin)
WOOD = lib.ramp(P.WOOD_RAMP)
MET = lib.ramp(P.METAL_RAMP)
RUST = lib.ramp(P.RUST_RAMP)
STONE = lib.ramp(P.STONE_RAMP)
BRASS = lib.ramp(P.BRASS_RAMP)
GLOW = lib.ramp(P.WINDOW_GLOW_RAMP)
CANV = lib.ramp(X.CANVAS_RAMP)
ROPE = lib.ramp(X.ROPE)
G_GREEN = lib.ramp(X.GLASS_GREEN)
G_BROWN = lib.ramp(X.GLASS_BROWN)
CLOTH_RED = lib.ramp(X.CLOTH_RED)
TEAL = lib.ramp(P.FEST_TEAL_RAMP)
FRED = lib.ramp(P.FEST_RED_RAMP)
GOLD = lib.ramp(P.FEST_GOLD_RAMP)
FBLUE = lib.ramp(P.FEST_BLUE_RAMP)
CREAM = rgba(P.CREAM)


def _outlined(layer, local=0.6):
    lib.outline(layer, WARM, local=local)
    return layer


# ================================================================================================
# trading post (48 x 44, footprint 3 x 2)
# ================================================================================================
TP_W, TP_H = 48, 44
TP_EAVE = 20         # fascia row (front edge of the roof)
TP_WALL = (2, 45)    # wall x range
TP_OPEN = (7, 40, 24, 33)   # open front: x0, x1, y0, y1 (counter top starts at y1)
TP_BASE = 42         # sill row; row 43 is the contact shadow


def _tp_walls(s):
    x0, x1 = TP_WALL
    # end walls / corner posts: vertical boards
    for y in range(TP_EAVE + 1, TP_BASE):
        for x in list(range(x0, TP_OPEN[0])) + list(range(TP_OPEN[1] + 1, x1 + 1)):
            k = (x - x0) % 3
            c = PW[4] if k == 0 else PW[3] if k == 1 else PW[2]
            if x == x0:
                c = PW[5]
            if x >= x1 - 1:
                c = PW[1] if x == x1 else PW[2]
            if x in (TP_OPEN[0] - 1,):
                c = PW[2]                                   # post's shaded inner edge
            if x == TP_OPEN[1] + 1:
                c = PW[4]                                   # lit inner edge of the right post
            if _hash("tpk", x, y // 4) < 0.06:
                c = PW[1]                                   # knots / nail holes
            s.px(x, y, c)
    # lintel beam under the eave
    for y in range(TP_EAVE + 1, TP_OPEN[2]):
        for x in range(TP_OPEN[0] - 1, TP_OPEN[1] + 2):
            c = PW[4] if y == TP_EAVE + 1 else PW[3] if y == TP_EAVE + 2 else PW[1]
            s.px(x, y, c)


def _tp_interior(s):
    ox0, ox1, oy0, oy1 = TP_OPEN
    lamp_x = 24
    for y in range(oy0, oy1 + 1):
        for x in range(ox0, ox1 + 1):
            # back wall boards, warmed by the lantern hanging in the middle
            k = (x - ox0) % 4
            c = INTERIOR[2] if k else INTERIOR[1]
            d = math.hypot((x - lamp_x) / 1.6, (y - (oy0 + 2)))
            if d < 6:
                c = mix(c, GLOW[0], 0.55)
            elif d < 10:
                c = mix(c, GLOW[0], 0.3)
            if y == oy0:
                c = INTERIOR[0]                             # shadow under the lintel
            s.px(x, y, c)
    # shelves along the back wall
    for sy in (27, 31):
        for x in range(ox0, ox1 + 1):
            s.px(x, sy, WOOD[3] if x < ox1 - 1 else WOOD[2])
            s.px(x, sy + 1, mix(WOOD[1], WARM, 0.3))
    # top shelf: jars, tins, bottles, a folded blanket
    goods = [
        (8, [(0, G_GREEN[2]), (0, G_GREEN[1])], 2),
        (11, [(0, G_BROWN[3]), (0, G_BROWN[1])], 2),
        (14, [(0, MET[4]), (0, MET[2])], 2),
        (15, [(0, MET[3]), (0, MET[1])], 2),
        (29, [(0, G_GREEN[3]), (0, G_GREEN[1])], 2),
        (32, [(0, G_BROWN[2]), (0, G_BROWN[0])], 2),
        (35, [(0, MET[4]), (0, MET[2])], 2),
        (36, [(0, MET[3]), (0, MET[1])], 2),
        (38, [(0, G_GREEN[2]), (0, G_GREEN[0])], 2),
    ]
    for (gx, cols, h) in goods:
        for j, (_, c) in enumerate(cols):
            s.px(gx, 27 - h + j, c)
    for x in range(17, 22):                                 # folded red blanket
        s.px(x, 25, CLOTH_RED[3] if x < 21 else CLOTH_RED[2])
        s.px(x, 26, CLOTH_RED[2] if x < 21 else CLOTH_RED[1])
    # lower shelf: sacks and a bolt of teal cloth
    for (bx, R) in ((9, CANV), (13, CANV)):
        for (dx, dy, k) in ((1, -3, 3), (0, -2, 4), (1, -2, 3), (2, -2, 2), (0, -1, 3), (1, -1, 3),
                            (2, -1, 1)):
            s.px(bx + dx, 31 + dy, R[k])
    for x in range(30, 38):
        s.px(x, 29, TEAL[3] if x < 37 else TEAL[2])
        s.px(x, 30, TEAL[2] if x < 37 else TEAL[1])
    s.px(33, 29, TEAL[1]); s.px(33, 30, TEAL[0])
    # the lantern on a hook under the lintel (lit: a working shop)
    s.px(lamp_x, oy0, MET[2])
    s.px(lamp_x - 1, oy0 + 1, BRASS[2]); s.px(lamp_x, oy0 + 1, BRASS[3]); s.px(lamp_x + 1, oy0 + 1, BRASS[1])
    for y in (oy0 + 2, oy0 + 3):
        s.px(lamp_x - 1, y, GLOW[3]); s.px(lamp_x, y, GLOW[4]); s.px(lamp_x + 1, y, GLOW[2])
    s.px(lamp_x - 1, oy0 + 4, BRASS[2]); s.px(lamp_x, oy0 + 4, BRASS[2]); s.px(lamp_x + 1, oy0 + 4, BRASS[0])


def _tp_counter(s):
    x0, x1 = 5, 42
    top = TP_OPEN[3]
    for y in range(top, TP_BASE):
        for x in range(x0, x1 + 1):
            if y == top:
                c = WOOD[5] if x < x1 else WOOD[3]
            elif y == top + 1:
                c = WOOD[3] if x < x1 else WOOD[2]
            else:
                k = (y - top - 2) % 3
                c = WOOD[4] if k == 0 else WOOD[3] if k == 1 else WOOD[2]
                if x == x0:
                    c = mix(c, WOOD[5], 0.5)
                if x == x1:
                    c = WOOD[1]
                if (x - x0 + (y - top) // 3 * 7) % 13 == 0 and k:
                    c = WOOD[2]                                 # board joints
            s.px(x, y, c)
    # a painted price board nailed to the counter front: three rows of tally marks, no letters
    bx, by, bw, bh = 19, top + 3, 10, 5
    for y in range(by, by + bh):
        for x in range(bx, bx + bw):
            edge = x in (bx, bx + bw - 1) or y in (by, by + bh - 1)
            c = CANV[2] if edge else CANV[4]
            if edge and (x == bx or y == by):
                c = CANV[3]
            s.px(x, y, c)
    for (x, y) in ((bx + 2, by + 1), (bx + 3, by + 1), (bx + 5, by + 1), (bx + 6, by + 1), (bx + 7, by + 1),
                   (bx + 2, by + 3), (bx + 4, by + 3), (bx + 5, by + 3), (bx + 7, by + 3)):
        s.px(x, y, rgba(P.MEDIC_RED_RAMP[1]))
    s.px(bx + 4, by + 2, rgba(P.CAP_RED)); s.px(bx + 6, by + 2, rgba(P.CAP_BLUE))
    # sill / foundation stones
    for x in range(1, 47):
        c = STONE[3] if (x // 4) % 2 else STONE[2]
        if x % 4 == 3:
            c = STONE[1]
        s.px(x, TP_BASE, c)


def _tp_roof(s):
    x0, x1 = 0, 47
    y0 = 9
    corrugated(s, x0 + 1, y0, x1 - 1, TP_EAVE - 2, TIN, seed=3, panel=11, course=5,
               tints=[(TIN[3], 0.0), (RUST[3], 0.38), (TIN[3], 0.0), (TIN[4], 0.15),
                      (TIN[3], 0.0)])
    # ridge cap along the back edge and rounded back corners
    for x in range(x0 + 1, x1):
        s.px(x, y0, TIN[5] if x < x1 - 4 else TIN[4])
    s.a[y0, x0 + 1] = 0
    s.a[y0, x1 - 1] = 0
    # fascia board along the front (eave) edge
    for x in range(x0, x1 + 1):
        s.px(x, TP_EAVE - 1, PW[4] if x < x1 else PW[2])
        s.px(x, TP_EAVE, PW[2] if x < x1 else PW[1])
    # a riveted scrap patch and a couple of rust streaks
    for y in range(11, 15):
        for x in range(31, 37):
            edge = x in (31, 36) or y in (11, 14)
            c = RUST[2] if edge else (RUST[4] if (x + y) % 3 == 0 else RUST[3])
            s.px(x, y, c)
    for (x, y) in ((31, 11), (36, 11), (31, 14), (36, 14)):
        s.px(x, y, MET[4])
    for (x, y) in ((8, 15), (8, 16), (8, 17), (19, 16), (19, 17), (42, 13), (42, 14)):
        s.px(x, y, mix(s.get(x, y), RUST[2], 0.6))


def _tp_sign():
    """Two posts on the roof, a crossbar, a plank sign on two short chains with a painted brass
    balance scale between two bottle caps."""
    g = Canvas(TP_W, TP_H)
    for px_ in (8, 38):                                      # posts (stand on the roof)
        for y in range(2, 14):
            g.px(px_, y, WOOD[3]); g.px(px_ + 1, y, WOOD[1])
    for x in range(6, 42):                                   # crossbar
        g.px(x, 1, WOOD[4] if x < 41 else WOOD[2])
        g.px(x, 2, WOOD[2] if x < 41 else WOOD[1])
    for cx in (14, 33):                                      # chains
        g.px(cx, 3, MET[3])
        g.px(cx, 4, MET[1])
    bx0, by0, bw, bh = 12, 5, 24, 9
    for y in range(by0, by0 + bh):
        for x in range(bx0, bx0 + bw):
            edge = x in (bx0, bx0 + bw - 1) or y in (by0, by0 + bh - 1)
            c = CANV[4] if y < by0 + 4 else CANV[3]
            if y == by0 + 4 and not edge:
                c = CANV[2]                                   # the seam between two planks
            if edge:
                c = WOOD[1] if (x == bx0 + bw - 1 or y == by0 + bh - 1) else WOOD[3]
            if not edge and _hash("sgn", x, y) < 0.07:
                c = CANV[2]                                   # weathering
            g.px(x, y, c)
    # balance scale painted in dark brass: post on a foot, beam, two hanging pans
    ink = BRASS[1]
    cx = bx0 + bw // 2
    for y in range(by0 + 2, by0 + 8):
        g.px(cx, y, ink)
    for x in range(cx - 2, cx + 3):
        g.px(x, by0 + 7, ink)
    g.px(cx, by0 + 1, BRASS[2])
    for x in range(cx - 6, cx + 7):
        g.px(x, by0 + 2, ink)
    for side in (-1, 1):
        px_ = cx + side * 6
        g.px(px_ - 1, by0 + 3, ink); g.px(px_ + 1, by0 + 3, ink)
        g.px(px_ - 1, by0 + 4, ink); g.px(px_ + 1, by0 + 4, ink)
        for x in range(px_ - 2, px_ + 3):
            g.px(x, by0 + 5, BRASS[3] if x < px_ + 2 else BRASS[2])
        g.px(px_ - 1, by0 + 6, BRASS[2]); g.px(px_, by0 + 6, BRASS[2]); g.px(px_ + 1, by0 + 6, BRASS[1])
    # a red and a blue bottle cap in the left pan
    g.px(cx - 7, by0 + 4, rgba(P.CAP_RED)); g.px(cx - 6, by0 + 4, rgba(P.CAP_BLUE))
    return _outlined(g)


def _tp_props():
    """A crate of produce at the left corner and a water barrel at the right, on the ground."""
    layers = []
    c = Canvas(TP_W, TP_H)
    _produce_crate(c, 0, 36, ["#5a3a28", "#8c5a38", "#b07850"], w=7)    # mutant potatoes
    layers.append(c)
    b = Canvas(TP_W, TP_H)
    _barrel_body(b, 44.0, 42, 2.6, 34, WOOD, hoops=(2, 6))
    for x in range(41, 48):                                  # lid
        b.px(x, 33, WOOD[4] if x < 46 else WOOD[2])
    layers.append(b)
    return [_outlined(l) for l in layers]


def trading_post():
    s = Canvas(TP_W, TP_H)
    _tp_walls(s)
    _tp_interior(s)
    _tp_counter(s)
    roof = Canvas(TP_W, TP_H)
    _tp_roof(roof)
    lib.outline(s, WARM, local=0.6)
    _outlined(roof, 0.55)
    # the eave throws a shadow onto the lintel
    for x in range(TP_WALL[0], TP_WALL[1] + 1):
        y = TP_EAVE + 1
        if s.alpha(x, y) == 255:
            s.px(x, y, mix(s.get(x, y), WARM, 0.45))
    # goods on the counter top: a ledger, a jar of caps, a small brass scale
    top = TP_OPEN[3]
    deck = Canvas(TP_W, TP_H)
    for x in range(10, 15):                                  # ledger (open book)
        deck.px(x, top - 1, CREAM if x != 12 else CANV[2])
        deck.px(x, top, CANV[3] if x != 12 else CANV[1])
    for y in range(top - 3, top + 1):                        # jar of caps
        for x in range(16, 19):
            c = [rgba(P.CAP_RED), rgba(P.CAP_BLUE), BRASS[3]][(x + y) % 3]
            deck.px(x, y, c if y > top - 3 else MET[3])
    deck.px(16, top - 2, rgba(P.CAP_GLINT))
    for x in range(31, 38):                                  # brass scale: base, post, beam, pans
        deck.px(x, top - 4, BRASS[3] if x < 36 else BRASS[2])
    for y in range(top - 4, top + 1):
        deck.px(34, y, BRASS[2])
    deck.px(33, top, BRASS[3]); deck.px(35, top, BRASS[1])
    for px_ in (31, 37):
        deck.px(px_, top - 3, BRASS[1])
        deck.px(px_ - 1, top - 2, BRASS[3]); deck.px(px_, top - 2, BRASS[3]); deck.px(px_ + 1, top - 2, BRASS[1])
    deck.px(36, top - 3, rgba(P.CAP_RED))                     # a cap on the right pan's chain
    _outlined(deck)
    out = Canvas(TP_W, TP_H)
    out.shadow(24.0, TP_H - 0.6, 24, 1.0)
    out.blit(s, 0, 0)
    out.blit(roof, 0, 0)
    out.blit(_tp_sign(), 0, 0)
    out.blit(deck, 0, 0)
    for l in _tp_props():
        out.blit(l, 0, 0)
    return out


# ================================================================================================
# the mayor's house with the scrap radio mast (64 x 72; mayor_house.png bottom-aligned)
# ================================================================================================
MH_W, MH_H = 64, 72
MAST_X = 18            # left rail of the 3 px lattice mast
MAST_TOP = 25          # the aerial's boom row; the whip rises above it. Kept low on purpose: the
                       # house stands on map row 1, and the camera's top edge (map bounds) sits
                       # near this sprite's row 18 (in-game check), so the aerial must sit below it
MAST_FOOT = 39         # canvas row where the mast stands on the roof (roof row 15 of the PNG + 24)
WIRE_ANCHORS = ((9, 38), (31, 35))


def mayor_house_antenna(repo):
    """mayor_house.png on a taller canvas (bottom-aligned, pixels untouched), plus a scrap radio
    mast on the left roof: a 3 px lattice of salvaged angle iron (rust-spotted), a fishbone
    aerial on top, a whip with a red tip lamp, two guy wires to bolts on the roof, and the feed
    cable running down to the eave."""
    house = Canvas.load(repo / "art/buildings/mayor_house.png")
    assert (house.w, house.h) == (64, 48), (house.w, house.h)
    dy = MH_H - house.h
    MM = [MET[0]] + MET[:-1]                                     # one step darker: weathered iron
    cv = Canvas(MH_W, MH_H)
    cv.blit(house, 0, dy)
    wire = mix(MM[0], WARM, 0.35)
    wires = Canvas(MH_W, MH_H)
    for (ax, ay) in WIRE_ANCHORS:
        sx = MAST_X if ax < MAST_X else MAST_X + 2
        for (x, y) in lib.line_points(sx, MAST_TOP + 3, ax, ay):
            wires.px(x, y, wire)
    mast = Canvas(MH_W, MH_H)
    x0 = MAST_X
    for y in range(MAST_TOP + 1, MAST_FOOT + 1):
        mast.px(x0, y, MM[3])                                   # lit rail
        mast.px(x0 + 2, y, MM[1])                               # shaded rail
        k = (y - MAST_TOP) % 4                                   # zig-zag bracing
        if k == 1:
            mast.px(x0 + 1, y, MM[2])
        elif k == 3:
            mast.px(x0 + 1, y, MM[1])
        if _hash("mast", y) < 0.2:
            mast.px(x0 + 2, y, RUST[2])
        if _hash("mastl", y) < 0.12:
            mast.px(x0, y, RUST[3])
    for x in range(x0, x0 + 3):                                  # a cross-tie halfway
        mast.px(x, 32, MM[3] if x < x0 + 2 else MM[1])
    # fishbone aerial: boom with five elements, longest at the back
    boom_y = MAST_TOP
    for x in range(x0 - 6, x0 + 10):
        mast.px(x, boom_y, MM[3] if x < x0 + 8 else MM[2])
    for (ex, half) in ((x0 - 5, 3), (x0 - 1, 3), (x0 + 3, 2), (x0 + 6, 2), (x0 + 9, 1)):
        for y in range(boom_y - half, boom_y + half + 1):
            if y != boom_y:
                mast.px(ex, y, MM[4] if y < boom_y else MM[2])
    # whip and the red warning lamp
    for y in range(14, boom_y):
        mast.px(x0 + 1, y, MM[3] if y > 15 else MM[4])
    mast.px(x0 + 1, 13, rgba(P.MEDIC_RED_RAMP[2]))
    mast.px(x0 + 1, 12, rgba(P.MEDIC_RED_RAMP[4]))
    # a scrap tin junction box strapped on
    for y in range(33, 36):
        for x in range(x0 + 3, x0 + 6):
            mast.px(x, y, MM[4] if y == 33 else (MM[3] if x < x0 + 5 else MM[1]))
    mast.px(x0 + 4, 34, RUST[3])
    # base clamp where it is lashed to the roof
    for x in range(x0 - 1, x0 + 4):
        mast.px(x, MAST_FOOT, MM[2] if x < x0 + 3 else MM[0])
    lib.outline(mast, WARM, local=0.5)
    cv.blit(wires, 0, 0)
    cv.blit(mast, 0, 0)
    for (ax, ay) in WIRE_ANCHORS:                                # bolts the wires are tied to
        cv.px(ax, ay, MM[4])
    # feed cable from the junction box down the roof to the eave
    for (x, y) in lib.line_points(x0 + 5, 36, x0 + 9, 49):
        if cv.alpha(x, y) == 255 and y > MAST_FOOT:
            cv.px(x, y, mix(MM[0], WARM, 0.3))
        elif y <= MAST_FOOT:
            cv.px(x, y, mix(MM[0], WARM, 0.3))
    return cv


# ================================================================================================
# festival booth (32 x 40, footprint 2 x 1)
# ================================================================================================
FB_W, FB_H = 32, 40


def festival_booth():
    """A striped teal / cream canopy booth: two corner poles with gold-and-red pennants, a
    scalloped valance, a counter draped in red cloth with a gold trim, prizes on the back."""
    s = Canvas(FB_W, FB_H)
    poles = Canvas(FB_W, FB_H)
    # poles (front corners), from the ground to above the canopy
    for px_ in (2, 28):
        for y in range(3, 39):
            poles.px(px_, y, WOOD[4])
            poles.px(px_ + 1, y, WOOD[2])
        poles.px(px_, 2, GOLD[3]); poles.px(px_ + 1, 2, GOLD[1])
    # a string of little flags between the pole tops, sagging over the canopy's ridge
    flag_cols = [FRED, GOLD, TEAL, FBLUE, FRED, GOLD]
    pts = []
    for x in range(4, 28):
        t = (x - 3) / 25
        pts.append((x, round(3 + 3.2 * 4 * t * (1 - t) * 0.75)))
    for (x, y) in pts:
        poles.px(x, y, ROPE[0])
    for k, fx in enumerate((6, 10, 14, 18, 22, 25)):
        y = dict(pts)[fx] + 1
        R = flag_cols[k]
        poles.px(fx - 1, y, R[3]); poles.px(fx, y, R[2]); poles.px(fx + 1, y, R[1])
        poles.px(fx - 1, y + 1, R[2]); poles.px(fx, y + 1, R[1])
        poles.px(fx - 1, y + 2, R[1])
    # canopy roof seen from above, sloping to the front: rows 9..17
    for y in range(9, 18):
        inset = max(0, 3 - (y - 9) // 2)
        for x in range(inset, FB_W - inset):
            stripe = (x // 4) % 2 == 0
            c = (TEAL[3] if y < 14 else TEAL[2]) if stripe else (CANV[4] if y < 14 else CANV[3])
            if y == 9:
                c = mix(c, CREAM, 0.4)
            if x >= FB_W - 4:
                c = mix(c, WARM, 0.18)
            s.px(x, y, c)
    for x in range(14, 18):                                  # finial on the ridge
        s.px(x, 8, GOLD[3] if x < 17 else GOLD[1])
    s.px(15, 7, GOLD[3]); s.px(16, 7, GOLD[2])
    # scalloped valance with a gold hem
    for x in range(FB_W):
        stripe = (x // 4) % 2 == 0
        depth = 3 if (x % 4) in (1, 2) else 2
        for d in range(depth):
            if d == depth - 1:
                c = GOLD[2] if (x % 4) in (1, 2) else GOLD[1]
            else:
                c = (TEAL[2] if stripe else CANV[3]) if d == 0 else (TEAL[1] if stripe else CANV[2])
            s.px(x, 18 + d, c)
    # back wall of the booth (in shade), prize ribbons and a jar on a shelf
    for y in range(21, 29):
        for x in range(4, 28):
            c = INTERIOR[2] if (x // 3) % 2 else INTERIOR[1]
            if y == 21:
                c = INTERIOR[0]
            s.px(x, y, c)
    for x in range(5, 27):
        s.px(x, 25, WOOD[3]); s.px(x, 26, WOOD[1])
    for (rx, R) in ((7, FRED), (11, FBLUE), (15, GOLD)):     # rosettes pinned on the back wall
        s.px(rx, 22, R[3]); s.px(rx + 1, 22, R[2]); s.px(rx, 23, R[2]); s.px(rx + 1, 23, R[1])
        s.px(rx, 24, R[1])
    for (gx, G) in ((20, G_GREEN), (23, G_BROWN)):            # jars of preserves on the shelf
        s.px(gx, 23, MET[4]); s.px(gx + 1, 23, MET[2])
        s.px(gx, 24, G[3]); s.px(gx + 1, 24, G[1])
    # counter: red cloth over the top and front, gold trim, a scalloped hem
    for y in range(28, 39):
        for x in range(3, 29):
            if y == 28:
                c = FRED[3] if x < 28 else FRED[2]
            elif y == 29:
                c = GOLD[3] if x < 28 else GOLD[1]
            else:
                fold = (x - 3) % 6
                c = FRED[2] if fold in (0, 1) else FRED[1] if fold in (2, 3, 4) else FRED[0]
                if x == 3:
                    c = FRED[3]
                if y == 38 and (x % 3) == 2:
                    continue
                if y == 37:
                    c = GOLD[2] if (x % 3) != 2 else c
            s.px(x, y, c)
    # a prize rosette painted on the cloth: gold ring, red heart, two little tails
    sx, sy = 15, 32
    ros = [".GGG.", "GgFgG", "GFfFG", "GgFgG", ".GGG."]
    cm = {"G": GOLD[3], "g": GOLD[2], "F": FRED[3], "f": FRED[2]}
    for j, row in enumerate(ros):
        for i, ch in enumerate(row):
            if ch != ".":
                s.px(sx - 2 + i, sy - 2 + j, cm[ch] if j < 3 or ch not in "G" else GOLD[2])
    for (dx, dy) in ((-1, 3), (1, 3), (-2, 4), (2, 4)):
        s.px(sx + dx, sy + dy, GOLD[1])
    lib.outline(s, WARM, local=0.6)
    lib.outline(poles, WARM, local=0.55)
    out = Canvas(FB_W, FB_H)
    out.shadow(16.0, FB_H - 0.6, 15, 1.0)
    out.blit(poles, 0, 0)
    # the front of the poles shows over the counter (they stand at the front corners)
    out.blit(s, 0, 0)
    for px_ in (2, 28):
        for y in range(28, 39):
            out.px(px_, y, WOOD[4])
            out.px(px_ + 1, y, WOOD[2])
        out.px(px_ - 1 if px_ == 2 else px_ + 2, 39, mix(WOOD[1], WARM, 0.5))
    return out
