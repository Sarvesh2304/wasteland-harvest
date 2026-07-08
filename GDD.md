# Wasteland Harvest — Game Design Document

**Status:** Living document. This is the authoritative statement of what the game *is* — its
world, tone, loops, and systems. `ROADMAP.md` remains the authoritative statement of build order
and task status; where this document expands scope beyond what `ROADMAP.md` currently says, that
is flagged explicitly in the final section rather than silently assumed.

---

## 1. High Concept

**Wasteland Harvest** is a cozy farming and settlement-building RPG in the style of Stardew
Valley, set two generations after a global nuclear war. You were born in a small survivor
settlement your parents helped found on a defensible patch of reclaimed land; when they pass
away peacefully in their old age, their farm becomes yours. By day you till irradiated-but-
recovering soil, raise chickens (some of them with two heads), befriend your neighbors, and
build the town up plank by scavenged plank. When you're ready for more, you load a salvaged
rifle with hand-pressed ammunition and ride a scrap buggy into the ruined city nearby — a
dangerous maze of feral zombies, radiation pockets, pre-war loot, and a wary human raider
faction whose opinion of you genuinely matters.

The pitch in one line: *Stardew Valley's warmth, with a wasteland outside the fence.* The
settlement layer is deliberately gentle — low-stakes, welcoming, funny, kind — while the
expedition layer supplies the danger, tension, and darkness. The player chooses their own blend
of the two, forever: there is no ending, no fail state for the town, and no clock. The story
completes; the game doesn't end.

## 2. World & Lore

### The war

Roughly half a century before the game's present day, the old world ended in a global nuclear
exchange. It was not a clean apocalypse: as the missiles flew, several combatants also released
bio-weapons — engineered plagues and mutagens meant to finish what the warheads started. The
bombs cracked the cities; the bio-agents cracked the survivors. This dual origin is
load-bearing for the game's fiction: **radiation** explains the environmental hazards, the
radstorms, the mutated crops and livestock; the **bio-weapons** explain the zombies and monsters
that infest the ruins — feral, infected things that were once people and animals, not
supernatural undead. Nobody alive in the game fully understands which weapon caused what, and
the lore layer (notes, broadcasts, posters — see ROADMAP.md Phase 13) deliberately keeps the
exact history fragmentary. The old world is a rumor the young generation grew up on.

### The founding (~25 years after the war)

The first two and a half decades after the war were the bad years — the years the older NPCs
don't like to talk about. Roaming, scavenging, losing people. Around the 25-year mark, a band
of survivors — the player's parents among them — found a small patch of land that had three
things going for it: it was defensible, it had water, and its soil was clean enough to farm.
They stopped running and dug in. That patch became **the settlement**, the game's home town.
The founding generation built the first fences, the first fields, and the first fragile trade
contacts with other pockets of survivors. Several of the town's older NPCs are founders or
early arrivals, and their personal questlines can draw on that shared history.

### The present day (~44–50 years after the war)

The player was born in the settlement in its early years and is a young adult (19–25) when the
game begins — meaning the present day sits roughly 44–50 years after the war. This timeline
placement is a deliberate tonal choice. Humanity is past mere survival and into **slow,
hopeful rebuilding**: established trade routes connect a handful of small settlements, a
functioning currency (Credits, see §7) circulates, salvaged technology is being coaxed back to
life, and a whole generation — the player's generation — has never known the old world at all.
The wasteland is still lethal in places. The ruins are still full of things that bite. But the
trajectory of the world is *upward*, and the game's fiction, dialogue, and events should
consistently reflect that. This is not a world winding down; it's a world waking up.

### Tone of the setting

Warm frontier, not grimdark. The reference feeling is a small town that happens to have a very
good fence: hardship exists and is acknowledged (NPCs have lost people; scarcity is real), but
it lives in backstory and in the ruins, not in the daily texture of town life. Humor is
allowed and encouraged — the wasteland's absurdities (a two-headed chicken, a trader who
insists bottle caps will catch on someday) are played for gentle comedy. See §9 for the full
tone/art contract.

