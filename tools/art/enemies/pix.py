"""Small pixel-art toolkit for the enemy / FX pipeline (same conventions as tools/art/env/lib.py).

`Canvas` wraps an (h, w, 4) uint8 numpy RGBA array; (0, 0) is the top-left pixel. Colours are
RGBA tuples, and every helper also accepts '#rrggbb' strings. docs/ART_STYLE.md rules baked in:
  * alpha is 0 or 255 except deliberately translucent effects (glows, smoke, splat edges);
  * light from the top-left;
  * selective 1 px outline outside the silhouette: the cold ruins outline below/right, a dark
    shade of the local material above/left (`outline`);
  * parts drawn in front of other parts cast a 1 px contour onto them (`Canvas.over`), which is
    how the overlapping limbs of a 16 px figure stay readable.
Parts are authored as ASCII rows ('.' / ' ' transparent, other characters index a colour map).
"""
from __future__ import annotations

import pathlib
import random

import numpy as np
from PIL import Image

import palette as P

REPO = pathlib.Path(__file__).resolve().parents[3]
CLEAR = (0, 0, 0, 0)


# ------------------------------------------------------------------------------------------------
# colours
# ------------------------------------------------------------------------------------------------
def rgba(c, a=None):
    """'#rrggbb' / (r, g, b) / (r, g, b, a) -> (r, g, b, a) tuple of ints."""
    if isinstance(c, str):
        v = P.hex_to_rgba(c)
    else:
        v = tuple(int(t) for t in c)
        if len(v) == 3:
            v = v + (255,)
    if a is not None:
        v = v[:3] + (int(a),)
    return v


def ramp(colors):
    return [rgba(c) for c in colors]


def mix(c1, c2, t):
    """Linear RGB blend; alpha comes from c1."""
    a = rgba(c1)
    b = rgba(c2)
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (a[3],)


COLD = rgba(P.OUTLINE_COLD)
WARM = rgba(P.OUTLINE_WARM)


