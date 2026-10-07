extends SceneTree
## Headless feature smoke for Phase 7 Stage 2's daily schedules (scripts/npc_schedule.gd +
## scripts/npc.gd) — the "prove it with real frames, not just the pure function" discipline
## tools/sleep_smoke.gd established for the other timing-sensitive feature in this codebase.
## tests/test_npc_schedule.gd already pins current_waypoint()/next_travel_cell() as pure math;
## what this tool proves is the part no pure test can: that a REAL NPC node, in a REAL booted
## zone, walking on REAL physics frames through its own collision-checked one-cell steps,
## actually ends up standing at the cell its schedule names.
##
## Stages:
##   0. BOOT — at 6:00 AM every scheduled NPC stands on its authored home cell (which is also
##      its own 6:00 AM waypoint, per npc_schedule.gd's authoring rule 4). Nothing has moved yet.
##   1. MIDDAY TRAVEL — hold the clock at noon and let real frames run: all four named NPCs walk
##      to their midday waypoints and arrive inside them, each one a genuinely DIFFERENT cell
##      from its home (a schedule that quietly resolved to "stay home" would prove nothing).
##   2. ALIVE AT WORK — an NPC that has arrived keeps ambling inside the waypoint's wander box
##      (it changes cell at least once) and never wanders out of it. "At work" must not mean
##      "frozen statue", and must not mean "drifts off across town" either.
##   3. EVENING RETURN — hold the clock at 11:00 PM and let them walk home again, proving the
##      schedule drives movement in both directions rather than being a one-way boot-time
##      placement.
##   4. UNSCHEDULED REGRESSION — a settler (spawned through the real npcs.spawn_settler path) has
##      no schedule entry, and at the same noon that sends the named four across town it never
##      leaves its own home wander box. This is the check that Stage 2 stayed additive.
##
## Clock convention: scripts/main.gd's _process re-derives DayManager.time_paused from the modal
## gate EVERY frame, so a one-off `time_paused = true` from a tool is overwritten a frame later.
## To hold a time-of-day window steady this tool instead re-teleports minutes_into_day each tick
## (a direct write, which by DayManager's own contract is not "lived" time and fires no
## time_advanced) — the schedule reads that value, so the window stays exactly where we put it.
##
## Run: godot --headless --path . --script res://tools/npc_schedule_smoke.gd
##   WH_SCHEDULE_SMOKE_SETTLEMENT=riverside re-runs it against the riverside zone variants (the
##   town three and Silas are shared verbatim by both variants — see layout_common.gd).

const NpcSchedule := preload("res://scripts/npc_schedule.gd")
const NpcGrid := preload("res://scripts/npc_grid.gd")
const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

## Generous: Kael's watch post is ~25 cells from his home cell, and one scheduled step is a
## 0.3s travel idle plus ~0.67s of walking (16 px at 24 px/s), so a full crossing is ~25s (~1500
## ticks) of real frames — plus however long he spends waiting out other townsfolk standing in
## the plaza he crosses. 90s is well above the worst observed healthy run (~1800 ticks) while
## still failing loudly on a genuine stall.
const MAX_TICKS_PER_STAGE := 5400

## npc_id -> the zone its roster lives in (layout_common.gd's TOWN_NPCS / RANCH_NPCS).
const ZONE_BY_NPC := {
	"mayor_harlan": "town",
	"marta": "town",
	"scout_kael": "town",
	"rancher_silas": "ranch",
}
const NOON := 12 * 60
const LATE_EVENING := 23 * 60
const SETTLER_ID := "schedule_smoke_settler"

var game_state: Node
var day_manager: Node
var main: Node

var stage := 0
var stage_started_at := 0
var checks := 0
var failures: Array[String] = []
## Clock window held steady every tick (see the class doc); -1 leaves the clock alone.
var _hold_minutes := -1
var _settler: Node = null
var _work_cell := Vector2i.ZERO
var _work_moved := false
var _watchdog_tripped := false


