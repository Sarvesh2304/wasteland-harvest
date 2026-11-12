"""The opening's seven illustrated pages (scripts/opening.gd INTRO_PAGES / MONTAGE_PAGES).

Each function returns a 256x112 opaque RGBA array. The parents are the player's own sprite
recoloured (op_scene.person): father in ink-black hair and an olive coat, mother in auburn
(shoulder length) and plum — so the player visibly takes after them.

PLAYER_SPOTS: pages that leave room for the LIVE player sprite, which scripts/opening.gd draws
on top in the look the player just chose — {page: (x, bottom, animation)} in picture pixels
(bottom = the first row below the feet). Mirrored in opening.gd's MONTAGE_PAGES.
"""
from __future__ import annotations

import numpy as np

import palette as P
import op_scene as S

PLAYER_SPOTS = {"farm": (140, 104, "idle_north")}

DUST_RAMP = ["#8a6238", "#a87c48", "#c4995e"]
GRASS_RAMP = ["#5d7d3a", "#7f9a45", "#95ac49"]
SPRING_RAMP = ["#488c55", "#5b9f4c", "#6cb34d"]
AUTUMN_RAMP = ["#6e5a1e", "#8c8832", "#a89a3c"]


def father(**kw):
    return S.person(hair="ink", skin="tan", outfit="olive", **kw)


def mother(**kw):
    return S.person(hair="auburn", skin="fair", outfit="plum", long_hair=True, **kw)


def townsfolk(npc, action="idle", facing="south", frame=0):
    return S.load(f"art/characters/{npc}/{action}/{facing}/{frame}.png")


def tufts(img, kind, season, spots, seed=0):
    for i, (x, b) in enumerate(spots):
        n = 1 + (i + seed) % 2
        S.paste(img, S.load(f"art/env/{'debris' if kind in ('tallgrass', 'weeds') else 'decor'}/{kind}_{season}_{n}.png"),
                x, b, shadow=False)


def stake(img, x, bottom):
    """The claim stake: a split post with a rag tied on, hand-drawn."""
    wood = P.WOOD_RAMP
    for y in range(bottom - 16, bottom):
        img[y, x, :3] = S.rgb(wood[4]).astype(np.uint8)
        img[y, x + 1, :3] = S.rgb(wood[2]).astype(np.uint8)
    img[bottom - 17, x, :3] = S.rgb(wood[3]).astype(np.uint8)
    rag = P.FEST_RED_RAMP
    flag = ["3332", "33221", "2221 ", "221  "]
    for dy, row in enumerate(flag):
        for dx, ch in enumerate(row):
            if ch != " ":
                img[bottom - 15 + dy, x + 2 + dx, :3] = S.rgb(rag[int(ch) - 1 + 0]).astype(np.uint8)
    S.ellipse(img, x + 1, bottom - 1, 2, 1, P.OUTLINE_WARM, 0.35)


def grave(img, x, bottom, ramp=P.GRAVE_STONE_RAMP):
    """A small rounded headstone (8x10) with a carved line, light from the top-left."""
    shape = [
        "..1221..",
        ".122221.",
        "12333320",
        "12322320",
        "12333320",
        "12322320",
        "12333320",
        "12333320",
        "12333320",
        "00000000",
    ]
    cols = {"0": P.OUTLINE_WARM, "1": ramp[3], "2": ramp[2], "3": ramp[1]}
    S.ellipse(img, x + 4, bottom - 1, 5, 1.5, P.OUTLINE_WARM, 0.35)
    for dy, row in enumerate(shape):
        for dx, ch in enumerate(row):
            if ch != ".":
                img[bottom - len(shape) + dy, x + dx, :3] = S.rgb(cols[ch]).astype(np.uint8)


# -- intro ----------------------------------------------------------------------------------------

def claim():
    img = S.canvas()
    hz = 56
    S.sky(img, P.SKY_DAWN, hz)
    S.disc(img, 196, 56, 9, ["#f3b05e", "#ffd88a", "#fff1c4"])
    S.halo(img, 196, 52, 46, "#ffd88a", 0.45, y_max=hz)
    S.skyline(img, hz, 0, 118, 3, "#5a4a5e", window="#4a3d52")
    S.ridge(img, hz + 1, 2.0, 5, "#7a5a4a", period=30)
    S.ground(img, hz + 2, DUST_RAMP, 11, density=0.10)
    S.halo(img, 196, hz + 2, 40, "#e8b070", 0.25)
    S.paste(img, S.load("art/env/trees/deadtree.png"), 6, 84)
    S.paste(img, S.load("art/props/wrecked_car.png"), 160, 82)
    S.paste(img, S.load("art/env/props/barrel.png"), 148, 88)
    S.paste(img, S.load("art/env/props/crate.png"), 206, 86)
    S.paste(img, S.load("art/env/props/crate.png"), 214, 90)
    S.paste(img, S.load("art/buildings/shelter_tent.png"), 60, 80)
    tufts(img, "tallgrass", "summer", [(20, 106), (226, 104), (40, 96), (186, 100), (96, 110)])
    stake(img, 118, 98)
    S.paste(img, father(facing="south"), 90, 103)
    S.paste(img, mother(facing="south"), 124, 103)
    return img


