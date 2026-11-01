"""Wren, the scavenger (docs/SOCIAL_AND_QUESTS.md section 1): early twenties, the player's
childhood friend.

A patched brown hood over auburn hair, brass goggles pushed up on her forehead, a muted teal scarf
(her accent colour), a cross-body satchel (strap from her LEFT shoulder to the bag on her RIGHT
hip), fingerless gloves, patched khaki trousers and scuffed boots. Slim: 6 px torso, sloped
shoulders.
"""
from __future__ import annotations

import palette as P
from townsfolk import tf_doll as D
from townsfolk.tf_doll import Arm

SKIN = P.SKIN_FAIR_RAMP
HAIR = P.AUBURN_RAMP
HOOD = P.HOOD_BROWN_RAMP
JACKET = P.WREN_JACKET_RAMP
SCARF = P.SCARF_TEAL_RAMP
BRASS = P.BRASS_RAMP
LEA = P.LEATHER_RAMP
KHAKI = P.KHAKI_RAMP
PATCH = P.RUST_RAMP

CMAP = {
    # hood / jacket (brown), light -> dark
    "J": HOOD[4], "j": HOOD[3], "h": HOOD[2], "H": HOOD[1], "K": HOOD[0],
    # jacket (faded plum), light -> dark
    "P": JACKET[4], "p": JACKET[3], "q": JACKET[2], "Q": JACKET[1], "Z": JACKET[0],
    # hood patch (rust cloth)
    "r": PATCH[3], "R": PATCH[2],
    # auburn hair
    "A": HAIR[4], "a": HAIR[3], "b": HAIR[2], "c": HAIR[1],
    # skin
    "5": SKIN[4], "4": SKIN[3], "3": SKIN[2], "2": SKIN[1], "1": SKIN[0],
    "e": P.EYE_DARK,
    # goggles: brass frame + lens glint
    "Y": BRASS[3], "y": BRASS[2], "g": P.LENS_GLINT,
    # teal scarf
    "T": SCARF[4], "t": SCARF[3], "u": SCARF[2], "U": SCARF[1],
    # satchel strap / bag, gloves
    "L": LEA[3], "l": LEA[2], "m": LEA[1], "M": LEA[0],
}

HEAD = {
    "S": (["..jjjh..",
           ".Jjjjhh.",
           "jYgYYgYH",
           "ja4444bH",
           "jae44ebK",
           ".b4432K."], 8, 3),
    "N": (["..jjjh..",
           ".JjjjhH.",
           "JjrRhhhH",
           "jjRRhhhH",
           "jjjhhhHK",
           ".jjhhHK."], 8, 3),
    # facing east (her right side, the satchel side)
    "E": (["..jjjh..",
           ".Jjjjhy.",
           "jjjhYgy.",
           "jjha444.",
           "jjhb4e4.",
           ".Hhb43.."], 7, 3),
}

TORSO = {
    "S": (["TTTttu",
           "PptuLQ",
           "PpqLqQ",
           "PpLqqQ",
           "PmqqqQ",
           "QqqqqZ"], 9, 9),
    "N": (["TTttuu",
           "PLpqqQ",
           "PpLqqQ",
           "PpqLqQ",
           "PpqqmQ",
           "QqqqqZ"], 9, 9),
    "E": ([".TTt.",
           "PpqLu",
           "PpLqQ",
           "PLqqQ",
           "mqqqQ",
           "qqqQZ"], 10, 9),
}

ARMS = {
    "S": (Arm("PppqM4", 8, 10), Arm("qqQQM3", 15, 10)),
    "N": (Arm("PppqM3", 8, 10), Arm("qqQQM3", 15, 10)),
    "E": (Arm("QQZZM2", 11, 10), Arm("PppqM4", 12, 10)),
}


def gear(look, facing, pose):
    """Satchel on her right hip; the strap is part of the torso art. A patch on the left knee."""
    by = pose.by
    out = {"under": [], "over": []}
    cm = look.cmap
    if facing == "S":
        out["over"].append(("bag", D.stamp(["Ll", "lm", "mM"], cm, 9, 13 + by), True))
    elif facing == "N":
        out["under"].append(("bag", D.stamp(["lL", "ml", "Mm"], cm, 13, 13 + by), True))
    elif facing == "E":
        out["over"].append(("bag", D.stamp(["Ll", "lm", "mM"], cm, 10, 13 + by), True))
    # knee patch on the left trouser leg (front views follow the leg; side views the near leg)
    patch = D.layer()
    if facing == "S":
        patch.px(13, 16, cm["R"])
    elif facing == "N":
        patch.px(9, 16, cm["R"])
    elif facing == "W":                       # her left side: the near leg
        patch.px(look.leg_x_at(pose, True, 16), 16, cm["R"])
    if patch.any().any():
        out["over"].append(("patch", patch, False))
    return out


LOOK = D.Look(
    cmap=CMAP, head=HEAD, torso=TORSO, arms=ARMS,
    legs=KHAKI[1:4], boots=P.BOOT_RAMP[1:4],
    leg_x=(9, 13), hip_y=14, hip_e=11, gear=gear,
)