## 3. Player Character & the Opening

### The birth/intro sequence

Character creation is framed diegetically as the player character's **birth**. A short intro
sequence (a few screens, skippable on replay) shows the settlement in its rough early years:
the parents at the newly-claimed land, the first walls going up — and then a birth in the
settlement's one-room clinic. At this moment the player chooses:

- **Name** — framed as the parents naming their child.
- **Gender** — chosen at the same point in the sequence.
- **Appearance** — *moderate* customization: a handful of preset portraits/base sprites to
  choose from, plus cosmetic adjustments (hair color, skin tone, outfit color). Explicitly
  **not** a fully modular build-your-own-character system; presets keep the sprite/portrait
  art pipeline tractable (relevant to the PixelLab-first pipeline in `CLAUDE.md`).

The intro then compresses two decades into a brief montage — glimpses of growing up as the
town grows around you — and lands on the present day: the parents have recently **passed away
peacefully, of old age, in the town they built**. No tragedy, no violence, no dark secret;
they got the ending almost nobody in their generation got, and the town remembers them fondly.
The farm and land pass to the player. Day 1 begins.

This is the game's direct answer to Stardew's inherited-farm opening, deliberately inverted:
instead of *an outsider arrives at a place they don't know*, it's *the town's own child steps
into their parents' role*. Both produce the same mechanical starting state — one person, one
run-down farm, a town full of characters to meet — but ours grounds the player in the world
from the first minute and gives the whole settlement a reason to already care about them.

### The onboarding tension (and how we resolve it)

There is an obvious narrative tension here, and we address it head-on rather than pretending
it doesn't exist: the *character* grew up in this town and knows everyone, but the *player*
knows nothing and needs a tutorial. Stardew dodges this by making the character a newcomer;
we can't, so we solve it differently, with three reinforcing devices:

1. **Inheritance as re-introduction.** The tutorial's fiction is not "learn what farming is"
   but "take over the farm." The parents let the fields go in their last years; tools are worn,
   plots are overgrown, and Mayor-figure and neighbor NPCs come by in the first days to help
   you get *the farm specifically* back on its feet. Teaching moments are framed as "your
   mother used to do it this way" and "you remember your father's trick for this" — the
   character is remembering, while the player is learning. Same content, two readings.
