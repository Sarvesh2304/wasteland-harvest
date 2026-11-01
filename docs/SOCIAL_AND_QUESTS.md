# Social life, requests and Town Works — design + data contracts (Milestone B, 2026-10-08)

This is the spec for the second half of Milestone B ("A reason to come back tomorrow"):
- context dialogue;
- gifts and hearts;
- three new named NPCs;
- daily notice-board requests;
- the "Rebuild the Settlement" project line (**Town Works**);
- the journal;
- the weather forecast.

The data files below are hand-edited JSON. The engine code (`scripts/dialogue_db.gd`,
`scripts/gift_db.gd`, `scripts/quests.gd`, `scripts/affinity.gd`, …) reads exactly these
shapes. If you change a shape, change this document in the same commit.

Tone: `GDD.md` §2 and §9 apply to every line: "people who have chosen hope and are a little
funny about it".

**Text rule (enforced by tests).** The UI font (`art/ui/fonts/wasteland_harvest_ui.ttf`) has these
glyphs only:

```
 !"'()+,-./0123456789:;?ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz–—‘’“”…↑↓←→%♥♡
```

No `& # * = < > [ ] $ @ _`, and no accented letters. Write "and", not "&".

---

## 1. Who lives here

GDD §3 sets the frame: **known faces, new relationship.** The player was born in this
settlement. Everyone has known them since they were small, and their parents (founders, beloved,
recently passed of old age) are remembered warmly.
- **No stranger framing.** Never "who are you?", "new face" or "the new farmer".
- **Early lines are warm but surface-level.** "You've got your mother's stubbornness, I'll bet."
- **Hearts start near zero anyway.** They knew you as the founders' kid. They don't yet know you
  as an adult neighbour.
- **The player has no name in the data yet** (naming comes in Milestone E). Address them as
  "you", or use a nickname the speaker would use: "kid", "farmer", "seedling".

| id | Name | Personality tag | Lives | Role |
|---|---|---|---|---|
| `mayor_harlan` | Mayor Harlan | Optimistic Builder | town, the big house | Runs the Town Works list on the notice board. |
| `marta` | Marta | Pragmatic Trader | town, the store | Seeds and staples; buys your goods. |
| `scout_kael` | Scout Kael | Paranoid Survivor | town, south lane | Drives the truck to the ruins. |
| `rancher_silas` | Silas | Gentle Medic | the ranch | Livestock. |
| `brask` | Brask | Gruff Soldier | town, west gate | **New.** Wall warden; wants the watchtower rebuilt. |
| `wren` | Wren | Secretive Scavenger | town, east by the fire pit | **New.** The player's childhood friend; scavenges the ruins. |
| `doc_ama` | Doc Ama | Gentle Medic | town, south-west | **New.** The town doctor; the clinic is a Town Works project. |

New NPC sketches (writers flesh these out; artists draw them):
- **Brask** — sixties, ex-militia, built the first fence beside the player's father. He walks the
  wall every dawn.
  - Few words, all of them blunt.
  - Secretly carves little wooden animals for the town's kids.
  - The old north watchtower burned in a storm years back, and he still counts it as his
    failure.
  - Look: grey crew cut, a scar through one eyebrow, an olive drab long coat, a cudgel on his
    belt.
- **Wren** — the player's age; they grew up sneaking to the fence together.
  - Goes into the ruins alone, against everyone's advice, and comes back with odd things.
  - Speaks in hints and half-answers, and knows things she shouldn't.
  - Teases the lore hooks in `data/lore_notes.json` (the Northgate Company, the seed vault)
    without explaining them.
  - Look: auburn hair under a patched hood, goggles pushed up on her forehead, a scarf, a
    satchel, fingerless gloves.
- **Doc Ama** — fifties. She delivered the player in the one-room clinic: "you came out yelling
  and haven't stopped."
  - The clinic roof caved in two winters ago; she works out of a tent beside it until it's
    rebuilt.
  - Dry wit; nags about vegetables, sleep and radiation: "come see me if you start to glow".
  - Look: dark hair with grey streaks in a bun, round glasses, a long off-white coat, a red
    armband, a satchel.

## 2. Hearts (affinity) — `scripts/affinity.gd`

