"""Festival dressing (art/env/props/): bunting, the food table, the lantern posts and the seed
packets of the seed hunt.

  bunting.png           64 x 16  a rope of little pennants; both ends at the same height (row 2)
                                 so copies placed 64 px apart join into one long line
  festival_table.png    32 x 24  trestle table, cloth, a feast on it (footprint 2 x 1)
  festival_lantern.png  32 x 32  2 frames of 16 x 32: unlit / lit paper lantern on a post
                                 (props.gd night_frame 1; its light sits 22 px above the base,
                                 which is the lantern's middle)
  seed_packet.png       16 x 16  a paper seed packet lying in the grass
Settlement side: warm selective outline, warm contact shadows, light from the top-left.
"""
from __future__ import annotations

import math

import palette as P
from env import colors as X
from env import lib
from env.lib import Canvas, mix, rgba

WARM = lib.WARM
WOOD = lib.ramp(P.WOOD_RAMP)
MET = lib.ramp(P.METAL_RAMP)
STONE = lib.ramp(P.STONE_RAMP)
ROPE = lib.ramp(X.ROPE)
TEAL = lib.ramp(P.FEST_TEAL_RAMP)
FRED = lib.ramp(P.FEST_RED_RAMP)
GOLD = lib.ramp(P.FEST_GOLD_RAMP)
FBLUE = lib.ramp(P.FEST_BLUE_RAMP)
PAPER = lib.ramp(P.LANTERN_PAPER_RAMP)
GLOW = lib.ramp(P.WINDOW_GLOW_RAMP)
CANV = lib.ramp(X.CANVAS_RAMP)
CREAM = rgba(P.CREAM)
CREAM_RAMP = [rgba(c) for c in ("#a89878", "#cdbf9c", "#e8dcbc", P.CREAM)]   # table cloth (CANVAS -> CREAM)
G_GREEN = lib.ramp(X.GLASS_GREEN)
G_BROWN = lib.ramp(X.GLASS_BROWN)
CRUST = [rgba(c) for c in ("#7a4a1c", "#a8692a", "#d08c3c", "#eab25e")]  # pie / bread crust
BERRY = [rgba(c) for c in P.BLOOD[:2]] + [rgba("#e06a4c")]                  # bowl of bloodberries
GREENS = lib.ramp(P.LEAF_RAMP)


def _outline(cv, local=0.6):
    lib.outline(cv, WARM, local=local)
    return cv


# ================================================================================================
# bunting (64 x 16)
# ================================================================================================
BUNT_W, BUNT_H = 64, 16
BUNT_END_Y = 2
BUNT_SAG = 5.0
FLAG = [                # 5 wide, 6 tall, pointing down; digits index a 4-step ramp
    "33332",
    "33321",
    ".332.",
    ".321.",
    "..2..",
    "..1..",
]


def bunting():
    cv = Canvas(BUNT_W, BUNT_H)
    rope_y = []
    for x in range(BUNT_W):
        t = (x + 0.5) / BUNT_W
        rope_y.append(int(round(BUNT_END_Y + BUNT_SAG * 4 * t * (1 - t))))
    flags = Canvas(BUNT_W, BUNT_H)
    cols = [FRED, GOLD, TEAL, FBLUE, CREAM_RAMP]
    for k, fx in enumerate(range(3, BUNT_W - 4, 8)):
        R = cols[k % len(cols)]
        top = rope_y[fx + 2] + 1
        for j, row in enumerate(FLAG):
            for i, ch in enumerate(row):
                if ch != ".":
                    flags.px(fx + i, top + j, R[int(ch)])
    _outline(flags, 0.55)
    cv.blit(flags, 0, 0)
    for x in range(BUNT_W):                       # the rope over the flags' top edges
        cv.px(x, rope_y[x], ROPE[1] if x % 3 else ROPE[0])
    # little knots where the flags are sewn on
    for fx in range(3, BUNT_W - 4, 8):
        cv.px(fx, rope_y[fx], ROPE[2])
        cv.px(fx + 4, rope_y[fx + 4], ROPE[0])
    return cv


# ================================================================================================
# festival table (32 x 24, footprint 2 x 1)
# ================================================================================================
TB_W, TB_H = 32, 24
TOP_Y0, TOP_Y1 = 8, 14        # table top (cloth) seen from above
HEM_Y = 18                    # cloth hangs over the front edge down to here


def _pie(s, x0, y0):
    """A round pie, 8 x 5, lattice crust."""
    for y in range(5):
        for x in range(8):
            dx = (x + 0.5 - 4) / 4.0
            dy = (y + 0.5 - 2.5) / 2.5
            if dx * dx + dy * dy > 1.05:
                continue
            c = CRUST[3] if dy < -0.3 else CRUST[2] if dy < 0.4 else CRUST[1]
            if dx > 0.6:
                c = CRUST[1]
            if (x + y) % 3 == 0 and 0 < y < 4 and 0 < x < 7:
                c = FRED[2]                       # berry filling through the lattice
            s.px(x0 + x, y0 + y, c)
    for x in range(1, 7):
        s.px(x0 + x, y0 + 5, MET[2] if x < 6 else MET[1])     # tin plate rim