2. **Known faces, new relationship.** NPCs greet the player by name from day one — no "who are
   you, stranger?" dialogue anywhere in the opening. But the *relationship system* starts near
   zero anyway, and the fiction supports it: these people knew you as the kid of two beloved
   founders; they don't yet know you as an adult, a farmer, a neighbor in your own right. Early
   low-affinity dialogue is written as warm-but-surface familiarity ("You've got your mother's
   stubbornness, I'll bet") rather than stranger-talk, converging with Stardew's affinity curve
   without its stranger framing.
3. **The ruins are legitimately new.** The one thing the character genuinely does *not* know
   is the world beyond the fence — their parents' generation kept the young ones out of the
   city, full stop. So expedition onboarding (the game's second, more dangerous tutorial arc,
   delivered via the Scout NPC per ROADMAP.md Phase 5) needs no framing trick at all: the
   character is discovering the ruins for the first time right along with the player.

## 4. Core Gameplay Loop — The Settlement (Cozy-Core)

This is the game's emotional home base and its Stardew-faithful heart. The loop, on a
day-by-day scale:

**Wake → tend the farm (till / plant / water / harvest) → spend the day's energy on your
choice of activity (building, foraging, fishing, socializing, crafting, trading, or prepping
an expedition) → ship goods / sell at the store → sleep → auto-save → morning report.**

Key beats, all consistent with the systems already enumerated in `ROADMAP.md`:

- **Farming** — post-apocalyptic crop roster (Mutant Potato, Dustwheat, Ironroot, Sunbloom,
  plus seasonal additions), 4–6 visual growth stages, daily watering, energy-gated actions,
  seasonal rotation across the four seasons (Spring Rains, Scorched Summer, Amber Autumn, Grey
  Winter). Farming is the reliable economic backbone: safe, steady, scaling with investment.
- **Settlement building** — the player grows the town itself: 12+ structure types, fencing and
  perimeter, settler recruitment, NPC–building assignments, player-run businesses. The
  long-arc fantasy of the cozy side is watching the settlement your parents founded become a
  real town under your stewardship.
- **Social life** — NPC schedules, affinity, gifts, festivals, personal questlines. The full
  Stardew social register: birthdays, seasonal festivals (Harvest Day, Winter Gathering),
  slowly-earned friendships.
- **Foraging & fishing** — gathering in the safe-ish wilds around the settlement, plus the
  dock/water-body fishing minigame. (Note: mechanically, fishing is a sub-activity of the
  Foraging skill — see §8.)

**The cozy contract:** the settlement is a hard safe zone (ROADMAP.md Phase 9 already
specifies zombies cannot enter the boundary). Nothing on the settlement side should ever feel
like a survival game — no hunger meter, no town-destroying failure states, no permanent loss
of NPCs, no doom timers. Raid *events* exist (bandit scouts at the perimeter, per Phase 11)
but resolve as manageable, bounded incidents — tension as seasoning, never as dread. When the
player walks back through the gate at dusk with a full pack, the feeling should be relief and
warmth, every single time. That contrast is the entire point of the game.

## 5. The Expedition Loop — Ruins, Radiation & the Ammo Economy

This is where the darkness lives, quarantined by design. The loop, on a per-expedition scale:

**Prepare (weapons, ammo, meds, rad-protection, fuel, pack space) → travel out → explore a
zone (fight, loot, sneak, manage stamina/HP/radiation) → decide when greed becomes stupidity →
return (or die and lose the expedition's loot, respawning at the settlement at 10% HP) →
convert loot into settlement progress.**

### The ruined city

The nearest major ruin, a pre-war city a manageable travel from the settlement, split into the
zones already planned in ROADMAP.md Phase 9 — **Downtown Ruins**, **Industrial Quarter**,
**Residential Blocks** — later expanded by Phase 14's Vault District and Boneyard Markets. The
city has two kinds of inhabitants:

- **The infected** — feral zombies and mutated monsters, legacies of the war's bio-weapons.
  They are animalistic, not cunning: patrol, detect, chase, attack (per the Phase 9 AI spec).
  Their horror register is allowed to be genuinely dark — gore, body horror, tension — because
  it stays in the ruins. They are an environmental force, not a faction; you cannot negotiate
  with them.
- **The raider/scavenger faction** — living humans who hold part of the city. They are a full
  system, not set dressing; see §6.

### Combat & the ammunition economy

Decades of salvage mean **firearms are common** — most survivors own a gun, and so does the
player early on. What's scarce is **ammunition**. This single scarcity decision shapes the
whole combat economy:

- **Ammo is a first-class resource loop.** Crafted at the Workshop (ROADMAP.md Phase 10
  already lists Ammunition as a crafting output), looted in the ruins, traded at real cost.
  Components (casings, powder, scrap lead) are themselves loot/trade goods. A player can run
  an "ammo business" — pressing rounds for Credits — as a legitimate economic specialty.
- **Melee stays relevant forever.** Not a starter weapon class you graduate out of: swinging a
  machete at a lone shambler *to save the bullet* is correct play at every stage of the game.
  Guns are for when things go wrong, when they come in packs, or when they're armored.
- Every trigger pull should carry a tiny economic flinch. Spraying rounds at trash enemies is
  how you go home poor.

This confirms and extends ROADMAP.md Phase 9's melee + ranged combat spec (player HP,
knockback, hit flash, expedition-loot death penalty all stand as written).

### Radiation

Radiation is a **real, persistent expedition hazard**, not lore flavor:

- Certain zones (and sub-areas within zones) are irradiated; some loot is too — a hot salvage
  find is a genuine dilemma, not a free pickup.
- The player has a tracked **radiation exposure** meter alongside HP and stamina.
  Accumulating exposure degrades the expedition (reduced stamina/HP ceiling as it climbs)
  and, unmanaged, forces retreat or worse.
- Counterplay comes in two flavors: **gear** (scavenged hazmat scraps early, proper suits
  later — crafted/upgraded like tools) and **consumables** (purifier meds — the setting's
  Rad-Away equivalent, craftable at the Clinic/Workshop and a valuable trade good).
- Radiation gives the **radstorm** weather event (already in ROADMAP.md Phase 11) real teeth:
  a radstorm is not just "don't go outside" flavor text — getting caught in the open during one
  inflicts fast, serious exposure. Shelter matters; the personal bunker (§8) is the premium
  answer.
- Rad-protection is soft progression gating: deeper, hotter zones (and some bunkers) are
  effectively locked until the player's gear can handle them, without needing literal locked
  doors.

## 6. The Raider Faction & Reputation System

A rival human faction — raiders-turned-scavengers — controls a portion of the ruined city.
They are the game's most morally textured content: not monsters, not friends, but people who
took the other path after the war and are not sorry about it. They deal in barter, respect
strength and consistency, and have long memories.

**The player's standing with the faction is a fully tracked reputation system** that
materially changes world state:

- **Hostile (low rep):** faction patrols in the city attack on sight; faction ambush events
  can trigger on expeditions; their turf is effectively an extra combat zone.
- **Wary (neutral band):** live-and-let-live. Patrols warn rather than attack; a fringe
  trader or two will deal with the player (barter only, poor rates); faction turf is passable
  but tense.
- **Tolerated → Trusted (high rep):** access to faction traders with unique stock (ammo
  components, weapon mods, intel on loot locations), faction-given quests, safe passage
  through their territory, and eventually a **wary alliance** — never warm, never a
  friendship system like the town's affinity, but a real strategic relationship (e.g. they
  stop raiding the region's caravans, or tip you off before a raid event).

Reputation moves through actions, not dialogue checkboxes: killing faction members tanks it;
trading fairly, completing their jobs, and honoring agreements builds it slowly; some main-
story and town-quest choices push it either way. It should be recoverable but slow —
rebuilding trust with people who shoot first is supposed to take a while.

Design intent: the faction gives expeditions a *diplomatic* axis in a layer of the game that
is otherwise purely physical, and it lets the player express a stance (exterminate, avoid, or
engage) that the world visibly remembers. It is deliberately quarantined from the cozy side —
faction reputation is a *city/world* system and never threatens the settlement's safe-zone
guarantee.

> **Scope note:** this is a larger system than ROADMAP.md Phase 9 currently describes (Phase 9
> mentions only zombie/monster AI). Flagged in §11.

## 7. The Wider World — Settlements, Trade & Two Currencies

The home settlement is not alone. A few other small human settlements exist within reachable
range, connected by **established trade routes** — the physical evidence that the world is
rebuilding. Early game, they exist as the source of caravan traders (ROADMAP.md Phase 10) and
as dialogue/lore; as the player unlocks vehicles and the world map (Phase 14's map screen and
fast travel), they become visitable destinations with their own merchants, goods
specialties, and quest hooks. They are *small* — trading posts with personalities, not
additional full towns to maintain; the home settlement remains the game's one deep social hub.

**Two economies coexist, by design:**

- **Credits** — the established currency of settled humanity. Trade routes run on it, the town
  store prices in it, settlers are paid in it. Its existence is itself a piece of
  worldbuilding: functioning currency means functioning trust between settlements. Credits are
  the player's primary money and the unit for all standard economy systems (store, shipping
  box, businesses, supply & demand pricing).
