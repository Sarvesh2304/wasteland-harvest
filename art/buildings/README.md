# Building Art — Phase 6 "Art pass 1" (buildings half) — PixelLab Provenance

The 10 building KINDS from `scripts/structures.gd`'s `BUILDING_COLORS` (previously flat-color
ColorRect placeholder volumes, Phase 4), one generation per kind — every instance of a kind
(e.g. all 4 town shacks) shares one texture. Consumed by `structures.gd`'s
`_building_texture()`: real art when `art/buildings/<kind>.png` exists, flat-color fallback
otherwise (same pattern as `farm.gd`'s `_crop_texture()`).

## Generation parameters (all 10 objects)

`mcp__pixellab__create_map_object`, **basic mode** (no `background_image`): this codebase
renders buildings as separate sprites floating over the ground TileMapLayers, not painted into
the tilemap, so a transparent-background standalone object is the architecturally correct fit —
style-matching/inpainting mode would have baked ground pixels into the sprite's context for no
benefit. Shared parameters, chosen to sit between the two established passes:

- `view: low top-down` — matches the player/NPC characters, NOT the ground tiles' `high
  top-down`. Same reasoning as the character pass: Stardew's actual mix is flat floors +
  forced-perspective everything-on-top; buildings show facades in that projection.
- `shading: basic shading` — matches both the tiles and characters.
- `detail: low detail` — matches the characters; at 16-64px canvases, higher detail turns to
  noise.
- `outline: single color outline` — the character convention; buildings are sprites that need
  to pop off the ground layer, unlike the `lineless` tiles they sit on.

Every prompt anchors the kind's `BUILDING_COLORS` placeholder hex as its dominant material tone
(the color-identity relationship the NPC pass established) and quotes `MAPS.md` §2's building
description where one exists. All hexes are GDD.md §9 settlement-anchor/seasonal palette values.

## The sub-32px sizing resolution (5 kinds)

`create_map_object`'s minimum canvas is 32x32, but 5 kinds (chest, bulletin_board, bed,
shipping_box, shelter_tent) have 1x1-cell (16x16) footprints. **Resolution: generate at 32x32
(an exact 2x integer multiple, prompted to fill the canvas), then downscale 2x to 16x16.**
The alternative (keep 32x32, let the sprite overhang its footprint, per the CLAUDE.md
sprite-beyond-tile precedent) was rejected for a concrete reason: three of the five kinds sit
on *adjacent* cells (the farmhouse service row — chest x16 / shipping box x17 / bed x18), so
32px-wide sprites on 16px cells would opaquely overlap each other.

Downscale kernel (verified visually against alternatives, comparison sheets in the session
scratchpad): **modal-block** — each output pixel takes the most frequent color among its 2x2
source block's opaque pixels (alpha >= 200; blocks with <2 opaque pixels go transparent).
Chosen over plain nearest-neighbor (broke up the bed frame and shipping-box panels) and over
box-average (blurry anti-aliased edges that clash with the game's nearest-filtered look) and
over box-average + palette-snap (averaged the chest's small gold clasp out of existence, which
modal-block preserves). Applied uniformly to all five kinds. Script: one-off inline python
(PIL) in the build session, logic documented above.

Multi-cell kinds were generated at their exact footprint pixel size and are used as-is,
unscaled (the API honored non-square sizes in the downloaded file even though the status page
reports a square canvas).

## The 10 objects (all generated 2026-07-10, one accepted attempt each, no rejects)

| Kind | Object id | Canvas -> shipped | Identity hex anchored |
|---|---|---|---|
| `farmhouse` | `4cb5b4e3-33c4-41b2-9d9d-808d42e5823e` | 48x32 as-is | `#7b5025` worn wood dark |
| `mayor_house` | `7372f8e3-49b5-47cf-9d8f-50965dbab942` | 64x48 as-is | `#9d9180` scavenged metal |
| `store` | `09bd4bc0-463a-4a1c-b93e-763a43e1fdd3` | 48x32 as-is | `#e1982a` dusty amber |
| `shack` | `1884aa0f-3944-4135-9f4b-8837c9b8e9ca` | 32x32 as-is | `#b77c3e` worn wood light |
| `storage_shed` | `dbc05587-60bd-4a41-8730-06c1d9785ccd` | 32x32 as-is | `#7d452a` rusted iron-brown |
| `chest` | `efa03430-255c-4f0e-88cc-8ec4e9e5fbed` | 32x32 -> 16x16 | `#ffc948` lamplight gold |
| `bulletin_board` | `01cdb0a2-79d7-4009-a801-a4fdf737d9e2` | 32x32 -> 16x16 | `#ffedb1` worn cream |
| `bed` | `74ac7133-7299-42e3-b8b1-c9ca2ff414f7` | 32x32 -> 16x16 | `#f3acb7` mutant blossom pink |
| `shipping_box` | `89248359-0c56-446c-be19-116f95c79ddd` | 32x32 -> 16x16 | `#c5520f` rust red |
| `shelter_tent` | `bb1302a9-3237-478e-8c27-c79017be9116` | 32x32 -> 16x16 | `#95ac49` faded field green |

Design-brief sources per kind: `MAPS.md` §2 ("derelict, weathered home"; "half town hall, half
keep, concrete-patched walls"; "scavenged-metal awning, crates out front"; "patched-plank"
shacks; "worn-paper notice board") and `data/buildings.json`'s descriptions ("salvaged-tarp
lean-to"; "scrap-sheet storage hut").

**Note on the PixelLab account objects:** map objects auto-delete after 8 hours (unlike
characters/tilesets) — the ids above are historical provenance, not retrievable assets. The
shipped PNGs here are the only copies.

**Palette note:** these were generated directly against the *boosted* (Phase 3-revised) GDD §9
hex values, so unlike the Phase 1-2 art they need no retroactive HSV boost.
