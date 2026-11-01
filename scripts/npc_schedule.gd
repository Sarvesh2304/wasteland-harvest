extends RefCounted
## Phase 7 Stage 2: pure daily-schedule math for the 4 named NPCs (scripts/npc.gd) — the
## ROADMAP.md Phase 7 checklist's "Daily schedules — wake/tasks/eat/sleep, location changes by
## time of day" item, as static functions on plain data, headless-testable with no Node/scene
## required (tests/test_npc_schedule.gd). Same pure-core/stateful-shell split as npc_grid.gd vs
## npc.gd, and deliberately the same file shape as npc_grid.gd (a RefCounted holding nothing but
## `static func`s and const data).
##
## ## Scope: IN-ZONE waypoints only, and only the 4 named NPCs
##
## A schedule moves an NPC around ITS OWN zone; it never sends anyone through a gate. NPCs are
## spawned once into one zone's Npcs node (scripts/npcs.gd) and have zero reparent/cross-zone
## infrastructure — unlike the player, whose zone crossing is a `_bind_zone` rebind scripts/
## main.gd owns exclusively. Cross-zone NPC travel would mean inventing a parallel per-NPC
## zone-identity/reparent/gate-pathing system from scratch; in-zone waypoints instead reuse
## npc.gd's existing validated one-cell walk, and match every example the ROADMAP item itself
## gives (wake, garden/store/water walk, eat, sleep — all local activities).
##
## Only the 4 named NPCs are scheduled. Settlers (procedurally named, player-recruited via
## Phase 8's arrival system) are interchangeable by design and keep today's pure random wander:
## npc.gd gates on SCHEDULES.has(npc_id), so an unscheduled NPC runs exactly the code path it ran
## before this stage.
##
## ## Schedule shape
##
## A schedule is an ORDERED Array of {"start_minutes": int, "cell": Vector2i}, ascending by
## start_minutes. Times are minutes-into-day in DayManager's own frame (0..1439, where the day
## begins at DayManager.DAY_START_MINUTES = 360 = 6:00 AM, so the pre-dawn minutes 0..359 are the
## TAIL of the lived day, not its head — see current_waypoint's wrap rule).
##
## ## Authoring rules for a waypoint cell (all four checked by hand AND by
## ## tests/test_npc_schedule.gd against the real layout ROWS)
##
## 1. OPEN GROUND IN EVERY VARIANT THAT SHARES THE NPC. The town three and Silas are declared
##    once in layout_common.gd's TOWN_NPCS/RANCH_NPCS and reused verbatim by BOTH the standard
##    and riverside variants of their zone, so a cell that is open in one variant and water/fence
##    in the other is not a legal waypoint. test_npc_schedule.gd re-checks every cell through the
##    layouts' own is_solid(), not a duplicated copy of the ASCII map.
## 2. DISJOINT 3x3 BOXES. On arrival an NPC wanders within wander_radius of the WAYPOINT (not of
##    home), so each waypoint inherits TOWN_NPCS' disjointness discipline: no waypoint box may
##    overlap another NPC's home box, another waypoint box, or one of layout_common.gd's
##    SETTLER_HOME_CELLS boxes. (Overlapping wander boxes caused real intermittent
##    wrong-NPC-picked-up failures in tools/runtime_smoke.gd — see TOWN_NPCS' own doc comment.)
## 3. REACHABLE BY A MONOTONE L-PATH. next_travel_cell() below is deliberately a simple greedy
##    walker with no backtracking, so every authored route must get from A to B by only ever
##    stepping toward the target (detouring around a blocked cell via the other axis is fine —
##    that is what the fallback in next_travel_cell does — but a route that needs to move AWAY
##    from the target to escape a pocket is not authorable here).
## 4. FIRST ENTRY IS THE NPC'S HOME CELL, at 6:00 AM. Two reasons: a fresh boot / save reload
##    respawns every NPC on its authored home cell (npcs.gd) at exactly DAY_START_MINUTES, so a
##    home-first schedule means "the day starts where the game puts you" with no teleport-looking
##    first walk; and every existing smoke tool that asserts spawn-on-home-cell keeps passing
##    unchanged.

