extends "res://tests/test_case.gd"
## Phase 7 Stage 2 daily schedules (scripts/npc_schedule.gd): the pure time->cell lookup and the
## greedy travel step behind npc.gd's scheduled movement, plus a well-formedness sweep over the
## authored SCHEDULES.
##
## The well-formedness half deliberately re-derives every waypoint's walkability from the REAL
## layout data, through the layout scripts' own is_solid() — the same function the running game
## calls — rather than restating the ASCII ROWS here. A duplicated map in a test can only ever
## prove the test agrees with itself.

const NpcSchedule := preload("res://scripts/npc_schedule.gd")
const NpcGrid := preload("res://scripts/npc_grid.gd")
const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")
const DayManager := preload("res://scripts/day_manager.gd")

const TownStandard := preload("res://scripts/map_layouts/town_layout_standard.gd")
const TownRiverside := preload("res://scripts/map_layouts/town_layout_riverside.gd")
const RanchStandard := preload("res://scripts/map_layouts/ranch_layout_standard.gd")
const RanchRiverside := preload("res://scripts/map_layouts/ranch_layout_riverside.gd")

## Every layout variant each scheduled NPC actually appears in. The town three and Silas are
## declared ONCE in layout_common.gd's TOWN_NPCS/RANCH_NPCS and reused verbatim by both variants
## of their zone, so a waypoint has to be open ground in every file listed here — a cell that is
## grass in the standard variant and river in the riverside one is not a legal waypoint.
const VARIANTS_BY_ZONE := {
	"town": [TownStandard, TownRiverside],
	"ranch": [RanchStandard, RanchRiverside],
}

## Always-open / always-blocked step predicates for the pure travel tests.
static func _all_open(_cell: Vector2i) -> bool:
	return true


static func _all_blocked(_cell: Vector2i) -> bool:
	return false


func _sample_schedule() -> Array:
	return [
		{"start_minutes": 360, "cell": Vector2i(1, 1)},    # 6:00 AM
		{"start_minutes": 600, "cell": Vector2i(2, 2)},    # 10:00 AM
		{"start_minutes": 1200, "cell": Vector2i(3, 3)},   # 8:00 PM
	]


# -- current_waypoint(): the pure lookup ------------------------------------------------------

func test_before_first_entry_wraps_to_the_last_entry() -> void:
	# 2:00 AM is the TAIL of the evening the NPC is still living, not the head of a day that
	# hasn't started — so the answer is the day's FINAL waypoint, not its first.
	var schedule := _sample_schedule()
	assert_eq(NpcSchedule.current_waypoint(schedule, 120.0), Vector2i(3, 3),
		"2:00 AM (before the 6:00 AM first entry) wraps to the 8:00 PM cell")
	assert_eq(NpcSchedule.current_waypoint(schedule, 0.0), Vector2i(3, 3),
		"midnight wraps to the last entry too")
	assert_eq(NpcSchedule.current_waypoint(schedule, 359.0), Vector2i(3, 3),
		"one minute before the first entry still wraps")


func test_exact_boundary_minute_uses_that_entry() -> void:
	var schedule := _sample_schedule()
	assert_eq(NpcSchedule.current_waypoint(schedule, 360.0), Vector2i(1, 1),
		"exactly 6:00 AM is the 6:00 AM entry, not the wrap")
	assert_eq(NpcSchedule.current_waypoint(schedule, 600.0), Vector2i(2, 2),
		"exactly 10:00 AM is the 10:00 AM entry, not the 6:00 AM one")
	assert_eq(NpcSchedule.current_waypoint(schedule, 1200.0), Vector2i(3, 3),
		"exactly 8:00 PM is the 8:00 PM entry")


func test_between_entries_picks_the_earlier_one() -> void:
	var schedule := _sample_schedule()
	assert_eq(NpcSchedule.current_waypoint(schedule, 599.0), Vector2i(1, 1),
		"one minute before 10:00 AM is still the 6:00 AM cell")
	assert_eq(NpcSchedule.current_waypoint(schedule, 900.0), Vector2i(2, 2),
		"3:00 PM sits in the 10:00 AM window")
	assert_eq(NpcSchedule.current_waypoint(schedule, 1439.0), Vector2i(3, 3),
		"11:59 PM is still in the last window")


