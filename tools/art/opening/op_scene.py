"""Scene-painting helpers for the opening's illustrated pages (Milestone E).

Every page is a 256x112 opaque postcard: a dithered sky, a far horizon (ruined-city skyline,
hills), a ground plane, and the game's OWN sprites (buildings, props, trees, townsfolk, the
player) pasted onto it bottom-anchored with contact shadows — so the intro reads as the same
world the player is about to walk around in, at exactly 1 game pixel = 1 art pixel.

Plain numpy RGBA arrays (h, w, 4) throughout; colours are '#rrggbb' strings from palette.py.
Everything is deterministic (hash-based noise, fixed seeds).
"""
from __future__ import annotations

import pathlib

import numpy as np
from PIL import Image

import palette as P

REPO = pathlib.Path(__file__).resolve().parents[3]
W, H = 256, 112
BAYER = np.array([[0, 2], [3, 1]]) / 4.0 + 0.125


def rgb(c) -> np.ndarray:
    v = P.hex_to_rgba(c) if isinstance(c, str) else tuple(c)
    return np.array(v[:3], dtype=np.float64)


def canvas(color=P.OUTLINE_WARM) -> np.ndarray:
    a = np.zeros((H, W, 4), np.uint8)
    a[:, :, :3] = rgb(color).astype(np.uint8)
    a[:, :, 3] = 255
    return a


def load(rel: str) -> np.ndarray:
    return np.array(Image.open(REPO / rel).convert("RGBA"))


def hash01(x: int, y: int, seed: int = 0) -> float:
    h = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def mix(a, b, t: float) -> np.ndarray:
    return rgb(a) * (1.0 - t) + rgb(b) * t


# -- sky ------------------------------------------------------------------------------------------

def sky(img, ramp, horizon: int) -> None:
    """Bands top -> horizon, each boundary softened by a 2x2 ordered dither over ~4 rows."""
    n = len(ramp)
    for y in range(horizon):
        pos = y / max(horizon - 1, 1) * (n - 1)
        i = min(int(pos), n - 2)
        frac = pos - i
        for x in range(W):
            # dither only near the band boundary: frac in [0.5, 1) blends toward the next band
            t = 0.0
            if frac > 0.55:
                t = (frac - 0.55) / 0.45
            use_next = t > BAYER[y % 2, x % 2]
            img[y, x, :3] = rgb(ramp[i + 1] if use_next else ramp[i]).astype(np.uint8)


def stars(img, horizon: int, seed: int, count: int, color=P.STAR) -> None:
    placed = 0
    k = 0
    while placed < count and k < count * 20:
        k += 1
        x = int(hash01(k, 1, seed) * W)
        y = int(hash01(k, 2, seed) * (horizon - 8))
        if y < 1:
            continue
        bright = hash01(k, 3, seed)
        c = rgb(color) if bright > 0.6 else mix(color, img[y, x, :3], 0.45)
        img[y, x, :3] = c.astype(np.uint8)
        if bright > 0.93 and 1 <= x < W - 1:     # a few twinkle crosses
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                img[y + dy, x + dx, :3] = mix(color, img[y + dy, x + dx, :3], 0.6).astype(np.uint8)
        placed += 1


def disc(img, cx, cy, r, ramp) -> None:
    """A lit disc (sun / moon): light from the top-left, ramp [shade, base, light]."""
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if not (0 <= x < W and 0 <= y < H):
                continue
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= r:
                lit = ((x - cx) + (y - cy)) / max(r, 1)
                c = ramp[2] if lit < -0.5 else (ramp[1] if lit < 0.6 else ramp[0])
                img[y, x, :3] = rgb(c).astype(np.uint8)