- **Barter** — Credits are *not* universally accepted. The raider faction, independent
  scavengers, and some remote traders deal only in goods-for-goods. Barter partners value
  goods idiosyncratically (the faction overvalues ammo components and meds; a remote
  settlement might overvalue seeds), which creates arbitrage play for traveling traders and
  makes "what do I carry out there?" a real loadout question, parallel to weapons and rad-gear.

## 8. Systems Summary

Cross-reference summary of the remaining major systems. Where a system already appears in
`ROADMAP.md`, this section refines it; where it's new detail, it slots into the existing
phase structure without changing build order.

### Vehicles

Modest, deliberate scope — three tiers, each craftable and upgradeable, with **fuel** as a
managed resource (scavenged and, later, crafted/refined):

1. **Bike** — cheap, no fuel or minimal fuel, faster overland travel, tiny cargo.
2. **Scrap buggy** — the workhorse: real cargo capacity for loot runs, fuel-hungry, unlocks
   comfortable travel to the city and nearer settlements.
3. **Truck (one tier)** — late-game hauling: bulk trade runs between settlements, big
   expedition hauls.

Explicitly **not** in scope: deep vehicle-part customization, vehicle combat, or a vehicle-
building minigame. Vehicles are travel-and-cargo utility with an upgrade ladder, nothing more.