func test_single_entry_schedule_always_returns_that_cell() -> void:
	var schedule: Array = [{"start_minutes": 720, "cell": Vector2i(7, 7)}]
	for minutes in [0.0, 1.0, 719.0, 720.0, 721.0, 1439.0]:
		assert_eq(NpcSchedule.current_waypoint(schedule, float(minutes)), Vector2i(7, 7),
			"a one-waypoint schedule answers the same cell at minute %s" % minutes)


func test_empty_schedule_returns_zero_and_is_never_a_sentinel() -> void:
	# Documented behaviour: (0,0) is a real cell, so callers gate on has_schedule(), never on
	# the returned value. This test pins the documented answer so it can't drift silently.
	assert_eq(NpcSchedule.current_waypoint([], 720.0), Vector2i.ZERO,
		"an empty schedule answers Vector2i.ZERO")
	assert_false(NpcSchedule.has_schedule("settler_1"),
		"an unscheduled npc_id is excluded by has_schedule, not by its waypoint value")
	assert_true(NpcSchedule.schedule_for("settler_1").is_empty(),
		"schedule_for() on an unscheduled npc_id is safe to pass to current_waypoint")


func test_out_of_order_entries_still_resolve_to_the_latest_match() -> void:
	# Authored schedules are ascending (enforced below), but the scan is order-independent so a
	# future hand-edit that breaks the order degrades to the right answer, not to nonsense.
	var schedule: Array = [
		{"start_minutes": 1200, "cell": Vector2i(3, 3)},
		{"start_minutes": 360, "cell": Vector2i(1, 1)},
	]
	assert_eq(NpcSchedule.current_waypoint(schedule, 900.0), Vector2i(1, 1),
		"3:00 PM still resolves to the 6:00 AM entry")
	assert_eq(NpcSchedule.current_waypoint(schedule, 60.0), Vector2i(3, 3),
		"1:00 AM still wraps to the greatest start_minutes, wherever it sits in the array")


# -- next_travel_cell(): the greedy one-cell walk ---------------------------------------------

func test_travel_step_takes_the_longer_axis_first() -> void:
	var step := NpcSchedule.next_travel_cell(Vector2i(5, 5), Vector2i(10, 7), _all_open)
	assert_eq(step, Vector2i(6, 5), "dx 5 > dy 2, so the step is east")
	var step_v := NpcSchedule.next_travel_cell(Vector2i(5, 5), Vector2i(6, 1), _all_open)
	assert_eq(step_v, Vector2i(5, 4), "dy 4 > dx 1, so the step is north")


func test_travel_step_is_one_cell_and_cardinal() -> void:
	var step := NpcSchedule.next_travel_cell(Vector2i(5, 5), Vector2i(9, 9), _all_open)
	var delta := step - Vector2i(5, 5)
	assert_eq(absi(delta.x) + absi(delta.y), 1, "a travel step is exactly one cardinal cell")


func test_travel_step_falls_back_to_the_other_axis_when_blocked() -> void:
	# A building corner between the NPC and its waypoint: the preferred (longer) axis is walled
	# off, so the step detours along the other axis rather than stalling.
	var blocked := {Vector2i(6, 5): true}
	var is_open := func(cell: Vector2i) -> bool: return not blocked.has(cell)
	var step := NpcSchedule.next_travel_cell(Vector2i(5, 5), Vector2i(10, 7), is_open)
	assert_eq(step, Vector2i(5, 6), "east is blocked, so the step goes south toward the target")


func test_travel_step_stays_put_when_boxed_in_or_arrived() -> void:
	assert_eq(NpcSchedule.next_travel_cell(Vector2i(5, 5), Vector2i(10, 7), _all_blocked),
		Vector2i(5, 5), "every step toward the target blocked -> stay put and retry later")
	assert_eq(NpcSchedule.next_travel_cell(Vector2i(4, 4), Vector2i(4, 4), _all_open),
		Vector2i(4, 4), "already at the target -> no step")


func test_travel_step_swap_axis_leads_with_the_other_axis() -> void:
	# npc.gd sets swap_axis after a travel step is bounced by a live BODY (another NPC / the
	# player), which `is_open` can't see — the retry must then try the other way around them.
	var step := NpcSchedule.next_travel_cell(Vector2i(5, 5), Vector2i(10, 7), _all_open, true)
	assert_eq(step, Vector2i(5, 6),
		"swapped: the longer axis (east) yields to the shorter one (south)")
	var step_v := NpcSchedule.next_travel_cell(Vector2i(5, 5), Vector2i(6, 1), _all_open, true)
	assert_eq(step_v, Vector2i(6, 5), "swapped: the longer axis (north) yields to east")


