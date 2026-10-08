"""Mock ruined-city street (art/env/_previews/ruins_city.png): composited at 1x the way the engine
draws it (ruins_ground base, dual-grid concrete / asphalt / rubble overlays, flat decals, then
y-sorted bottom-anchored sprites and ruin-wall fence frames) and saved at x4. Review aid only:
the _previews folder carries a .gdignore so Godot never imports it."""
from __future__ import annotations

import random

from env.lib import Canvas
from env.preview import Scene, load, save, sub
from env.previews import frame_of, place_fences

PLAYER = "../characters/player/rotations/south.png"

# 30 x 20 cells. c = concrete, a = asphalt, r = rubble ground, . = ruins_ground base
GROUND = [
    "..............................",
    "..............................",
    "..............................",
    "..............................",
    "..............................",
    "..............................",
    "..............................",
    "..............................",
    "cccccccccccccccccccccccccccccc",
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "aaaaaaaaaaaaaaaaaaaaaaaaarraaa",
    "cccccccccccccccccccccccrrrcccc",
    ".rr.......ccccccc......rrrr...",
    "..rr......ccccccc.......rrr...",
    "..........ccccccc........rr...",
    "......r...ccccccc.............",
    ".........ccccccccc......r.....",
    "..............................",
]
WALLS = [
    "..............................",
    ".BBBB.BBBB....................",
    ".B........B...........KKK.K...",
    ".B........B.............K.....",
    ".B............................",
    ".BBBBBBBBBB.............K.....",
]
WALL_ROW0 = 14


def build():
    sc = Scene(30, 20, "spring", seed=12)
    base = load("terrain/ruins_ground.png")
    r = random.Random(7)
    for j in range(sc.rows):
        for i in range(sc.cols):
            v = r.choices(range(8), weights=[10, 10, 3, 10, 10, 3, 10, 10])[0]
            sc.cv.blit(sub(base, v * 16, 0, 16, 16), i * 16, j * 16)
    cell = lambda i, j: GROUND[j][i]
    for name, ch in [("rubble_ground", "r"), ("concrete", "c"), ("asphalt", "a")]:
        sc.overlay(f"terrain/{name}.png", lambda i, j, ch=ch: cell(i, j) == ch,
                   f"terrain/{name}_full.png")
    # flat decals: manholes, pavement wear, bones
    deco = load("ruins/pavement_decor.png")
    for (i, j, v) in [(6, 10, 2), (12, 8, 0), (17, 13, 1), (25, 8, 3), (4, 12, 0), (13, 18, 3),
                      (21, 11, 1)]:
        sc.decal(sub(deco, v * 16, 0, 16, 16), i, j)
    mh = load("ruins/manhole.png")
    sc.decal(sub(mh, 0, 0, 16, 16), 9, 11)
    sc.decal(sub(mh, 16, 0, 16, 16), 19, 10)
    bones = load("ruins/bones.png")
    sc.decal(sub(bones, 0, 0, 16, 16), 6, 17)
    sc.decal(sub(bones, 16, 0, 16, 16), 27, 18)
    # north side: the building masses (footprint bottom row 7)
    sc.put("ruins/ruin_house.png", 1.5, 7)
    sc.put("ruins/ruin_shopfront.png", 5.5, 7)
    sc.put("ruins/ruin_garage.png", 10.5, 7)
    sc.put("ruins/ruin_apartment.png", 15.5, 7)
    sc.put("ruins/ruin_office.png", 21.0, 7)
    sc.put("ruins/rubble_pile_1.png", 25.5, 7)
    sc.put("ruins/streetlamp_broken.png", 8, 8)
    sc.put("ruins/streetlamp_broken.png", 26, 8)
    sc.put("ruins/oil_drum.png", 27, 7)
    sc.put("ruins/tire_pile.png", 28, 7)
    # the street: Kael's truck (arrival / extraction), wrecks
    sc.put("ruins/kaels_truck.png", 3, 11)
    sc.put(PLAYER, 5, 12)
    sc.put("ruins/car_burnt.png", 15, 10)
    sc.put("ruins/car_wreck_1.png", 23, 12)
    sc.put("ruins/traffic_cone.png", 11, 12)
    sc.put("ruins/shopping_cart.png", 19, 12)
    # south side: a roofless brick ruin (doorway onto the street, a breach in its east wall),
    # a concrete wall remnant, the subway entrance on its plaza, containers
    grid = ["." * 30 for _ in range(sc.rows)]
    for k, row in enumerate(WALLS[1:]):
        grid[WALL_ROW0 + k] = row.ljust(30, ".")
    place_fences(sc, grid, {"B": "fences/ruin_wall_brick.png", "K": "fences/ruin_wall_concrete.png"})
    sc.put(frame_of("ruins/filing_cabinet.png", 0, 16), 3, 15)
    sc.put(frame_of("ruins/filing_cabinet.png", 1, 16), 4, 15)
    sc.put(frame_of("ruins/locker.png", 1, 16), 9, 15)
    sc.put(frame_of("ruins/supply_crate.png", 0, 16), 8, 17)
    sc.put("ruins/subway_stairs.png", 13.5, 16)
    sc.put("ruins/dumpster.png", 16.5, 14)
    sc.put("ruins/oil_drum.png", 18, 17)
    sc.put("ruins/oil_drum.png", 19, 17)
    sc.put("ruins/tire_pile.png", 18, 18)
    sc.put("ruins/rubble_pile_2.png", 25.5, 16)
    sc.put("ruins/concrete_barrier.png", 11.5, 13)
    sc.put("ruins/car_wreck_2.png", 28, 19)
    save(sc.render(4), "ruins_city.png")
