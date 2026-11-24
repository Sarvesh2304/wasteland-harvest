# Graph Report - wasteland-harvest  (2026-11-24)

## Corpus Check
- 178 files · ~274,354 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 1596 file(s) not represented in the graph (top: .import 1115, .gd 221, .uid 221)
- WARNING: 1596 of 2918 files seen (55%) have no supported extractor and are missing from this graph entirely. It may look complete while representing only part of the codebase.

## Summary
- 2593 nodes · 7271 edges · 94 communities (88 shown, 6 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 761 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `963a63cd`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- ns
- Song
- Ramp
- theory.py
- Canvas
- outline
- .render
- gen_ambience.py
- ramp
- ia_produce.py
- previews.py
- effects.py
- op_scene.py
- trees.py
- ia_lib.py
- ia_place.py
- validate_social_data.py
- op_pages.py
- rc_common.py
- hval
- rc_walls.py
- drums.py
- debris.py
- Wasteland Harvest — Game Design Document
- sfx/synth.py
- end_fade
- bloater.py
- ia_crops.py
- Year 1 — Foundation & Prototype
- Canvas
- humanoid.py
- fences.py
- palette.py
- townsfolk/build.py
- rgba
- instruments.py
- numpy
- Mix
- engine/synth.py
- items/build.py
- rgba
- lv_vault.py
- rig.py
- Balance & Performance Pass (Milestone E, 2026-11-12)
- math
- analyze.py
- lv_festival.py
- Building a Release (Milestone E)
- weather_icons.py
- sfx
- terrain.py
- 3. Brutal assessment — what a player would actually experience
- os
- shambler.py
- bloater.py
- Wasteland Harvest
- Social life, requests and Town Works — design + data contracts (Milestone B, 2026-10-08)
- Wasteland Harvest — Map Layout Sketches
- part
- runner.py
- wang.py
- music/build_all.py
- Character Art — PixelLab Provenance
- op_pages.py
- Wasteland Harvest — Art Style Guide (code-generated pixel art)
- A living settlement — design + data contracts (Milestone D, 2026-11-10)
- ia_tools.py
- fi_fish.py
- export_all.sh
- Instrument
- lv_common.py
- Building Art — Phase 6 "Art pass 1" (buildings half) — PixelLab Provenance
- Tile Art — Phase 1 Test Set
- sys
- burst
- UI Art — PixelLab Provenance (Phase 2 basic HUD)
- enemies/build.py
- master.py
- Stardew Valley — Structural Reference (Pelican Town & Marnie's Ranch)
- fishing/build.py
- Crop Art — PixelLab Provenance (Phase 3)
- Item Icon Art — PixelLab Provenance (Phase 3)
- Prop Art — PixelLab Provenance
- registry.py
- Fishing (2026-11-24)
- _LRU
- Audio
- living/build.py
- creak
- sys

## God Nodes (most connected - your core abstractions)
1. `Canvas` - 158 edges
2. `Ramp` - 156 edges
3. `mix()` - 144 edges
4. `ns()` - 115 edges
5. `sfx()` - 102 edges
6. `Mix` - 90 edges
7. `norm()` - 82 edges
8. `rgba()` - 74 edges
9. `ramp()` - 59 edges
10. `outline()` - 57 edges

## Surprising Connections (you probably didn't know these)
- `11. Fishing (`tools/art/fishing/`, docs/FISHING.md section 9)` --references--> `painted()`  [INFERRED]
  docs/ART_STYLE.md → tools/art/fishing/fi_fish.py
- `3. Dialogue — `data/dialogue.json` (v2)` --references--> `player_hurt()`  [INFERRED]
  docs/SOCIAL_AND_QUESTS.md → tools/audio/sfx/gen_combat.py
- `8. Townsfolk and Town Works (`tools/art/townsfolk/`, Milestone B)` --references--> `gift_icon()`  [INFERRED]
  docs/ART_STYLE.md → tools/art/townsfolk/tf_ui.py
- `8. Townsfolk and Town Works (`tools/art/townsfolk/`, Milestone B)` --references--> `heart_empty()`  [INFERRED]
  docs/ART_STYLE.md → tools/art/townsfolk/tf_ui.py
- `8. Townsfolk and Town Works (`tools/art/townsfolk/`, Milestone B)` --references--> `quest_marker()`  [INFERRED]
  docs/ART_STYLE.md → tools/art/townsfolk/tf_ui.py

## Import Cycles
- None detected.

## Communities (94 total, 6 thin omitted)

### Community 0 - "ns"
Cohesion: 0.07
Nodes (54): chicken(), chop(), coins(), cow(), cozy(), craft(), _dirt_contact(), door_close() (+46 more)

### Community 1 - "Song"
Cohesion: 0.07
Nodes (37): Kit, Bass, CachedDecay, Chip, EPiano, FMBell, Pad, Piano (+29 more)

### Community 2 - "Ramp"
Cohesion: 0.04
Nodes (65): 2. Hearts (affinity) — `scripts/affinity.gd`, adrenal_shot(), bandage(), berry_jam(), bowl(), canned_beans(), cheese(), choco_bar() (+57 more)

### Community 3 - "theory.py"
Cohesion: 0.06
Nodes (34): grid_len(), melody_length(), Note, parse_chart(), parse_grid(), parse_melody(), _strip_comments(), arp() (+26 more)

### Community 4 - "Canvas"
Cohesion: 0.07
Nodes (12): build(), _flower(), flowers(), _grass(), _leafpair(), leaves_autumn(), snow_clump(), specks() (+4 more)

### Community 5 - "outline"
Cohesion: 0.06
Nodes (46): Living settlement buildings (Milestone D) — code-generated, 3 kinds, 8. Townsfolk and Town Works (`tools/art/townsfolk/`, Milestone B), line_points(), outline(), _barrel_body(), festival_booth(), mayor_house_antenna(), _outlined() (+38 more)

### Community 6 - ".render"
Cohesion: 0.10
Nodes (25): Phase 3 — Farming Core & Inventory System, mystery_jerky(), potato_hash(), bresenham(), Layer, Sprite, cobble_path_icon(), gravel_path_icon() (+17 more)

### Community 7 - "gen_ambience.py"
Cohesion: 0.10
Nodes (38): amb_farm_day(), amb_farm_night(), amb_fire(), amb_geiger_loop(), amb_indoor(), amb_radstorm(), amb_rain(), amb_river() (+30 more)

### Community 8 - "ramp"
Cohesion: 0.18
Nodes (24): mix(), ramp(), barricade(), build(), bus_wreck(), _car(), car_wreck(), concrete_barrier() (+16 more)

### Community 9 - "ia_produce.py"
Cohesion: 0.08
Nodes (35): crop_colors(), crop_ramp(), R(), ramp(), ash_apple(), ash_beet(), blister_tomato(), cactus_pear() (+27 more)

### Community 10 - "previews.py"
Cohesion: 0.17
Nodes (14): load(), save(), Scene, sub(), zoom(), contact(), frame_of(), main() (+6 more)

### Community 11 - "effects.py"
Cohesion: 0.09
Nodes (24): apply_fx(), body(), chorus(), compress(), convolve_reverb(), echo(), eq(), haas() (+16 more)

### Community 12 - "op_scene.py"
Cohesion: 0.09
Nodes (25): canvas(), crop(), disc(), ellipse(), fence_run(), frame(), flip(), ground() (+17 more)

### Community 13 - "trees.py"
Cohesion: 0.07
Nodes (31): canopy(), Puff, scatter_blossoms(), check_alpha(), edge_masks(), hexs(), lum(), _nbrs() (+23 more)

### Community 14 - "ia_lib.py"
Cohesion: 0.06
Nodes (28): kind_at(), fish_stew(), grilled_fish(), smoked_eel(), add_shadow(), apply_outline(), auto_ramp(), check_icon() (+20 more)

### Community 15 - "ia_place.py"
Cohesion: 0.11
Nodes (33): bee_box_icon(), bee_box_world(), _beebox(), _bricks(), compost_bin_world(), crate_chest_world(), _furnace(), kiln_icon() (+25 more)

### Community 16 - "validate_social_data.py"
Cohesion: 0.08
Nodes (21): check_dialogue(), check_gifts(), check_intro_shapes(), check_projects(), check_requests(), check_services(), check_story_nodes(), check_taste_block() (+13 more)

### Community 17 - "op_pages.py"
Cohesion: 0.17
Nodes (11): _allowed(), build_pages(), build_preview(), build_regions(), check_page(), main(), build(), classify() (+3 more)

### Community 18 - "rc_common.py"
Cohesion: 0.06
Nodes (18): chips(), darken(), dk(), finish(), plank(), rust_streak(), soot(), text() (+10 more)

### Community 19 - "hval"
Cohesion: 0.08
Nodes (35): hstrip(), boarded_door(), build(), fill_block(), fill_brick(), fill_concrete(), fill_siding(), grime() (+27 more)

### Community 20 - "rc_walls.py"
Cohesion: 0.10
Nodes (12): _band(), _base_details(), _bits(), Brick, build(), Concrete, frame(), _height_at() (+4 more)

### Community 21 - "drums.py"
Cohesion: 0.19
Nodes (28): anvil(), boom(), brush(), chime(), clap(), crash(), _env(), hat() (+20 more)

### Community 22 - "debris.py"
Cohesion: 0.09
Nodes (25): _bolt(), build(), _drum_lying(), _finish(), junk(), _leaf(), _lichen(), log_large() (+17 more)

### Community 23 - "Wasteland Harvest — Game Design Document"
Cohesion: 0.06
Nodes (30): 10. Win / Lose Conditions, 11. Scope-Addition Flags (reconciled into ROADMAP.md — kept here for design rationale), 1. High Concept, 2. World & Lore, 3. Player Character & the Opening, 4. Core Gameplay Loop — The Settlement (Cozy-Core), 5. The Expedition Loop — Ruins, Radiation & the Ammo Economy, 6. The Raider Faction & Reputation System (+22 more)

### Community 24 - "sfx/synth.py"
Cohesion: 0.06
Nodes (35): _arr(), biquad(), _blep(), bp(), butter(), cents(), chip(), chirp() (+27 more)

### Community 25 - "end_fade"
Cohesion: 0.10
Nodes (14): bubble(), end_fade(), env_ad(), env_adsr(), fade(), fmbell(), make_ir(), modes() (+6 more)

### Community 26 - "bloater.py"
Cohesion: 0.10
Nodes (22): _arms(), _cloud(), frame(), _halo(), _stub_legs(), _carcass(), death_frames(), frame() (+14 more)

### Community 27 - "ia_crops.py"
Cohesion: 0.16
Nodes (17): build(), bush_flowering(), bush_fruit(), crop_ramps(), dead_sprite(), draw(), flower(), grain() (+9 more)

### Community 28 - "Year 1 — Foundation & Prototype"
Cohesion: 0.07
Nodes (27): ⚡ Accelerated Plan (2026-10-07) — supersedes the order of Phases 7(stages 4-5) and 9–18, Milestone A — "The first hour feels great", Milestone B — "A reason to come back tomorrow", Milestone C — "The wasteland outside the fence", Milestone D — "A living settlement", Milestone E — "Ship-ready", Phase 10 — Business System, Crafting & Advanced Economy, Phase 11 — Seasons, Weather & World Events (+19 more)

### Community 29 - "Canvas"
Cohesion: 0.10
Nodes (3): Canvas, line_points(), _over()

### Community 30 - "humanoid.py"
Cohesion: 0.20
Nodes (3): Arm, blood_pool(), Pose

### Community 31 - "fences.py"
Cohesion: 0.17
Nodes (18): _beam(), build(), chainlink_frame(), _dark(), gate_chainlink(), gate_wood(), _log(), _mesh() (+10 more)

### Community 32 - "palette.py"
Cohesion: 0.06
Nodes (9): gear(), gear(), Arm, layer(), Look, Pose, stamp(), gear() (+1 more)

### Community 33 - "townsfolk/build.py"
Cohesion: 0.13
Nodes (15): build_buildings(), build_characters(), build_preview(), build_ui(), main(), verify_building(), write(), check_frame() (+7 more)

### Community 34 - "rgba"
Cohesion: 0.13
Nodes (25): alert_mark(), blood_splat(), bolt(), build(), _burst(), _center(), hit_spark(), ichor_splat() (+17 more)

### Community 35 - "instruments.py"
Cohesion: 0.14
Nodes (11): _interp_key(), ks_design(), ks_loop(), _smoothstep(), vel_amp(), dc_block(), onepole_lp(), place() (+3 more)

### Community 36 - "numpy"
Cohesion: 0.06
Nodes (25): circ_apply(), circ_conv(), circ_reverb(), crush(), env_bell(), env_pts(), kweight(), _kweight_coefs() (+17 more)

### Community 37 - "Mix"
Cohesion: 0.11
Nodes (42): cricket(), wood_hammer(), extract(), heal(), loot_rare(), radio_click(), build(), build_complete() (+34 more)

### Community 38 - "engine/synth.py"
Cohesion: 0.11
Nodes (15): additive(), biquad(), chain(), env_ar(), fade_edges(), lagrange_frac(), noise(), _norm_sos() (+7 more)

### Community 39 - "items/build.py"
Cohesion: 0.16
Nodes (11): check(), main(), placeholder(), registry(), res_to_path(), crop_sheet(), _font(), icon_sheet() (+3 more)

### Community 40 - "rgba"
Cohesion: 0.15
Nodes (28): rgba(), barrel(), bench(), build(), _dk(), laundry_line(), hang(), rope_y() (+20 more)

### Community 41 - "lv_vault.py"
Cohesion: 0.19
Nodes (11): _collar(), frame(), _hazard(), _keypad(), _lamp(), _leaf(), _rim(), _stairs() (+3 more)

### Community 42 - "rig.py"
Cohesion: 0.36
Nodes (9): A(), arms_e(), arms_n(), arms_s(), death_frames(), frames(), pistol(), poses() (+1 more)

### Community 43 - "Balance & Performance Pass (Milestone E, 2026-11-12)"
Cohesion: 0.33
Nodes (5): 1. Farming, 2. The ruins, 3. Credit sinks: the change this pass made, 4. Performance, Balance & Performance Pass (Milestone E, 2026-11-12)

### Community 44 - "math"
Cohesion: 0.21
Nodes (10): build_one(), band_report(), _cmap(), _font(), harmonic_lint(), seam_check(), _seam_metrics(), spectral_balance() (+2 more)

### Community 45 - "analyze.py"
Cohesion: 0.10
Nodes (23): stable_seed(), amb_flags(), amb_metrics(), analyze(), _cmap(), contact_sheet(), draw_tile(), ffmpeg_lufs() (+15 more)

### Community 46 - "lv_festival.py"
Cohesion: 0.21
Nodes (11): _bowl(), bunting(), festival_lantern(), festival_table(), _jug(), _lantern_body(), lantern_frame(), _loaf() (+3 more)

### Community 47 - "Building a Release (Milestone E)"
Cohesion: 0.25
Nodes (7): Before a store upload (Steam / itch.io), Building a Release (Milestone E), Mac signing, One command, Playtesting on a Mac, The presets, What's needed

### Community 48 - "weather_icons.py"
Cohesion: 0.39
Nodes (12): build(), _canvas(), clear(), clear_night(), _cloud(), _disc(), _hex(), _outline() (+4 more)

### Community 49 - "sfx"
Cohesion: 0.14
Nodes (34): alarm(), bloater_pop(), bullet_impact(), container_open(), crit(), crossbow(), door_metal(), explosion() (+26 more)

### Community 50 - "terrain.py"
Cohesion: 0.05
Nodes (27): grid_sheet(), Asphalt, build(), Cobble, Concrete, _detail_clover(), _detail_pebble(), _detail_tips() (+19 more)

### Community 51 - "3. Brutal assessment — what a player would actually experience"
Cohesion: 0.14
Nodes (13): 1. Verification of the 2026-10-07 status report, 2. What is genuinely good (keep it), 3.1 It does not look like a game yet (presentation: **2/10**), 3.2 It is completely silent (audio: **0/10**), 3.3 Interaction feel (controls: **4/10**), 3.4 The farming loop is thin and punishing (core gameplay: **3/10**), 3.5 Nothing to work toward (progression/goals: **2/10**), 3.6 Half the game does not exist (expeditions/combat: **0/10**) (+5 more)

### Community 52 - "os"
Cohesion: 0.17
Nodes (7): build(), _tile_h(), _tile_v(), build(), main(), build_character(), main()

### Community 53 - "shambler.py"
Cohesion: 0.23
Nodes (9): arms_e(), arms_limp_s(), arms_n(), arms_s(), arms_up_s(), death_frames(), frames(), poses() (+1 more)

### Community 54 - "bloater.py"
Cohesion: 0.17
Nodes (14): _belly(), BPose, _chest(), death_frames(), _ell(), frames(), _lambert(), poses() (+6 more)

### Community 55 - "Wasteland Harvest"
Cohesion: 0.17
Nodes (11): Art Pipeline — PixelLab-first, Chess Engine, Core Systems (see `ROADMAP.md` for the full phase-by-phase breakdown), Engine & Technical Spec, graphify, Platform & Release, Repo Conventions, Shared Assets (`~/Projects/shared-assets`, sibling repo) (+3 more)

### Community 56 - "Social life, requests and Town Works — design + data contracts (Milestone B, 2026-10-08)"
Cohesion: 0.25
Nodes (7): 1. Who lives here, 3. Dialogue — `data/dialogue.json` (v2), 4. Gift preferences — `data/gifts.json`, 5. Notice-board requests — `data/requests.json`, 6. Town Works — `data/projects.json`, 7. Journal and forecast, Social life, requests and Town Works — design + data contracts (Milestone B, 2026-10-08)

### Community 57 - "Wasteland Harvest — Map Layout Sketches"
Cohesion: 0.17
Nodes (11): 1. The Three Starting Settlements, 2. The Town Core, 3. The Ranch/Sanctuary, 4. The Ruined City — Concept Sketch, Bunkers, Forest Edge — the salvager's start (lean: **ruin materials**), Open Plains — the farmer's start (lean: **better soil**), Raider faction territory (+3 more)

### Community 58 - "part"
Cohesion: 0.40
Nodes (7): part(), build(), gift_icon(), heart_empty(), heart_full(), quest_marker(), talk_icon()

### Community 59 - "runner.py"
Cohesion: 0.29
Nodes (8): A(), arms_e(), arms_s(), death_frames(), frames(), poses(), _raise(), sheet()

### Community 60 - "wang.py"
Cohesion: 0.25
Nodes (5): bits(), cov(), coverage(), distances(), verify()

### Community 61 - "music/build_all.py"
Cohesion: 0.14
Nodes (13): load_json(), fmt_time(), main(), _print_result(), sync_import(), _worker(), write_manifest(), write_readme() (+5 more)

### Community 62 - "Character Art — PixelLab Provenance"
Cohesion: 0.18
Nodes (10): Character Art — PixelLab Provenance, Enemies (code-generated) — Milestone C, Files, Files, Files (per NPC, same layout as `player/`), `mayor_harlan/`, `marta/`, `scout_kael/` — Phase 6 "Art pass 1" NPCs, `player/` — Phase 2 player character, `rancher_silas/` — Phase 8 Ranch/Sanctuary keeper NPC (+2 more)

### Community 63 - "op_pages.py"
Cohesion: 0.23
Nodes (13): childhood(), claim(), clinic(), farewell(), farm(), father(), grave(), mother() (+5 more)

### Community 64 - "Wasteland Harvest — Art Style Guide (code-generated pixel art)"
Cohesion: 0.13
Nodes (13): 10. The opening and character creation (`tools/art/opening/`, Milestone E), 11. Fishing (`tools/art/fishing/`, docs/FISHING.md section 9), 1. Grid, scale, projection, 2. Light, shading, outlines, 3. Palette rules, 4. Anchors and file conventions, 5. Quality bar, 6. Ruined-city kit (`tools/art/ruins_city/`, Milestone C) (+5 more)

### Community 65 - "A living settlement — design + data contracts (Milestone D, 2026-11-10)"
Cohesion: 0.22
Nodes (8): 1. The market — `scripts/market.gd`, `scripts/market_rules.gd`, 2. The caravan — `scripts/caravan.gd`, `data/caravan.json`, 3. The trading post — `scripts/structures.gd`, 4. Festivals — `data/festivals.json`, `scripts/festivals.gd`, 5. The Signal — `data/story.json`, `scripts/story.gd`, 6. New dialogue flags, 7. Art list, A living settlement — design + data contracts (Milestone D, 2026-11-10)

### Community 66 - "ia_tools.py"
Cohesion: 0.33
Nodes (5): axe(), build(), hoe(), pickaxe(), scythe()

### Community 68 - "fi_fish.py"
Cohesion: 0.13
Nodes (18): 5. The fish, ash_trout(), bog_eel(), draw(), eel(), frostfin(), glowfin(), iron_pike() (+10 more)

### Community 69 - "export_all.sh"
Cohesion: 0.70
Nodes (4): output_for(), preset_for(), export_all.sh script, sign_macos_zip()

### Community 70 - "Instrument"
Cohesion: 0.19
Nodes (4): Instrument, NoteInstrument, _PhraseLead, _phrases()

### Community 71 - "lv_common.py"
Cohesion: 0.17
Nodes (5): glow(), shadow(), stamp(), tint(), under()

### Community 72 - "Building Art — Phase 6 "Art pass 1" (buildings half) — PixelLab Provenance"
Cohesion: 0.29
Nodes (6): Building Art — Phase 6 "Art pass 1" (buildings half) — PixelLab Provenance, Generation parameters (all 10 objects) — SUPERSEDED, see "Revision note" below, Ranch/Sanctuary buildings (Phase 8) — 3 new kinds, Revision note (2026-07-10, same session as Phase 6's first buildings pass): too 3D/isometric, The 10 objects (all generated 2026-07-10, one accepted attempt each, no rejects), The sub-32px sizing resolution (5 kinds)

### Community 73 - "Tile Art — Phase 1 Test Set"
Cohesion: 0.29
Nodes (6): Metadata, Provenance, Revision note (Phase 3): settlement palette boosted, ruins left alone, `ruins/rubble_planks_tileset.png` + `.json`, `settlement/grass_soil_tileset.png` + `.json`, Tile Art — Phase 1 Test Set

### Community 74 - "sys"
Cohesion: 0.27
Nodes (4): main(), main(), write(), load()

### Community 75 - "burst"
Cohesion: 0.15
Nodes (10): _auto(), burst(), chime(), church_bell(), colored(), kalimba(), marimba(), musicbox() (+2 more)

### Community 76 - "UI Art — PixelLab Provenance (Phase 2 basic HUD)"
Cohesion: 0.33
Nodes (5): HUD redesign (2026-07-11 playtest feedback session), Pixel font (`fonts/`, added after Phase 4), Revision note (Phase 3): palette boosted, Stardew-fusion pass (2026-07-11, second HUD session), UI Art — PixelLab Provenance (Phase 2 basic HUD)

### Community 77 - "enemies/build.py"
Cohesion: 0.13
Nodes (10): build_enemies(), main(), verify_sheet(), anim_gif(), build(), contact_sheet(), _player(), assemble() (+2 more)

### Community 78 - "master.py"
Cohesion: 0.16
Nodes (12): circular_eq(), decode(), encode_ogg(), _hop_energy(), _k_weight_sos(), limit(), lufs(), master() (+4 more)

### Community 80 - "Stardew Valley — Structural Reference (Pelican Town & Marnie's Ranch)"
Cohesion: 0.40
Nodes (4): Marnie's Ranch — structural takeaways, Pelican Town — structural takeaways, Stardew Valley — Structural Reference (Pelican Town & Marnie's Ranch), What this unblocks

### Community 81 - "fishing/build.py"
Cohesion: 0.15
Nodes (17): build_dishes(), build_fish(), build_fx(), build_preview(), check(), main(), write(), bobber() (+9 more)

### Community 82 - "Crop Art — PixelLab Provenance (Phase 3)"
Cohesion: 0.50
Nodes (3): Crop Art — PixelLab Provenance (Phase 3), Known follow-up: these PNGs are not yet imported, Revision note (Phase 3): palette boosted, and the import gap above is now closed

### Community 83 - "Item Icon Art — PixelLab Provenance (Phase 3)"
Cohesion: 0.33
Nodes (5): Fishing — code-generated (13 fish + 3 dishes), Item Icon Art — PixelLab Provenance (Phase 3), Known follow-up: not yet imported, Milestone D quest items — code-generated (`vault_seeds.png`, `festival_ribbon.png`), Revision note (Phase 3): palette boosted, and the import gap above is now closed

### Community 84 - "Prop Art — PixelLab Provenance"
Cohesion: 0.50
Nodes (3): Prop Art — PixelLab Provenance, `ranch_cow.png`, `ranch_goat.png` — Phase 8 Ranch/Sanctuary decorative livestock, `wrecked_car.png`, `weed_tuft.png` — Path zone dressing (zone split, Stage 1)

### Community 85 - "registry.py"
Cohesion: 0.43
Nodes (6): name(), _add(), deco(), Entry, _pick(), deco()

### Community 86 - "Fishing (2026-11-24)"
Cohesion: 0.20
Nodes (9): 1. Getting the rod, 2. Where, 3. Casting and the bite, 4. The reel: line tension, 6. What fish are for, 7. Journal and dialogue, 8. Save, 9. Art (`tools/art/fishing/`, code-generated) (+1 more)

### Community 89 - "living/build.py"
Cohesion: 0.06
Nodes (40): build_buildings(), build_festival(), build_fx(), build_items(), build_preview(), build_ruins(), build_stall(), check() (+32 more)

### Community 95 - "creak"
Cohesion: 0.25
Nodes (4): creak(), periodic_env(), resonate(), smooth_noise()

### Community 97 - "sys"
Cohesion: 0.15
Nodes (4): draw(), main(), build(), _hex()

## Knowledge Gaps
- **6 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Canvas` connect `Canvas` to `outline`, `rgba`, `ramp`, `previews.py`, `lv_vault.py`, `trees.py`, `lv_festival.py`, `terrain.py`, `hval`, `rc_common.py`, `rc_walls.py`, `debris.py`, `fences.py`?**
  _High betweenness centrality (0.077) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `Canvas` (e.g. with `load()` and `Scene`) actually correct?**
  _`Canvas` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Should `ns` be split into smaller, more focused modules?**
  _Cohesion score 0.07496194824961948 - nodes in this community are weakly interconnected._
- **Why does `Ramp` connect `Ramp` to `Wasteland Harvest — Art Style Guide (code-generated pixel art)`, `ia_tools.py`, `fi_fish.py`, `.render`, `ia_produce.py`, `ia_lib.py`, `ia_place.py`, `ia_crops.py`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._
- **Are the 26 inferred relationships involving `Ramp` (e.g. with `fish_stew()` and `grilled_fish()`) actually correct?**
  _`Ramp` has 26 INFERRED edges - model-reasoned connections that need verification._
- **Should `Song` be split into smaller, more focused modules?**
  _Cohesion score 0.06580645161290323 - nodes in this community are weakly interconnected._
- **Why does `mix()` connect `ramp` to `Canvas`, `outline`, `rgba`, `lv_vault.py`, `trees.py`, `lv_festival.py`, `terrain.py`, `hval`, `rc_common.py`, `rc_walls.py`, `debris.py`, `fences.py`?**
  _High betweenness centrality (0.049) - this node is a cross-community bridge._