**Scale.** Friendship is stored as points, 0–2500, with 250 points to a heart (Stardew's scale).
- `value_for(npc)` returns whole hearts (0–10).
- Dialogue tiers are by hearts: stranger 0–1, acquaintance 2–4, friend 5–7, close 8–10.
- There is no decay.

| Event | Points |
|---|---|
| First conversation of the day | +20 |
| Gift: loved / liked / neutral | +80 / +45 / +20 |
| Gift: disliked / hated | −20 / −40 |
| Gift on their birthday | ×5 |
| Completing their notice-board request | +150 |

**Gift limits.**
- One gift per NPC per day, and two per NPC per week (Mon–Sun).
- A birthday gift doesn't count toward the weekly two.

**Giftable items.** Types `crop`, `food`, `forage`, `medicine` and `resource`, except
`fertilizer` and `quality_fertilizer`. Seeds, tools, weapons, ammo, placeables, equipment and
quest items are never offered.

**Discovery.** Once you've given an item, its reaction is remembered and shown in the PEOPLE
tab.

## 3. Dialogue — `data/dialogue.json` (v2)

One entry per NPC id:

```jsonc
"marta": {
  "name": "Marta",
  "personality": "Pragmatic Trader",
  "birthday": {"season": "summer", "day": 9},
  "start": "greet",            // the FIRST conversation ever: the intro tree in "nodes"
  "service": "shop",           // optional: node shown after the daily line in later talks
  "service_when": {"flag": "project_clinic"},   // optional condition on the service node
  "lines": [ /* daily lines, see below */ ],
  "repeat": [ "short line for a second chat the same day", "..." ],
  "gift": {
    "loved": ["Oh! {item}? You remembered.", "..."],
    "liked": ["..."], "neutral": ["..."], "disliked": ["..."], "hated": ["..."],
    "birthday": ["..."],       // a birthday gift that isn't loved
    "birthday_loved": ["..."], // a loved birthday gift
    "already_today": ["..."]   // not shown today; reserved
  },
  "nodes": { "greet": {"text": "...", "next": "stocktake"}, "...": {} }
}
```

**How a conversation runs.**
1. **The first conversation ever** plays the `start` intro tree, exactly as the old dialogue did.
2. **Every later conversation:**
   1. The **daily line**: one line per NPC per day, picked from `lines` by context. A second
      chat the same day picks from `repeat` instead.
   2. If you're holding a giftable item and haven't given this NPC a gift today, the line
      offers "Give the {item}" / "Not today". Giving shows a `gift` reaction line.
   3. Then the `service` node, if any (and its `service_when` holds), else the conversation
      ends.
3. **A request delivery replaces the daily line.** If you're carrying everything an active
   request from this NPC asks for, they thank you with the request's `thanks` line and the
   reward is paid.

**Daily lines.**

```jsonc
{"text": "Rain again. Good for your radishes, bad for my roof.", "when": {"weather": "rain"}},
{"text": "...", "when": {"season": "winter", "time": "morning"}},
{"text": "...", "when": {"tier": "friend"}},
{"text": "...", "when": {"flag": "project_clinic_new"}, "priority": 5},
{"id": "harlan_first_snow", "text": "...", "when": {"weather": "snow"}, "once": true}
```

`when` keys (all optional; every key present must match):

| key | values |
|---|---|
| `season` | `spring` `summer` `autumn` `winter` |
| `weather` | `clear` `rain` `storm` `snow` `radstorm` |
| `time` | `morning` (6:00–11:59), `afternoon` (12:00–16:59), `evening` (17:00–20:59), `night` (21:00–2:00) |
| `weekday` | `Mon` `Tue` `Wed` `Thu` `Fri` `Sat` `Sun` |
| `tier` | minimum tier: `acquaintance` `friend` `close` |
| `tier_max` | maximum tier: `stranger` `acquaintance` `friend` |
| `flag` | one world flag (below) that must be true |
| `not_flag` | one world flag that must be false |

World flags:

| flag | true when |
|---|---|
| `first_week` | days 1–7 of year 1 |
| `after_day_28` | Harlan's Day-28 food-shortage talk has happened |
| `expedition_today` | an expedition ended today or last night |
| `died_recently` | Kael carried the player home in the last 2 days |
| `veteran` | 5 or more expeditions |
| `reached_downtown` / `reached_industrial` / `reached_core` | deepest depth ≥ 2 / 3 / 4 |
| `raiders_hostile` / `raiders_trusted` | raider standing is Hostile / Trusted |
| `player_hurt` | HP under 40% |
| `player_irradiated` | 100 rads or more |
| `rich` | 3000 Cr or more on hand |
| `has_animals` | the player owns livestock |
| `has_settlers` | at least one settler has moved in |
| `birthday` | today is **this** NPC's birthday |
| `project_<id>` | that Town Works project is complete (e.g. `project_clinic`) |
| `project_<id>_new` | …and it was completed in the last 3 days |
| `has_request_<npc_id>` | you hold an active request from that NPC |

**Picking a line.**
1. Keep the lines whose `when` all match, dropping `once` lines already seen.
2. If any of them has a `priority` above 0, keep only the highest-priority ones.
3. Otherwise each line is weighted 1 + 2 × (number of `when` keys), so specific lines are
   likelier.
4. The pick is seeded by (npc, day). The NPC says the same line all day, and a reload doesn't
   change it.

**Tokens in text:**
- `{item}`: the item's name, in gift lines.
- `{season}`: e.g. "Spring Rains".

**Content targets (per NPC).**
- At least 18 daily lines:
  - 6 or more generic (no `when`);
  - at least one per season;
  - the weathers that suit the character;
  - 2 or 3 times of day;
  - 2 each at `acquaintance`, `friend` and `close`, deepening personal history: the close lines
    hint at a personal struggle a future questline resolves;
  - 1 for their `birthday` flag at priority 10;
  - the flags that suit them, e.g. Doc on `player_hurt`, `died_recently` and
    `player_irradiated`, Kael on `expedition_today`, and each project's NPC on
    `project_<id>_new` at priority 5.
- 3–4 `repeat` lines.
- Gift lines: 2 loved, 2 liked, 1–2 neutral, 1–2 disliked, 1–2 hated, 1 `birthday`, 1
  `birthday_loved`.
- **Line length:** keep each `text` at 200 characters or fewer; the box fits about 3 lines.

**Constraints.**
- **Intro trees keep their shape.** The four existing intro trees keep their node ids and
  structure, because `tools/runtime_smoke.gd` drives them by id:
  - Harlan: `greet → founding → offer` (2 choices → `offer_yes` / `offer_no`), plus
    `day_28_food_shortage → day_28_food_shortage_farm`.
  - Marta: `greet → stocktake` (choice 0 = `OPEN_STORE`, choice 1 = `chicken`).
  - Kael: `greet → city → ask` (2 choices → `inside` / `danger`).
  - Silas: `greet → stock → offer` (choice 0 = `OPEN_RANCH_STORE`, choice 1 = `look`); and
    `not_yet` must still mention a barn or coop.
- **Their wording is free to change**, and should change to fix the stranger framing (Harlan's
  "the new farmer", Kael's "new face").
- **Every NPC has one choice branch:** at least one node with 2+ choices.
- **Service nodes:**
  - Marta: `shop` (choice 0 → `OPEN_STORE`).
  - Silas: his own id (`pens`; `stock` is taken by his intro tree), choice 0 → `OPEN_RANCH_STORE`.
  - Doc Ama: `clinic` (with `"service_when": {"flag": "project_clinic"}`). Choice 0 →
    `CLINIC_HEAL` ("Patch me up"); choice 1 → `OPEN_CLINIC_STORE`; choice 2 → a goodbye line.
  - The others have no service.

## 4. Gift preferences — `data/gifts.json`

```jsonc
{
  "universal": {"loved": ["prewar_relic"], "liked": ["..."], "disliked": ["..."], "hated": ["..."]},
  "npcs": {
    "marta": {"loved": ["..."], "liked": ["..."], "disliked": ["..."], "hated": ["..."]}
  }
}
```

- **Precedence:** the NPC's own lists first, then the universal lists, else neutral.
- **Item ids** must be real (`data/items.json`) and giftable (§2).
- **Per NPC:** 3–5 loved, 5–8 liked, 2–4 disliked, 1–3 hated.
- **Make it characterful:**
  - Doc loves Cleanleaf Kale and hates Rotgut.
  - Brask loves Mystery Jerky.
  - Wren loves the odd ruins finds (Circuit Board, Rad Crystal).
  - Silas loves Mutant Goat Milk.
  - Marta loves Bottle Caps, ironically.

## 5. Notice-board requests — `data/requests.json`

The board in the town square posts one request a morning (if none is posted). You accept it
there, and it's due two days later. You can hold one request at a time.

```jsonc
{"templates": [
  {"id": "marta_shelf", "npc": "marta", "kind": "deliver", "pool": "crop", "count": [3, 6],
   "min_day": 1, "title": "Shelf Filler",
   "text": "Marta's shelf is looking thin. Bring her {count} {item} by {due}.",
   "thanks": "Oh, these will be gone by lunch. Here, as promised — and thank you."},
  {"id": "brask_hunt", "npc": "brask", "kind": "hunt", "enemy": "shambler", "count": [3, 5],
   "min_runs": 1, "title": "Thin the Herd",
   "text": "Brask wants {count} shamblers put down in the ruins. Report back by {due}.",
   "thanks": "Good. Fewer of them, more of us."}
]}
```

**Request kinds.**
- `kind: "deliver"`: needs `pool` or `items` (a list of item ids). Pools:
  - `crop`: crops in season;
  - `forage`: forage in season;
  - `material`: wood, stone, fiber, hardwood;
  - `salvage`: copper wire, plastic, rubber, cloth scrap, glass, battery, scrap metal;
  - `cooked`: the cooked dishes;
  - `artisan`: jam, pickles, cheese, honey, wine, charcoal, metal bars.
- `kind: "hunt"`: `enemy` is one of `shambler` `runner` `bloater` `rad_hound`, or `any`; optional `min_depth` (deepest district reached) holds back hunts for things that live deeper. Hunts
  never target raiders.

**Gating.** Optional `min_day` (absolute day), `min_runs` (expeditions so far) and `season` (only
posted in that season).

**Tokens.**
- `{count}` and `{item}` (pluralised name) appear in `text`.
- `{due}` is the weekday it's due, e.g. "Thursday".
- `{npc}` is the requester's name.

**Rewards (computed, not authored).**
- Deliveries pay 3× the items' sell value (at least 30 Cr). Hunts pay 35 Cr a kill.
- Either way, +150 friendship points with the requester.

**Content target:** 2–4 templates per NPC (about 20 in all), every NPC represented.
- Salvage requests go to Kael, Wren and Brask, with `min_runs: 1`.
- Food requests go to Marta, Harlan and Doc.
- Material requests go to Harlan and Brask.
- Hunts go to Brask and Kael, with `min_runs: 1`.

## 6. Town Works — `data/projects.json`

Harlan's list of what the town needs rebuilt. It's posted on the notice board, and progress shows
in the journal.
- **Contributing.** At the board, "Contribute" moves whatever you're carrying of the needed items
  into the project, plus Credits up to what's still owed.
- **Building.** Once everything is in, it's built overnight. The next morning the town looks
  different, a notice explains the reward, and `project_<id>_new` lines play for three days.

| id | Name | Who cares | Needs | Cr | Reward | Visible change |
|---|---|---|---|---|---|---|
| `shop_expansion` | Marta's New Shopfront | marta | wood 50, stone 30, fiber 20 | 400 | Marta pays 10% more for everything you ship. | The store gets a bigger shopfront. |
| `clinic` | The Clinic Roof | doc_ama | wood 40, stone 40, glass 6, cloth_scrap 10, copper_wire 3 | 600 | The clinic reopens: Doc heals you (HP and rads) for 80 Cr and sells medical supplies. | The ruined clinic is rebuilt. |
| `watchtower` | The West Watchtower | brask | hardwood 20, scrap_metal 40, metal_bar 6, rubber 4 | 800 | Kael can drive you straight to any district you've reached. | A watchtower by the west gate, lit at night. |
| `greenhouse` | The Farm Greenhouse | mayor_harlan | wood 60, glass 24, metal_bar 10, circuit_board 2, battery 2 | 1500 | A glass greenhouse on your farm where any crop grows in any season. | A greenhouse beside your farmhouse. |

```jsonc
{"projects": [
  {"id": "clinic", "name": "The Clinic Roof", "npc": "doc_ama",
   "needs": {"wood": 40, "stone": 40, "glass": 6, "cloth_scrap": 10, "copper_wire": 3}, "credits": 600,
   "summary": "One or two sentences on the board: why the town needs it.",
   "reward": "One sentence: what you get.",
   "done": "The morning-after notice when it's finished (2-3 sentences, Harlan's voice)."}
]}
```

## 7. Journal and forecast

- **JOURNAL menu tab.**
  - Today: the date and weather, plus tomorrow's forecast.
  - The active request, with progress and days left.
  - Town Works progress.
  - The lore notes you've read; select one to read it again.
- **PEOPLE menu tab.** For each named NPC:
  - portrait, name and hearts;
  - birthday;
  - whether you've talked to them today and given them a gift;
  - the gift reactions you've discovered.
- **The forecast** comes from Kael's weather call: a notice pinned on the board ("Kael says:
  tomorrow, rain"), the journal's top line, and the morning toast.
