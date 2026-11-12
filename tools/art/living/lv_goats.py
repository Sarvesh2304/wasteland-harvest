"""The game's goats, Milestone D: Tully's pack-goat (on the open market stall) and the race goat
strip (art/fx/race_goat.png).

Both follow art/props/ranch_goat.png: a stocky goat with a short tail cocked up, back-swept
horns, a cream muzzle and beard, a dark eye, a 1 px plum outline all round (animals keep it).
The pack-goat wears ranch_goat.png's grey-green coat and magenta hooves and carries canvas
panniers with a rolled red blanket on top; the race goat is neutral grey-white
(RACE_GOAT_RAMP, near-neutral dark outline) so the game can tint each runner with `modulate`,
and wears a blank white racing bib on its flank for the game to colour / number.
Both face LEFT (the race runs east to west; the pack-goat looks out of the stall).
"""
from __future__ import annotations

from living.lv_common import Canvas, P, outline_solid, part, pix, shadow

COAT = P.GOAT_COAT_RAMP
HORN = P.GOAT_HORN_RAMP
PACK = P.PACK_CANVAS_RAMP
LEATHER = P.LEATHER_RAMP
RED = P.FEST_RED_RAMP

PACK_GOAT_CMAP = {
    "5": COAT[4], "4": COAT[3], "3": COAT[2], "2": COAT[1], "1": COAT[0],
    "t": HORN[0], "H": HORN[1], "m": HORN[2], "b": HORN[1], "e": P.GOAT_OUTLINE,
    "f": P.GOAT_HOOF,
    "p": PACK[4], "P": PACK[3], "q": PACK[2], "Q": PACK[1],
    "s": LEATHER[2], "y": P.BRASS_RAMP[3],
    "r": RED[3], "R": RED[2], "k": RED[1],
}

# Tully's pack-goat standing side on, facing LEFT, panniers over its back. Hooves on the last row.
PACK_GOAT = [
    "....tH..............",
    "...tHHt.............",
    "..5544t.............",
    ".554433t............",
    "55e4432.............",
    "m544432.............",
    "mm44432..rrrrrr..5..",
    ".bb4432.rRRRRRRk.45.",
    "..b4432pPPPPPPPPq45.",
    "...4433pPPPPsPPPq43.",
    "...4433pPPPPyPPPq432",
    "...4432qPPPPsPPPQ322",
    "...4432QqqqqsqqqQ322",
    "....433.QQQQQQQQ.32.",
    "....432..3.....3.32.",
    "....32...2.....2.21.",
    "....32...2.....2.21.",
    "....ff...f.....f.ff.",
]


def pack_goat():
    """20 x 18 interior + plum outline = 22 x 20, facing left. Anchor: hooves on the last row."""
    body = part(PACK_GOAT, PACK_GOAT_CMAP)
    cv = Canvas(body.w + 2, body.h + 2)
    cv.blit(body, 1, 1)
    outline_solid(cv, P.GOAT_OUTLINE)
    return cv


# -- race goat ------------------------------------------------------------------------------------
RG = P.RACE_GOAT_RAMP
RACE_CMAP = {
    "5": RG[4], "4": RG[3], "3": RG[2], "2": RG[1], "1": RG[0],
    "t": HORN[0], "H": HORN[1], "m": RG[4], "b": RG[2], "e": P.RACE_GOAT_OUTLINE,
    "W": RG[4], "w": RG[1],       # bib: blank white field inside a grey hem
}

# Head and body (no legs), facing LEFT: head up on a stretched neck, horns swept back, ears
# streaming behind, chin beard, tail cocked. Blitted at (1, 1); legs hang from the belly.
RACE_BODY = [
    "....tHH...........",
    "...tH..H..........",
    "..554t1.........4.",
    ".5e4421........43.",
    "m54443.1......443.",
    "mm4443455555554432",
    ".b.443444444444432.",
    "..b.34wwwwwwwww432.",
    ".....3wWWWWWWWw332.",
    "......wwwwwwwww21..",
]
BODY_X, BODY_Y = 1, 1
BELLY_ROW = BODY_Y + 9    # legs hang from here
HOOF_ROW = 14             # planted hooves; the outline takes row 15

# Gallop legs per frame: (hip x, knee, hoof) in canvas coordinates, drawn far-front, far-back,
# near-front, near-back (the near pair lighter, in front). Lifted hooves sit above HOOF_ROW.
GALLOP = [
    # 0 stretched: front legs reaching forward, hind legs pushed back
    [(8, (6, 12), (4, 13)), (17, (19, 12), (21, 14)),
     (7, (5, 12), (3, 14)), (16, (18, 12), (20, 14))],
    # 1 gathered: all four bunched under the body
    [(8, (9, 12), (10, 13)), (17, (16, 12), (15, 13)),
     (7, (8, 12), (8, 14)), (16, (15, 12), (14, 14))],
    # 2 landing on the front legs, hind legs swinging through
    [(8, (7, 12), (6, 14)), (17, (17, 12), (16, 13)),
     (7, (6, 12), (5, 14)), (16, (16, 12), (14, 13))],
    # 3 push-off from the hind legs, front legs tucked up
    [(8, (6, 12), (8, 12)), (17, (18, 12), (19, 14)),
     (7, (5, 11), (6, 13)), (16, (17, 12), (18, 14))],
]


def race_frame(i):
    cv = Canvas(24, 16)
    for k, (hx, knee, hoof) in enumerate(GALLOP[i]):
        near = k >= 2
        col = RACE_CMAP["3"] if near else RACE_CMAP["1"]
        pts = pix.poly_points([(hx, BELLY_ROW), knee, hoof])
        for (x, y) in pts:
            cv.px(x, y, col)
        x, y = pts[-1]
        cv.px(x, y, RACE_CMAP["e"])            # hoof
    cv.blit(part(RACE_BODY, RACE_CMAP), BODY_X, BODY_Y)
    outline_solid(cv, P.RACE_GOAT_OUTLINE)
    return cv


def race_strip():
    return pix.hstrip([race_frame(i) for i in range(4)])


def with_shadow(goat, rx=None):
    """A copy on a canvas 1 px taller with a contact shadow under the hooves."""
    cv = Canvas(goat.w, goat.h + 1)
    cv.blit(goat, 0, 0)
    shadow(cv, goat.w / 2, goat.h - 1, rx or goat.w / 2 - 2, 1)
    return cv