# ------------------------------------------------------------------------------------------------
# canvas
# ------------------------------------------------------------------------------------------------
class Canvas:
    def __init__(self, w, h):
        self.w = int(w)
        self.h = int(h)
        self.a = np.zeros((self.h, self.w, 4), dtype=np.uint8)

    @classmethod
    def from_array(cls, arr):
        c = cls(arr.shape[1], arr.shape[0])
        c.a = arr.astype(np.uint8).copy()
        return c

    @classmethod
    def load(cls, path):
        return cls.from_array(np.array(Image.open(path).convert("RGBA")))

    def copy(self):
        return Canvas.from_array(self.a)

    # -- pixels ---------------------------------------------------------------------------------
    def inb(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def get(self, x, y):
        if not self.inb(x, y):
            return CLEAR
        return tuple(int(v) for v in self.a[y, x])

    def alpha(self, x, y):
        return int(self.a[y, x, 3]) if self.inb(x, y) else 0

    def px(self, x, y, c):
        x = int(x)
        y = int(y)
        if not self.inb(x, y):
            return
        c = rgba(c)
        if c[3] == 255 or self.a[y, x, 3] == 0:
            self.a[y, x] = c
        elif c[3] > 0:
            self.a[y, x] = _over(self.a[y, x], c)

    def px_if(self, x, y, c):
        """Paint only where something opaque already is (surface detail)."""
        if self.alpha(x, y) == 255:
            self.px(x, y, c)

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.px(xx, yy, c)

    def line(self, x0, y0, x1, y1, c):
        for x, y in line_points(x0, y0, x1, y1):
            self.px(x, y, c)

    def opaque(self):
        return self.a[:, :, 3] == 255

    def any(self):
        return self.a[:, :, 3] > 0

    # -- compositing ----------------------------------------------------------------------------
    def blit(self, src, x=0, y=0):
        """Alpha-composite `src` (Canvas) with its top-left at (x, y)."""
        for sy in range(src.h):
            ty = y + sy
            if not 0 <= ty < self.h:
                continue
            for sx in range(src.w):
                tx = x + sx
                if not 0 <= tx < self.w:
                    continue
                p = src.a[sy, sx]
                if p[3] == 0:
                    continue
                if p[3] == 255 or self.a[ty, tx, 3] == 0:
                    self.a[ty, tx] = p
                else:
                    self.a[ty, tx] = _over(self.a[ty, tx], p)

    def over(self, src, x=0, y=0, contour=None, strong=0.62, soft=0.0):
        """Blit `src` in front of what is already drawn, casting a 1 px contour onto it.

        Existing opaque pixels just below / right of src's silhouette are pulled `strong` of
        the way toward `contour`; those just above / left `soft` of the way (0 = untouched).
        """
        if contour is not None:
            m = np.zeros((self.h, self.w), bool)
            ys, xs = np.nonzero(src.a[:, :, 3] > 0)
            valid = (ys + y >= 0) & (ys + y < self.h) & (xs + x >= 0) & (xs + x < self.w)
            m[ys[valid] + y, xs[valid] + x] = True
            pad = np.pad(m, 1)
            from_above = pad[:-2, 1:-1]
            from_left = pad[1:-1, :-2]
            from_below = pad[2:, 1:-1]
            from_right = pad[1:-1, 2:]
            base = (self.a[:, :, 3] == 255) & ~m
            hard = base & (from_above | from_left)
            light = base & ~hard & (from_below | from_right)
            dark = rgba(contour)
            for yy, xx in zip(*np.nonzero(hard)):
                self.a[yy, xx] = mix(tuple(self.a[yy, xx]), dark, strong)
            if soft > 0:
                for yy, xx in zip(*np.nonzero(light)):
                    self.a[yy, xx] = mix(tuple(self.a[yy, xx]), dark, soft)
        self.blit(src, x, y)
        return self

    # -- transforms -----------------------------------------------------------------------------
    def flip_h(self):
        return Canvas.from_array(self.a[:, ::-1])

    def shifted(self, dx, dy):
        out = Canvas(self.w, self.h)
        out.blit(self, dx, dy)
        return out

    def recolor(self, mapping):
        """Exact-colour remap {rgba_or_hex: rgba_or_hex}; alpha preserved."""
        out = self.copy()
        for src, dst in mapping.items():
            s = rgba(src)
            d = rgba(dst)
            hit = np.all(self.a[:, :, :3] == np.array(s[:3], np.uint8), axis=2) & (self.a[:, :, 3] > 0)
            out.a[hit, :3] = d[:3]
        return out

    def clean(self):
        """Zero the RGB of fully transparent pixels (deterministic, tidy PNGs)."""
        self.a[self.a[:, :, 3] == 0] = 0
        return self

    def to_image(self):
        self.clean()
        return Image.fromarray(self.a, "RGBA")

    def save(self, path):
        path = pathlib.Path(path)
        if not path.is_absolute():
            path = REPO / path
        path.parent.mkdir(parents=True, exist_ok=True)
        self.to_image().save(path, optimize=False)
        return path


def _over(dst, src):
    sa = src[3] / 255.0
    da = dst[3] / 255.0
    oa = sa + da * (1 - sa)
    if oa <= 0:
        return np.array([0, 0, 0, 0], np.uint8)
    out = [(src[i] * sa + dst[i] * da * (1 - sa)) / oa for i in range(3)]
    return np.array([int(round(out[0])), int(round(out[1])), int(round(out[2])),
                     int(round(oa * 255))], np.uint8)


def line_points(x0, y0, x1, y1):
    """Bresenham line, endpoints included."""
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    pts = []
    dx = abs(x1 - x0)
    dy = -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        pts.append((x0, y0))
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
    return pts


def poly_points(pts):
    """Bresenham polyline through `pts`, no duplicated joints."""
    out = []
    for (a, b) in zip(pts, pts[1:]):
        seg = line_points(a[0], a[1], b[0], b[1])
        if out and seg and out[-1] == seg[0]:
            seg = seg[1:]
        out.extend(seg)
    if len(pts) == 1:
        out = [(int(round(pts[0][0])), int(round(pts[0][1])))]
    return out


# ------------------------------------------------------------------------------------------------
# ASCII parts
# ------------------------------------------------------------------------------------------------
def part(rows, cmap, flip=False):
    """ASCII rows -> Canvas. '.' and ' ' are transparent; other characters index `cmap`."""
    h = len(rows)
    w = max(len(r) for r in rows)
    cv = Canvas(w, h)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in ". ":
                continue
            if ch not in cmap:
                raise KeyError(f"colour key {ch!r} missing (row {y}: {row!r})")
            cv.px(x, y, cmap[ch])
    return cv.flip_h() if flip else cv


# ------------------------------------------------------------------------------------------------
# outlines
# ------------------------------------------------------------------------------------------------
def _nbrs(op):
    pad = np.pad(op, 1)
    return pad[:-2, 1:-1], pad[2:, 1:-1], pad[1:-1, :-2], pad[1:-1, 2:]


def outline(cv, dark=COLD, local=0.72, diag=False, skip=None):
    """Selective 1 px outline drawn OUTSIDE the opaque silhouette.

    Pixels below / right of the shape get `dark`; pixels above / left get the neighbouring
    material pulled `local` of the way toward `dark` (a dark shade of the local material).
    `diag` also closes diagonal-only corners (with `dark`). `skip`: bool mask left untouched.
    """
    dark = rgba(dark)
    a = cv.a
    op = a[:, :, 3] == 255
    up, down, left, right = _nbrs(op)
    cand = ~op & (up | down | left | right)
    diag_only = np.zeros_like(op)
    if diag:
        pad = np.pad(op, 1)
        dg = pad[:-2, :-2] | pad[:-2, 2:] | pad[2:, :-2] | pad[2:, 2:]
        diag_only = ~op & dg & ~cand
        cand |= diag_only
    if skip is not None:
        cand &= ~skip
    out = a.copy()
    for y, x in zip(*np.nonzero(cand)):
        if up[y, x] or left[y, x] or diag_only[y, x]:
            out[y, x] = dark
        else:
            n = a[y + 1, x] if down[y, x] else a[y, x + 1]
            out[y, x] = mix(tuple(n[:3]) + (255,), dark, local)
    cv.a = out
    return cv


# ------------------------------------------------------------------------------------------------
# sheets / misc
# ------------------------------------------------------------------------------------------------
def hstrip(frames):
    w = sum(f.w for f in frames)
    h = max(f.h for f in frames)
    out = Canvas(w, h)
    x = 0
    for f in frames:
        out.blit(f, x, 0)
        x += f.w
    return out


def rng(seed):
    return random.Random(seed)


def bbox(cv):
    ys, xs = np.nonzero(cv.a[:, :, 3] > 0)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())
