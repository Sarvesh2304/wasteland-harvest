extends SceneTree
## Windowed end-to-end walk-through of the zone cluster (Stage 1 verification's "manual"
## pass, driven through the REAL input actions — the same Input.action_press convention as
## tools/held_input_smoke.gd): boots scenes/main.tscn on Open Plains and physically WALKS the
## player Farm → Path → Town → Ranch → Town → Path → Farm through every gate (no teleports —
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
const WAYPOINTS := [
	["farm", Vector2i(34, 5)],
	["farm", Vector2i(35, 5)],   # east gate -> path
	["path", Vector2i(22, 4)],
	["path", Vector2i(23, 4)],   # east gate -> town
	["town", Vector2i(1, 6)],
	["town", Vector2i(15, 6)],
	["town", Vector2i(15, 15)],
	["town", Vector2i(17, 15)],
	["town", Vector2i(17, 16)],  # south gate -> ranch
	["ranch", Vector2i(17, 7)],  # through the cosmetic inner compound gate
	["ranch", Vector2i(17, 1)],
	["ranch", Vector2i(17, 0)],  # north gate -> town
	["town", Vector2i(15, 15)],
	["town", Vector2i(15, 6)],
	["town", Vector2i(1, 6)],
	["town", Vector2i(1, 4)],
	["town", Vector2i(0, 4)],    # west gate -> path
	["path", Vector2i(1, 4)],
	["path", Vector2i(0, 4)],    # west gate -> farm
	["farm", Vector2i(30, 4)],
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
		_check(false, "waypoint %d timed out" % waypoint_index)
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
	if delta.length() < 3.0 or zone_map.world_to_cell(player.global_position) == Vector2i(wp[1]):
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
