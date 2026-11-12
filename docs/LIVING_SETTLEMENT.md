# A living settlement — design + data contracts (Milestone D, 2026-11-10)

The spec for Milestone D: a market that moves, a caravan, the player's own trading post, four
seasonal festivals and the main story ("The Signal"). It builds on `docs/SOCIAL_AND_QUESTS.md`
(same text rule, same dialogue format, same tone: GDD §2 and §9).

If you change a shape here, change the code that reads it in the same commit.

---

## 1. The market — `scripts/market.gd`, `scripts/market_rules.gd`

Two forces move what the shipping box pays. Both are shown in the shipping screen, on the notice
board and in the journal, so the player can plan around them.

- **Glut.** Shipping a lot of one thing floods Marta's shelf.
  - Each item has a saturation from 0 to 1. A sale adds `units × base value ÷ 1200`.
  - A sale is paid at the saturation *before* it, so the first big load gets full price and the
    next ones don't.
  - Saturation up to 0.25 costs nothing (a small farm never notices). From there the price falls
    in a straight line to −40% at 1.
  - Saturation falls by 0.2 each morning. A fully flooded item is back to normal in five days.
- **Demand.** From day 8, every Monday Marta names three things she's short of. They pay +40% all
  week. The list is drawn from crops and forage in season, cooked dishes and artisan goods.

The shop-expansion bonus (+10%) multiplies on top. Store *buy* prices never move.

## 2. The caravan — `scripts/caravan.gd`, `data/caravan.json`

**Tully, the bottle-cap man**, works the trade road between settlements. He ran the east road
with Marta for nine years before she settled. He is certain bottle caps will be money again one
day and takes them as payment in spirit only.

- **When:** every Wednesday and Saturday from day 3, all day, at the market stall in the town's
  south-west. On his days the stall is stocked and lit, and he stands in front of it.
- **Who:** `caravan_trader` is the eighth named NPC: hearts, gifts, a birthday, full v2 dialogue.
  His service node is `wares` (choice 0 → `OPEN_CARAVAN`).
- **Stock:** six items a visit, drawn from the pool in `data/caravan.json`, each with a limited
  quantity. The draw is seeded by the day, so a reload doesn't reroll it.
- **Friendship matters:** each heart with Tully takes 2% off his prices (20% at ten hearts), and
  some stock only appears at 3 or 6 hearts.

```jsonc
{"visit_weekdays": ["Wed", "Sat"], "first_day": 3, "offers_per_visit": 6,
 "pool": [
  {"item": "coffee", "price": 320, "qty": [1, 2], "weight": 8},
  {"item": "blueprint", "price": 900, "qty": [1, 1], "weight": 3, "min_hearts": 3},
  {"item": "seed_glow_melon", "price": 90, "qty": [3, 6], "weight": 4, "season": "spring"}
 ]}
```

Pool entry keys: `item`, `price` (Credits each), `qty` ([min, max] in stock), `weight`, and
optional `min_hearts` and `season` (only offered in that season).

## 3. The trading post — `scripts/structures.gd`

The buildable Trading Post (3×2, already on the BUILD tab) becomes the player's own shop.

- Interact to open its shelf (a storage screen). Anything shippable can go on it.
- Each morning, passing trade buys from the shelf in shelf order, at a markup the player sets.
  **Q** on the shelf screen cycles it:

| Markup | Price | Units sold a day |
|---|---|---|
| Fair | base × 1.15 | 12 |
| Bold | base × 1.35 | 6 |
| Steep | base × 1.6 | 3 |

- A settler assigned to the post as trader sells half as many again (18 / 9 / 4).
- The post ignores glut and demand: it's a slow, steady, premium outlet next to the shipping
  box's fast one.

## 4. Festivals — `data/festivals.json`, `scripts/festivals.gd`

One a season. On the day the plaza is dressed (bunting, lanterns, a food table), everyone gathers
there from 9 AM, and a striped **festival booth** in the plaza runs the day's activity. The day
before, a toast and the notice board announce it; the journal always shows the next one.

