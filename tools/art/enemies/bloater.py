"""Bloater: a grotesquely swollen infected (body ~18 px wide, ~21 at full swell), sickly
yellow-green (BLOATER_SKIN_RAMP) with glowing rad pustules, a scrap of torn shirt still stretched
over its chest and a small head sunk into the bulk. A slow waddle. Attack: frames 0-1 swell up
with the pustules going white-hot and a translucent warning glow (frame 1 = the telegraph), frame
2 belches a gas cloud toward the facing, frame 3 deflates. Death: swell, burst, deflated sack,
then the sack lying in an ichor puddle.

Mostly procedural: the belly is a sphere-shaded ellipse lit from the top-left.
"""
from __future__ import annotations

import math

import numpy as np

import palette as P
from enemies import pix, rig
from enemies.pix import Canvas, mix, ramp, rgba

BS = ramp(P.BLOATER_SKIN_RAMP)
SHIRT = ramp(P.INFECTED_SHIRT_RAMP)
ICH = ramp(P.ICHOR_RAMP)
GLOW = rgba(P.RAD_GLOW)
DEEP = rgba(P.RAD_GLOW_DEEP)
HOT = rgba(P.RAD_HOT)
LIGHT = np.array([-0.55, -0.70, 0.62])
LIGHT = LIGHT / np.linalg.norm(LIGHT)

CMAP = {"1": BS[0], "2": BS[1], "3": BS[2], "4": BS[3], "5": BS[4],
        "e": rgba(P.INFECTED_EYE), "m": rgba(P.GORE_DARK), "g": GLOW}

HEAD = {
    ("S", "n"): [".4554.", "455443", "4e33e3", "433332", ".3mm2.", ".2332."],
    ("S", "o"): [".4554.", "4e44e3", "433332", ".mmmm.", ".mmmm.", ".2mm2."],
    ("N", "n"): [".4554.", "455443", "444433", "443332", ".3332.", ".2332."],
    ("E", "n"): [".4554.", "455444", "4443e4", "444334", ".33mm.", ".2332."],
    ("E", "o"): [".4554.", "4443e4", "44333m", ".33mmm", ".23mm.", ".2332."],
}
HEAD[("N", "o")] = HEAD[("N", "n")]

# pustules in belly-normalised coords (u, v in -1..1), per facing; the bigger ones get 2 px
PUST = {
    "S": [(-0.45, 0.25, 2), (0.35, 0.5, 1), (0.55, -0.05, 2), (-0.1, 0.65, 1), (-0.7, -0.1, 1)],
    "N": [(-0.35, -0.2, 2), (0.4, 0.15, 2), (0.0, 0.55, 1), (-0.6, 0.4, 1), (0.65, -0.3, 1)],
    "E": [(0.35, 0.3, 2), (-0.3, 0.05, 1), (0.1, 0.65, 1), (-0.55, 0.45, 2)],
}


class BPose:
    def __init__(self, **kw):
        self.swell = 0.0      # belly growth in px of radius
        self.bx = 0
        self.by = 0
        self.legs = (0, 0)
        self.stride = 0
        self.mouth = "n"
        self.heat = 0         # 0 dull, 1 bright, 2 white-hot + halo
        self.squash = 0.0     # + = wider and shorter (hurt)
        self.cloud = 0.0      # belch cloud strength
        self.arm = 0          # arm swing
        self.__dict__.update(kw)


def _belly(facing, p):
    """(cx, cy, rx, ry) of the swollen belly; it rests on the stubby legs."""
    if facing == "E":
        cx, rx, ry = 12.5, 7.0, 5.2
    else:
        cx, rx, ry = 12.0, 8.8, 5.2
    rx += p.swell + p.squash
    ry += p.swell * 0.55 - p.squash * 0.6
    cy = 19.0 - ry + p.by - 0.6
    return cx + p.bx, cy, rx, ry


