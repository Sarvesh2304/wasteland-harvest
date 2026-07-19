extends SceneTree
## Windowed screenshot driver for the 2026-07-11 forced-sleep rules (NOT headless — the GL
## renderer must actually draw). Boots scenes/main.tscn on Forest Edge and saves two viewport
## captures (4x nearest-neighbor upscaled from the native 320x192):
##   1. shot_sleepy_130am_4x.png — 1:30 AM: the pulsing "GETTING SLEEPY..." cue (captured at a
##      pulse peak so it reads clearly), the night-tinted world, a visibly drained energy bar
##      from the passive post-midnight drain, and a Scav-Brew Coffee in the hotbar.
##   2. shot_forced_passout_4x.png — immediately after the 2 AM forced pass-out: 6:00-AM dawn
##      tint, energy refilled, and the "WORLD SAVED" notice from the pass-out's new auto-save.
##
## Uses a throwaway save filename and deletes it before quitting (test hygiene). Clock
## positioning is done by teleport (doesn't count as lived time), then the cutoff is crossed
## with real advance_minutes ticks so the pass-out fires through the genuine path.
##
## Run (windowed-game launch has standing approval per CLAUDE.md; this never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_sleepy.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var hud: CanvasLayer
var stage := 0
var stage_started_at := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.save_path = "user://screenshot_sleepy_save.json"
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
			hud = main.get_node("HUD")
			# Stand in the open near the farmhouse, coffee in the hotbar for flavor.
			player.global_position = main.get_node("FarmMap").cell_to_world_center(Vector2i(17, 7))
			player.velocity = Vector2.ZERO
			player.facing = "south"
			player.inventory.remove_item("stone", 99)  # free a hotbar slot (Forest Edge bonus)
			player.inventory.add_item("coffee", 1)
			# 1:30 AM, mid-drain: teleport the clock, then charge the energy bar with exactly
			# the drain those 90 post-midnight minutes would have cost, as if lived through.
			day_manager.minutes_into_day = 90.0
			player.set_energy(player.max_energy - 90.0 * player.SLEEPY_DRAIN_PER_GAME_MINUTE)
			_enter_stage(1)
		1:
			# ~0.5s so the camera settles, then wait for a pulse PEAK so the cue reads clearly.
			if ticks >= 30 and hud.get_node("%SleepyLabel").modulate.a > 0.9:
				_capture("shot_sleepy_130am_4x.png")
				# Cross the cutoff through the real lived-time path: the 2 AM forced pass-out
				# fires mid-loop, jumping the clock to 6:00 AM and writing the auto-save.
				var guard := 0
				while day_manager.minutes_into_day < 120.0 and guard < 60:
					day_manager.advance_minutes(1.0)
					guard += 1
				_enter_stage(2)
		2:
			if ticks >= 20:  # well inside the notice's 1.6s hold — "WORLD SAVED" is on screen
				_capture("shot_forced_passout_4x.png")
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