| id | Name | Date | Host | Activity |
|---|---|---|---|---|
| `planting_day` | Planting Day | Spring 14 | mayor_harlan | `seed_hunt` |
| `scorch_fair` | Scorch Fair | Summer 15 | rancher_silas | `goat_race` |
| `harvest_day` | Harvest Day | Autumn 21 | marta | `harvest_show` |
| `winter_gathering` | Winter Gathering | Winter 14 | doc_ama | `gift_circle` |

**Activities.**
- **`seed_hunt`:** twelve seed packets are hidden around town. You have two in-game hours.
  Wren always finds eight.
  - 10 or more: 300 Cr and 3 Glow Melon Seeds. 6–9: 150 Cr. Fewer: 50 Cr.
  - Every packet is yours to keep (2 Wild Seeds each).
- **`goat_race`:** four goats run the plaza. Pick one and stake 50 Cr. A win pays the stake
  times the goat's odds. Up to three races. Dorothy is the favourite and the least reliable:
  she sometimes stops to bite a rival.
- **`harvest_show`:** your best five different things you grew, foraged, cooked or made go on
  the table (you keep them). The score is their combined sell value, plus 10% for each
  different kind (crop, forage, cooked, artisan, animal product). Marta, Silas and Harlan
  enter too, and their tables get better each year.
  - 1st: 1000 Cr. 2nd: 500 Cr. 3rd: 250 Cr. 4th: 100 Cr.
- **`gift_circle`:** a week before (Winter 7), you draw a name. At the gathering, a gift to
  that person counts five times, like a birthday. Someone drew your name too: the booth has
  your gift from them.

```jsonc
{"festivals": [
  {"id": "harvest_day", "name": "Harvest Day", "season": "autumn", "day": 21,
   "host": "marta", "activity": "harvest_show",
   "announce": "One line for the toast and the board, the day before.",
   "blurb": "Two sentences for the journal.",
   "booth_title": "The Harvest Table",
   "booth_text": "What the booth's prompt says before you start (2-3 sentences).",
   "results": {"1": "...", "2": "...", "3": "...", "4": "..."},  // by place (harvest_show)
   "spots": {"mayor_harlan": [15, 6], "marta": [18, 7]}           // optional, engine default otherwise
  }
]}
```

Per-activity text keys, all strings:
- `seed_hunt`: `start`, `results` with keys `high`, `mid`, `low` (may use `{count}`).
- `goat_race`: `goats`, an array of four `{"name", "odds", "quip"}` (odds 2, 3, 4 and 6;
  Dorothy is the 2); `win`, `lose` (may use `{goat}` and `{winner}`).
- `harvest_show`: `results` keyed `"1"`–`"4"` (may use `{score}`).
- `gift_circle`: `draw` (the Winter 7 toast, uses `{npc}`), `open` (uses `{npc}` and `{item}`),
  `gifts`: for each of the seven townsfolk, the item id they give (real items).

**Dialogue flags** (see §6): `festival_<id>` on the day, `festival_tomorrow` the day before.

## 5. The Signal — `data/story.json`, `scripts/story.gd`

The main story. It is a thread, not an ending: finishing it changes the world and the game goes
on (GDD §10). Harlan has kept a dead radio on for twenty years, hoping to hear his sister June.
It finally says something.

| Stage | Starts when | The player's goal | What happens |
|---|---|---|---|
| `static` | Day 8 or later, one expedition done | Talk to Harlan (he shows a "!") | His radio is catching a looping broadcast, too faint to read. |
| `radio_parts` | Harlan's talk | Bring Harlan 3 Radio Parts | One lies in each ruins level until he has them. Overnight an antenna goes up on his roof. |
| `broadcast` | The antenna is up | Read the morning notice | The broadcast: the Northgate seed vault, under The Core, still sealed. |
| `find_vault` | The notice is read | Reach The Core and open the vault | The door needs a Keycard and a four-digit code. The code is in an old note in the ruins; Wren will tell a friend. |
| `decision` | The vault is open | Bring the seed stock to Harlan | He asks what the town should do with it. |
| `done_home` | "Plant it here" | — | The town's fields are sown from it. Your crops yield more, and Harlan sends a share every Monday. |
| `done_shared` | "Send it down the road" | — | Tully carries it to every settlement. He comes four days a week with more stock, and demand lists are longer. |