func _initialize() -> void:
	day_manager = root.get_node("DayManager")
	game_state = root.get_node("GameState")
	game_state.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	var settlement := OS.get_environment("WH_SCHEDULE_SMOKE_SETTLEMENT")
	game_state.chosen_settlement_id = settlement if settlement != "" else "open_plains"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append("stage %d: %s" % [stage, message])


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()


func _map(zone_id: String) -> Node2D:
	return main.zones[zone_id]["map"]


func _npc(npc_id: String) -> Node:
	var zone: String = String(ZONE_BY_NPC.get(npc_id, "town"))
	for npc in main.zones[zone]["npcs"].npcs():
		if String(npc.npc_id) == npc_id:
			return npc
	return null


## The zone-local cell an NPC currently stands in.
func _cell_of(npc: Node) -> Vector2i:
	return _map(String(ZONE_BY_NPC.get(String(npc.npc_id), "town"))).world_to_cell(
		npc.global_position)


func _waypoint(npc_id: String, minutes: int) -> Vector2i:
	return NpcSchedule.current_waypoint(NpcSchedule.schedule_for(npc_id), float(minutes))


## Whether every named NPC has arrived inside its wander box around the given window's waypoint.
func _all_arrived(minutes: int) -> bool:
	for npc_id in ZONE_BY_NPC:
		var npc: Node = _npc(String(npc_id))
		if npc == null:
			return false
		if not NpcGrid.within_zone(_cell_of(npc), _waypoint(String(npc_id), minutes),
				int(npc.wander_radius)):
			return false
	return true


