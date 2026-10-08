# Wasteland Harvest — Art Style Guide (code-generated pixel art)

Authoritative rules for every sprite produced by the `tools/art/` generators. The goal is
**Stardew-Valley-grade readability and warmth** in an original post-apocalyptic world. Palette
roots: `GDD.md` §9. Shared palette constants: `tools/art/palette.py` (import it — never invent
new hex values without adding them there first).

## 1. Grid, scale, projection
- **Tile = 16×16 px.** The game renders a 320×192 viewport scaled ×4. Every sprite is authored
  at native 1× resolution; never draw at 2× and downscale. One art pixel = one game pixel,
  always. No sub-pixel, no anti-aliasing to transparency (alpha is 0 or 255, except
  deliberately translucent effects like water shine, shadows, wet-soil overlays).
- **Projection: Stardew's 3/4 top-down.** The ground is seen straight down (flat squares).
  Upright things (trees, people, buildings, fences, rocks, crates) show their **front face plus
  a sliver of their top**, and extend *upward* past their footprint cell. Never draw an
  isometric diamond, never rotate buildings onto a diagonal.
- **Character scale reference:** the player is ~14 px wide × ~22 px tall inside a 24×24 frame.
  A door is ~12–14 px tall. A one-storey house wall is ~20–24 px tall plus roof. A cow is ~2
  tiles long and ~16–18 px tall (slightly shorter than a person); a chicken ~8–10 px. Trees are
  2–4 tiles tall. Rocks and bushes are 1 tile (small) or 2×2 tiles (large).

## 2. Light, shading, outlines
- **Light comes from the top-left.** Lit faces: top and left. Shadow faces: right and bottom.
- **Shading ramps:** 3–4 shades per material (highlight, base, shade, deep shade). Hue-shift
  ramps: highlights drift warmer/yellower, shadows drift cooler/redder-purple — do not just
  darken toward black.
- **Outlines:** selective, coloured outlines. Use a dark shade of the local material on most
  edges and the warm outline `#281a0b` only on the bottom/right silhouette edges and in deep
  crevices. Ruins/hostile content uses the cold outline `#181a16` instead. Never pure `#000000`.
- **Ground contact shadow:** upright objects get a soft shadow ellipse at their base:
  `#281a0b` at ~35% alpha (settlement) — 1–2 px tall, slightly offset to the bottom-right.
- **Dithering:** sparingly, only for large gradients (sky, water depth). Never checkerboard
  noise across whole surfaces.
- **Readability first:** at 1×, a sprite must read by silhouette. Avoid single isolated noise
  pixels; cluster detail. Keep the busiest detail on the top/front, calm the edges.

## 3. Palette rules
- **Settlement / cozy side:** the anchor palette (dusty amber, lamplight gold, worn cream, field
  greens, worn woods, tilled soil, scavenged metal, warm outline) plus the active season's set.
  Saturated but not neon. Warm.
- **Ruins / expedition side:** the ruins palette (concrete greys, ash brown, rust, faded signage
  cream, cold outline). **Rad-glow green `#86e83e` / `#3fa832` is an accent that always means
  hazard** — use it only on irradiated things.
