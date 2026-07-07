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
- [ ] Player character — 4-directional movement, walking animation (idle, walk, tool-use),
      Godot's `CharacterBody2D`
- [ ] Tile-based world — `TileMap` node, small test map (farmland + surrounding area), collision
      layers
- [ ] Camera system — smooth follow camera clamped to map boundaries, screen-shake hook for
      future combat
- [ ] Day/Night cycle — global `DayManager` node tracks time (e.g. 1 in-game minute = 1 real
      second), sky colour shifts dawn → noon → dusk → night via `CanvasModulate`, day counter in
      HUD
- [ ] Basic HUD — day number, in-game clock, energy bar, post-apoc UI aesthetic (scavenged
      metal, cracked glass)

**Milestone:** Day/night cycle fully functional. Player can walk around a test map and time
passes visually.

### Phase 3 — Farming Core & Inventory System
- [ ] Till soil with a hoe (normal ground tile → farmable tile)
- [ ] Plant seeds (place seed item on tilled tile)
- [ ] Water crops daily or they die; visual indicator if watered
- [ ] Growth stages — 4–6 visual stages per crop, auto-progress each morning; post-apoc crops:
      Mutant Potato, Dustwheat, Ironroot, Sunbloom
- [ ] Harvest — interact with mature crop to collect produce
- [ ] Inventory grid — slot-based with item stacking, hotbar for quick access
- [ ] Tool system — Hoe, Watering Can, Axe, Pickaxe, Bag, each with durability (upgradeable
      later)
- [ ] Energy system — actions cost energy; passing out at zero energy loses the rest of the day
- [ ] First 20 items defined (seeds, crops, wood, stone, scrap metal, food)

**Milestone:** Full farming loop functional: till → plant → water → grow → harvest → inventory.

### Phase 4 — Settlement Maps, Building & Auto-Save
- [ ] Settlement selection screen — choose from 3 starting maps at game start, each with
      different layout/terrain/lore blurb and differing starting resources (water access vs.
      ruin materials vs. better soil)
- [ ] Full farmland map — player's home area: farm plots, derelict home structure, storage
      chest, a small perimeter fence gap (closed later)
- [ ] Town map rough draft — mayor's fortified house, one trading store, 3–4 settler shacks,
      water body (river or lake) with dock, bulletin board
- [ ] Basic building placement — place a structure blueprint, spend resources, wait 1 in-game
      day; simple grid-snap system
- [ ] Auto-save at end of day — interacting with a bed saves all state (crops, inventory, day,
      world modifications), brief "WORLD SAVED" notification, `FileAccess` + JSON serialisation

**Milestone:** Auto-save works. Player can quit and reload mid-playthrough with all state
restored.

### Phase 5 — Basic NPCs, Town Economy & Dialogue
- [ ] NPC base class — name, sprite, position, dialogue data, wanders within a defined zone
      (`NavigationAgent2D`)
- [ ] Dialogue system — interact near an NPC to open a dialogue box, character-by-character text,
      basic branching, dialogue stored in JSON for easy editing
- [ ] First NPCs: Mayor Harlan (quest-giver), Marta (store owner), Scout Kael (tells you about
      the ruined city)
- [ ] Town store — Marta sells seeds/basic tools/food; UI shows name/description/price; currency
      is Credits (per `GDD.md` §7; not "Scrap Coins" as earlier drafted — Credits is settled
      humanity's established currency, with barter as a parallel economy for raiders/remote
      traders who don't accept it)
- [ ] Shipping box — place harvested crops before sleeping; Credits added next morning; tracks
      sale history

**Milestone:** Player can farm, sell crops, earn currency, and buy seeds. Economy loop is closed.

### Phase 6 — First Playable Build & Stabilisation
- [ ] All Year 1 systems integrated — farming, inventory, economy, NPCs, day/night, auto-save
      work together without conflicts
- [ ] Bug-fixing sprint — play through 5 in-game days end to end; fix crashes, edge cases,
      broken tile interactions
- [ ] Internal playtesting — 3–5 people play it; note confusion/breakage/fun; prioritise fixes
      for the next phase
- [ ] Art pass 1 — replace placeholder tiles with proper pixel art: ground tiles, farmland,
      player character, 3 NPCs, basic buildings
- [ ] First demo build exported (Windows)

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
- [ ] Building type library — 12+ structures: Shelter Cabin, Storage Barn, Workshop, Clinic,
      Trading Post, Watchtower, Greenhouse, Compost Pit, Rain Collector, Solar Panel, Antenna
      Tower, Community Kitchen
- [ ] Building grid system — snap-to-grid placement, valid/blocked preview, resource cost shown,
      1–3 day construction time by size
- [ ] Fencing & perimeter system — fence segments/walls/gates around the settlement boundary;
      wood/chain-link/concrete, differing durability (relevant to future raid events)
- [ ] Settler system — periodic Survivor NPC arrivals asking to join; accept/reject; accepted
      settlers add to population and unlock dialogue/economy options
- [ ] NPC–building assignment — assign a settler to a building for a passive benefit or
      functioning shop

**Milestone:** Settlement can grow — buildings, fences, and settlers all function together as a
real base-building loop.

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
