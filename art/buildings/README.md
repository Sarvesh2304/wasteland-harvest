# Building Art — Phase 6 "Art pass 1" (buildings half) — PixelLab Provenance

The 10 building KINDS from `scripts/structures.gd`'s `BUILDING_COLORS` (previously flat-color
ColorRect placeholder volumes, Phase 4), one generation per kind — every instance of a kind
(e.g. all 4 town shacks) shares one texture. Consumed by `structures.gd`'s
`_building_texture()`: real art when `art/buildings/<kind>.png` exists, flat-color fallback
otherwise (same pattern as `farm.gd`'s `_crop_texture()`).

## Generation parameters (all 10 objects) — SUPERSEDED, see "Revision note" below

**2026-07-10 update: the `view`/`shading` choices below read as too 3D/isometric in play and
were replaced (`view: high top-down` + `shading: flat shading`) — see the "Revision note"
section at the end of this file for what changed and why. This section is left as-is for
historical record of the original Phase 6 pass; the shipped PNGs reflect the revision, not
this section.**

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

## Revision note (2026-07-10, same session as Phase 6's first buildings pass): too 3D/isometric

**The problem:** after playing the game, Sarvesh's exact feedback on
`build/screenshots/shot_buildings_blueprint_vs_complete_4x.png` (Mayor Harlan's fortified house,
the worst offender) was that the art "looks 3D, instead of top-down 2D with a little depth for
3D-like effect of Stardew Valley." On inspection this was correct: the original pass's
`view: low top-down` gave every building visible converging left-face/right-face/roof-face
shading — a real rendered 3D box volume, reading as a small isometric diorama sitting on its own
dirt-patch base, not Stardew's actual building convention (a flat front elevation with a bit of
roof visible from above). This is the same class of problem `CLAUDE.md` explicitly chose plain
top-down to avoid (learned the hard way in Blood Fields: Empires) — it had crept back in via an
art-generation-parameter choice, not an engine/architecture one, since `low top-down` was
originally chosen to match the *characters*, not because it suited architecture.

**What was tested:** ran 7 candidates of `mayor_house` (the flagged offender) varying `view`
(`low top-down` vs `high top-down`) and `shading` (`basic shading` vs `flat shading`), all at
64x48, basic mode, before touching any other kind:

| Candidate | view | shading | Verdict |
|---|---|---|---|
| A | high top-down | basic shading | Still a rendered 3D box (dark blue slate roof implies real volume) |
| B | low top-down | basic shading | Same as the original shipped art — isometric diorama |
| **C** | **high top-down** | **flat shading** | **Flat front-facing gable, no converging side faces — winner** |
| D | low top-down | flat shading | Still shows a visible left wall + ground plinth |
| E | high top-down | flat shading (verbose color prompt) | Still isometric — extra prompt detail didn't fix it, shading did |
| F | high top-down | flat shading ("no side walls" prompt wording) | Still isometric — anti-3D prompt language alone doesn't work |
| G | side | flat shading | Isometric corner view, worse than C |

The deciding factor was **`shading: flat shading` combined with `view: high top-down`**, not
elaborate anti-isometric prompt wording (E, F, G tried that and still came out isometric) — flat
shading removes the per-face gradient that PixelLab uses to imply a 3D volume, and `high
top-down` (the same flatter looking-straight-down angle already used for ground tiles) supplies
a front elevation instead of a 3/4 character-style angle. `detail: low detail` and `outline:
single color outline` were kept unchanged from the original pass (not the source of the
problem).

**What changed:** all 10 kinds regenerated with `view: high top-down`, `shading: flat shading`,
`detail: low detail`, `outline: single color outline`, basic mode (no `background_image`) — the
same recipe as candidate C above, applied uniformly. Per-kind `BUILDING_COLORS` identity-anchor
hex, footprint pixel sizes, and canvas-vs-shipped sizing are all **unchanged** from the table
above (still one generation per kind, same dimensions). The 5 kinds needing the 32x32-generate
to 16x16-modal-block-downscale treatment (chest, bulletin_board, bed, shipping_box,
shelter_tent) needed one extra prompt-wording round each after the first flat-shading pass still
came out corner-view-y at that small a canvas (small square objects without an obvious "front"
default to a 3/4 corner view even under flat shading) — adding explicit "flat front view... no
corner angle" (chest, shipping_box) or "viewed straight from above... no perspective tilt" (bed)
language to the description fixed it. `bulletin_board` and `shelter_tent` came out flat on the
first flat-shading attempt with no extra wording needed. The modal-block downscale kernel
(unchanged from the original pass, same alpha>=200 / most-frequent-color-per-2x2-block logic)
was re-verified against the new flatter-style art and still reads well at 16x16 — the smaller
canvas loses some fine detail (shelter_tent's tent shape gets a little mushy) but no worse than
the original pass's downscale, and no kind's identity color got lost.

**New object ids (all generated 2026-07-10, this revision):**

| Kind | Object id | Recipe notes |
|---|---|---|
| `mayor_house` | `8198e633-3009-4e74-9251-ba2a73e3c324` | Candidate C, the winning recipe |
| `store` | `78a51e4e-d630-4a6a-bf5e-8e19d96f11cc` | First attempt at winning recipe |
| `farmhouse` | `6dd79dbb-da9c-49ba-bf4b-4073133036bd` | First attempt at winning recipe |
| `shack` | `192ce50f-6560-4535-b611-6b7115e97aca` | Second attempt — added "dollhouse front, no corner angle" wording |
| `storage_shed` | `167b1de0-3169-4198-be00-851888bef003` | Second attempt — same added wording |
| `chest` | `8a2897d7-1c2b-4559-b2bd-fe7cfe5ea9ed` | Second attempt — added "flat front view...no corner angle" wording |
| `bulletin_board` | `42a62c67-9ecc-4493-827e-73e9515d7f1d` | First attempt, no extra wording needed |
| `bed` | `1e8e1c7b-5167-4882-b95c-4d4c5ab8d0d8` | Second attempt — added "viewed straight from above...no perspective tilt" wording |
| `shipping_box` | `f5d92b6c-5fe4-451e-bf46-a1c37030757a` | Second attempt — same "flat front view" wording as chest |
| `shelter_tent` | `7a5f1375-3b21-475f-8f45-a6dad7f230f4` | First attempt, no extra wording needed |

Same 8-hour map-object auto-delete caveat as the original pass applies — these ids are
historical provenance only, the shipped PNGs are the only copies. `scripts/structures.gd` was
not touched; it already loads whatever PNG is at `art/buildings/<kind>.png`, so this was a pure
asset swap.

**Verification:** full test suite (196/196), `tools/runtime_smoke.gd`, and `tools/soak_test.gd`
all re-run clean after the swap. Screenshots retaken with `tools/screenshot_buildings.gd`
(unchanged) at `build/screenshots/` (same 4 filenames as before); the pre-revision versions were
preserved at `build/screenshots_before_revision/` for direct side-by-side comparison, since
`build/` is gitignored and has no git history to diff against otherwise. **Important operational
note for future asset-swap sessions:** overwriting a PNG in place does not automatically
invalidate Godot's `.import` cache — a `godot --headless --path . --import` pass (standing
headless approval, not the GUI editor) was required before the windowed screenshot run actually
picked up the new art; the first screenshot attempt silently rendered the stale cached texture.
