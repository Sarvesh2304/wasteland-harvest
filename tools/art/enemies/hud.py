"""Combat HUD icons (art/ui/): hp_icon.png (9x8 heart) and rad_icon.png (9x9 trefoil).

UI art is settlement-side, so the heart takes the warm outline (#281a0b) like the weather icons;
the radiation trefoil is a hazard sign, so it is rad-glow on a dark disc with the cold outline.
"""
from __future__ import annotations

import math

import palette as P
from enemies import pix
from enemies.pix import Canvas, mix, rgba


def hp_icon():
    rows = [".oo...oo.",
            "oHro.orro",
            "oHrrorrso",
            "orrrrrrso",
            ".orrrrso.",
            "..orrso..",
            "...oso...",
            "....o...."]
    cmap = {"o": rgba(P.OUTLINE_WARM), "H": rgba(P.HEART_HIGHLIGHT), "r": rgba(P.BLOOD[2]),
            "s": rgba(P.BLOOD[1])}
    return pix.part(rows, cmap)


def rad_icon():
    cv = Canvas(9, 9)
    disc = rgba(P.ICHOR_RAMP[0])
    rim = mix(disc, P.OUTLINE_COLD, 0.5)
    glow = rgba(P.RAD_GLOW)
    deep = rgba(P.RAD_GLOW_DEEP)
    cx = cy = 4.5
    for y in range(9):
        for x in range(9):
            dx = x + 0.5 - cx
            dy = y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > 4.6:
                continue
            c = disc if d < 3.9 else rim
            ang = math.degrees(math.atan2(dy, dx)) % 360
            # blades centred at 30, 150 and 270 deg (screen y down: 270 = up), 60 deg wide
            blade = any(abs(((ang - b + 180) % 360) - 180) <= 30 for b in (90, 210, 330))
            if d <= 1.0:
                c = glow
            elif 1.6 <= d <= 3.7 and blade:
                c = glow if d < 3.0 else deep
            cv.px(x, y, c)
    return cv


def build(repo):
    out = repo / "art" / "ui"
    hp_icon().save(out / "hp_icon.png")
    rad_icon().save(out / "rad_icon.png")