### Bunkers (two distinct meanings, both in scope)

- **Discoverable pre-war bunkers** — self-contained mini-dungeon locations scattered across
  the wasteland, *distinct from the ruined-city zones*: sealed, claustrophobic, often
  irradiated or infested, with unique pre-war loot (blueprint scrolls, legendary items, lore
  caches). These give the overworld exploration texture beyond the city and pair naturally
  with ROADMAP.md Phase 14's underground/bunker areas.
- **The player-buildable personal bunker** — a late-tier settlement structure serving three
  roles: **deep storage**, **radstorm shelter** (the definitive answer to the weather event),
  and **panic room** during raid events. A capstone of the building tree and a cozy-side
  expression of the setting's fiction.

### Animals & pets

A yield-vs-hardiness axis runs through all livestock:

- **Normal (pre-war-line) animals** — cows, chickens, plus dogs and cats as pets — exist, are
  **valuable and somewhat rare** (clean breeding stock is a prized trade good), produce
  premium goods, but are fragile: more care, more sensitivity to neglect and events.
- **Mutated variants** — radiated goats, mutant chickens, and kin — are common, cheap, and
  extremely hardy (shrug off radstorms, forgive missed care days) but yield stranger,
  lower-value produce.

The player's barn composition is therefore a real strategic choice, not a cosmetic one — and
mixed herds are the natural middle path. Mutant animals are written cute-weird, not
horrifying: they live on the cozy side of the tonal line.

### Skills & progression

