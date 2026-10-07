"""Reusable 3/4-view solid shapes: faceted rocks, cylinders, boxes, discs, rings.

Each helper draws into a Canvas without outlining; callers outline the finished silhouette
(lib.outline) so overlapping parts get one coherent selective outline.
"""
from __future__ import annotations

import math

import numpy as np

from env import lib
from env.lib import Canvas, mix, rgba


# ------------------------------------------------------------------------------------------------
def rock(cv, cx, base, w, h, R, top_h=None, ridge=0.18, seed=0, crack=True, speck=True,
         ridge2=None, flat=2.4, tuck=True):
    """Faceted rock/boulder in 3/4 view.

    cx: centre x (float), base: ground row, w/h: size, R: ramp (>= 6, dark -> light).
    Upper part = lit top face; lower part = front face split by a ridge into a lit-left and a
    shaded-right facet.
    """
    r = lib.rng(seed)
    top = base - h + 1
    top_h = top_h if top_h is not None else max(2, int(h * 0.42))
    mask = np.zeros((cv.h, cv.w), bool)
    for y in range(top, base + 1):
        t = (base + 0.5 - y) / h                     # 0 at the ground .. 1 at the top
        f = max(0.0, 1 - t ** flat) ** 0.5
        if tuck and y == base:
            f *= 0.86
        half = w / 2.0 * f
        for x in range(int(cx - half - 1), int(cx + half + 2)):
            if abs(x + 0.5 - cx) <= half:
                if 0 <= x < cv.w and 0 <= y < cv.h:
                    mask[y, x] = True
    # top face ellipse
    fcy = top + top_h * 0.55
    frx = w / 2.0 * 0.86
    fry = top_h * 0.75
    ridge_x = cx + w * ridge
    for y in range(cv.h):
        for x in range(cv.w):
            if not mask[y, x]:
                continue
            dx = (x + 0.5 - cx) / (w / 2.0)
            top_face = ((x + 0.5 - cx) / frx) ** 2 + ((y + 0.5 - fcy) / fry) ** 2 <= 1.0 and \
                y < fcy + fry * 0.6
            if top_face:
                c = R[4]
                if dx < -0.2 and y < fcy:
                    c = R[5]
                elif dx > 0.55:
                    c = R[3]
            else:
                # front face: left facet lit, right facet shaded; darker toward the ground
                rx = ridge_x + (y - fcy) * 0.25
                if x + 0.5 < rx:
                    c = R[3] if dx < -0.45 or y < base - 2 else R[2]
                else:
                    c = R[2] if y < base - 1 else R[1]
                if ridge2 is not None and x + 0.5 > cx + w * ridge2 and not top_face:
                    c = R[1]
                if y == base:
                    c = R[1] if c != R[3] else R[2]
            cv.px(x, y, c)
    # facet edge highlight along the top face rim (front edge of the top)
    for x in range(cv.w):
        for y in range(cv.h - 1):
            if mask[y, x] and mask[y + 1, x]:
                a = cv.get(x, y)
                b = cv.get(x, y + 1)
                if a[:3] in (R[4][:3], R[5][:3]) and b[:3] not in (R[4][:3], R[5][:3]):
                    if (x + 0.5) < ridge_x:
                        cv.px(x, y + 1, mix(R[3], R[4], 0.5))
    if crack:
        x = int(cx + w * r.uniform(-0.1, 0.12))
        y = int(fcy + fry * 0.3)
        for k in range(r.randint(2, 3)):
            if mask[min(cv.h - 1, y + k), x]:
                cv.px(x, y + k, R[1])
            x += r.choice([0, 1])
    if speck:
        for _ in range(max(1, w // 6)):
            x = r.randrange(int(cx - w / 3), int(cx + w / 3))
            y = r.randrange(top + 1, base)
            if 0 <= x < cv.w and mask[y, x]:
                c = cv.get(x, y)
                cv.px(x, y, mix(c, R[0], 0.35) if r.random() < 0.6 else mix(c, R[5], 0.4))
    return mask


# ------------------------------------------------------------------------------------------------
def cylinder(cv, cx, base, rx, height, R, ry=None, top=None, bands=(), hollow=False,
             top_ramp=None):
    """Upright cylinder (barrel/drum/pipe) in 3/4 view; R dark->light (>= 5)."""
    ry = ry if ry is not None else max(1.0, rx * 0.42)
    top_y = base - height
    w = int(round(rx * 2))
    x0 = int(round(cx - rx))
    for y in range(int(top_y), base + 1):
        for x in range(x0, x0 + w):
            t = (x + 0.5 - (cx - rx)) / (2 * rx)       # 0..1 across
            # body: bottom ellipse cut
            dyb = (y + 0.5 - (base - ry)) / ry
            dxe = (x + 0.5 - cx) / rx
            if y > base - ry and dxe * dxe + dyb * dyb > 1.0:
                continue
            if t < 0.14:
                c = R[3]
            elif t < 0.32:
                c = R[4]
            elif t < 0.55:
                c = R[3]
            elif t < 0.8:
                c = R[2]
            else:
                c = R[1]
            for (by, bh) in bands:
                if by <= base - y < by + bh:
                    c = mix(c, R[0], 0.35) if t > 0.5 else mix(c, R[0], 0.2)
                    if base - y == by + bh - 1:
                        c = mix(c, R[4], 0.35)
            cv.px(x, y, c)
    # top ellipse
    T = top_ramp or R
    for y in range(int(top_y - ry), int(top_y + ry) + 1):
        for x in range(x0, x0 + w):
            dxe = (x + 0.5 - cx) / rx
            dye = (y + 0.5 - top_y) / ry
            d = dxe * dxe + dye * dye
            if d > 1.0:
                continue
            if hollow and d < 0.55:
                c = T[0] if dye < 0.2 else T[1]
            elif d > 0.62:
                c = T[4] if dxe < 0 else T[3]       # rim
            else:
                c = T[3] if dxe < 0.2 else T[2]
            cv.px(x, y, c)


# ------------------------------------------------------------------------------------------------
def box(cv, x, y, w, front_h, top_h, top_ramp, front_ramp, side=0, side_ramp=None):
    """3/4 box: top face (top_h rows) above a front face (front_h rows). Optional right side.

    (x, y) = top-left of the top face. Ramps dark->light.
    """
    T = top_ramp
    F = front_ramp
    for j in range(top_h):
        for i in range(w):
            c = T[4] if j < top_h - 1 else T[3]
            if i == 0:
                c = mix(c, T[5] if len(T) > 5 else T[4], 0.5)
            if i >= w - 1:
                c = T[2]
            cv.px(x + i, y + j, c)
    for j in range(front_h):
        for i in range(w):
            c = F[3]
            if i == 0:
                c = F[4]
            if i >= w - 2:
                c = F[2]
            if j == front_h - 1:
                c = F[1]
            cv.px(x + i, y + top_h + j, c)
    if side and side_ramp:
        S = side_ramp
        for j in range(front_h + top_h):
            for i in range(side):
                cv.px(x + w + i, y + j - i + 0, S[1])


# ------------------------------------------------------------------------------------------------
def ellipse_fill(cv, cx, cy, rx, ry, c):
    m = cv.ellipse_mask(cx, cy, rx, ry)
    cv.fill(m, c)
    return m


def ring(cv, cx, cy, rx, ry, thick, R, hole_clear=True):
    """Flat ring (tyre lying on the ground) in 3/4 view, R dark -> light."""
    outer = cv.ellipse_mask(cx, cy, rx, ry)
    inner = cv.ellipse_mask(cx, cy - 0.5, rx - thick, max(0.8, ry - thick * 0.6))
    ys, xs = np.nonzero(outer & ~inner)
    for y, x in zip(ys, xs):
        dx = (x + 0.5 - cx) / rx
        dy = (y + 0.5 - cy) / ry
        if dy < -0.25:
            c = R[3] if dx < 0.3 else R[2]
        elif dy > 0.35:
            c = R[1]
        else:
            c = R[2] if dx < 0 else R[1]
        cv.px(x, y, c)
    return outer, inner


def thick_line(cv, pts, w, colors, cap=True):
    """Polyline of width w (1..3); colors: list per offset across the line (lit -> dark)."""
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        ln = max(abs(bx - ax), abs(by - ay), 1)
        for i in range(int(ln * 2) + 1):
            f = i / (ln * 2)
            x = ax + (bx - ax) * f
            y = ay + (by - ay) * f
            horiz = abs(bx - ax) >= abs(by - ay)
            for k in range(w):
                c = colors[min(k, len(colors) - 1)]
                if horiz:
                    cv.px(int(round(x)), int(round(y)) + k, c)
                else:
                    cv.px(int(round(x)) + k, int(round(y)), c)


# ------------------------------------------------------------------------------------------------
def facet_rock(cv, cx, base, w, h, R, seed=0, n_facets=6, jag=0.12, top_flat=0.0, lit_bias=0.0):
    """Angular faceted rock: jittered convex silhouette split into flat Voronoi facets.

    Each facet gets one shade from a fake normal (its seed's offset from the centre): top-left
    facets bright, bottom-right dark. Facet borders are re-lit/darkened for a chiselled look.
    Returns the silhouette mask.
    """
    r = lib.rng(seed)
    cy = base - h / 2.0
    # silhouette polygon
    pts = []
    k = 9
    for i in range(k):
        a = math.pi + (i / (k - 1)) * math.pi          # from left (pi) over the top to right (2pi)
        rr = 1.0 + r.uniform(-jag, jag)
        x = cx + math.cos(a) * w / 2.0 * rr
        y = cy + math.sin(a) * h / 2.0 * rr * (1.0 - top_flat * (abs(math.cos(a)) < 0.5))
        pts.append((x, y))
    tuck = max(0.6, w * 0.07)
    pts = [(cx - w / 2.0 + tuck, base + 0.5)] + pts + [(cx + w / 2.0 - tuck, base + 0.5)]
    mask = cv.poly_mask(pts)
    mask[base + 1:, :] = False
    # facet seeds
    seeds = [(cx - w * 0.12, cy - h * 0.32, 0.9 + lit_bias)]           # top facet
    for i in range(n_facets - 1):
        a = math.pi * (0.95 + 1.1 * i / max(1, n_facets - 2))
        sx = cx + math.cos(a) * w * r.uniform(0.25, 0.4)
        sy = cy + math.sin(a) * h * 0.3 + h * r.uniform(0.05, 0.25)
        u = (sx - cx) / (w / 2.0)
        v = (sy - cy) / (h / 2.0)
        val = 0.55 - 0.55 * u - 0.45 * v + r.uniform(-0.08, 0.08) + lit_bias
        seeds.append((sx, sy, val))
    lab = np.full((cv.h, cv.w), -1)
    ys, xs = np.nonzero(mask)
    for y, x in zip(ys, xs):
        best = min(range(len(seeds)),
                   key=lambda j: (x + 0.5 - seeds[j][0]) ** 2 + ((y + 0.5 - seeds[j][1]) * 1.3) ** 2)
        lab[y, x] = best
    for y, x in zip(ys, xs):
        val = seeds[lab[y, x]][2]
        val -= 0.25 * max(0.0, (y - (base - 2)) / 2.0)          # ground contact darkening
        idx = int(np.clip(1 + val * 4.0, 1, len(R) - 1))
        cv.px(x, y, R[idx])
    # chisel: a facet pixel whose upper/left neighbour belongs to another facet gets a highlight
    # if it is the brighter facet, else a crease shadow
    out = cv.a.copy()
    for y, x in zip(ys, xs):
        a = lab[y, x]
        for (nx, ny) in ((x, y - 1), (x - 1, y)):
            if 0 <= nx < cv.w and 0 <= ny < cv.h and lab[ny, nx] >= 0 and lab[ny, nx] != a:
                if seeds[a][2] > seeds[lab[ny, nx]][2]:
                    out[y, x] = R[min(len(R) - 1, int(np.clip(2 + seeds[a][2] * 4.0, 1, len(R) - 1)))]
                else:
                    out[y, x] = R[max(1, int(np.clip(seeds[a][2] * 4.0, 1, len(R) - 1)))]
                break
    cv.a = out
    return mask