## Per-NPC schedules, keyed by npc_id (the dialogue.json / roster key). 3-4 waypoints each.
##
## Every cell below was verified open in BOTH variants of its zone before being authored (rule 1
## above); the file+row each was checked against is named in the per-entry comments.
##
## TOWN (town_layout_standard.gd + town_layout_riverside.gd — same 36x17 grid, same BUILDINGS,
## differing only in the west column and the water feature):
##   - mayor_harlan, home (10,4) — the plaza square in front of his fortified house.
##       06:00 home (10,4)      : the founder's own doorstep at first light.
##       08:30 (16,4)           : beside the bulletin board at (17,4) — the town's one civic
##                                fixture, where notices are posted and read. Harlan is the
##                                Optimistic Builder (Stage 1, data/dialogue.json): holding court
##                                at the notice board is his whole characterisation.
##       18:00 (10,8)           : mid-plaza, evening rounds — visible from the store and the
##                                west approach, the "still out among people" beat.
##       22:00 home (10,4)      : back to his door for the night.
##   - marta, home (17,9) — out front of her store (footprint x16-18, y10-11) with the crates.
##       06:00 home (17,9)      : before opening, still stacking the front crates.
##       09:00 (20,10)          : the store's east face — the trade window/counter side, open
##                                hours. She is the Pragmatic Trader; the store IS her day.
##       18:00 (21,4)           : after closing, the plaza's north-east corner between the
##                                bulletin board and the shacks, where the evening crowd is.
##       22:00 home (17,9)      : home past the shuttered store.
##   - scout_kael, home (18,13) — the plaza's southern edge (see TOWN_NPCS' doc).
##       06:00 home (18,13)     : dawn, before he walks his watch.
##       07:00 (26,14)          : the pond dock on the east side, looking out over the water at
##                                the road east he scouts. (Until Milestone B he stood two cells
##                                inside the west gate at (3,3); that's Brask's ground now.)
##       19:00 home (18,13)     : off watch, back to the south plaza edge.
##   - brask, home (4,2) — the wall warden's corner by the west gate and the watchtower site.
##       06:00 home (4,2)       : first light, the north-west corner of the wall.
##       09:00 (2,10)           : walking the west wall south, past the market stall.
##       13:00 (21,14)          : the south fence, below the plaza.
##       19:00 home (4,2)       : back to his corner for the night watch.
##   - wren, home (29,2) — up by the fire pit on the east side, away from everyone.
##       06:00 home (29,2)      : asleep by the embers, as far as anyone can tell.
##       11:00 (33,4)           : the north-east corner of the fence, looking at the city.
##       17:00 (25,6)           : behind the shacks, where the trading gets done quietly.
##       23:00 home (29,2)      : back to the fire pit; a night owl.
##   - doc_ama, home (10,13) — beside her tent and the ruined clinic in the south-west.
##       06:00 home (10,13)     : the tent, morning surgery.
##       09:00 (8,11)           : out front of the clinic site, between the tent and the stall.
##       13:00 (13,3)           : house calls along the plaza's north side.
##       18:00 home (10,13)     : back to the tent.
## Every waypoint keeps its radius-1 box clear of every other NPC's and the settler slots
## (tests/test_npc_schedule.gd checks it).
## RANCH (ranch_layout_standard.gd + ranch_layout_riverside.gd — same 36x18 grid, same
## BUILDINGS, differing only in the west column):
##   - rancher_silas, home (17,9) — the open yard inside the fenced compound.
##       06:00 home (17,9)      : the yard, start of day.
##       07:30 (10,10)          : the east face of the barn (footprint x6-9, y9-11) — morning
##                                feed and muck-out, right beside the cow pen his RANCH_DECOR
##                                cows stand in.
##       13:00 (24,9)           : the west face of the coop (footprint x25-26, y9-10) and the
##                                goat pen beyond it — the afternoon half of the same rounds.
##       19:00 home (17,9)      : back to the yard in front of the ranch house for the evening.
const SCHEDULES: Dictionary = {
	"mayor_harlan": [
		{"start_minutes": 6 * 60, "cell": Vector2i(10, 4)},
		{"start_minutes": 8 * 60 + 30, "cell": Vector2i(16, 4)},
		{"start_minutes": 18 * 60, "cell": Vector2i(10, 8)},
		{"start_minutes": 22 * 60, "cell": Vector2i(10, 4)},
	],
	"marta": [
		{"start_minutes": 6 * 60, "cell": Vector2i(17, 9)},
		{"start_minutes": 9 * 60, "cell": Vector2i(20, 10)},
		{"start_minutes": 18 * 60, "cell": Vector2i(21, 4)},
		{"start_minutes": 22 * 60, "cell": Vector2i(17, 9)},
	],
	"scout_kael": [
		{"start_minutes": 6 * 60, "cell": Vector2i(18, 13)},
		{"start_minutes": 7 * 60, "cell": Vector2i(26, 14)},
		{"start_minutes": 19 * 60, "cell": Vector2i(18, 13)},
	],
	"brask": [
		{"start_minutes": 6 * 60, "cell": Vector2i(4, 2)},
		{"start_minutes": 9 * 60, "cell": Vector2i(2, 10)},
		{"start_minutes": 13 * 60, "cell": Vector2i(21, 14)},
		{"start_minutes": 19 * 60, "cell": Vector2i(4, 2)},
	],
	"wren": [
		{"start_minutes": 6 * 60, "cell": Vector2i(29, 2)},
		{"start_minutes": 11 * 60, "cell": Vector2i(33, 4)},
		{"start_minutes": 17 * 60, "cell": Vector2i(25, 6)},
		{"start_minutes": 23 * 60, "cell": Vector2i(29, 2)},
	],
	"doc_ama": [
		{"start_minutes": 6 * 60, "cell": Vector2i(10, 13)},
		{"start_minutes": 9 * 60, "cell": Vector2i(8, 11)},
		{"start_minutes": 13 * 60, "cell": Vector2i(13, 3)},
		{"start_minutes": 18 * 60, "cell": Vector2i(10, 13)},
	],
	"rancher_silas": [
		{"start_minutes": 6 * 60, "cell": Vector2i(17, 9)},
		{"start_minutes": 7 * 60 + 30, "cell": Vector2i(10, 10)},
		{"start_minutes": 13 * 60, "cell": Vector2i(24, 9)},
		{"start_minutes": 19 * 60, "cell": Vector2i(17, 9)},
	],
}