- **Gore:** only in ruins/combat, using the shared blood ramp `#9b1818` / `#c43020` / `#e84030`.
- **Seasons** re-tint organic things (grass, leaves, crops' foliage) using the season sets;
  man-made things (wood, metal, roofs, UI) never change with season.

## 4. Anchors and file conventions
- PNG, RGBA, no colour profile, no indexed palette required.
- **Ground tiles** are exactly 16×16 and must tile seamlessly with themselves and their variants.
- **Upright sprites** are anchored at their **bottom-centre on the ground line** of their base
  cell(s). The engine places a sprite so that its bottom-centre pixel row sits on the bottom
  edge of its footprint. Leave no empty transparent rows below the ground line (the shadow
  ellipse may extend 1 px below it).
- **Animation frames** go left-to-right in one horizontal strip, equal frame widths.
- **Wang (dual-grid) terrain overlays:** 64×64 sheets = 4×4 tiles. The tile at column `c`, row
  `r` is corner mask `m = r*4 + c`, where `m = NW*8 + NE*4 + SW*2 + SE*1` (bit set = that corner
  of the 16×16 tile is the terrain). In the dual grid each visual tile is offset half a tile so
  its four corners are the centres of four logical cells. Where a corner bit is clear the tile
  must be **fully transparent** (the grass base shows through). Mask 0 is fully transparent;
  mask 15 is fully covered. Transition edges are organic (wobbly, 1–2 px irregularity), with a
  1 px darker rim on the covered side and/or a 1 px highlight lip, so terrains read as having
  edges, not as cut-outs. All 16 tiles must agree on edge positions so any combination joins
  seamlessly: edges between two covered corners meet exactly at the tile's half-way line ±1 px.
- Every generator is deterministic (fixed RNG seeds) and is re-runnable from
  `tools/art/build_all.py`.

## 5. Quality bar
Before calling an asset done: view it at 1× in a mock scene (several tiles together, on its
real background, next to the player sprite for scale) and at 4×/8× zoom. Ask: would this look
at home in Stardew Valley? Does it read at 1×? Is it consistent in scale, light direction,
outline treatment and palette with everything around it? If not, iterate.

## 6. Ruined-city kit (`tools/art/ruins_city/`, Milestone C)
`python3 tools/art/ruins_city/build.py [ground walls landmarks buildings props preview]`
(an output allowlist in `build.py` stops it from writing anything but its own files). Colours:
the "Ruined city kit" block at the end of `tools/art/palette.py`.
- **Ruin walls** (`fences/ruin_wall_brick.png`, `ruin_wall_concrete.png`) use the fence-sheet
  contract (64x128, mask `N*1 + E*2 + S*4 + W*8`). They are drawn by a small voxel painter over
  the cell's footprint (6 px thick bands: E-W rows 23..28, N-S columns 5..10; every arm leaves
  the cell at height 11), so runs, corners and T-joints meet exactly. Straight runs stay fairly
  level (detail there would repeat every 16 px); corners rise into piers, ends crumble down.
- **Building masses** (`ruins/ruin_*.png`): flat south-facing elevation plus a foreshortened
  roof band, footprint = bottom W x H cells. No door is enterable (boarded, collapsed or
  buried in rubble). Curtains are never yellow: in a dead city, yellow reads as a lit window.
- **Kael's truck** is the one settlement object in the ruins: warm outline, warm shadow and
  lamplight, so it reads as safe at a glance.
- `ruins/dumpster_open.png` is the searched state of `dumpster.png`, with identical body pixels.
- Review scene: `art/env/_previews/ruins_city.png`.

## 7. Enemies, combat FX, combat HUD (`tools/art/enemies/`, Milestone C)
`python3 tools/art/enemies/build.py [enemies fx hud preview] [<enemy id> ...]`. Colours: the
"Enemies / combat FX" block in `tools/art/palette.py`.
- **Enemy sheets** (`art/characters/enemies/<id>.png`, 96x336 = 4x14 frames of 24x24; row
  layout in `art/characters/README.md` and `tools/art/enemies/rig.py`). Same canvas, centring
  and feet row as the PixelLab player (lowest opaque row = 20), cold 1 px selective outline,
  parts cast a 1 px contour onto what they overlap. Humanoids are paper dolls (ASCII heads and
  torsos per facing + procedural limbs, `humanoid.py`); corpses are the front view rotated 90°
  clockwise, which keeps the top-left light. Attack frame 1 is always the dodge telegraph and
  must change the silhouette, not just a colour.
- **FX** (`art/fx/`) may be translucent; the slash is drawn for an east swing around the
  frame's left-middle so code can rotate it. Ground decals (blood/ichor splats) stay opaque.
- **HUD icons**: `art/ui/hp_icon.png` (warm outline, settlement UI) and `rad_icon.png`
  (rad-glow trefoil, cold outline: it is a hazard sign).
