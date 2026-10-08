"""Low ruined walls: the broken remains of building walls (art/env/fences/ruin_wall_*.png).

Fence-sheet format, identical to fence_wood.png: 64x128 = 16 frames of 16x32; the frame for
connection mask m sits at ((m % 4) * 16, (m // 4) * 32), mask = N*1 + E*2 + S*4 + W*8 (bit set =
that neighbour cell is also a wall). Each frame is drawn bottom-anchored on its cell: rows 16..31
are the cell itself, rows 0..15 overhang the cell to the north (scripts/ground_rules.gd
fence_region, scripts/test_map.gd _add_cell_sprite).

The wall is a heightmap over the cell's 16x16 footprint, rendered by a tiny voxel painter in the
game's 3/4 projection: a footprint pixel (x, y) at height z lands on screen row y - z, so a
column of height h shows its top face at row y - h and its front face below it. Walls are 6 px
thick: the E-W band is footprint rows 23..28 (front face standing on row 28, like a fence post's
base), the N-S band is columns 5..10. Every frame renders only its own cell, and every arm meets
the cell border at the same height EDGE, so neighbouring frames continue each other's top faces
and front faces exactly whatever order they are drawn in. Overlaps between vertically adjacent
frames resolve like the real geometry: the southern frame (drawn later, it y-sorts lower) is the
nearer one. The only care needed is the outline: where an N arm runs on into the north
neighbour's frame, no outline is drawn across the joint.
"""
from __future__ import annotations

import numpy as np

from env import lib
from env.lib import Canvas, mix, rgba
from ruins_city import rc_common as C
from ruins_city.rc_common import ASH, BRICK, COLD, CON, DRY, RUST, WEED, hval

FW, FH = 16, 32
N, E, S, W = 1, 2, 4, 8
XW, XE = 5, 10          # N-S band columns
YN, YS = 23, 28         # E-W band footprint rows (frame coordinates)
YMID = 26               # first row of the front half of the E-W band
NS_MID = 8              # first column of the east half of the N-S band
# lime mortar: a dusty grey-brown between the brick and the concrete, so the bond reads as brick
MORTAR = mix(mix(BRICK[2], CON[3], 0.55), ASH, 0.25)


def _bits(mask):
    return bool(mask & N), bool(mask & E), bool(mask & S), bool(mask & W)


# ================================================================================================
# wall kinds: height profiles + materials
# ================================================================================================
class Kind:
    name = ""
    EDGE = 11
    # E-W run profile over x = 0..15 for the back half (rows 23..25) and front half (26..28)
    EW_BACK = []
    EW_FRONT = []
    # N-S run profile over footprint rows 16..31 (index y - 16), west half / east half of the band
    NS_WEST = []
    NS_EAST = []
    PIER = 14                         # corner / T / cross junction height
    # wall ends: centre heights when only one arm exists (the wall breaks off here)
    END_FROM_E = ([], [])              # (back, front) over x = 5..10
    END_FROM_W = ([], [])
    END_FROM_N = []                    # over rows 23..28
    END_FROM_S = []
    PILLAR_X = (XW, XE)                # mask 0 footprint columns (rows 23..28)
    PILLAR = []                        # 6 rows (23..28) of heights over PILLAR_X: mask 0
    REBAR = []                         # (x, y, extra height, lean, region) rebar stubs

    def ew(self, x, y):
        return self.EW_BACK[x] if y < YMID else self.EW_FRONT[x]

    def ns(self, x, y):
        return self.NS_WEST[y - 16] if x < NS_MID else self.NS_EAST[y - 16]

    def pier(self, x, y):
        return self.PIER

    # materials -----------------------------------------------------------------------------
    def front(self, x, z, y, h):
        raise NotImplementedError

    def top(self, x, y, h, band):
        raise NotImplementedError

    def top_edge(self, x, y):
        raise NotImplementedError