## Whether npc_id is one of the scheduled (named) NPCs — the single gate npc.gd checks before
## doing any schedule work at all, so settlers and any future unscheduled NPC pay one Dictionary
## lookup and nothing else.
static func has_schedule(npc_id: String) -> bool:
	return SCHEDULES.has(npc_id)


## The schedule for npc_id, or [] when it has none (safe to pass straight to current_waypoint).
static func schedule_for(npc_id: String) -> Array:
	return SCHEDULES.get(npc_id, [])


## Where `schedule` says to be at `minutes_into_day` (DayManager's frame, 0..1439): the cell of
## the LATEST entry whose start_minutes <= minutes_into_day.
##
## Before the first entry's start_minutes — i.e. the pre-dawn minutes 0..359, since every
## authored schedule opens at 6:00 AM — it WRAPS to the entry with the greatest start_minutes,
## which is the same day's final waypoint. That is the honest reading of a repeating daily
## schedule: 2 AM is the tail of the evening you are still living, not the head of a day that
## hasn't started, so "where were you last told to be" is the last entry, and an NPC that walked
## home at 22:00 stays home through the small hours instead of snapping back to a morning spot.
##
## Entries are expected in ascending start_minutes order (test_npc_schedule.gd enforces it for
## every authored schedule), but the scan is order-independent by construction, so an
## out-of-order array still resolves to the same latest-entry answer rather than silently
## returning nonsense.
##
## An EMPTY schedule returns Vector2i.ZERO. That is not a sentinel and must not be treated as
## one — (0,0) is a real (if always solid-walled) cell on every layout here — which is exactly
## why callers gate on has_schedule()/SCHEDULES.has(npc_id) and never on the returned cell.
static func current_waypoint(schedule: Array, minutes_into_day: float) -> Vector2i:
	var latest_start := -1
	var latest_cell := Vector2i.ZERO   # the day's final waypoint — the pre-dawn wrap target
	var current_start := -1
	var current_cell := Vector2i.ZERO
	for entry in schedule:
		var start := int(entry["start_minutes"])
		var cell: Vector2i = entry["cell"]
		if start > latest_start:
			latest_start = start
			latest_cell = cell
		if float(start) <= minutes_into_day and start > current_start:
			current_start = start
			current_cell = cell
	if current_start >= 0:
		return current_cell
	return latest_cell


## One validated cell-step from `current` toward `target` — the scheduled-travel counterpart to
## npc_grid.gd's candidate_steps(), which picks a RANDOM in-zone neighbour and so can't close
## distance on a waypoint across the plaza.
##
## Deliberately simple and deliberately NOT a pathfinder (same reasoning npc_grid.gd's header
## gives for not reaching for NavigationAgent2D): step one cell along the axis with the larger
## remaining distance, falling back to the other axis when that cell is blocked — which is
## enough to walk around a building corner or a placed structure — and otherwise stay put so the
## caller just idles and retries. `is_open` is a Callable(Vector2i) -> bool (npc.gd passes
## `not test_map.is_blocked_at(...)`, the same check candidate_steps gets, so scheduled travel
## respects terrain, layout buildings AND player-placed structures with no navmesh anywhere).
##
## Returns `current` itself when already there or when every step toward the target is blocked.
## The no-backtracking limitation is an AUTHORING constraint, not a runtime hazard: see rule 3 in
## the class doc.
##
## `swap_axis` inverts the axis preference for one call. `is_open` only knows about the MAP
## (terrain, layout buildings, placed structures) — it cannot see another NPC or the player
## standing in the next cell, which is a live body the step will physically collide with instead.
## npc.gd sets this after such a collision so the retry tries the other axis and walks AROUND the
## person rather than re-attempting the same blocked direction. Found the hard way: Kael's walk
## home crosses the plaza square Harlan ambles in, and without the swap the two could shove at
## each other for tens of seconds (tools/npc_schedule_smoke.gd's riverside run caught it).
static func next_travel_cell(current: Vector2i, target: Vector2i, is_open: Callable,
		swap_axis := false) -> Vector2i:
	var delta := target - current
	if delta == Vector2i.ZERO:
		return current
	var horizontal := Vector2i(signi(delta.x), 0)
	var vertical := Vector2i(0, signi(delta.y))
	var order: Array[Vector2i] = []
	if (absi(delta.x) >= absi(delta.y)) != swap_axis:
		order.append(horizontal)
		order.append(vertical)
	else:
		order.append(vertical)
		order.append(horizontal)
	for offset in order:
		if offset == Vector2i.ZERO:
			continue
		var cell: Vector2i = current + offset
		if bool(is_open.call(cell)):
			return cell
	return current
