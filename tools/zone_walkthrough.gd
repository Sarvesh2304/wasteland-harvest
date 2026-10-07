extends SceneTree
## Windowed end-to-end walk-through of the zone cluster (Stage 1 verification's "manual"
## pass, driven through the REAL input actions — the same Input.action_press convention as
## tools/held_input_smoke.gd): boots scenes/main.tscn on Open Plains and physically WALKS the
## player Farm → Ranch → Farm → Path → Town → Path → Farm through every gate (no teleports —
## teleport-onto-gate coverage lives in tools/zone_transition_smoke.gd), while asserting every
## physics frame that:
##   - the player never leaves the ACTIVE zone's world-space map rect (the "no way to walk off
##     any zone's edge into the void" guarantee — this is what the new perimeter wall rows
##     exist for);
##   - the camera center never leaves its clamp bounds (no camera glitches at the snap-cuts).
## Captures a screenshot at each zone arrival for the visual record. Exactly 6 transitions are
## expected over the route. Waypoints deliberately dodge every NPC wander zone (radius-1 zones
## around authored homes) so the walk can't get stuck on a townsperson.
##
## Run (windowed — rendering must be real for the camera/visual half):
##   WH_SHOT_DIR=/abs/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/zone_walkthrough.gd

const SAVE_PATH := "user://zone_walkthrough_save.json"

## [zone_id, cell] — consecutive same-zone waypoints are axis-aligned; gate cells warp.
## Re-routed for the 2026-08-09 ranch relocation (the Ranch hangs off the FARM's south gate now,
## and the Town is a dead end reached only through the Path). Still exactly 6 transitions, but
## the shape changed from a linear out-and-back chain to two spurs off the farm:
##   Farm -> Ranch -> Farm  (south gate, out and back)
##   Farm -> Path -> Town -> Path -> Farm  (east gate, out and back)
## Every cell below was re-verified against the authored Open Plains / Ranch / Path / Town ROWS:
## resource nodes ('T'/'O') get real StaticBody2D collision (farm.gd's _spawn_resource_prop), so
## the L-shaped legs the mover walks are kept off every one of them, and off all three town NPCs'
## radius-1 wander zones.
const WAYPOINTS := [
	# -- Spur 1: out the farm's south gate to the Ranch and back --
	["farm", Vector2i(35, 5)],   # east along the homestead row to the south gate's column
	["farm", Vector2i(35, 30)],  # straight down column 35, through the field, to the wall
	["farm", Vector2i(35, 31)],  # south gate -> ranch, arriving at (17,16)
	# The compound's own south wall (row 15) is solid, so the way in from the new gate is round
	# the perimeter yard: west along row 16, north up the x1-4 corridor, east across the north
	# yard, then south through the cosmetic inner gate at (17,4). Flagged as a UX wart in
	# ranch_layout_standard.gd's class doc; walked here exactly as a player would have to.
	["ranch", Vector2i(3, 16)],
	["ranch", Vector2i(3, 2)],
	["ranch", Vector2i(17, 2)],
	["ranch", Vector2i(17, 7)],  # through the cosmetic inner compound gate into the yard
	["ranch", Vector2i(17, 2)],  # and back out the same way (Silas's wander zone never entered)
	["ranch", Vector2i(3, 2)],
	["ranch", Vector2i(3, 16)],
	["ranch", Vector2i(17, 16)],
	["ranch", Vector2i(17, 17)],  # south gate -> farm, arriving at (35,30)
	# -- Spur 2: out the farm's east gate to the Path and the Town, and back --
	["farm", Vector2i(70, 30)],  # east along the open row 30, south of the field
	["farm", Vector2i(70, 15)],  # north up the clear column 70 to the east gate's row
	["farm", Vector2i(71, 15)],  # east gate -> path
	["path", Vector2i(22, 4)],
	["path", Vector2i(23, 4)],   # east gate -> town
	["town", Vector2i(2, 6)],
	["town", Vector2i(15, 6)],
	["town", Vector2i(15, 14)],  # down the plaza's clear column, west of the pond
	["town", Vector2i(2, 14)],   # along the resealed south wall — no gate there any more
	["town", Vector2i(2, 4)],
	["town", Vector2i(0, 4)],    # west gate -> path
	["path", Vector2i(1, 4)],
	["path", Vector2i(0, 4)],    # west gate -> farm
	["farm", Vector2i(50, 15)],
]

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var camera: Camera2D
var zone_fade: CanvasLayer

var waypoint_index := 0
var waypoint_started_at := 0
var transitions := 0
var last_zone := "farm"
var checks := 0
var failures := 0
var started := false
var start_frame := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	game_state = root.get_node("GameState")
	game_state.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	day_manager = root.get_node("DayManager")
	game_state.save_path = SAVE_PATH
	game_state.delete_save()
	game_state.chosen_settlement_id = "open_plains"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	player = main.get_node("Player")
	camera = main.get_node("GameCamera")
	zone_fade = main.get_node("ZoneFade")
	start_frame = int(Engine.get_physics_frames())


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: %s" % label)


