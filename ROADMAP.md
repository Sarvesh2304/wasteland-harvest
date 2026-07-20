# Roadmap — Phase Checklist (no calendar; milestone-gated)

Adapted from `Wasteland Harvest 3-Year Dev Roadmap.html`, with all month/calendar pacing removed.
Work phases in order — each depends on the last. Check off tasks as they land; a phase isn't done
until its milestone line is true. Keep this file updated in the same commit as the work. "Year 1/2/3"
headers below are kept only as the source material's organizational grouping (Foundation → Content
→ Story/Launch) — they are not time commitments.

Some phase milestones below are carried directly from the source HTML (marked as such implicitly
by their specificity); phases where the source didn't state an explicit milestone have one
synthesized here from that phase's own goal — treat those the same as any other milestone gate.

## Year 1 — Foundation & Prototype

Goal: a playable vertical slice — one map, one farming loop, one NPC, auto-save working.

### Phase 1 — Setup, Design & World Building
- [x] Game Design Document (GDD) — core loop, world lore (what caused the apocalypse?), player
      goals, win/lose conditions, tone and art direction. See `GDD.md` (authoritative going
      forward); two scope additions beyond this file's original checklist text are folded in
      below (raider faction reputation in Phase 9/10, other settlements in Phase 14) per
      `GDD.md` §11.
- [x] Map layout sketches — 3 starting settlement types (forest edge, riverside, open plains),
      town layout (mayor's house, store, water body), ruined city concept. See `MAPS.md` —
      also records a structural decision that the three starts share one town-core template
      (re-dressed by surrounding terrain) rather than three fully distinct towns, for Phase 4
      to build from without re-litigating.
- [x] Godot 4 project set up — engine installed (`~/Downloads/Godot.app`, 4.7), project
      structure created (`art/`, `audio/`, `data/`, `scenes/`, `scripts/`, `tests/`,
      `tilemaps/`, `tools/`, mirroring blood-fields-empires's conventions minus its
      isometric-specific `IsoGrid` autoload), Git + GitHub already in place. Headless test
      runner (`tests/run_tests.gd`) verified working: `godot --headless --path . --script
      res://tests/run_tests.gd` → `Ran 1 tests, 1 passed, 0 failed.`
- [x] **Pixel art style decided** — tile size is **16×16px**, matching Stardew Valley's actual
      base tile size (chosen to keep the ~120-item art pipeline tractable); `project.godot`'s
      viewport (320×192, exactly 20×12 tiles) and Nearest-neighbor texture filtering are set
      accordingly. Colour palette locked to concrete hex values with seasonal modulation — see
      `GDD.md` §9. First test tiles generated (see next item).
- [x] ~~Aseprite installed~~, basic tiles drawn: soil, grass, ruin rubble, wood planks —
      **Aseprite explicitly skipped for now** (Sarvesh's call: rely on the PixelLab-first
      pipeline already described in `CLAUDE.md`; install Aseprite later only if PixelLab output
      needs manual touch-up). The same four tile types were instead generated via PixelLab's
      `create_topdown_tileset` at the locked 16×16 size and settlement palette — see
      `art/tiles/README.md` for the two Wang tilesets (`settlement/grass_soil_tileset.png`,
      `ruins/rubble_planks_tileset.png`) and their provenance.

**Milestone: Phase 1 complete.** GDD exists (`GDD.md`), map sketches exist (`MAPS.md`), tile
size and palette are decided and recorded, Godot project + first test tiles exist, repo is on
GitHub.

### Phase 2 — Core Engine: Player, World & Day/Night Cycle
- [x] Player character — 4-directional movement, walking animation (idle, walk, tool-use),
      Godot's `CharacterBody2D`. PixelLab-generated sprite (`art/characters/player/`, one
      representative appearance — the full preset+slider character-creation system is later
      birth-sequence UI work, not a Phase 2 blocker). `scripts/player.gd`.
- [x] Tile-based world — `TileMapLayer` (Godot 4.3+'s supported replacement for the deprecated
      `TileMap` node), small test map (farmland + surrounding grass/rubble/plank terrain) built
      from the two Phase 1 tilesets, collision layers (`world` vs `player`, rubble solid,
      grass/soil/planks walkable). `scripts/test_map.gd`, `tilemaps/wasteland_tileset.tres`.
- [x] Camera system — smooth follow camera (exponential smoothing) clamped to map boundaries,
      `shake(intensity, duration)` hook ready for Phase 9 combat to call. `scripts/game_camera.gd`.
- [x] Day/Night cycle — global `DayManager` autoload, 1 in-game minute per real second, day
      counter rolls at midnight, sky colour shifts dawn → noon → dusk → night via
      `CanvasModulate`. `scripts/day_manager.gd`, `scripts/day_night_modulate.gd`.
- [x] Basic HUD — day number + clock + energy bar over a PixelLab scavenged-metal/cracked-glass
      plaque (`art/ui/`). `scripts/hud.gd`.

**Milestone: Phase 2 complete.** Verified independently (re-run, not just taken on the building
agent's word): 32/32 headless unit tests pass, plus a scripted runtime smoke test
(`tools/runtime_smoke.gd`) that boots the real `main.tscn` and drives simulated input — player
spawns correctly, walks in all 4 directions with correct animation, is physically blocked by
rubble/map-border collision, camera follows and clamps at the true map edge, tool-use locks
movement and spends energy, and the sky color shifts across a full simulated day. Code review of
`player.gd`/`day_manager.gd`/`game_camera.gd`/`main.gd` confirms sound logic (pure static
functions for testability, sensible collision layering, frame-rate-independent camera math).
Generated art (player sprite, HUD plaque/energy frame) spot-checked visually and matches the
locked palette and cozy-scavenger art direction. **Not yet verified: live rendered gameplay** —
this repo's team-model gate on driving the Godot GUI/runtime blocked an automated screenshot
check this session; a quick look in-editor is worth doing when convenient, though nothing in the
headless verification suggests a problem.

### Phase 3 — Farming Core & Inventory System
- [x] Till soil with a hoe (normal ground tile → farmable tile). Tilling targets one logical
      grid cell; the existing dual-grid Wang ground painter automatically re-blends the visual
      tiles touching it — reasoning in `scripts/farm_grid.gd`'s header (resolves the open
      question flagged at the end of Phase 2).
- [x] Plant seeds (place seed item on tilled tile). `scripts/farm.gd`.
- [x] Water crops daily or they die; visual indicator if watered (cool-blue sprite tint).
      Judgment call, documented in `farm_grid.gd`: missing a single day's watering kills an
      unwatered, not-yet-mature crop outright (no grace period) — stricter than Stardew, taken
      literally from the checklist wording. Mature crops need no further water.
- [x] Growth stages — 4–6 visual stages per crop (Dustwheat 4, Mutant Potato/Ironroot 5,
      Sunbloom 6), auto-progress each morning via `DayManager.day_started`. Real PixelLab art
      for all 4 crops' full growth chains (`art/crops/`, see its README for provenance).
- [x] Harvest — interact with mature crop to collect produce; harvesting isn't tool-gated
      (Stardew convention), plot returns to bare tilled soil after.
- [x] Inventory grid — slot-based (27 slots, 3×9) with stacking, hotbar (row 1, number-key
      select) for quick access. `scripts/inventory.gd`, HUD grid/hotbar in `scenes/hud.tscn`.
- [x] Tool system — Hoe, Watering Can, Axe, Pickaxe, Bag, each with durability that decrements
      on use (a broken tool is inert until a later phase adds repair). `scripts/player.gd`'s
      `_interact()` dispatch.