def walls():
    img = S.canvas()
    hz = 44
    S.sky(img, P.SKY_DAY, hz)
    S.skyline(img, hz, 170, 256, 8, "#9aa6aa")
    S.ridge(img, hz + 1, 2.0, 2, "#7d9455", period=26)
    S.ground(img, hz + 2, GRASS_RAMP, 4, density=0.08)
    S.path(img, [(150, hz + 2), (140, 80), (120, 112)], 4, 22, DUST_RAMP, hz + 2, 6)
    S.paste(img, S.load("art/buildings/shack.png"), 18, 66)
    S.paste(img, S.load("art/buildings/store.png"), 62, 64)
    S.paste(img, S.load("art/env/props/well.png"), 168, 68)
    S.paste(img, S.load("art/env/trees/pine_summer.png"), 222, 70)
    sheet = S.load("art/env/fences/fence_palisade.png")
    S.paste(img, S.fence_run(sheet, 7), 0, 92, shadow=False)
    S.paste(img, S.fence_run(sheet, 3), 176, 92, shadow=False)
    S.paste(img, S.load("art/env/debris/log_large.png"), 128, 100)
    S.paste(img, S.load("art/env/debris/log_large.png"), 140, 104)
    S.paste(img, townsfolk("brask", facing="east"), 110, 100)
    S.paste(img, father(action="walk", facing="west", frame=1), 154, 99)
    S.paste(img, mother(action="tool", facing="east", frame=2), 202, 106)
    S.paste(img, townsfolk("marta", facing="south"), 90, 70)
    tufts(img, "tuft", "summer", [(10, 106), (60, 110), (232, 110), (236, 76)])
    return img


def clinic():
    img = S.canvas()
    hz = 50
    S.sky(img, P.SKY_NIGHT, hz)
    S.stars(img, hz, 21, 70)
    S.disc(img, 36, 16, 6, P.MOON)
    S.halo(img, 36, 16, 18, "#6a7090", 0.35)
    S.skyline(img, hz, 150, 256, 13, "#262c45")
    S.ground(img, hz, P.SNOW_RAMP[1:], 9, density=0.06)
    night = P.NIGHT_SKY
    S.tint_region(img, hz, 112, night, 0.42)
    S.paste(img, S.tint(S.load("art/buildings/shack.png"), night, 0.5), 14, 72)
    S.paste(img, S.tint(S.load("art/buildings/town_clinic.png"), night, 0.42), 96, 92)
    S.paste(img, S.tint(S.crop(S.load("art/env/props/lamp_post.png"), 16, 0, 16, 48), night, 0.4), 76, 96)
    S.paste(img, S.tint(S.load("art/env/trees/pine_winter.png"), night, 0.5), 200, 84)
    S.paste(img, S.tint(S.load("art/env/trees/pine_winter.png"), night, 0.55), 222, 74)
    # lamplight spilling from the clinic's windows and door onto the snow
    S.halo(img, 128, 96, 44, "#ffc948", 0.35)
    S.halo(img, 84, 70, 14, "#ffc948", 0.3)
    S.paste(img, S.tint(father(action="walk", facing="east", frame=0), night, 0.25), 166, 104)
    # a little falling snow
    for k in range(40):
        x = int(S.hash01(k, 9, 5) * 256)
        y = int(S.hash01(k, 10, 5) * 110)
        img[y, x, :3] = S.mix(P.SNOW_RAMP[3], img[y, x, :3], 0.35).astype(np.uint8)
    return img


# -- montage --------------------------------------------------------------------------------------

def childhood():
    img = S.canvas()
    hz = 42
    S.sky(img, P.SKY_DAY, hz)
    S.ridge(img, hz + 1, 2.5, 4, "#6f9a52", period=34)
    S.ground(img, hz + 2, SPRING_RAMP, 14, density=0.08)
    S.paste(img, S.load("art/buildings/shack.png"), 8, 62)
    S.paste(img, S.load("art/buildings/store.png"), 44, 60)
    S.paste(img, S.load("art/buildings/mayor_house.png"), 96, 62)
    S.paste(img, S.load("art/env/trees/ashwood_spring.png"), 196, 74)
    S.paste(img, S.load("art/env/props/laundry_line.png"), 160, 74)
    sheet = S.load("art/env/fences/fence_wood.png")
    S.paste(img, S.fence_run(sheet, 9), 0, 80, shadow=False)
    for row, b in enumerate((92, 102, 112)):
        for i in range(6):
            S.paste(img, S.load(f"art/crops/dustwheat/stage_{2 + (i + row) % 2}.png"), 8 + i * 14 + row * 3, b, shadow=False)
    S.paste(img, mother(facing="east"), 98, 102)
    kid = S.person(action="walk", facing="east", frame=1)       # the player's own colours
    S.paste(img, S.shrink_child(kid), 150, 104)
    S.paste(img, S.crop(S.load("art/props/ranch_goat.png"), 0, 0, 32, 32), 196, 108)
    tufts(img, "flowers", "spring", [(236, 100), (128, 110), (230, 86)])
    return img


