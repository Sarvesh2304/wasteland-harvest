"""Fences and gates.

Fence sheets: 16 connection variants, mask = N*1 + E*2 + S*4 + W*8 (bit set = fence neighbour in
that direction). Frames are 16x32, laid out 4x4 (mask m at column m%4, row m//4) -> 64x128.
The logical cell is the bottom 16x16 of each frame; the post base stands on the ground at about
(8, 28). E/W rails run to the frame edges (x=0 / x=15) at fixed heights, so neighbours join
seamlessly. N/S connectors occupy x=6..9 only: N fills y=12..15 (up to the base of the
north neighbour's post, which sits at y=12 in this frame's coordinates) and S fills y=29..31,
exactly the pixels the south neighbour's own N connector paints, so either draw order matches.

Gates: 2 frames of 16x32 (closed, open) -> 32x32; a gate sits in an E-W fence run.
"""
from __future__ import annotations

import palette as P
from env import colors as X
from env import lib
from env.lib import Canvas, mix, rgba

FW, FH = 16, 32
BASE = 28                      # ground line of a post
N, E, S, W = 1, 2, 4, 8

WOOD = lib.ramp(P.WOOD_RAMP)
BARK = lib.ramp(P.BARK_RAMP)
MET = lib.ramp(P.METAL_RAMP)
RUST = lib.ramp(P.RUST_RAMP)
WARM = lib.WARM


def _dark(c):
    """Local dark outline shade of a material colour."""
    return mix(c, lib.WARM, 0.62)


def _shadow_strip(cv, x0, x1, y=BASE + 1):
    for x in range(x0, x1 + 1):
        cv.px(x, y, rgba(P.OUTLINE_WARM, lib.SHADOW_ALPHA))


# ================================================================================================
# weathered wood fence
# ================================================================================================
# a slightly weathered (greyed) wood ramp for the everyday fence
WW = [mix(c, MET[2], 0.18) for c in WOOD]
RAIL_ROWS = (18, 23)             # top row of the upper / lower rail (2px rails)
SAG = {2: 1, 3: 1, 12: 1, 13: 1}  # upper-rail sag (x -> +y) away from the frame edges


def _wood_rail(cv, xs, top, sag=False):
    for x in xs:
        dy = SAG.get(x, 0) if sag else 0
        y = top + dy
        cv.px(x, y - 1, _dark(WW[3]))
        lit = WW[5] if (x * 5 + top) % 7 == 0 else WW[4]
        cv.px(x, y, lit)
        cv.px(x, y + 1, WW[2])
        cv.px(x, y + 2, WARM)
        if dy:   # fill the gap left above the sagging section with transparency (nothing)
            pass


def _wood_post(cv, top=16):
    # outline + body
    for y in range(top, BASE + 1):
        cv.px(5, y, _dark(WW[3]))
        cv.px(6, y, WW[4])
        cv.px(7, y, WW[4] if y < top + 3 else WW[3])
        cv.px(8, y, WW[3])
        cv.px(9, y, WW[2])
        cv.px(10, y, WARM)
    for x in range(6, 10):
        cv.px(x, top - 1, _dark(WW[3]))
    # cut top face
    cv.px(6, top, WW[5]); cv.px(7, top, WW[5]); cv.px(8, top, WW[4]); cv.px(9, top, WW[3])
    # grain + knot + weathering
    cv.px(8, top + 4, WW[2]); cv.px(8, top + 5, WW[2])
    cv.px(7, top + 9, WW[1]); cv.px(8, top + 9, WW[2])
    cv.px(6, top + 11, WW[3])
    # base
    for x in range(6, 10):
        cv.px(x, BASE + 1, WARM)
    cv.px(5, BASE + 1, mix(WARM, WW[2], 0.3))


def _wood_conn_v(cv, y0, y1):
    for y in range(y0, y1 + 1):
        cv.px(6, y, _dark(WW[3]))
        cv.px(7, y, WW[4])
        cv.px(8, y, WW[2])
        cv.px(9, y, WARM)


