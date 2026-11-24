"""The three fish dishes (art/items/<id>.png, 16 x 16), drawn with the items pipeline's kit and
its shared containers so they sit with the other cooked food (potato_hash, pumpkin_soup,
cooked_meal):

  grilled_fish  a whole fish, golden and grill-striped, on the enamel plate (the bowls' enamel)
  fish_stew     the enamel stew bowl (same shape and enamel as ia_food.bowl, which pumpkin_soup and
                cooked_meal use), creamy chowder with potato, greens and fish chunks, a fish tail
                poking out of it
  smoked_eel    the Bog Eel's own S-coil, lacquered mahogany with gold glints, smoke curling off
                it (the way smoked goods are the raw item, darkened, with smoke)
"""
from __future__ import annotations

import ia_lib as L
from ia_lib import Ramp
from ia_common import C
import ia_food

from fishing import fi_fish

import palette as P

ENAMEL = ia_food.ENAMEL


def grilled_fish():
    skin = Ramp(P.GRILL_SKIN_RAMP)
    fin = Ramp(P.GRILL_SKIN_RAMP[:5])
    s, lays = L.icon("""
        ................
        ................
        ................
        ................
        ............tt..
        .......tt..tt...
        ....bbbbbbbt....
        ...bebbbbbbb....
        ..mbbbbbbbbb....
        ...vvvvvvvvt....
        ..ppvvvvvvptt...
        ..pppppppppptt..
        ...pppppppppp...
        ................
        ................
        ................
    """, {
        "p": (ENAMEL, "flat", {"base": 4, "lit": 5, "dark": 2}),
        "t": (fin, "flat", {"base": 3, "lit": 4, "dark": 2, "sep": "outer", "sep_idx": 0}),
        "b": (skin, "inflate", {"contrast": 1.8, "base": 3, "sep": "outer", "sep_idx": 0}),
        "v": (skin, "flat", {"base": 4, "lit": 4, "dark": 3}),
    }, {"e": "b", "m": "b"}, render=False)
    s.put(4, 7, P.CHOWDER_RAMP[5], skin)                     # a cooked fish's pale eye
    s.put(2, 8, P.GRILL_SKIN_RAMP[1], skin)                  # mouth
    for (x, y) in ((7, 6), (6, 7), (5, 8), (10, 6), (9, 7), (8, 8), (7, 9)):
        s.put(x, y, P.GRILL_MARK, skin)                      # two grill stripes
    s.put(5, 6, P.GRILL_SKIN_RAMP[5], skin)                  # crisp glint on the back
    s.put(2, 11, C.LEAF[4], ENAMEL)                          # a sprig of greens on the plate
    s.put(3, 11, C.LEAF[3], ENAMEL)
    s.put(3, 12, C.LEAF[2], ENAMEL)
    return s.render()


def fish_stew():
    broth = Ramp(P.CHOWDER_RAMP)
    tail = Ramp(P.DACE_RAMP[1:])
    s = L.Sprite()
    t = s.layer(tail, "flat", base=2, lit=3, dark=1)
    t.ascii(L.grid("""
        .........#..#...
        .........####...
        ..........##....
        ...........#....
    """), 0, 2)
    body = s.layer(ENAMEL, "cyl", axis=90, contrast=2.0)
    body.ascii(L.grid("""
        ..############..
        ..############..
        ...##########...
        ....########....
        .....######.....
    """), 0, 8)
    lip = s.layer(ENAMEL, "solid", index=4, sep="outer", sep_idx=1)
    lip.ascii(["..############.."], 0, 8)
    f = s.layer(broth, "sphere", contrast=1.8, bias=0.3, sep="outer", sep_idx=1)
    f.ascii(L.grid("""
        .....######.....
        ...##########...
        ..############..
        ..############..
    """), 0, 4)
    for (x, y, d) in ((5, 5, 1), (8, 6, -1), (4, 6, -1), (6, 7, 1), (10, 7, -1), (9, 5, 1)):
        f.nudge([(x, y)], d)
    for (x, y, col) in ((6, 5, C.POTATO_CUBE[3]), (9, 7, C.POTATO_CUBE[2]), (4, 7, P.SMOKED_EEL_RAMP[4]),
                        (7, 6, "#f2e8d8"), (8, 5, "#e8dcc8"), (10, 6, C.LEAF[4]), (5, 6, C.LEAF[3]),
                        (12, 7, C.LEAF[4])):
        s.put(x, y, col, broth)
    img = s.render()
    for (x, y) in ((4, 2), (7, 1)):
        img[y, x] = L.rgba(C.STEAM[1])                        # steam, like pumpkin_soup
    return img



def smoked_eel():
    """The Bog Eel's own coil, smoked: lacquered mahogany with gold glints, smoke curling off it."""
    skin = Ramp(P.SMOKED_EEL_RAMP)
    s, lays = fi_fish.eel(skin, Ramp(P.SMOKED_EEL_RAMP[2:]), Ramp(P.SMOKED_EEL_RAMP[1:5]),
                          eye="#1c140c", render=False)
    for (x, y) in ((4, 3), (5, 3), (9, 6), (10, 6), (6, 9), (7, 8), (6, 11), (7, 11)):
        s.put(x, y, P.SMOKED_EEL_RAMP[5], skin)              # lacquer glints
    img = s.render()
    for (x, y, k) in ((12, 4, 0), (11, 3, 1), (12, 2, 2), (13, 1, 1), (14, 7, 0), (14, 6, 1)):
        img[y, x] = L.rgba(P.SMOKE_WISP[k])                   # smoke curling off it
    return img

ICONS = {"grilled_fish": grilled_fish, "fish_stew": fish_stew, "smoked_eel": smoked_eel}
