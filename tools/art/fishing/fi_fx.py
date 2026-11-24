"""Fishing effects (art/fx/), hand-placed pixel maps in the house palette. Translucent pixels are
allowed here (ripples), as for the other FX; everything else is fully opaque.

  bobber.png  16 x 8 = 2 frames of 8 x 8:
              0 float: the red-and-cream bobber riding on the water, a ripple ring round it
              1 dip:   pulled under, only the red cap showing, a wider splash ring and two
                       droplets
              The bobber's waterline is row 5 in both frames, centred between columns 3 and 4,
              so code can place the frame's (4, 5) on the water cell and swap frames in place.
  splash.png  48 x 16 = 3 frames of 16 x 16, a small water splash (cast landing, catch, junk):
              0 the crown rising, 1 at full height with droplets flying, 2 falling back into a
              wide fading ring. Centred on column 8; the water surface is row 12.

Foam and pale blue (SPLASH_RAMP: the water ramp's top + FOAM) with a dark-water rim
(WATER_RAMP[1]) where it needs to read against the game's water (#3c6f86).
"""
from __future__ import annotations

import numpy as np

import ia_lib as L
import palette as P

RED = P.BOBBER_RED_RAMP
CREAM = P.BOBBER_CREAM_RAMP
SPL = P.SPLASH_RAMP
RIM = P.WATER_RAMP[1]
OUT = P.OUTLINE_WARM

# char -> (colour, alpha)
LEGEND = {
    "o": (OUT, 255),                       # bobber outline
    "R": (RED[3], 255), "r": (RED[2], 255), "d": (RED[1], 255), "D": (RED[0], 255),
    "C": (CREAM[3], 255), "c": (CREAM[2], 255), "k": (CREAM[1], 255),
    "u": (CREAM[0], 150),                  # the bobber's body seen through the water (dimmed)
    "F": (SPL[3], 255), "W": (SPL[2], 255), "w": (SPL[1], 255), "b": (SPL[0], 255),
    "f": (SPL[3], 200), "h": (SPL[2], 150), "q": (SPL[1], 110), "x": (RIM, 150),
}


def paint(rows, w, h):
    rows = L.grid(rows)
    out = np.zeros((h, w, 4), np.uint8)
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch in LEGEND:
                col, a = LEGEND[ch]
                out[j, i] = L.rgba(col, a)
    return out


BOBBER_FLOAT = """
    ....o...
    ...oo...
    ..oRdo..
    .oRrrdo.
    .oCccko.
    hhokkohh
    W.xuux.W
    .WWWWWW.
"""

BOBBER_DIP = """
    f......f
    ..f..f..
    ........
    ........
    ...oo...
    WhoRdohW
    hWxddxWh
    .WWWWWW.
"""


def bobber():
    return np.concatenate([paint(BOBBER_FLOAT, 8, 8), paint(BOBBER_DIP, 8, 8)], axis=1)


SPLASH = ["""
    ................
    ................
    ................
    ................
    ................
    ................
    ........F.......
    ......f...f.....
    .......WFW......
    ....F..WFW..F...
    ......wWFWw.....
    ....hwWFFFWwh...
    ...h.wwWWWww.h..
    ....hqqqqqqqh...
    ................
    ................
""", """
    ................
    ................
    .....F.....F....
    ........F.......
    ..F...W...W...F.
    ......W.F.W.....
    .....wW.W.Ww....
    ....fwW.W.Wwf...
    .....wWwWwWw....
    ....wWWFFFWWw...
    ...wwWFFFFFWww..
    ..hwwWWWWWWWwwh.
    .h.qqqqqqqqqqq.h
    ..hhqqqqqqqqqhh.
    ................
    ................
""", """
    ................
    ................
    ................
    ................
    ................
    ................
    ...f.........f..
    ................
    .....F.....F....
    ..f...........f.
    ........f.......
    .q....wWWWw....q
    q.hh.........hh.
    .qq.hhhhhhhhh.qq
    ...qqqqqqqqqqq..
    ................
"""]


def splash():
    return np.concatenate([paint(r, 16, 16) for r in SPLASH], axis=1)


FX = {"bobber": bobber, "splash": splash}
