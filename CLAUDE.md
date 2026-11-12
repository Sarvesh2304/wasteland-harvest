# Wasteland Harvest

A post-apocalyptic farming & survival RPG in the pixel-art style of Stardew Valley. The player
rebuilds a settlement — farming, building, NPC relationships — while running combat expeditions
into ruined cities for loot, story, and danger. Unlike Blood Fields: Empires (a sibling project,
see "Shared Assets" below), this game uses Stardew's **actual** top-down projection: a plain
axis-aligned grid, not a rotated isometric diamond.

Full original design source: `Wasteland Harvest 3-Year Dev Roadmap.html` (kept in this repo for
reference/history). **`GDD.md` is the authoritative statement of what the game *is*** — world,
lore, tone, loops, systems — written from a design Q&A with Sarvesh; consult it before making
any content or systems-design judgment call not already spelled out in `ROADMAP.md`.
**`ROADMAP.md` in this repo is the authoritative, living task list** — the HTML file is frozen;
`ROADMAP.md` is what gets checked off. Where `GDD.md` expands scope beyond `ROADMAP.md`'s
current checklist text, that's flagged in `GDD.md`'s final section rather than silently
assumed — reconcile those flags into `ROADMAP.md` as you touch the relevant phases.

## Why no calendar

The original roadmap was paced for a 3-year first-time solo developer (see the HTML's phase
months). That pacing is intentionally discarded here — this project is built primarily by a
Fable 5 agent, so phases are gated by **milestones**, not months. Work through `ROADMAP.md`
phases in order (each has real dependencies on the last); a phase is "done" when its milestone
line is objectively true (tests pass, systems work end-to-end, content exists), not when a date
arrives.

## Team model: who does what

Same model as Blood Fields: Empires, carried over because it worked well there:
- **Fable 5** (via the `Agent` tool with `model: "fable"`) was the primary hands-on builder:
  GDScript, scene construction, art-direction calls, content writing (dialogue, lore notes,
  quest text), PixelLab art-generation calls.
