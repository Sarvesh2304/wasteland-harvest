# Balance & Performance Pass (Milestone E, 2026-11-12)

The numbers behind the economy and the frame budget, how to re-measure them, and the tuning
this pass made. Re-run the tools after any change to `data/crops.json`, `data/items.json`,
`data/loot_tables.json`, `data/buildings.json` or the ruins generator.

| Tool | What it reports |
|---|---|
| `python3 tools/balance/crop_table.py` | Each crop over a full season: harvests, revenue, seed cost, profit per tile per day |
| `python3 tools/balance/loot_table.py` | Expected sell value of one search of each container / enemy, per ruins tier |
| `godot --headless --path . --script res://tools/balance/ruins_value.gd` | 40 real generated levels per depth: containers, enemies, total loot value |
| `godot --headless --path . --audio-driver Dummy --script res://tools/perf_probe.gd` | Frame time in the heaviest situations (add a display via xvfb-run for draw calls) |

## 1. Farming

Profit per tile per day over a 28-day season, planted on day 1:

| Season | Best | Typical | Notes |
|---|---|---|---|
| Spring | Bloodberry 13.5 (regrows) | 4.5-6.4 | The learning season: cheap, fast crops |
| Summer | Glow Melon 12.9 | 6.7-9.6 | |
| Autumn | Rustvine Grape 21.9 (regrows) | 5.7-15.7 | The money season, like Stardew's fall |
| Winter | Frostroot 10.0 | | One outdoor crop; the greenhouse carries the rest |

The curve is Stardew's: regrowing crops lead, high-value single crops follow, and quick cheap
crops trail but pay out often. Dust Corn (two seasons, 6.5/day) and Dustwheat (3.8/day) are
deliberately low: they feed cooking and artisan goods rather than the shipping box.
**No change.**

## 2. The ruins

A full search of real generated levels (sell value of everything found):

| Depth | Containers | Enemies | Loot | Enemy drops | Run total (cumulative) |
|---|---|---|---|---|---|
| 1 | 7.4 | 7.6 | 216 | 18 | ~230 |
| 2 | 10.0 | 11.0 | 505 | 172 | ~910 |
| 3 | 14.9 | 13.8 | 1459 | 291 | ~2660 |
| 4 | 14.4 | 16.2 | 1442 | 358 | ~4460 |

A depth-1 run is worth about a day of a 30-tile spring farm. Deeper runs are worth several
days of farming, which is intended: GDD §1 has the player choose their own blend of the gentle
settlement and the dangerous ruins, and the deep ruins pay for their risk (rads, the death
penalty that forfeits the haul, ammo and medicine spent). Three things keep the theoretical
total from being the real one:
- **The pack.** 27 slots, about half taken by tools, weapons and medicine. A depth-3 run
  turns up 25+ different things, so the player chooses what to carry home.
- **The market.** Shipping a lot of one thing floods its price (`docs/LIVING_SETTLEMENT.md` §1).
- **Spending.** Ammo, bandages and rad meds are bought or crafted before a run.

The Python loot table first showed containers getting *worse* deeper; that was the analysis
script's bug (a tier without its own roll range uses the nearest lower tier's, as
`scripts/loot_db.gd` does), not the game's. Every container's value rises with depth.
**No change to loot.**

## 3. Credit sinks: the change this pass made

Before this pass, the Town Works projects (3,300 Cr in total) and animals (45-180 Cr) were
nearly the only things Credits bought; every building cost only materials. With the ruins
paying as above, Credits piled up with nothing to spend them on. Stardew's answer is the
builder's fee, and the bigger buildings now have one (`"credits"` in `data/buildings.json`,
`BuildingDB.credits()`, shown first in the cost line and checked wherever affordability is):

| Building | Fee | | Building | Fee |
|---|---|---|---|---|
| Barn | 1200 | | Greenhouse | 1500 |
| Coop | 600 | | Antenna Tower | 1500 |
| Workshop | 400 | | Community Kitchen | 1200 |
| Clinic | 800 | | Solar Panel | 400 |
| Trading Post | 1000 | | Rain Collector | 100 |
| Watchtower | 500 | | | |

The Shelter Tent, Storage Shed, Compost Pit, fences and gates stay free. The day-1 starting
bonus still covers the first shed, and settler housing shouldn't be gated behind money. About
9,000 Cr of fees in all: weeks of farming, or a handful of deep runs.

## 4. Performance

The work done in one frame, measured by `tools/perf_probe.gd` with no rendering and
low-processor sleep off:

| Scenario | Mean | p95 | Max |
|---|---|---|---|
| The farm with all 1,334 tillable cells planted and watered | 1.1 ms | 1.4 ms | 13 ms (once) |
| The town at noon on Planting Day, everyone gathered | 1.3 ms | 2.0 ms | 6 ms |
| A Core level (depth 4) with every enemy chasing | 1.7 ms | 2.5 ms | 5 ms |
| One overnight day change, full farm | 64 ms, once, behind the sleep fade | | |

Rendering (xvfb, software OpenGL, so far slower than any real GPU): 160-300 draw calls a frame
and a 10-12 ms average, with one 137 ms frame on entering the ruins (a first-use shader
compile; it doesn't recur). Node counts stay around 5,500-6,700. **There is no hot spot to
fix.** The budget at 60 fps is 16.7 ms, and the script side uses about a tenth of it.

Two measurement traps for whoever runs this next:
- Godot's `Performance.TIME_PROCESS` monitor only updates once per idle frame. Sampling it
  from `_physics_process` repeats one slow frame many times.
- Headless runs sleep 6.9 ms between frames in low-processor mode, so every frame reads
  6.9 ms unless that mode is turned off (the probe does).
