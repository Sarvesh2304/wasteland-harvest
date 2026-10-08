"""Rad-hound: a mangy mutant dog. Low and long; patchy ash-brown fur (HOUND_FUR_RAMP) with raw
bald patches, exposed ribs, glowing rad sores and a glowing eye, a long fanged snout and a ratty
tail. Trot = diagonal leg pairs. Attack: frame 0 crouches, frame 1 (the telegraph) is coiled
low with hackles up, ears pinned and fangs bared, frame 2 is the lunging bite (body stretched,
jaw wide), frame 3 recovers. Death: a yelp, legs buckle, it rolls onto its side, the carcass.
Drawn from scratch: ASCII parts per facing + 1 px procedural legs.
"""
from __future__ import annotations

import palette as P
from enemies import humanoid as H
from enemies import pix, rig
from enemies.pix import mix, ramp, rgba

F = ramp(P.HOUND_FUR_RAMP)
K = ramp(P.HOUND_SKIN_RAMP)
GLOW = rgba(P.RAD_GLOW)
DEEP = rgba(P.RAD_GLOW_DEEP)
HOT = rgba(P.RAD_HOT)

CMAP = {
    "a": F[0], "b": F[1], "c": F[2], "d": F[3], "f": F[4],
    "j": K[0], "k": K[1], "K": K[2],
    "g": GLOW, "G": DEEP, "e": GLOW, "x": F[1],
    "n": mix(F[0], P.OUTLINE_COLD, 0.5), "m": rgba(P.GORE_DARK), "w": rgba(P.SIGNAGE_CREAM),
    "t": K[2], "r": rgba(P.GORE_STAIN),
}

# --- side view (facing east) --------------------------------------------------------------------
BODY_E = [".cd.cdc.ddc.",
          "cddcdccdddcc",
          "ccgcbcbcbccb",
          "bcGkbkbkbccb",
          ".bbbbbbbbbba",
          "..aa....aaa."]
HACKLES_E = [".d.d.d.d..", "dcdcdcdcd."]        # bristling back fur (telegraph)
HEAD_E = {
    "n": ["c......",
          "dc.....",
          "cdcc...",
          "bcecccn",
          "bccccbn",
          ".bwbbb."],
    "s": [".......",
          "dcc....",
          "cdccc..",
          "bcecccn",
          "bcwwwwn",
          ".bmbb.."],
    "o": ["c......",
          "dc...n.",
          "cdcccc.",
          "bcecww.",
          "bcmm...",
          ".bbww.."],
    "x": [".......",
          "dcc....",
          "cdccc..",
          "bcbcccn",
          "bccccbn",
          ".bbtt.."],
}
# --- front view (facing south) ------------------------------------------------------------------
BODY_S = [".cdddc...",
          "cddccdcb.",
          "cdgcccbbb",
          "bckbcbkbb",
          "bcbcccbca",
          ".bccccbb.",
          ".bbccbba.",
          "..abbaa.."]
HEAD_S = {
    "n": ["c.....d",
          "dc...cb",
          "cdcccdb",
          "cedcdeb",
          ".cdfdb.",
          ".cffcb.",
          "..bnb.."],
    "s": [".......",
          "cd...db",
          "cdcccdb",
          "cedcdeb",
          ".cfnfb.",
          ".wmmmw.",
          "..w.w.."],
    "o": ["c.....d",
          "dc...cb",
          "cdcccdb",
          "cedcdeb",
          ".cfnfb.",
          ".wmmmw.",
          ".bmmmb.",
          "..wtw.."],
}
# --- back view (facing north) -------------------------------------------------------------------
BODY_N = [".cdddc...",
          "cddccdcb.",
          "cdcGccbbb",
          "bckbcbkbb",
          "bcbcccbca",
          "bccccccba",
          ".bcb.bca.",
          ".ab...ba."]
HEAD_N = {"n": ["c.....d",
                "dc...cc",
                "cdcccdb",
                "cddccbb",
                ".cccbb."]}
HEAD_N["s"] = HEAD_N["o"] = HEAD_N["n"]


class HPose:
    def __init__(self, **kw):
        self.bx = 0
        self.by = 0
        self.hx = 0
        self.hy = 0
        self.head = "n"
        self.hackles = False
        self.heat = 0
        # E legs: paw x offsets / lifts for (far front, near front, far hind, near hind)
        self.paws = (0, 0, 0, 0)
        self.lifts = (0, 0, 0, 0)
        self.tail = 0             # 0 low, 1 raised, -1 tucked
        self.__dict__.update(kw)


def _leg(cv, pts, col, paw, toe=1):
    path = pix.poly_points(pts)
    for (x, y) in path:
        cv.px(x, y, col)
    x, y = path[-1]
    cv.px(x + toe, y, paw)
    return cv


def _sores(cv, heat):
    """Heat 2: every sore pixel goes white-hot."""
    if heat < 2:
        return cv
    out = cv.recolor({GLOW: HOT, DEEP: GLOW})
    return out


