extends SceneTree
## Windowed screenshot driver for the 2026-07-11 HUD redesign session (NOT headless — the GL
## renderer must actually draw). Boots scenes/main.tscn on Forest Edge, grants some Credits, and
## captures three shots (4x nearest-neighbor upscaled from the native 320x192):
##   1. shot_hud_redesign_noon.png — the new layout at noon: Credits stacked under the clock
##      plaque, no top-left panel, the day dial, everything ~10% smaller — directly comparable to
##      tools/screenshot_hud_credits.gd's existing noon shot (the "before" reference).
##   2. shot_hud_redesign_morning.png — 7:00 AM, showing the day dial just past empty.
##   3. shot_hud_redesign_afternoon.png — 3:00 PM, showing the day dial well advanced, proving it
##      actually progresses across the day rather than sitting static.
##
## Run (windowed-game launch has standing approval per CLAUDE.md; this never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_hud_redesign.gd
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
			day_manager.time_paused = true
			player.set_credits(128)
			day_manager.minutes_into_day = 720.0  # noon: unmodulated palette for a clean shot
			_enter_stage(1)
		1:
			if ticks >= 15:
				_capture("shot_hud_redesign_noon.png")
				day_manager.minutes_into_day = 420.0  # 7:00 AM — just past the 6 AM day start
				_enter_stage(2)
		2:
			if ticks >= 15:
				_capture("shot_hud_redesign_morning.png")
				day_manager.minutes_into_day = 900.0  # 3:00 PM — well into the afternoon
				_enter_stage(3)
		3:
			if ticks >= 15:
				_capture("shot_hud_redesign_afternoon.png")
				quit(0)
		_:
			pass
	return false


func _capture(file_name: String) -> void:
	# Force the HUD's clock labels/dial to refresh immediately rather than waiting on the next
	# organic time_changed tick, since minutes_into_day was just teleported directly above.
	var hud := main.get_node("HUD")
	hud._on_time_changed(day_manager.day, day_manager.minutes_into_day)
	var image := root.get_texture().get_image()
	if image.get_width() < 640:  # native 320x192 -> 4x for legibility
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
