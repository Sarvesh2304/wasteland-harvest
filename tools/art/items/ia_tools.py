"""Tool icons: hoe, watering can, axe, pickaxe, scythe (4 tiers each), fishing rod, bag.

Shared composition: wooden handle on the 45-degree diagonal from bottom-left to top-right, metal
head at the top-right. Tiers only swap materials / accents:
  1 rusty iron (brown-orange)          2 patched (iron with copper patches + copper ferrule)
  3 reinforced (clean grey steel, dark band + bright rivet)
  4 pre-war (blue steel, gold trim and ferrule, dark polished handle)

ASCII legend used by every handle tool:
  w handle   g grip tape   h head metal   H lit head   d shaded head   E bright edge / tip
  f ferrule (tier fitting colour)   p patch (tier 2 copper)   b band (tier 3 dark steel / tier 4 gold)
  r rivet (tier-coloured single pixel)
"""
from __future__ import annotations

import ia_lib as L
from ia_lib import Ramp
from ia_common import C

TIERS = {
    1: dict(head=Ramp(C.RUST[1:]), fit=Ramp(C.RUST[:5]), patch=None, band=None,
            handle=Ramp(C.WOOD[1:]), rivet=C.RUST[0]),
    2: dict(head=Ramp(C.IRON[1:]), fit=Ramp(C.COPPER[1:]), patch=Ramp(C.COPPER[1:]), band=None,
            handle=Ramp(C.WOOD[1:]), rivet=C.COPPER[5]),
    3: dict(head=Ramp(C.STEEL[1:]), fit=Ramp(C.STEEL[:5]), patch=None, band=Ramp(C.STEEL[:4]),
            handle=Ramp(C.WOOD[1:]), rivet=C.STEEL[5]),
    4: dict(head=Ramp(C.BLUE_STEEL[1:]), fit=Ramp(C.GOLD[1:]), patch=None, band=Ramp(C.GOLD[1:]),
            handle=Ramp(C.WOOD_DARK_POLISH[1:]), rivet=C.GOLD[5]),
}
GRIP_TAPE = Ramp(["#5e5646", "#8c826a", "#bcb294", "#ddd4b8"])


def build(rows, tier, accents=None):
    """Render a handle tool. `accents` maps tier -> list of (x, y, key) overlays where key is one
    of f/p/b/r/E/H/d; they are painted on top of the base ASCII."""
    t = TIERS[tier]
    rows = [list(r) for r in L.grid(rows)]
    for (x, y, key) in (accents or {}).get(tier, []):
        rows[y][x] = key
    s = L.Sprite()
    n = len(t["head"])
    lays = {
        "w": s.layer(t["handle"], "cyl", axis=45, contrast=2.2),
        "g": s.layer(GRIP_TAPE, "cyl", axis=45, contrast=2.0),
        "f": s.layer(t["fit"], "flat", sep="outer"),
        "h": s.layer(t["head"], "flat", sep="outer", cast=True),
        "p": s.layer(t["patch"] or t["head"], "flat"),
        "b": s.layer(t["band"] or t["head"], "flat", bevel_light=False),
    }
    legend = {"w": "w", "g": "g", "f": "f", "h": "h", "p": "p", "b": "b",
              "E": ("h", n - 1), "H": ("h", n - 2), "d": ("h", 1), "D": ("h", 0)}
    L.paint(lays, ["".join(r) for r in rows], legend)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "r":
                s.put(x, y, t["rivet"], t["head"])
            elif ch == "k":   # rust pit
                s.put(x, y, C.RUST_PIT, t["head"])
    return s.render()


# ----------------------------------------------------------------------------------------------

HOE = """
................
................
................
.........hhH....
........wwhhh...
.......ww..hhh..
......ww...hhh..
.....ww...hhhh..
....ww....hhhh..
...ww....EEEEE..
..gg............
..g.............
................
................
................
................
"""
HOE_ACC = {
    1: [(12, 6, "k"), (11, 8, "k")],
    2: [(11, 6, "p"), (12, 6, "p"), (12, 7, "p"), (11, 7, "p"), (9, 4, "f"), (8, 4, "f"), (13, 8, "r")],
    3: [(10, 7, "b"), (11, 7, "b"), (12, 7, "b"), (13, 7, "b"), (11, 7, "r"), (9, 4, "f"), (8, 4, "f")],
    4: [(9, 3, "b"), (10, 3, "b"), (9, 4, "f"), (8, 4, "f"), (10, 8, "b"), (11, 8, "b"), (12, 8, "b"), (13, 8, "b")],
}

