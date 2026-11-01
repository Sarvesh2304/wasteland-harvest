"""Brask, the wall warden (docs/SOCIAL_AND_QUESTS.md section 1): sixties, ex-militia.

Grey crew cut, a scar through his LEFT eyebrow (shows facing south and west), an olive-drab long
coat with square shoulders, belted; dark trousers and tall boots; a short cudgel hanging on his
RIGHT hip (shows facing south, north and east). Broad, but still the 8 px townsfolk body.
"""
from __future__ import annotations

import palette as P
from townsfolk import tf_doll as D
from townsfolk.tf_doll import Arm

SKIN = P.SKIN_RUDDY_RAMP
HAIR = P.STEEL_HAIR_RAMP
COAT = P.OLIVE_DRAB_RAMP
BELT = P.LEATHER_RAMP
WOOD = P.WOOD_RAMP

CMAP = {
    # hair (steel grey crew cut), light -> dark
    "a": HAIR[4], "b": HAIR[3], "c": HAIR[2], "d": HAIR[1], "w": HAIR[0],
    # skin
    "5": SKIN[4], "4": SKIN[3], "3": SKIN[2], "2": SKIN[1], "1": SKIN[0],
    "e": P.EYE_DARK, "x": P.SCAR_PALE, "m": SKIN[1],
    # coat
    "O": COAT[5], "o": COAT[4], "p": COAT[3], "P": COAT[2], "Q": COAT[1],
    # belt, buckle
    "l": BELT[2], "L": BELT[1], "B": P.BRASS_RAMP[3],
    # cudgel
    "W": WOOD[3], "V": WOOD[1], "G": BELT[0],
}

HEAD = {
    "S": (["aabbbc",
           "babbbd",
           "5w44x3",
           "5e44e3",
           "4443x3",
           ".3mm3."], 9, 3),
    "N": (["aabbbc",
           "babbcd",
           "abbbcd",
           "4bbcc3",
           ".3cc3.",
           ".3432."], 9, 3),
    # facing east: his right side (no scar)
    "E": (["aabbc.",
           "babbc.",
           "bbc4w4",
           "cc43e4",
           ".c4444",
           "..343."], 9, 3),
    # facing west (drawn right-facing, mirrored): his left side, the scarred brow
    "W": (["aabbc.",
           "babbc.",
           "bbc4x4",
           "cc43e4",
           ".c44x4",
           "..343."], 9, 3),
}

TORSO = {
    "S": (["Oo32oP",
           "OoopoP",
           "OooppP",
           "lLBLLL",
           "OooppP",
           "OooppP",
           "OooppP",
           "op..pP"], 9, 9),
    "N": (["PooopP",
           "OoooPP",
           "OooopP",
           "lLLLLL",
           "OoopPP",
           "OoopPP",
           "OoopPP",
           "opp.pP"], 9, 9),
    "E": ([".Oo3.",
           "Ooopp",
           "OoopP",
           "lLLLL",
           "OoopP",
           "OoopP",
           "OoppP",
           "OoppP"], 10, 9),
}

ARMS = {
    "S": (Arm("OOooo4", 8, 10), Arm("pPPPQ2", 15, 10)),
    "N": (Arm("OOooo3", 8, 10), Arm("pPPPQ2", 15, 10)),
    "E": (Arm("PPQQQ2", 11, 10), Arm("Oooop4", 12, 10)),
}


def gear(look, facing, pose):
    """The cudgel on his right hip: in front of the coat facing south, behind the arm facing
    north / east, hidden behind his body facing west. Facing sideways mid-stride, the coat's
    skirt flares 1 px fore and aft over the striding legs."""
    by = pose.by
    out = {"under": [], "over": []}
    if facing == "S":
        rows = [".G", ".W", "W.", "V."]
        out["over"].append(("cudgel", D.stamp(rows, look.cmap, 9, 13 + by), True))
    elif facing == "N":
        rows = ["G", "V", "W", "V"]
        out["under"].append(("cudgel", D.stamp(rows, look.cmap, 13, 12 + by), True))
    elif facing == "E":
        rows = ["G.", "W.", ".W", ".V"]
        out["under"].append(("cudgel", D.stamp(rows, look.cmap, 11, 12 + by), True))
    if facing in ("E", "W") and pose.stride:
        flare = D.layer()
        flare.px(9, 16 + by, look.cmap["o"])
        flare.px(15, 16 + by, look.cmap["P"])
        out["under"].append(("flare", flare, False))
    return out


LOOK = D.Look(
    cmap=CMAP, head=HEAD, torso=TORSO, arms=ARMS,
    legs=P.CHARCOAL_RAMP[1:4], boots=P.BOOT_RAMP[1:4],
    leg_x=(9, 13), hip_y=15, hip_e=11, gear=gear,
)