def _loaf(s, x0, y0):
    rows = [".3333.", "332332", "222221", ".1111."]
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != ".":
                s.px(x0 + i, y0 + j, CRUST[int(ch)])
    s.px(x0 + 1, y0, CRUST[3]); s.px(x0 + 2, y0 + 1, mix(CRUST[3], CREAM, 0.4))


def _bowl(s, x0, y0, R):
    for x in range(1, 5):
        s.px(x0 + x, y0, R[2] if x % 2 else R[1])
    for x in range(6):
        s.px(x0 + x, y0 + 1, R[2] if x not in (0, 5) else R[1])
    s.px(x0 + 2, y0, R[2]); s.px(x0 + 2, y0 - 1, mix(R[2], CREAM, 0.3))
    for x in range(6):                                          # wooden bowl
        s.px(x0 + x, y0 + 2, WOOD[4] if x < 4 else WOOD[2])
    for x in range(1, 5):
        s.px(x0 + x, y0 + 3, WOOD[2] if x < 4 else WOOD[1])


def _jug(s, x0, y0):
    """A clay jug of cider, 5 x 6 (rust ramp = fired clay)."""
    clay = lib.ramp(P.RUST_RAMP)
    rows = [".22.", ".32.", "4431", "4331", "3221", ".11."]
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != ".":
                s.px(x0 + i, y0 + j, clay[int(ch) + 1])
    s.px(x0 + 4, y0 + 2, clay[2]); s.px(x0 + 4, y0 + 3, clay[1])   # handle
    s.px(x0 + 1, y0, CREAM_RAMP[2])                                 # a cloth stopper


def festival_table():
    cv = Canvas(TB_W, TB_H)
    legs = Canvas(TB_W, TB_H)
    # trestle legs: an A-frame at each end under the cloth, with a stretcher between them
    for lx in (4, 26):
        for (x, y) in lib.line_points(lx - 2, 22, lx + 1, 17) + lib.line_points(lx + 3, 22, lx, 17):
            legs.px(x, y, WOOD[3])
    for x in range(5, 28):
        legs.px(x, 20, WOOD[2])
    _outline(legs)
    s = Canvas(TB_W, TB_H)
    # cloth over the top: cream with a red runner down the middle
    for y in range(TOP_Y0, TOP_Y1 + 1):
        for x in range(1, 31):
            c = CREAM_RAMP[3] if y < TOP_Y0 + 2 else CREAM_RAMP[2]
            if x >= 29:
                c = CREAM_RAMP[1]
            if 11 <= x <= 20:
                c = FRED[3] if y < TOP_Y0 + 2 else FRED[2]
                if x in (11, 20):
                    c = GOLD[2]
            s.px(x, y, c)
    # cloth hanging down the front: folds and a scalloped hem
    for y in range(TOP_Y1 + 1, HEM_Y + 1):
        for x in range(1, 31):
            fold = (x - 1) % 5
            c = CREAM_RAMP[2] if fold < 2 else CREAM_RAMP[1] if fold < 4 else CREAM_RAMP[0]
            if 11 <= x <= 20:
                c = FRED[2] if fold < 2 else FRED[1]
                if x in (11, 20):
                    c = GOLD[1]
            if y == TOP_Y1 + 1:
                c = mix(c, WARM, 0.15)            # the table edge under the cloth
            if y == HEM_Y and fold in (0, 4):
                continue
            s.px(x, y, c)
    _outline(s)
    food = Canvas(TB_W, TB_H)
    _pie(food, 2, 6)
    _loaf(food, 11, 7)
    _jug(food, 18, 4)
    _bowl(food, 23, 8, BERRY)
    _outline(food)
    cv.shadow(16.0, TB_H - 0.7, 14, 1.0)
    cv.blit(legs, 0, 0)
    cv.blit(s, 0, 0)
    cv.blit(food, 0, 0)
    return cv


# ================================================================================================
# festival lantern (2 frames of 16 x 32)
# ================================================================================================
LT_W, LT_H = 16, 32
LANTERN_X0, LANTERN_Y0 = 6, 7          # lantern body top-left (7 x 8); its middle is row 10-11
LANTERN = [                            # p..P = paper ramp positions, c = wooden caps, r = rib
    "..ccc..",
    ".43332.",
    "4333221",
    "rrrrrrr",
    "4332221",
    "4332221",
    ".33221.",
    "..ccc..",
]


