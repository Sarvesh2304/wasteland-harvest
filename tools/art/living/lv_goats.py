"""The game's goats, Milestone D: Tully's pack-goat (on the open market stall) and the race goat
strip (art/fx/race_goat.png).

Both follow art/props/ranch_goat.png: a stocky goat with a short tail cocked up, back-swept cream
horns, a cream muzzle and beard, a 1 px plum outline all round (animals keep it). The pack-goat
wears ranch_goat.png's grey-green coat and magenta hooves; the race goat is neutral grey-white
(RACE_GOAT_RAMP, near-neutral dark outline) so the game can tint each runner with `modulate`,
and wears a blank white racing bib on its flank for the game to draw a number / colour on.
"""
from __future__ import annotations

from living.lv_common import Canvas, P, outline_solid, part, pix, shadow

COAT = P.GOAT_COAT_RAMP
HORN = P.GOAT_HORN_RAMP
PACK = P.PACK_CANVAS_RAMP

PACK_GOAT_CMAP = {
    "5": COAT[4], "4": COAT[3], "3": COAT[2], "2": COAT[1], "1": COAT[0],
    "h": HORN[2], "H": HORN[1], "t": HORN[0], "c": HORN[2], "e": P.GOAT_OUTLINE,
    "f": P.GOAT_HOOF,
    "p": PACK[4], "P": PACK[3], "q": PACK[2], "Q": PACK[1], "s": P.LEATHER_RAMP[2],
    "r": P.LEATHER_RAMP[3],
}

# Tully's pack-goat standing side on, facing LEFT (out of the stall), panniers on its flank.
PACK_GOAT = [
    "...hH..........",
    "..hHt..........",
    "..544t.......5.",
    ".5e443.......42",
    "c44432.......42",
    ".cc432pppPPs42.",
    "..c44pPPPPPs422",
    "...44pPqqPPs322",
    "...44PqqqqQs322",
    "...44QQQQQQs222",
    "...42.2...4222.",
    "...4..2...4..2.",
    "...f..f...f..f.",
]


def pack_goat():
    """15 x 13 interior + plum outline = 17 x 15, facing left. Anchor: hooves on the last row."""
    body = part(PACK_GOAT, PACK_GOAT_CMAP)
    cv = Canvas(body.w + 2, body.h + 2)
    cv.blit(body, 1, 1)
    outline_solid(cv, P.GOAT_OUTLINE)
    return cv


# -- race goat ------------------------------------------------------------------------------------
RG = P.RACE_GOAT_RAMP
RACE_CMAP = {
    "5": RG[4], "4": RG[3], "3": RG[2], "2": RG[1], "1": RG[0],
    "h": HORN[2], "H": HORN[1], "e": P.RACE_GOAT_OUTLINE,
    "W": RG[4], "w": RG[3], "b": RG[1],       # bib: white field, pale-grey hem
    "f": P.RACE_GOAT_OUTLINE,
}

# Body (no legs), facing LEFT. Head low and forward: a goat at full gallop.
RACE_BODY = [
    ".hH..................",
    "hHH..................",
    "554H..............44.",
    "5e44H............4432",
    "44443.55555555555443.",
    ".4433455444444444432.",
    "..4334WWWWWWW44443322",
    "...3344bWWWWWWb443322",
    "....344bWWWWWWb433322",
    "....343bbbbbbbb333221",
    ".....3322222222222211",
]

# Four gallop frames: (body y offset, [(hip x, hip y, foot x, foot y) per leg]); legs drawn as
# 1 px lines in leg order far-front, far-back, near-front, near-back (near ones lighter).
GALLOP = [
    # extended: front legs reaching forward, hind legs pushed back
    (1, [(6, 11, 2, 14), (17, 11, 21, 14), (7, 11, 3, 14), (18, 11, 22, 13)]),
    # gathered: legs under the body, body high
    (0, [(6, 10, 8, 14), (17, 10, 14, 14), (7, 10, 9, 13), (18, 10, 15, 14)]),
    # landing on the front legs, hind legs swinging forward
    (1, [(6, 11, 4, 14), (17, 11, 15, 13), (7, 11, 6, 14), (18, 11, 18, 14)]),
    # push-off from the hind legs, front legs tucked
    (0, [(6, 10, 3, 12), (17, 10, 20, 14), (7, 10, 5, 13), (18, 10, 19, 14)]),
]


def race_frame(i):
    by, legs = GALLOP[i]
    cv = Canvas(24, 16)
    body = part(RACE_BODY, RACE_CMAP)
    for k, (hx, hy, fx, fy) in enumerate(legs):
        near = k >= 2
        col = RACE_CMAP["3"] if near else RACE_CMAP["2"]
        pts = pix.line_points(hx + 1, hy + by - 1, fx + 1, fy)
        for (x, y) in pts[:-1]:
            cv.px(x, y, col)
        x, y = pts[-1]
        cv.px(x, y, RACE_CMAP["f"])                 # hoof
    cv.blit(body, 1, by + 1)
    # tail flicks up on the gathered / push-off frames
    if i in (1, 3):
        cv.px(21, by + 2, RACE_CMAP["4"])
    outline_solid(cv, P.RACE_GOAT_OUTLINE)
    # keep it inside the frame: nothing below row 15 (the hooves' row)
    return cv


def race_strip():
    frames = [race_frame(i) for i in range(4)]
    return pix.hstrip(frames)


def with_shadow(goat, rx=None):
    """A copy on a canvas 1 px taller with a contact shadow under the hooves."""
    cv = Canvas(goat.w, goat.h + 1)
    cv.blit(goat, 0, 0)
    shadow(cv, goat.w / 2, goat.h - 1, rx or goat.w / 2 - 2, 1)
    return cv
