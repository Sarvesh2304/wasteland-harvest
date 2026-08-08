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
  / 16 for the Credits/save-notice/sleepy-cue text; the sleepy cue has since dropped to native 8
  as part of the 2026-08-09 HUD polish that moved it out of the HUD and above the player's head,
  which is the other sanctioned size, not a new one) — this project's pixel font only stays crisp
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

## Stardew-fusion pass (2026-07-11, second HUD session)

Sarvesh shared an actual Stardew Valley HUD screenshot: its day/time widget is a circular
day/night dial fused **into** a hanging signpost as one seamless graphic, with the gold counter
as a matching-but-separate smaller sign below — not several separate plaques side by side,
which is what the first redesign session had shipped. One new PixelLab asset replaces the
separate ClockPanel plaque + standalone vector dial:

- `hud_day_sign.png` — fused day-sign widget (top-right). Asset id
  `2a454c70-6066-41db-aab3-2b0e877ad09e` ("wasteland_day_sign_dial_fused", 512x192 canvas,
  seed 7), generated with an explicit two-`pieces` shape template — a circle (dial, virtual
  coords x=88 y=96 r=84) overlapping a rounded rect (sign, x=150 y=36 w=354 h=120) by ~22
  virtual px so the generator drew them as one welded object, not two neighbors. Prompted as
  "salvaged riveted metal gauge dial with a plain dark glass face, welded onto a scrap-wood /
  patched-corrugated-metal hanging sign with one plain dark cracked-glass window, no text",
  palette pinned to the GDD §9 settlement-anchor hexes (so no post-hoc HSV boost needed,
  unlike the Phase 2 assets — this one was generated against the already-revised palette).
  Content-cropped (full-scale box x 10..498, y 22..170) then downscaled 4x nearest-neighbor
  to **122x37**. The heavier-than-plaque downscale (4x vs 2x) matches the energy bar frame's
  8x precedent; the slight speckle it leaves reads as scavenged patina, verified legible in
  the screenshot pass.
- **Region map** (final 122x37 texture coords, measured off the bitmap, for anyone moving
  the overlay nodes in `scenes/hud.tscn`): dial bezel outer circle center ≈ (19, 18),
  outer radius ≈ 18.5; sign glass window x 50..112, y 11..25. `%DayDial` (30x30, offsets
  4,3 → 34,33 inside DaySign) is sized so its own vector backing disc (r 15) covers the
  bitmap's baked glass face exactly, leaving the bitmap's welded bezel visible around it —
  the bitmap owns the frame, the vector owns the readout (see `scripts/day_dial.gd`'s
  hosting note; its fill math and rendering are unchanged). `%DayLabel`/`%ClockLabel` are
  two zero-gap 8px lines centered on the window (boxes y 10..18 and 18..26 — native-8px
  pixel-font ink lands inside the glass; the window's 61px content width exceeds the 54px
  the old plaque proved fits "6:00 AM").
- **No weather/season slots** on the sign, even as placeholders — Stardew's sign has both,
  but `DayManager` has neither system yet, and the first redesign session's deferred
  season-icon call (above) already established "don't fake a system that doesn't exist."
- **EnergyBar relocated** (no new art): out of the top-right column to **bottom-right**,
  base-aligned with the Hotbar (Stardew keeps energy by the toolbar, not with the clock).
- **CreditsPlaque touched up, no new art**: same `hud_plaque.png` texture (a regeneration
  would have spent generations to arrive at the same family read), but now displayed at an
  exact **half-scale 51x24** (`stretch_mode` SCALE into a rect precisely half the 102x48
  texture — a 2:1 integer downscale, so nearest-neighbor stays crisp; do NOT resize this
  rect to a non-half-multiple or it will mush silently) with the credits text dropped from
  16px to the font's native 8px. Rationale: screenshot review showed the old KEEP_CENTERED
  plaque actually drew at its full native 102x48 regardless of its 86x34 rect, which made
  the money sign visibly *bigger and heavier* than the new 122x37 day sign it hangs under —
  backwards from the Stardew reference, where gold is the *smaller* matching sign below.
  Half-scale + uniform 8px text makes it clearly subordinate, and shrinks the baked garbled
  nameplate (which the new day sign deliberately lacks) to unobtrusive texture noise. It
  hangs 3px under the sign (top 49 → 43), right-aligned.

## Revision note (Phase 3): palette boosted

`hud_plaque.png` and `energy_bar_frame.png` both had their pixel colors brightened/saturated
in place (HSV saturation ×1.30, value ×1.12) — see `GDD.md` §9's "Revision note." The
`fill_mode`/in-code fill colors in `hud.gd`/`hud.tscn` were updated to the matching new
lamplight-gold hex (`#ffc948`) in the same pass.