def halo(img, cx, cy, r, color, strength=0.5, y_max=None) -> None:
    """Soft glow blended toward `color` (sun haze, lamplight on snow)."""
    c = rgb(color)
    for y in range(max(0, int(cy - r)), min(H, int(cy + r + 1))):
        if y_max is not None and y > y_max:
            continue
        for x in range(max(0, int(cx - r)), min(W, int(cx + r + 1))):
            d = ((x - cx) ** 2 + ((y - cy) * 1.3) ** 2) ** 0.5 / r
            if d < 1.0:
                t = strength * (1.0 - d) ** 2
                # quantise the falloff into steps, ordered-dithered between them, so it stays
                # pixel art (no airbrush) without a hard ring at any step edge
                steps = 6.0
                lo = int(t * steps)
                t = (lo + (1 if (t * steps - lo) > BAYER[y % 2, x % 2] else 0)) / steps
                if t > 0:
                    img[y, x, :3] = (img[y, x, :3] * (1 - t) + c * t).astype(np.uint8)


# -- far horizon ----------------------------------------------------------------------------------

def skyline(img, base_y: int, x0: int, x1: int, seed: int, color, window=None, max_h=31) -> None:
    """Ruined-city silhouette: broken towers with notched tops and the odd bare girder."""
    x = x0
    k = 0
    while x < x1:
        k += 1
        w = 5 + int(hash01(k, 1, seed) * 12)
        h = 5 + int(hash01(k, 2, seed) ** 1.6 * (max_h - 5))
        top = base_y - h
        for xx in range(x, min(x + w, x1)):
            notch = 0
            r = hash01(xx, k, seed + 7)
            if r > 0.78:
                notch = 1 + int(hash01(xx, 3, seed) * 4)        # broken top
            for y in range(top + notch, base_y):
                if 0 <= y < H:
                    img[y, xx, :3] = rgb(color).astype(np.uint8)
        if hash01(k, 4, seed) > 0.75:                          # a bare girder / antenna
            gx = x + int(w / 2)
            for y in range(top - 4, top):
                if 0 <= y < H and gx < W:
                    img[y, gx, :3] = rgb(color).astype(np.uint8)
        if window is not None:                                 # empty window holes
            for wy in range(top + 3, base_y - 2, 3):
                for wx in range(x + 1, min(x + w - 1, x1), 3):
                    if hash01(wx, wy, seed + 11) > 0.72 and 0 <= wy < H:
                        img[wy, wx, :3] = rgb(window).astype(np.uint8)
        x += w + int(hash01(k, 5, seed) * 6)


def ridge(img, base_y: int, amp: float, seed: int, color, period=40.0) -> None:
    """A rolling hill line from base_y down to the bottom of the picture."""
    for x in range(W):
        h = amp * (0.6 * np.sin((x + seed * 13) / period) + 0.4 * np.sin((x + seed * 7) / (period * 0.37)))
        top = int(base_y - abs(h))
        img[top:, x, :3] = rgb(color).astype(np.uint8)


# -- ground ---------------------------------------------------------------------------------------

def ground(img, y0: int, ramp, seed: int, density=0.08) -> None:
    """Ground plane below y0: base colour, a darker rim at the horizon, and short horizontal
    texture strokes (2-3 px clusters, never single noise pixels) in the ramp's other shades.
    `ramp` = [dark, base, light]."""
    img[y0:, :, :3] = rgb(ramp[1]).astype(np.uint8)
    img[y0, :, :3] = rgb(ramp[0]).astype(np.uint8)
    for y in range(y0 + 2, H):
        # strokes get longer toward the viewer (cheap perspective)
        length = 2 + (y - y0) // 22
        for x in range(0, W, 3):
            r = hash01(x, y, seed)
            if r < density:
                c = ramp[0] if hash01(x, y, seed + 1) < 0.55 else ramp[2]
                for i in range(length):
                    if x + i < W:
                        img[y, x + i, :3] = rgb(c).astype(np.uint8)


def path(img, pts, width_far: int, width_near: int, ramp, y0: int, seed: int) -> None:
    """A dirt track through the ground, from far (first point) to near (last)."""
    for y in range(y0 + 1, H):
        t = (y - y0) / max(H - y0, 1)
        # interpolate centre x along the polyline by y
        cx = None
        for (xa, ya), (xb, yb) in zip(pts, pts[1:]):
            if ya <= y <= yb:
                cx = xa + (xb - xa) * (y - ya) / max(yb - ya, 1)
        if cx is None:
            continue
        half = (width_far + (width_near - width_far) * t) / 2
        for x in range(int(cx - half), int(cx + half) + 1):
            if 0 <= x < W:
                edge = abs(x - cx) > half - 1
                c = ramp[0] if edge else (ramp[2] if hash01(x, y, seed) < 0.06 else ramp[1])
                img[y, x, :3] = rgb(c).astype(np.uint8)


