"""Mock-up scenes + contact sheets for reviewing the environment art (run via preview.py)."""
from __future__ import annotations

import random

from PIL import Image

from env import lib, wang
from env.lib import Canvas
from env.preview import PREV, Scene, load, save, sub

PLAYER = "../characters/player/rotations/south.png"


# ------------------------------------------------------------------------------------------------
def place_fences(sc, grid, kinds, gates=None):
    """grid: list of strings; kinds: char -> fence sheet path; gates: char -> (kind char, path)."""
    gates = gates or {}
    sheets = {k: load(v) for k, v in kinds.items()}
    gsheets = {k: (kk, load(v)) for k, (kk, v) in gates.items()}

    def kind_at(i, j):
        if not (0 <= j < len(grid) and 0 <= i < len(grid[0])):
            return None
        ch = grid[j][i]
        if ch in gsheets:
            return gsheets[ch][0]
        return ch if ch in sheets else None

    for j, row in enumerate(grid):
        for i, ch in enumerate(row):
            if ch in gsheets:
                fr = sub(gsheets[ch][1], 0, 0, 16, 32)
                sc.sprites.append(((j + 1) * 16, i * 16, (j + 1) * 16 - 32, fr))
                continue
            if ch not in sheets:
                continue
            m = (kind_at(i, j - 1) == ch) * 1 + (kind_at(i + 1, j) == ch) * 2 + \
                (kind_at(i, j + 1) == ch) * 4 + (kind_at(i - 1, j) == ch) * 8
            fr = sub(sheets[ch], (m % 4) * 16, (m // 4) * 32, 16, 32)
            sc.sprites.append(((j + 1) * 16, i * 16, (j + 1) * 16 - 32, fr))


def frame_of(path, i, fw):
    cv = load(path)
    return sub(cv, i * fw, 0, fw, cv.h)


# ------------------------------------------------------------------------------------------------
GROUND = [
    "gggggggggdgggggggggg",
    "gggggggggdgggggggggg",
    "gggggggggddggggggggg",
    "ggggggggggdggggggggg",
    "gggnnngggcdcgggggggg",
    "ggnnwwnnggdccccccccg",
    "gnnwwwwnggdggggggggg",
    "gnwwwwwngdddgsssSSgg",
    "gnnwwwwngddggsSSSsgg",
    "ggnnwwnnggdggsssssgg",
    "gggnnnngggdggggggggg",
    "ggggggggggdggggggggg",
]
FENCE = [
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "....................",
    "............wwwGwww.",
    "............w.....w.",
    "............w.....w.",
    "............w.....w.",
    "............wwwwwww.",
    "....................",
]


def settlement(season):
    sc = Scene(20, 12, season, seed=11)
    sc.grass()
    cell = lambda i, j: GROUND[j][i]
    for name, chars in [("sand", "nw"), ("dirt", "d"), ("cobble", "c"), ("soil", "sS"),
                        ("soil_wet", "S")]:
        sc.overlay(f"terrain/{name}.png", lambda i, j, ch=chars: cell(i, j) in ch,
                   f"terrain/{name}_full.png")
    sc.overlay("terrain/water.png", lambda i, j: cell(i, j) == "w", "terrain/water_full.png",
               animated=True)
    # decor decals
    for (i, j, n) in [(14, 1, 1), (6, 2, 2), (17, 4, 3), (1, 11, 4), (12, 11, 1), (7, 9, 3)]:
        sc.decal(f"decor/flowers_{season}_{n}.png", i, j)
    for (i, j, n) in [(3, 1, 1), (12, 3, 2), (8, 11, 3), (19, 9, 1), (16, 0, 2)]:
        sc.decal(f"decor/tuft_{season}_{n}.png", i, j)
    sc.decal("decor/specks_1.png", 11, 9)
    sc.decal("decor/specks_2.png", 8, 4)
    if season == "autumn":
        sc.decal("decor/leaves_autumn_1.png", 3, 3)
        sc.decal("decor/leaves_autumn_2.png", 5, 4)
    place_fences(sc, FENCE, {"w": "fences/fence_wood.png"}, {"G": ("w", "fences/gate_wood.png")})
    # trees & plants
    sc.put(f"trees/ashwood_{season}.png", 3, 3)
    sc.put(f"trees/pine_{season}.png", 6, 2)
    sc.put(f"trees/pine_{season}.png", 0, 4)
    sc.put(f"trees/ashwood_{season}.png", 17, 2)
    sc.put("trees/deadtree.png", 19, 10)
    sc.put(f"trees/sapling_2_{season}.png", 14, 3)
    sc.put(f"trees/sapling_1_{season}.png", 12, 1)
    sc.put(f"trees/sapling_0_{season}.png", 11, 2)
    sc.put(f"trees/bush_{season}.png", 7, 5)
    sc.put(f"trees/bush_large_{season}.png", 0.5, 10)
    sc.put("trees/ashwood_stump.png", 8, 8)
    # rocks & debris
    sc.put("debris/rock_small_1.png", 13, 5)
    sc.put("debris/rock_large_1.png", 4.5, 11)
    sc.put("debris/scrap_small_2.png", 19, 6)
    sc.put("debris/pebble_1.png", 16, 11)
    sc.put("debris/twig_1.png", 2, 0)
    sc.put(f"debris/weeds_{season}_1.png", 15, 4)
    sc.put(f"debris/weeds_{season}_2.png", 9, 10)
    sc.put(f"debris/tallgrass_{season}_1.png", 18, 11)
    sc.put(f"debris/tallgrass_{season}_2.png", 7, 11)
    sc.put("debris/junk_1.png", 13, 11)
    # props
    sc.put(frame_of("props/lamp_post.png", 1 if season == "winter" else 0, 16), 11, 6)
    sc.put("props/sign_post.png", 9, 6)
    sc.put("props/scarecrow.png", 15, 8)
    sc.put("props/barrel.png", 18, 5)
    sc.put("props/crate.png", 19, 5)
    sc.put("props/mailbox.png", 8, 1)
    sc.put("props/planter.png", 12, 5)
    sc.put(PLAYER, 10, 7)
    return sc


TOWN_GROUND = [
    "cccccccccccccccccccc",
    "cccccccccccccccccccc",
    "dddddddddccccddddddd",
    "gggggggggccccggggggg",
    "gggggggggccccggggggg",
    "gggggggggccccggggggg",
    "gggggggggccccggggggg",
    "gggggggdddcccddggggg",
    "ggggggddddccccdddggg",
    "gggggggggccccggggggg",
    "ggggggggggccgggggggg",
    "ggggggggggccgggggggg",
]
TOWN_FENCE = [
    "....................",
    "....................",
    "....................",
    "PPPPPPPP.....PPPPPPP",
    "P..................P",
    "P..................P",
    "P..................P",
    "P..................P",
    "P..................P",
    "P..................P",
    "P..................P",
    "Pcccc..........ccccP",
]


def town():
    sc = Scene(20, 12, "spring", seed=5)
    sc.grass()
    cell = lambda i, j: TOWN_GROUND[j][i]
    for name, chars in [("dirt", "d"), ("cobble", "c")]:
        sc.overlay(f"terrain/{name}.png", lambda i, j, ch=chars: cell(i, j) in ch,
                   f"terrain/{name}_full.png")
    for (i, j, n) in [(2, 5, 1), (16, 9, 2), (4, 9, 3), (17, 5, 4)]:
        sc.decal(f"decor/flowers_spring_{n}.png", i, j)
    place_fences(sc, TOWN_FENCE, {"P": "fences/fence_palisade.png", "c": "fences/fence_chainlink.png"})
    sc.put("props/water_tower.png", 4, 9)
    sc.put("props/market_stall.png", 15, 6)
    sc.put("props/well.png", 10.5, 9)
    sc.put(frame_of("props/wind_turbine.png", 1, 32), 17.5, 10)
    sc.put("props/laundry_line.png", 3, 5)
    sc.put(frame_of("props/fire_pit.png", 2, 16), 8, 6)
    sc.put("props/bench.png", 8.5, 5)
    sc.put(frame_of("props/lamp_post.png", 1, 16), 13, 4)
    sc.put(frame_of("props/lamp_post.png", 0, 16), 8, 9)
    sc.put("props/crate_stack.png", 18, 7)
    sc.put("props/crate.png", 17, 8)
    sc.put("props/water_barrel.png", 13, 8)
    sc.put("props/planter.png", 12, 4)
    sc.put("props/planter.png", 9, 4)
    sc.put("trees/ashwood_spring.png", 1, 10)
    sc.put("trees/bush_spring.png", 18, 4)
    sc.put(PLAYER, 11, 6)
    return sc


RUINS_GROUND = [
    "cccccccccccccccccccc",
    "cccccccccccccccrrccc",
    "ccrrcccccccccccrrrcc",
    "aaaaaaaaaaaaaaaaaaaa",
    "aaaaaaaaaaaaaaaaaaaa",
    "aaaaaaaaaaaaaaaaaaaa",
    "aaaaaaaaaaaaaaaaaaaa",
    "aaaaaarrraaaaaaaaaaa",
    "cccccrrrrrcccccccccc",
    "cccccrrrcccccccccrrc",
    "ccccccccccccccccrrrc",
    "cccccccccccccccccccc",
]


def ruins():
    sc = Scene(20, 12, "spring", seed=9)
    sc.base_full("terrain/rubble_ground_full.png")
    cell = lambda i, j: RUINS_GROUND[j][i]
    for name, chars in [("concrete", "c"), ("asphalt", "a"), ("rubble_ground", "r")]:
        sc.overlay(f"terrain/{name}.png", lambda i, j, ch=chars: cell(i, j) in ch,
                   f"terrain/{name}_full.png")
    sc.decal(frame_of("ruins/rad_puddle.png", 1, 32), 13, 9)
    sc.put("ruins/bus_wreck.png", 8.5, 5)
    sc.put("ruins/car_wreck_1.png", 2, 6)
    sc.put("ruins/car_wreck_2.png", 16, 4)
    sc.put("ruins/barricade.png", 15.5, 7)
    sc.put("ruins/traffic_cone.png", 13, 7)
    sc.put("ruins/traffic_cone.png", 18, 6)
    sc.put("ruins/dumpster.png", 1.5, 1)
    sc.put("ruins/streetlamp_broken.png", 4, 2)
    sc.put("ruins/streetlamp_broken.png", 12, 2)
    sc.put("ruins/rubble_pile_1.png", 6.5, 9)
    sc.put("ruins/rubble_pile_2.png", 17.5, 10)
    sc.put("ruins/concrete_barrier.png", 9.5, 2)
    sc.put(frame_of("ruins/locker.png", 0, 16), 14, 1)
    sc.put(frame_of("ruins/locker.png", 1, 16), 15, 1)
    sc.put(frame_of("ruins/fridge.png", 1, 16), 17, 1)
    sc.put(frame_of("ruins/supply_crate.png", 0, 16), 2, 10)
    sc.put("ruins/rad_barrel.png", 13, 10)
    sc.put("ruins/remains.png", 10, 10)
    sc.put("debris/scrap_large_1.png", 3.5, 11)
    sc.put("debris/junk_3.png", 9, 11)
    sc.put(PLAYER, 11, 8)
    return sc


# ------------------------------------------------------------------------------------------------
def wang_test(names, cols=14, rows=8, seed=3):
    """Random corner grids composited per terrain: proves any combination joins seamlessly."""
    tiles = []
    for name in names:
        r = random.Random(seed + len(name))
        sc = Scene(cols, rows, "spring", seed=seed)
        if name in ("asphalt", "concrete", "rubble_ground"):
            sc.base_full("terrain/rubble_ground_full.png" if name != "rubble_ground"
                         else "terrain/concrete_full.png")
        else:
            sc.grass()
        grid = [[r.random() < 0.5 for _ in range(cols)] for _ in range(rows)]
        anim = name == "water"
        sc.overlay(f"terrain/{name}.png", lambda i, j: grid[j][i], f"terrain/{name}_full.png",
                   animated=anim)
        tiles.append(sc.render(3))
    w = max(t.width for t in tiles)
    out = Image.new("RGBA", (w * 2 + 12, ((len(tiles) + 1) // 2) * (tiles[0].height + 12)),
                    (20, 20, 20, 255))
    for k, t in enumerate(tiles):
        out.paste(t, ((k % 2) * (w + 12), (k // 2) * (t.height + 12)))
    return out


def contact(paths, scale=4, cols=None, bg="grass", max_w=470, pad=6):
    """Flow-layout contact sheet (sprites bottom-aligned per row) on a real ground texture."""
    ims = [load(p) for p in paths]
    rows, row, x = [], [], pad
    for im in ims:
        if row and x + im.w + pad > max_w:
            rows.append(row)
            row, x = [], pad
        row.append(im)
        x += im.w + pad
    if row:
        rows.append(row)
    W = max_w
    H = sum(max(i.h for i in r) + pad for r in rows) + pad
    out = Canvas(W, H)
    g = load("terrain/grass_spring.png") if bg == "grass" else load("terrain/asphalt_full.png")
    n = g.w // 16
    for y in range(0, out.h, 16):
        for xx in range(0, out.w, 16):
            out.blit(sub(g, ((xx // 16 * 3 + y // 16 * 5) % n) * 16, 0, 16, 16), xx, y)
    y = pad
    for r in rows:
        rh = max(i.h for i in r)
        x = pad
        for im in r:
            out.blit(im, x, y + rh - im.h)
            x += im.w + pad
        y += rh + pad
    im = out.to_image()
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)


def main(argv):
    from env import lib as L
    import pathlib
    env = L.OUT
    for s in ("spring", "summer", "autumn", "winter"):
        save(settlement(s).render(4), f"settlement_{s}.png")
    save(town().render(4), "town_spring.png")
    save(ruins().render(4), "ruins_street.png")
    save(wang_test(["dirt", "soil", "soil_wet", "cobble", "gravel", "sand", "water", "asphalt",
                    "concrete", "rubble_ground"]), "wang_seams.png")

    def files(sub_):
        return sorted(str(p.relative_to(env)) for p in (env / sub_).glob("*.png"))
    save(contact(files("trees")), "contact_trees.png")
    save(contact(files("debris")), "contact_debris.png")
    save(contact(files("decor")), "contact_decor.png")
    save(contact(files("props")), "contact_props.png")
    save(contact(files("ruins"), bg="asphalt"), "contact_ruins.png")
    save(contact(files("fences")), "contact_fences.png")
    save(contact(files("terrain"), bg="asphalt"), "contact_terrain.png")