def _chest(facing, p):
    """(cx, cy, rx, ry) of the narrower shoulders / chest sitting on top of the belly."""
    if facing == "E":
        cx, cy, rx, ry = 10.5, 9.0, 4.2, 3.6
    else:
        cx, cy, rx, ry = 12.0, 9.0, 5.6, 3.6
    rx += p.swell * 0.3 + p.squash * 0.5
    return cx + p.bx, cy + p.by + p.squash * 0.5, rx, ry


def _ell(cx, cy, rx, ry):
    ys, xs = np.mgrid[0:rig.FH, 0:rig.FW]
    nx = (xs + 0.5 - cx) / rx
    ny = (ys + 0.5 - cy) / ry
    return nx, ny, nx * nx + ny * ny


def _lambert(nx, ny, d):
    nz = np.sqrt(np.clip(1 - d, 0, 1))
    return nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]


def _shade_body(cv, facing, p):
    bx_, by_, brx, bry = _belly(facing, p)
    cx_, cy_, crx, cry = _chest(facing, p)
    bnx, bny, bd = _ell(bx_, by_, brx, bry)
    cnx, cny, cd = _ell(cx_, cy_, crx, cry)
    belly = bd <= 1.0
    chest = (cd <= 1.0) & ~belly
    lam_b = np.digitize(_lambert(bnx, bny, bd), [0.05, 0.38, 0.66, 0.86])
    lam_c = np.digitize(_lambert(cnx, cny, cd), [0.05, 0.38, 0.66, 0.86])
    for y, x in zip(*np.nonzero(belly)):
        k = int(lam_b[y, x])
        if bd[y, x] > 0.78 and bny[y, x] > 0.35:
            k = max(0, k - 1)                     # occluded underside
        cv.px(x, y, BS[k])
    for y, x in zip(*np.nonzero(chest)):
        k = int(lam_c[y, x])
        # torn shirt on the shoulders; ragged hem above the belly
        hem = cy_ + 0.6 + (1 if (x * 5 + 3) % 7 < 3 else 0)
        if y + 0.5 < hem and not (facing == "S" and abs(x + 0.5 - cx_) < 1.6):
            cv.px(x, y, SHIRT[min(3, max(0, k - 1))])
        else:
            cv.px(x, y, BS[k])
    # navel crease + a stretch-mark vein on the belly
    if facing == "S":
        cv.px_if(int(bx_), int(by_ + bry * 0.25), BS[1])
    return (bx_, by_, brx, bry)


def _pustules(cv, facing, p, cx, cy, rx, ry):
    for (u, v, size) in PUST[facing]:
        x = int(math.floor(cx + u * rx * 0.9))
        y = int(math.floor(cy + v * ry * 0.9))
        core = HOT if p.heat >= 2 else (GLOW if p.heat >= 1 or size == 2 else mix(GLOW, BS[2], 0.35))
        cells = [(x, y)] if size == 1 else [(x, y), (x + 1, y), (x, y + 1)]
        for (a, b) in cells:
            cv.px_if(a, b, core)
        cv.px_if(x + size, y + size, DEEP)
        cv.px_if(x - 1, y + size - 1, mix(DEEP, BS[1], 0.4))
        if size == 2:
            cv.px_if(x + 1, y + 1, DEEP if p.heat < 2 else GLOW)