- [x] Energy system — real per-action costs (till 4, water 2, plant 1, harvest 1, chop/mine 5,
      replacing Phase 2's flat placeholder); passing out at zero energy triggers
      `DayManager.skip_to_next_morning()` + full refill (a "black out, wake at 6 AM" stand-in
      until a real bed/sleep interaction exists in Phase 4).
      **Enhanced 2026-07-11 (post-Phase 6, direct playtest feedback from Sarvesh — new scope,
      not an original checklist item; design record in `GDD.md` §4 "The night rules"):**
      Stardew-style forced sleep. (1) From midnight, a passive sleepy drain (0.15 energy/game-
      minute — 18 over the midnight-to-2-AM window) plus a pulsing HUD "GETTING SLEEPY..." cue
      (`player.gd` night rules riding a new `DayManager.time_advanced` lived-time-only signal;
      `hud.gd`/`hud.tscn` `%SleepyLabel`). (2) At 2 AM a *second, energy-independent* pass-out
      trigger fires regardless of the bar. (3) Rare stay-awake consumable: Scav-Brew Coffee
      (`items.json` `"coffee"`, 75 Cr, `stay_awake: true`) suppresses exactly one night's
      cutoff; deliberately NOT in Marta's stock and with **no acquisition path yet** (the
      `bottle_caps`/`cloth_scrap` exists-ahead-of-its-system precedent — source it from a later
      caravan/rare-vendor phase). (4) Pass-outs now auto-save like the bed (superseding Phase 4
      Stage 3's deliberate bed-only-save choice, per the explicit new spec "saved when the
      player falls asleep OR passes out"). Landed alongside: general food-eating (hotbar-select
      + `use_tool` consumes any `food` item for its until-now-dead `energy_restored` — the
      plumbing coffee needed anyway, item count now 21), and a latent-bug fix in
      `skip_to_next_morning()` — an *after-midnight* night ending no longer skips a calendar
      day or double-fires `day_started` (crops/construction/sales ticked twice per night;
      unreachable before, guaranteed-hot once 2 AM endings became the norm). Verified:
      209/209 unit tests, `tools/sleep_smoke.gd` (new: onset drain+cue, energy-independent 2 AM
      cutoff+save, coffee night incl. next-night collapse, zero-energy save, 2-AM-can't-arrive-
      mid-dialogue), soak stage 5 reworked into a real stay-up-all-nighter, screenshots of the
      cue + forced pass-out.
- [x] First 20 items defined (`data/items.json`): 4 seeds, 4 crop-produce, 5 resources (incl.
      bottle caps, cloth scrap), 2 food, 5 tools. `data/crops.json` for the 4 crops' growth/
      yield data. Real PixelLab icons for 7 items (4 crop produce + wood/stone/scrap); the
      remaining 13 use in-engine flat-color placeholders, deferred to Phase 6 art polish.