func _physics_process(_delta: float) -> bool:
	if _hold_minutes >= 0:
		day_manager.minutes_into_day = float(_hold_minutes)
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	if ticks > MAX_TICKS_PER_STAGE and not _watchdog_tripped:
		_watchdog_tripped = true
		_check(false, "TIMED OUT after %d ticks with no stage transition (watchdog)" % ticks)
		_report_positions()
		_finish()
		return true
	match stage:
		0:
			# -- Boot: 6:00 AM, everyone on their authored home cell (== their own first
			#    waypoint), nothing travelled yet --
			if ticks < 10:
				_hold_minutes = int(day_manager.DAY_START_MINUTES)
				return false
			for npc_id in ZONE_BY_NPC:
				var npc: Node = _npc(String(npc_id))
				_check(npc != null, "'%s' spawned in the %s zone" % [npc_id, ZONE_BY_NPC[npc_id]])
				if npc == null:
					continue
				_check(_cell_of(npc) == Vector2i(npc.home),
					"'%s' starts the day on its home cell %s (at %s)"
						% [npc_id, npc.home, _cell_of(npc)])
				_check(_waypoint(String(npc_id), int(day_manager.DAY_START_MINUTES)) \
						== Vector2i(npc.home),
					"'%s' 6:00 AM waypoint IS its home cell" % npc_id)
			_hold_minutes = NOON
			_enter_stage(1)
		1:
			# -- Midday: real frames carry every named NPC to its noon waypoint --
			if not _all_arrived(NOON):
				return false
			for npc_id in ZONE_BY_NPC:
				var npc: Node = _npc(String(npc_id))
				var waypoint := _waypoint(String(npc_id), NOON)
				var cell := _cell_of(npc)
				_check(NpcGrid.within_zone(cell, waypoint, int(npc.wander_radius)),
					"'%s' arrived at its noon waypoint %s (standing at %s)"
						% [npc_id, waypoint, cell])
				_check(waypoint != Vector2i(npc.home),
					"'%s' noon waypoint %s is a different cell from home %s"
						% [npc_id, waypoint, npc.home])
				_check(cell != Vector2i(npc.home),
					"'%s' physically left home (at %s, home %s)" % [npc_id, cell, npc.home])
				print("ARRIVED %s at %s (waypoint %s, home %s)" % [npc_id, cell, waypoint, npc.home])
			_work_cell = _cell_of(_npc("mayor_harlan"))
			_work_moved = false
			_enter_stage(2)
		2:
			# -- Alive at work: ambles inside the waypoint box, never out of it --
			var harlan: Node = _npc("mayor_harlan")
			var cell := _cell_of(harlan)
			var waypoint := _waypoint("mayor_harlan", NOON)
			if not NpcGrid.within_zone(cell, waypoint, int(harlan.wander_radius)):
				_check(false, "Harlan wandered out of his waypoint box: %s (waypoint %s)"
					% [cell, waypoint])
				_finish()
				return true
			if cell != _work_cell:
				_work_moved = true
			if ticks < 900:  # ~15s: several idle windows at the 2-6s amble pause
				return false
			_check(_work_moved,
				"Harlan kept ambling at his waypoint instead of freezing on one cell")
			_check(NpcGrid.within_zone(_cell_of(harlan), waypoint, int(harlan.wander_radius)),
				"Harlan is still inside his waypoint box after 15s of ambling")
			_hold_minutes = LATE_EVENING
			_enter_stage(3)
		3:
			# -- Evening: they walk home again (the schedule drives both directions) --
			if not _all_arrived(LATE_EVENING):
				return false
			for npc_id in ZONE_BY_NPC:
				var npc: Node = _npc(String(npc_id))
				var waypoint := _waypoint(String(npc_id), LATE_EVENING)
				_check(waypoint == Vector2i(npc.home),
					"'%s' last-window waypoint is home %s" % [npc_id, npc.home])
				_check(NpcGrid.within_zone(_cell_of(npc), Vector2i(npc.home),
						int(npc.wander_radius)),
					"'%s' walked home by 11:00 PM (at %s)" % [npc_id, _cell_of(npc)])
				print("HOME %s at %s (home %s)" % [npc_id, _cell_of(npc), npc.home])
			# Spawn the unscheduled control NPC through the real settler-arrival path.
			var home_cell: Vector2i = LayoutCommon.SETTLER_HOME_CELLS[0]
			_settler = main.zones["town"]["npcs"].spawn_settler(SETTLER_ID, home_cell, 1)
			_check(_settler != null, "the control settler spawned into the town roster")
			_check(not NpcSchedule.has_schedule(SETTLER_ID),
				"the control settler has no schedule entry")
			_hold_minutes = NOON  # the window that sends every named NPC across town
			_enter_stage(4)
		4:
			# -- Unscheduled regression: the settler never leaves its own home wander box --
			var settler_cell: Vector2i = _map("town").world_to_cell(_settler.global_position)
			if not NpcGrid.within_zone(settler_cell, Vector2i(_settler.home),
					int(_settler.wander_radius)):
				_check(false, "the unscheduled settler left its home box: %s (home %s)"
					% [settler_cell, _settler.home])
				_finish()
				return true
			if ticks < 900:  # ~15s, the same window the named four cross town in
				return false
			_check(true, "the unscheduled settler stayed in its home wander box all noon")
			_check(_cell_of(_npc("marta")) != Vector2i(_npc("marta").home),
				"...while the scheduled NPCs did leave home in that same window")
			_finish()
			return true
		_:
			pass
	return false


func _report_positions() -> void:
	for npc_id in ZONE_BY_NPC:
		var npc: Node = _npc(String(npc_id))
		if npc == null:
			print("  %s: MISSING" % npc_id)
			continue
		print("  %s: cell %s, home %s, waypoint %s, stepping=%s"
			% [npc_id, _cell_of(npc), npc.home,
				_waypoint(String(npc_id), int(day_manager.minutes_into_day)), npc._stepping])


func _finish() -> void:
	if failures.is_empty():
		print("NPC SCHEDULE SMOKE PASS — %d checks" % checks)
		quit(0)
		return
	for failure in failures:
		print("FAIL: %s" % failure)
	print("NPC SCHEDULE SMOKE FAIL — %d/%d checks failed" % [failures.size(), checks])
	quit(1)
