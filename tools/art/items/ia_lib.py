"""ia_lib -- a small pixel-art drawing kit for the item-icon and crop generators.

Everything is authored at native 1x resolution (docs/ART_STYLE.md section 1). A `Sprite` is a stack
of `Layer`s; every layer has a material ramp (darkest -> lightest) and a shading mode that turns
its mask into ramp indices with light from the top-left:

  inflate  dome built from the distance transform of the mask (good for organic blobs)
  sphere   analytic ellipsoid fitted to the mask's bounding box (round produce, bottles' bellies)
  cyl      cylinder along an axis (handles, bottles, cans, logs)
  flat     base colour with a 1 px lit top/left bevel and shaded bottom/right bevel
  solid    one ramp index

After compositing, an outline pass adds the selective coloured outline: the dark local colour of
the neighbouring material on top/left edges, the warm outline #281a0b on bottom/right edges.
Explicit pixels (`Sprite.put`) can be drawn before or after the outline pass.

The module is named ia_* (item art) so it cannot collide with modules of the other art
pipelines that tools/art/build_all.py loads into the same interpreter.
"""
from __future__ import annotations

import math
import pathlib

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

import palette as P

# ----------------------------------------------------------------------------------------------
# colour helpers
# ----------------------------------------------------------------------------------------------


def rgba(value, alpha: int = 255) -> tuple:
    if isinstance(value, str):
        return P.hex_to_rgba(value, alpha)
    if len(value) == 3:
        return (int(value[0]), int(value[1]), int(value[2]), alpha)
    return tuple(int(v) for v in value)


def to_hex(c) -> str:
    c = rgba(c)
    return "#%02x%02x%02x" % c[:3]


def mix(a, b, t: float) -> tuple:
    a, b = rgba(a), rgba(b)
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


WARM = rgba(P.OUTLINE_WARM)
COLD = rgba(P.OUTLINE_COLD)
CLEAR = (0, 0, 0, 0)


