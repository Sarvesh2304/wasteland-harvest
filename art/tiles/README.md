# Tile Art — Phase 1 Test Set

First PixelLab-generated test tiles (Phase 1 "first test tiles" checklist item; also substitutes
for the now-skipped Aseprite checklist item, which named the same four tile types: soil, grass,
ruin rubble, wood planks). Generated with `create_topdown_tileset` per `CLAUDE.md`'s art
pipeline (top-down Wang tilesets, not `create_isometric_tile` — this project's grid is plain
top-down), at the locked 16x16px tile size, using the settlement anchor palette from `GDD.md`
§9.

Each `create_topdown_tileset` call generates one 16-tile Wang sheet blending two terrain types
(16 tiles of 16x16px each, sheet image 64x64px), which is why two calls cover all four requested
tile types:

## `settlement/grass_soil_tileset.png` + `.json`

Faded field green grass (`#8a9a56` grass with `#c9974b` dusty amber dry patches) blending into
tilled farm soil (`#7a5a3c` with `#241a10` furrow shadow) — covers **grass** and **soil**
(untilled/tilled ground) from the Phase 1 checklist in one connected sheet, so the grass-to-farm
transition tiles farmland naturally against surrounding meadow.

## `ruins/rubble_planks_tileset.png` + `.json`

Concrete ruin rubble (`#6f6f68` / `#4a4a44` with `#7d452a` rust and `#5c5347` ash debris)
blending into worn wooden plank flooring (`#a37b50` boards with `#6e5033` dark seams) — covers
**ruin rubble** and **wood planks** in one connected sheet (useful later for salvaged-wood floor
patches inside ruined structures).

## Metadata

The `.json` files alongside each PNG are PixelLab's tile metadata (per-tile terrain-corner
data). As of Phase 2 they are consumed: `scripts/wang_tileset.gd` encodes the corner→atlas
lookup derived from them (both sheets share the same tileset15 layout), the map painter in
`scripts/test_map.gd` uses it, `tilemaps/wasteland_tileset.tres` wraps both PNGs as atlas
sources (rubble tiles carry world-layer collision), and `tests/test_wang_tileset.gd`
cross-validates the lookup table against these JSON files so table and art can't drift.

## Provenance

Both tilesets were generated via `mcp__pixellab__create_topdown_tileset` (`view: high top-down`,
`detail: medium detail`, `shading: basic shading`, `outline: lineless`, `tile_size: 16x16`):

- Settlement sheet: tileset id `abb766dd-ebda-4f0e-a587-39aa21cf613c`
- Ruins sheet: tileset id `598d94d3-affa-4937-92fa-08e3da44589a`

## Revision note (Phase 3): settlement palette boosted, ruins left alone

`grass_soil_tileset.png`'s actual pixel colors were brightened/saturated in place (HSV
saturation ×1.30, value ×1.12) as part of a Phase 3 palette fix — see `GDD.md` §9's "Revision
note." The hex values in this file's own description above are the *original* generation-prompt
colors (accurate history of what was asked for), not what's currently in the PNG.

`rubble_planks_tileset.png` was deliberately left untouched, including its wood-plank tiles
(which nominally share the settlement anchor's "worn wood" hex identity) — the whole sheet was
treated as one ruins-palette unit rather than re-touching individual tiles within it, since
splitting one blended Wang sheet by sub-region wasn't worth the precision for a single tileset.
Worth a look if/when Phase 9 gives ruins interiors real dedicated content.
