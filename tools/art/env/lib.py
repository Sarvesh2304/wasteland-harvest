"""Pixel-art drawing toolkit for the environment pipeline.

Everything works on `Canvas`, a thin wrapper around an (h, w, 4) uint8 numpy RGBA array.
Coordinates are integer pixels with (0, 0) at the top-left. Colours are RGBA tuples; every
helper also accepts '#rrggbb' strings. Rules from docs/ART_STYLE.md baked in here:
  * alpha is 0 or 255, except contact shadows / deliberate translucent effects;
  * light from the top-left; selective outlines (local dark shade on top/left edges, the warm
    or cold outline colour on bottom/right edges);
  * contact shadows are OUTLINE_WARM at ~35% alpha, offset to the bottom-right.
"""
from __future__ import annotations

import math
import pathlib
import random

import numpy as np
from PIL import Image, ImageDraw

import palette as P

REPO = pathlib.Path(__file__).resolve().parents[3]
OUT = REPO / "art" / "env"
SHADOW_ALPHA = 89  # ~35 %


# --------------------------------------------------------------------------------------------
# colour helpers
# --------------------------------------------------------------------------------------------
def rgba(c, a=None):
    """'#rrggbb' / (r,g,b) / (r,g,b,a) -> (r,g,b,a) tuple of ints."""
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
    """Linear RGB blend, alpha taken from c1."""
    a = rgba(c1)
    b = rgba(c2)
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (a[3],)


def hexs(c):
    c = rgba(c)
    return "#%02x%02x%02x" % c[:3]


def lum(c):
    c = rgba(c)
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


WARM = rgba(P.OUTLINE_WARM)
COLD = rgba(P.OUTLINE_COLD)
CLEAR = (0, 0, 0, 0)


