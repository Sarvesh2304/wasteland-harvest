extends SceneTree
## Windowed screenshot driver for Phase 4 Stage 2's building placement (NOT headless — the GL
## renderer must actually draw). Boots scenes/main.tscn on Forest Edge, walks through the build
## flow, and saves three viewport captures (4x nearest-neighbor upscaled from the native 320x192):
##   1. shot_build_preview_4x.png  — placement mode active, Storage Shed preview + cost label
##   2. shot_build_blueprint_4x.png — the placed, under-construction blueprint volume
##   3. shot_build_complete_4x.png  — the finished shed after the day advance
##
## Run (windowed-game launch has standing approval per CLAUDE.md; this never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_build.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var builder: Node2D
var stage := 0
var stage_started_at := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	game_state = root.get_node("GameState")
	game_state.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	day_manager = root.get_node("DayManager")
	game_state.chosen_settlement_id = "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	match stage:
		0:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			builder = main.get_node("Builder")
			day_manager.minutes_into_day = 720.0  # noon: unmodulated palette for a clean shot
			day_manager.time_paused = true
			# Same site as tools/runtime_smoke.gd's stage 16: SHED_STAND (30,8), facing south,
			# so the 2x2 shed preview lands on the open build clearing at (30,9)-(31,10).
			# (Re-anchored with the 2026-08-09 72x32 farm expansion — the old (3,15) stand cell
			# is inside Forest Edge's re-authored creek now, and its "shed at (3,16)" comment
			# had already drifted from what runtime_smoke's stage 16 actually does.)
			player.global_position = main.get_node("FarmMap").cell_to_world_center(Vector2i(30, 8))
			player.velocity = Vector2.ZERO
			player.facing = "south"
			builder.set_active(true)
			builder.catalog_index = 1  # storage_shed
			_enter_stage(1)
		1:
			if ticks >= 30:  # ~0.5s of rendered frames so the preview is on screen
				_capture("shot_build_preview_4x.png")
				builder.confirm_placement()
				builder.set_active(false)
				_enter_stage(2)
		2:
			if ticks >= 30:
				_capture("shot_build_blueprint_4x.png")
				day_manager.skip_to_next_morning()
				day_manager.minutes_into_day = 720.0
				_enter_stage(3)
		3:
			if ticks >= 30:
				_capture("shot_build_complete_4x.png")
				quit(0)
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