def _lantern_body(cv, lit):
    for j, row in enumerate(LANTERN):
        for i, ch in enumerate(row):
            x, y = LANTERN_X0 + i, LANTERN_Y0 + j
            if ch == ".":
                continue
            if ch == "c":
                c = WOOD[1] if i != 2 else WOOD[2]
            elif ch == "r":
                c = FRED[1] if not lit else FRED[2]           # the red paper band
            else:
                k = int(ch)                                    # 1 (shade) .. 4 (lit edge)
                if lit:
                    d = math.hypot(i - 2.7, (j - 3.8) * 0.9)
                    c = GLOW[4] if d < 1.2 else GLOW[3] if d < 2.4 else GLOW[2] if k > 1 else GLOW[1]
                else:
                    c = PAPER[min(3, k - 1)] if k > 1 else PAPER[0]
                    if k == 4:
                        c = PAPER[3]
            cv.px(x, y, c)
    # tassel
    tx = LANTERN_X0 + 3
    cv.px(tx, LANTERN_Y0 + 8, FRED[2])
    cv.px(tx, LANTERN_Y0 + 9, FRED[1])
    cv.px(tx - 1, LANTERN_Y0 + 10, FRED[1]); cv.px(tx, LANTERN_Y0 + 10, FRED[2]); cv.px(tx + 1, LANTERN_Y0 + 10, FRED[0])


def lantern_frame(lit):
    cv = Canvas(LT_W, LT_H)
    post = Canvas(LT_W, LT_H)
    px0 = 3                                                    # post columns 3..4
    for y in range(4, 30):
        post.px(px0, y, WOOD[4])
        post.px(px0 + 1, y, WOOD[2])
    post.px(px0, 3, WOOD[5]); post.px(px0 + 1, 3, WOOD[3])
    for x in range(px0, 12):                                   # arm out to the right
        post.px(x, 5, WOOD[4] if x < 11 else WOOD[2])
        post.px(x, 6, WOOD[2] if x < 11 else WOOD[1])
    for k in range(3):                                         # brace
        post.px(px0 + 2 + k, 9 - k, WOOD[3])
    # stone foot
    for y in (28, 29, 30):
        for x in range(px0 - 2, px0 + 4):
            c = STONE[4] if y == 28 else STONE[3] if x < px0 + 2 else STONE[2]
            if y == 30:
                c = STONE[2] if x < px0 + 3 else STONE[1]
            post.px(x, y, c)
    # hook from the arm
    post.px(LANTERN_X0 + 3, LANTERN_Y0 - 1, MET[2])
    # little gold streamers tied at the arm
    post.px(px0 + 2, 7, GOLD[2]); post.px(px0 + 2, 8, GOLD[1])
    post.px(px0 + 1, 7, FRED[2])
    _outline(post)
    lamp = Canvas(LT_W, LT_H)
    _lantern_body(lamp, lit)
    _outline(lamp, 0.5)
    cv.shadow(4.5, LT_H - 0.7, 4, 1.0)
    if lit:
        # soft glow around the paper (the game adds the real light at night)
        cx, cy = LANTERN_X0 + 3.0, LANTERN_Y0 + 4.0
        for y in range(LT_H):
            for x in range(LT_W):
                d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.1)
                if 4.4 < d <= 7.2:
                    a = int(70 * (1 - (d - 4.4) / 2.8))
                    if a > 10:
                        cv.a[y, x] = (*rgba(P.LAMPLIGHT)[:3], a)
    cv.blit(post, 0, 0)
    cv.blit(lamp, 0, 0)
    return cv


def festival_lantern():
    return lib.hstrip([lantern_frame(False), lantern_frame(True)])


# ================================================================================================
# seed packet (16 x 16)
# ================================================================================================
def seed_packet():
    """A paper seed packet lying in the grass (the hunt's pickups): cream paper, folded and
    crimped top, a red band, a painted green sprout, a contact shadow."""
    cv = Canvas(16, 16)
    s = Canvas(16, 16)
    rows = [
        ".cccccc.",
        "zzzzzzzz",
        "PPPPPPPq",
        "RRRRRRRr",
        "PPGPPGPq",
        "PPPgPgPq",
        "PPPPgPPq",
        "PPPPgPPq",
        "PPPPPPPq",
        "qqqqqqqq",
    ]
    cm = {"c": CREAM_RAMP[2], "z": CREAM_RAMP[1], "P": CREAM_RAMP[3], "q": CREAM_RAMP[1],
          "R": FRED[2], "r": FRED[1], "g": GREENS[3], "G": GREENS[5]}
    x0, y0 = 4, 4
    for j, row in enumerate(rows):
        dx = 0
        for i, ch in enumerate(row):
            if ch != ".":
                s.px(x0 + i + dx, y0 + j, cm[ch])
    for i in range(0, 8, 2):                                  # crimped top edge
        s.px(x0 + i, y0, CREAM_RAMP[3])
    s.px(x0, y0 + 2, CREAM)                                    # light catching the corner
    _outline(s)
    cv.shadow(8.5, 14.6, 5, 1.0)
    cv.blit(s, 0, 0)
    return cv