class Brick(Kind):
    """Red-brown brick: courses of 2 px bricks over 1 px mortar (3 px), bricks 7 px + joint,
    half-bond stagger of 4 px (period 8, so the bond continues across 16 px frames). The broken
    top steps a whole course (3 px) at a time, so every height is 3k + 2 (a full course).
    Straight runs stay fairly level (a continuous wall that lost its upper courses); the drama
    is at corners (taller piers) and at ends, which crumble down course by course."""
    name = "brick"
    EDGE = 11
    EW_BACK = [11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 8, 8, 8, 8, 11, 11]
    EW_FRONT = [11, 11, 8, 8, 8, 11, 11, 11, 11, 11, 8, 8, 5, 5, 8, 11]
    NS_WEST = [11, 11, 11, 11, 8, 8, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11]
    NS_EAST = [11, 11, 11, 8, 8, 5, 8, 11, 11, 11, 11, 11, 11, 11, 11, 11]
    PIER = 14
    END_FROM_E = ([8, 8, 11, 11, 11, 11], [5, 5, 5, 8, 8, 11])
    END_FROM_W = ([14, 14, 11, 11, 8, 8], [11, 11, 11, 8, 5, 5])
    END_FROM_N = [11, 11, 8, 8, 5, 5]
    END_FROM_S = [5, 5, 8, 8, 11, 11]
    # mask 0: a chunky broken pillar stub (8 wide x 6 deep, centred on the cell)
    PILLAR_X = (4, 11)
    PILLAR = [
        [14, 14, 14, 14, 14, 11, 11, 8],
        [14, 14, 14, 14, 14, 14, 11, 8],
        [14, 14, 14, 14, 14, 14, 11, 11],
        [14, 14, 14, 14, 14, 14, 14, 11],
        [11, 14, 14, 14, 14, 14, 14, 11],
        [11, 11, 14, 14, 14, 14, 14, 14],
    ]

    def pier(self, x, y):
        if (x, y) in ((XE, YN), (XE - 1, YN), (XE, YN + 1)):
            return 11                      # a corner knocked off the back of the pier
        return self.PIER

    def front(self, x, z, y, h):
        R = BRICK
        course = z // 3
        r = z % 3                          # 0 = lower brick row, 1 = upper brick row, 2 = mortar
        u = x + (4 if course % 2 else 0)
        bid = (u // 8, course)
        v = hval("brick", bid)
        mortar = MORTAR
        if r == 2 or u % 8 == 7:
            c = mortar
            if r == 2 and u % 8 == 7:
                c = mix(mortar, R[1], 0.3)
        else:
            base = R[3] if v < 0.5 else R[2] if v < 0.8 else mix(R[3], R[4], 0.6)
            c = mix(base, R[4], 0.35) if r == 1 else base
            if hval("missing", bid) < 0.10 and 2 <= z < h - 3:
                c = mix(R[0], COLD, 0.4) if r == 1 else R[1]   # a brick knocked out
        # grime / soot creeping up from the ground, ragged per column
        g = 2 + int(hval("grime", x) * 3)
        if z < g:
            c = mix(c, mix(ASH, COLD, 0.5), 0.5 - 0.12 * z)
        return c

    def top(self, x, y, h, band):
        R = BRICK
        c = R[4]
        if band == "ew":
            u = x + (4 if ((y - YN) // 3) % 2 else 0)
            if u % 8 == 7 and (y - YN) % 3 == 1:
                c = mix(R[3], R[4], 0.5)
        else:
            u = y + (4 if ((x - XW) // 3) % 2 else 0)
            if u % 8 == 7 and (x - XW) % 3 == 1:
                c = mix(R[3], R[4], 0.5)
        v = hval("crumb", x, y)
        if v < 0.07:
            c = R[5]
        elif v < 0.12:
            c = mix(R[3], R[4], 0.5)
        return c

    def top_edge(self, x, y):
        return BRICK[5]


class Concrete(Kind):
    """Cast concrete: formwork seams every 5 px, tie holes, precast panel joints at the frame
    edges, a crumbling top bitten into along the run, rusty rebar stubs where it broke."""
    name = "concrete"
    EDGE = 11
    EW_BACK = [11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 10, 9, 9, 10, 11]
    EW_FRONT = [11, 11, 8, 8, 8, 11, 11, 11, 11, 11, 11, 10, 9, 8, 10, 11]
    NS_WEST = [11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11]
    NS_EAST = [11, 11, 11, 8, 8, 8, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11]
    PIER = 15
    END_FROM_E = ([6, 7, 9, 10, 11, 11], [4, 5, 7, 9, 10, 10])
    END_FROM_W = ([13, 13, 11, 9, 7, 6], [13, 12, 10, 8, 5, 4])
    END_FROM_N = [11, 11, 8, 8, 5, 5]
    END_FROM_S = [5, 5, 8, 8, 11, 11]
    PILLAR_X = (4, 11)
    PILLAR = [
        [15, 15, 15, 14, 13, 12, 11, 10],
        [15, 15, 15, 15, 14, 13, 12, 11],
        [15, 15, 15, 15, 15, 14, 13, 12],
        [15, 15, 15, 15, 15, 15, 14, 13],
        [12, 12, 15, 15, 15, 15, 15, 14],
        [12, 12, 12, 15, 15, 15, 15, 15],
    ]
    # (x, y, extra height, lean, where): where = arm the stub belongs to ("e", "w", "c" centre
    # when it is a pier / end / pillar)
    REBAR = [(11, 24, 3, 1, "e"), (6, 24, 3, -1, "c"), (9, 25, 2, 1, "c")]

    def pier(self, x, y):
        if x >= XE - 1 and y <= YN + 1:
            return 12
        return self.PIER

    def front(self, x, z, y, h):
        R = CON
        c = R[2] if z < h - 1 else mix(R[2], R[3], 0.5)
        if z % 5 == 4:
            c = mix(R[2], R[1], 0.5)                       # formwork seam
        if x % 8 == 3 and z % 5 == 2 and 1 < z < h - 1:
            c = R[0]                                       # tie hole
        if x == 15:
            c = mix(R[1], R[0], 0.3)                       # precast panel joint
        elif x == 0:
            c = mix(R[2], R[3], 0.6)
        # water stains running down from the broken top
        st = hval("stain", x)
        if st < 0.35 and z > h - 3 - int(st * 18):
            c = mix(c, R[1], 0.4)
        g = 2 + int(hval("cgrime", x) * 3)
        if z < g:
            c = mix(c, mix(ASH, COLD, 0.45), 0.5 - 0.12 * z)
        return c

    def top(self, x, y, h, band):
        R = CON
        c = R[4]
        v = hval("ctop", x, y)
        if v < 0.10:
            c = R[5]
        elif v < 0.22:
            c = mix(R[3], R[4], 0.4)
        return c

    def top_edge(self, x, y):
        return CON[5]


KINDS = {"brick": Brick(), "concrete": Concrete()}


# ================================================================================================
# heightmap
# ================================================================================================
def heights(kind, mask):
    """(32, 16) int array: wall height on each footprint pixel of the cell (rows 16..31)."""
    n, e, s, w = _bits(mask)
    horiz = e or w
    vert = n or s
    H = np.zeros((FH, FW), int)
    for y in range(YN, YS + 1):
        for x in range(FW):
            if x < XW and w or x > XE and e:
                H[y, x] = kind.ew(x, y)
    for y in range(16, 32):
        if (y < YN and n) or (y > YS and s):
            for x in range(XW, XE + 1):
                H[y, x] = kind.ns(x, y)
    if mask == 0:
        x0, x1 = kind.PILLAR_X
        for y in range(YN, YS + 1):
            for x in range(x0, x1 + 1):
                H[y, x] = kind.PILLAR[y - YN][x - x0]
        return H
    for y in range(YN, YS + 1):
        j = y - YN
        for x in range(XW, XE + 1):
            i = x - XW
            if horiz and vert:
                h = kind.pier(x, y)
            elif e and w:
                h = kind.ew(x, y)
            elif n and s:
                h = kind.ns(x, y)
            elif e:
                h = kind.END_FROM_E[0 if y < YMID else 1][i]
            elif w:
                h = kind.END_FROM_W[0 if y < YMID else 1][i]
            elif n:
                h = kind.END_FROM_N[j]
            else:
                h = kind.END_FROM_S[j]
            H[y, x] = h
    return H


def _height_at(H, mask, kind, x, y):
    """Height including the neighbours' arms just beyond the frame (for edge shading)."""
    n, e, s, w = _bits(mask)
    if 0 <= x < FW and 16 <= y < FH:
        return int(H[y, x])
    if x < 0:
        return kind.EDGE if w and YN <= y <= YS else 0
    if x >= FW:
        return kind.EDGE if e and YN <= y <= YS else 0
    if y < 16:
        return kind.EDGE if n and XW <= x <= XE else 0
    return kind.EDGE if s and XW <= x <= XE else 0


# ================================================================================================
# rendering
# ================================================================================================
def _project(H):
    """Voxel painter: screen pixel -> (face, footprint y, z, column height) of the nearest face."""
    info = {}
    for sx in range(FW):
        for sy in range(FH):
            for y in range(FH - 1, 15, -1):           # nearest (southernmost) row first
                h = int(H[y, sx])
                if h <= 0:
                    continue
                if y - h <= sy <= y:
                    if sy == y - h:
                        info[(sx, sy)] = ("top", y, h, h)
                    else:
                        info[(sx, sy)] = ("front", y, y - sy, h)
                    break
    return info


def _band(x, y):
    return "ew" if YN <= y <= YS else "ns"


def frame(kind, mask):
    n, e, s, w = _bits(mask)
    H = heights(kind, mask)
    cv = Canvas(FW, FH)
    body = Canvas(FW, FH)
    info = _project(H)
    for (sx, sy), (face, y, z, h) in info.items():
        if face == "top":
            c = kind.top(sx, y, h, _band(sx, y))
            if _height_at(H, mask, kind, sx, y + 1) < h:
                c = kind.top_edge(sx, y)                     # lit front lip of the top face
            elif _height_at(H, mask, kind, sx, y - 1) < h and \
                    _height_at(H, mask, kind, sx - 1, y) >= h:
                c = mix(c, kind.top_edge(sx, y), 0.35)      # back rim catches a little light
        else:
            c = kind.front(sx, z, y, h)
            if _height_at(H, mask, kind, sx - 1, y) <= z:
                c = mix(c, kind.top_edge(sx, y), 0.3)        # lit west end of a face
            elif _height_at(H, mask, kind, sx + 1, y) <= z:
                c = mix(c, COLD, 0.3)                        # shaded east end of a face
        body.px(sx, sy, c)
    # rebar stubs (concrete): 1 px rods sticking out of the broken top
    straight = mask in (E | W, N | S)
    for (rx, ry, extra, lean, where) in kind.REBAR:
        if H[ry, rx] <= 0:
            continue
        if straight or where == "e" and not e or where == "w" and not w:
            continue
        top = ry - int(H[ry, rx])
        if info.get((rx, top), ("", 0))[1] != ry:
            continue                                         # hidden behind a nearer face
        for k in range(1, extra + 1):
            body.px(rx, top - k, RUST[3] if k < extra else RUST[4])
        if lean:
            body.px(rx + lean, top - extra - 1, RUST[4])
        body.px(rx, top, RUST[2])
    # outline: never across the joint where an N arm continues into the north neighbour's frame
    skip = np.zeros((FH, FW), bool)
    if n:
        skip[: 16 - kind.EDGE, XW:XE + 1] = True
    lib.outline(body, COLD, local=0.6, skip=skip)
    _base_details(body, kind, mask, H)
    # contact shadows (translucent, cold, offset bottom-right): under the E-W faces, along the
    # east side of N-S arms, an ellipse under the lone pillar
    sh = rgba(COLD[:3], lib.SHADOW_ALPHA)
    if mask == 0:
        cv.shadow(8.5, YS + 1.7, 5.0, 1.4, color="#181a16")
    else:
        pts = set()
        for x in range(FW):
            if H[YS, x] > 0:
                pts |= {(x, YS + 1), (x, YS + 2)}
                if x + 1 < FW and H[YS, x + 1] == 0:
                    pts.add((x + 1, YS + 1))
        for y in range(16, FH):
            if H[y, XE] > 0 and not (e and YN <= y <= YS):
                pts.add((XE + 2, y))
        for (x, y) in sorted(pts):            # each pixel once: shadows darken, never stack
            cv.px(x, y, sh)
    cv.blit(body, 0, 0)
    return cv


def _base_details(s, kind, mask, H):
    """Weeds and fallen chips at the foot of the visible E-W faces (inside the frame, never on
    its left/right edges, so they cannot be cut off by a neighbour)."""
    n, e, s_, w = _bits(mask)
    R = BRICK if kind.name == "brick" else CON
    if mask in (E | W, N | S):
        return                       # straight runs stay clean: details would repeat every cell
    if w and H[YS, 2] > 0:
        C.tuft(s, 2, YS + 1, "dry")
        s.px(4, YS + 2, R[3]); s.px(5, YS + 2, R[1])
    if e and H[YS, 13] > 0:
        C.tuft(s, 13, YS + 1, "weed")
    if mask == 0:
        C.tuft(s, 11, YS + 1, "dry")
        s.px(3, YS + 2, R[4]); s.px(4, YS + 2, R[2])


def sheet(kind):
    return lib.grid_sheet([frame(kind, m) for m in range(16)], 4)


def build():
    out = {}
    for name, kind in KINDS.items():
        out[f"fences/ruin_wall_{name}.png"] = sheet(kind)
    return out