func _release_all() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)


func _finish() -> void:
	_release_all()
	game_state.delete_save()
	_check(transitions == 6, "exactly 6 zone transitions over the route (got %d)" % transitions)
	if failures == 0:
		print("WALKTHROUGH PASS — %d checks, %d transitions" % [checks, transitions])
		quit(0)
	else:
		print("WALKTHROUGH FAIL — %d/%d checks failed" % [failures, checks])
		quit(1)


func _physics_process(_delta: float) -> bool:
	var frames := int(Engine.get_physics_frames()) - start_frame
	if frames < 10:
		return false
	if not started:
		started = true
		day_manager.time_paused = true
		waypoint_started_at = frames
	# -- Per-frame invariants --
	if player.current_zone_id != last_zone:
		transitions += 1
		last_zone = player.current_zone_id
		_capture("walk_%02d_arrive_%s.png" % [transitions, last_zone])
	var zone_map: Node2D = main.zones[player.current_zone_id]["map"]
	if not bool(zone_fade.playing):
		var rect: Rect2 = zone_map.get_global_map_rect().grow(4.0)
		_check_silent(rect.has_point(player.global_position),
			"player inside %s bounds (at %s)" % [player.current_zone_id, player.global_position])
		var bounds: Rect2 = camera._map_bounds
		_check_silent(bounds.grow(4.0).has_point(camera.global_position),
			"camera center inside clamp bounds")
	# -- Waypoint walking --
	if waypoint_index >= WAYPOINTS.size():
		_finish()
		return false
	if frames - waypoint_started_at > 60 * 20:
		# Include where the player actually got stuck: a bare "waypoint N timed out" cost a whole
		# extra instrumented re-run to diagnose the corridor deadlock described below.
		_check(false, "waypoint %d timed out (target %s, stuck in %s at cell %s / %s)"
			% [waypoint_index, WAYPOINTS[waypoint_index], player.current_zone_id,
				zone_map.world_to_cell(player.global_position), player.global_position])
		_finish()
		return false
	var wp: Array = WAYPOINTS[waypoint_index]
	var wp_zone := String(wp[0])
	if player.current_zone_id != wp_zone:
		# Mid-transition (or just crossed): stop pushing, skip forward to this zone's waypoints.
		if bool(zone_fade.playing):
			_release_all()
			return false
		for i in range(waypoint_index, WAYPOINTS.size()):
			if String(WAYPOINTS[i][0]) == player.current_zone_id:
				waypoint_index = i
				waypoint_started_at = frames
				return false
		_check(false, "landed in %s with no remaining waypoints there" % player.current_zone_id)
		_finish()
		return false
	var target: Vector2 = main.zones[wp_zone]["map"].get_global_cell_center(Vector2i(wp[1]))
	var delta := target - player.global_position
	# Arrival needs the player NEAR the target cell's center on both axes, not merely somewhere
	# inside the cell. The old rule ("world_to_cell() == the waypoint") ended a leg the instant the
	# player's ORIGIN crossed the cell boundary, leaving it up to 7.5px off-center — and the
	# collision box is a 10x6 "feet" rect offset (0,2), so its top edge then sits ~0.5px inside the
	# PREVIOUS row. That is invisible in an open field and fatal in a one-cell-tall corridor: the
	# 2026-08-09 ranch relocation's route runs the compound's south yard (row 16, solid compound
	# wall above at row 15, perimeter wall below at row 17), and the player descending the west
	# corridor stopped at y-offset 0.53 into row 16, then deadlocked against the (5,15) fence
	# corner the moment it pushed east — a purely horizontal push into a vertical face slides
	# nowhere. A 5px window is well inside the 8px half-cell (so it still implies the right cell)
	# and is always reachable: the mover below drives the dominant axis under 3px first, then the
	# other, and neither undoes the other.
	if delta.length() < 3.0 or (absf(delta.x) < 5.0 and absf(delta.y) < 5.0):
		_release_all()
		waypoint_index += 1
		waypoint_started_at = frames
		return false
	_release_all()
	if absf(delta.x) >= 3.0:
		Input.action_press("move_right" if delta.x > 0.0 else "move_left")
	else:
		Input.action_press("move_down" if delta.y > 0.0 else "move_up")
	return false


## Bounds checks run every frame — report each failure site once, not 60x/second.
var _reported := {}
func _check_silent(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		var key := label.get_slice("(", 0)
		if _reported.has(key):
			return
		_reported[key] = true
		failures += 1
		print("FAIL: %s" % label)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
