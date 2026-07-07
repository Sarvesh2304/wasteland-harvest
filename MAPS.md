# Wasteland Harvest — Map Layout Sketches

**Status:** Phase 1 design document — conceptual/textual layout sketches, not built maps.
Actual map construction happens in Phase 4 (settlement and town), Phase 9 (ruined city), and
Phase 12 (full polish pass). This document is the spatial companion to `GDD.md`: it says where
things *are*, the way the GDD says what things *mean*. Where it makes a call the roadmap leaves
open, that call is stated explicitly so Phase 4 can build without re-litigating it.

---

## 1. The Three Starting Settlements

All three starting maps share the same founding fiction (`GDD.md` §2): around twenty-five years
after the war, a band of survivors — the player's parents among them — stopped running because
they found a patch of land that was defensible, had water, and had soil clean enough to farm.
The three starting types are three different answers to *what kind of patch it was*. Each gets
a distinct terrain layout, a lore blurb for the selection screen, and one clear early-game
resource lean, matching ROADMAP.md Phase 4's split: **water access vs. ruin materials vs.
better soil**. The lean shapes the first in-game year, not the whole game — every start can
eventually build everything.

A structural decision, stated here so Phase 4 doesn't have to guess: the three starting maps
vary the **player's farmland map and its surrounding terrain**. The **town core** (§2 below) is
a single spatial template shared by all three starts, re-dressed by the surrounding terrain
(treeline behind the shacks at Forest Edge, the river doubling as the water body at Riverside,
open horizon at Open Plains) rather than three fully hand-built towns. This keeps the Phase 4–5
build tractable and keeps NPC schedules/pathing identical across starts. If a later phase wants
divergent towns, that's a scope addition to flag then.

### Forest Edge — the salvager's start (lean: **ruin materials**)

**Lore blurb.** The founders followed a creek up out of the wastes and stopped where the trees
began. What looked like wild forest turned out to be younger than it seemed: half a century of
green swallowing a pre-war suburb. Under the moss there are foundations; under the leaf-litter,
street signs. The settlement grew up in a broad clearing with its back to the woods — the
founders liked that the trees hid them from the road, and they liked even better that the
forest was full of the old world's bones, close enough to haul home by handcart.

**Layout sketch.** The map is a clearing pushed against a dense treeline that runs the whole
northern and eastern edge. The farmhouse sits at the clearing's heart with farm plots fanning
south and west of it — sunward, away from the canopy shade, in irregular patches broken up by
stumps and old foundation lines rather than one big clean rectangle. The creek cuts the
south-west corner (enough water to farm, not enough to fish seriously). Woven through the
treeline itself are the overgrown ruins: collapsed suburban walls, a rusted car half-eaten by a
tree, salvage nodes among the trunks. The town core sits south of the farm along the old
suburb's buried main road; the perimeter fence runs tight around clearing and town, with the
forest pressing close against its north-east length — cover works both ways, and night sounds
come from the trees.

**Resource lean, justified.** The reclaimed suburb makes Forest Edge the **ruin-materials**
start: scrap metal, concrete chunks, and salvage sit inside walking distance from day one,
where the other starts must run expeditions or trade for them. Abundant timber is the natural
secondary perk. The trade-offs: farm plots are cramped and irregular (worst total plantable
area of the three), canopy shade and root-tangled soil mean unremarkable yields, and the
proximity of ruin-stuff means the map reads a shade closer to the wasteland than the others —
chosen by players who want to build and craft early.

### Riverside — the fisher-trader's start (lean: **water access**)

**Lore blurb.** The founders stopped at the river because everyone stops at the river. A slow,
wide bend with a gravel shallow, an intact pre-war bridge pier to anchor a dock to, and water
that ran clean enough once the filters were built. The settlement grew along the bank the way
river towns always have — and when the first trade caravans started moving again, they moved
along the water, which means Riverside heard the news first and sold to the messengers.

**Layout sketch.** The river runs the full western edge of the map, north to south, with the
settlement strung along its eastern bank. The dock is the map's signature feature — planks out
over the water at the town core's western edge, doubling as the fishing spot and the caravan
landing. The farmhouse sits just north of town on a low bluff above the floodline, plots
terraced between house and bank. The waterline itself is the best land on the map: naturally
irrigated silt rows where crops never miss a watering. Farther east the ground rises and dries
into gravel and scrub — expansion that way costs effort. The perimeter fence describes a
half-circle with both ends anchored on the riverbank; the river *is* the western wall, which
the town is proud of and the wary NPCs privately are not (things can wade).

