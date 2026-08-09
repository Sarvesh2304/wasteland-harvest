extends SceneTree
## Windowed screenshot driver for the Farm/Path/Town/Ranch zone split (NOT headless — the GL
## renderer must actually draw). Boots scenes/main.tscn on Open Plains and captures each zone's
## arrival point plus the Path zone's new content (the ruined road, weed dressing, wrecked-car
## landmark, and sealed checkpoint — brand-new art needing its own visual check per the plan's
## Stage 1 verification), the mayor's-house-near-the-new-north-wall cosmetic note, and then
## reboots on Riverside for the bridge crossing + the gap-in-the-river west town gate (the
## flagged cosmetic rough edge). Player placement uses main._bind_zone directly — the real
## gate-crossing path is exercised end-to-end by tools/zone_transition_smoke.gd; this tool only
## frames shots.
##
## Run (windowed-game launch has standing approval per CLAUDE.md; never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_zones.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var stage := 0
var stage_started_at := 0

## [zone_id, player cell (zone-local), facing, file name] — Open Plains pass.
const SHOTS_OPEN_PLAINS := [
	["farm", Vector2i(69, 15), "east", "shot_zone_farm_east_gate_4x.png"],
	["path", Vector2i(2, 4), "east", "shot_zone_path_west_arrival_4x.png"],
	["path", Vector2i(11, 6), "north", "shot_zone_path_car_checkpoint_4x.png"],
	["path", Vector2i(21, 5), "east", "shot_zone_path_east_gate_4x.png"],
	["town", Vector2i(2, 4), "east", "shot_zone_town_west_arrival_4x.png"],
	# Ranch relocation (2026-08-09): the Town's south gate is resealed plain fence and the Ranch
	# now hangs off the FARM's south gate, so these two shots moved with the seam. The town shot
	# is kept — pointed at the resealed wall, since "is the reseal visually seamless against the
	# rest of row 16?" is exactly the kind of thing only a screenshot answers — and the ranch
	# arrival is reframed from the old north gate to the new south one.
	["town", Vector2i(17, 14), "south", "shot_zone_town_south_wall_resealed_4x.png"],
	["farm", Vector2i(35, 29), "south", "shot_zone_farm_south_gate_4x.png"],
	["ranch", Vector2i(17, 16), "north", "shot_zone_ranch_south_arrival_4x.png"],
]
## Riverside pass: the Path's plank bridge and the town-bank landing (gap-in-the-river gate).
const SHOTS_RIVERSIDE := [
	["path", Vector2i(19, 5), "east", "shot_zone_path_riverside_bridge_4x.png"],
	["town", Vector2i(3, 4), "west", "shot_zone_town_riverside_landing_4x.png"],
]

var _shots: Array = []
var _shot_index := 0
var _riverside_pass := false


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.save_path = "user://screenshot_zones_save.json"
	game_state.delete_save()
	game_state.chosen_settlement_id = "open_plains"
	_shots = SHOTS_OPEN_PLAINS
	_boot_main()


func _boot_main() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	player = main.get_node("Player")


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	match stage:
		0:
			if ticks < 10:
				return false
			day_manager.minutes_into_day = 720.0  # noon: unmodulated palette for clean shots
			day_manager.time_paused = true
			_enter_stage(1)
		1:
			if _shot_index >= _shots.size():
				if _riverside_pass:
					game_state.delete_save()
					quit(0)
					return false
				# Reboot the whole scene on Riverside for the bridge/river-gate shots.
				root.remove_child(main)
				main.free()
				game_state.chosen_settlement_id = "riverside"
				_shots = SHOTS_RIVERSIDE
				_shot_index = 0
				_riverside_pass = true
				_boot_main()
				_enter_stage(0)
				return false
			var shot: Array = _shots[_shot_index]
			if ticks < 5:
				main._bind_zone(String(shot[0]), Vector2i(shot[1]))
				player.velocity = Vector2.ZERO
				player.facing = String(shot[2])
				return false
			if ticks >= 25:
				_capture(String(shot[3]))
				_shot_index += 1
				_enter_stage(1)
		_:
			pass
	return false


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:  # native 320x192 -> 4x for legibility
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
