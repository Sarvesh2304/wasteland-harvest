# Fishing (2026-11-24)

The Fishing Rod has been an item since Phase 4 (`data/items.json`, tool kind `fishing_rod`,
150 Cr) and `audio/sfx/fish_bite.wav` exists, but nothing sold or gave the rod and using it did
nothing. GDD §4 lists fishing as a core settlement activity, a sub-activity of the Foraging
skill (GDD §8: no separate fishing skill), and ROADMAP Year 2 asks for "Water body + fishing:
cast-and-catch minigame, fish as food/trade commodity, rare fish trigger NPC dialogue". This is
that system.

## 1. Getting the rod

- **New games:** the rod is in the farm chest on day 1: your father's rod. The day-1 morning
  toast says so ("Dad's old fishing rod is in the chest.").
- **Marta** stocks it at 150 Cr for anyone who lost or sold theirs, and for saves from before
  fishing existed.

## 2. Where

Any water cell ('W'). Each zone layout that has water declares what kind it is, with
`const WATER_KIND := "pond" | "river" | "creek"`:

| Water | Where |
|---|---|
| `pond` | The town pond (every start) |
| `creek` | The Forest Edge farm's water |
| `river` | Riverside: the farm, path and ranch |

The riverside town had no pond (its water was the river down its west edge and a bank dock), so
it gained the standard town's south-east pond and dock, same cells: its west edge is `river`, the
pond is `pond` (`town_layout_riverside.gd`'s `water_kind_at`). The fishing code asks the bound
zone's map: `test_map.gd`'s `water_kind_at(cell)`.

## 3. Casting and the bite

1. Hold the rod and face water. **Hold** Use to charge the cast; a small power meter fills
   over 1 s. **Release** to cast: the bobber flies 1-4 cells ahead in the facing direction, by
   power. If that cell isn't water: "No water there." No energy is spent.
2. A cast costs **2 energy** (like a tool swing; the Foraging skill's discounts apply).
3. The bobber floats and bobs. A bite comes after a random **1.5-6 s**, faster in rain (x0.7)
   and at dawn and dusk (x0.8). Before the bite, a fish may nibble (1-2 small twitches with a
   faint plop): pressing Use on a nibble reels in empty, and that's the skill check.
4. **The bite:** the bobber dips hard, a "!" pops over the player and `fish_bite.wav` plays.
   Press Use within **0.75 s** to hook it, which starts the reel. Too late: "It got away." Moving
   or pressing Esc/B at any point reels in.
5. About **10%** of bites are **junk** (an old boot becomes 1 Rubber, a can becomes 1 Scrap
   Metal, a tangle becomes 2 Fiber): caught instantly, with a short wry line, no reel.

## 4. The reel: line tension

An original minigame, readable at 320x192, playable with one button (keyboard or pad):

- A horizontal **tension gauge** with a green **sweet spot** band, a **catch bar** under it, and
  the fish's silhouette shaking as it fights.
- **Hold Use to reel:** tension rises (0.9/s). **Release to give line:** tension falls (0.7/s).
- **The fish runs** in bursts. During a run, tension climbs fast on its own (the fish's force),
  so you must ease off. Between runs it rests.
- **Catch bar:** it starts at 30%. It **fills** while tension is inside the sweet spot (by the
  fish's difficulty), **drains** while tension is below 15% (the fish works loose), and holds
  still otherwise.
- Tension reaching **100%** snaps the line: the fish is gone, the rod is fine. The catch bar at
  0% means the fish escapes; at 100% it's caught.
- The fish's difficulty (1-5) sets run frequency, run force, and the sweet spot's width
  (35% wide at 1 down to 18% at 5). Each Foraging level widens the sweet spot by 1%.
- Accessibility: Settings' **Reduce flashes** keeps the gauge from flashing on runs. The reel
  pauses with the game (menus, focus loss).

## 5. The fish

`data/fish.json`. Each fish has id, name, sell value, difficulty, the waters it lives in,
seasons, times of day (`morning` 6-11, `day` 11-17, `evening` 17-21, `night` 21-2), weather
(`rain` = only in rain or storm; omitted = any), and a weight (rarity). Fish are items with
type `fish` (shippable; listed in the market, requests, gifts and the harvest show).

| id | Name | Cr | Diff | Waters | Seasons | When | Weather | Weight |
|---|---|---|---|---|---|---|---|---|
| `mud_minnow` | Mud Minnow | 15 | 1 | all | all | any | | 30 |
| `shellback_crawdad` | Shellback Crawdad | 35 | 1 | creek, pond | spring, summer | any | | 14 |
| `rustgill_carp` | Rustgill Carp | 40 | 2 | pond, river | spring, summer, autumn | any | | 18 |
| `sun_perch` | Sun Perch | 45 | 2 | pond | summer | day | | 12 |
| `silver_dace` | Silver Dace | 55 | 2 | river, creek | spring, summer | morning, day | | 12 |
| `ash_trout` | Ash Trout | 60 | 3 | creek, river | spring, autumn | morning, evening | | 10 |
| `bog_eel` | Bog Eel | 70 | 3 | pond, creek | all | evening, night | | 8 (x2 in rain) |
| `sludge_catfish` | Sludge Catfish | 80 | 3 | pond | all | any | rain | 8 |
| `frostfin` | Frostfin | 90 | 3 | all | winter | any | | 14 |
| `iron_pike` | Iron Pike | 110 | 4 | river | autumn, winter | any | | 6 |
| `glowfin` | Glowfin | 120 | 4 | all | summer, autumn | night | | 6 |
| `two_headed_perch` | Two-Headed Perch | 150 | 4 | all | all | any | | 2 |
| `old_mayor` | The Old Mayor | 1500 | 5 | pond | autumn | evening | rain | legendary |

**The Old Mayor** is the town pond's legendary catfish. Harlan's grandfather swore it was
there, and nobody has believed him for sixty years. It bites only in autumn, in the rain, in
the evening, at 5% of eligible bites, and only once per save. Catching it sets the dialogue flag
`caught_old_mayor`: Harlan and others react (the rare-fish dialogue the roadmap asks for), and
the journal marks it.

## 6. What fish are for

- **Selling:** shippable, and part of Marta's demand-list pool.
- **Cooking** (Cooking category in the crafting menu):
  - Grilled Fish: any 1 fish from a set of common ones, plus 1 Wood. Restores energy.
  - Fish Stew: 2 fish + 1 Mutant Potato + 1 Wild Greens. Restores more.
  - Smoked Eel: 1 Bog Eel + 1 Charcoal. Sells well.

  Each recipe names specific fish (recipes take item ids): Grilled Fish has variants, or one
  recipe takes the cheapest fish and the menu shows the rest.
  Built as variants: Grilled Fish from a Mud Minnow, Rustgill Carp, Sun Perch, Silver Dace or
  Frostfin, Fish Stew from 2 Mud Minnows or 2 Rustgill Carp; each variant is its own recipe
  with the same result, and `variant` names the fish on the CRAFT tab ("Grilled Fish: Carp").
- **Gifts:**
  - Kael likes fish (he grew up living off the land).
  - Brask loves Grilled Fish.
  - Doc likes Fish Stew.
  - Marta is neutral (she can't sell what spoils).
  - Silas dislikes raw eel.
- **Requests:** a `fish` pool joins the notice-board pools ("Kael wants 3 Rustgill Carp").
- **Harvest show:** fish count as their own kind (`fish`), worth the +10% kind bonus.
- **Foraging XP:** 3 + 3 x difficulty per catch; junk gives 1.

## 7. Journal and dialogue

- **Fish page** in the JOURNAL tab: every species, with "?" for ones not caught yet, and for
  caught ones the count and where and when they bite. Completionist bait.
- **Dialogue flags:**
  - `has_fished`: one catch ever.
  - `angler`: 6 or more species caught.
  - `caught_old_mayor`.
- **Lines:** each townsperson gets one reaction line per flag (once lines, priority 3). Kael
  also gets a hint line about the Old Mayor at friend tier.

## 8. Save

Additive section `fishing`: `{"caught": {id: count}, "old_mayor": bool}`. Old saves load with
an empty log.

## 9. Art (`tools/art/fishing/`, code-generated)

- Icons for the 13 fish (16x16), plus Grilled Fish, Fish Stew and Smoked Eel icons.
- The bobber: 8x8, 2 frames (float, dip).
- A splash effect: 16x16, 3 frames.
- The reel panel's pieces: the gauge frame and a fish silhouette, or drawn in code from the
  house palette.

The player's cast reuses the existing tool-swing animation with the rod's sprite, and the line
is a Line2D from the rod tip to the bobber.