# --------------------------------------------------------------------------------------------
# canvas
# --------------------------------------------------------------------------------------------
class Canvas:
    def __init__(self, w, h):
        self.w = int(w)
        self.h = int(h)
        self.a = np.zeros((self.h, self.w, 4), dtype=np.uint8)

    # -- construction ------------------------------------------------------------------------
    @classmethod
    def from_array(cls, arr):
        c = cls(arr.shape[1], arr.shape[0])
        c.a = arr.astype(np.uint8).copy()
        return c

    @classmethod
    def load(cls, path):
        im = Image.open(path).convert("RGBA")
        return cls.from_array(np.array(im))

    def copy(self):
        return Canvas.from_array(self.a)

    # -- pixel access ------------------------------------------------------------------------
    def inb(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def get(self, x, y):
        if not self.inb(x, y):
            return CLEAR
        return tuple(int(v) for v in self.a[y, x])

    def alpha(self, x, y):
        if not self.inb(x, y):
            return 0
        return int(self.a[y, x, 3])

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
        """Only paint where something opaque already is (detail on a body)."""
        if self.alpha(x, y) == 255:
            self.px(x, y, c)

    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.px(xx, yy, c)

    def hline(self, x0, x1, y, c):
        if x1 < x0:
            x0, x1 = x1, x0
        for x in range(int(x0), int(x1) + 1):
            self.px(x, y, c)

    def vline(self, x, y0, y1, c):
        if y1 < y0:
            y0, y1 = y1, y0
        for y in range(int(y0), int(y1) + 1):
            self.px(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        for x, y in line_points(x0, y0, x1, y1):
            self.px(x, y, c)

    def fill(self, mask, c):
        c = rgba(c)
        if c[3] == 255:
            self.a[mask] = c
        else:
            ys, xs = np.nonzero(mask)
            for y, x in zip(ys, xs):
                self.px(x, y, c)

    def fill_where(self, mask, c):
        """Fill mask but only on already-opaque pixels."""
        m = mask & (self.a[:, :, 3] == 255)
        self.fill(m, c)

    def blit(self, src, x, y):
        """Alpha-composite `src` (Canvas) at (x, y)."""
        sa = src.a
        for sy in range(src.h):
            ty = y + sy
            if not 0 <= ty < self.h:
                continue
            for sx in range(src.w):
                tx = x + sx
                if not 0 <= tx < self.w:
                    continue
                p = sa[sy, sx]
                if p[3] == 0:
                    continue
                if p[3] == 255 or self.a[ty, tx, 3] == 0:
                    self.a[ty, tx] = p
                else:
                    self.a[ty, tx] = _over(self.a[ty, tx], p)

    def opaque(self):
        return self.a[:, :, 3] == 255

    def any(self):
        return self.a[:, :, 3] > 0

    # -- shapes --------------------------------------------------------------------------------
    def ellipse_mask(self, cx, cy, rx, ry):
        """Pixel-centre sampled ellipse; cx/cy may be fractional (use x.5 for odd widths)."""
        ys, xs = np.mgrid[0:self.h, 0:self.w]
        return ((xs + 0.5 - cx) / rx) ** 2 + ((ys + 0.5 - cy) / ry) ** 2 <= 1.0

    def poly_mask(self, pts):
        im = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(im).polygon([(float(x), float(y)) for x, y in pts], fill=255, outline=255)
        return np.array(im) > 0

    def shadow(self, cx, cy, rx, ry, alpha=SHADOW_ALPHA, color=None):
        """Soft contact shadow (translucent ellipse); only darkens, never stacks."""
        color = rgba(color or P.OUTLINE_WARM)
        m = self.ellipse_mask(cx, cy, rx, ry)
        ys, xs = np.nonzero(m)
        for y, x in zip(ys, xs):
            cur = self.a[y, x]
            if cur[3] == 0:
                self.a[y, x] = color[:3] + (alpha,)
            elif cur[3] == 255:
                self.a[y, x] = _over(cur, color[:3] + (alpha,))
            else:
                self.a[y, x, 3] = max(int(cur[3]), alpha)

    # -- transforms -----------------------------------------------------------------------------
    def flip_h(self):
        return Canvas.from_array(self.a[:, ::-1])

    def crop(self, x, y, w, h):
        out = Canvas(w, h)
        out.blit(self, -x, -y)
        return out

    def clean(self):
        """Zero RGB of fully transparent pixels (deterministic, tidy PNGs)."""
        self.a[self.a[:, :, 3] == 0] = 0
        return self

    def to_image(self):
        self.clean()
        return Image.fromarray(self.a, "RGBA")

    def save(self, rel_or_path):
        path = pathlib.Path(rel_or_path)
        if not path.is_absolute():
            path = OUT / path
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


# --------------------------------------------------------------------------------------------
# outlines
# --------------------------------------------------------------------------------------------
def _nbrs(op):
    pad = np.pad(op, 1)
    up = pad[:-2, 1:-1]
    down = pad[2:, 1:-1]
    left = pad[1:-1, :-2]
    right = pad[1:-1, 2:]
    return up, down, left, right


def outline(cv, dark=WARM, local=0.62, diag=False, skip=None):
    """Selective 1px outline drawn OUTSIDE the opaque silhouette.

    Pixels below/right of the shape get `dark` (the warm/cold outline colour); pixels above/left
    get the neighbouring material colour pulled `local` of the way toward `dark` (a dark shade of
    the local material). `diag` also closes diagonal-only corners. `skip` = bool mask of pixels
    that must stay untouched.
    """
    dark = rgba(dark)
    a = cv.a
    op = a[:, :, 3] == 255
    up, down, left, right = _nbrs(op)
    cand = ~op & (up | down | left | right)
    if diag:
        pad = np.pad(op, 1)
        dg = pad[:-2, :-2] | pad[:-2, 2:] | pad[2:, :-2] | pad[2:, 2:]
        cand |= ~op & dg
    if skip is not None:
        cand &= ~skip
    out = a.copy()
    ys, xs = np.nonzero(cand)
    for y, x in zip(ys, xs):
        if up[y, x] or left[y, x]:
            out[y, x] = dark
        elif down[y, x] or right[y, x]:
            n = a[y + 1, x] if down[y, x] else a[y, x + 1]
            out[y, x] = mix(tuple(n), dark, local)
        else:  # diagonal-only
            out[y, x] = dark
    cv.a = out
    return cv


def outline_inner(cv, dark=WARM, local=0.5, br_only=False):
    """Recolour the shape's own edge pixels (keeps the silhouette size)."""
    dark = rgba(dark)
    a = cv.a
    op = a[:, :, 3] == 255
    up, down, left, right = _nbrs(op)
    out = a.copy()
    br = op & (~down | ~right)
    tl = op & (~up | ~left) & ~br
    for y, x in zip(*np.nonzero(br)):
        out[y, x] = dark
    if not br_only:
        for y, x in zip(*np.nonzero(tl)):
            out[y, x] = mix(tuple(a[y, x]), dark, local)
    cv.a = out
    return cv


def edge_masks(op):
    """(top, bottom, left, right) edge-pixel masks of a boolean shape."""
    up, down, left, right = _nbrs(op)
    return op & ~up, op & ~down, op & ~left, op & ~right


# --------------------------------------------------------------------------------------------
# shading / noise
# --------------------------------------------------------------------------------------------
LIGHT = np.array([-0.55, -0.70, 0.62])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def sphere_shade(nx, ny, light=LIGHT):
    """Lambert term for a unit-sphere normal given its (x, y) components (arrays ok)."""
    nz = np.sqrt(np.clip(1.0 - nx * nx - ny * ny, 0.0, 1.0))
    return nx * light[0] + ny * light[1] + nz * light[2]


def quantize(v, thresholds):
    """Map values to indices: thresholds ascending; returns 0..len(thresholds)."""
    out = np.zeros(np.shape(v), dtype=int)
    for t in thresholds:
        out += (np.asarray(v) > t).astype(int)
    return out


BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.47


def value_noise(w, h, cx, cy, seed, wrap=True):
    """Smooth value noise in [0,1]; `cx`,`cy` lattice cells across the image; tileable if wrap."""
    rng = np.random.default_rng(seed)
    grid = rng.random((cy + 1, cx + 1))
    if wrap:
        grid[-1, :] = grid[0, :]
        grid[:, -1] = grid[:, 0]
    ys = (np.arange(h) + 0.5) * cy / h
    xs = (np.arange(w) + 0.5) * cx / w
    y0 = np.floor(ys).astype(int)
    x0 = np.floor(xs).astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    g00 = grid[y0][:, x0]
    g10 = grid[y0][:, x0 + 1]
    g01 = grid[y0 + 1][:, x0]
    g11 = grid[y0 + 1][:, x0 + 1]
    top = g00 * (1 - fx) + g10 * fx
    bot = g01 * (1 - fx) + g11 * fx
    return top * (1 - fy[:, None]) + bot * fy[:, None]


def dist_inside(mask):
    from scipy.ndimage import distance_transform_edt
    return distance_transform_edt(mask)


# --------------------------------------------------------------------------------------------
# text sprites (hand-placed pixels)
# --------------------------------------------------------------------------------------------
def from_text(rows, cmap, w=None, h=None, x0=0, y0=0, cv=None):
    """Draw a sprite given as strings; '.' and ' ' are transparent, other chars index `cmap`."""
    h = h or len(rows)
    w = w or max(len(r) for r in rows)
    cv = cv or Canvas(w, h)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in ". ":
                continue
            cv.px(x0 + x, y0 + y, cmap[ch])
    return cv


# --------------------------------------------------------------------------------------------
# sheets
# --------------------------------------------------------------------------------------------
def hstrip(frames):
    w = sum(f.w for f in frames)
    h = max(f.h for f in frames)
    out = Canvas(w, h)
    x = 0
    for f in frames:
        out.blit(f, x, h - f.h)
        x += f.w
    return out


def grid_sheet(frames, cols):
    fw = frames[0].w
    fh = frames[0].h
    rows = (len(frames) + cols - 1) // cols
    out = Canvas(fw * cols, fh * rows)
    for i, f in enumerate(frames):
        out.blit(f, (i % cols) * fw, (i // cols) * fh)
    return out


def rng(seed):
    return random.Random(seed)


def check_alpha(cv, name, allow_translucent=True):
    """Assert the ART_STYLE alpha rule: translucent pixels only where explicitly allowed."""
    al = cv.a[:, :, 3]
    bad = (al > 0) & (al < 255)
    if bad.any() and not allow_translucent:
        raise AssertionError(f"{name}: unexpected translucent pixels")
