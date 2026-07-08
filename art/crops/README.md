# Crop Art — PixelLab Provenance (Phase 3)

Growth-stage sprites for the 4 post-apoc crops named in `ROADMAP.md`/`GDD.md`: Mutant Potato,
Dustwheat, Ironroot, Sunbloom. Generated at 32x32 (PixelLab's `create_map_object` minimum
canvas — the locked 16x16 tile size from Phase 1 is too small for that tool) via
`mcp__pixellab__create_map_object` for each crop's seedling stage, then
`mcp__pixellab__create_object_state` chained forward stage-by-stage so every stage in a crop's
sequence shares the same PixelLab "group" and visually reads as one growing plant rather than
unrelated art. `high top-down` view, low detail, flat/basic shading, single-color outline, in
the settlement anchor palette (`GDD.md` §9).

Stage counts vary per crop (4-6, per the ROADMAP checklist's range) rather than using one number
everywhere, to demonstrate the range is actually supported:

- `mutant_potato/` — 5 stages (`stage_0.png`..`stage_4.png`). Group `70c09e67-...`. Stage 4 adds
  the mottled purple-green mutant skin on the exposed tuber.
- `dustwheat/` — 4 stages. Group `8615845d-...`. The shortest chain (Dustwheat is meant to read
  as the quick, hardy staple crop).
- `ironroot/` — 5 stages. Group `c2c4644a-...`. Stage 4's root is rust-red and gnarled.
- `sunbloom/` — 6 stages (the longest chain, deliberately at the top of the range). Group
  `10656424-...`. Stages 3-4 show the flower bud swelling and starting to open before stage 5's
  full lamplight-gold bloom.

Consumed by `scripts/farm.gd`'s `_crop_texture()` via `scripts/crop_db.gd`'s
`stage_texture_path()` (`res://art/crops/<crop_id>/stage_<N>.png`). If a stage file can't be
loaded, `_crop_texture()` falls back to a flat-color placeholder (green-to-amber lerp by growth
progress) rather than erroring — see that function's comment.

## Known follow-up: these PNGs are not yet imported

These files were downloaded straight from PixelLab (`curl` against the `download` URL each
generation call returns) and have **no `.import` sidecar yet** — confirmed directly:
`ResourceLoader.exists("res://art/crops/mutant_potato/stage_0.png")` returns `false` under
`godot --headless --script ...`, while an already-imported Phase 2 asset
(`art/ui/hud_plaque.png`) returns `true` and loads. Godot's asset-import pipeline
(`EditorFileSystem`) only runs inside the editor; there's no runtime/export-build equivalent,
and the standard non-interactive way to trigger it is `godot --headless --import` (or opening
the project once) — which per this task's explicit boundary ("Do NOT open the Godot GUI
editor") is left for the orchestrating session, since that command's own `--help` text
describes it as "Starts the editor... and then quits."

**Practical effect right now:** the game runs correctly and every headless test/smoke check
passes, but crops and the 7 icon items below currently render as the flat-color placeholder
fallback, not the real art, until someone with editor access runs `godot --headless --import`
(or opens the project in the GUI editor once) to generate the missing `.import` files and
`.godot/imported/` cache. No code change is needed for the real art to take over after that —
`ResourceLoader.exists()` will start returning `true` for these paths and the fallback branch
simply stops being hit.

## Revision note (Phase 3): palette boosted, and the import gap above is now closed

The orchestrating session ran `godot --headless --import` the same day this art was generated,
so the caveat above (real art not showing up without a manual import) no longer applies — these
PNGs have been imported and render normally. Separately, all 20 stage PNGs then had their pixel
colors brightened/saturated in place (HSV saturation ×1.30, value ×1.12) as part of a same-day
palette fix — see `GDD.md` §9's "Revision note."
