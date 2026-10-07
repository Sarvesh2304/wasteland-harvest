"""The "ready" bubble a finished machine floats above itself (art/ui/ready_bubble.png, 20x22):
a cream thought bubble with a warm outline and a tail pointing down at the machine. The product's
own 16x16 item icon is drawn inside it at (2, 2) by world_objects.gd. Pixel-drawn from
tools/art/palette.py.

Run: python3 tools/art/ready_bubble.py
"""
from __future__ import annotations

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import palette as P  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "ui", "ready_bubble.png")

W, H = 20, 22
BOX = 20  # the square part; the tail hangs below it
OUTLINE = P.hex_to_rgba(P.OUTLINE_WARM)
FILL = P.hex_to_rgba(P.CREAM)
SHADE = P.hex_to_rgba(P.DIRT_RAMP[5])  # the bubble's lower inner edge


def build() -> Image.Image:
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = im.load()
    # Body: a rounded square (corner pixels cut, 1px outline).
    for y in range(BOX):
        for x in range(W):
            corner = (x in (0, W - 1)) and (y in (0, BOX - 1))
            if corner:
                continue
            edge = x in (0, W - 1) or y in (0, BOX - 1)
            near_corner = (x in (1, W - 2)) and (y in (1, BOX - 2))
            if edge or near_corner:
                px[x, y] = OUTLINE
            else:
                px[x, y] = SHADE if y == BOX - 2 else FILL
    # Re-round: the corner-adjacent edge pixels become transparent so the outline steps inward.
    for x, y in ((1, 0), (0, 1), (W - 2, 0), (W - 1, 1), (1, BOX - 1), (0, BOX - 2),
                 (W - 2, BOX - 1), (W - 1, BOX - 2)):
        px[x, y] = (0, 0, 0, 0)
    # Tail: opens the bottom edge and narrows to a point.
    mid = W // 2
    for x in range(mid - 2, mid + 2):
        px[x, BOX - 1] = SHADE
    px[mid - 3, BOX - 1] = OUTLINE
    px[mid + 2, BOX - 1] = OUTLINE
    px[mid - 2, BOX] = OUTLINE
    px[mid - 1, BOX] = SHADE
    px[mid, BOX] = SHADE
    px[mid + 1, BOX] = OUTLINE
    px[mid - 1, BOX + 1] = OUTLINE
    px[mid, BOX + 1] = OUTLINE
    return im


def main() -> None:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    build().save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