def _stub_legs(facing, p):
    cv = rig.layer()
    if facing == "E":
        hx = 11 + p.bx
        for k, (sgn, cols) in enumerate(((-1, (BS[1], BS[0])), (1, (BS[2], BS[1])))):
            fx = hx + sgn * p.stride + (1 if p.legs[k] else 0)
            for y in range(16, rig.GROUND + 1 - p.legs[k]):
                cv.px(fx, y, cols[0]); cv.px(fx + 1, y, cols[1])
            cv.px(fx + 2, rig.GROUND - p.legs[k], cols[1])
    else:
        for k, x0 in enumerate((8, 14)):
            lift = p.legs[k]
            for y in range(16, rig.GROUND + 1 - lift):
                cv.px(x0 + p.bx // 2, y, BS[2] if k == 0 else BS[1])
                cv.px(x0 + 1 + p.bx // 2, y, BS[1] if k == 0 else BS[0])
    return cv


def _arms(facing, p, cx, cy, rx, ry):
    cv = rig.layer()
    if facing == "E":
        x = int(cx)
        y = int(cy - 1)
        rig.limb(cv, [(x, y), (x + 1, y + 2 + p.arm), (x + 1, y + 4 + p.arm)], BS[3])
        cv.px(x + 1, y + 4 + p.arm, BS[4])
        return cv
    for sgn in (-1, 1):
        x = int(math.floor(cx + sgn * rx))
        y = int(cy - 1)
        a = p.arm * sgn
        rig.limb(cv, [(x, y), (x + sgn, y + 2), (x + sgn, y + 4 + a)], BS[3] if sgn < 0 else BS[2])
        cv.px(x + sgn, y + 4 + a, BS[4] if sgn < 0 else BS[3])
    return cv


def _halo(cv, strength):
    """Translucent rad glow 1-2 px around the outlined silhouette (warning)."""
    op = cv.a[:, :, 3] > 0
    from scipy.ndimage import binary_dilation
    ring1 = binary_dilation(op, iterations=1) & ~op
    ring2 = binary_dilation(op, iterations=2) & ~op & ~ring1
    out = rig.layer()
    for (ring, al) in ((ring1, int(110 * strength)), (ring2, int(55 * strength))):
        ring[rig.FEET_ROW + 1:, :] = False          # never below the feet baseline
        for y, x in zip(*np.nonzero(ring)):
            out.px(x, y, rgba(P.RAD_GLOW, al))
    out.blit(cv, 0, 0)
    return out


def _cloud(facing, strength, seed=11):
    """Belched gas: translucent puffs + a few opaque droplets, aimed along the facing."""
    cv = rig.layer()
    r = pix.rng(seed)
    if facing == "E":
        puffs = [(18.5, 9.5, 2.6), (21.0, 8.5, 2.2), (20.5, 11.5, 2.0), (22.5, 10.5, 1.6)]
        drops = [(23, 13), (21, 6), (19, 13)]
    elif facing == "S":
        puffs = [(12.0, 9.5, 2.6), (9.0, 10.5, 2.0), (15.0, 10.0, 2.2), (12.0, 12.5, 1.8)]
        drops = [(6, 9), (18, 9), (9, 13), (16, 13)]
    else:  # N: the cloud rises beyond the head
        puffs = [(12.0, 2.5, 2.6), (9.0, 3.5, 2.0), (15.0, 3.0, 2.0)]
        drops = [(6, 2), (18, 1), (12, 0)]
    for (px_, py_, rad) in puffs:
        rad *= strength
        for y in range(rig.FH):
            for x in range(rig.FW):
                d = math.hypot(x + 0.5 - px_, y + 0.5 - py_)
                if d <= rad:
                    core = d < rad * 0.55
                    cv.px(x, y, rgba(P.RAD_GLOW, 200) if core else rgba(P.ICHOR_RAMP[3], 150))
    for (x, y) in drops:
        cv.px(x, y, ICH[3])
        cv.px(x, y + 1, ICH[1])
    return cv


def frame(facing, p):
    if facing == "W":
        return frame("E", p).flip_h()
    body = rig.layer()
    cx, cy, rx, ry = _shade_body(body, facing, p)
    _pustules(body, facing, p, cx, cy, rx, ry)
    legs = _stub_legs(facing, p)
    ccx, ccy, crx, cry = _chest(facing, p)
    arms = _arms(facing, p, ccx, ccy + 1, crx + 0.5, cry)
    if facing == "E":
        hx = int(round(ccx + 0.5))
        hy = int(round(ccy - cry - 2.4))
    else:
        hx = int(round(ccx - 3.0))
        hy = int(round(ccy - cry - 2.4))
    head = rig.stamp(HEAD[(facing, p.mouth)], CMAP, hx, hy)
    if facing == "N":
        layers = [legs, arms, body, head]
    elif facing == "E":
        layers = [legs, body, head, arms]
    else:
        layers = [legs, body, arms, head]
    out = rig.compose(layers)
    if p.heat >= 2:
        out = _halo(out, 1.0)
    if p.cloud > 0:
        cl = _cloud(facing, p.cloud)
        if facing == "N":
            under = rig.layer()
            under.blit(cl, 0, 0)
            under.blit(out, 0, 0)
            out = under
        else:
            out.blit(cl, 0, 0)
    out.a[rig.FEET_ROW + 1:, :, :] = 0
    return out


def poses():
    B = BPose
    out = {}
    for i in range(2):
        for d in "SNE":
            out[("idle", d, i)] = B(swell=0.3 * i, by=0, heat=i, arm=i)
    for d in "SN":
        for i, (bx, by, legs) in enumerate(((0, 0, (0, 1)), (-1, -1, (0, 0)),
                                             (0, 0, (1, 0)), (1, -1, (0, 0)))):
            out[("walk", d, i)] = B(bx=bx, by=by, legs=legs, arm=(i % 2))
    for i, (st, by, legs) in enumerate(((1, 0, (0, 0)), (0, -1, (0, 1)), (-1, 0, (0, 0)), (0, -1, (1, 0)))):
        out[("walk", "E", i)] = B(stride=st, by=by, legs=legs, arm=(i % 2))
    for d in "SNE":
        out[("attack", d, 0)] = B(swell=1.0, heat=1, mouth="n", arm=-1)
        out[("attack", d, 1)] = B(swell=1.7, heat=2, mouth="o", arm=-1, by=-1)
        out[("attack", d, 2)] = B(swell=0.4, heat=1, mouth="o", cloud=1.0, arm=1)
        out[("attack", d, 3)] = B(swell=-0.4, heat=0, mouth="n", arm=0)
        out[("hurt", d)] = B(squash=1.2, heat=1, mouth="o", arm=-1)
    return out


# ------------------------------------------------------------------------------------------------
# death: swell -> burst -> deflated sack -> sack in an ichor puddle
# ------------------------------------------------------------------------------------------------
def _puddle(cv, cx, cy, rx, ry, seed=5, glowing=True):
    r = pix.rng(seed)
    lobes = [(cx, cy, rx, ry)] + [(cx + r.uniform(-rx, rx) * 0.8, cy + r.uniform(-ry, ry) * 0.5,
                                   rx * r.uniform(0.3, 0.5), ry * r.uniform(0.5, 0.8)) for _ in range(4)]
    for y in range(cv.h):
        for x in range(cv.w):
            best = min(((x + 0.5 - a) / c) ** 2 + ((y + 0.5 - b) / d) ** 2 for (a, b, c, d) in lobes)
            if best <= 1.0:
                c = ICH[1] if best < 0.5 else ICH[2]
                if best > 0.75 and (x + 0.5 < cx) and (y + 0.5 < cy):
                    c = ICH[3]
                cv.px(x, y, c)
    for (dx, dy) in ((-rx - 1.5, -1), (rx + 1.2, 0), (-rx * 0.5, -ry - 1.2), (rx * 0.6, -ry - 1.0)):
        cv.px(int(cx + dx), int(cy + dy), ICH[2])
    if glowing:
        for (dx, dy) in ((-2, 0), (3, -1), (0, 1)):
            cv.px(int(cx + dx), int(cy + dy), GLOW)


def _sack(cv, cx, base, w, h, arm=True):
    """Deflated skin pile lying flat: lumpy lobes, wrinkles, torn shirt scrap, flopped head."""
    s = rig.layer()
    lobes = [(cx, base - h * 0.45, w * 0.40, h * 0.52),
             (cx - w * 0.30, base - h * 0.32, w * 0.20, h * 0.42),
             (cx + w * 0.12, base - h * 0.62, w * 0.22, h * 0.45)]
    ys, xs = np.mgrid[0:rig.FH, 0:rig.FW]
    best = np.full((rig.FH, rig.FW), -9.0)
    for (lx, ly, lrx, lry) in lobes:
        nx, ny, d = _ell(lx, ly, lrx, lry)
        lam = np.where(d <= 1.0, _lambert(nx, ny, d), -9.0)
        best = np.maximum(best, lam)
    idx = np.digitize(best, [0.05, 0.38, 0.66, 0.86])
    for y, x in zip(*np.nonzero(best > -9.0)):
        k = int(idx[y, x])
        if (x * 3 + y * 2) % 7 == 0 and k > 0:
            k -= 1                                      # wrinkles / folds
        s.px(x, y, BS[max(0, min(4, k - 1))])
    top = base - int(round(h * 0.95))
    for x in range(int(cx - 2), int(cx + 3)):
        s.px_if(x, top + 1, SHIRT[2] if x % 2 else SHIRT[1])
        s.px_if(x, top + 2, SHIRT[1])
    s.px_if(int(cx - 3), base - 2, DEEP)
    s.px_if(int(cx + 2), base - 1, DEEP)
    s.px_if(int(cx - w * 0.3), base - 2, mix(GLOW, BS[1], 0.4))
    if arm:
        ax, ay = int(cx - w * 0.15), top + 1
        rig.limb(s, [(ax, ay), (ax - 2, ay - 2), (ax - 3, ay - 2)], BS[2])
        s.px(ax - 3, ay - 2, BS[3])
    head = pix.part([".455.", "45m43", "4mm32", ".222."], CMAP)
    s.blit(head, int(cx + w / 2) - 3, base - 3)
    pix.outline(s, pix.COLD, local=0.72)
    cv.blit(s, 0, 0)


def death_frames():
    f0 = frame("S", BPose(swell=2.0, heat=2, mouth="o", arm=-1, by=-1))
    # f1: the burst
    f1 = rig.layer()
    base = rig.layer()
    _puddle(base, 12.0, 18.0, 6.0, 1.8, seed=2, glowing=False)
    f1.blit(base, 0, 0)
    burst = rig.layer()
    r = pix.rng(31)
    for k in range(26):
        ang = k / 26.0 * math.tau + r.uniform(-0.1, 0.1)
        dist = r.uniform(4.5, 9.5)
        x = 12 + math.cos(ang) * dist
        y = 11.5 + math.sin(ang) * dist * 0.8
        c = [ICH[2], ICH[3], GLOW, BS[3], ICH[1]][k % 5]
        burst.px(int(x), int(y), c)
        if k % 3 == 0:
            burst.px(int(x) + 1, int(y), mix(c, ICH[1], 0.4))
    for y in range(rig.FH):
        for x in range(rig.FW):
            d = math.hypot(x + 0.5 - 12, (y + 0.5 - 11.5) / 0.8)
            if d < 6.5:
                burst.px(x, y, rgba(P.RAD_GLOW, 170 if d < 3.5 else 90))
    tatters = rig.layer()
    for (x, y, c) in ((10, 14, BS[3]), (11, 14, BS[2]), (13, 15, BS[2]), (14, 14, BS[3]), (12, 16, SHIRT[2]),
                      (9, 16, BS[1]), (15, 16, BS[1]), (11, 12, BS[4]), (13, 12, BS[3])):
        tatters.px(x, y, c)
    pix.outline(tatters, pix.COLD, local=0.72)
    f1.blit(tatters, 0, 0)
    f1.blit(burst, 0, 0)
    f2 = rig.layer()
    _puddle(f2, 12.0, 17.5, 9.0, 2.8, seed=2, glowing=True)
    _sack(f2, 11.5, 18, 16, 7)
    for (x, y) in ((4, 12), (20, 13), (7, 10), (17, 10)):
        f2.px(x, y, ICH[3])
        f2.px(x, y + 1, rgba(P.ICHOR_RAMP[2], 160))
    f3 = rig.layer()
    _puddle(f3, 12.0, 17.5, 10.5, 3.2, seed=2, glowing=True)
    _sack(f3, 11.5, 19, 17, 6)
    return [f0, f1, f2, f3]


def frames():
    out = {k: frame(k[1], p) for k, p in poses().items()}
    for i, f in enumerate(death_frames()):
        out[("death", i)] = f
    return out


def sheet():
    return rig.assemble(frames())
