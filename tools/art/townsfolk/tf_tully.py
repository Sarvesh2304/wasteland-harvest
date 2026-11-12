"""Tully, the bottle-cap man (docs/LIVING_SETTLEMENT.md section 2): the caravan trader.

Fifties, road-weathered tan; a sun-bleached wide-brim straw hat (paler and wider than Silas's
brown one, so the two never read as the same man); a grey-ginger beard; a long faded slate-blue
travelling coat with a rust patch on its LEFT skirt; a leather sash of bottle caps across his
chest, from his RIGHT shoulder to his LEFT hip (glinting cream / red / blue dots); brown trousers,
road boots; and the big canvas pack with an olive army-blanket bedroll on top that makes his silhouette: it
bulges past his shoulders facing south, fills his back facing north and rides behind him side on.

Facing east the camera sees his RIGHT side (the sash's shoulder end); facing west his LEFT side
(the sash's hip end and the coat patch), via the "W" parts.
"""
from __future__ import annotations

import palette as P
from townsfolk import tf_doll as D
from townsfolk.tf_doll import Arm

SKIN = P.SKIN_TAN_RAMP
HAT = P.HAT_STRAW_RAMP
BEARD = P.GINGER_BEARD_RAMP
GREY = P.BEARD_GREY_RAMP
COAT = P.DUSTER_RAMP
PACK = P.PACK_CANVAS_RAMP
LEA = P.LEATHER_RAMP
ROLL = P.RUST_RAMP
BLANKET = P.OLIVE_DRAB_RAMP

CMAP = {
    # straw hat, light -> dark, and its leather band
    "h": HAT[4], "H": HAT[3], "i": HAT[2], "I": HAT[1], "J": HAT[0], "B": LEA[1],
    # beard / hair: ginger going grey
    "g": BEARD[3], "G": BEARD[2], "q": BEARD[1], "Q": BEARD[0], "y": GREY[2], "Y": GREY[1],
    # skin
    "5": SKIN[4], "4": SKIN[3], "3": SKIN[2], "2": SKIN[1], "1": SKIN[0],
    "e": P.EYE_DARK,
    # travelling coat (faded slate blue), light -> dark
    "O": COAT[4], "o": COAT[3], "p": COAT[2], "P": COAT[1], "Z": COAT[0], "z": COAT[0],
    # coat patch (rust cloth)
    "x": ROLL[3], "X": ROLL[2],
    # the bottle-cap sash: leather band, caps
    "L": LEA[3], "l": LEA[2], "k": P.CAP_GLINT, "r": P.CAP_RED, "b": P.CAP_BLUE,
    # pack canvas, straps, bedroll, tin cup
    "n": PACK[4], "N": PACK[3], "m": PACK[2], "M": PACK[1], "w": PACK[0],
    "s": LEA[2], "S": LEA[1],
    "R": BLANKET[4], "u": BLANKET[3], "U": BLANKET[2],
    "c": P.METAL_RAMP[4], "C": P.METAL_RAMP[2],
}

HEAD = {
    "S": (["...hhHi...",
           "..hhhHHi..",
           "..BBBBBB..",
           "hhhhHHHiiI",
           ".IJ3332JI.",
           "..4e44e3..",
           "..y4334q..",
           "..gGggGq..",
           "...gGGq...",
           "....Gq...."], 7, 1),
    "N": (["...hhHi...",
           "..hhhHHi..",
           "..BBBBBB..",
           "hhhhHHHiiI",
           ".IJGGGqJI.",
           "..GyGGGq..",
           "..3GqqG2..",
           "...3332..."], 7, 1),
    # facing east: his right side
    "E": (["....hhHi..",
           "...hhhHHi.",
           "...BBBBBB.",
           ".hhhhHHHHi",
           "...JqG333.",
           "...qG44e4.",
           "...qGy444.",
           "....gGgg..",
           "....gGGg..",
           ".....Gq..."], 7, 1),
}

