# UI Art — PixelLab Provenance (Phase 2 basic HUD)

Scavenged-metal / cracked-glass HUD elements per ROADMAP Phase 2's "post-apoc UI aesthetic"
note, generated with `mcp__pixellab__create_ui_asset` in the settlement anchor palette
(`GDD.md` §9). Scope is deliberately "basic HUD reads clearly" — the fully art-directed UI
system is Phase 16 polish.

PixelLab's minimum output is 192px per axis, far larger than the 320x192 game viewport, so
each asset was generated large and integer-downscaled (nearest-neighbor, so it stays crisp)
to HUD size. The original full-size PNGs are retrievable from PixelLab by asset id if a
different scale is ever needed.

- `hud_plaque.png` — day/clock plaque (top-right). Asset id
  `34c1ca3b-344e-456f-b75d-8bb2880754fb` ("wasteland_hud_plaque", 384x192 canvas whose
  actual panel content is 204x96), content-cropped then downscaled 2x to 102x48. The day
  and clock labels render inside its cracked-glass window; the garbled nameplate text at
  the bottom is baked-in generated detail, left as-is.
- `energy_bar_frame.png` — energy gauge housing, **vertical**, Stardew-style (below the
  plaque, top-right). Asset id `54de2e24-e137-4580-ae81-6a700e28245f`
  ("wasteland_energy_bar_frame_vertical", 224x640 canvas with a tall rounded-rect piece
  and a baked "ENERGY MAX" nameplate), content-cropped to 104x512 then downscaled 8x to
  13x64. Replaces an earlier horizontal 120x14 version (Phase 2's initial pass) — Sarvesh
  asked for a vertical, Stardew-proportioned bar instead, and a fresh vertical generation
  was used rather than rotating the old horizontal asset, since the old one's baked
  nameplate text and aspect ratio were designed for horizontal reading and wouldn't have
  survived a 90° rotation cleanly. The fill inside it is a plain ProgressBar drawn in
  lamplight gold `#e8c268` at slight transparency (`fill_mode = FILL_BOTTOM_TO_TOP`, so
  it depletes from the top down like Stardew's), so the generated glass cracks still show
  through.

## Pixel font (`fonts/`, added after Phase 4)

Godot's default vector font was illegible at 6-11px inside the 320x192 viewport (anti-aliased
glyph edges turn to mush under the 4x nearest-neighbor stretch), so the deferred pixel font was
pulled forward from Phase 16. `fonts/wasteland_harvest_ui.ttf` is a PixelLab `create_font`
generation (job id `8c4a9988-a6fa-4127-ba1a-afe9a91dc32d`, Bold weight, seed 7, 8px native
glyphs, monospaced 4x6-px letterforms). Two earlier candidates were rejected: job
`70b1fe89-...` (8px Regular — mangled letterforms) and `0bc89f23-...` (16px Regular — clean
but native 16px is too large for body text in the 320x192 viewport). Bold at 8px was the
readability winner, and its plain blocky forms still read warm/cozy in the worn-cream
palette colors rather than grim.

**PixelLab's font reference layout contains no digits** (verified across independent
generations: same 65-char set, 0-9 absent). Since the HUD renders "Day 1", "6:00 AM", and
stack counts, glyphs for `0-9 / ↑ ↓ —` and `…` were hand-authored on the same 4x6 grid /
128-units-per-pixel / same stroke weight and merged into the TTF, plus cmap aliases mapping
`– ' ' " "` onto existing glyphs so lore text never hits the blurry system-fallback font —
see `tools/font_add_glyphs.py` (the glyph designs are embedded in it as ASCII art).
Regenerating the font from PixelLab alone will silently lose all of these; re-run that
script on any fresh TTF. (The internal family name was also cleaned from the generation
name "... UI v2" to "Wasteland Harvest UI" via fontTools' name table, IDs 1/3/4/6/16.)

It's wired in as the project-wide default via `ui_theme.tres` (this directory), set as
`[gui] theme/custom` in `project.godot`, with import settings forcing crisp rendering
(no antialiasing, no hinting, subpixel positioning disabled). **Font-size convention:** the
theme's default is the font's native **8px** (1 font pixel = 1 viewport pixel = 4 screen
pixels); larger text uses exact integer multiples only — **16px** for titles/names (e.g. the
settlement name on the select screen). Never use non-multiple sizes (6/7/11 etc.) — bitmap
glyphs only scale cleanly at integer multiples of their design size.

## HUD redesign (2026-07-11 playtest feedback session)

Three changes, no new PixelLab assets:

- **Credits relocated.** The Credits readout moved from its own top-left plaque to a second,
  shorter `hud_plaque.png` instance stacked directly below the day/clock plaque, top-right —
  matching Stardew's own corner cluster (day/season/gold stacked in one spot) per direct
  feedback. Same texture, same font/color treatment, just a smaller box (86x34 vs the clock
  plaque's 102x43) and a new position; no new art.
- **HUD shrunk ~10%,** applied to plaque/bar-frame **graphics and gaps**, never to `font_size` —
  see `scripts/hud.gd`'s "HUD shrink note" for the exact numbers. The short version: the clock
  plaque's width (102, unchanged) stayed put because it's what the widest string this HUD renders
  ("6:00 AM") is proven to fit at the existing 24px margins; its height dropped ~10% instead,
  since the bottom third of the plaque bitmap is decorative baked nameplate art the day/clock text
  never rendered into anyway. The energy bar frame shrank ~10% on both axes since it has no text
  to protect. All `theme_override_font_sizes` stayed at their existing sanctioned values (8 native
  / 16 for the Credits/save-notice/sleepy-cue text) — this project's pixel font only stays crisp
  at those exact sizes (see above), and a fractional `Control.scale` or font_size change was
  exactly the blur bug this convention exists to prevent, so it wasn't used here even though it
  would have been the simplest way to hit a literal "10% smaller" everywhere.
- **Day-progress dial added** (`scripts/day_dial.gd`, `%DayDial` in `hud.tscn`, beside the clock
  plaque): a small clock-face meter that fills clockwise as `DayManager.minutes_into_day` advances
  through the current (6 AM-to-6 AM) gameplay day and resets to empty the instant a new day
  starts. Drawn procedurally via `_draw()` (a vector arc: `draw_circle`/`draw_arc`, no bitmap)
  rather than as a new PixelLab plaque — a vector arc is exactly crisp at any control size, so it
  sidesteps the pixel-font/pixel-art integer-scale concerns entirely, while still reusing the
  established palette (scavenged metal ring, warm near-black backing, lamplight gold fill — the
  same lamplight gold as the energy bar's own fill) so it reads as part of the same cluster rather
  than an unrelated new visual language. A season icon was explicitly requested but deferred — no
  season system exists in `DayManager` yet, and faking one wasn't wanted.

## Revision note (Phase 3): palette boosted

`hud_plaque.png` and `energy_bar_frame.png` both had their pixel colors brightened/saturated
in place (HSV saturation ×1.30, value ×1.12) — see `GDD.md` §9's "Revision note." The
`fill_mode`/in-code fill colors in `hud.gd`/`hud.tscn` were updated to the matching new
lamplight-gold hex (`#ffc948`) in the same pass.
