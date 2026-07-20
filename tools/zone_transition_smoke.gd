extends SceneTree
## Headless smoke test for the Farm/Path/Town/Ranch zone-transition system (Stage 1 of the
## zone split — see the zone-transition plan's Verification section). Boots the real
## scenes/main.tscn (Open Plains) and drives, via the real physics/input paths:
##
##   1. All SIX gate-cell crossings (Farm↔Path, Path↔Town, Town↔Ranch — 3 pairs, both
##      directions), each by placing the player ON the authored gate cell and letting
##      player.gd's own _physics_process detection + zone_fade + main._bind_zone run the warp.
##      After each: current_zone_id changed, position == the target zone's
##      get_global_cell_center(entry_cell), camera clamp bounds moved to the target zone's
##      global rect, player.structures/player.npcs point at the target zone's nodes, and
##      zone_exit_requested fired EXACTLY once (zone_fade.play_count/rejected_count agree).
##   2. The held-movement-key regression for player.gd's _zone_transitioning guard: walk into
##      the Farm east gate with "move_right" physically held down through the ENTIRE crossing
##      (never released at the boundary), asserting the exit signal still fired exactly once
##      and zone_fade.play() was never re-entered mid-tween — the bug this catches (a re-emit
##      during the fade's still-on-the-gate-cell window) wouldn't show up if input were
##      conveniently released at the gate.
##   3. A save→reload round trip from INSIDE Town: place a Storage Shed blueprint there, save
##      via the exact GameState.save_game(player, zones) call the menu/bed use, tear the whole
##      scene down, reload from disk into a fresh main.tscn, and confirm the shed persisted in
##      the TOWN zone (not any other), along with the player's zone/position.
##
## Run: godot --headless --path . --script res://tools/zone_transition_smoke.gd
## Uses test-only save locations (wiped before and after), never the real user:// slots —
## the same never-inherit/never-leave-stale-state rule every other smoke tool follows.

const SAVE_PATH := "user://zone_smoke_save.json"

## The six crossings, in walk order: [from_zone, gate cell (from-zone-local), to_zone,
## expected entry cell (to-zone-local)] — mirrors the layouts' authored zone_exits().
const CROSSINGS := [
	["farm", Vector2i(35, 4), "path", Vector2i(1, 4)],
	["path", Vector2i(23, 4), "town", Vector2i(1, 4)],
	["town", Vector2i(17, 16), "ranch", Vector2i(17, 1)],
	["ranch", Vector2i(17, 0), "town", Vector2i(17, 15)],
	["town", Vector2i(0, 4), "path", Vector2i(22, 4)],
	["path", Vector2i(0, 4), "farm", Vector2i(34, 4)],
]

## Town cell for the round-trip Storage Shed (open plaza grass, clear of every authored
## building/gate in both town variants).
const SHED_CELL := Vector2i(5, 8)

var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var camera: Camera2D
var zone_fade: CanvasLayer

var _settlement_id := "open_plains"
var stage := 0
var stage_started_at := 0
var crossing_index := 0
var exit_signal_count := 0
var checks := 0
var failures := 0


func _initialize() -> void:
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.save_path = SAVE_PATH
	game_state.delete_save()
	# Default Open Plains; WH_ZONE_SMOKE_SETTLEMENT=riverside re-runs the identical script
	# against the riverside zone variants (same gate/entry coordinates by design — the variants
	# differ in terrain only: river west columns, the Path's plank bridge).
	var settlement := OS.get_environment("WH_ZONE_SMOKE_SETTLEMENT")
	game_state.chosen_settlement_id = settlement if settlement != "" else "open_plains"
	_settlement_id = game_state.chosen_settlement_id
	_boot_main()


