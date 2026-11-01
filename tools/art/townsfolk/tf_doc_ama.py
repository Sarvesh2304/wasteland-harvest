"""Doc Ama, the town doctor (docs/SOCIAL_AND_QUESTS.md section 1): fifties.

Deep brown skin; near-black hair with grey streaks, worn in a bun; round glasses that catch the
light (two pale lens pixels instead of eyes); a long off-white coat over a slate top and slate
trousers; a red armband on her LEFT sleeve (shows facing south, north and west); a leather
satchel on her RIGHT hip, strap over her left shoulder (shows facing south, north and east).
"""
from __future__ import annotations

import palette as P
from townsfolk import tf_doll as D
from townsfolk.tf_doll import Arm

SKIN = P.SKIN_DEEP_RAMP
HAIR = P.INK_HAIR_RAMP
GREY = P.GREY_STREAK_RAMP
COAT = P.COAT_WHITE_RAMP
RED = P.MEDIC_RED_RAMP
LEA = P.LEATHER_RAMP
SLATE = P.SLATE_CLOTH_RAMP

CMAP = {
    # hair, light -> dark, plus the grey streaks
    "h": HAIR[3], "H": HAIR[2], "k": HAIR[1], "K": HAIR[0], "g": GREY[1], "G": GREY[0],
    # skin
    "5": SKIN[4], "4": SKIN[3], "3": SKIN[2], "2": SKIN[1], "1": SKIN[0],
    "o": P.LENS_GLINT, "e": P.EYE_DARK,
    # coat (off-white), light -> dark
    "W": COAT[5], "w": COAT[4], "c": COAT[3], "C": COAT[2], "d": COAT[1],
    # slate top / trousers
    "s": SLATE[3], "S": SLATE[2], "t": SLATE[1],
    # red armband
    "R": RED[3], "r": RED[2],
    # satchel
    "L": LEA[3], "l": LEA[2], "m": LEA[1], "M": LEA[0],
}

HEAD = {
    "S": (["..hH..",
           "..Hk..",
           ".hHHHk",
           "hgHHHk",
           "g4433G",
           "Ho33ok",
           ".3432.",
           "..32.."], 9, 1),
    "N": (["..hH..",
           "..Hk..",
           ".hHHHk",
           "hgHHHk",
           "gHHHkG",
           "HHHHkk",
           ".kHHk.",
           "..32.."], 9, 1),
    "E": (["hH....",
           "Hk....",
           ".hHgk.",
           "hHgHH4",
           "kHH443",
           "kH33o3",
           ".k3433",
           "..32.."], 9, 1),
}

TORSO = {
    "S": (["wcsScd",
           "wcsLcd",
           "wcLccd",
           "wLccCd",
           "wcccCd",
           "wcc.Cd",
           "wC..Cd"], 9, 9),
    "N": (["wccCCd",
           "wcLCCd",
           "wccLCd",
           "wcccLd",
           "wcccCd",
           "wccCCd",
           "wcC.Cd"], 9, 9),
    "E": ([".ws3.",
           "wccsL",
           "wccLd",
           "wcLCd",
           "wLcCd",
           "wccCd",
           "wcCCd"], 10, 9),
}

ARMS = {
    "S": (Arm("wwccC4", 8, 10), Arm("CRrdd2", 15, 10)),
    "N": (Arm("wRrcC3", 8, 10), Arm("CCddd2", 15, 10)),
    # facing east: her right side; the armband is on the far (left) arm
    "E": (Arm("dRdddd", 11, 10), Arm("wwccC4", 12, 10)),
    # facing west (drawn right-facing, mirrored): her left side, armband on the near arm
    "W": (Arm("dddddd", 11, 10), Arm("wRrcC4", 12, 10)),
}


def gear(look, facing, pose):
    """Satchel on her right hip (strap drawn in the torso art)."""
    by = pose.by
    out = {"under": [], "over": []}
    cm = look.cmap
    if facing == "S":
        out["over"].append(("bag", D.stamp(["Ll", "lm", "mM"], cm, 9, 13 + by), True))
    elif facing == "N":
        out["under"].append(("bag", D.stamp(["lL", "ml", "Mm"], cm, 13, 13 + by), True))
    elif facing == "E":
        out["over"].append(("bag", D.stamp(["Ll", "lm", "mM"], cm, 10, 13 + by), True))
    if facing in ("E", "W") and pose.stride:
        flare = D.layer()
        flare.px(9, 15 + by, cm["c"])
        flare.px(15, 15 + by, cm["d"])
        out["under"].append(("flare", flare, False))
    return out


LOOK = D.Look(
    cmap=CMAP, head=HEAD, torso=TORSO, arms=ARMS,
    legs=SLATE[0:3], boots=P.LEATHER_RAMP[0:3],
    leg_x=(9, 13), hip_y=14, hip_e=11, gear=gear,
)