func test_travel_step_swap_axis_still_respects_blocked_cells() -> void:
	# The swap is only a PREFERENCE — it must never produce a step into a solid cell.
	var blocked := {Vector2i(5, 6): true}
	var is_open := func(cell: Vector2i) -> bool: return not blocked.has(cell)
	assert_eq(NpcSchedule.next_travel_cell(Vector2i(5, 5), Vector2i(10, 7), is_open, true),
		Vector2i(6, 5), "swapped preference is blocked, so it falls back to the other axis")


func test_travel_step_on_a_pure_axis_never_wanders_sideways() -> void:
	# dy == 0: the only legal offsets are along x, so a blocked x must NOT produce a y step.
	var blocked := {Vector2i(6, 5): true}
	var is_open := func(cell: Vector2i) -> bool: return not blocked.has(cell)
	assert_eq(NpcSchedule.next_travel_cell(Vector2i(5, 5), Vector2i(9, 5), is_open),
		Vector2i(5, 5), "a straight-line approach with the next cell blocked just waits")


# -- Well-formedness of the authored SCHEDULES ------------------------------------------------

## npc_id -> the roster entry (home/wander_radius) layout_common.gd declares for it, plus which
## zone it lives in. Derived from the real TOWN_NPCS/RANCH_NPCS arrays, never restated.
func _roster() -> Dictionary:
	var out := {}
	for entry in LayoutCommon.TOWN_NPCS:
		out[String(entry["id"])] = {"zone": "town", "entry": entry}
	for entry in LayoutCommon.RANCH_NPCS:
		out[String(entry["id"])] = {"zone": "ranch", "entry": entry}
	return out


func test_schedules_cover_exactly_the_named_npcs() -> void:
	var roster := _roster()
	assert_eq(NpcSchedule.SCHEDULES.size(), 7, "the 7 named NPCs are scheduled (Milestone B added 3)")
	for npc_id in NpcSchedule.SCHEDULES:
		assert_true(roster.has(String(npc_id)),
			"scheduled npc '%s' is a real roster NPC" % npc_id)
	for npc_id in roster:
		assert_true(NpcSchedule.has_schedule(String(npc_id)),
			"roster NPC '%s' has a schedule" % npc_id)


func test_every_schedule_is_ascending_and_starts_at_home_at_6am() -> void:
	var roster := _roster()
	for npc_id in NpcSchedule.SCHEDULES:
		var schedule: Array = NpcSchedule.SCHEDULES[npc_id]
		assert_true(schedule.size() >= 2 and schedule.size() <= 4,
			"'%s' has 2-4 waypoints (got %d)" % [npc_id, schedule.size()])
		var previous := -1
		for entry in schedule:
			var start := int(entry["start_minutes"])
			assert_true(start > previous,
				"'%s' entries ascend by start_minutes (%d after %d)" % [npc_id, start, previous])
			assert_true(start >= 0 and start < DayManager.MINUTES_PER_DAY,
				"'%s' start_minutes %d is a real minute-into-day" % [npc_id, start])
			previous = start
		assert_eq(int(schedule[0]["start_minutes"]), DayManager.DAY_START_MINUTES,
			"'%s' opens at 6:00 AM, the minute the day starts" % npc_id)
		var home: Vector2i = roster[String(npc_id)]["entry"]["home"]
		assert_eq(Vector2i(schedule[0]["cell"]), home,
			"'%s' starts the day on the home cell it actually spawns at" % npc_id)


func test_every_waypoint_is_open_ground_in_every_variant_that_npc_appears_in() -> void:
	# The load-bearing check of this stage: read the REAL ROWS through each layout's own
	# is_solid() (terrain chars + building footprints), the exact call the running game makes.
	var roster := _roster()
	for npc_id in NpcSchedule.SCHEDULES:
		var zone: String = roster[String(npc_id)]["zone"]
		for variant in VARIANTS_BY_ZONE[zone]:
			for entry in NpcSchedule.SCHEDULES[npc_id]:
				var cell: Vector2i = entry["cell"]
				assert_false(variant.is_solid(cell.x, cell.y),
					"'%s' waypoint %s (%d min) is open ground in a %s variant"
						% [npc_id, cell, int(entry["start_minutes"]), zone])
				var bounds: Vector2i = variant.size()
				assert_true(cell.x > 0 and cell.y > 0 \
						and cell.x < bounds.x - 1 and cell.y < bounds.y - 1,
					"'%s' waypoint %s is inside the %s map's perimeter" % [npc_id, cell, zone])


