"""Foliage / organic-shape rendering shared by trees, bushes, saplings and weeds.

A canopy is a list of "puffs" (leaf clumps): circles with a scalloped rim, shaded as spheres
lit from the top-left, drawn back-to-front so lower/front clumps overlap the ones behind. Clump
crevices get a darker line, a small-scale value noise breaks the shading bands into leafy
clusters, and the silhouette receives a selective outline.
"""
from __future__ import annotations

import math

import numpy as np

from env import lib
from env.lib import Canvas, mix, rgba


class Puff:
    def __init__(self, cx, cy, r, ramp=None, bumps=None, phase=0.0, amp=0.10, bias=0.0):
        self.cx, self.cy, self.r = cx, cy, r
        self.ramp = ramp
        self.bumps = bumps if bumps is not None else max(5, int(r * 1.1))
        self.phase = phase
        self.amp = amp
        self.bias = bias

    def inside(self, x, y):
        dx = x + 0.5 - self.cx
        dy = y + 0.5 - self.cy
        d = math.hypot(dx, dy)
        if d < 1e-6:
            return True, 0.0, 0.0
        th = math.atan2(dy, dx)
        rr = self.r * (1.0 + self.amp * math.sin(self.bumps * th + self.phase))
        if d > rr:
            return False, 0.0, 0.0
        return True, dx / rr, dy / rr


def canopy(w, h, puffs, ramp, seed=1, leaf_amp=0.16, levels=None, ao=0.25, crevice=True,
           y_span=None, highlight_cut=0.80, outline=True, outline_dark=None, outline_local=None):
    """Render puffs into a new Canvas. `ramp` darkest->lightest (>= 5 colours).

    levels: intensity thresholds -> ramp indices 1..len(ramp)-1 (index 0 reserved for outline).
    """
    ramp = [rgba(c) for c in ramp]
    n = len(ramp)
    noise = lib.value_noise(w, h, max(1, w // 3), max(1, h // 3), seed, wrap=False)
    noise2 = lib.value_noise(w, h, max(1, w // 2), max(1, h // 2), seed + 7, wrap=False)
    lab = -np.ones((h, w), int)
    inten = np.zeros((h, w))
    ys = [p.cy for p in puffs]
    y0 = min(p.cy - p.r for p in puffs)
    y1 = max(p.cy + p.r for p in puffs)
    if y_span:
        y0, y1 = y_span
    order = sorted(range(len(puffs)), key=lambda i: (puffs[i].cy, -puffs[i].r))
    for rank, i in enumerate(order):
        p = puffs[i]
        for y in range(max(0, int(p.cy - p.r * 1.2) - 1), min(h, int(p.cy + p.r * 1.2) + 2)):
            for x in range(max(0, int(p.cx - p.r * 1.2) - 1), min(w, int(p.cx + p.r * 1.2) + 2)):
                ok, nx, ny = p.inside(x, y)
                if not ok:
                    continue
                v = float(lib.sphere_shade(nx, ny))
                v += (noise[y, x] - 0.5) * 2 * leaf_amp + (noise2[y, x] - 0.5) * leaf_amp * 0.8
                t = (y + 0.5 - y0) / max(1.0, (y1 - y0))
                v -= ao * t
                v += p.bias
                lab[y, x] = rank
                inten[y, x] = v
    if levels is None:
        # spread across ramp indices 1..n-1
        k = n - 1
        levels = list(np.linspace(-0.35, highlight_cut, k - 1))
    idx = 1 + lib.quantize(inten, levels)
    idx = np.clip(idx, 1, n - 1)
    if crevice:
        # back clump pixels right above / left of a front clump sit in its shadow
        dark = np.zeros_like(idx)
        for y in range(h - 1):
            for x in range(w):
                a = lab[y, x]
                if a < 0:
                    continue
                b = lab[y + 1, x]
                if b > a:
                    dark[y, x] = 2
                    if y > 0 and lab[y - 1, x] == a:
                        dark[y - 1, x] = max(dark[y - 1, x], 1)
                if x + 1 < w and lab[y, x + 1] > a:
                    dark[y, x] = max(dark[y, x], 1)
        idx = np.clip(idx - dark, 1, n - 1)
    cv = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            if lab[y, x] < 0:
                continue
            p = puffs[order[lab[y, x]]]
            r = [rgba(c) for c in p.ramp] if p.ramp else ramp
            cv.a[y, x] = r[min(idx[y, x], len(r) - 1)]
    if outline:
        od = outline_dark if outline_dark is not None else mix(ramp[0], lib.WARM, 0.45)
        lib.outline(cv, od, local=0.5)
        if outline_local is not None:
            pass
    return cv, lab


def scatter_blossoms(cv, lab, r, colors, count, region=None, seed=0, min_level=None):
    """Small 2-3px blossoms on the lit side of a canopy (top-left biased)."""
    rng = lib.rng(seed)
    h, w = lab.shape
    placed = []
    tries = 0
    hi, mid, lo = colors
    while len(placed) < count and tries < 2000:
        tries += 1
        x = rng.randrange(2, w - 3)
        y = rng.randrange(2, h - 3)
        if region and not region(x, y):
            continue
        if lab[y, x] < 0 or lab[y + 1, x] < 0 or lab[y, x + 1] < 0 or lab[y - 1, x] < 0:
            continue
        if cv.alpha(x, y - 2) == 0:
            continue
        if any(abs(x - px) + abs(y - py) < 5 for px, py in placed):
            continue
        if (x + y) % 3 == 0:
            # tiny five-pixel blossom
            cv.px(x, y - 1, mid); cv.px(x - 1, y, mid); cv.px(x + 1, y, lo); cv.px(x, y + 1, lo)
            cv.px(x, y, hi)
        else:
            cv.px(x, y, hi); cv.px(x + 1, y, mid); cv.px(x, y + 1, lo)
        placed.append((x, y))
    return placed