def wood_frame(mask):
    cv = Canvas(FW, FH)
    cv.shadow(9.0, BASE + 1.6, 3.6, 1.3)
    if mask & W:
        _shadow_strip(cv, 0, 5)
    if mask & E:
        _shadow_strip(cv, 10, 15)
    if mask & N:
        _wood_conn_v(cv, 12, 15)
    for i, top in enumerate(RAIL_ROWS):
        if mask & W:
            _wood_rail(cv, range(0, 6), top, sag=(i == 0))
        if mask & E:
            _wood_rail(cv, range(10, 16), top, sag=(i == 0))
    _wood_post(cv)
    # nails where rails meet the post
    for top in RAIL_ROWS:
        if mask & W:
            cv.px(6, top, MET[5])
        if mask & E:
            cv.px(9, top, MET[4])
    if mask & S:
        _wood_conn_v(cv, 29, 31)
    return cv


# ================================================================================================
# chain-link fence (scrap pipe posts + diamond mesh)
# ================================================================================================
MESH_TOP, MESH_BOT = 13, 27


def _mesh(cv, xs, mask):
    for x in xs:
        for y in range(MESH_TOP + 1, MESH_BOT + 1):
            if (x + y) % 4 == 0 or (x - y) % 4 == 0:
                c = MET[3] if y < 20 else MET[2]
                if (x * 3 + y) % 11 == 0:
                    c = RUST[3]
                cv.px(x, y, c)
        # top pipe and bottom tension wire
        cv.px(x, MESH_TOP - 1, MET[4])
        cv.px(x, MESH_TOP, MET[1])
        cv.px(x, MESH_BOT + 1, MET[1])


def _pipe_post(cv, top=10):
    for y in range(top, BASE + 1):
        cv.px(6, y, _dark(MET[3]))
        cv.px(7, y, MET[4])
        cv.px(8, y, MET[3])
        cv.px(9, y, MET[1])
        cv.px(10, y, lib.WARM)
    # cap (scrap: a dented tin can lid)
    for x in range(6, 11):
        cv.px(x, top - 1, _dark(MET[3]) if x < 10 else WARM)
    cv.px(7, top, MET[5]); cv.px(8, top, MET[4])
    # rust streaks
    for (x, y) in [(8, top + 5), (8, top + 6), (9, top + 6), (7, top + 13), (8, BASE - 1),
                   (8, BASE)]:
        cv.px(x, y, RUST[3] if x < 9 else RUST[1])
    # clamps where the mesh/pipe attach
    cv.px(7, MESH_TOP - 1, MET[5])
    for x in range(6, 10):
        cv.px(x, BASE + 1, WARM)


def chainlink_frame(mask):
    cv = Canvas(FW, FH)
    cv.shadow(9.0, BASE + 1.6, 3.4, 1.2)
    if mask & W:
        _mesh(cv, range(0, 6), mask)
    if mask & E:
        _mesh(cv, range(10, 16), mask)
    if mask & N:   # mesh seen edge-on: a dotted wire just east of the posts
        for y in range(12, 16):
            cv.px(9, y, MET[2] if y % 2 else MET[3])
            cv.px(8, y, MET[3])
    _pipe_post(cv)
    if mask & S:
        for y in range(29, 32):
            cv.px(9, y, MET[2] if y % 2 else MET[3])
            cv.px(8, y, MET[3])
    return cv


# ================================================================================================
# palisade (settlement perimeter wall)
# ================================================================================================
# Four 4px logs per frame at x = 0, 4, 8, 12. The centre pair (x=4..11) is the "post" present in
# every variant, so N-S runs read as a sturdy double-log column; W adds x=0..3, E adds x=12..15.
LOG_TOPS = {0: 4, 4: 2, 8: 1, 12: 3}
PB = BARK
CUT = WOOD