AXE = """
................
................
........EHh..w..
.......EHhh.ww..
......EHhhhhw...
.....EHhhhhhh...
....EEhhhhhhd...
........whdd....
.......ww.......
......ww........
.....ww.........
....ww..........
...ww...........
..ww............
................
................
"""
AXE_ACC = {
    1: [(9, 4, "k"), (8, 5, "k")],
    2: [(8, 4, "p"), (9, 4, "p"), (8, 5, "p"), (7, 5, "p"), (9, 5, "r"), (8, 7, "f"), (7, 8, "f")],
    3: [(8, 6, "b"), (9, 5, "b"), (10, 4, "b"), (9, 5, "r"), (8, 7, "f"), (7, 8, "f")],
    4: [(10, 6, "b"), (11, 5, "b"), (9, 7, "b"), (10, 7, "b"), (11, 6, "b"), (8, 7, "f"), (7, 8, "f")],
}

PICK_HALF = """
................
................
...Ehhh.........
....hhhhhh......
......hhhhh.....
........hhhh....
.........ww.....
........ww......
.......ww.......
......ww........
.....ww.........
....ww..........
...ww...........
..ww............
................
................
"""


def _mirror_pick(rows):
    g = [list(r) for r in L.grid(rows)]
    src = [r[:] for r in g]
    for y in range(16):
        for x in range(16):
            c = src[y][x]
            if c in "hHEdT":
                mx, my = 15 - y, 15 - x
                if g[my][mx] in ".w":
                    g[my][mx] = c
    return ["".join(r) for r in g]


PICK = "\n".join(_mirror_pick(PICK_HALF))
PICK_ACC = {
    1: [(6, 3, "k"), (12, 9, "k")],
    2: [(9, 4, "p"), (10, 4, "p"), (9, 5, "p"), (10, 5, "r"), (8, 7, "f"), (9, 6, "f"), (10, 6, "f")],
    3: [(9, 4, "b"), (10, 5, "b"), (11, 6, "b"), (10, 5, "r"), (9, 6, "f"), (10, 6, "f")],
    4: [(9, 4, "b"), (10, 4, "b"), (10, 5, "b"), (11, 5, "b"), (11, 6, "b"), (9, 6, "f"), (10, 6, "f")],
}

SCYTHE = """
................
................
.......hhhh..w..
....hhhhhhhhww..
...hhEEE...hhw..
..hhE.....ww....
..hE.....ww.....
..E.....ww......
.......ww.......
......ww........
.....ww.........
....ww..........
...ww...........
..ww............
................
................
"""
SCY_ACC = {
    1: [(7, 3, "k"), (9, 2, "k")],
    2: [(9, 3, "p"), (10, 3, "p"), (10, 2, "p"), (11, 3, "r"), (10, 5, "f"), (11, 5, "f")],
    3: [(10, 2, "b"), (10, 3, "b"), (11, 4, "b"), (11, 3, "r"), (10, 5, "f"), (11, 5, "f")],
    4: [(7, 2, "b"), (8, 2, "b"), (9, 2, "b"), (10, 2, "b"), (10, 5, "f"), (11, 5, "f"), (11, 4, "b"), (12, 4, "b")],
}


def hoe(tier=1):
    return build(HOE, tier, HOE_ACC)


def axe(tier=1):
    return build(AXE, tier, AXE_ACC)


def pickaxe(tier=1):
    return build(PICK, tier, PICK_ACC)


def scythe(tier=1):
    return build(SCYTHE, tier, SCY_ACC)


# ----------------------------------------------------------------------------------------------
# watering can (tiered: body in head metal, bands/rose in fitting colour)
# ----------------------------------------------------------------------------------------------

def watering_can(tier=1):
    t = TIERS[tier]
    s = L.Sprite()
    lays = {
        "a": s.layer(t["head"], "flat", base=1, lit=2, dark=0),
        "s": s.layer(t["head"], "cyl", axis=45, contrast=2.0),
        "b": s.layer(t["head"], "cyl", axis=90, contrast=2.4, gloss=True, gloss_cut=0.8, sep="outer"),
        "R": s.layer(t["fit"] if tier > 1 else Ramp(C.RUST[2:]), "flat", sep="outer"),
        "t": s.layer(t["head"] if tier == 1 else (t["band"] or t["fit"]), "cyl", axis=90, contrast=2.0),
        "o": s.layer(Ramp(C.IRON[:3]), "solid", index=0),
    }
    L.paint(lays, L.grid(CAN), {"a": "a", "s": "s", "b": "b", "R": "R", "t": "t", "o": "o"})
    if tier == 1:
        s.put(4, 11, C.RUST_PIT, t["head"])
        s.puts([(6, 10), (7, 10)], C.IRON[3], t["head"])      # the tin patch on the old can
    elif tier == 2:
        s.puts([(4, 11), (5, 11), (4, 12)], C.COPPER[3], t["head"])
        s.put(5, 12, C.COPPER[5], t["head"])
    elif tier == 3:
        s.puts([(3, 10), (6, 10)], C.STEEL[5], t["head"])
    return s.render()