func _boot_main() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	player = main.get_node("Player")
	camera = main.get_node("GameCamera")
	zone_fade = main.get_node("ZoneFade")
	player.zone_exit_requested.connect(func(_z: String, _c: Vector2i) -> void:
		exit_signal_count += 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: %s" % label)


func _fatal(label: String) -> void:
	print("FAIL (fatal): %s" % label)
	print("ZONE SMOKE FAIL — %d/%d checks failed" % [failures + 1, checks + 1])
	quit(1)


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()


func _zone(zone_id: String) -> Dictionary:
	return main.zones[zone_id]


func _map(zone_id: String) -> Node2D:
	return _zone(zone_id)["map"]


## Post-warp assertions shared by every crossing. exact_position is false only for the
## held-key stage: releasing the _zone_transitioning guard at the fade's black midpoint is BY
## DESIGN (see player.gd), so a still-held movement key legitimately walks the player a few
## pixels off the entry cell before this assertion runs — there we assert proximity instead.
func _assert_arrival(to_zone: String, entry_cell: Vector2i, label: String,
		expected_exit_count: int, expected_play_count: int, exact_position := true) -> void:
	_check(player.current_zone_id == to_zone, "%s: current_zone_id is %s" % [label, to_zone])
	var expected: Vector2 = _map(to_zone).get_global_cell_center(entry_cell)
	var tolerance := 1.0 if exact_position else 40.0
	_check(player.global_position.distance_to(expected) < tolerance,
		"%s: player at/near %s's entry cell %s (got %s, expected %s)"
			% [label, to_zone, entry_cell, player.global_position, expected])
	_check(camera._map_bounds == _map(to_zone).get_global_map_rect(),
		"%s: camera clamp bounds moved to %s" % [label, to_zone])
	_check(player.structures == _zone(to_zone)["structures"],
		"%s: player.structures points at %s's node" % [label, to_zone])
	_check(player.npcs == _zone(to_zone)["npcs"],
		"%s: player.npcs points at %s's node" % [label, to_zone])
	_check(player.test_map == _map(to_zone), "%s: player.test_map is %s's map" % [label, to_zone])
	_check(exit_signal_count == expected_exit_count,
		"%s: zone_exit_requested fired exactly once for this crossing (total %d, expected %d)"
			% [label, exit_signal_count, expected_exit_count])
	_check(zone_fade.play_count == expected_play_count,
		"%s: zone_fade.play accepted exactly once (total %d, expected %d)"
			% [label, zone_fade.play_count, expected_play_count])
	_check(zone_fade.rejected_count == 0,
		"%s: zone_fade.play never re-entered mid-tween (rejected %d)"
			% [label, zone_fade.rejected_count])


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	if ticks > 600:
		_fatal("stage %d timed out" % stage)
		return false
	match stage:
		0:
			# -- Boot: fresh game lands on the farm spawn, camera clamped to the farm --
			if ticks < 10:
				return false
			day_manager.time_paused = true  # freeze the clock: no pass-out mid-run
			_check(player.current_zone_id == "farm", "boot: current zone is farm")
			var spawn: Vector2 = _map("farm").to_global(_map("farm").get_spawn_position())
			_check(player.global_position.distance_to(spawn) < 1.0, "boot: player at farm spawn")
			_check(camera._map_bounds == _map("farm").get_global_map_rect(),
				"boot: camera clamped to farm")
			_check(zone_fade.play_count == 0, "boot: no fade played yet (boot binds unfaded)")
			_enter_stage(1)
		1:
			# -- The six crossings: teleport onto each gate cell, let the real detection warp us --
			if crossing_index >= CROSSINGS.size():
				_enter_stage(2)
				return false
			var crossing: Array = CROSSINGS[crossing_index]
			var from_zone := String(crossing[0])
			if ticks == 0 or ticks == 1:
				return false  # settle a frame between crossings
			if ticks == 2:
				_check(player.current_zone_id == from_zone,
					"crossing %d starts in %s" % [crossing_index, from_zone])
				player.velocity = Vector2.ZERO
				player.global_position = _map(from_zone).get_global_cell_center(Vector2i(crossing[1]))
				return false
			# Wait for the full warp (detection frame + ~0.15s fade) to finish.
			if player.current_zone_id == String(crossing[2]) and not zone_fade.playing \
					and ticks > 12:
				_assert_arrival(String(crossing[2]), Vector2i(crossing[3]),
					"crossing %d (%s->%s)" % [crossing_index, from_zone, String(crossing[2])],
					crossing_index + 1, crossing_index + 1)
				crossing_index += 1
				_enter_stage(1)
			return false
		2:
			# -- Held-key regression: walk into the Farm east gate with move_right held the
			#    whole way through (we ended stage 1 back on the farm at (34,4), one cell west
			#    of the gate) --
			if ticks == 0:
				return false
			if ticks == 1:
				Input.action_press("move_right")
				return false
			if player.current_zone_id == "path" and not zone_fade.playing and ticks > 20:
				# Key STILL held here — the entire fade ran with the gate cell underfoot.
				_assert_arrival("path", Vector2i(1, 4), "held-key crossing", 7, 7, false)
				_enter_stage(3)
			return false
		3:
			# Keep the key held a little longer in the new zone (proves arrival under held
			# input doesn't re-trigger anything), then release.
			if ticks < 20:
				return false
			_check(exit_signal_count == 7, "held key after arrival: still exactly 7 exit signals")
			_check(zone_fade.rejected_count == 0, "held key: no rejected fade plays")
			Input.action_release("move_right")
			_enter_stage(4)
		4:
			# -- Save round trip: bind into town, place a Storage Shed, save, tear down, reload --
			if ticks < 5:
				return false
			main._bind_zone("town", Vector2i(5, 5))  # direct bind: the gate path is already proven
			var town_structures: Node = _zone("town")["structures"]
			var placed: bool = town_structures.place_blueprint("storage_shed", SHED_CELL)
			_check(placed, "roundtrip: Storage Shed blueprint placed in town at %s" % SHED_CELL)
			_check(bool(game_state.save_game(player, main.zones, main.get_node("Settlers"))),
				"roundtrip: save written")
			# Tear down and deliberately scramble state a reload must restore.
			root.remove_child(main)
			main.free()
			game_state.chosen_settlement_id = \
				"riverside" if _settlement_id != "riverside" else "open_plains"
			_check(bool(game_state.load_save_from_disk()), "roundtrip: save re-read from disk")
			_check(game_state.chosen_settlement_id == _settlement_id,
				"roundtrip: settlement restored from the save")
			_boot_main()
			exit_signal_count = 0
			_enter_stage(5)
		5:
			if ticks < 10:
				return false
			_check(player.current_zone_id == "town", "roundtrip: reloaded into the town zone")
			var expected: Vector2 = _map("town").get_global_cell_center(Vector2i(5, 5))
			_check(player.global_position.distance_to(expected) < 1.0,
				"roundtrip: player position restored (got %s)" % player.global_position)
			_check(camera._map_bounds == _map("town").get_global_map_rect(),
				"roundtrip: camera clamped to town after reload")
			var town_pending: Array = _zone("town")["structures"]._pending
			_check(town_pending.size() == 1 and Vector2i(town_pending[0]["top_left"]) == SHED_CELL,
				"roundtrip: the shed blueprint persisted in the TOWN zone")
			for other in ["farm", "path", "ranch"]:
				_check((_zone(other)["structures"]._pending as Array).is_empty(),
					"roundtrip: no stray blueprint leaked into %s" % other)
			game_state.delete_save()
			if failures == 0:
				print("ZONE SMOKE PASS — %d checks" % checks)
				quit(0)
			else:
				print("ZONE SMOKE FAIL — %d/%d checks failed" % [failures, checks])
				quit(1)
		_:
			pass
	return false
