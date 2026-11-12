# Graph Report - wasteland-harvest  (2026-11-12)

## Corpus Check
- 170 files · ~264,084 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 1564 file(s) not represented in the graph (top: .import 1097, .gd 214, .uid 214)
- WARNING: 1564 of 2859 files seen (55%) have no supported extractor and are missing from this graph entirely. It may look complete while representing only part of the codebase.

## Summary
- 2512 nodes · 7088 edges · 81 communities (77 shown, 4 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 712 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `13c0e839`
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
- burst
- bloater.py
- ia_crops.py
- Year 1 — Foundation & Prototype
- Canvas
- palette.py
- fences.py
- palette.py
- townsfolk/build.py
- rgba
- instruments.py
- palette.py
- rgba
- hound.py
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
- sfx/build_all.py
- terrain.py
- 3. Brutal assessment — what a player would actually experience
- os
- shambler.py
- lv_buildings.py
- Wasteland Harvest
- Social life, requests and Town Works — design + data contracts (Milestone B, 2026-10-08)
- Wasteland Harvest — Map Layout Sketches
- part
- runner.py
- wang.py
- music/build_all.py
- Character Art — PixelLab Provenance
- items/build.py
- Wasteland Harvest — Art Style Guide (code-generated pixel art)
- A living settlement — design + data contracts (Milestone D, 2026-11-10)
- ia_tools.py
- export_all.sh
- Building Art — Phase 6 "Art pass 1" (buildings half) — PixelLab Provenance
- Tile Art — Phase 1 Test Set
- UI Art — PixelLab Provenance (Phase 2 basic HUD)
- enemies/build.py
- Stardew Valley — Structural Reference (Pelican Town & Marnie's Ranch)
- Crop Art — PixelLab Provenance (Phase 3)
- Item Icon Art — PixelLab Provenance (Phase 3)
- Prop Art — PixelLab Provenance
- Audio
- living/build.py

## God Nodes (most connected - your core abstractions)
1. `Canvas` - 158 edges
2. `Ramp` - 144 edges
3. `mix()` - 144 edges
4. `ns()` - 115 edges
5. `sfx()` - 102 edges
6. `Mix` - 90 edges
7. `norm()` - 82 edges
8. `rgba()` - 74 edges
9. `ramp()` - 59 edges
10. `outline()` - 57 edges

## Surprising Connections (you probably didn't know these)
- `3. Dialogue — `data/dialogue.json` (v2)` --references--> `player_hurt()`  [INFERRED]
  docs/SOCIAL_AND_QUESTS.md → tools/audio/sfx/gen_combat.py
- `8. Townsfolk and Town Works (`tools/art/townsfolk/`, Milestone B)` --references--> `gift_icon()`  [INFERRED]
  docs/ART_STYLE.md → tools/art/townsfolk/tf_ui.py
- `8. Townsfolk and Town Works (`tools/art/townsfolk/`, Milestone B)` --references--> `heart_empty()`  [INFERRED]
  docs/ART_STYLE.md → tools/art/townsfolk/tf_ui.py
- `8. Townsfolk and Town Works (`tools/art/townsfolk/`, Milestone B)` --references--> `quest_marker()`  [INFERRED]
  docs/ART_STYLE.md → tools/art/townsfolk/tf_ui.py
- `8. Townsfolk and Town Works (`tools/art/townsfolk/`, Milestone B)` --references--> `talk_icon()`  [INFERRED]
  docs/ART_STYLE.md → tools/art/townsfolk/tf_ui.py

## Import Cycles
- None detected.

## Communities (81 total, 4 thin omitted)

### Community 0 - "ns"
Cohesion: 0.05
Nodes (133): bird_note(), bird_phrase(), cricket(), owl_hoot(), wood_hammer(), alarm(), bloater_pop(), bullet_impact() (+125 more)

### Community 1 - "Song"
Cohesion: 0.05
Nodes (42): Kit, Bass, CachedDecay, Chip, EPiano, FMBell, Instrument, _LRU (+34 more)

### Community 2 - "Ramp"
Cohesion: 0.04
Nodes (66): 2. Hearts (affinity) — `scripts/affinity.gd`, adrenal_shot(), bandage(), berry_jam(), bowl(), canned_beans(), cheese(), choco_bar() (+58 more)

### Community 3 - "theory.py"
Cohesion: 0.06
Nodes (35): grid_len(), melody_length(), Note, parse_chart(), parse_grid(), parse_melody(), _strip_comments(), arp() (+27 more)

### Community 4 - "Canvas"
Cohesion: 0.07
Nodes (17): Canvas, hstrip(), _over(), bones(), build(), car_burnt(), _cover(), dumpster_open() (+9 more)

### Community 5 - "outline"
Cohesion: 0.07
Nodes (32): 8. Townsfolk and Town Works (`tools/art/townsfolk/`, Milestone B), line_points(), outline(), _beam(), build(), _cave_in(), clapboard(), clinic() (+24 more)

### Community 6 - ".render"
Cohesion: 0.13
Nodes (22): Phase 3 — Farming Core & Inventory System, mystery_jerky(), potato_hash(), bresenham(), Layer, cobble_path_icon(), gravel_path_icon(), _lantern() (+14 more)

### Community 7 - "gen_ambience.py"
Cohesion: 0.09
Nodes (41): name(), amb_farm_day(), amb_farm_night(), amb_fire(), amb_geiger_loop(), amb_indoor(), amb_radstorm(), amb_rain() (+33 more)

### Community 8 - "ramp"
Cohesion: 0.21
Nodes (21): ramp(), barricade(), build(), bus_wreck(), _car(), car_wreck(), concrete_barrier(), dumpster() (+13 more)

### Community 9 - "ia_produce.py"
Cohesion: 0.08
Nodes (35): crop_colors(), crop_ramp(), R(), ramp(), ash_apple(), ash_beet(), blister_tomato(), cactus_pear() (+27 more)

### Community 10 - "previews.py"
Cohesion: 0.17
Nodes (14): load(), save(), Scene, sub(), zoom(), contact(), frame_of(), main() (+6 more)

### Community 11 - "effects.py"
Cohesion: 0.07
Nodes (34): apply_fx(), body(), chorus(), compress(), convolve_reverb(), echo(), eq(), haas() (+26 more)

### Community 12 - "op_scene.py"
Cohesion: 0.09
Nodes (25): canvas(), crop(), disc(), ellipse(), fence_run(), frame(), flip(), ground() (+17 more)

### Community 13 - "trees.py"
Cohesion: 0.07
Nodes (32): canopy(), Puff, scatter_blossoms(), check_alpha(), edge_masks(), from_text(), hexs(), lum() (+24 more)

### Community 14 - "ia_lib.py"
Cohesion: 0.07
Nodes (27): 9. A living settlement (`tools/art/living/`, Milestone D), kind_at(), add_shadow(), apply_outline(), auto_ramp(), check_icon(), _clean(), compose() (+19 more)

### Community 15 - "ia_place.py"
Cohesion: 0.11
Nodes (33): bee_box_icon(), bee_box_world(), _beebox(), _bricks(), compost_bin_world(), crate_chest_world(), _furnace(), kiln_icon() (+25 more)

### Community 16 - "validate_social_data.py"
Cohesion: 0.06
Nodes (26): load_json(), load(), main(), season_run(), main(), check_dialogue(), check_gifts(), check_intro_shapes() (+18 more)

### Community 17 - "op_pages.py"
Cohesion: 0.10
Nodes (24): _allowed(), build_pages(), build_preview(), build_regions(), check_page(), main(), childhood(), claim() (+16 more)

### Community 18 - "rc_common.py"
Cohesion: 0.07
Nodes (14): chips(), darken(), dk(), finish(), plank(), rust_streak(), soot(), text() (+6 more)

### Community 19 - "hval"
Cohesion: 0.11
Nodes (25): boarded_door(), build(), fill_block(), fill_brick(), fill_concrete(), fill_siding(), grime(), ledge() (+17 more)

### Community 20 - "rc_walls.py"
Cohesion: 0.08
Nodes (12): _band(), _base_details(), _bits(), Brick, build(), Concrete, frame(), _height_at() (+4 more)

### Community 21 - "drums.py"
Cohesion: 0.20
Nodes (29): anvil(), boom(), brush(), chime(), clap(), crash(), _env(), hat() (+21 more)

### Community 22 - "debris.py"
Cohesion: 0.09
Nodes (25): _bolt(), build(), _drum_lying(), _finish(), junk(), _leaf(), _lichen(), log_large() (+17 more)

### Community 23 - "Wasteland Harvest — Game Design Document"
Cohesion: 0.06
Nodes (30): 10. Win / Lose Conditions, 11. Scope-Addition Flags (reconciled into ROADMAP.md — kept here for design rationale), 1. High Concept, 2. World & Lore, 3. Player Character & the Opening, 4. Core Gameplay Loop — The Settlement (Cozy-Core), 5. The Expedition Loop — Ruins, Radiation & the Ammo Economy, 6. The Raider Faction & Reputation System (+22 more)

### Community 24 - "sfx/synth.py"
Cohesion: 0.03
Nodes (61): _arr(), biquad(), _blep(), bp(), butter(), cents(), chip(), chirp() (+53 more)

### Community 25 - "burst"
Cohesion: 0.05
Nodes (29): _auto(), bubble(), burst(), chime(), church_bell(), circ_conv(), circ_reverb(), colored() (+21 more)

### Community 26 - "bloater.py"
Cohesion: 0.12
Nodes (23): _arms(), _belly(), BPose, _chest(), _cloud(), death_frames(), _ell(), frame() (+15 more)

### Community 27 - "ia_crops.py"
Cohesion: 0.16
Nodes (17): build(), bush_flowering(), bush_fruit(), crop_ramps(), dead_sprite(), draw(), flower(), grain() (+9 more)

### Community 28 - "Year 1 — Foundation & Prototype"
Cohesion: 0.07
Nodes (27): ⚡ Accelerated Plan (2026-10-07) — supersedes the order of Phases 7(stages 4-5) and 9–18, Milestone A — "The first hour feels great", Milestone B — "A reason to come back tomorrow", Milestone C — "The wasteland outside the fence", Milestone D — "A living settlement", Milestone E — "Ship-ready", Phase 10 — Business System, Crafting & Advanced Economy, Phase 11 — Seasons, Weather & World Events (+19 more)

### Community 29 - "Canvas"
Cohesion: 0.10
Nodes (3): Canvas, line_points(), _over()

### Community 30 - "palette.py"
Cohesion: 0.13
Nodes (10): build(), hp_icon(), rad_icon(), Arm, blood_pool(), Pose, mix(), _nbrs() (+2 more)

### Community 31 - "fences.py"
Cohesion: 0.17
Nodes (18): _beam(), build(), chainlink_frame(), _dark(), gate_chainlink(), gate_wood(), _log(), _mesh() (+10 more)

### Community 32 - "palette.py"
Cohesion: 0.14
Nodes (4): layer(), Look, Pose, stamp()

### Community 33 - "townsfolk/build.py"
Cohesion: 0.13
Nodes (15): build_buildings(), build_characters(), build_preview(), build_ui(), main(), verify_building(), write(), check_frame() (+7 more)

### Community 34 - "rgba"
Cohesion: 0.19
Nodes (17): alert_mark(), blood_splat(), bolt(), build(), _burst(), _center(), hit_spark(), ichor_splat() (+9 more)

### Community 35 - "instruments.py"
Cohesion: 0.08
Nodes (26): _interp_key(), ks_design(), ks_loop(), _smoothstep(), vel_amp(), additive(), biquad(), chain() (+18 more)

### Community 36 - "palette.py"
Cohesion: 0.09
Nodes (5): gear(), gear(), Arm, gear(), gear()

### Community 37 - "rgba"
Cohesion: 0.22
Nodes (9): build(), _flower(), flowers(), _grass(), _leafpair(), leaves_autumn(), snow_clump(), specks() (+1 more)

### Community 38 - "hound.py"
Cohesion: 0.22
Nodes (12): _carcass(), death_frames(), frame(), frame_e(), frame_sn(), frames(), HPose, _leg() (+4 more)

### Community 39 - "items/build.py"
Cohesion: 0.16
Nodes (7): save(), crop_sheet(), _font(), icon_sheet(), mock_scene(), _text_color(), world_sheet()

### Community 40 - "rgba"
Cohesion: 0.16
Nodes (26): rgba(), barrel(), bench(), build(), laundry_line(), hang(), rope_y(), market_stall() (+18 more)

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
Cohesion: 0.19
Nodes (13): amb_flags(), amb_metrics(), analyze(), _cmap(), contact_sheet(), draw_tile(), ffmpeg_lufs(), main() (+5 more)

### Community 46 - "lv_festival.py"
Cohesion: 0.21
Nodes (11): _bowl(), bunting(), festival_lantern(), festival_table(), _jug(), _lantern_body(), lantern_frame(), _loaf() (+3 more)

### Community 47 - "Building a Release (Milestone E)"
Cohesion: 0.33
Nodes (5): Before a store upload (Steam / itch.io), Building a Release (Milestone E), One command, The presets, What's needed

### Community 48 - "weather_icons.py"
Cohesion: 0.39
Nodes (12): build(), _canvas(), clear(), clear_night(), _cloud(), _disc(), _hex(), _outline() (+4 more)

### Community 49 - "sfx/build_all.py"
Cohesion: 0.23
Nodes (9): finalize_amb(), finalize_sfx(), _load_existing_stats(), main(), render(), _render(), _section(), seed_for() (+1 more)

### Community 50 - "terrain.py"
Cohesion: 0.05
Nodes (27): grid_sheet(), Asphalt, build(), Cobble, Concrete, _detail_clover(), _detail_pebble(), _detail_tips() (+19 more)

### Community 51 - "3. Brutal assessment — what a player would actually experience"
Cohesion: 0.14
Nodes (13): 1. Verification of the 2026-10-07 status report, 2. What is genuinely good (keep it), 3.1 It does not look like a game yet (presentation: **2/10**), 3.2 It is completely silent (audio: **0/10**), 3.3 Interaction feel (controls: **4/10**), 3.4 The farming loop is thin and punishing (core gameplay: **3/10**), 3.5 Nothing to work toward (progression/goals: **2/10**), 3.6 Half the game does not exist (expeditions/combat: **0/10**) (+5 more)

### Community 52 - "os"
Cohesion: 0.09
Nodes (11): draw(), main(), build(), _hex(), build(), _tile_h(), _tile_v(), build() (+3 more)

### Community 53 - "shambler.py"
Cohesion: 0.14
Nodes (11): assemble(), check(), arms_e(), arms_limp_s(), arms_n(), arms_s(), arms_up_s(), death_frames() (+3 more)

### Community 54 - "lv_buildings.py"
Cohesion: 0.14
Nodes (18): Living settlement buildings (Milestone D) — code-generated, 3 kinds, mix(), _barrel_body(), _dk(), _dk(), festival_booth(), mayor_house_antenna(), _outlined() (+10 more)

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
Cohesion: 0.30
Nodes (8): part(), stamp(), build(), gift_icon(), heart_empty(), heart_full(), quest_marker(), talk_icon()

### Community 59 - "runner.py"
Cohesion: 0.14
Nodes (10): Body, bbox(), A(), arms_e(), arms_s(), death_frames(), frames(), poses() (+2 more)

### Community 60 - "wang.py"
Cohesion: 0.21
Nodes (6): main(), bits(), cov(), coverage(), distances(), verify()

### Community 61 - "music/build_all.py"
Cohesion: 0.18
Nodes (10): main(), write(), fmt_time(), main(), _print_result(), sync_import(), _worker(), write_manifest() (+2 more)

### Community 62 - "Character Art — PixelLab Provenance"
Cohesion: 0.18
Nodes (10): Character Art — PixelLab Provenance, Enemies (code-generated) — Milestone C, Files, Files, Files (per NPC, same layout as `player/`), `mayor_harlan/`, `marta/`, `scout_kael/` — Phase 6 "Art pass 1" NPCs, `player/` — Phase 2 player character, `rancher_silas/` — Phase 8 Ranch/Sanctuary keeper NPC (+2 more)

### Community 63 - "items/build.py"
Cohesion: 0.33
Nodes (5): check(), main(), placeholder(), registry(), res_to_path()

### Community 64 - "Wasteland Harvest — Art Style Guide (code-generated pixel art)"
Cohesion: 0.20
Nodes (9): 10. The opening and character creation (`tools/art/opening/`, Milestone E), 1. Grid, scale, projection, 2. Light, shading, outlines, 3. Palette rules, 4. Anchors and file conventions, 5. Quality bar, 6. Ruined-city kit (`tools/art/ruins_city/`, Milestone C), 7. Enemies, combat FX, combat HUD (`tools/art/enemies/`, Milestone C) (+1 more)

### Community 65 - "A living settlement — design + data contracts (Milestone D, 2026-11-10)"
Cohesion: 0.22
Nodes (8): 1. The market — `scripts/market.gd`, `scripts/market_rules.gd`, 2. The caravan — `scripts/caravan.gd`, `data/caravan.json`, 3. The trading post — `scripts/structures.gd`, 4. Festivals — `data/festivals.json`, `scripts/festivals.gd`, 5. The Signal — `data/story.json`, `scripts/story.gd`, 6. New dialogue flags, 7. Art list, A living settlement — design + data contracts (Milestone D, 2026-11-10)

### Community 66 - "ia_tools.py"
Cohesion: 0.16
Nodes (7): Sprite, axe(), build(), hoe(), pickaxe(), scythe(), watering_can()

### Community 69 - "export_all.sh"
Cohesion: 0.50
Nodes (3): OUT, PRESET, export_all.sh script

### Community 72 - "Building Art — Phase 6 "Art pass 1" (buildings half) — PixelLab Provenance"
Cohesion: 0.29
Nodes (6): Building Art — Phase 6 "Art pass 1" (buildings half) — PixelLab Provenance, Generation parameters (all 10 objects) — SUPERSEDED, see "Revision note" below, Ranch/Sanctuary buildings (Phase 8) — 3 new kinds, Revision note (2026-07-10, same session as Phase 6's first buildings pass): too 3D/isometric, The 10 objects (all generated 2026-07-10, one accepted attempt each, no rejects), The sub-32px sizing resolution (5 kinds)

### Community 73 - "Tile Art — Phase 1 Test Set"
Cohesion: 0.29
Nodes (6): Metadata, Provenance, Revision note (Phase 3): settlement palette boosted, ruins left alone, `ruins/rubble_planks_tileset.png` + `.json`, `settlement/grass_soil_tileset.png` + `.json`, Tile Art — Phase 1 Test Set

### Community 76 - "UI Art — PixelLab Provenance (Phase 2 basic HUD)"
Cohesion: 0.33
Nodes (5): HUD redesign (2026-07-11 playtest feedback session), Pixel font (`fonts/`, added after Phase 4), Revision note (Phase 3): palette boosted, Stardew-fusion pass (2026-07-11, second HUD session), UI Art — PixelLab Provenance (Phase 2 basic HUD)

### Community 77 - "enemies/build.py"
Cohesion: 0.21
Nodes (8): build_enemies(), main(), verify_sheet(), anim_gif(), build(), contact_sheet(), _player(), frame_slice()

### Community 80 - "Stardew Valley — Structural Reference (Pelican Town & Marnie's Ranch)"
Cohesion: 0.40
Nodes (4): Marnie's Ranch — structural takeaways, Pelican Town — structural takeaways, Stardew Valley — Structural Reference (Pelican Town & Marnie's Ranch), What this unblocks

### Community 82 - "Crop Art — PixelLab Provenance (Phase 3)"
Cohesion: 0.50
Nodes (3): Crop Art — PixelLab Provenance (Phase 3), Known follow-up: these PNGs are not yet imported, Revision note (Phase 3): palette boosted, and the import gap above is now closed

### Community 83 - "Item Icon Art — PixelLab Provenance (Phase 3)"
Cohesion: 0.40
Nodes (4): Item Icon Art — PixelLab Provenance (Phase 3), Known follow-up: not yet imported, Milestone D quest items — code-generated (`vault_seeds.png`, `festival_ribbon.png`), Revision note (Phase 3): palette boosted, and the import gap above is now closed

### Community 84 - "Prop Art — PixelLab Provenance"
Cohesion: 0.50
Nodes (3): Prop Art — PixelLab Provenance, `ranch_cow.png`, `ranch_goat.png` — Phase 8 Ranch/Sanctuary decorative livestock, `wrecked_car.png`, `weed_tuft.png` — Path zone dressing (zone split, Stage 1)

### Community 89 - "living/build.py"
Cohesion: 0.05
Nodes (44): build_buildings(), build_festival(), build_fx(), build_items(), build_preview(), build_ruins(), build_stall(), check() (+36 more)

## Knowledge Gaps
- **2 isolated node(s):** `OUT`, `PRESET`
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 846 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Ramp` connect `Ramp` to `ia_tools.py`, `.render`, `ia_produce.py`, `ia_lib.py`, `ia_place.py`, `ia_crops.py`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `Canvas` (e.g. with `load()` and `Scene`) actually correct?**
  _`Canvas` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `OUT`, `PRESET` to the rest of the system?**
  _2 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `ns` be split into smaller, more focused modules?**
  _Cohesion score 0.05438151591997746 - nodes in this community are weakly interconnected._
- **Why does `Canvas` connect `Canvas` to `rgba`, `outline`, `rgba`, `ramp`, `previews.py`, `lv_vault.py`, `trees.py`, `lv_festival.py`, `terrain.py`, `hval`, `rc_common.py`, `rc_walls.py`, `debris.py`, `lv_buildings.py`, `fences.py`?**
  _High betweenness centrality (0.050) - this node is a cross-community bridge._
- **Are the 14 inferred relationships involving `Ramp` (e.g. with `crop_ramp()` and `ramp()`) actually correct?**
  _`Ramp` has 14 INFERRED edges - model-reasoned connections that need verification._
- **Should `Song` be split into smaller, more focused modules?**
  _Cohesion score 0.05264180264180264 - nodes in this community are weakly interconnected._