CAN = """
................
................
................
.............R..
...aaa......RR..
..a...a....sRR..
..a...a...ss....
..bbbbbb.ss.....
..boooob.s......
..bbbbbbss......
..ttttttts......
..bbbbbbb.......
..bbbbbbb.......
...bbbbb........
................
................
"""


# ----------------------------------------------------------------------------------------------
# fishing rod: bamboo rod, cork grip, little reel, wire line and a red/cream float
# ----------------------------------------------------------------------------------------------

def fishing_rod(tier=1):
    s = L.Sprite()
    rod = s.layer(Ramp(C.BAMBOO[1:]), "flat", base=1, lit=2, dark=0)
    rod.ascii(L.grid("""
        .............#..
        ............#...
        ...........#....
        ..........#.....
        .........#......
        ........#.......
        .......#........
        ......#.........
    """), 0, 2)
    # bamboo nodes
    node = s.layer(Ramp(C.BAMBOO[:3]), "solid", index=0)
    node.px((11, 4), (8, 7))
    grip = s.layer(Ramp(C.CANVAS[1:5]), "cyl", axis=45, contrast=2.0)
    grip.ascii(L.grid("""
        .....##.........
        ....##..........
        ...##...........
        ..##............
    """), 0, 10)
    reel = s.layer(Ramp(C.IRON[1:]), "sphere", contrast=2.2, sep="outer")
    reel.ascii(L.grid("""
        ......##........
        ......##........
    """), 0, 11)
    float_r = s.layer(Ramp(C.PLASTIC_RED), "sphere", contrast=2.0)
    float_r.px((12, 10), (13, 10))
    float_w = s.layer(Ramp(C.CLOTH_WHITE[1:]), "sphere", contrast=2.0)
    float_w.px((12, 11), (13, 11))
    img = s.render()
    # wire line (drawn after the outline so it stays a hair-thin 1 px line)
    line = L.rgba(C.TIN[3])
    for y in range(3, 10):
        if img[y, 13, 3] == 0:
            img[y, 13] = line
    img[2, 14] = (0, 0, 0, 0)
    return img


# ----------------------------------------------------------------------------------------------
# legacy scavenger's bag: a canvas satchel with a flap and strap
# ----------------------------------------------------------------------------------------------

def bag(tier=1):
    s = L.Sprite()
    strap = s.layer(Ramp(C.LEATHER[1:]), "flat", base=1, lit=2, dark=0)
    strap.ascii(L.grid("""
        .....######.....
        ....#......#....
        ...#........#...
    """), 0, 2)
    body = s.layer(Ramp(C.CANVAS[1:]), "inflate", contrast=2.2, bevel=3)
    body.ascii(L.grid("""
        ..##########....
        ..###########...
        ..###########...
        ..###########...
        ..###########...
        ..###########...
        ...#########....
    """), 0, 6)
    body.px((13, 7), (13, 8), (13, 9), (13, 10), (13, 11), add=True)
    flap = s.layer(Ramp(C.CANVAS[:5]), "flat", sep="outer", cast=True, base=3, lit=4, dark=2)
    flap.ascii(L.grid("""
        ..###########...
        ..###########...
        ...#########....
        .....#####......
    """), 0, 5)
    buckle = s.layer(Ramp(C.BRASS[1:]), "flat", sep="outer")
    buckle.px((7, 9), (8, 9))
    patch = s.layer(Ramp(C.CLOTH_RED[1:]), "flat")
    patch.px((10, 11), (11, 11), (10, 12), (11, 12))
    return s.render()


TIERED = {"hoe": hoe, "watering_can": watering_can, "axe": axe, "pickaxe": pickaxe, "scythe": scythe}
ICONS = {"hoe": hoe, "watering_can": watering_can, "axe": axe, "pickaxe": pickaxe, "scythe": scythe,
         "fishing_rod": fishing_rod, "bag": bag}