# -- sprites --------------------------------------------------------------------------------------

def paste(img, spr, x: int, bottom: int, shadow=True, shadow_alpha=0.35) -> None:
    """Alpha-paste `spr` with its bottom-left at (x, bottom) (bottom = first row BELOW it),
    casting a contact shadow on the ground first (docs/ART_STYLE.md §2)."""
    rows = np.nonzero(spr[:, :, 3].max(axis=1) > 0)[0]
    if rows.size:                      # anchor on the lowest opaque row, not the canvas edge
        spr = spr[:rows.max() + 1]
    sh, sw = spr.shape[:2]
    top = bottom - sh
    if shadow:
        cols = np.nonzero(spr[-3:, :, 3].max(axis=0) > 0)[0]
        if cols.size:
            cx = x + (cols.min() + cols.max()) / 2.0 + 1
            rx = (cols.max() - cols.min()) / 2.0 + 1
            ellipse(img, cx, bottom - 1, rx, 1.5, P.OUTLINE_WARM, shadow_alpha)
    for yy in range(sh):
        ty = top + yy
        if not 0 <= ty < H:
            continue
        for xx in range(sw):
            tx = x + xx
            if not 0 <= tx < W:
                continue
            a = spr[yy, xx, 3] / 255.0
            if a <= 0:
                continue
            img[ty, tx, :3] = (img[ty, tx, :3] * (1 - a) + spr[yy, xx, :3] * a).astype(np.uint8)


def ellipse(img, cx, cy, rx, ry, color, alpha) -> None:
    c = rgb(color)
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if 0 <= x < W and 0 <= y < H and ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 <= 1:
                img[y, x, :3] = (img[y, x, :3] * (1 - alpha) + c * alpha).astype(np.uint8)


def crop(spr, x, y, w, h) -> np.ndarray:
    return spr[y:y + h, x:x + w].copy()


def flip(spr) -> np.ndarray:
    return spr[:, ::-1].copy()


def tint(spr, color, amount: float, keep_lights=True) -> np.ndarray:
    """Pulls a sprite toward `color` (dusk, night, haze). Lamplight pixels (bright warm yellow)
    stay lit when keep_lights is set, so windows glow at night."""
    out = spr.copy()
    c = rgb(color)
    px = out[:, :, :3].astype(np.float64)
    lit = (px[:, :, 0] > 200) & (px[:, :, 1] > 140) & (px[:, :, 2] < 170) & (px[:, :, 0] > px[:, :, 2] + 70)
    blended = px * (1 - amount) + c * amount
    if keep_lights:
        blended[lit] = px[lit]
    out[:, :, :3] = blended.astype(np.uint8)
    return out


def tint_region(img, y0, y1, color, amount) -> None:
    c = rgb(color)
    img[y0:y1, :, :3] = (img[y0:y1, :, :3] * (1 - amount) + c * amount).astype(np.uint8)