Five skills, adapted from Stardew's proven five-skill model — XP per action, level-ups on a
curve, perk choices at milestone levels (following Stardew's pick-a-profession feel):

| Skill | Covers | Notes vs. Stardew |
|---|---|---|
| **Farming** | Crops, animals | Direct analogue |
| **Combat** | Melee & ranged, expedition survival | Direct analogue |
| **Scavenging** | Ruin/city exploration, salvage, loot yields, bunker-cracking | *Replaces Mining* — salvage is this world's mining |
| **Foraging** | Wild gathering, wood, **and fishing as a sub-activity** | Absorbs fishing; no separate fishing skill |
| **Crafting** | Ammo pressing, building materials, item crafting, workshop recipes | *New* — elevates the crafting/ammo loop to a first-class progression track |

Perks should reinforce playstyle identity: a Scavenging tree that makes ruins pay better, a
Crafting tree that makes the ammo business hum, a Foraging tree split between wilds and water.

### Building

As specified in ROADMAP.md Phases 4/8 (grid-snap placement, resource costs, construction
time, 12+ structure library, fencing/perimeter, settler assignment), extended by the personal
bunker above as a late-tier addition to the structure library.

## 9. Tone & Art Direction

**The one-sentence contract: cozy-core with a post-apocalyptic reskin.** The settlement,
farming, and social layers must hit Stardew Valley's actual emotional register — warm,
gentle, low-stakes, quietly funny — and the post-apocalyptic setting is a *skin and a story*
on that warmth, never a survival-genre pivot. Darkness (gore, real danger, horror-adjacent
tension) is permitted and welcome **only** in the expedition/city/bunker content, and even
there it serves contrast: the ruins exist so that coming home feels like coming home.

Practical rules of thumb for all content writing and art direction:

- If a feature makes the *town* feel unsafe, anxious, or grim, it's wrong — cut it or move it
  beyond the fence.
- NPC writing default: people who have chosen hope and are a little funny about it. Grief and
  loss exist in backstory and questlines, handled with warmth.
- Gore assets (the shared-assets repo's `gore-tile-styles/` may apply) belong to ruins,
  bunkers, and combat only — never town tiles or town events.
- Mutant flora/fauna on the cozy side reads *charming-weird* (a chicken with two heads is a
  town mascot); on the expedition side it may read *wrong* (that is what the bio-weapons did).

**Visual direction:** top-down 2D pixel art on a plain axis-aligned grid (per `CLAUDE.md` —
Stardew's true projection, explicitly not isometric). Palette anchored in **post-apocalyptic
dusty ambers and faded greens** (per `CLAUDE.md`; concrete hex values locked in Phase 1's
art-style pass alongside the tile-size decision — see the concrete palette below). The palette
splits by layer:
the settlement leans into the warm end — golden-hour ambers, living greens, lamplight — while
city/ruin zones desaturate toward greys, rust, and sickly green rad-glow accents, so the two
halves of the game are tonally legible at a glance. UI carries the scavenged-metal /
worn-paper theme already specified in ROADMAP.md Phases 2 and 16. Seasonal palettes (Phase 11)
modulate the warm base rather than replacing it.

### Concrete palette (locked — Phase 1 art-style pass; revised Phase 3)

The hex values below are the locked outcome of Phase 1's art-style pass, decided alongside the
**16×16 px tile size** (Stardew Valley's actual base tile size, confirmed with Sarvesh). Three
layers: a settlement anchor palette that never changes, a small seasonal modulation set layered
over it, and a separate ruins palette for expedition content.

**Revision note (Phase 3, same day as first playable Phase 3 build):** after seeing the game
actually running, the original Phase 1 hex values read as too dull/muted rather than "moody but
cozy" — the intended post-apocalyptic contrast with Stardew's vibrancy had overshot into
drabness. Sarvesh asked to fix it rather than defer to Phase 6 polish, since Phase 4+ would
otherwise generate a lot more art against colors that needed revising anyway. Every settlement-
anchor and seasonal hex below was boosted by a uniform HSV transform (saturation ×1.30, value
×1.12, hue untouched — so the identity colors are the same *hues*, just less washed-out) and
applied both to this table and to every already-generated settlement-side art asset (Phase 1's
grass/soil tileset, Phase 2's player character and HUD, Phase 3's crop/item art) via a batch
script rather than expensive full PixelLab regeneration. **The ruins palette below is
deliberately excluded from this boost** — its desaturation vs. the settlement's warmth is the
intentional "alive vs. stopped" contrast (see its own section below), and staying dull is the
point there.

#### Settlement anchor palette (year-round "home" tones)

These are the colors that make the settlement read as *home* in every season. Structures, tools,
lamplight, and UI are built from this set and are deliberately **not** seasonally modulated —
whatever the season does to the fields, the town's wood, metal, and window-glow stay constant,
so walking back through the gate always looks like the same warm place.

| Role | Hex | Used for |
|---|---|---|
| Dusty amber (identity color) | `#e1982a` | The game's signature tone — dry grass, thatch, dust, sun-warmed surfaces |
| Lamplight gold | `#ffc948` | Window glow, lanterns, UI highlights, festival lights |
| Worn cream | `#ffedb1` | Worn-paper UI, plaster walls, daylight highlights |
| Faded field green | `#95ac49` | Living crops and grass — the "faded green" of the source palette |
| Deep leaf green | `#5d7d3a` | Tree canopies, shadowed foliage, mature crops |
| Worn wood (light) | `#b77c3e` | Planks, fences, dock boards |
| Worn wood (dark) | `#7b5025` | Beams, door frames, shadowed wood |
| Tilled soil | `#895a2e` | Farm plots, dirt paths |
| Scavenged metal | `#9d9180` | Corrugated roofs, tools, patched walls |
| Warm outline / deep shadow | `#281a0b` | Sprite outlines and darkest shadow — warm near-black, never pure `#000000` |

#### Seasonal modulation of the settlement palette

Stardew Valley re-tints its world season to season, and Wasteland Harvest carries that mechanic
over directly (per Sarvesh): each season swaps the *organic* layer — grass, foliage, crops, soil
moisture — to a small seasonal set, plus a subtle global tint, while the anchor palette above
holds still. Implementation intent for later phases: seasonal ground/foliage tile variants plus
a light `CanvasModulate` grade, not four full re-draws of the world.

**Spring Rains** — the wet season washes the dust off the wasteland; for a few weeks the world
is cooler, damper, and greener than the game's amber identity, which makes the return of that
amber in summer land harder. Fresh cool greens, rain-grey skies, and a few soft blossom tones
on the mutant fruit trees.

| Role | Hex |
|---|---|
| Fresh rain-fed green | `#6cb34d` |
| Damp moss green | `#488c55` |
| Wet soil (dark, rich) | `#6a4626` |
| Rain-sky blue-grey | `#7fa1b7` |
| Mutant blossom pink | `#f3acb7` |

**Scorched Summer** — the palette's hottest and most sun-bleached point, and deliberately the
*opposite* of Stardew's lush green summer: the season is named "Scorched," and this is a
half-century-poisoned sky over dry land. Summer is when the game leans hardest into its core
dusty-amber identity — greens dry to straw, earth bakes pale, and the light itself goes hazy
and over-bright.

| Role | Hex |
|---|---|
| Bleached amber | `#f3b751` |
| Heat-haze cream | `#ffe494` |
| Sun-scorched straw green | `#bca843` |
| Baked earth | `#af6d2c` |
| Washed haze sky | `#e8d6a6` |

**Amber Autumn** — the anchor palette at full song; the season is literally named for the
game's identity color, and this is its peak expression. Deepest saturation of the year:
harvest golds, rust-leaf oranges, and ember browns. If a single screenshot has to sell the
game, it's taken in Amber Autumn.

| Role | Hex |
|---|---|
| Peak amber | `#e88b0f` |
| Harvest gold | `#ffb72d` |
| Rust-leaf orange | `#c5520f` |
| Ember red-brown | `#a03c13` |
| Last fading green | `#8c8832` |

**Grey Winter** — named "Grey," and it delivers: the organic layer desaturates toward cool
ash-greys and cold blue tones, a quiet visual echo of nuclear winter that stays on the right
side of the cozy contract because the anchor palette's lamplight gold (`#ffc948`) is *not*
modulated — warm windows against grey snow is the season's whole look, and it's the strongest
"home versus wasteland" contrast of the year.

| Role | Hex |
|---|---|
| Snow-ash white | `#e0e4e3` |
| Cold blue-grey | `#92a5b7` |
| Frozen ground | `#686458` |
| Dead-branch brown | `#78634c` |
| Winter-sky slate | `#4b5c6c` |

#### Ruins (expedition) palette

Desaturated concrete, rust, and ash, with the sickly rad-glow green reserved as a pure accent —
it should be rare enough on screen that it always means *hazard* (irradiated pockets, mutant
growths, glowing loot). Where gore appears (ruins/bunkers/combat only, per the tone rules
above), it uses the shared-assets blood rule (`#9b1818` / `#c43020` / `#e84030`) rather than
new colors.

| Role | Hex | Used for |
|---|---|---|
| Concrete grey (light) | `#6f6f68` | Broken streets, building faces |
| Concrete grey (dark) | `#4a4a44` | Interiors, shadow sides, rubble cores |
| Ash brown | `#5c5347` | Burnt timber, dead ground, debris |
| Rust (dull) | `#7d452a` | Corroded vehicles, rebar, pipes |
| Rust (bright) | `#a65c30` | Fresh rust streaks, warning-paint remnants |
| Faded signage cream | `#b5a98c` | Pre-war posters, road markings, bone |
| Rad-glow green (accent) | `#86e83e` | Radiation pockets, mutant growth, hot loot — accent only |
| Rad-glow deep | `#3fa832` | Rad-glow falloff, irradiated water |
| Cold outline / shadow | `#181a16` | Ruins sprite outlines — a *cold* near-black, vs. the settlement's warm `#281a0b` |

**Ruins get no seasonal palette modulation — decided, not deferred.** The ruins are dead ground:
nothing grows there to green in spring or turn in autumn, and a city that ignores the seasons
while the settlement moves through them is itself worldbuilding — it reinforces at a glance that
one place is alive and the other stopped. It also keeps art scope sane (no four-season variants
of every ruin tile). Two cheap, purely atmospheric exceptions are allowed via global tint and
weather overlays only (no per-season tile art): a thin snow-dust overlay in Grey Winter, and a
darker wet-sheen grade during Spring Rains — the sky still happens to the ruins, even if nothing
answers it.

## 10. Win / Lose Conditions

**There is no win condition, and that is a design decision, not an omission.** Wasteland
Harvest is an endless sandbox in exactly Stardew Valley's mold:

- The **main story arc** (ROADMAP.md Phase 13 — including the rebuild-vs-push-further
  decision) and all **NPC personal questlines** are *completable content threads*, not a game
  ending. Finishing the main arc changes world state and dialogue and delivers narrative
  closure, but the game continues indefinitely afterward — farming, building, relationships,
  expeditions, festivals, seasons, all of it — precisely like Stardew's post-Community-Center
  loop. The Phase 13 note "no single ending" stands; more precisely, there is no *forced*
  ending at all.
- **No global lose condition.** The settlement cannot be destroyed, the story cannot be
  failed, and there are no doom timers. Loss is local and bounded: dying on an expedition
  loses that expedition's loot (the Phase 9 roguelike penalty), passing out at zero energy
  loses the rest of the day, a neglected crop dies. Setbacks, never game-overs.
- Long-tail goals substitute for a win screen: the achievement set (Phase 17), legendary
  items and endgame zones (Phase 14), maxed skills and relationships, the fully built-out
  settlement, and raider-faction alliance status.

## 11. Scope-Addition Flags (reconciled into ROADMAP.md — kept here for design rationale)

**Reconciled** into `ROADMAP.md` Phases 5/9/10/14 as of Phase 1's close-out. The flags below are
kept for the design reasoning behind those additions, not as an open to-do list — don't treat
them as pending work.

The following design decisions in this GDD **exceeded what `ROADMAP.md` had written at the time
this GDD was drafted**. They were firm decisions (from Sarvesh's design Q&A), recorded here so
they could be reconciled into the roadmap's phase checklists — which has since happened.

1. **Raider/scavenger faction with a full reputation system (§6).** ROADMAP.md Phase 9
   currently describes the ruined city's inhabitants as zombies/monsters only. The GDD adds a
   human faction occupying part of the city with tracked reputation that materially affects
   world state: aggression level, barter-trader access, faction quests, safe passage, and a
   possible wary-alliance end state. This needs new checklist items (likely Phase 9 for the
   faction's presence/hostility and Phase 10/13 for its trade and quest integration) and is a
   genuinely larger build than Phase 9's original text implied — see Phase 9/10's "added per
   GDD.md §6/§11" items, now checklisted.
2. **Additional small settlements in the wider world (§7).** ROADMAP.md's text at the time
   covered only the home settlement plus the ruined city (Phase 14 adds more *city* zones). The
   GDD adds a few other small human settlements reachable via trade routes and, later, player
   vehicles — visitable trading destinations with their own merchants and quest hooks. Reconciled
   into Phase 14 (world map / expanded world), alongside vehicle unlocks.

**Minor naming reconciliation, already done:** ROADMAP.md Phase 5 now names the currency
**"Credits"** (with barter as the parallel non-currency economy), matching this GDD's §7
decision — the earlier "Scrap Coins" draft wording is gone.
