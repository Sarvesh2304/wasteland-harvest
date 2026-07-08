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

Text on the HUD uses Godot's default font at small size for Phase 2 — a proper pixel font
(PixelLab `create_font` or a shared-assets font) is deferred to Phase 16's UI/UX pass.

## Revision note (Phase 3): palette boosted

`hud_plaque.png` and `energy_bar_frame.png` both had their pixel colors brightened/saturated
in place (HSV saturation ×1.30, value ×1.12) — see `GDD.md` §9's "Revision note." The
`fill_mode`/in-code fill colors in `hud.gd`/`hud.tscn` were updated to the matching new
lamplight-gold hex (`#ffc948`) in the same pass.