**Resource lean, justified.** The obvious mapping, and it should feel generous: **water
access** means irrigation trivially early (the GDD's watering chore is lighter along the silt
rows), fishing from day one off the dock (the Foraging skill's water half, `GDD.md` §8), and
the best early trade access in the game — river-route caravans visit Riverside starts a touch
more often. Trade-offs: buildable, farmable land is a narrow ribbon (silt rows flood in heavy
Spring Rains storms — bounded setback, never a wipe, per the cozy contract), stone and scrap
are the scarcest of the three starts, and the river edge is a long soft border to fence.

### Open Plains — the farmer's start (lean: **better soil**)

**Lore blurb.** The founders crested a rise and saw grass to the horizon — old cropland gone
wild, deep dark topsoil that the war had poisoned less than anyone dared hope. No cover, no
walls, nothing between them and the weather but distance. They settled it anyway, because
people who had spent twenty-five years hiding in ruins understood exactly what they were
looking at: land that would feed everyone they had ever lost, if someone was brave enough to
stand in the open and work it.

**Layout sketch.** The flattest and most legible of the three maps: a gentle rise at center
with the farmhouse and windmill-topped well on it, and big, clean, rectangular farm plots
spreading in all four directions — the largest contiguous plantable area of the three starts by
a wide margin. A pond in a shallow depression south-east of the rise is the map's water body
(modest — enough for the dock and fishing checklist items, no river trade). The town core sits
west of the rise along the old farm road. The perimeter fence is the map's defining burden and
its defining sight: a huge ring with nothing leaning on it, every meter built and maintained by
hand, watchtower silhouettes on the skyline. Sightlines are total — nothing approaches Open
Plains unseen, which is the map's quiet defensive compensation for having no natural walls.

**Resource lean, justified.** **Better soil**, unambiguously: highest base crop yields,
largest plots, the map built for players who come to a Stardew-like to farm. Trade-offs: wood,
stone, and scrap are all scarce on-map (everything is bought, traded, or hauled back from
expeditions — the mirror image of Forest Edge), the pond is the weakest water feature of the
three, and weather hits hardest in the open: storm and radstorm events read most dramatically
here, with shelter (eventually the personal bunker, `GDD.md` §8) mattering most.

---

## 2. The Town Core

One spatial template, shared across all three starts (see §1), sketched here as relative
positions rather than tile coordinates. The organizing idea: **the town is a ring of warmth
with one door.** Everything the cozy loop needs sits inside a closed fence line; the wasteland
is on the other side of a single main gate; and the composition should make the safe-zone
guarantee (`GDD.md` §4 — zombies cannot enter, no town-destroying events, ever) *visible* at a
glance.

**Center: the plaza.** A packed-dirt square with the **bulletin board** on its edge — the
board faces the plaza and is the first thing you see walking in from the farm, because it's the
daily quest/notice touchpoint and wants to be on the player's natural morning path. A communal
fire pit or salvaged street lamp marks the plaza's middle: the lamplight-gold anchor of the
whole palette (`GDD.md` §9), lit at dusk, the image of home.

**Flanking the plaza: the two institutions.** The **mayor's fortified house** sits on the
plaza's north side on the town's highest ground — the settlement's original strongpoint, the
building the founders raised first, visibly older and heavier than everything around it:
concrete-patched walls, shutters, a watch platform on the roof. Mayor Harlan's fortified house
is half town hall, half keep, and its silhouette says *this town was built by people who
expected trouble and outlived it*. **Marta's trading store** faces it across the plaza from
the south side — scavenged-metal awning, crates out front, the economic heart opposite the
civic one. Between them, the plaza is naturally the stage for Phase 11's festivals.

**The ring: settler homes.** Three to four **settler shacks** (Phase 4's count; grown to 6–10
homes by Phase 12) form a loose arc around the plaza's east side — patched-plank homes with
small yards, each yard a spot for schedule beats (an NPC gardening at noon, sitting out at
dusk). Deliberately imperfect and lived-in: laundry lines, rain barrels, a two-headed-chicken
coop. The Phase 12 additions (clinic, watchtower, market stalls) slot into gaps in this ring
without moving anything.

**The water edge: dock.** The town's **water body** sits against the fence line — at
Riverside it *is* the river along the western edge; at Forest Edge and Open Plains it's the
creek pool / pond tucked against the perimeter's south-east corner. The **dock** is a short
plank walk with a lantern post: fishing spot, caravan landing where the water allows it, and
the town's quiet contemplative corner — the place NPCs go in their schedules to be alone.

**The boundary: fence and gate.** The perimeter fence closes the whole composition —
scavenged planks and chain-link in mismatched, honest patches (upgradeable per Phase 8), with
**one main gate** facing the road that leads toward the ruined city, on the town side opposite
the farm. One door in and out matters mechanically (expedition departures and returns, bandit-
scout events, caravan arrivals all happen *at the gate*) and tonally: leaving for the ruins
means walking through the gate with the town at your back, and coming home means seeing the
lamplight through it. The player's farm connects to town inside the fence via a second, smaller
path — the farm-to-plaza walk is the most-traveled route in the game and stays short, safe, and
pretty. Phase 4's "small perimeter fence gap (closed later)" sits along the farm's outer edge,
as the starting farm's to-do item, never a threat vector into town.

---

## 3. The Ruined City — Concept Sketch

The nearest pre-war city, a manageable travel from the settlement (on foot early;
trivialized by the scrap buggy later, `GDD.md` §8). Phase 9 builds it as 2–3 hand-crafted
zones — **Residential Blocks**, **Downtown Ruins**, **Industrial Quarter** — and this sketch
fixes how they sit relative to each other, where the raider faction lives, and where bunkers
plausibly hide. The organizing idea: **the city is a difficulty gradient that runs inward.**
The approach road from the settlement arrives at the city's soft outer edge, and danger, loot
quality, and radiation all rise as you push toward the center.

### Zone relationships

**Residential Blocks — the outer ring, tier 1.** The first zone the approach road reaches:
suburbs and low apartment rows, split streets with grass in the cracks, the ruins at their
most legible and least lethal. Scattered infected, domestic loot (seeds, tools, preserved
food, household scrap), and the expedition tutorial arc's natural home — Scout Kael's early
guidance (Phase 5) points here first. Spatially it wraps the city's settlement-facing side, so
both deeper zones are reached *through* it: the old high street funnels north-west into
Downtown, and a rail cutting runs north-east toward Industrial. Two exits, one gradient, and
the player's first taste of choosing a route.

**Downtown Ruins — the heart, tier 3.** The city center: collapsed towers, choked plazas,
street canyons under leaning rubble. Densest infected population, richest general loot
(pre-war tech, blueprint scrolls, Credits caches in bank vaults and offices), and the worst
radiation pockets outside a sealed bunker — the zone where the rad-exposure system (`GDD.md`
§5) does its soft gating, with the hottest blocks effectively closed until the player's gear
catches up. Downtown connects back to Residential via the high street and sideways to
Industrial via the rail line; Phase 14's Vault District is conceptually *through and beneath*
Downtown — the deeper city this zone's hottest edges hint at.

**Industrial Quarter — the flank, tier 2.** Factories, warehouses, a freight yard, and a dry
canal basin along the city's north-east edge, reached by the rail cutting from Residential or
laterally from Downtown. Mid-tier danger with a distinct hazard flavor: fewer infected in the
open, nastier surprises inside the big structures, and localized radiation around leaking
industrial tanks rather than Downtown's block-wide fields. The loot lean is what the
settlement's build tree eats: bulk scrap, machine parts, chemicals, ammo components — making
Industrial the *purposeful* destination (you go there to build something) where Downtown is
the *treasure-hunting* one. It is also where the raiders live.

### Raider faction territory

The faction (`GDD.md` §6) is **concentrated in one zone with tendrils, not spread evenly**:
their stronghold is a fortified factory compound in the Industrial Quarter's freight yard —
walls of stacked containers, watch platforms, one guarded gate. A faction of dozens can
plausibly hold a defensible compound; it cannot hold a city, and the concentration gives their
reputation system a geography. Around the stronghold, the Industrial Quarter is openly *their
turf*: patrols on routes, marked totems, toll points on the rail cutting. Beyond it, tendrils
— a raider checkpoint where the rail cutting leaves Residential, ambush parties working
Downtown's richest edges — enforce their claim without owning those zones.

Reputation reads directly onto this map: **Hostile** makes Industrial a de facto combat zone
and its tendrils ambush triggers; **Wary** means warnings at the checkpoint and passage past
the compound at a price; **Tolerated → Trusted** opens the rail cutting as safe passage, the
compound gate as a barter market (`GDD.md` §7), and eventually faction jobs that send the
player into the other two zones. The player who never engages can still reach everything —
Industrial's loot doesn't require crossing the compound — but the diplomatic route is always
the shorter, safer one, which is the reputation system's whole pitch.

### Bunkers

Discoverable pre-war bunkers (`GDD.md` §8) are self-contained mini-dungeons *distinct from*
the city zones, and their placement follows who built them:

- **Backyard family bunkers** — small, sad, single-room shelters under Residential Blocks'
  suburban yards and in the wastes between city and settlement. Early-game texture: a hatch
  under debris, one room of loot and one lore note. The player's first bunker should be one of
  these, found within the first few expeditions.
- **The factory shelter** — a company blast shelter under the Industrial Quarter, its entrance
  inside or near the raider compound. Naturally entangled with the faction: reaching it cheaply
  is a reputation reward, cracking it despite them is the hostile route's compensation prize.
- **The municipal bunker** — the big one, under Downtown's civic center: multi-level, sealed,
  irradiated, infested, holding the zone's best pre-war loot and the densest lore caches about
  the war (`GDD.md` §2 keeps the history fragmentary — this is where the biggest fragments
  live). Endgame-adjacent, gated by rad-gear progression, and the natural threshold to Phase
  14's underground expansion.

The gradient, summarized: Residential teaches, Industrial supplies and negotiates, Downtown
pays and punishes, and the bunkers thread a second, vertical layer of risk under all three.