def frame_e(p):
    bx, by = p.bx, p.by
    far = rig.layer()
    near = rig.layer()
    # front legs: shoulder ~ (15, 14); hind legs: hip ~ (7, 13) with a backward hock
    fy = rig.GROUND
    sh_x, sh_y = 15 + bx, 14 + by
    hp_x, hp_y = 7 + bx, 14 + by
    for i, (cv, dx, col, paw) in enumerate(((far, -1, F[1], F[0]), (near, 0, F[2], F[1]))):
        # front leg
        px_ = sh_x + dx + p.paws[i]
        ly = fy - p.lifts[i]
        knee = (sh_x + dx + p.paws[i] // 2 + (1 if p.lifts[i] else 0), sh_y + 2 + (0 if not p.lifts[i] else -1))
        _leg(cv, [(sh_x + dx, sh_y), knee, (px_, ly)], col, paw)
        # hind leg
        hx_ = hp_x + dx + p.paws[2 + i]
        hl = fy - p.lifts[2 + i]
        stifle = (hp_x + dx + 1 + p.paws[2 + i] // 2, hp_y + 2)
        hock = (hx_ - 1, hl - 2)
        _leg(cv, [(hp_x + dx, hp_y), stifle, hock, (hx_, hl)], col, paw)
    body = rig.stamp(BODY_E, CMAP, 5 + bx, 10 + by)
    if p.hackles:
        body.blit(pix.part(HACKLES_E, CMAP), 6 + bx, 8 + by)
    head = rig.stamp(HEAD_E[p.head], CMAP, 15 + bx + p.hx, 6 + by + p.hy)
    tail = rig.layer()
    tx, ty = 5 + bx, 11 + by
    if p.tail == 1:
        pts = [(tx, ty), (3 + bx, ty - 2), (2 + bx, ty - 4)]
    elif p.tail == -1:
        pts = [(tx, ty), (4 + bx, ty + 2), (4 + bx, ty + 4)]
    else:
        pts = [(tx, ty), (3 + bx, ty), (1 + bx, ty + 1)]
    for k, (x, y) in enumerate(pix.poly_points(pts)):
        tail.px(x, y, F[2] if k % 2 == 0 else F[1])
    out = rig.compose([far, tail, body, near, head])
    return _sores(out, p.heat)


def frame_sn(p, facing):
    bx, by = p.bx, p.by
    legs_back = rig.layer()
    legs_front = rig.layer()
    lf = p.lifts
    if facing == "S":
        # hind legs (far, peeking at the sides), front legs (near)
        for i, x in enumerate((8, 15)):
            _leg(legs_back, [(x + bx, 14 + by), (x + bx, 17 - lf[2 + i])], F[1], F[0], toe=0)
        for i, x in enumerate((10, 13)):
            _leg(legs_front, [(x + bx, 15 + by), (x + bx, rig.GROUND - lf[i])], F[2], F[1],
                 toe=1 if i == 1 else -1)
        body = rig.stamp(BODY_S, CMAP, 7 + bx, 7 + by)
        head = rig.stamp(HEAD_S[p.head], CMAP, 8 + bx + p.hx, 4 + by + p.hy)
        out = rig.compose([legs_back, body, legs_front, head])
    else:
        for i, x in enumerate((9, 14)):
            _leg(legs_back, [(x + bx, 13 + by), (x + bx, 16 - lf[i])], F[1], F[0], toe=0)
        for i, x in enumerate((8, 15)):
            _leg(legs_front, [(x + bx, 15 + by), (x + bx, rig.GROUND - lf[2 + i])], F[2], F[1],
                 toe=1 if i == 1 else -1)
        tail = rig.layer()
        tpts = [(12 + bx, 13 + by), (12 + bx, 15 + by), (13 + bx, 17 + by)] if p.tail <= 0 else \
               [(12 + bx, 13 + by), (12 + bx, 10 + by), (13 + bx, 8 + by)]
        for k, (x, y) in enumerate(pix.poly_points(tpts)):
            tail.px(x, y, F[3] if k % 2 == 0 else F[2])
        head = rig.stamp(HEAD_N[p.head], CMAP, 8 + bx + p.hx, 4 + by + p.hy)
        body = rig.stamp(BODY_N, CMAP, 7 + bx, 8 + by)
        layers = [legs_back, head, body, legs_front, tail] if p.tail > 0 else \
                 [legs_back, head, body, tail, legs_front]
        out = rig.compose(layers)
    return _sores(out, p.heat)


def frame(facing, p):
    if facing == "W":
        return frame_e(p).flip_h()
    if facing == "E":
        return frame_e(p)
    return frame_sn(p, facing)


def poses():
    Q = HPose
    out = {}
    for i in range(2):
        out[("idle", "E", i)] = Q(hy=i, tail=0 if i == 0 else 1, by=0)
        out[("idle", "S", i)] = Q(hy=i)
        out[("idle", "N", i)] = Q(hy=-i, tail=0)
    # trot: diagonal pairs (far front + near hind) / (near front + far hind)
    trot = [((2, -2, -2, 2), (0, 0, 0, 0), 0), ((0, 0, 0, 0), (1, 0, 0, 1), -1),
            ((-2, 2, 2, -2), (0, 0, 0, 0), 0), ((0, 0, 0, 0), (0, 1, 1, 0), -1)]
    for i, (paws, lifts, by) in enumerate(trot):
        out[("walk", "E", i)] = Q(paws=paws, lifts=lifts, by=by, hy=-by, tail=1)
    sn = [((1, 0, 0, 1), 0), ((0, 0, 0, 0), -1), ((0, 1, 1, 0), 0), ((0, 0, 0, 0), -1)]
    for i, (lifts, by) in enumerate(sn):
        out[("walk", "S", i)] = Q(lifts=lifts, by=by, hy=0)
        out[("walk", "N", i)] = Q(lifts=lifts, by=by, tail=1)
    # attack
    out[("attack", "E", 0)] = Q(by=1, hy=1, head="s", paws=(1, 1, 1, 1), tail=-1)
    out[("attack", "E", 1)] = Q(by=2, hy=2, hx=1, head="s", hackles=True, heat=2,
                                paws=(2, 2, 2, 2), tail=-1)
    out[("attack", "E", 2)] = Q(bx=3, by=-1, hx=1, hy=-1, head="o", paws=(3, 3, -3, -3),
                                lifts=(2, 2, 0, 0), tail=0)
    out[("attack", "E", 3)] = Q(bx=1, head="n", paws=(1, 0, 0, 1))
    out[("attack", "S", 0)] = Q(by=1, hy=1, head="s")
    out[("attack", "S", 1)] = Q(by=2, hy=2, head="s", heat=2)
    out[("attack", "S", 2)] = Q(by=1, hy=3, head="o", lifts=(1, 1, 0, 0))
    out[("attack", "S", 3)] = Q(by=0, hy=1, head="n")
    out[("attack", "N", 0)] = Q(by=1, hy=1, tail=-1)
    out[("attack", "N", 1)] = Q(by=2, hy=2, heat=2, tail=1)
    out[("attack", "N", 2)] = Q(by=-1, hy=-2, lifts=(0, 0, 1, 1), tail=0)
    out[("attack", "N", 3)] = Q(by=0, tail=0)
    out[("hurt", "E")] = Q(bx=-2, by=-1, hy=-2, hx=-1, head="o", tail=-1)
    out[("hurt", "S")] = Q(by=-1, hy=-2, head="o")
    out[("hurt", "N")] = Q(by=-1, hy=-1, tail=-1)
    return out


def _carcass(lift=0, pool=False, stiff=True, dx=-2):
    """Lying on its side: the side-view body dropped to the ground, legs sticking out."""
    by = 4 - lift
    legs = rig.layer()
    for (x0, y0, ex, ey) in ((15, 14, 4, 4), (13, 14, 2, 5), (7, 13, 3, 5), (5, 13, -1, 5)):
        y0 += by
        if not stiff:
            ex, ey = ex // 2, ey - 2
        pts = [(x0 + dx, y0), (x0 + dx + ex, min(rig.GROUND, y0 + ey))]
        for k, (x, y) in enumerate(pix.poly_points(pts)):
            legs.px(x, y, F[3] if k < 3 else F[2])
    body = rig.stamp(BODY_E, CMAP, 5 + dx, 10 + by)
    head = rig.stamp(HEAD_E["x"], CMAP, 15 + dx, 7 + by)
    tail = rig.layer()
    for (x, y) in pix.poly_points([(5 + dx, 12 + by), (3 + dx, 13 + by), (2 + dx, 14 + by)]):
        tail.px(x, y, F[2])
    out = rig.compose([legs, tail, body, head])
    out = out.recolor({GLOW: mix(GLOW, F[1], 0.5)})          # the sores dim once it is dead
    if pool:
        under = rig.layer()
        H.blood_pool(under, 17.0 + dx, 18.4, 3.6, 1.5)
        under.blit(out, 0, 0)
        out = under
    out.a[rig.FEET_ROW + 1:, :, :] = 0
    return out


def death_frames():
    f0 = frame_e(HPose(bx=-1, by=-1, hy=-2, hx=-1, head="o", paws=(1, 2, -1, -2), tail=-1))
    f1 = frame_e(HPose(by=3, hy=3, head="x", paws=(2, 3, -2, -1), tail=0))
    f2 = _carcass(lift=1, stiff=False)
    f3 = _carcass(pool=True)
    return [f0, f1, f2, f3]


def frames():
    out = {k: frame(k[1], p) for k, p in poses().items()}
    for i, f in enumerate(death_frames()):
        out[("death", i)] = f
    return out


def sheet():
    return rig.assemble(frames())
