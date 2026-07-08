extends SceneTree
## Windowed screenshot driver for Phase 4 Stage 3's bed/auto-save (NOT headless — the GL
## renderer must actually draw). Boots scenes/main.tscn on Forest Edge, walks the player up to
## the farmhouse bed, and saves two viewport captures (4x nearest-neighbor upscaled from the
## native 320x192):
##   1. shot_bed_interact_4x.png — player standing at the foot of the bed (blossom-pink 1x1
##      beside the farmhouse/chest), facing it, about to interact
##   2. shot_world_saved_4x.png  — immediately after sleeping: next morning, energy refilled,
##      the "WORLD SAVED" notice on screen
##
## Uses a throwaway save filename and deletes it before quitting (test hygiene — this run's
## auto-save must never leak into a real playthrough's resume check or a later test run).
##
## Run (windowed-game launch has standing approval per CLAUDE.md; this never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_sleep.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var stage := 0
var stage_started_at := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.save_path = "user://screenshot_sleep_save.json"
	game_state.delete_save()
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
			day_manager.minutes_into_day = 720.0  # noon: unmodulated palette for a clean shot
			day_manager.time_paused = true
			# Foot of Forest Edge's bed at (18,4) — same interaction cell the smoke test drives.
			player.global_position = main.get_node("TestMap").cell_to_world_center(Vector2i(18, 5))
			player.velocity = Vector2.ZERO
			player.facing = "north"
			_enter_stage(1)
		1:
			if ticks >= 30:  # ~0.5s of rendered frames so the camera settles on the player
				_capture("shot_bed_interact_4x.png")
				player.use_tool()  # the real bed interaction: sleep + auto-save
				day_manager.minutes_into_day = 720.0  # re-pin to noon so the shot stays bright
				_enter_stage(2)
		2:
			if ticks >= 20:  # well inside the notice's 1.6s hold — "WORLD SAVED" is on screen
				_capture("shot_world_saved_4x.png")
				game_state.delete_save()
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
