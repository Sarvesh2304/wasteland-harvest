"""Shared helpers for the living-settlement art: canvas, ASCII stamping, outlines, shadows.

Built on enemies.pix (Canvas, part, outline) so the conventions match the townsfolk kit: light
from the top-left, alpha 0 / 255 except deliberate glows and contact shadows, 1 px selective
outline (warm #281a0b below / right on settlement things, cold #181a16 on ruins things).
"""
from __future__ import annotations

import numpy as np

import palette as P
from enemies import pix
from enemies.pix import Canvas, rgba, mix

WARM = pix.WARM
COLD = pix.COLD
SHADOW_A = 90          # ~35% contact shadow (docs/ART_STYLE.md section 2)


def stamp(cv, rows, cmap, x, y):
    """Paint ASCII rows onto `cv` with their top-left at (x, y)."""
    cv.blit(pix.part(rows, {k: rgba(v) for k, v in cmap.items()}), x, y)
    return cv


def part(rows, cmap):
    return pix.part(rows, {k: rgba(v) for k, v in cmap.items()})


def outline(cv, dark=WARM, local=0.62, diag=False):
    return pix.outline(cv, dark, local=local, diag=diag)


def outline_solid(cv, color):
    """1 px outline all round in one colour (the game's animals: ranch_goat.png's plum line)."""
    c = rgba(color)
    op = cv.a[:, :, 3] == 255
    pad = np.pad(op, 1)
    near = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
    for y, x in zip(*np.nonzero(near & ~op)):
        cv.a[y, x] = c
    return cv


def shadow(cv, cx, cy, rx, ry, alpha=SHADOW_A, color=None):
    """Soft contact-shadow ellipse UNDER what is drawn (only fills transparent pixels)."""
    col = rgba(color or P.OUTLINE_WARM, alpha)
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if not cv.inb(x, y):
                continue
            if ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 <= 1.0 \
                    and cv.a[y, x, 3] == 0:
                cv.a[y, x] = col
    return cv


def under(cv, src, x=0, y=0):
    """Composite `src` BEHIND what `cv` already holds."""
    out = Canvas(cv.w, cv.h)
    out.blit(src, x, y)
    out.blit(cv, 0, 0)
    cv.a = out.a
    return cv


def glow(cv, cx, cy, r, color, alpha=70):
    """Translucent round glow (lit lanterns): fills only transparent pixels, fading outward."""
    col = rgba(color)
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if not cv.inb(x, y) or cv.a[y, x, 3] != 0:
                continue
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= r:
                a = int(alpha * (1 - d / (r + 1)) + 0.5)
                if a > 8:
                    cv.a[y, x] = col[:3] + (a,)
    return cv


def tint(img_canvas, color):
    """Multiply (Godot modulate) a canvas by a colour, for previews."""
    c = rgba(color)
    out = img_canvas.copy()
    out.a[:, :, :3] = (out.a[:, :, :3].astype(np.uint32) * np.array(c[:3]) // 255).astype(np.uint8)
    return out


__all__ = ["Canvas", "rgba", "mix", "pix", "P", "WARM", "COLD", "stamp", "part", "outline",
           "outline_solid", "shadow", "under", "glow", "tint"]