**Milestone: Phase 3 complete.** Verified independently: re-ran the full test suite after this
session's own headless `--import` pass for the new crop/item art (66/66 unit tests pass, both
before and after import), read through the core new scripts (`farm_grid.gd`, `farm.gd`,
`player.gd`, `inventory.gd` — clean pure/stateful separation matching Phase 2's established
style, sound logic, well-reasoned judgment calls documented inline), and spot-checked generated
crop/item art visually. Full farming loop confirmed via an extended headless runtime smoke test
(`tools/runtime_smoke.gd`): till → plant (consumes seed) → water (tint + durability) → forced
day advances to maturity → harvest → item lands in inventory → plot stays tilled and
replantable; a separate pass-out check (energy forced to 0 → day skips → energy refills) also
passes. Game launched live for Sarvesh to check visually (still no automated screenshot
capability — see Phase 2's milestone note on the Screen Recording permission gap).

### Phase 4 — Settlement Maps, Building & Auto-Save

Built in 3 committed stages (Sarvesh's preference, so a session interruption never loses more
than one stage's work) rather than one batch — see individual commits for exactly what landed
when.

- [x] Settlement selection screen — choose from 3 starting maps at game start, each with
      different layout/terrain/lore blurb and differing starting resources (water access vs.
      ruin materials vs. better soil). **Stage 1.** New `scenes/settlement_select.tscn` (now
      `run/main_scene`) shows each start's name/lore/resource-lean from `MAPS.md` §1; confirming
      sets the new `GameState` autoload's `chosen_settlement_id` and transitions to
      `scenes/main.tscn`.
- [x] Full farmland map — player's home area: farm plots, derelict home structure, storage
      chest, a small perimeter fence gap (closed later). **Stage 1.** All 3 starts
      (`scripts/map_layouts/{open_plains,forest_edge,riverside}_layout.gd`, 36×32 cells each)
      have a real farmhouse + chest (a genuine second `Inventory` instance, opened via the
      existing tool-use interaction) and match their `MAPS.md` terrain sketches (Open Plains'
      one large plot; Forest Edge's irregular patches + treeline/rubble; Riverside's narrow
      bank-side ribbon with the river replacing the west fence).
- [x] Town map rough draft — mayor's fortified house, one trading store, 3–4 settler shacks,
      water body (river or lake) with dock, bulletin board. **Stage 1.** One shared town-core
      layout per `MAPS.md` §2 (plaza, mayor's house north / store south, 4 shacks, water+dock,
      one main gate), reproduced identically across all 3 starts' layout files. All buildings
      are real collidable placeholder volumes (`scripts/structures.gd`) — flat-color per kind
      from the locked palette, no interiors/NPCs yet (Phase 5).
- [x] Basic building placement — place a structure blueprint, spend resources, wait 1 in-game
      day; simple grid-snap system. **Stage 2.** New keyboard-only build mode (`scripts/
      builder.gd`, `B` to toggle, `Q` to cycle, reusing `use_tool`/Space to confirm) lets the
      player place either of 2 buildable structures (`data/buildings.json` via `scripts/
      building_db.gd`) on a grid-snapped footprint anchored away from the player
      (`scripts/build_grid.gd`). Confirming spends resources and energy and spawns a translucent
      "under construction" placeholder (`scripts/structures.gd`, generalized from Stage 1's
      layout-only spawner); completion rides `DayManager.day_started` — the same signal crop
      growth uses — and recolors it to its finished kind, registering a working second storage
      chest if it's a Storage Shed. Deliberately just 2 structures (Shelter Tent, Storage Shed) —
      the full 12+ building library with real gameplay functions is Phase 8's job, not this
      stage's.
- [x] Auto-save at end of day — interacting with a bed saves all state (crops, inventory, day,
      world modifications), brief "WORLD SAVED" notification, `FileAccess` + JSON serialisation.
      **Stage 3.** Closes a real Phase 2/3 gap along the way: a farmhouse bed (`scripts/
      structures.gd`'s `is_bed_at()`) now exists at all, mirroring the chest's one-marked-cell
      pattern in each of the 3 layouts. Sleeping ends the day via the same `DayManager.
      skip_to_next_morning()` path pass-out already used (crop growth/construction completion
      fire identically either way), restores full energy, then auto-saves — deliberately in that
      order, so the save captures the fresh morning. Pure encode/decode of the JSON-unfriendly
      shapes (`Vector2i` keys/fields, JSON's float round-trip on int fields) lives in
      `scripts/save_data.gd`; the stateful gather/write/read/apply glue lives in the `GameState`
      autoload, since the resume-vs-new-game decision has to happen *before* `main.tscn` exists.
      `settlement_select.tscn` now skips straight to loading a save if one exists, falling
      through to the picker only for a missing/corrupt/unrecognized one — closing the resume gap
      Stage 1's own doc comment had explicitly flagged as deferred.
- [x] **Farm/Path/Town/Ranch zone-transition system, Stage 1 of 3 (added per Sarvesh's explicit
      request 2026-07-13 — see the zone-transition plan)** — the Ranch/Sanctuary session's
      continuous-single-map shortcut (Phase 8 bullet above) is replaced by 4 independent,
      always-instantiated zones (siblings under `Main`, not true scene load/unload) connected by
      gate-cell warps wrapped in a ~0.15s fade (`scripts/zone_fade.gd`). A new **Path** zone sits
      between Farm and Town — a Stardew-Bus-Stop-style corridor (conceptual reference only, see
      `docs/STARDEW_REFERENCE.md`), always open, with a wrecked-car landmark and a separate
      **locked, non-functional checkpoint gate** (structure only, unlock system deferred, same
      "structure now, system later" precedent as the Ranch's buy-animal shop). Farm/Town
      re-oriented literal east-west (Stardew-style), gate-breaks in their already-existing walls
      rather than new construction. Town and Ranch each needed a new prepended perimeter wall
      row (a real deviation the plan flagged for re-verification and which did NOT hold as
      simplified — the combined map had no wall between old farm/town rows, so this was a
      genuine finding, not an oversight). Saves reshaped to `SAVE_VERSION 2` (a `zones` dict
      keyed per zone); old v1 saves invalidated, not migrated.
- [x] **Zone-transition system, Stage 2 of 3 — save-system hardening.** `parse_save()`'s existing
      version check already invalidated v1 saves correctly with no new migrator needed; confirmed
      with a dedicated rejection test rather than just asserted. No stale local save files existed
      on disk to clean up (verified directly, not assumed). Swept the remaining direct
      `GameState.save_game(...)`/single-`TestMap` call sites in `soak_test.gd`, `runtime_smoke.gd`,
      `title_smoke.gd`, and 9 `screenshot_*.gd` tools onto the zone-aware `main.zones` signature —
      a real bug caught along the way: `title_smoke.gd`'s seeded save slots hardcoded
      `"version": 1`, which v2 now (correctly) refuses to even list, fixed to write
      `SaveData.SAVE_VERSION`. `soak_test.gd`/`runtime_smoke.gd` needed real re-anchoring (new
      `_warp_to(zone_id)`/`_npc_by_id(id, zone_id)` helpers riding `main._bind_zone()`, coordinates
      moved onto each zone's own clear ground) rather than a pure mechanical sweep — a purely
      literal signature swap left them crash-looping on null town NPCs, so scope necessarily
      pulled forward part of Stage 3's re-anchoring work while leaving *what's asserted*
      unchanged.
- [x] **Zone-transition system, Stage 3 of 3 — full test-suite migration.** `tests/test_map_layouts.gd`
      gained the full `zone_exits()` well-formedness gate: every target zone name resolves through
      the real `SettlementDB.layout_for_zone` dispatcher (with teeth — its unknown-id fallback
      silently returns the farm layout, so a typo'd target now fails loudly instead of misrouting
      at runtime), and the full cross-zone graph is bidirectionally consistent (every A→B exit
      requires a matching reverse B→A exit whose gate cells sit orthogonally beside A→B's entry
      cell — both sides must describe the same doorway). Checked across all 3 playable pairings
      (standard, forest_edge, riverside), not just the 2 variant archetypes. `runtime_smoke.gd`
      and `soak_test.gd` each now drive their first town round trip through the REAL gate-cell
      walk (player.gd's own detection → `zone_exit_requested` → `main`'s fade → `_bind_zone`) for
      both the Farm↔Path and Path↔Town seams, asserting the signal fires exactly once per hop —
      the remaining town visits stay direct `_bind_zone` shortcuts by design, since
      `zone_transition_smoke.gd` already exhaustively covers all 6 crossings. `sleep_smoke.gd` and
      `held_input_smoke.gd` were still fetching the deleted single `TestMap` node — genuinely
      broken (a silent per-frame crash-loop, not just untested), fixed onto `main.zones` plus a
      ported watchdog so a future regression like this fails loudly instead of hanging. A real,
      independently-reproduced test flake was also fixed along the way: stage 60's NPC-wander
      check compared only start/end cells, which intermittently failed when short idle timers let
      an NPC round-trip back to its home cell within the observation window — now accumulates
      "moved at any point," not just the endpoints.

**Zone-transition Stage 1 verified independently:** re-ran the full suite myself (252/252 tests)
and the new `tools/zone_transition_smoke.gd` (86 checks — all 6 gate crossings, camera-bounds
and ref-rebinding per crossing, a town save→reload round trip, and specifically the held-
movement-key regression case for the `_zone_transitioning` guard: exactly one
`zone_exit_requested` fired, `zone_fade` never re-entered mid-tween). Read through the core
diffs (`player.gd`'s guard, `main.gd`'s `_bind_zone`/`_bind_zone_refs`/fade sequencing,
`test_map.gd`'s `world_to_cell`/`get_global_cell_center`/`get_global_map_rect` frame fixes,
`zone_fade.gd`, the save reshape) and cross-checked the real `ROWS`/`zone_exits()` gate and
entry-cell coordinates by hand across all four zones (Farm↔Path↔Town↔Ranch) — internally
consistent both directions at every seam. Reviewed the zone-arrival screenshots
(`tools/screenshot_zones.gd`) — Path's car/weeds/checkpoint render correctly; confirmed the
plan's flagged "no row-shift" simplification genuinely did not hold and the +1 wall-row-prepend
fix that replaced it is correct. Known non-blocking rough edges (documented in the layout
files): the ruined road reads as reddish planks (only existing decor tile at 16px; a dedicated
tile is future polish), Riverside's west river gate has a cosmetic gap.

**Zone-transition Stage 2 verified independently:** re-ran the full suite myself (253/253 tests,
+1 new — the `version:1`-rejection test) and each of `zone_transition_smoke.gd` (86 checks),
`soak_test.gd`, `runtime_smoke.gd`, and `title_smoke.gd` individually (never batched) — all green,
matching Fable's own report exactly. Read the full diffs on `test_save_data.gd` (the round-trip
test now exercises real per-zone JSON through the actual encoders, typed-decode checks included,
not just presence checks) and `title_smoke.gd` (confirmed the seeded-slot `version:1` bug and its
fix are real). Independently confirmed on disk (`~/Library/Application Support/Godot/app_userdata/
Wasteland Harvest/saves/`) that no stale save files existed, rather than trusting the "nothing to
delete" claim. Confirmed `data/buildings.json`/`data/items.json`'s diffs are pure whitespace noise
via `git diff -w` before excluding them from this commit.

**Zone-transition Stage 3 verified independently:** re-ran the full suite myself (255/255 tests,
+2 new since Stage 2) and each of `runtime_smoke.gd`, `soak_test.gd`, `sleep_smoke.gd`,
`held_input_smoke.gd`, `zone_transition_smoke.gd` (86 checks), and `title_smoke.gd` individually
(never batched) — all green, matching Fable's own report exactly. Read the full diffs on all 5
changed files: confirmed `test_map_layouts.gd`'s new graph-consistency test's adjacency check
(orthogonal distance == 1 between an entry cell and the target's reverse gate cells) is sound, and
that `main.zone_fade`/`player.test_map`/`current_zone_id` — the fields the new gate-walk stages in
`runtime_smoke.gd`/`soak_test.gd` assert against — are real, existing fields (grepped
`main.gd`/`player.gd`/`zone_fade.gd` directly rather than assuming). Confirmed the reported
`sleep_smoke.gd` hang was real and the fix (watchdog + `main.zones` refs) is sound. Save hygiene
and `data/*.json` whitespace-noise re-confirmed clean.

**Stage 1 verified independently:** re-ran the full suite myself (87/87 unit tests), read
through the new core scripts (`game_state.gd`, `settlement_db.gd`, `structures.gd`,
`test_map.gd`'s generalized layout resolution, one full map layout file) — sound logic, the
`_enter_tree()`-before-children's-`_ready()` ordering trick for resolving the active layout is
correct and clearly documented, judgment calls (Riverside's indirect starting bonus since no
fishing/irrigation systems exist yet; chest UI has toggle/display but no item-transfer UX yet)
are reasonable and flagged. Runtime smoke test extended to cover selection → confirming a
*non-default* choice → correct layout loading → all building landmarks present and collidable →
chest interaction → the full farming loop and pass-out re-verified against the new maps; Open
Plains and Riverside independently boot-checked too, not just the one driven end-to-end. Live
game launch clean (no errors).

**Stage 2 verified independently:** re-ran the full suite myself (114/114 unit tests, +27 new
covering footprint anchoring/enumeration, map-bounds checks, affordability, and construction-day
completion) and the extended runtime smoke test (toggle/cycle/confirm, exact resource+energy
ledgers, invalid-site refusals, day-advance completion, collision walk into the finished shed,
shed-storage UI, and a from-zero gather→afford→build pass) — all passed. Read through the new
core scripts (`build_grid.gd`'s pure anchoring/affordability/completion math, `builder.gd`'s
input handling, `structures.gd`'s generalized footprint-body spawner and runtime building
registry, `test_map.gd`'s `_runtime_blocked` overlay mirroring the existing `_tilled` pattern) —
sound logic, consistent with this codebase's established conventions throughout. Visually
confirmed via screenshots: the placement-preview UI (cost/key-hint label, green/red valid-site
tint), the placed translucent blueprint, and the completed Storage Shed recolored the morning
after placement.

**Stage 3 verified independently:** re-ran the full suite myself (127/127 unit tests, +13 new
covering save/load round-tripping through actual JSON text and the new bed's presence/shape/
reachability) and the extended runtime smoke test, including its most important check for this
stage: after a real playthrough (till/plant/water/harvest, chop a tree, place and complete two
buildings, seed storage), sleeping through the actual `use_tool()`-facing-the-bed path, then
tearing down `main.tscn`, deliberately corrupting in-memory state, and re-instantiating
`settlement_select.tscn` as a genuine fresh launch — confirmed it skipped straight past the
picker and restored settlement choice, day/clock, exact player position/facing/energy/inventory,
tilled cells, crop growth stage, which resource nodes stayed gone, both buildings with their
storage contents, and the bed itself. Save-file hygiene confirmed clean (test-only filename,
deleted before and after; independently checked `user://`'s save directory has nothing left
behind). Read through the new core scripts (`save_data.gd`'s pure encode/decode, `game_state.gd`'s
save/load/resume glue, each node's `save_state()`/`load_state()`) — sound logic, correctly reuses
existing patterns throughout (block_cells re-derivation instead of serializing derived state,
`skip_to_next_morning`'s shared signal path, the established one-marked-cell building convention
for the bed). Visually confirmed via screenshots: the bed beside the farmhouse and the "WORLD
SAVED" notice appearing across a day transition.

**Milestone (whole phase) — met.** Auto-save works end-to-end; a player can quit (or have the
game close) mid-playthrough and reload with crops, inventory, day/time, tilled ground,
player-built structures and their storage, and player position all correctly restored, skipping
straight past the settlement picker on a resumed game.

### Phase 5 — Basic NPCs, Town Economy & Dialogue

Built in 3 stages, same reasoning as Phase 4 (a session interruption never loses more than one
stage's work).

- [x] NPC base class — name, sprite, position, dialogue data, wanders within a defined zone
      (`NavigationAgent2D`). **Stage 1.** Implemented as a grid random-walk (`scripts/npc_grid.gd`
      pure math + `scripts/npc.gd` stateful shell) rather than real `NavigationAgent2D` — this
      codebase has no navigation infrastructure anywhere, and re-baking a navmesh every time a
      Phase 4 player-built structure appears is a lot of machinery for "amble near home." An NPC
      idles, then steps one validated cell within a small Chebyshev-radius zone around its home
      cell, respecting terrain/buildings/player-built structures for free via the existing
      `is_blocked_at()`. Flat-color placeholder sprites (real PixelLab art is Phase 6's "Art pass
      1" checklist item).
- [x] Dialogue system — interact near an NPC to open a dialogue box, character-by-character text,
      basic branching, dialogue stored in JSON for easy editing. **Stage 1.** `data/dialogue.json`
      + `scripts/dialogue_db.gd` (same static-module convention as `item_db.gd`), traversal logic
      pure and unit-tested. `scripts/dialogue_ui.gd` is the presentation shell: typewriter reveal,
      instant-skip on repeat press, one branch point per NPC (2 options -> distinct follow-up
      lines). Keyboard-only, no new input actions (`use_tool` advances/closes, `move_up`/
      `move_down` cycle choices, reusing `settlement_select.gd`'s cycle-then-confirm shape).
- [x] First NPCs: Mayor Harlan (quest-giver), Marta (store owner), Scout Kael (tells you about
      the ruined city). **Stage 1.** Shared verbatim across all 3 starting layouts (`layout_common
      .gd`'s `TOWN_NPCS`, matching the town-core-is-one-template structural decision `MAPS.md` §2
      already established for buildings). Harlan stands by his house, Marta by her store, Kael
      just inside the town's main gate (MAPS.md §2 already places expedition departures there —
      the scout who watches the road east naturally posts up at the door to it). "Quest-giver" is
      flavor/dialogue only this stage — no quest system exists yet (Phase 13).
- [ ] **Day-28 food-shortage beat (added per `GDD.md` §§2–4/§11)** — one in-game month after Day
      1, Harlan delivers a scripted dialogue beat: food reserves are running low and the
      settlement is counting on the farm again, re-establishing its founding-era civic role
      (`GDD.md` §2). Dialogue content only, same "flavor/dialogue only" scope Harlan already has
      in this phase — no quest system needed. Starts the standing town-wellbeing signal described
      in `GDD.md` §4 (soft, never a fail state) and sets up the hired-labor payoff below.
- [x] Town store — Marta sells seeds/basic tools/food; UI shows name/description/price; currency
      is Credits (per `GDD.md` §7; not "Scrap Coins" as earlier drafted — Credits is settled
      humanity's established currency, with barter as a parallel economy for raiders/remote
      traders who don't accept it). **Stage 2.** Marta stocks all 4 seeds, both food items, and
      the 4 tools that actually wear out (hoe/watering can/axe/pickaxe — framed as replacements
      for a broken one, since no repair system exists yet; the unbreakable Scavenger's Bag isn't
      stocked). Reached via a new choice in Marta's dialogue ("Let's see what you've got") rather
      than a separate interaction, resolving her Stage-1 dialogue's stale "store's not open yet"
      line now that it actually is. Buy-only, per the roadmap's own split from Stage 3's
      shipping-box selling. Credits balance lives on `player.gd` (mirroring `energy`'s pattern
      exactly — a plain field, save/load support, a HUD display), starting at 0 since nothing
      grants Credits until Stage 3 exists.
- [x] Shipping box — place harvested crops before sleeping; Credits added next morning; tracks
      sale history. **Stage 3.** A new shipping-box building (marker `'S'`) completes the
      farmhouse's service row (chest / box / bed) in all 3 starts. Loading is one-way and
      one-crop-per-confirm (`scripts/shipping_ui.gd`, structurally the store's buy flow flipped
      to load) — crops only, per the checklist wording, gated by `scripts/shipping_db.gd`'s
      `is_shippable()`. The overnight sale rides `DayManager.day_started` (the same signal crop
      growth and construction completion already use), resolving strictly before
      `_sleep_in_bed()`'s trailing save so a sale is never lost on reload. Sale history is kept
      in full ({day, itemized items, total} per entry) — tracked per the checklist, no viewing UI
      yet (that would be scope creep into a later phase).

**Stage 1 verified independently:** re-ran the full suite myself (148/148 unit tests, +21 new
covering wander-zone math, dialogue-tree traversal, and per-layout NPC placement/reachability) and
the extended runtime smoke test (approaches and opens dialogue with all 3 NPCs via the real
facing+`use_tool` path, confirms zero energy cost and a full player freeze while a conversation is
open, drives both branches of a choice through the real input handler, confirms the player can
walk normally after every close, and confirms all 3 NPCs wander at least once within ~10s of
simulated time without leaving their zone or clipping through terrain) — all passed, twice in a
row. Read through the new core scripts — sound logic, consistent with established conventions
(pure/stateful split, signal-based handoff rather than direct calls, data-driven per-layout
spawning mirroring `structures.gd`'s `buildings()`). One real bug found and fixed during the
build (an unbounded wait loop in the smoke test's Kael stage, now safety-bounded) and one caught in
my own review of the verification screenshots: the dialogue box's hint label used a "full rect"
anchor stretch instead of a bottom-anchored strip, rendering "Space to continue"/"Up/Down to
choose..." above the box instead of inside it — fixed directly (a one-line anchor correction in
`dialogue_ui.tscn`, matching `settlement_select.tscn`'s already-correct `HintLabel` pattern),
re-verified visually and via a full test+smoke re-run afterward.

**Stage 2 verified independently:** re-ran the full suite myself (160/160 unit tests, +12 new
covering catalog pricing/affordability/purchase-deduction math) and the extended runtime smoke
test (opens the store via the real dialogue-choice path, buys a seed with exact Credits deducted
and the item landed in inventory, buys a tool and confirms a fresh full-durability instance
rather than a stack, forces and confirms an insufficient-funds refusal with zero deduction,
leaves via the Leave row, and confirms the player can move/interact normally afterward) — all
passed, twice in a row. Read through the new core scripts (`shop_db.gd`'s pure pricing/
affordability math, `store_ui.gd`'s presentation shell, the `OPEN_STORE` sentinel handoff kept
out of the domain-agnostic `dialogue_db.gd`) — sound logic, consistent with established
conventions throughout, including correctly applying the bottom-anchored `HintLabel` fix from
Stage 1's review rather than repeating that mistake. Verified no `.json`/`project.godot`
reformatting noise. Visually confirmed via screenshots: the store's full catalog with prices and
a selected item's description, and the new HUD Credits plaque alongside the existing day/clock
plaque.

**Stage 3 verified independently:** re-ran the full suite myself (177/177 unit tests, +17 new
covering shippable-roster/valuation/contents/sale-total/history math and the box's placement/
reachability in all 3 layouts) and the extended runtime smoke test — critically, the **entire
closed economy loop in one continuous run**: a tilled/planted/watered/harvested potato loaded into
the box via the real facing+`use_tool` path and the loading UI's real input handling, sleeping
through the bed to resolve the sale (exact Credits credited, itemized history recorded, box
emptied), a full save/teardown/reload confirming all of that survives a restart, and finally
walking to Marta and successfully spending those exact freshly-earned Credits at her store — farm
→ sell → earn → buy, verified as one chain, not just this stage's mechanism in isolation. Also
verified: a mid-session save with a loaded-but-not-yet-slept box survives a reload un-sold (no
phantom history entry) and still sells correctly the following sleep. All passed twice in a row.
Read through the new core scripts (`shipping_db.gd`'s pure math, `structures.gd`'s save-ordering
guarantee relative to `_sleep_in_bed()`'s trailing save, `shipping_ui.gd`'s one-way one-per-
confirm loading) — sound logic, consistent with every established convention, including reusing
the corrected bottom-anchored `HintLabel` pattern without reintroducing Stage 1's bug. Verified no
reformatting noise and clean save-file hygiene. Visually confirmed via screenshots: the loading
UI with per-crop held/in-box counts and running total, and the morning after — Credits landed,
"WORLD SAVED," and the farmhouse's three-color service row (chest/box/bed) all visible together.

**Milestone (whole phase) — met.** Player can farm, sell crops, earn currency, and buy seeds. The
economy loop is closed and verified end to end: harvest → ship overnight → Credits arrive → spend
them at Marta's store.

### Phase 6 — First Playable Build & Stabilisation
- [x] All Year 1 systems integrated — farming, inventory, economy, NPCs, day/night, auto-save
      work together without conflicts. Found and fixed a real cross-system input conflict: none
      of the four modal UIs (build mode, dialogue, store, shipping box) marked input as handled,
      so pressing "B" mid-conversation could turn build mode on *underneath* an open dialogue,
      after which a single keypress would double-drive both. New `scripts/modal_gate.gd` — a
      shared per-scene mutual-exclusion registry, three lines to wire in per surface — closes it;
      documented as reusable for future modal UIs (quest journal, pause menu, etc.).
- [x] Bug-fixing sprint — play through 5 in-game days end to end; fix crashes, edge cases,
      broken tile interactions. New `tools/soak_test.gd`: a continuous 6-day playthrough (not
      per-feature isolation like `runtime_smoke.gd`) with genuinely concurrent systems — 3 crop
      plots growing, 2 buildings under construction, 2 NPC conversations, a store purchase, 2
      shipping sales, and a mid-session save/reload — confirming multiple `day_started`
      subscribers (crop growth, construction completion, shipping sale) resolve correctly
      together with no double-crediting or corrupted state.
- [ ] Internal playtesting — 3–5 people play it; note confusion/breakage/fun; prioritise fixes
      for the next phase. **Blocked on real humans, not an agent task** — this needs Sarvesh (and
      4 others) actually playing the exported build above and giving feedback; flagged rather
      than silently skipped or faked. Nothing else in this phase depends on it landing first.
- [x] Art pass 1 — replace placeholder tiles with proper pixel art: ground tiles, farmland,
      player character, 3 NPCs, basic buildings. Ground tiles/farmland already had real PixelLab
      art from Phase 1 (untouched, no known issues). **NPCs and the player character: done.**
      Mayor Harlan, Marta, and Scout Kael each got a real PixelLab character (`create_character`
      + `animate_character`, the exact player-character pipeline: 16px/24x24 canvas, 4
      directions, low top-down, idle + walk only — no tool animation, since NPCs never use
      tools) via `scripts/npc.gd`'s new `AnimatedSprite2D`/`NPC_FRAMES` wiring (facing tracked the
      same way `player.gd` derives it, animation names `<action>_<facing>`); each NPC's
      placeholder identity color was kept as its dominant costume tone but reassigned for mutual
      contrast (the original 1:1 building-color mapping camouflaged every NPC against its own
      building/the grass — caught via screenshot, not assumed). Also repaired: the player
      character's north-view had actual face patches painted onto several idle/walk/tool frames
      (worse than `art/characters/README.md` had originally flagged — a simple neck sliver), now
      fixed frame-by-frame. **Basic buildings: done.** All 10 building kinds (farmhouse,
      mayor_house, store, shack, chest, bulletin_board, bed, shipping_box, shelter_tent,
      storage_shed) got real PixelLab art via `create_map_object` (basic mode, `low top-down` to
      match the characters, one generation per kind — every instance of a kind, e.g. all 4
      shacks, shares one texture). `create_map_object`'s 32x32 minimum canvas couldn't produce
      the 5 kinds with 16x16 (1x1-cell) footprints directly; resolved by generating at 32x32 and
      downscaling 2x with a modal-block kernel (each output pixel takes the most frequent color
      among its source block's opaque pixels) chosen over nearest-neighbor (broke up fine
      details) and box-average (blurry, and erased the chest's clasp) — verified visually at
      true in-game scale. `scripts/structures.gd`'s building-visual spawner now loads real art
      when `art/buildings/<kind>.png` exists, falling back to the original flat-color fill
      otherwise (same pattern as `farm.gd`'s crop art); the Phase 4 Stage 2 translucent-blue
      under-construction blueprint visual is untouched — only a *completed* building's visual
      swaps to the final art, confirmed via a screenshot showing a real Storage Shed standing
      next to a still-translucent pending Shelter Tent blueprint in the same frame.
- [x] First demo build exported (Windows). Godot 4.7's official Windows export templates
      installed (`~/Library/Application Support/Godot/export_templates/4.7.stable/`, downloaded
      from the official GitHub release, ~1.3GB), a hand-authored `export_presets.cfg` (Windows
      Desktop, x86_64, no codesigning) added and tracked in git (previously blanket-gitignored by
      boilerplate with no documented reason — now genuinely useful, secret-free project config,
      so un-ignored; the actual `build/` output is gitignored instead, being large regenerable
      binary output). A real headless export (`godot --headless --export-release "Windows
      Desktop" build/windows/WastelandHarvest.exe`) succeeded, producing a verified 109MB valid
      PE32+ Windows executable + its `.pck`. **Caveat:** this proves the export pipeline works
      end-to-end and is now a one-command operation for any future session — but this specific
      build predates the bug-fixing sprint and Art Pass 1 below, so re-export once those land
      before handing a build to actual playtesters.

**Integration + bug-fixing sprint verified independently:** re-ran the full suite myself
(187/187 unit tests, +10 new pinning `modal_gate.gd`'s pure `any_open()` logic including a test
that reproduces the exact reported bug shape) and both `tools/runtime_smoke.gd` and the new
`tools/soak_test.gd`, each passed cleanly twice in a row. Read through `modal_gate.gd` and its
wiring into all 4 modal surfaces — a clean, minimal, correctly-reasoned fix (closing is never
gated, only opening; the dialogue→store handoff still works because `dialogue_ui` closes itself
before emitting `store_requested`, verified this ordering holds). Confirmed no other integration
bugs beyond the one fixed — the HUD's inventory-grid toggle is correctly non-modal by design (not
a bug), and a soak-test stage confirmed three concurrent `day_started` subscribers (crop growth,
construction completion, shipping sale) resolve together with exact, non-double-counted state.
Verified no reformatting noise, clean save-file hygiene. Visually confirmed via screenshots: "B"
pressed mid-dialogue produces no build-mode overlay, dialogue box undisturbed.

**Art pass 1 (buildings half) verified independently:** re-ran the full suite myself (187/187,
unchanged — a pure art/rendering swap) and both `tools/runtime_smoke.gd` and `tools/soak_test.gd`
(both exercise real building placement/completion, so the blueprint-vs-completed visual swap and
collision footprints are proven, not just passing by coincidence). Confirmed all 10 generated
PNGs' actual pixel dimensions exactly match their expected footprint sizes (e.g. farmhouse
48x32, the 5 downscaled props genuinely 16x16) — `structures.gd` loads them unscaled, so a
mismatch would have misaligned the sprite against its collision body. Read through
`structures.gd`'s diff — the blueprint/final visual split is clean and correctly preserves the
Phase 4 Stage 2 under-construction rendering byte-for-byte. Visually confirmed via screenshots:
the town's building cluster, Marta's store close-up, all three 16px farmhouse-service-row props
reading distinctly at true scale, and — the most important check — a real Storage Shed and a
still-translucent pending Shelter Tent blueprint together in one frame, proving completion is
what triggers the art swap, not placement.

**Milestone (end of Year 1): Vertical slice demo complete.** Full farming loop, one town, 3 NPCs,
auto-save, day/night cycle working.

## Year 2 — Systems & Content Build-Out

Goal: all major game systems implemented — expedition combat, full NPC personalities,
building/settlement, seasons.

### Phase 7 — Advanced NPC System: Personalities, Schedules & Relationships
- [ ] NPC personality system — personality tags shape dialogue/behaviour: Paranoid Survivor,
      Optimistic Builder, Gruff Soldier, Gentle Medic, Secretive Scavenger, Pragmatic Trader
- [ ] Daily schedules — wake, tasks (garden/store/water walk), eat, sleep; location changes by
      time of day
- [ ] Relationship/affinity system — 0–10 affinity per NPC; up via daily talk/gifts
      preferred/quests, down via disliked gifts/neglect; gates dialogue and story events
- [ ] Gift preference database — liked/loved/neutral/hated items per NPC
- [ ] Context-sensitive dialogue — NPCs comment on weather, time of day, affinity, recent world
      events; stored in expandable JSON trees

**Milestone:** Town feels alive — NPCs move around, have schedules, react to you based on your
relationship with them.

### Phase 8 — Building, Settlement Expansion & Fencing System
- [x] **Building type library — 12+ structures (Stage 1 of the Phase 8 plan, see
      `/Users/sarveshpardeshi/.claude/plans/compiled-brewing-rocket.md`)**: Shelter Cabin,
      Storage Barn, Workshop, Clinic, Trading Post, Watchtower, Greenhouse, Compost Pit, Rain
      Collector, Solar Panel, Antenna Tower, Community Kitchen. Landed alongside a genuine
      generalization of the per-building dispatch that didn't exist before this stage: a new
      `data/buildings.json` schema (`interaction`/`daily_yield`/`capacity_unlock`/`effect`,
      backward-additive, migrated off the old `is_storage` bool) plus a new
      `scripts/building_effects.gd` registry, so a 13th functional building is data + at most one
      small bespoke callable, not three-file hardcoded wiring. `structures.gd` gained a
      `completed_entries()` getter and a `building_yield_produced` signal (wired to
      `player.add_items` in `main.gd`, the generalized-dispatch counterpart of the existing
      `crops_sold → player.add_credits` pattern); one-time `capacity_unlock` bonuses
      (Shelter Cabin's population cap, Clinic's +10 max energy, Solar Panel's 25% build-cost
      discount) are recomputed in full from the completed-buildings list on every boot/load
      rather than incrementally serialized, so they can never drift. Trading Post's
      `interaction: "trading_post"` and Watchtower/Antenna Tower's `effect` strings are data-only
      this stage — genuinely unreachable until Stage 4 (assignment) and Stage 3 (settler arrivals)
      wire them up, by design, not an oversight.
- [x] **Building grid system — already substantially built in Phase 4** (snap-to-grid placement
      via `builder.gd`/`build_grid.gd`, green/red valid-placement preview, resource cost shown in
      the build-mode HUD and the pause-menu catalog) — Stage 1's 12-building library is the first
      time the checklist's "1–3 day construction time by size" range is actually exercised (1-day
      1×1s, 2-day 2×2s, 3-day larger civic buildings), so checked off here rather than left open
      against infrastructure that was already sound.
- [x] **Fencing & perimeter system (Stage 2 of the Phase 8 plan)** — 3 fence tiers
      (Wood/Chain-Link/Concrete, `kind: "fence"`, escalating cost/`durability_max`) plus a Wood
      Gate (`kind: "gate"`), placed through the existing `builder.gd` single-cell flow — no new
      drag/linear placement UX, deliberately out of scope. `durability_max` is stored/displayed
      only this stage (no decay/damage system exists yet to consume it — data ahead of its
      system, same precedent as `fertilizer`). The real new mechanic: `BuildingDB.solid()`
      (default `true`, so no pre-existing building needed a data change) — a completed Gate
      drops its `CollisionShape2D` and calls a new `test_map.unblock_cells()` (the `block_cells()`
      counterpart) so it reads as a walkable opening in an otherwise-solid perimeter, while a
      construction site always blocks regardless of its final solidity. Closes the gap this
      opens (an unblocked Gate cell could otherwise be built over again) with a new
      `structures.gd::_is_footprint_occupied()` guard in `can_place()`. Solidity is re-derived
      from `BuildingDB.solid()` on save/load, never serialized, matching `_runtime_blocked`'s own
      "derive, don't serialize" rule. The farm layout's existing `'g'` "closed later" gap stays
      untouched — out of scope, per the plan.
- [x] **Settler system (Stage 3 of the Phase 8 plan)** — periodic visiting Survivor NPCs, gated by
      a live-recomputed population cap (`BuildingEffects.recompute_capacity_unlocks()`, Shelter
      Cabins) via the day-tick hook every other zone system already uses. Per the cozy "no fail
      state" contract (Silas's own "won't sell without a barn" precedent): a visitor is only ever
      offered with room in the roster AND no visitor already pending — one at a time, no queue.
      The roll/cooldown is split into small pure functions (`should_attempt_roll`/`roll_succeeds`/
      `next_arrival_day_after`) taking the random value as a parameter, so `tests/test_settlers.gd`
      can force success/failure deterministically without touching global RNG — this stage is
      `settler_arrival_modifiers()`'s first real consumer (Watchtower raises the chance, Antenna
      Tower shortens the cooldown, both implemented but unused since Stage 1). Accept/reject
      reuses the existing dialogue box wholesale — zero `player.gd` changes: a new
      `DialogueDB.register_runtime()`/`unregister_runtime()` additive layer lets a visitor's
      greeting/2-choice branch exist only in memory, and two new sentinels
      (`SETTLER_ACCEPT`/`SETTLER_REJECT`) in `dialogue_ui.gd` follow the existing
      `OPEN_STORE_SENTINEL` pattern exactly. Settlers always spawn into the Town zone (population
      growth is a town-plaza concept) at one of 4 verified-open `SETTLER_HOME_CELLS`. New
      additive top-level `"settlers"` save key (no `SAVE_VERSION` bump — the exact-match version
      check isn't touched, an old save just decodes the empty default).
- [ ] NPC–building assignment — assign a settler to a building for a passive benefit or
      functioning shop. **Specific narrative instance (added per `GDD.md` §§2–4/§11):** hiring a
      settler/newcomer for a weekly Credits salary to run the farm's own till/water/harvest loop
      — the payoff to the Day-28 beat above (Phase 5), a real simulated farming loop rather than
- [ ] NPC–building assignment — assign a settler to a building for a passive benefit or
      functioning shop. **Specific narrative instance (added per `GDD.md` §§2–4/§11):** hiring a
      settler/newcomer for a weekly Credits salary to run the farm's own till/water/harvest loop
      — the payoff to the Day-28 beat above (Phase 5), a real simulated farming loop rather than
      an abstracted trickle, not separate scope from this item.
- [x] **Ranch/Sanctuary compound (added per `GDD.md` §8/§11, `MAPS.md` §3)** — a dedicated small
      map area south of the farm, its own fenced compound with a distinct entrance gate separate
      from the town's main (city-bound) gate, one shared template across all 3 starts extending
      each layout's continuous map southward rather than a new scene-transition system (none
      existed yet at the time; disproportionate for this scope then — since superseded by
      Phase 4's zone-transition system above, which the Ranch now rides too). Real PixelLab art (`ranch_house`/`ranch_barn`/`ranch_coop`, flat/high-top-down,
      matching the town buildings' established convention) plus decorative cow/goat props
      (`scripts/props.gd` — cosmetic only, no animal-entity system).
- [x] **Rancher NPC — exists, no shop yet (added per `GDD.md` §8/§11)** — Silas, the
      Ranch/Sanctuary's keeper, spawned with real character art and full dialogue (including an
      honest in-character line that he won't sell livestock until the player has a barn/coop to
      put them in — matching Marta's own Stage-1 precedent of not faking an unbuilt shop). The
      actual buy-animal transaction is **not** built yet — that's still open, along with the
      Barn/Coop split below, both genuine Phase 8 gameplay systems this pass deliberately didn't
      reach.
- [ ] **Barn/Coop building split (added per `GDD.md` §8/§11)** — the generic "Storage Barn" above
      is resource storage only; add distinct **Barn** (cows/goats/pigs) and **Coop** (chickens)
      building types the player constructs on their own farm via the building-grid system above,
      sized/tiered to the yield-vs-hardiness axis (`GDD.md` §8's "Animals & pets"). This is where
      animals bought from the Ranch/Sanctuary actually live and produce.

**Milestone:** Settlement can grow — buildings, fences, and settlers all function together as a
real base-building loop, and the player can buy and house their first livestock.

**Phase 8 Stage 1 verified independently:** re-ran the full suite myself (278/278 tests, +19 new)
and `tools/runtime_smoke.gd`/`tools/soak_test.gd` individually (never batched) — all green,
matching Fable's own report exactly. Read the full diffs on every changed file: confirmed
`building_effects.gd`'s self-referencing `Callable(Self, ...)` pattern is sound, `structures.gd`'s
new day-tick pass stays inventory-agnostic (only ever emits, never touches `player`), and
`main.gd`'s `_recompute_capacity_unlocks()` is genuinely called from both the fresh-game and
loaded-game paths so capacity bonuses can't drift. Verified `_test_map.get_node("Farm")` (the Rain
Collector's zone-scoping) is an existing, already-used pattern in this same file, not a new
assumption. Cross-checked `buildings.json`'s new fields against `building_db.gd`'s new accessors
and the `EFFECTS` registry by hand — all 12 buildings' dispatch shapes match the Stage 1 plan's
table. Confirmed Shelter Cabin/Storage Barn kept their exact original `size`/`cost`/`build_days`
(only the display name and schema migrated) — the right call, since `runtime_smoke.gd`/
`soak_test.gd` pin those exact numbers. `data/buildings.json`/`items.json` diffs re-confirmed real
content via `git diff -w` (not noise) before committing.

**Phase 8 Stage 2 verified independently:** re-ran the full suite myself (292/292 tests, +14 new)
and `tools/runtime_smoke.gd`/`tools/soak_test.gd` individually (never batched) — all green,
matching Fable's own report exactly. Read every diff: confirmed `_spawn_footprint_body`'s new
`solid` param is real (a genuine skip of `CollisionShape2D` creation, not a cosmetic flag), that
`_complete_construction`'s retire-and-respawn approach correctly keeps the `_bodies` tracking
array consistent (verified `_bodies` is a real pre-existing field, `_spawn_footprint_body` always
appends to it), and that `_is_footprint_occupied()`'s guard is wired into `can_place()` exactly
where the unblocked-Gate gap needed closing. `tests/test_structures_fencing.gd`'s fake
map/farm/layout stand-in exercises the real `place_blueprint → _complete_construction → can_place`
flow unmodified (not mocked-out) — read in full, sound. `runtime_smoke.gd`'s stages 130-132 prove
the actual walkability milestone with real physical collision (player driven into a completed
Fence and stopped; driven through a completed Gate and passes clean), plus the save/reload
persistence check confirms solidity is correctly re-derived, never serialized. `buildings.json`'s
diff re-confirmed as real content via `git diff -w` before committing.

**Phase 8 Stage 3 verified independently:** re-ran the full suite myself (313/313 tests, +21 new)
and `tools/runtime_smoke.gd`/`tools/soak_test.gd`/`tools/settler_smoke.gd`/`tools/title_smoke.gd`/
`tools/zone_transition_smoke.gd` individually (never batched) — all green, matching Fable's own
report exactly. Read every diff: confirmed `settlers.gd`'s roll/cooldown gating is split into
genuinely pure, parameter-fed functions (not just wrapped RNG), that `population_cap()` is never
cached (recomputed from `_all_completed_entries()` every call, same rule as `player.max_energy`),
and that `dialogue_ui.gd`'s new `SETTLER_ACCEPT`/`SETTLER_REJECT` sentinels are wired exactly like
the existing `OPEN_STORE_SENTINEL` precedent. Verified the 4 new `SETTLER_HOME_CELLS` by hand
against the real Town `ROWS` data — all open grass, clear of every `TOWN_NPCS` home and building
footprint. Confirmed a real bug fix: `decode_settlers`' roster must be built as a typed
`Array[Dictionary]` (Godot 4.7 refuses a plain-Array assignment into a typed field even when every
element matches) — this would have crashed on load otherwise. `settler_smoke.gd` drives the full
accept/reject flow through the actual input pipeline (real `use_tool`, real dialogue advance,
real choice-selection) rather than calling `settlers.gd` methods directly — read in full, sound.
Save-file hygiene re-confirmed clean after all runs.

### Phase 9 — Expedition System: Ruined City & Combat
- [ ] Ruined city map(s) — 2–3 distinct zones: Downtown Ruins, Industrial Quarter, Residential
      Blocks; hand-crafted, hidden areas, loot spawns
- [ ] Solo expedition mode — limited expedition-inventory backpack, travel to a zone, auto-return
      at set time (or earlier by choice), stamina countdown
- [ ] Zombie & monster AI — patrol routes, line-of-sight detection and chase, states Idle →
      Alerted → Chasing → Attacking (`NavigationAgent2D`)
- [ ] Combat system — melee (swing range, knockback, hit flash) and ranged (thrown objects,
      scavenged crossbow); player HP; death during expedition loses expedition loot and respawns
      at settlement with 10% HP
- [ ] Loot system — destructible crates/cars/buildings, weighted loot table (scrap, food, seeds,
      medicine, tools, blueprint scrolls, ammo); blueprint scrolls unlock buildings/recipes
- [ ] Settlement confirmed as a safe zone — zombies cannot enter the settlement boundary
- [ ] **Raider/scavenger faction (added per `GDD.md` §6/§11)** — a human faction occupying part
      of the ruined city, distinct from zombie/monster AI: patrols, ambush events, and turf that
      reacts to the reputation system below rather than always attacking on sight
- [ ] **Faction reputation system (added per `GDD.md` §6/§11)** — tracked player standing
      (Hostile → Wary → Tolerated → Trusted) driven by actions (combat, fair trading, completed
      jobs, story/quest choices) not dialogue checkboxes; gates faction aggression, trader
      access, and safe passage through their turf. Deliberately quarantined from the
      settlement's safe-zone guarantee — a city/world system only.
- [ ] **Radiation exposure mechanic (elaborates Phase 11's radstorm event per `GDD.md` §5)** —
      persistent tracked meter alongside HP/stamina during expeditions; irradiated zones/loot,
      degraded stamina/HP ceiling as exposure climbs, countered by hazmat gear (scrap → proper
      suits) and purifier meds (craftable, see Phase 10); gives the radstorm weather event real
      teeth and soft-gates deeper/hotter zones without literal locked doors

**Milestone:** Expeditions feel risky and rewarding. Player must prepare before going, and brings
back supplies that improve the town. Raider faction reacts believably to the player's tracked
reputation.

### Phase 10 — Business System, Crafting & Advanced Economy
- [ ] Crafting system — Workshop crafts Scrap Tools, Preserved Food, Medicine, Ammunition,
      Building Materials; recipes unlocked via Blueprint Scrolls
- [ ] Player-run businesses — Trading Post lets the player set sell prices and stock from
      inventory
- [ ] Settler economy — settlers assigned to businesses generate passive income/goods daily
- [ ] Caravan traders — weekly visiting NPCs with rotating rare-goods stock; prices/stock react
      to town affinity
- [ ] Supply & demand — store prices fluctuate based on recent sales (e.g. overselling Dustwheat
      devalues it)
- [ ] **Faction barter trading (added per `GDD.md` §6/§7/§11)** — raider faction and other
      barter-only partners (remote traders, independent scavengers) don't accept Credits; goods-
      for-goods trading with idiosyncratic valuations (e.g. the faction overvalues ammo
      components/meds) unlocked progressively as reputation rises from Wary to Trusted

**Milestone:** The town has a self-sustaining economy beyond the basic store — crafting,
businesses, and dynamic pricing all function.

### Phase 11 — Seasons, Weather & World Events
- [ ] 4-season cycle (28 in-game days each): Spring Rains, Scorched Summer, Amber Autumn, Grey
      Winter — each changes growable crops, store stock, and lighting palette
- [ ] Seasonal crops — 4–6 unique crops per season; Winter requires the Greenhouse for outdoor-
      equivalent farming
- [ ] Weather system — daily rolls: clear, cloudy, rain (auto-waters crops), heavy storm (stay
      indoors), rare radstorm (don't go outside); forecast icon in HUD
- [ ] World events — scripted triggers: Bandit Scout near perimeter, Trader Caravan arrival,
      Survivor seeking shelter, disease outbreak (Clinic needed), Mysterious Signal (story hook)
- [ ] Town festivals — seasonal community events (Harvest Day, Winter Gathering) boosting NPC
      affinity, with mini-game activities

**Milestone:** The world feels alive over time — seasons, weather, and scripted events all
change what's happening without the player doing anything.

### Phase 12 — Full Map Polish, Fishing & Beta Testing
- [ ] All 3 starting maps fully built — complete tile art, unique lore notes, distinct
      early-game advantages
- [ ] Water body + fishing — animated water tiles, cast-and-catch minigame, fish as
      food/trade commodity, rare fish trigger NPC dialogue
- [ ] Full town map — mayor's house, Marta's store, Clinic, Watchtower, Community Board,
      6–10 settler homes, dock, market stalls
- [ ] Closed beta released to 10–20 testers; feedback collected on balance/clarity/fun
- [ ] Performance audit — stable 60fps on modest hardware; tile rendering, NPC pathfinding, and
      save/load times optimised

**Milestone (end of Year 2): All core systems built.** Full game loop from farming →
expeditions → building → economy → seasons. Beta tested.

## Year 3 — Story, Expansion & Launch

Goal: full story, expanded world, co-op expeditions, full audio/visual polish, and public launch.

### Phase 13 — Story, Narrative & Quest System
- [ ] Main story arc written — why the player arrived, what caused the apocalypse, a rebuild-
      vs-push-further decision with no single ending
- [ ] NPC personal questlines — 8–10 main NPCs each get a 3–5 quest chain revealing backstory
      and resolving a personal struggle
- [ ] Quest journal UI — active/completed quests, objectives, NPC portrait, lore snippet;
      tracked per NPC and per story chapter
- [ ] Story moments & cutscenes — short pixel-art animated sequences (2–5s) for high-impact
      story beats, used sparingly
- [ ] Lore layer — handwritten notes, radio broadcasts, worn posters scattered through the
      world, drip-feeding backstory

**Milestone:** The main story is fully playable start to finish, with at least one NPC personal
questline complete end to end as proof of the pattern.

### Phase 14 — Expanded World: Nearby Cities & New Zones
- [ ] World map screen — stylised hand-drawn map, settlement + 3 ruined-city zones + 2 new
      major city areas (locked until mid-game) + points of interest; fast-travel unlocked via
      Radio Tower components
- [ ] **Other small settlements (added per `GDD.md` §7/§11)** — a few other small human
      settlements beyond the home town and the ruined city, reachable via established trade
      routes and player vehicles; small trading-post destinations with their own merchants and
      quest hooks, not full towns to maintain — the home settlement stays the game's one deep
      social hub
- [ ] 2 new major city zones — "The Vault District" (high danger/reward) and "The Boneyard
      Markets" (semi-safe trading hub, new merchant NPCs)
- [ ] Underground/bunker areas — hidden entrances, darker claustrophobic aesthetic, harder
      enemies, unique pre-war loot
- [ ] 5 new enemy types: Mutant Hound, Armoured Zombie, Feral Scavenger, Acid Spitter, rare Boss
      Behemoth guarding a major loot cache
- [ ] 15 unique named legendary items, endgame-zone-only

**Milestone:** The explorable world roughly doubles in size and difficulty ceiling, with new
zones, enemies, and loot distinct from Year 2's content.

### Phase 15 — Team Expeditions & Co-Op System
- [ ] Co-op expedition framework — 2–4 players join an expedition via online lobby (Godot
      networking or Steam multiplayer); host's world shared, guests join for the expedition only
- [ ] Party formation UI — loadout visibility, agreed destination zone, shared return timer
- [ ] Co-op combat scaling — enemy count/HP scale with party size; harder but proportionally
      more loot
- [ ] Shared loot distribution — round-robin draft at expedition end
- [ ] NPC companion expeditions — 1–2 settler NPCs as a solo alternative to co-op, reduced
      combat effectiveness, extra loot carry

**Milestone:** A 2-player co-op expedition can be completed start to finish, with working loot
distribution.

### Phase 16 — Audio, Visual Polish & Accessibility
- [ ] Full pixel art pass — consistent style across all tiles/characters/items/UI; animated
      water, fire, swaying crops, NPC blink, tool swings
- [ ] Sound design — per-zone ambient soundscapes, distinct action sounds (till, water pour,
      chop)
- [ ] Original soundtrack — 10–15 tracks, chiptune-meets-post-apoc-ambient, varying by zone/mood
- [ ] UI/UX redesign pass — worn-paper/scavenged-metal theme, consistent font, UI sound
      feedback
- [ ] Accessibility options — text size, colourblind mode, reduced motion, dialogue subtitles,
      remappable controls

**Milestone:** The game looks, sounds, and feels like a finished product, and is usable by
players who need accessibility accommodations.

### Phase 17 — Balance, Content Completion & Achievements
- [ ] Economy balancing — full item pricing, earning-curve tuning, verified via 5 full
      playthroughs
- [ ] Complete item database — 120+ unique items across all categories
- [ ] All NPC dialogue finalised — 30+ lines per main NPC, all quest stages complete, seasonal
      and affinity-dependent responses
- [ ] Achievement system — 40 achievements (farming, social, exploration, survival, hidden
      story-moment achievements)
- [ ] Options menu — 3 save slots, volume/resolution/fullscreen controls, control rebinding

**Milestone:** Content is locked — no more new systems or items, only tuning from here.

### Phase 18 — QA, Launch Preparation & Release
- [ ] Full QA bug sweep — save/load edge cases, NPC schedule conflicts, expedition loot
      exploits, building placement bugs, multiplayer desyncs
- [ ] Performance optimisation — stable 60fps on a 5-year-old mid-range PC
- [ ] Platform export — Windows PC (Steam & itch.io) primary; macOS/Linux stretch goals; console
      ports explicitly deferred 6+ months post-PC-launch
- [ ] Store page & marketing — Steam page, 90-second trailer, store description, devlogs
      (itch.io, r/indiegaming, r/gamedev, Discord)
- [ ] Press & content-creator outreach — keys sent 2 weeks pre-launch, Stardew Valley fans as
      primary audience
- [ ] Launch-day monitoring — crash reports, review responses, 24-hour critical hotfixes, Day 1
      patch from beta feedback

**Milestone (end of plan): Wasteland Harvest is live** on Steam and itch.io. Full farming/
building/economy loop, expedition combat, story with NPC questlines, co-op expeditions, audio/
visual polish complete.
