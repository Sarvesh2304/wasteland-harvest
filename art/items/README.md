# Item Icon Art — PixelLab Provenance (Phase 3)

Real icon art for a representative subset of the 20 items in `data/items.json`, per
`CLAUDE.md`'s Phase 3 scope guidance ("generate real small icon art for a representative
subset — the 4 crops' harvested-produce icons at minimum, plus a couple of key resources").
Generated via `mcp__pixellab__create_map_object`, 32x32, `high top-down` view, low detail,
basic shading, single-color outline, matching the crop art's style — described as an isolated
item ("no soil, no plant") rather than reusing the growing-plant sprites, so icons read cleanly
at hotbar/inventory slot size.

- `mutant_potato.png`, `dustwheat_grain.png`, `ironroot.png`, `sunbloom.png` — the 4 crops'
  harvested-produce icons (the checklist's stated minimum).
- `wood.png`, `stone.png`, `scrap_metal.png` — 3 key resource icons (wood/stone/scrap were
  explicitly named in the checklist's "first 20 items" list), generated as a "couple... if time
  allows" per the scope guidance.

The remaining 13 items (4 seed items, cloth scrap, bottle caps, 2 food items, 5 tools) use
flat-color placeholders instead — a `placeholder_color` + short `placeholder_label` in
`data/items.json`, drawn in-engine by `scripts/hud.gd`'s slot widgets (a `ColorRect`, not a
PNG). No art generation spent on those; full icon art for all 20 items is Phase 6 polish, not a
Phase 3 blocker, per the scope guidance.

## Known follow-up: not yet imported

Same situation as `art/crops/README.md` describes in detail: these 7 PNGs have no `.import`
sidecar yet, so `scripts/hud.gd`'s `_refresh_slot()` currently falls back to the placeholder
`ColorRect` rendering for these items too (its `ResourceLoader.exists(icon_path)` check returns
false) until `godot --headless --import` (or an editor open) runs once. See that README for the
full explanation of why this wasn't done in this session.

## Revision note (Phase 3): palette boosted, and the import gap above is now closed

Same as `art/crops/README.md`: the import gap was closed the same day (headless `--import`),
and these 7 icon PNGs were then brightened/saturated in place (HSV saturation ×1.30, value
×1.12) along with the rest of the settlement-side art — see `GDD.md` §9's "Revision note."

## Milestone D quest items — code-generated (`vault_seeds.png`, `festival_ribbon.png`)

Drawn with the items pipeline's own kit (`tools/art/items/ia_lib.py` + its private ramps) by
`tools/art/living/lv_items.py`, so they match the other code-generated icons (16x16, 1 px clear
margin, top-left light, selective outline). Written by the living pipeline
(`python3 tools/art/build_all.py living`) and also registered in `tools/art/items/build.py`'s
icon registry, so the items pipeline writes the same bytes (rather than placeholders) now that
both ids are in `data/items.json`.
- `vault_seeds.png` — a sealed steel seed canister from the Northgate vault: clamped lid, cream
  label with a stencilled green sprout.
- `festival_ribbon.png` — a prize rosette: pleated red ring, gold heart, two notched tails.

## Fishing — code-generated (13 fish + 3 dishes)

Drawn with the items pipeline's own kit (`tools/art/items/ia_lib.py`, 16x16, 1 px clear margin,
top-left light, selective outline) by `tools/art/fishing/fi_fish.py` and `fi_dishes.py`, colours
from the "Fishing" block of `tools/art/palette.py`. Written by the fishing pipeline
(`python3 tools/art/build_all.py fishing`) and also registered in `tools/art/items/build.py`'s
icon registry, so the items pipeline writes the same bytes (not placeholders) now that the ids
are in `data/items.json`. Ids and stats: `docs/FISHING.md` §5-6.
- `mud_minnow.png` — small, stubby, silt-brown with a dark side stripe and a tan belly.
- `shellback_crawdad.png` — brick-red crawdad seen from above, claws up, round crimped shell.
- `rustgill_carp.png` — deep, humped bronze carp; rust-orange gill plates; a barbel.
- `sun_perch.png` — round gold sunfish disc, orange breast, teal bars, spiny crest.
- `silver_dace.png` — slim blue-steel/silver dart with a huge chevron tail.
- `ash_trout.png` — ash-grey trout leaping up-right, dark speckles, faded pink band.
- `bog_eel.png` — peat-dark eel in an S-coil, yellow belly, fin ridge along its back.
- `sludge_catfish.png` — flat-headed swamp-green catfish, whiskers, oily sludge dripping off it.
- `frostfin.png` — ice-blue fish with pale, shard-like frosted fins.
- `iron_pike.png` — gunmetal pike corner to corner, rivet spots, a toothed bear-trap jaw.
- `glowfin.png` — deep-blue fish whose sail fins and flank spots glow rad green (it is
  irradiated, so the hazard accent is earned); the glow tints the outline round its fins.
- `two_headed_perch.png` — barred yellow-green perch with red-orange fins and two heads.
- `old_mayor.png` — the legendary catfish, filling the icon: dark slate-bronze, old-gold eye,
  cream barbels, a scar across its back, moss, a rusted hook still in its mouth.
- `grilled_fish.png` — a golden grill-striped fish on the enamel plate, a sprig of greens.
- `fish_stew.png` — the enamel stew bowl (as pumpkin_soup / cooked_meal), creamy chowder with
  potato, greens and fish, a fish tail poking out, steam.
- `smoked_eel.png` — the Bog Eel's own coil, lacquered mahogany with glints, smoke curling off.