def _log(cv, x0, top):
    """4px sharpened log occupying columns x0..x0+3 (last column = gap/outline)."""
    cols = [PB[3], PB[2], PB[1], WARM]
    for y in range(top + 3, BASE + 1):
        for i, c in enumerate(cols):
            cc = c
            if i < 3 and (y * 5 + x0 * 3 + i * 7) % 13 == 0:
                cc = PB[1] if i < 2 else PB[0]           # bark texture
            if i == 0 and (y + x0) % 6 == 0:
                cc = PB[4]                                # lit bark ridge
            cv.px(x0 + i, y, cc)
    # sharpened point (cut wood faces)
    cv.px(x0 + 1, top, CUT[5])
    cv.px(x0 + 1, top + 1, CUT[5]); cv.px(x0 + 2, top + 1, CUT[3])
    cv.px(x0, top + 2, CUT[4]); cv.px(x0 + 1, top + 2, CUT[4]); cv.px(x0 + 2, top + 2, CUT[2])
    # outline around the point
    cv.px(x0 + 1, top - 1, _dark(CUT[3]))
    cv.px(x0, top, _dark(CUT[3])); cv.px(x0, top + 1, _dark(CUT[3]))
    cv.px(x0 + 2, top, WARM); cv.px(x0 + 3, top + 1, WARM); cv.px(x0 + 3, top + 2, WARM)


def _beam(cv, x0, x1, y):
    """Horizontal plank nailed across the logs (2px + outlines)."""
    for x in range(x0, x1 + 1):
        cv.px(x, y - 1, _dark(WOOD[3]))
        cv.px(x, y, WOOD[4] if (x * 7) % 9 else WOOD[5])
        cv.px(x, y + 1, WOOD[2])
        cv.px(x, y + 2, WARM)


def _sheet(cv, x0, y0, w, h, kind):
    """Nailed corrugated scrap sheet (vertical ribs)."""
    if kind == "rust":
        hi, mid, lo = RUST[4], RUST[3], RUST[1]
    else:
        hi, mid, lo = MET[4], MET[3], MET[1]
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            c = hi if (x - x0) % 2 == 0 else mid
            if y == y0 + h - 1:
                c = lo
            if kind == "metal" and (x * 3 + y) % 7 == 0:
                c = RUST[3]
            cv.px(x, y, c)
    for x in range(x0, x0 + w):
        cv.px(x, y0 - 1, _dark(mid))
        cv.px(x, y0 + h, WARM)
    for y in range(y0, y0 + h):
        cv.px(x0 - 1, y, _dark(mid))
        cv.px(x0 + w, y, WARM)
    cv.px(x0 + 1, y0 + 1, MET[5]); cv.px(x0 + w - 2, y0 + 1, MET[5])
    cv.px(x0 + 1, y0 + h - 2, MET[4]); cv.px(x0 + w - 2, y0 + h - 2, MET[4])


def _skirt(cv, x0, x1):
    """Corrugated scrap-metal skirt nailed over the lower logs (continuous across frames)."""
    top = 20
    for x in range(x0, x1 + 1):
        cv.px(x, top - 1, _dark(MET[2]))
        for y in range(top, BASE + 1):
            rib = x % 3 == 0
            c = MET[3] if rib else MET[2]
            if y == top:
                c = MET[4]
            # rust blooms (periodic in x so frames join)
            if (x % 16 in (5, 6, 7, 8) and y > top + 2) or (x % 16 in (12, 13) and y > top + 4) \
                    or (x % 16 in (1, 2) and y > top + 5):
                c = RUST[3] if rib else RUST[2]
            if y >= BASE - 1:
                c = mix(c, PB[0], 0.5)
            cv.px(x, y, c)
        if x % 4 == 1:
            cv.px(x, top + 1, MET[5])
    for x in range(x0, x1 + 1):
        cv.px(x, BASE + 1, WARM)


def palisade_frame(mask):
    cv = Canvas(FW, FH)
    cv.shadow(9.5, BASE + 1.6, 5.0, 1.3)
    xs = [4, 8]
    if mask & W:
        xs = [0] + xs
        _shadow_strip(cv, 0, 4)
    if mask & E:
        xs = xs + [12]
        _shadow_strip(cv, 11, 15)
    for x0 in xs:
        _log(cv, x0, LOG_TOPS[x0])
    x_lo = 0 if mask & W else 4
    x_hi = 15 if mask & E else 11
    _beam(cv, x_lo, x_hi, 9)
    for x0 in xs:
        cv.px(x0 + 1, 9, MET[5])
    _skirt(cv, x_lo, x_hi)
    if not mask & W:
        for y in range(19, BASE + 2):
            cv.px(3, y, _dark(MET[2]))
    if not mask & E:
        for y in range(19, BASE + 2):
            cv.px(12, y, WARM)
    return cv


