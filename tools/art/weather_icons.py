"""HUD weather icons (art/ui/weather_<kind>.png, 16x16) for the day sign: clear, rain, storm, snow
and radstorm. Pixel-drawn from tools/art/palette.py so they sit with the rest of the UI.

Run: python3 tools/art/weather_icons.py
"""
from __future__ import annotations

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import palette as P  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "ui")


def _hex(c: str, a: int = 255) -> tuple:
    c = c.lstrip("#")
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


OUTLINE = _hex("#281a0b")
SUN = [_hex("#c47a20"), _hex("#ffb72d"), _hex("#ffd86a"), _hex("#fff2b8")]
CLOUD = [_hex("#5d6670"), _hex("#8c97a3"), _hex("#c3ccd4"), _hex("#eef2f4")]
DARK_CLOUD = [_hex("#3a3f4a"), _hex("#555c69"), _hex("#7a8290"), _hex("#9aa2ae")]
RAD = [_hex("#2f4a1c"), _hex("#4f7a24"), _hex("#7fbf2e"), _hex("#c6f25a")]
RAIN = _hex(P.WATER_RAMP[4])
BOLT = _hex("#ffe066")


def _canvas() -> Image.Image:
    return Image.new("RGBA", (16, 16), (0, 0, 0, 0))


def _disc(px, cx, cy, r, ramp):
    for y in range(16):
        for x in range(16):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= r:
                shade = 3 if (x - cx) + (y - cy) < -r * 0.6 else (2 if (x - cx) + (y - cy) < r * 0.2 else 1)
                px[x, y] = ramp[shade]


def _outline(im: Image.Image) -> None:
    px = im.load()
    solid = {(x, y) for y in range(16) for x in range(16) if px[x, y][3] > 0}
    for x, y in [(x, y) for y in range(16) for x in range(16)]:
        if (x, y) in solid:
            continue
        if any((x + dx, y + dy) in solid for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            px[x, y] = OUTLINE


def _cloud(px, ramp, ox=0, oy=0):
    for cx, cy, r in ((5, 8, 3.2), (9, 6, 4.0), (12, 9, 2.6)):
        _disc(px, cx + ox, cy + oy, r, ramp)
    for y in range(9 + oy, 12 + oy):
        for x in range(4 + ox, 14 + ox):
            if 0 <= x < 16 and 0 <= y < 16:
                px[x, y] = ramp[1] if y == 11 + oy else ramp[2]


def clear() -> Image.Image:
    im = _canvas()
    px = im.load()
    for x, y in ((8, 1), (8, 14), (1, 8), (14, 8), (3, 3), (12, 3), (3, 12), (12, 12)):
        px[x, y] = SUN[1]
    _disc(px, 8, 8, 4.3, SUN)
    _outline(im)
    return im


def clear_night() -> Image.Image:
    """A crescent moon with two stars (clear weather after dark)."""
    im = _canvas()
    px = im.load()
    moon = [_hex("#8f8a6e"), _hex("#c9c29a"), _hex("#ece4bd"), _hex("#fff8dc")]
    for y in range(16):
        for x in range(16):
            outer = ((x - 7) ** 2 + (y - 8) ** 2) ** 0.5 <= 5.2
            inner = ((x - 9.6) ** 2 + (y - 6.4) ** 2) ** 0.5 <= 4.6
            if outer and not inner:
                d = x - 7 + y - 8
                px[x, y] = moon[3] if d < -3 else (moon[2] if d < 1 else moon[1])
    _outline(im)
    px[13, 3] = moon[3]
    px[12, 12] = moon[2]
    return im


def rain() -> Image.Image:
    im = _canvas()
    px = im.load()
    _cloud(px, CLOUD, 0, -2)
    _outline(im)
    for x, y in ((5, 12), (8, 13), (11, 12), (6, 14), (10, 15)):
        px[x, y] = RAIN
    return im


def storm() -> Image.Image:
    im = _canvas()
    px = im.load()
    _cloud(px, DARK_CLOUD, 0, -2)
    _outline(im)
    for x, y in ((9, 10), (8, 11), (7, 12), (8, 12), (9, 12), (8, 13), (7, 14)):
        px[x, y] = BOLT
    px[4, 12] = RAIN
    px[12, 13] = RAIN
    return im


def snow() -> Image.Image:
    im = _canvas()
    px = im.load()
    flake = _hex("#eef6fb")
    for i in range(-5, 6):
        px[8 + i, 8] = flake
        px[8, 8 + i] = flake
        if abs(i) <= 3:
            px[8 + i, 8 + i] = flake
            px[8 + i, 8 - i] = flake
    for x, y in ((8, 3), (8, 13), (3, 8), (13, 8)):
        px[x, y] = CLOUD[2]
    _outline(im)
    return im


def radstorm() -> Image.Image:
    im = _canvas()
    px = im.load()
    _cloud(px, RAD, 0, -2)
    _outline(im)
    # Trefoil hint on the cloud and green drizzle.
    for x, y in ((8, 6), (7, 7), (9, 7), (8, 8)):
        px[x, y] = OUTLINE
    for x, y in ((5, 12), (8, 13), (11, 12), (6, 14), (10, 15)):
        px[x, y] = RAD[3]
    return im


def build() -> None:
    os.makedirs(OUT, exist_ok=True)
    for name, fn in (("clear", clear), ("clear_night", clear_night), ("rain", rain), ("storm", storm), ("snow", snow),
                     ("radstorm", radstorm)):
        path = os.path.join(OUT, "weather_%s.png" % name)
        fn().save(path)
        print("wrote", path)


if __name__ == "__main__":
    build()
