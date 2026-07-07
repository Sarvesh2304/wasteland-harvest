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
- `energy_bar_frame.png` — energy gauge housing (bottom-right). Asset id
  `ffb5ea67-b102-43c5-972d-b70aef887e10` ("wasteland_energy_bar_frame", 512x192 with a
  custom bar-shaped piece), content-cropped to 480x56 then downscaled 4x to 120x14. The
  fill inside it is a plain ProgressBar drawn in lamplight gold `#e8c268` at slight
  transparency, so the generated glass cracks still show through.

Text on the HUD uses Godot's default font at small size for Phase 2 — a proper pixel font
(PixelLab `create_font` or a shared-assets font) is deferred to Phase 16's UI/UX pass.