# ================================================================================================
# gates
# ================================================================================================
def gate_wood():
    """Open-frame plank gate: two stiles, the fence's two rails, a diagonal brace."""
    frames = []
    G = WW
    for state in ("closed", "open"):
        cv = Canvas(FW, FH)
        if state == "closed":
            _shadow_strip(cv, 0, 15)
            for top in RAIL_ROWS:
                _wood_rail(cv, range(0, 16), top)
            # diagonal brace (behind the stiles)
            for i in range(9):
                x = 3 + i
                y = 24 - (i * 5) // 8
                cv.px(x, y - 1, _dark(G[3]))
                cv.px(x, y, G[4])
                cv.px(x, y + 1, G[2])
            # stiles
            for x0 in (1, 12):
                for y in range(17, BASE + 1):
                    cv.px(x0 - 1, y, _dark(G[3]))
                    cv.px(x0, y, G[4])
                    cv.px(x0 + 1, y, G[3])
                    cv.px(x0 + 2, y, WARM)
                cv.px(x0, 16, _dark(G[3])); cv.px(x0 + 1, 16, _dark(G[3]))
                cv.px(x0, 17, G[5])
                cv.px(x0, BASE + 1, WARM); cv.px(x0 + 1, BASE + 1, WARM)
            # strap hinges + latch
            for y in RAIL_ROWS:
                cv.px(1, y, MET[1]); cv.px(2, y, MET[2]); cv.px(3, y, MET[1])
            cv.px(14, 20, MET[4]); cv.px(15, 20, MET[2]); cv.px(14, 21, MET[1])
        else:
            # door swung open, seen edge-on against its hinge side
            _shadow_strip(cv, 0, 4)
            for y in range(16, BASE + 1):
                cv.px(0, y, G[4])
                cv.px(1, y, G[3])
                cv.px(2, y, G[2])
                cv.px(3, y, WARM)
            for x in range(0, 3):
                cv.px(x, 15, _dark(G[3]))
                cv.px(x, BASE + 1, WARM)
            cv.px(0, 16, G[5]); cv.px(1, 16, G[5])
            for y in RAIL_ROWS:
                cv.px(0, y, MET[2]); cv.px(1, y, MET[1])
        frames.append(cv)
    return lib.hstrip(frames)


def gate_chainlink():
    frames = []
    for state in ("closed", "open"):
        cv = Canvas(FW, FH)
        if state == "closed":
            _mesh(cv, range(0, 16), 0)
            # pipe frame around the panel
            for y in range(MESH_TOP - 1, BASE + 1):
                for x0 in (1, 14):
                    cv.px(x0, y, MET[4] if x0 == 1 else MET[3])
                    cv.px(x0 + 1, y, MET[1])
            for x in range(1, 16):
                cv.px(x, BASE, MET[2])
            # diagonal brace pipe
            for i in range(12):
                cv.px(2 + i, BASE - 1 - i, MET[3])
            # latch chain + padlock
            cv.px(13, 19, MET[5]); cv.px(13, 20, RUST[3]); cv.px(12, 21, lib.rgba(P.LAMPLIGHT))
            cv.px(12, 22, RUST[2])
            for x in range(1, 16):
                cv.px(x, BASE + 1, rgba(P.OUTLINE_WARM, lib.SHADOW_ALPHA))
        else:
            for y in range(MESH_TOP - 1, BASE + 1):
                cv.px(0, y, MET[4])
                cv.px(1, y, MET[3])
                cv.px(2, y, MET[1])
                cv.px(3, y, WARM)
            cv.px(1, MESH_TOP - 2, MET[5])
            for x in range(0, 4):
                cv.px(x, BASE + 1, WARM)
        frames.append(cv)
    return lib.hstrip(frames)


def sheet(fn):
    return lib.grid_sheet([fn(m) for m in range(16)], 4)


def build(out):
    sheet(wood_frame).save("fences/fence_wood.png")
    sheet(chainlink_frame).save("fences/fence_chainlink.png")
    sheet(palisade_frame).save("fences/fence_palisade.png")
    gate_wood().save("fences/gate_wood.png")
    gate_chainlink().save("fences/gate_chainlink.png")
