"""Shared frame plumbing for the enemy sheets: canvas geometry, limbs, legs, sheet assembly.

Geometry (matches the PixelLab player / NPC frames in art/characters/):
  * 24x24 frames; the body is centred on column CX = 12;
  * GROUND = 19 is the lowest body-colour row of a standing figure, so with the 1 px cold
    outline underneath the feet the sprite's lowest opaque row is FEET_ROW = 20, the same row
    the player's boots end on (art/characters/player/walk/*/*.png).

Sheet layout (the game slices by these coordinates): 4 columns x 14 rows of 24x24 = 96x336.
  rows 0-3   idle   S, N, E, W   (2 frames, cols 2-3 transparent)
  rows 4-7   walk   S, N, E, W   (4 frames)
  rows 8-11  attack S, N, E, W   (4 frames: windup start, windup PEAK = telegraph, strike, recover)
  row  12    hurt   col 0 S, 1 N, 2 E, 3 W
  row  13    death  4 frames, direction-agnostic; frame 3 = the corpse on the ground
W frames are horizontal mirrors of E.
"""
from __future__ import annotations

from enemies import pix
from enemies.pix import Canvas, mix, rgba

FW = 24
FH = 24
CX = 12
GROUND = 19
FEET_ROW = GROUND + 1
COLS = 4
ROWS = 14
DIRS = ["S", "N", "E", "W"]


# ------------------------------------------------------------------------------------------------
# limbs
# ------------------------------------------------------------------------------------------------
def limb(cv, pts, colors, width=1, horizontal=None):
    """Polyline limb. `colors`: one colour, or a list (lit edge first, shaded edge last) for
    width 2 limbs. Width-2 limbs thicken sideways (vertical limbs) or downward (horizontal)."""
    if not isinstance(colors, (list, tuple)) or isinstance(colors[0], int):
        colors = [colors]
    path = pix.poly_points(pts)
    if horizontal is None:
        dx = abs(pts[-1][0] - pts[0][0])
        dy = abs(pts[-1][1] - pts[0][1])
        horizontal = dx > dy
    for k in range(width):
        c = colors[min(k, len(colors) - 1)]
        for (x, y) in path:
            if horizontal:
                cv.px(x, y + k, c)
            else:
                cv.px(x + k, y, c)
    return path


def layer():
    return Canvas(FW, FH)


def stamp(rows, cmap, x, y, flip=False):
    """Return a full-frame layer with the ASCII part `rows` placed with its top-left at (x, y)."""
    cv = layer()
    cv.blit(pix.part(rows, cmap, flip=flip), x, y)
    return cv


def compose(layers, contour=pix.COLD, strong=0.6, soft=0.0, outline=True, local=0.72):
    """Composite full-frame layers back to front; a layer given as (canvas, False) is blitted
    without casting a contour. Then the selective cold outline goes around the silhouette."""
    out = layer()
    for item in layers:
        if item is None:
            continue
        if isinstance(item, tuple):
            cv, cast = item
        else:
            cv, cast = item, True
        if cast:
            out.over(cv, 0, 0, contour=contour, strong=strong, soft=soft)
        else:
            out.blit(cv, 0, 0)
    if outline:
        pix.outline(out, pix.COLD, local=local)
    return out


# ------------------------------------------------------------------------------------------------
# sheet
# ------------------------------------------------------------------------------------------------
def assemble(frames):
    """frames: dict with keys ('idle'|'walk'|'attack', dir, i), ('hurt', dir), ('death', i).
    W frames missing from the dict are mirrored from E. Returns the 96x336 sheet Canvas."""
    sheet = Canvas(FW * COLS, FH * ROWS)

    def get(key):
        if key in frames:
            return frames[key]
        if key[1] == "W":
            e = (key[0], "E") + tuple(key[2:])
            return frames[e].flip_h()
        raise KeyError(key)

    for r, anim in ((0, "idle"), (4, "walk"), (8, "attack")):
        n = 2 if anim == "idle" else 4
        for d, dname in enumerate(DIRS):
            for i in range(n):
                sheet.blit(check(get((anim, dname, i)), (anim, dname, i)), i * FW, (r + d) * FH)
    for d, dname in enumerate(DIRS):
        sheet.blit(check(get(("hurt", dname)), ("hurt", dname)), d * FW, 12 * FH)
    for i in range(4):
        sheet.blit(check(frames[("death", i)], ("death", i)), i * FW, 13 * FH)
    return sheet


def check(cv, key):
    assert (cv.w, cv.h) == (FW, FH), (key, cv.w, cv.h)
    return cv


def frame_slice(sheet, row, col):
    return sheet.a[row * FH:(row + 1) * FH, col * FW:(col + 1) * FW]