func test_waypoint_wander_boxes_stay_disjoint_from_every_other_npc_zone() -> void:
	# On arrival an NPC wanders around the WAYPOINT, so each waypoint inherits TOWN_NPCS'
	# disjointness rule (overlapping wander boxes previously made runtime_smoke pick up the wrong
	# NPC at a shared boundary cell). Two radius-r boxes are disjoint iff their centers differ by
	# more than r on at least one axis.
	var roster := _roster()
	var boxes := {"town": [], "ranch": []}  # each: {id, cell, radius}
	for npc_id in roster:
		var entry: Dictionary = roster[String(npc_id)]["entry"]
		var zone: String = roster[String(npc_id)]["zone"]
		var radius := int(entry.get("wander_radius", 2))
		var cells: Array[Vector2i] = [entry["home"]]
		for wp in NpcSchedule.schedule_for(String(npc_id)):
			if not cells.has(Vector2i(wp["cell"])):
				cells.append(Vector2i(wp["cell"]))
		for cell in cells:
			boxes[zone].append({"id": String(npc_id), "cell": cell, "radius": radius})
	# Settler home cells share the Town plaza and get the same treatment (radius 1, per
	# layout_common.gd's SETTLER_HOME_CELLS doc).
	for cell in LayoutCommon.SETTLER_HOME_CELLS:
		boxes["town"].append({"id": "settler_slot", "cell": cell, "radius": 1})
	for zone in boxes:
		var zone_boxes: Array = boxes[zone]
		for i in zone_boxes.size():
			for j in range(i + 1, zone_boxes.size()):
				var a: Dictionary = zone_boxes[i]
				var b: Dictionary = zone_boxes[j]
				if String(a["id"]) == String(b["id"]):
					continue  # one NPC's own waypoints may sit near each other
				var reach: int = int(a["radius"]) + int(b["radius"])
				var delta: Vector2i = Vector2i(a["cell"]) - Vector2i(b["cell"])
				assert_true(absi(delta.x) > reach or absi(delta.y) > reach,
					"%s's box at %s and %s's box at %s must not overlap (%s zone)"
						% [a["id"], a["cell"], b["id"], b["cell"], zone])


func test_every_authored_route_is_walkable_by_the_greedy_travel_step() -> void:
	# next_travel_cell() has no backtracking, so every consecutive waypoint pair (including the
	# night wrap from the last entry back to the first) must be reachable by repeatedly stepping
	# toward the target through cells the real layout calls open — in EVERY variant. This is the
	# runtime consequence of authoring rule 3 in npc_schedule.gd's class doc; without it a bad
	# waypoint pair would only show up as an NPC quietly stuck against a wall in-game.
	var roster := _roster()
	for npc_id in NpcSchedule.SCHEDULES:
		var zone: String = roster[String(npc_id)]["zone"]
		var schedule: Array = NpcSchedule.SCHEDULES[npc_id]
		for variant in VARIANTS_BY_ZONE[zone]:
			var is_open := func(cell: Vector2i) -> bool: return not variant.is_solid(cell.x, cell.y)
			for i in schedule.size():
				var from: Vector2i = schedule[i]["cell"]
				var to: Vector2i = schedule[(i + 1) % schedule.size()]["cell"]
				var at := from
				var guard := 0
				while at != to and guard < 200:
					var next_cell: Vector2i = NpcSchedule.next_travel_cell(at, to, is_open)
					if next_cell == at:
						break
					at = next_cell
					guard += 1
				assert_eq(at, to,
					"'%s' can walk %s -> %s in a %s variant (reached %s)"
						% [npc_id, from, to, zone, at])


func test_arrival_uses_the_same_box_the_wander_uses() -> void:
	# npc.gd treats "within wander_radius of the waypoint" as arrived and hands back over to
	# NpcGrid's wander around that cell — this pins the two definitions together so a future
	# change to one can't silently desync from the other.
	var waypoint := Vector2i(16, 4)
	assert_true(NpcGrid.within_zone(Vector2i(15, 5), waypoint, 1),
		"a diagonal neighbour of the waypoint counts as arrived at radius 1")
	assert_false(NpcGrid.within_zone(Vector2i(14, 4), waypoint, 1),
		"two cells out is still travelling")
