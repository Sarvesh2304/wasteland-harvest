#!/usr/bin/env python3
"""Add missing glyphs (digits 0-9, slash, arrows, em dash, ellipsis) to the PixelLab 8px TTF.

Usage: python3 tools/font_add_glyphs.py <input.ttf> <output.ttf>

PixelLab's create_font reference layout ships no digits at all (verified 2026-07-08: two
independent generations both returned the same 65-char set) and no typographic punctuation.
The base font (art/ui/fonts/wasteland_harvest_ui.ttf, PixelLab job
8c4a9988-a6fa-4127-ba1a-afe9a91dc32d) is monospaced 4x6-pixel glyphs, 128 font units per
pixel, baseline at y=0, caps from y=0..768. New glyphs are hand-designed on the same grid at
the same stroke weight, one rectangle contour per horizontal pixel run. If the font is ever
regenerated from PixelLab, this script MUST be re-run on the fresh TTF or all digits vanish
from the HUD. Requires fontTools (pip install fonttools).

Idempotent (2026-10-08): a glyph that already exists is redrawn in place rather than appended a
second time, so the script can be re-run on the shipped TTF to add new glyphs (it was re-run
then to add the left/right arrows and the percent sign).
"""
import sys

from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen

PX = 128  # font units per pixel (upem 1024 / glyph_px 8)

# Rows top-to-bottom; top row sits at the 6px cap height (y = 768 down to y = 0).
GLYPHS = {
    0x30: ".##.|#..#|#..#|#..#|#..#|.##.",   # 0
    0x31: ".#..|##..|.#..|.#..|.#..|####",   # 1
    0x32: "###.|...#|.##.|#...|#...|####",   # 2
    0x33: "###.|...#|.##.|...#|...#|###.",   # 3
    0x34: "#..#|#..#|####|...#|...#|...#",   # 4
    0x35: "####|#...|###.|...#|...#|###.",   # 5
    0x36: ".###|#...|###.|#..#|#..#|.##.",   # 6
    0x37: "####|...#|..#.|.#..|.#..|.#..",   # 7
    0x38: ".##.|#..#|.##.|#..#|#..#|.##.",   # 8
    0x39: ".##.|#..#|#..#|.###|...#|###.",   # 9
    0x2F: "...#|..#.|..#.|.#..|.#..|#...",   # /
    0x2191: "..#..|.###.|#####|..#..|..#..|..#..",  # up arrow (5px wide for a pointed tip)
    0x2193: "..#..|..#..|..#..|#####|.###.|..#..",  # down arrow
    0x2014: "......|......|......|......|######|......",  # em dash (bar on row 4, like hyphen)
    0x2026: ".....|.....|.....|.....|.....|#.#.#",  # ellipsis
    0x2190: "......|..#...|.##...|######|.##...|..#...",  # left arrow (HUD truck marker)
    0x2192: "......|...#..|...##.|######|...##.|...#..",  # right arrow
    0x25: "#..#|...#|..#.|.#..|#...|#..#",  # percent (Town Works rewards: "10% more")
    0x2665: ".....|.#.#.|#####|#####|.###.|..#..",  # filled heart (friendship, PEOPLE tab)
    0x2661: ".....|.#.#.|#.#.#|#...#|.#.#.|..#..",  # empty heart
}

# Typographic chars that appear in lore/dialogue text, mapped onto existing glyphs so they
# never hit the (blurry, anti-aliased) system fallback font.
ALIASES = {
    0x2013: 0x2D,   # en dash -> hyphen
    0x2018: 0x27,   # left single quote -> apostrophe
    0x2019: 0x27,   # right single quote -> apostrophe
    0x201C: 0x22,   # left double quote -> quotedbl
    0x201D: 0x22,   # right double quote -> quotedbl
}

src, dst = sys.argv[1], sys.argv[2]
f = TTFont(src)
glyf, hmtx, cmaps = f["glyf"], f["hmtx"], f["cmap"].tables
order = f.getGlyphOrder()

for code, art in sorted(GLYPHS.items()):
    rows = art.split("|")
    width_px = len(rows[0])
    name = "uni%04X" % code
    pen = TTGlyphPen(None)
    top = len(rows)  # top row's upper edge in px above baseline (6 = cap height)
    for r, row in enumerate(rows):
        y1 = (top - r) * PX      # upper edge of this pixel row
        y0 = y1 - PX
        x = 0
        while x < width_px:
            if row[x] == "#":
                run = x
                while run < width_px and row[run] == "#":
                    run += 1
                pen.moveTo((x * PX, y0))
                pen.lineTo((run * PX, y0))
                pen.lineTo((run * PX, y1))
                pen.lineTo((x * PX, y1))
                pen.closePath()
                x = run
            else:
                x += 1
    glyph = pen.glyph()
    glyph.recalcBounds(glyf)
    if name not in order:
        order.append(name)
    glyf[name] = glyph
    hmtx[name] = ((width_px + 1) * PX, glyph.xMin)  # glyph width + 1px spacing, like base glyphs
    for table in cmaps:
        if table.isUnicode():
            table.cmap[code] = name

base_cmap = f.getBestCmap()
for code, target in ALIASES.items():
    name = base_cmap.get(target) or "uni%04X" % target
    for table in cmaps:
        if table.isUnicode():
            table.cmap[code] = name

f.setGlyphOrder(order)
if hasattr(f["post"], "extraNames"):
    f["post"].extraNames = []  # let compile regenerate names for the new glyphs
f.save(dst)
print("added %d drawn glyphs + %d cmap aliases -> %s" % (len(GLYPHS), len(ALIASES), dst))