```jsonc
{"stages": {
  "static":      {"title": "A Voice in the Static", "journal": "What the journal says now.",
                  "notice": "The morning notice that starts it (Harlan wants a word)."},
  "radio_parts": {"title": "...", "journal": "...", "have_some": "Harlan, when you bring fewer than 3."},
  "broadcast":   {"title": "...", "journal": "...", "notice": "The broadcast itself, as received."},
  "find_vault":  {"title": "...", "journal": "...",
                  "need_keycard": "At the door without a keycard.",
                  "need_code": "At the door with a keycard but no code.",
                  "opening": ["Page 1 of the vault scene.", "Page 2.", "Page 3."]},
  "decision":    {"title": "...", "journal": "..."},
  "done_home":   {"title": "...", "journal": "...", "notice": "The morning after."},
  "done_shared": {"title": "...", "journal": "...", "notice": "The morning after."}
 },
 "wren_code_hint": "What Wren says (friend tier) that gives the code away."}
```

Harlan's story conversations are nodes in his `data/dialogue.json` entry:
- `story_static` → … → a terminal node (the engine then moves to `radio_parts`).
- `story_parts` → … → terminal (played when he gets the third part).
- `story_decision` → … → a node with two choices: choice 0 → `STORY_HOME`, choice 1 →
  `STORY_SHARED`.
- `story_home_end` and `story_shared_end`: what he says right after each choice.

The code is **4-1-7-7** (it's already in `data/lore_notes.json`).

## 6. New dialogue flags

| flag | true when |
|---|---|
| `caravan_day` | Tully is in town today |
| `festival_tomorrow` | a festival is tomorrow |
| `festival_<id>` | that festival is today (four ids, §4) |
| `story_signal` | the story has started (stage `static` or later) |
| `story_broadcast` | the broadcast has been heard (`find_vault` or later) |
| `story_vault_open` | the vault has been opened (`decision` or later) |
| `story_home` / `story_shared` | the decision made |
| `in_demand_<item>` | not provided; don't use |

Priorities: birthday 10, festival-day lines 8, project news 5, story reactions 3 (and `once`),
`festival_tomorrow` and `caravan_day` 2.

## 7. Art list

All code-generated (`tools/art/`), same rules as before: deterministic, house palette.

| File | Size | Notes |
|---|---|---|
| `art/characters/caravan_trader/` | 24×24 frames | Tully: wide-brim hat, grey-ginger beard, long patched travelling coat, a sash of bottle caps across the chest (glinting dots), big pack. Same layout as the other townsfolk, plus `_frames.tres`. |
| `art/env/props/market_stall_open.png` | 48 wide, up to 56 tall | The existing `market_stall.png`, open for business: goods, hanging lanterns, a jar of caps, Tully's pack-goat tethered at one end. Same footprint (3×1), bottom-aligned. |
| `art/buildings/trading_post.png` | 48 wide, up to 48 tall | Player-built shop, footprint 3×2: open front with a counter, shelves, a hanging scales sign. |
| `art/buildings/mayor_house_antenna.png` | 64×72 | `mayor_house.png` with a scrap antenna mast and guy wires on the roof (load the existing PNG and draw on a taller canvas, bottom-aligned). |
| `art/buildings/festival_booth.png` | 32 wide, up to 40 tall | Striped booth with flags, footprint 2×1. |
| `art/env/props/bunting.png` | 64×16 | A string of little flags, to hang in rows across the plaza (no footprint). |
| `art/env/props/festival_table.png` | 32×24 | A trestle table with food and a cloth, footprint 2×1. |
| `art/env/props/festival_lantern.png` | 32×32, 2 frames of 16×32 | A post with a paper lantern: unlit, lit. |
| `art/env/props/seed_packet.png` | 16×16 | A little paper seed packet lying on the ground (the hunt's pickups). |
| `art/fx/race_goat.png` | 96×16, 4 frames of 24×16 | A goat running left, white-grey so the game can tint it, with a blank bib. |
| `art/env/ruins/vault_door.png` | 64×32, 2 frames of 32×32 | A heavy steel hatch set in a concrete collar, seen from above, footprint 2×2: sealed with a red light, open with a green light and a dark stairwell. |
| `art/items/vault_seeds.png`, `art/items/festival_ribbon.png` | 16×16 | Item icons: a sealed steel canister with a sprout stencil; a rosette ribbon. |
