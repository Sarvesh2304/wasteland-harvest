"""The app icon (Milestone E, exported builds): a seedling in tilled soil in front of a ruined
skyline under an amber dusk sky — the game in one picture: a farm, with a wasteland beyond.

Drawn at 32x32 from ASCII rows in the house palette (tools/art/palette.py), then scaled up
nearest-neighbour. Deterministic. Writes:
  art/ui/app_icon/icon_32.png, icon_256.png, icon_512.png  (512 for macOS)
  art/ui/app_icon/icon.ico                                  (16-256, Windows)
  icon.png                                                  (project icon, 256)
Usage: python3 tools/art/build_all.py app_icon
"""
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "art"))
import palette as P  # noqa: E402

SKY = ["#5a3a4a", "#5a3a4a", "#5a3a4a", "#8a4a3c", "#8a4a3c", "#8a4a3c", "#c46a32", "#c46a32",
       "#c46a32", P.AMBER, P.AMBER, P.AMBER, P.AMBER, "#e9b35a", "#e9b35a", "#e9b35a"]
SUN = (22, 13, 4.6)
SKYLINE = "#3e3030"
SKYLINE_LIT = "#5a4440"
# Ruined towers: (x0, x1, top row, broken-top pattern of row offsets per column).
TOWERS = [
    (2, 5, 9, [1, 0, 0, 2]),
    (6, 8, 12, [0, 1, 0]),
    (9, 13, 7, [2, 0, 0, 1, 3]),
    (14, 16, 11, [0, 0, 1]),
    (17, 18, 14, [0, 1]),
    (24, 27, 10, [0, 2, 0, 1]),
    (28, 30, 13, [1, 0, 0]),
]
WINDOWS = [(3, 12), (11, 10), (12, 14), (10, 16), (25, 13), (26, 16), (15, 15)]
GROUND = 19
SOIL_TOP = 26


def draw() -> Image.Image:
    img = Image.new("RGBA", (32, 32))
    px = img.load()

    def put(x, y, color):
        if 0 <= x < 32 and 0 <= y < 32:
            px[x, y] = Image.new("RGBA", (1, 1), color).getpixel((0, 0))

    for y in range(32):
        for x in range(32):
            put(x, y, SKY[min(y, len(SKY) - 1)])
    sx, sy, r = SUN
    for y in range(32):
        for x in range(32):
            d = ((x - sx) ** 2 + (y - sy) ** 2) ** 0.5
            if d <= r - 1.2:
                put(x, y, P.CREAM)
            elif d <= r:
                put(x, y, P.LAMPLIGHT)
    for x0, x1, top, jag in TOWERS:
        for i, x in enumerate(range(x0, x1 + 1)):
            for y in range(top + jag[i % len(jag)], GROUND + 1):
                put(x, y, SKYLINE)
        # a lit edge on the sun side
        for y in range(top + jag[-1], GROUND + 1):
            put(x1, y, SKYLINE_LIT)
    for x, y in WINDOWS:
        put(x, y, P.LAMPLIGHT)
    # The fence line, then the field.
    for y in range(GROUND + 1, 32):
        for x in range(32):
            put(x, y, P.SOIL_RAMP[2] if y < SOIL_TOP else P.SOIL_RAMP[1])
    for x in range(1, 31):
        put(x, GROUND + 1, P.WOOD_RAMP[1])
        if x % 4 == 1:
            put(x, GROUND, P.WOOD_RAMP[2])
            put(x, GROUND + 2, P.WOOD_RAMP[1])
    # Furrows.
    for y in (SOIL_TOP + 1, SOIL_TOP + 3):
        for x in range(2, 30, 3):
            put(x, y, P.SOIL_RAMP[0])
            put(x + 1, y, P.SOIL_RAMP[3])
    # The seedling: a stem and two broad leaves, big enough to read at 16 px.
    stem = P.LEAF_RAMP[2]
    for y in range(22, SOIL_TOP + 1):
        put(15, y, stem)
        put(16, y, P.LEAF_RAMP[1])
    leaf_l = [(10, 19), (11, 18), (12, 18), (13, 19), (14, 20), (11, 19), (12, 19), (13, 20),
              (12, 20), (11, 20), (13, 21), (14, 21)]
    leaf_r = [(21, 18), (20, 17), (19, 17), (18, 18), (17, 19), (20, 18), (19, 18), (18, 19),
              (19, 19), (20, 19), (18, 20), (17, 20)]
    for x, y in leaf_l:
        put(x, y + 1, P.LEAF_RAMP[4])
    for x, y in leaf_r:
        put(x, y + 1, P.LEAF_RAMP[4])
    for x, y in [(11, 19), (12, 19), (19, 18), (20, 18)]:
        put(x, y, P.LEAF_RAMP[5])
    for x, y in [(13, 21), (12, 21), (18, 20), (19, 20)]:
        put(x, y + 1, P.LEAF_RAMP[3])
    for y in range(20, 23):
        put(15, y, stem)
    # A mound of fresh soil at the root.
    for x in range(13, 19):
        put(x, SOIL_TOP, P.SOIL_RAMP[3])
    for x in range(14, 18):
        put(x, SOIL_TOP - 1, P.SOIL_RAMP[4])
    # Frame.
    for i in range(32):
        for x, y in ((i, 0), (i, 31), (0, i), (31, i)):
            put(x, y, P.OUTLINE_WARM)
    return img


def main():
    out = ROOT / "art" / "ui" / "app_icon"
    out.mkdir(parents=True, exist_ok=True)
    base = draw()
    base.save(out / "icon_32.png")
    for size in (256, 512):
        base.resize((size, size), Image.NEAREST).save(out / f"icon_{size}.png")
    big = base.resize((256, 256), Image.NEAREST)
    big.save(out / "icon.ico", sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    big.save(ROOT / "icon.png")
    print("[app_icon] wrote icon_32/256/512.png, icon.ico, icon.png")


if __name__ == "__main__":
    main()
