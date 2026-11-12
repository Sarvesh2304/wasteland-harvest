# Graph Report - wasteland-harvest  (2026-11-12)

## Corpus Check
- 153 files · ~239,869 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 1447 file(s) not represented in the graph (top: .import 1023, .gd 194, .uid 194)
- WARNING: 1447 of 2648 files seen (55%) have no supported extractor and are missing from this graph entirely. It may look complete while representing only part of the codebase.

## Summary
- 2290 nodes · 6578 edges · 91 communities (81 shown, 10 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 690 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6ccf6d3e`
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
- mix
- ia_produce.py
- previews.py
- effects.py
- rgba
- trees.py
- ia_lib.py
- ia_place.py
- validate_social_data.py
- hound.py
- rc_common.py
- hval
- rc_walls.py
- drums.py
- ramp_cos
- Wasteland Harvest — Game Design Document
- sfx/synth.py
- numpy
- bloater.py
- ia_crops.py
- Year 1 — Foundation & Prototype
- Canvas
- rgba
- fences.py
- palette.py
- townsfolk/build.py
- lib.py
- engine/synth.py
- tf_doll.py
- end_fade
- sys
- items/build.py
- fx.py
- lv_common.py
- rig.py
- _arr
- math
- analyze.py
- master.py
- burst
- weather_icons.py
- sfx/build_all.py
- terrain.py
- 3. Brutal assessment — what a player would actually experience
- os
- shambler.py
- decor.py
- Wasteland Harvest
- Social life, requests and Town Works — design + data contracts (Milestone B, 2026-10-08)
- Wasteland Harvest — Map Layout Sketches
- part
- runner.py
- Feature
- music/build_all.py
- Character Art — PixelLab Provenance
- _ground
- Wasteland Harvest — Art Style Guide (code-generated pixel art)
- A living settlement — design + data contracts (Milestone D, 2026-11-10)
- ia_tools.py
- butter
- Cobble
- wang.py
- make_ir
- creak
- Building Art — Phase 6 "Art pass 1" (buildings half) — PixelLab Provenance
- Tile Art — Phase 1 Test Set
- Soil
- Terrain
- UI Art — PixelLab Provenance (Phase 2 basic HUD)
- enemies/preview.py
- RubbleGround
- loudness
- Stardew Valley — Structural Reference (Pelican Town & Marnie's Ranch)
- saw
- Crop Art — PixelLab Provenance (Phase 3)
- Item Icon Art — PixelLab Provenance (Phase 3)
- Prop Art — PixelLab Provenance
- Dirt
- Water
- Audio

## God Nodes (most connected - your core abstractions)
1. `Canvas` - 145 edges
2. `Ramp` - 142 edges
3. `mix()` - 127 edges
4. `ns()` - 115 edges
5. `sfx()` - 102 edges
6. `Mix` - 90 edges
7. `norm()` - 82 edges
8. `rgba()` - 66 edges
9. `ramp()` - 58 edges
10. `outline()` - 51 edges

## Surprising Connections (you probably didn't know these)
- `3. Dialogue — `data/dialogue.json` (v2)` --references--> `player_hurt()`  [INFERRED]
  docs/SOCIAL_AND_QUESTS.md → tools/audio/sfx/gen_combat.py
- `8. Townsfolk and Town Works (`tools/art/townsfolk/`, Milestone B)` --references--> `heart_empty()`  [INFERRED]
  docs/ART_STYLE.md → tools/art/townsfolk/tf_ui.py
- `8. Townsfolk and Town Works (`tools/art/townsfolk/`, Milestone B)` --references--> `quest_marker()`  [INFERRED]
  docs/ART_STYLE.md → tools/art/townsfolk/tf_ui.py
- `8. Townsfolk and Town Works (`tools/art/townsfolk/`, Milestone B)` --references--> `gift_icon()`  [INFERRED]
  docs/ART_STYLE.md → tools/art/townsfolk/tf_ui.py
- `8. Townsfolk and Town Works (`tools/art/townsfolk/`, Milestone B)` --references--> `talk_icon()`  [INFERRED]
  docs/ART_STYLE.md → tools/art/townsfolk/tf_ui.py

## Import Cycles
- None detected.

## Communities (91 total, 10 thin omitted)

### Community 0 - "ns"
Cohesion: 0.06
Nodes (130): owl_hoot(), wood_hammer(), alarm(), bloater_pop(), bullet_impact(), container_open(), crit(), crossbow() (+122 more)

### Community 1 - "Song"
Cohesion: 0.05
Nodes (43): Kit, Bass, CachedDecay, Chip, EPiano, FMBell, Instrument, ks_loop() (+35 more)

### Community 2 - "Ramp"
Cohesion: 0.05
Nodes (61): adrenal_shot(), bandage(), berry_jam(), bowl(), canned_beans(), cheese(), choco_bar(), coffee() (+53 more)

### Community 3 - "theory.py"
Cohesion: 0.05
Nodes (41): grid_len(), melody_length(), Note, parse_chart(), parse_grid(), parse_melody(), _strip_comments(), arp() (+33 more)

### Community 4 - "Canvas"
Cohesion: 0.06
Nodes (23): _bolt(), build(), _drum_lying(), _finish(), junk(), _leaf(), _lichen(), log_large() (+15 more)

### Community 5 - "outline"
Cohesion: 0.07
Nodes (35): 8. Townsfolk and Town Works (`tools/art/townsfolk/`, Milestone B), line_points(), outline(), _beam(), build(), _cave_in(), clapboard(), clinic() (+27 more)

### Community 6 - ".render"
Cohesion: 0.09
Nodes (26): Phase 3 — Farming Core & Inventory System, mystery_jerky(), potato_hash(), bresenham(), _clean(), Layer, Sprite, cobble_path_icon() (+18 more)

### Community 7 - "gen_ambience.py"
Cohesion: 0.10
Nodes (38): amb_farm_day(), amb_farm_night(), amb_fire(), amb_geiger_loop(), amb_indoor(), amb_radstorm(), amb_rain(), amb_river() (+30 more)

### Community 8 - "mix"
Cohesion: 0.13
Nodes (38): hstrip(), mix(), ramp(), barricade(), build(), bus_wreck(), _car(), car_wreck() (+30 more)

### Community 9 - "ia_produce.py"
Cohesion: 0.07
Nodes (35): crop_colors(), crop_ramp(), R(), ramp(), ash_apple(), ash_beet(), blister_tomato(), cactus_pear() (+27 more)

### Community 10 - "previews.py"
Cohesion: 0.12
Nodes (17): load(), save(), Scene, sub(), zoom(), contact(), frame_of(), main() (+9 more)

### Community 11 - "effects.py"
Cohesion: 0.09
Nodes (25): apply_fx(), body(), chorus(), compress(), convolve_reverb(), echo(), eq(), haas() (+17 more)

### Community 12 - "rgba"
Cohesion: 0.11
Nodes (30): rgba(), barrel(), _barrel_body(), bench(), build(), _dk(), laundry_line(), hang() (+22 more)

### Community 13 - "trees.py"
Cohesion: 0.11
Nodes (24): canopy(), Puff, scatter_blossoms(), rng(), value_noise(), rock(), _ash_puffs(), _ash_winter() (+16 more)

### Community 14 - "ia_lib.py"
Cohesion: 0.08
Nodes (24): kind_at(), add_shadow(), apply_outline(), auto_ramp(), check_icon(), compose(), dilate4(), from_oklch() (+16 more)

### Community 15 - "ia_place.py"
Cohesion: 0.11
Nodes (33): bee_box_icon(), bee_box_world(), _beebox(), _bricks(), compost_bin_world(), crate_chest_world(), _furnace(), kiln_icon() (+25 more)

### Community 16 - "validate_social_data.py"
Cohesion: 0.09
Nodes (21): load_json(), check_dialogue(), check_gifts(), check_intro_shapes(), check_projects(), check_requests(), check_services(), check_taste_block() (+13 more)

### Community 17 - "hound.py"
Cohesion: 0.12
Nodes (17): _carcass(), death_frames(), frame(), frame_e(), frame_sn(), frames(), HPose, _leg() (+9 more)

### Community 18 - "rc_common.py"
Cohesion: 0.07
Nodes (14): chips(), darken(), dk(), finish(), plank(), rust_streak(), soot(), text() (+6 more)

### Community 19 - "hval"
Cohesion: 0.14
Nodes (22): ring(), boarded_door(), build(), fill_block(), fill_brick(), fill_concrete(), fill_siding(), grime() (+14 more)

### Community 20 - "rc_walls.py"
Cohesion: 0.08
Nodes (12): _band(), _base_details(), _bits(), Brick, build(), Concrete, frame(), _height_at() (+4 more)

### Community 21 - "drums.py"
Cohesion: 0.19
Nodes (28): anvil(), boom(), brush(), chime(), clap(), crash(), _env(), hat() (+20 more)

### Community 22 - "ramp_cos"
Cohesion: 0.14
Nodes (11): _interp_key(), ks_design(), _smoothstep(), vel_amp(), dc_block(), onepole_lp(), place(), ramp_cos() (+3 more)

### Community 23 - "Wasteland Harvest — Game Design Document"
Cohesion: 0.06
Nodes (30): 10. Win / Lose Conditions, 11. Scope-Addition Flags (reconciled into ROADMAP.md — kept here for design rationale), 1. High Concept, 2. World & Lore, 3. Player Character & the Opening, 4. Core Gameplay Loop — The Settlement (Cozy-Core), 5. The Expedition Loop — Ruins, Radiation & the Ammo Economy, 6. The Raider Faction & Reputation System (+22 more)

### Community 24 - "sfx/synth.py"
Cohesion: 0.10
Nodes (18): biquad(), bp(), cents(), circ_add(), fft_eq(), grains(), hp(), hshelf() (+10 more)

### Community 25 - "numpy"
Cohesion: 0.08
Nodes (18): circ_apply(), crush(), env_bell(), env_pts(), loop_crossfade(), metal_modes(), mtof(), normalize_peak() (+10 more)

### Community 26 - "bloater.py"
Cohesion: 0.13
Nodes (20): _arms(), _belly(), BPose, _chest(), _cloud(), death_frames(), _ell(), frame() (+12 more)

### Community 27 - "ia_crops.py"
Cohesion: 0.16
Nodes (17): build(), bush_flowering(), bush_fruit(), crop_ramps(), dead_sprite(), draw(), flower(), grain() (+9 more)

### Community 28 - "Year 1 — Foundation & Prototype"
Cohesion: 0.07
Nodes (27): ⚡ Accelerated Plan (2026-10-07) — supersedes the order of Phases 7(stages 4-5) and 9–18, Milestone A — "The first hour feels great", Milestone B — "A reason to come back tomorrow", Milestone C — "The wasteland outside the fence", Milestone D — "A living settlement", Milestone E — "Ship-ready", Phase 10 — Business System, Crafting & Advanced Economy, Phase 11 — Seasons, Weather & World Events (+19 more)

### Community 29 - "Canvas"
Cohesion: 0.10
Nodes (3): Canvas, line_points(), _over()

### Community 30 - "rgba"
Cohesion: 0.12
Nodes (11): build(), hp_icon(), rad_icon(), Arm, blood_pool(), Pose, mix(), _nbrs() (+3 more)

### Community 31 - "fences.py"
Cohesion: 0.16
Nodes (19): _beam(), build(), chainlink_frame(), _dark(), gate_chainlink(), gate_wood(), _log(), _mesh() (+11 more)

### Community 32 - "palette.py"
Cohesion: 0.09
Nodes (5): gear(), gear(), Arm, gear(), gear()

### Community 33 - "townsfolk/build.py"
Cohesion: 0.13
Nodes (15): build_buildings(), build_characters(), build_preview(), build_ui(), main(), verify_building(), write(), check_frame() (+7 more)

### Community 34 - "lib.py"
Cohesion: 0.10
Nodes (13): check_alpha(), edge_masks(), from_text(), hexs(), lum(), _nbrs(), outline_inner(), quantize() (+5 more)

### Community 35 - "engine/synth.py"
Cohesion: 0.12
Nodes (14): additive(), chain(), env_ar(), fade_edges(), lagrange_frac(), noise(), _norm_sos(), pan_gains() (+6 more)

### Community 36 - "tf_doll.py"
Cohesion: 0.14
Nodes (4): layer(), Look, Pose, stamp()

### Community 37 - "end_fade"
Cohesion: 0.12
Nodes (13): bubble(), chip(), end_fade(), env_ad(), env_adsr(), fade(), fmbell(), modes() (+5 more)

### Community 38 - "sys"
Cohesion: 0.14
Nodes (9): build_enemies(), main(), verify_sheet(), frame_slice(), main(), verify(), main(), write() (+1 more)

### Community 39 - "items/build.py"
Cohesion: 0.15
Nodes (11): check(), main(), placeholder(), registry(), res_to_path(), crop_sheet(), _font(), icon_sheet() (+3 more)

### Community 40 - "fx.py"
Cohesion: 0.19
Nodes (17): alert_mark(), blood_splat(), bolt(), build(), _burst(), _center(), hit_spark(), ichor_splat() (+9 more)

### Community 41 - "lv_common.py"
Cohesion: 0.14
Nodes (10): glow(), outline_solid(), part(), shadow(), tint(), under(), pack_goat(), race_frame() (+2 more)

### Community 42 - "rig.py"
Cohesion: 0.18
Nodes (11): A(), arms_e(), arms_n(), arms_s(), death_frames(), frames(), pistol(), poses() (+3 more)

### Community 43 - "_arr"
Cohesion: 0.13
Nodes (11): _arr(), chirp(), creaky_source(), fm(), formant_cascade(), glottal(), _klatt_tv(), phase() (+3 more)

### Community 44 - "math"
Cohesion: 0.22
Nodes (10): build_one(), band_report(), _cmap(), _font(), harmonic_lint(), seam_check(), _seam_metrics(), spectral_balance() (+2 more)

### Community 45 - "analyze.py"
Cohesion: 0.19
Nodes (13): amb_flags(), amb_metrics(), analyze(), _cmap(), contact_sheet(), draw_tile(), ffmpeg_lufs(), main() (+5 more)

### Community 46 - "master.py"
Cohesion: 0.19
Nodes (10): circular_eq(), decode(), encode_ogg(), ffmpeg_loudness(), _hop_energy(), _k_weight_sos(), limit(), master() (+2 more)

### Community 47 - "burst"
Cohesion: 0.15
Nodes (10): _auto(), burst(), chime(), church_bell(), colored(), kalimba(), marimba(), musicbox() (+2 more)

### Community 48 - "weather_icons.py"
Cohesion: 0.39
Nodes (12): build(), _canvas(), clear(), clear_night(), _cloud(), _disc(), _hex(), _outline() (+4 more)

### Community 49 - "sfx/build_all.py"
Cohesion: 0.24
Nodes (9): finalize_amb(), finalize_sfx(), _load_existing_stats(), main(), render(), _render(), _section(), seed_for() (+1 more)

### Community 50 - "terrain.py"
Cohesion: 0.33
Nodes (12): build(), _detail_clover(), _detail_pebble(), _detail_tips(), _detail_tuft(), _free(), grass_tiles(), _inside() (+4 more)

### Community 51 - "3. Brutal assessment — what a player would actually experience"
Cohesion: 0.14
Nodes (13): 1. Verification of the 2026-10-07 status report, 2. What is genuinely good (keep it), 3.1 It does not look like a game yet (presentation: **2/10**), 3.2 It is completely silent (audio: **0/10**), 3.3 Interaction feel (controls: **4/10**), 3.4 The farming loop is thin and punishing (core gameplay: **3/10**), 3.5 Nothing to work toward (progression/goals: **2/10**), 3.6 Half the game does not exist (expeditions/combat: **0/10**) (+5 more)

### Community 52 - "os"
Cohesion: 0.20
Nodes (6): build(), _hex(), build(), main(), build_character(), main()

### Community 53 - "shambler.py"
Cohesion: 0.23
Nodes (9): arms_e(), arms_limp_s(), arms_n(), arms_s(), arms_up_s(), death_frames(), frames(), poses() (+1 more)

### Community 54 - "decor.py"
Cohesion: 0.27
Nodes (9): build(), _flower(), flowers(), _grass(), _leafpair(), leaves_autumn(), snow_clump(), specks() (+1 more)

### Community 55 - "Wasteland Harvest"
Cohesion: 0.17
Nodes (11): Art Pipeline — PixelLab-first, Chess Engine, Core Systems (see `ROADMAP.md` for the full phase-by-phase breakdown), Engine & Technical Spec, graphify, Platform & Release, Repo Conventions, Shared Assets (`~/Projects/shared-assets`, sibling repo) (+3 more)

### Community 56 - "Social life, requests and Town Works — design + data contracts (Milestone B, 2026-10-08)"
Cohesion: 0.18
Nodes (11): 1. Who lives here, 2. Hearts (affinity) — `scripts/affinity.gd`, 3. Dialogue — `data/dialogue.json` (v2), 4. Gift preferences — `data/gifts.json`, 5. Notice-board requests — `data/requests.json`, 6. Town Works — `data/projects.json`, 7. Journal and forecast, Social life, requests and Town Works — design + data contracts (Milestone B, 2026-10-08) (+3 more)

### Community 57 - "Wasteland Harvest — Map Layout Sketches"
Cohesion: 0.17
Nodes (11): 1. The Three Starting Settlements, 2. The Town Core, 3. The Ranch/Sanctuary, 4. The Ruined City — Concept Sketch, Bunkers, Forest Edge — the salvager's start (lean: **ruin materials**), Open Plains — the farmer's start (lean: **better soil**), Raider faction territory (+3 more)

### Community 58 - "part"
Cohesion: 0.30
Nodes (8): part(), stamp(), build(), gift_icon(), heart_empty(), heart_full(), quest_marker(), talk_icon()

### Community 59 - "runner.py"
Cohesion: 0.32
Nodes (8): A(), arms_e(), arms_s(), death_frames(), frames(), poses(), _raise(), sheet()

### Community 60 - "Feature"
Cohesion: 0.17
Nodes (3): Concrete, Feature, Sand

### Community 61 - "music/build_all.py"
Cohesion: 0.33
Nodes (7): fmt_time(), main(), _print_result(), sync_import(), _worker(), write_manifest(), write_readme()

### Community 62 - "Character Art — PixelLab Provenance"
Cohesion: 0.18
Nodes (10): Character Art — PixelLab Provenance, Enemies (code-generated) — Milestone C, Files, Files, Files (per NPC, same layout as `player/`), `mayor_harlan/`, `marta/`, `scout_kael/` — Phase 6 "Art pass 1" NPCs, `player/` — Phase 2 player character, `rancher_silas/` — Phase 8 Ranch/Sanctuary keeper NPC (+2 more)

### Community 63 - "_ground"
Cohesion: 0.18
Nodes (3): Asphalt, Gravel, _ground()

### Community 64 - "Wasteland Harvest — Art Style Guide (code-generated pixel art)"
Cohesion: 0.22
Nodes (8): 1. Grid, scale, projection, 2. Light, shading, outlines, 3. Palette rules, 4. Anchors and file conventions, 5. Quality bar, 6. Ruined-city kit (`tools/art/ruins_city/`, Milestone C), 7. Enemies, combat FX, combat HUD (`tools/art/enemies/`, Milestone C), Wasteland Harvest — Art Style Guide (code-generated pixel art)

### Community 65 - "A living settlement — design + data contracts (Milestone D, 2026-11-10)"
Cohesion: 0.22
Nodes (8): 1. The market — `scripts/market.gd`, `scripts/market_rules.gd`, 2. The caravan — `scripts/caravan.gd`, `data/caravan.json`, 3. The trading post — `scripts/structures.gd`, 4. Festivals — `data/festivals.json`, `scripts/festivals.gd`, 5. The Signal — `data/story.json`, `scripts/story.gd`, 6. New dialogue flags, 7. Art list, A living settlement — design + data contracts (Milestone D, 2026-11-10)

### Community 66 - "ia_tools.py"
Cohesion: 0.33
Nodes (5): axe(), build(), hoe(), pickaxe(), scythe()

### Community 67 - "butter"
Cohesion: 0.22
Nodes (5): butter(), dc_block(), distance(), sat(), warm()

### Community 69 - "wang.py"
Cohesion: 0.32
Nodes (4): bits(), cov(), coverage(), distances()

### Community 70 - "make_ir"
Cohesion: 0.25
Nodes (4): circ_conv(), circ_reverb(), make_ir(), reverb()

### Community 71 - "creak"
Cohesion: 0.25
Nodes (4): creak(), periodic_env(), resonate(), smooth_noise()

### Community 72 - "Building Art — Phase 6 "Art pass 1" (buildings half) — PixelLab Provenance"
Cohesion: 0.29
Nodes (6): Building Art — Phase 6 "Art pass 1" (buildings half) — PixelLab Provenance, Generation parameters (all 10 objects) — SUPERSEDED, see "Revision note" below, Ranch/Sanctuary buildings (Phase 8) — 3 new kinds, Revision note (2026-07-10, same session as Phase 6's first buildings pass): too 3D/isometric, The 10 objects (all generated 2026-07-10, one accepted attempt each, no rejects), The sub-32px sizing resolution (5 kinds)

### Community 73 - "Tile Art — Phase 1 Test Set"
Cohesion: 0.29
Nodes (6): Metadata, Provenance, Revision note (Phase 3): settlement palette boosted, ruins left alone, `ruins/rubble_planks_tileset.png` + `.json`, `settlement/grass_soil_tileset.png` + `.json`, Tile Art — Phase 1 Test Set

### Community 76 - "UI Art — PixelLab Provenance (Phase 2 basic HUD)"
Cohesion: 0.33
Nodes (5): HUD redesign (2026-07-11 playtest feedback session), Pixel font (`fonts/`, added after Phase 4), Revision note (Phase 3): palette boosted, Stardew-fusion pass (2026-07-11, second HUD session), UI Art — PixelLab Provenance (Phase 2 basic HUD)

### Community 77 - "enemies/preview.py"
Cohesion: 0.53
Nodes (4): anim_gif(), build(), contact_sheet(), _player()

### Community 79 - "loudness"
Cohesion: 0.33
Nodes (4): kweight(), _kweight_coefs(), loudness(), momentary_max()

### Community 80 - "Stardew Valley — Structural Reference (Pelican Town & Marnie's Ranch)"
Cohesion: 0.40
Nodes (4): Marnie's Ranch — structural takeaways, Pelican Town — structural takeaways, Stardew Valley — Structural Reference (Pelican Town & Marnie's Ranch), What this unblocks

### Community 81 - "saw"
Cohesion: 0.40
Nodes (3): _blep(), saw(), square()

### Community 82 - "Crop Art — PixelLab Provenance (Phase 3)"
Cohesion: 0.50
Nodes (3): Crop Art — PixelLab Provenance (Phase 3), Known follow-up: these PNGs are not yet imported, Revision note (Phase 3): palette boosted, and the import gap above is now closed

### Community 83 - "Item Icon Art — PixelLab Provenance (Phase 3)"
Cohesion: 0.50
Nodes (3): Item Icon Art — PixelLab Provenance (Phase 3), Known follow-up: not yet imported, Revision note (Phase 3): palette boosted, and the import gap above is now closed

### Community 84 - "Prop Art — PixelLab Provenance"
Cohesion: 0.50
Nodes (3): Prop Art — PixelLab Provenance, `ranch_cow.png`, `ranch_goat.png` — Phase 8 Ranch/Sanctuary decorative livestock, `wrecked_car.png`, `weed_tuft.png` — Path zone dressing (zone split, Stage 1)

## Knowledge Gaps
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Canvas` connect `Canvas` to `lib.py`, `outline`, `mix`, `previews.py`, `Terrain`, `rgba`, `trees.py`, `terrain.py`, `hval`, `rc_common.py`, `rc_walls.py`, `decor.py`, `fences.py`?**
  _High betweenness centrality (0.059) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `Canvas` (e.g. with `load()` and `Scene`) actually correct?**
  _`Canvas` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Should `ns` be split into smaller, more focused modules?**
  _Cohesion score 0.055190823172931246 - nodes in this community are weakly interconnected._
- **Why does `Ramp` connect `Ramp` to `ia_tools.py`, `.render`, `ia_produce.py`, `ia_lib.py`, `ia_place.py`, `Social life, requests and Town Works — design + data contracts (Milestone B, 2026-10-08)`, `ia_crops.py`?**
  _High betweenness centrality (0.051) - this node is a cross-community bridge._
- **Are the 12 inferred relationships involving `Ramp` (e.g. with `crop_ramp()` and `ramp()`) actually correct?**
  _`Ramp` has 12 INFERRED edges - model-reasoned connections that need verification._
- **Should `Song` be split into smaller, more focused modules?**
  _Cohesion score 0.05193969479683765 - nodes in this community are weakly interconnected._
- **Why does `Canvas` connect `Canvas` to `part`, `tf_doll.py`, `fx.py`, `lv_common.py`, `rig.py`, `hound.py`, `bloater.py`, `rgba`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._