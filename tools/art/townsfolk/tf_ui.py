"""Social UI icons (art/ui/), native size, in the style of ready_bubble.png / hp_icon.png: warm
outline #281a0b, flat fills with one shade and one highlight, no anti-aliasing.

  heart_full.png  7x6   a filled heart (one per affinity heart, ten in a row)
  heart_empty.png 7x6   the same outline with a dark fill
  quest_marker.png 9x12 cream speech bubble with a bold "!" (floats over an NPC with something for you)
  gift_icon.png   8x8   a brown-paper parcel tied with twine, a red bow on top
  talk_icon.png   8x7   a small speech bubble
"""
from __future__ import annotations

import palette as P
from enemies import pix
from enemies.pix import rgba

O = rgba(P.OUTLINE_WARM)
CREAM = rgba(P.CREAM)
CREAM_SHADE = rgba(P.DIRT_RAMP[5])          # the bubble's lower inner edge (as ready_bubble.png)
RED = rgba(P.BLOOD[2])                      # same reds as hp_icon.png
RED_SHADE = rgba(P.BLOOD[1])
RED_HI = rgba(P.HEART_HIGHLIGHT)
EMPTY = rgba("#4a3022")                     # dark warm fill of an empty heart
EMPTY_HI = rgba("#5e3e2c")
MARK = rgba(P.MEDIC_RED_RAMP[2])           # the "!" of the quest marker
MARK_HI = rgba(P.MEDIC_RED_RAMP[3])
KRAFT = [rgba(c) for c in ("#8a5c36", "#b07a48", "#cf9c62")]  # brown paper
STRING = rgba(P.MEDIC_RED_RAMP[2])
STRING_HI = rgba(P.MEDIC_RED_RAMP[4])

TWINE = rgba(P.CREAM)
TWINE_SHADE = rgba(P.DIRT_RAMP[4])

CMAP = {"w": TWINE, "W": TWINE_SHADE, "o": O, "c": CREAM, "s": CREAM_SHADE, "r": RED, "R": RED_SHADE, "h": RED_HI,
        "e": EMPTY, "E": EMPTY_HI, "m": MARK, "M": MARK_HI, "k": KRAFT[1], "K": KRAFT[0],
        "l": KRAFT[2], "t": STRING, "T": STRING_HI}


def heart_full():
    return pix.part([".oo.oo.",
                     "ohrorRo",
                     "orrrrRo",
                     ".orrRo.",
                     "..oRo..",
                     "...o..."], CMAP)


def heart_empty():
    return pix.part([".oo.oo.",
                     "oEeoeeo",
                     "oeeeeeo",
                     ".oeeeo.",
                     "..oeo..",
                     "...o..."], CMAP)


def quest_marker():
    return pix.part([".ooooooo.",
                     "occccccco",
                     "occMmmcco",
                     "occMmmcco",
                     "occMmmcco",
                     "occcmccco",
                     "occccccco",
                     "occMmmcco",
                     "occmmmcco",
                     "ossssssso",
                     ".ooosooo.",
                     "....o...."], CMAP)


def gift_icon():
    return pix.part([".oo..oo.",
                     "oTtooTto",
                     "ooowWooo",
                     "ollwWllo",
                     "okkwWkKo",
                     "owwwWWWo",
                     "okkwWkKo",
                     "oooooooo"], CMAP)


def talk_icon():
    return pix.part([".oooooo.",
                     "occcccco",
                     "ocKKcKco",
                     "osssssso",
                     ".oosooo.",
                     ".oso....",
                     ".oo....."], CMAP)


def build():
    return {
        "heart_full": heart_full(),
        "heart_empty": heart_empty(),
        "quest_marker": quest_marker(),
        "gift_icon": gift_icon(),
        "talk_icon": talk_icon(),
    }