- **Fable unavailable (2026-08-09, confirmed account-wide, not this project's own quota lapse):**
  Sarvesh confirmed Fable is down everywhere right now, same situation as Blood Fields: Empires
  (see that project's `CLAUDE.md` for the identical note) — and wants the shared ~$100 Anthropic
  API credit preserved for later. Builder-seat work routes to **Opus** (`Agent` tool,
  `model: "opus"`) per the existing fallback rule below, now as the standing default rather than
  a temporary detour. Revisit if Fable comes back or Sarvesh says otherwise.
- **Sonnet** (orchestrating session) reviews the builder's output independently before trusting it
  (re-run tests yourself, re-check diffs — don't just relay Fable's own summary), runs
  tests/builds, verifies milestones, handles git operations, and gates anything risky.
- **Fable-unavailable fallback:** Fable 5 has a separate weekly usage limit from the rest of
  this plan; when it's hit mid-week, don't block on it waiting for reset — the builder seat is
  just a `model:` parameter to the `Agent` tool, so swapping it is mechanical, not a workflow
  change. Split by task size rather than picking one universal substitute: route substantial
  multi-file builds, new systems, and art-direction-heavy work (the kind of task Fable would
  normally take) to **Opus** (`Agent` tool, `model: "opus"`), with every other convention in
  this section unchanged — same prompt-writing discipline, same independent Sonnet review
  (re-run tests, re-read the diff, don't trust the builder's own summary, regardless of which
  model produced it). For small, quick fixes (a one/two-line bug, a doc-comment update, a
  config tweak) Sonnet edits directly instead of spinning up an agent at all — there's rarely
  enough surface area there for a second pair of eyes to meaningfully add anything. Switch
  back to routing new work to Fable as soon as its limit resets; this is a temporary detour
  around a quota, not a reconsideration of Fable as the primary builder.
- **Gate before acting, every session, no standing approval:** opening/driving the Godot **GUI
  editor** itself, `git push`, and creating/modifying anything in `~/Projects/shared-assets`
  (a second project, Blood Fields: Empires, already depends on it) all require explicit
  confirmation from Sarvesh first, even if a similar action was approved earlier. Editing files
  in this repo by hand (including `.tscn`/`.godot` project files as text) does not require
  confirmation, and is preferred over launching the Godot GUI when it accomplishes the same
  thing.
- **Standing exception:** running Godot **headlessly** (`godot --headless ...`, e.g. to execute
  a GDScript test suite or `--check-only` validate a scene) has standing approval for the rest
  of this build — no need to ask each time. This does not extend to the GUI editor.
- **Standing exception:** launching the **compiled game itself** in windowed mode (e.g. `godot
  --path .`, with no `-e`/`--editor` flag, which runs `run/main_scene` directly rather than
  opening the editor) has standing approval for the rest of this build, specifically to
  visually verify gameplay/rendering and take screenshots — granted explicitly by Sarvesh
  2026-07-08 after the auto-mode classifier blocked an attempt on the (correct, at the time)
  reading that the editor gate covered it too. This is still distinct from and does **not**
  extend to opening the Godot **editor** GUI (`godot -e`/`--editor`), which still requires
  per-session confirmation as above.
- **PixelLab job concurrency:** learned from Blood Fields: Empires — PixelLab caps concurrent
  generation jobs at 8 total, and one 8-direction `animate_character` call consumes all 8 at
  once, so animation jobs for different NPCs/creatures cannot run in parallel with each other.
  Plan serial-with-immediate-requeue. Also: don't trust a background agent's own "I'll wait for
  the timer" self-report as evidence of progress — background self-wake sleeps have failed to
  actually resume an agent more than once; check PixelLab status directly
  (`list_characters`/`get_character` etc.) instead.
- **Autosave at 98% session/context usage:** for every session (Sonnet orchestrator or a Fable 5
  builder agent), when session/context usage is reported at or approaching 98% — whether
  self-reported or reported by Sarvesh in chat — treat that as a hard trigger to immediately
  commit (and push, if push has already been confirmed for that session) whatever verified work
  is sitting uncommitted, rather than waiting for a natural stopping point. Don't just checkpoint
  at phase/stage boundaries (see "Repo Conventions" below) — checkpoint reactively the moment a
  reported percentage gets close to the limit, since a session can end with no further warning
  after that.

## Engine & Technical Spec

- **Godot 4.7** (installed at `~/Downloads/Godot.app` on this machine — same install used for
  Blood Fields: Empires).
- **Top-down 2D** (plain axis-aligned TileMap, NOT isometric/rotated) — Stardew's actual
  projection: camera looks straight down, only characters/props get a bit of forced-perspective
  height, floor tiles are flat squares. This was an explicit lesson from Blood Fields: Empires,
  where a rotated-diamond isometric grid caused a real, hard-to-fix bug (piece sprites visually
  overlapping neighboring tiles, breaking click hit-testing) — a plain top-down grid avoids that
  class of problem by construction. GDScript (not C#).
- **Tile size: 16×16 px (decided in Phase 1)** — matches Stardew Valley's actual base tile size,
  chosen specifically to keep the ~120-item art pipeline tractable. `project.godot`'s viewport
  (320×192, an exact 20×12 tiles) and Nearest-neighbor texture filtering are both set
  accordingly. See `GDD.md` §9 for the full concrete palette that was locked alongside this.
- **Click/interact hit-testing:** even in a top-down (non-diamond) grid, don't let interaction
  resolve on raw tile-geometry alone if a sprite (player, NPC, prop) can visually extend beyond
  its own tile — resolve against actual visible sprite bounds first, matching the fix *designed*
  for Blood Fields: Empires after a real bug there (documented in that repo's `ROADMAP.md` "Known
  Issue" / `CLAUDE.md`'s "Board interaction convention" — not yet implemented there as of
  2026-07-09, so don't assume a working reference implementation exists to copy). Cheaper to
  build this in from the start than to retrofit it.
- Git from day one; commit every working session.

## Art Pipeline — PixelLab-first

Generate tiles, character/NPC sprites, and UI assets primarily via the **PixelLab MCP tools**
available in this environment (`create_character`, `animate_character`, `create_topdown_tileset`,
`create_ui_asset`, `create_font`, etc. — note `create_topdown_tileset` rather than
`create_isometric_tile`, since this project's grid is top-down, not isometric), rather than
hand-drawing in Aseprite from scratch. Aseprite is still the tool of choice for manual touch-ups
and anything PixelLab output needs correcting.

Palette: post-apocalyptic dusty ambers and faded greens, now locked to concrete hex values with
seasonal modulation — see `GDD.md` §9 (settlement anchor + per-season sets + separate,
unmodulated ruins palette). First PixelLab test tiles generated at 16×16 using this palette live
under `art/tiles/` (see `art/tiles/README.md` for provenance).

## Chess Engine

N/A — this project has no chess engine. (Removing this section is intentional; it's a holdover
reminder from the Blood Fields: Empires template this file was adapted from, listed here so it's
obvious the omission is deliberate, not an oversight.)

## Core Systems (see `ROADMAP.md` for the full phase-by-phase breakdown)

- Farming loop: till → plant → water → grow → harvest → sell, with post-apoc themed crops
  (Mutant Potato, Dustwheat, Ironroot, Sunbloom).
- Day/night cycle, seasons (4, 28 in-game days each), weather.
- NPC system: personality tags, daily schedules, affinity/relationship tracking, gift
  preferences, branching dialogue.
- Settlement building: placeable structures, fencing/perimeter, settler recruitment and
  building assignment.
- Expedition system: ruined-city zones, combat (melee + ranged), loot tables, roguelike death
  penalty (lose expedition loot, respawn at settlement).
- Economy: town store, player-run trading post, caravan traders, supply & demand pricing.
- Story: main narrative arc + per-NPC personal questlines.
- Co-op: 2–4 player expeditions (later phase, see `ROADMAP.md` Year 3).

**Testing:** same convention as Blood Fields: Empires — custom lightweight GDScript test runner,
no addons (not GUT). Runner must extend `SceneTree`/`MainLoop` so it's invocable headlessly, e.g.
`godot --headless --path . --script res://tests/run_tests.gd`. Standing approval for headless
Godot CLI use (see "Team model" above) specifically so this can be run for verification without
asking each time.

## Shared Assets (`~/Projects/shared-assets`, sibling repo)

Already scaffolded and pushed to GitHub (https://github.com/Sarvesh2304/shared-assets) as part of
Blood Fields: Empires — this project is the second consumer it was built for. Contains: `fonts/`,
`gore-tile-styles/` (may be relevant here too, given zombie/combat content — check before
assuming it's chess-specific), `particle-presets/`, `panel-textures/`. Anything faction/genre-
agnostic and reusable across both games belongs there, not duplicated into `art/` here. Touching
this repo requires confirmation first (see "Team model" above) since Blood Fields: Empires
already depends on it.

## Platform & Release

PC first (Windows/Mac/Linux via Godot export), **Steam and itch.io** both (more ambitious than
Blood Fields: Empires's itch.io-only target — per the source roadmap's explicit Steam page,
trailer, and press-outreach plan). Co-op multiplayer (2–4 players) is in scope for Year 3, unlike
Blood Fields: Empires. Console ports require separate certification — explicitly out of scope
until 6+ months post-PC-launch, per the source roadmap.

## Repo Conventions

- Commit every working session, descriptive messages.
- `ROADMAP.md` phase checkboxes get updated in the same commit as the work that completes them.
- No secrets/credentials ever committed.
- Before committing, check `project.godot` and any JSON data files for incidental
  whitespace/float-precision reformatting from Godot's `--import` step or the editor being left
  open — this happened repeatedly in Blood Fields: Empires and is pure noise, not real changes.
  Exclude it from commits.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- When graphify-out/graph.json exists, run `graphify query "<question>"` before your first grep, search or source-file read for a codebase question, and put this rule in every subagent prompt that explores code. Read raw files only for lines the graph or an earlier read already located. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- A committed graphify-out/graph.json is rewritten whole on every build, so a large diff to it in a pull request is expected. Do not flag it as churn or suggest skipping the graph rebuild or its hooks.