def fence_run(sheet, tiles: int, mask_ends=True) -> np.ndarray:
    """A horizontal fence run `tiles` long from a 64x128 fence sheet (mask N1 E2 S4 W8)."""
    def frame(mask):
        return crop(sheet, (mask % 4) * 16, (mask // 4) * 32, 16, 32)
    out = np.zeros((32, tiles * 16, 4), np.uint8)
    for i in range(tiles):
        m = 2 | 8
        if mask_ends and i == 0:
            m = 2
        if mask_ends and i == tiles - 1:
            m = 8
        if tiles == 1:
            m = 0
        f = frame(m)
        a = f[:, :, 3:4] / 255.0
        region = out[:, i * 16:(i + 1) * 16]
        region[:, :, :3] = (region[:, :, :3] * (1 - a) + f[:, :, :3] * a).astype(np.uint8)
        region[:, :, 3] = np.maximum(region[:, :, 3], f[:, :, 3])
    return out


# -- people ---------------------------------------------------------------------------------------

def luminance(c) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def map_color(src, from_ramp, to_ramp):
    """Python twin of scripts/player_look.gd's map_color (luminance position on the source
    ramp, read off the target ramp)."""
    f = [rgb(c) for c in from_ramp]
    t = [rgb(c) for c in to_ramp]
    y = luminance(src)
    y0, y1, y2 = (luminance(c) for c in f)
    if y <= y1:
        k = (y - y0) / max(y1 - y0, 0.5)
        out = t[0] * (1 - k) + t[1] * k if k >= 0 else t[0] * (1 - min(-k * 0.35, 0.6))
    else:
        k = (y - y1) / max(y2 - y1, 0.5)
        out = t[1] * (1 - k) + t[2] * k if k <= 1 else t[2] + (255 - t[2]) * min((k - 1) * 0.3, 0.5)
    return np.clip(out, 0, 255)


def person(action="idle", facing="south", frame=0, hair="chestnut", skin="peach",
           outfit="duster_tan", long_hair=False) -> np.ndarray:
    """A player-sprite frame recoloured as someone else (the parents)."""
    rel = f"art/characters/player/{action}/{facing}/{frame}.png"
    spr = load(rel)
    mask = load(f"art/characters/player/regions/{action}/{facing}/{frame}.png")
    ramps = {
        (255, 0, 0): (P.PLAYER_HAIR_RAMPS["chestnut"], P.PLAYER_HAIR_RAMPS[hair]),
        (0, 255, 0): (P.PLAYER_SKIN_RAMPS["peach"], P.PLAYER_SKIN_RAMPS[skin]),
        (0, 0, 255): (P.PLAYER_OUTFIT_RAMPS["duster_tan"], P.PLAYER_OUTFIT_RAMPS[outfit]),
    }
    out = spr.copy()
    hair_px = []
    for y in range(spr.shape[0]):
        for x in range(spr.shape[1]):
            if mask[y, x, 3] == 0 or spr[y, x, 3] == 0:
                continue
            key = tuple(int(v) for v in mask[y, x, :3])
            if key in ramps:
                fr, to = ramps[key]
                out[y, x, :3] = map_color(spr[y, x, :3].astype(np.float64), fr, to).astype(np.uint8)
                if key == (255, 0, 0):
                    hair_px.append((y, x))
    if long_hair and hair_px:
        # Shoulder-length hair: extend the outermost hair columns 4 rows down the sides/back.
        ramp = P.PLAYER_HAIR_RAMPS[hair]
        bottom = max(y for y, _ in hair_px)
        xs = [x for _, x in hair_px]
        left, right = min(xs), max(xs)
        back = facing == "north"
        cols = range(left, right + 1) if back else [left, right]
        for x in cols:
            col_ys = [y for y, xx in hair_px if xx == x]
            if not col_ys:
                continue
            start = max(col_ys) + 1
            for y in range(start, min(bottom + 5, spr.shape[0])):
                out[y, x, :3] = rgb(ramp[0] if (x == left or x == right or y == bottom + 4) else ramp[1]).astype(np.uint8)
                out[y, x, 3] = 255
    return out


def shrink_child(spr) -> np.ndarray:
    """A child from an adult frame: keep the head, drop every other body row (shorter torso and
    legs), keep the feet. Bottom-aligned in the same canvas."""
    rows = [y for y in range(spr.shape[0]) if spr[y, :, 3].any()]
    if not rows:
        return spr
    top, bottom = rows[0], rows[-1]
    head_end = top + 7
    keep = list(range(top, head_end))
    body = list(range(head_end, bottom - 1))
    keep += body[::2] + [bottom - 1, bottom]
    out = np.zeros_like(spr)
    stacked = spr[keep]
    out[bottom + 1 - len(keep):bottom + 1] = stacked
    return out