TORSO = {
    "S": (["kLoooP",
           "OrLooP",
           "OokLoP",
           "OoobLP",
           "OoopkL",
           "OoopPP",
           "OxoppP",
           "op..pP"], 9, 9),
    "N": (["oooopP",
           "OoooPP",
           "OoooPP",
           "OoopPP",
           "OoopPL",
           "OoopPP",
           "OoopPZ",
           "opp.pP"], 9, 9),
    # facing east: the sash's shoulder end across his chest
    "E": ([".OoLk",
           "OooLr",
           "OoLkP",
           "OLbpP",
           "OoopP",
           "OoopP",
           "OoppP",
           "OoppP"], 10, 9),
    # facing west (drawn right-facing, mirrored): the sash's hip end and the coat patch
    "W": ([".OooP",
           "OoooP",
           "OoooP",
           "OoopL",
           "OookL",
           "OoxrP",
           "OoXpP",
           "OoppP"], 10, 9),
}

ARMS = {
    "S": (Arm("OOooo4", 8, 10), Arm("pPPPZ2", 15, 10)),
    "N": (Arm("OOooo3", 8, 10), Arm("pPPPZ2", 15, 10)),
    "E": (Arm("PPZZZ2", 11, 10), Arm("Oooop4", 12, 10)),
}

# the pack, per facing: (rows, x, y, layer) - "under" = behind the head and arms
PACK_S = (["Ru....uU",          # bedroll ends and pack shoulders beside the beard
           "nN....mM",
           "n......M",
           "n......M",
           "N......w",
           "N......w",
           "m......w"], 8, 7)
PACK_S_SIDES = (["N", "N", "m", "m", "M"], ["M", "M", "w", "w", "w"])   # x7 / x16, rows 9..13
PACK_N = ([".RRuuuUUU.",
           "RuuuuuuUUU",
           ".nnnnnNNm.",
           ".nNNNNNNm.",
           ".mmmsmmmM.",
           ".NNNsNNmM.",
           ".NNNNmmmM.",
           "..NmmmmM..",
           "..mMMMMw..",
           "...wwww..."], 7, 6)
PACK_E = ([".RuU",
           "RuuU",
           "nnNs",
           "nnNs",
           "nNNs",
           "nNms",
           "NNms",
           "Nmms",
           "mMMw",
           ".ww."], 6, 6)


def gear(look, facing, pose):
    """The pack (the silhouette), a tin cup hanging off its side, and the coat's flare mid-stride."""
    by = pose.by
    cm = look.cmap
    out = {"under": [], "over": []}
    if facing == "S":
        rows, x, y = PACK_S
        cv = D.stamp(rows, cm, x, y + by)
        left, right = PACK_S_SIDES
        for k in range(len(left)):
            cv.px(7, 9 + k + by, cm[left[k]])
            cv.px(16, 9 + k + by, cm[right[k]])
        out["under"].append(("pack", cv, False))
    elif facing == "N":
        rows, x, y = PACK_N
        cv = D.stamp(rows, cm, x, y + by)
        cv.px(16, 11 + by, cm["C"])            # tin cup on the pack's right flank
        cv.px(16, 12 + by, cm["c"])
        out["over"].append(("pack", cv, True))
    elif facing in ("E", "W"):
        rows, x, y = PACK_E
        cv = D.stamp(rows, cm, x, y + by)
        if facing == "E":
            cv.px(6, 12 + by, cm["c"])         # the tin cup hangs on the pack's right side
            cv.px(6, 13 + by, cm["C"])
        out["under"].append(("pack", cv, False))
        if pose.stride:
            flare = D.layer()
            flare.px(9, 16 + by, cm["o"])
            flare.px(15, 16 + by, cm["P"])
            out["under"].append(("flare", flare, False))
    return out


LOOK = D.Look(
    cmap=CMAP, head=HEAD, torso=TORSO, arms=ARMS,
    legs=P.CLOTH_RAMP[1:4], boots=P.BOOT_RAMP[1:4],
    leg_x=(9, 13), hip_y=15, hip_e=11, gear=gear,
)