def town():
    img = S.canvas()
    hz = 40
    S.sky(img, P.SKY_GOLDEN, hz)
    S.halo(img, 40, 30, 50, "#f6d896", 0.35, y_max=hz)
    S.ground(img, hz + 1, AUTUMN_RAMP, 3, density=0.08)
    S.paste(img, S.load("art/env/props/water_tower.png"), 0, 70)
    S.paste(img, S.crop(S.load("art/env/props/wind_turbine.png"), 0, 0, 32, 64), 150, 58)
    S.paste(img, S.load("art/buildings/watchtower.png"), 222, 74)
    S.paste(img, S.load("art/buildings/mayor_house_antenna.png"), 40, 82)
    S.paste(img, S.load("art/buildings/town_clinic.png"), 104, 84)
    S.paste(img, S.load("art/buildings/store_expanded.png"), 168, 86)
    S.paste(img, S.load("art/env/trees/ashwood_autumn.png"), 206, 96)
    S.paste(img, S.load("art/env/props/market_stall_open.png"), 6, 100)
    sheet = S.load("art/env/fences/fence_wood.png")
    S.paste(img, S.fence_run(sheet, 16), 0, 112, shadow=False)
    S.paste(img, townsfolk("mayor_harlan", facing="south"), 84, 100)
    S.paste(img, townsfolk("wren", facing="east"), 130, 102)
    S.paste(img, townsfolk("doc_ama", facing="west"), 150, 102)
    S.paste(img, townsfolk("scout_kael", facing="south"), 60, 104)
    S.paste(img, S.person(facing="south"), 112, 106)
    return img


def farewell():
    img = S.canvas()
    hz = 58
    S.sky(img, P.SKY_SUNSET, hz)
    S.disc(img, 70, 58, 11, ["#f2a64e", "#ffd27a", "#fff0c0"])
    S.halo(img, 70, 54, 60, "#ffd27a", 0.4, y_max=hz)
    # the settlement far off, dark against the sunset
    S.skyline(img, hz + 1, 176, 252, 31, "#4a2c3a", window="#ffc948", max_h=12)
    S.ridge(img, hz + 6, 6.0, 9, "#6a6a3a", period=60)
    S.ground(img, hz + 10, ["#4e6e34", "#6a8a40", "#82a04a"], 17, density=0.07)
    warm = "#d98a4e"
    S.paste(img, S.tint(S.load("art/env/trees/ashwood_spring.png"), warm, 0.18), 132, 98)
    grave(img, 118, 102)
    grave(img, 134, 102)
    S.paste(img, S.tint(S.load("art/env/props/bench.png"), warm, 0.18), 64, 104)
    tufts(img, "flowers", "spring", [(110, 106), (128, 108), (144, 106), (150, 110), (100, 112), (190, 110)])
    return img


def farm():
    img = S.canvas()
    hz = 44
    S.sky(img, P.SKY_DAWN[1:], hz)
    S.disc(img, 214, 44, 7, ["#f3b05e", "#ffd88a", "#fff1c4"])
    S.halo(img, 214, 40, 40, "#ffd88a", 0.4, y_max=hz)
    S.ridge(img, hz + 1, 2.0, 7, "#6a7a46", period=28)
    S.ground(img, hz + 2, GRASS_RAMP, 23, density=0.09)
    S.path(img, [(128, 74), (136, 92), (140, 112)], 8, 16, DUST_RAMP, 74, 31)
    S.paste(img, S.load("art/env/trees/pine_spring.png"), 30, 72)
    S.paste(img, S.load("art/env/trees/pine_spring.png"), 52, 64)
    S.paste(img, S.load("art/buildings/farmhouse.png"), 104, 76)
    S.paste(img, S.load("art/buildings/shipping_box.png"), 160, 78)
    S.paste(img, S.load("art/env/props/scarecrow.png"), 196, 92)
    S.paste(img, S.load("art/env/debris/stump_large.png"), 30, 104)
    S.paste(img, S.load("art/env/debris/rock_large_1.png"), 214, 108)
    S.paste(img, S.load("art/env/debris/rock_small_2.png"), 176, 104)
    sheet = S.load("art/env/fences/fence_wood.png")
    S.paste(img, S.fence_run(sheet, 3), 70, 84, shadow=False)
    S.paste(img, S.fence_run(sheet, 2), 168, 84, shadow=False)
    tufts(img, "tallgrass", "spring", [(64, 100), (80, 108), (96, 96), (176, 96), (190, 108), (232, 98), (8, 92), (112, 112), (156, 112)])
    tufts(img, "weeds", "spring", [(48, 94), (88, 104), (240, 110), (200, 102), (16, 110)], seed=1)
    return img


PAGES = {
    "claim": claim,
    "walls": walls,
    "clinic": clinic,
    "childhood": childhood,
    "town": town,
    "farewell": farewell,
    "farm": farm,
}