def _s2l(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _l2s(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055) * 255.0


def to_oklch(c):
    r, g, b = _s2l(np.array(rgba(c)[:3], float))
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l_, m_, s_ = np.cbrt(l), np.cbrt(m), np.cbrt(s)
    L = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    bb = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    return float(L), float(math.hypot(a, bb)), float(math.degrees(math.atan2(bb, a)) % 360)


def _oklab_to_lin(L, a, b):
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


def from_oklch(L, C, h) -> tuple:
    # reduce chroma until the colour fits in sRGB (keeps hue + lightness honest)
    for _ in range(40):
        a = C * math.cos(math.radians(h))
        b = C * math.sin(math.radians(h))
        lin = _oklab_to_lin(L, a, b)
        if all(-0.0005 <= v <= 1.0005 for v in lin):
            break
        C *= 0.93
    out = _l2s(np.array(lin))
    return tuple(int(round(v)) for v in out) + (255,)


def _hue_toward(h, target, amount):
    d = ((target - h + 540) % 360) - 180
    step = max(-abs(d), min(abs(d), amount)) if d >= 0 else -min(abs(d), amount)
    return (h + step) % 360


def shade(c, dl=-0.08, dc=1.0, dh=0.0):
    """Shift a colour's OKLCh lightness/chroma/hue (hue-shifting toward purple when darkening)."""
    L, C, h = to_oklch(c)
    if dh == 0.0 and C > 0.02:
        dh = 9.0 if dl < 0 else 7.0
    target = 300.0 if dl < 0 else 100.0
    h2 = _hue_toward(h, target, dh)
    return from_oklch(max(0.0, min(1.0, L + dl)), C * dc, h2)


class Ramp:
    """Material colours from darkest to lightest, plus the material's local outline colour."""

    def __init__(self, cols, outline=None, name: str = ""):
        self.cols = [rgba(c) for c in cols]
        self.name = name
        if outline is None:
            outline = mix(self.cols[0], WARM, 0.55)
        self.outline = rgba(outline)

    def __len__(self):
        return len(self.cols)

    def __getitem__(self, i):
        if i == -2:
            return self.outline
        return self.cols[max(0, min(len(self.cols) - 1, i))]

    def with_outline(self, outline):
        return Ramp(self.cols, outline, self.name)


def auto_ramp(base, n: int = 5, base_index: int | None = None, step: float = 0.085,
              hue_dark: float = 10.0, hue_light: float = 8.0, chroma_light: float = 0.86,
              chroma_dark: float = 0.97, outline=None, name: str = "") -> Ramp:
    """Hue-shifted ramp around `base` (highlights drift yellow, shadows drift purple)."""
    if base_index is None:
        base_index = n // 2
    L, C, h = to_oklch(base)
    cols = []
    for i in range(n):
        k = i - base_index
        if k == 0:
            cols.append(rgba(base))
            continue
        if k < 0:
            hh = _hue_toward(h, 295.0, hue_dark * -k)
            cc = C * (chroma_dark ** -k)
        else:
            hh = _hue_toward(h, 100.0, hue_light * k)
            cc = C * (chroma_light ** k)
        cols.append(from_oklch(max(0.04, min(0.99, L + step * k)), cc, hh))
    return Ramp(cols, outline, name)


# ----------------------------------------------------------------------------------------------
# geometry helpers
# ----------------------------------------------------------------------------------------------

LIGHT = np.array([-0.62, -0.74, 0.92])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
HALF = LIGHT + np.array([0.0, 0.0, 1.0])
HALF = HALF / np.linalg.norm(HALF)


def bresenham(x0, y0, x1, y1):
    pts = []
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    x, y = x0, y0
    while True:
        pts.append((x, y))
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x += sx
        if e2 <= dx:
            err += dx
            y += sy
    return pts


def dilate4(mask):
    out = mask.copy()
    out[1:, :] |= mask[:-1, :]
    out[:-1, :] |= mask[1:, :]
    out[:, 1:] |= mask[:, :-1]
    out[:, :-1] |= mask[:, 1:]
    return out


def shift(mask, dx, dy):
    out = np.zeros_like(mask)
    h, w = mask.shape
    ys = slice(max(0, dy), min(h, h + dy))
    yd = slice(max(0, -dy), min(h, h - dy))
    xs = slice(max(0, dx), min(w, w + dx))
    xd = slice(max(0, -dx), min(w, w - dx))
    out[ys, xs] = mask[yd, xd]
    return out


# ----------------------------------------------------------------------------------------------
# layers and sprites
# ----------------------------------------------------------------------------------------------


class Layer:
    def __init__(self, spr: "Sprite", ramp: Ramp, mode: str = "inflate", **opts):
        self.spr = spr
        self.ramp = ramp
        self.mode = mode
        self.opts = opts
        self.mask = np.zeros((spr.h, spr.w), bool)
        self.force = np.full((spr.h, spr.w), -9, np.int16)
        self.delta = np.zeros((spr.h, spr.w), np.int16)

    # -- drawing ---------------------------------------------------------------------------
    def _apply(self, m, add=True):
        if add:
            self.mask |= m
        else:
            self.mask &= ~m
            self.force[m] = -9
        return self

    def ellipse(self, cx, cy, rx, ry, add=True, fat=0.0):
        ys, xs = np.mgrid[0:self.spr.h, 0:self.spr.w]
        d = ((xs + 0.5 - cx) / rx) ** 2 + ((ys + 0.5 - cy) / ry) ** 2
        return self._apply(d <= 1.0 + fat, add)

    def rect(self, x0, y0, x1, y1, add=True):
        m = np.zeros_like(self.mask)
        m[max(0, y0):y1 + 1, max(0, x0):x1 + 1] = True
        return self._apply(m, add)

    def poly(self, pts, add=True):
        im = Image.new("L", (self.spr.w, self.spr.h), 0)
        ImageDraw.Draw(im).polygon([tuple(p) for p in pts], fill=1, outline=1)
        return self._apply(np.array(im) > 0, add)

    def line(self, x0, y0, x1, y1, brush=((0, 0),), add=True):
        m = np.zeros_like(self.mask)
        for (x, y) in bresenham(x0, y0, x1, y1):
            for (bx, by) in brush:
                if 0 <= x + bx < self.spr.w and 0 <= y + by < self.spr.h:
                    m[y + by, x + bx] = True
        return self._apply(m, add)

    def px(self, *pts, add=True):
        m = np.zeros_like(self.mask)
        for (x, y) in pts:
            if 0 <= x < self.spr.w and 0 <= y < self.spr.h:
                m[y, x] = True
        return self._apply(m, add)

    def ascii(self, rows, x0=0, y0=0, chars="#", index_chars=None, add=True):
        """Add pixels for every char in `chars`; `index_chars` maps a char to a forced ramp index
        (the pixel is added to the mask too)."""
        index_chars = index_chars or {}
        m = np.zeros_like(self.mask)
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                x, y = x0 + i, y0 + j
                if not (0 <= x < self.spr.w and 0 <= y < self.spr.h):
                    continue
                if ch in chars or ch in index_chars:
                    m[y, x] = True
                    if ch in index_chars:
                        self.force[y, x] = index_chars[ch]
        return self._apply(m, add)

    def mask_from(self, m, add=True):
        return self._apply(m.astype(bool), add)

    def set(self, pts, idx):
        """Force a ramp index on pixels (they are added to the mask)."""
        for (x, y) in pts:
            if 0 <= x < self.spr.w and 0 <= y < self.spr.h:
                self.mask[y, x] = True
                self.force[y, x] = idx
        return self

    def nudge(self, pts, d):
        """Add pixels to the mask and shift their shaded ramp index by d (texture that follows
        the lighting: stripes, ribs, pits, kernels)."""
        for (x, y) in pts:
            if 0 <= x < self.spr.w and 0 <= y < self.spr.h:
                self.mask[y, x] = True
                self.delta[y, x] = d
        return self

    def set_mask(self, m, idx):
        m = m & self.mask
        self.force[m] = idx
        return self

    # -- shading ---------------------------------------------------------------------------
    def normals(self):
        h, w = self.mask.shape
        o = self.opts
        m = self.mask
        if self.mode in ("inflate",):
            d = ndimage.distance_transform_edt(np.pad(m, 1))[1:-1, 1:-1]
            R = o.get("bevel") or max(1.0, float(d.max()))
            t = np.clip(d / R, 0, 1)
            z = np.sqrt(np.clip(1 - (1 - t) ** 2, 0, 1)) * R * o.get("height", 1.0)
            z = np.where(m, z, 0.0)
            gy, gx = np.gradient(z)
            n = np.dstack([-gx, -gy, np.ones_like(z)])
        elif self.mode == "sphere":
            ys, xs = np.nonzero(m)
            if len(xs) == 0:
                return np.zeros((h, w, 3))
            cx = o.get("cx", (xs.min() + xs.max() + 1) / 2.0)
            cy = o.get("cy", (ys.min() + ys.max() + 1) / 2.0)
            rx = o.get("rx", (xs.max() - xs.min() + 1) / 2.0)
            ry = o.get("ry", (ys.max() - ys.min() + 1) / 2.0)
            Y, X = np.mgrid[0:h, 0:w]
            nx = (X + 0.5 - cx) / rx
            ny = (Y + 0.5 - cy) / ry
            r2 = np.clip(nx * nx + ny * ny, 0, 0.98)
            n = np.dstack([nx, ny, np.sqrt(1 - r2)])
        elif self.mode == "cyl":
            ang = math.radians(o.get("axis", 90.0))
            ax, ay = math.cos(ang), -math.sin(ang)   # axis direction (y down)
            px_, py_ = -ay, ax                       # perpendicular
            if px_ + py_ < 0:
                px_, py_ = -px_, -py_                # perpendicular points down/right
            ys, xs = np.nonzero(m)
            if len(xs) == 0:
                return np.zeros((h, w, 3))
            Y, X = np.mgrid[0:h, 0:w]
            s = (X + 0.5) * px_ + (Y + 0.5) * py_
            sv = s[m]
            c = o.get("center", (sv.min() + sv.max()) / 2.0)
            hw = o.get("halfwidth", max(0.5, (sv.max() - sv.min()) / 2.0 + 0.5))
            t = np.clip((s - c) / hw, -0.97, 0.97)
            n = np.dstack([t * px_, t * py_, np.sqrt(1 - t * t)])
        else:
            n = np.dstack([np.zeros((h, w)), np.zeros((h, w)), np.ones((h, w))])
        norm = np.linalg.norm(n, axis=2, keepdims=True)
        return n / np.maximum(norm, 1e-6)

    def indices(self):
        """Ramp index per pixel (-9 outside the mask)."""
        o = self.opts
        n_cols = len(self.ramp)
        base = o.get("base", (n_cols - 1) // 2 if n_cols > 3 else 1)
        if self.mode == "solid":
            idx = np.full(self.mask.shape, o.get("index", base), np.int16)
        elif self.mode == "flat":
            m = self.mask
            idx = np.full(m.shape, base, np.int16)
            up = ~shift(m, 0, 1) & m
            left = ~shift(m, 1, 0) & m
            down = ~shift(m, 0, -1) & m
            right = ~shift(m, -1, 0) & m
            lit = o.get("lit", base + 1)
            dark = o.get("dark", base - 1)
            if o.get("bevel_light", True):
                idx[up | left] = lit
            if o.get("bevel_dark", True):
                idx[down | right] = dark
                idx[(up | left) & (down | right)] = base
        else:
            n = self.normals()
            v = n @ LIGHT
            vflat = LIGHT[2]
            k = o.get("contrast", 2.6)
            f = base + (v - vflat) * k + o.get("bias", 0.0)
            idx = np.floor(f + 0.5).astype(np.int16)
            if o.get("gloss"):
                spec = np.clip(n @ HALF, 0, 1) ** o.get("shine", 18)
                idx[(spec > o.get("gloss_cut", 0.62)) & self.mask] = n_cols - 1
            lo = o.get("min", 0)
            hi = o.get("max", n_cols - 1)
            idx = np.clip(idx, lo, hi)
        idx = np.clip(idx + self.delta, 0, n_cols - 1)
        idx = np.where(self.force != -9, self.force, idx)
        if o.get("clean", False):
            idx = _clean(idx, self.mask)
        return np.where(self.mask, idx, -9).astype(np.int16)


def _clean(idx, mask):
    """Remove isolated single pixels of a shade (replace by the most common neighbour)."""
    out = idx.copy()
    h, w = idx.shape
    for y in range(h):
        for x in range(w):
            if not mask[y, x]:
                continue
            nb = []
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and mask[yy, xx]:
                    nb.append(idx[yy, xx])
            if len(nb) >= 3 and idx[y, x] not in nb:
                vals, counts = np.unique(nb, return_counts=True)
                out[y, x] = vals[np.argmax(counts)]
    return out


class Sprite:
    def __init__(self, w: int = 16, h: int = 16):
        self.w, self.h = w, h
        self.layers: list[Layer] = []
        self.pre: list = []    # explicit pixels before the outline pass: (x, y, colour, ramp)
        self.post: list = []   # explicit pixels after the outline pass

    def layer(self, ramp: Ramp, mode: str = "inflate", **opts) -> Layer:
        lay = Layer(self, ramp, mode, **opts)
        self.layers.append(lay)
        return lay

    def put(self, x, y, colour, ramp: Ramp | None = None, after: bool = False):
        (self.post if after else self.pre).append((x, y, rgba(colour), ramp))
        return self

    def puts(self, pts, colour, ramp=None, after=False):
        for (x, y) in pts:
            self.put(x, y, colour, ramp, after)
        return self

    def ascii_put(self, rows, legend, x0=0, y0=0, after=False):
        """Explicit colours from a char map; legend maps char -> colour (or (colour, ramp))."""
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in legend:
                    val = legend[ch]
                    if isinstance(val, tuple) and len(val) == 2 and isinstance(val[1], Ramp):
                        self.put(x0 + i, y0 + j, val[0], val[1], after)
                    else:
                        self.put(x0 + i, y0 + j, val, None, after)
        return self

    # -- render ----------------------------------------------------------------------------
    def render(self, outline: str = "outer", outline_color=None, warm=None,
               shadow: dict | None = None) -> np.ndarray:
        h, w = self.h, self.w
        owner = np.full((h, w), -1, np.int16)
        idxmap = np.full((h, w), -9, np.int16)
        for li, lay in enumerate(self.layers):
            idx = lay.indices()
            m = lay.mask
            if lay.opts.get("cast"):
                d = lay.opts["cast"] if isinstance(lay.opts["cast"], tuple) else (1, 1)
                sh = shift(m, d[0], d[1]) & ~m & (owner >= 0) & (idxmap >= 0)
                idxmap[sh] = np.maximum(0, idxmap[sh] - 1)
            sep = lay.opts.get("sep")
            if sep:
                if sep == "inner":
                    lower = owner >= 0
                    ring = m & dilate4(lower & ~m)
                    idx = np.where(ring, -2, idx)
                else:
                    ring = dilate4(m) & ~m & (owner >= 0)
                    owner[ring] = li
                    idxmap[ring] = lay.opts.get("sep_idx", -2)
            owner[m] = li
            idxmap[m] = idx[m]
        img = np.zeros((h, w, 4), np.uint8)
        outl = np.zeros((h, w, 4), np.uint8)  # local outline colour per opaque pixel
        for li, lay in enumerate(self.layers):
            sel = owner == li
            if not sel.any():
                continue
            ys, xs = np.nonzero(sel)
            for y, x in zip(ys, xs):
                img[y, x] = lay.ramp[int(idxmap[y, x])]
                outl[y, x] = lay.ramp.outline
        for (x, y, c, ramp) in self.pre:
            if 0 <= x < w and 0 <= y < h:
                img[y, x] = c
                outl[y, x] = ramp.outline if ramp else mix(c, WARM, 0.6)
        if outline:
            img = apply_outline(img, outl, mode=outline, local=outline_color, warm=warm)
        for (x, y, c, ramp) in self.post:
            if 0 <= x < w and 0 <= y < h:
                img[y, x] = c
        if shadow:
            img = add_shadow(img, **shadow)
        return img

    def image(self, **kw) -> Image.Image:
        return Image.fromarray(self.render(**kw), "RGBA")


def apply_outline(img, outl, mode="outer", local=None, warm=None):
    h, w = img.shape[:2]
    A = img[:, :, 3] > 0
    warm = rgba(warm) if warm is not None else WARM
    out = img.copy()
    if mode == "outer":
        ring = dilate4(A) & ~A
        for y, x in zip(*np.nonzero(ring)):
            up = y > 0 and A[y - 1, x]
            left = x > 0 and A[y, x - 1]
            down = y < h - 1 and A[y + 1, x]
            right = x < w - 1 and A[y, x + 1]
            if up or left:
                out[y, x] = warm
            else:
                sy, sx = (y + 1, x) if down else (y, x + 1)
                out[y, x] = rgba(local) if local is not None else outl[sy, sx]
    else:  # inner: recolour boundary pixels
        edge = A & ~(shift(A, 0, 1) & shift(A, 0, -1) & shift(A, 1, 0) & shift(A, -1, 0))
        for y, x in zip(*np.nonzero(edge)):
            down = y == h - 1 or not A[y + 1, x]
            right = x == w - 1 or not A[y, x + 1]
            if down or right:
                out[y, x] = warm
            else:
                out[y, x] = rgba(local) if local is not None else outl[y, x]
    return out


def add_shadow(img, cx, cy, rx, ry, alpha=90, color=None):
    """Soft contact shadow ellipse under (behind) the sprite."""
    h, w = img.shape[:2]
    c = rgba(color or P.OUTLINE_WARM)
    Y, X = np.mgrid[0:h, 0:w]
    d = ((X + 0.5 - cx) / rx) ** 2 + ((Y + 0.5 - cy) / ry) ** 2
    m = (d <= 1.0) & (img[:, :, 3] == 0)
    out = img.copy()
    out[m] = (c[0], c[1], c[2], alpha)
    return out


# ----------------------------------------------------------------------------------------------
# image utilities
# ----------------------------------------------------------------------------------------------


def compose(*imgs) -> np.ndarray:
    """Alpha-over a list of equally sized RGBA arrays (later on top); binary alpha is kept."""
    base = Image.fromarray(imgs[0], "RGBA")
    for im in imgs[1:]:
        base.alpha_composite(Image.fromarray(im, "RGBA"))
    return np.array(base)


def offset(img, dx, dy, w=None, h=None):
    h0, w0 = img.shape[:2]
    w = w or w0
    h = h or h0
    out = np.zeros((h, w, 4), np.uint8)
    for y in range(h0):
        for x in range(w0):
            if img[y, x, 3] and 0 <= x + dx < w and 0 <= y + dy < h:
                out[y + dy, x + dx] = img[y, x]
    return out


def flip_x(img):
    return img[:, ::-1].copy()


def recolor(img, mapping: dict) -> np.ndarray:
    """Exact-colour substitution (hex -> hex)."""
    out = img.copy()
    for src, dst in mapping.items():
        s = rgba(src)
        d = rgba(dst)
        m = (img[:, :, 0] == s[0]) & (img[:, :, 1] == s[1]) & (img[:, :, 2] == s[2]) & (img[:, :, 3] > 0)
        out[m, 0:3] = d[:3]
    return out


def save(img, path):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    arr = np.asarray(img).astype(np.uint8)
    Image.fromarray(arr, "RGBA").save(path, optimize=False)


def check_icon(img, name=""):
    """Sanity check: 16x16 with an empty 1 px frame (warn only)."""
    a = img[:, :, 3] > 0
    issues = []
    if a[0].any() or a[-1].any() or a[:, 0].any() or a[:, -1].any():
        issues.append("touches edge")
    if not a.any():
        issues.append("empty")
    return issues


def paint(layers: dict, rows, legend: dict, x0: int = 0, y0: int = 0):
    """Paint an ASCII map into layers. legend: char -> layer_key or (layer_key, forced_index)."""
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch not in legend:
                continue
            val = legend[ch]
            key, idx = (val, None) if not isinstance(val, tuple) else val
            lay = layers[key]
            if idx is None:
                lay.px((x0 + i, y0 + j))
            else:
                lay.set([(x0 + i, y0 + j)], idx)


def grid(rows):
    """Normalise an ASCII block (strip a leading newline / common indentation)."""
    if isinstance(rows, str):
        rows = [r for r in rows.split("\n")]
        while rows and not rows[0].strip():
            rows.pop(0)
        while rows and not rows[-1].strip():
            rows.pop()
        ind = min(len(r) - len(r.lstrip()) for r in rows if r.strip())
        rows = [r[ind:] for r in rows]
    return rows


def icon(rows, layers, legend=None, w=16, h=16, outline="outer", x0=0, y0=0, sprite=None, render=True,
         **render_kw):
    """Build a sprite from one ASCII map.

    layers: ordered dict key -> (Ramp, mode, {opts}) -- drawn bottom to top.
    legend: char -> layer key | (layer key, forced ramp index) | ("put", colour) | ("after", colour)
            | ("nudge", layer key, delta)  (pixel joins the layer, shaded index shifted by delta)
            Chars equal to a layer key map to that layer automatically.
    """
    s = sprite or Sprite(w, h)
    lays = {}
    for key, spec in layers.items():
        ramp, mode = spec[0], spec[1]
        opts = spec[2] if len(spec) > 2 else {}
        lays[key] = s.layer(ramp, mode, **opts)
    legend = dict(legend or {})
    for key in layers:
        legend.setdefault(key, key)
    rows = grid(rows)
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch not in legend:
                continue
            val = legend[ch]
            x, y = x0 + i, y0 + j
            if isinstance(val, tuple) and val[0] in ("put", "after"):
                s.put(x, y, val[1], val[2] if len(val) > 2 else None, after=(val[0] == "after"))
            elif isinstance(val, tuple) and val[0] == "nudge":
                lays[val[1]].nudge([(x, y)], val[2])
            elif isinstance(val, tuple):
                lays[val[0]].set([(x, y)], val[1])
            else:
                lays[val].px((x, y))
    if not render:
        return s, lays
    return s.render(outline=outline, **render_kw)
