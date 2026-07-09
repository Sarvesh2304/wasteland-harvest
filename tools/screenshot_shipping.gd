extends SceneTree
## Windowed screenshot driver for Phase 5 Stage 3's shipping box (NOT headless — the GL renderer
## must actually draw). Boots scenes/main.tscn on Forest Edge and saves two viewport captures
## (4x nearest-neighbor upscaled from the native 320x192):
##   1. shot_shipping_load_4x.png    — the crop-loading UI open at the box with a part-loaded
##      haul: the 4 crop rows (per-unit value, held, in-box counts), the "In box: N Cr" pending
##      value, and the one-way info line all visible at once.
##   2. shot_shipping_credits_4x.png — the next morning after sleeping: the HUD Credits plaque
##      showing the overnight sale's exact payout (0 -> 40 Cr) beside the advanced day counter,
##      with the bed's WORLD SAVED notice still up ("Credits added next morning", visually).
##
## Run (windowed-game launch has standing approval per CLAUDE.md; this never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_shipping.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done. Uses a test-only
## save filename, deleted before and after (the bed sleep writes a save) — same hygiene rule as
## tools/screenshot_sleep.gd/runtime_smoke.gd.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var test_map: Node
var shipping_ui: Node
var stage := 0
var stage_started_at := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.save_path = "user://screenshot_shipping_save.json"
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
			test_map = main.get_node("TestMap")
			shipping_ui = main.get_node("ShippingUI")
			day_manager.minutes_into_day = 720.0  # noon: unmodulated palette for a clean shot
			day_manager.time_paused = true
			# A believable end-of-day haul to load: 3 potatoes and 2 sunbloom "harvested".
			player.inventory.add_item("mutant_potato", 3)
			player.inventory.add_item("sunbloom", 2)
			_enter_stage(1)
		1:
			# -- Stand on the spawn cell (17,5), facing the box at (17,4), open it via the real
			#    dispatch, and load 2 potatoes so held/in-box/pending-value all read non-trivially --
			if ticks < 5:
				player.global_position = test_map.cell_to_world_center(Vector2i(17, 5))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks == 5:
				player.use_tool()
				_drive_shipping_action("use_tool")  # load 1 mutant potato
				_drive_shipping_action("use_tool")  # load another
				return false
			if ticks >= 20:  # a few rendered frames so the fresh layout settles
				_capture("shot_shipping_load_4x.png")
				_enter_stage(2)
		2:
			# -- Leave the UI, then sleep in the bed at (18,4): the pending 2-potato load sells
			#    overnight (2 x 20 = 40 Cr) and the save notice appears --
			if ticks == 1:
				for i in 3:
					_drive_shipping_action("move_down")  # potato(0) -> Leave(4)... (3 then 4th below)
				_drive_shipping_action("move_down")
				_drive_shipping_action("use_tool")  # Leave
				player.global_position = test_map.cell_to_world_center(Vector2i(18, 5))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks == 10:
				player.use_tool()  # sleep -> sale resolves -> auto-save
				day_manager.minutes_into_day = 720.0  # re-pin to noon for an unmodulated shot
				return false
			if ticks >= 25:
				_capture("shot_shipping_credits_4x.png")
				game_state.delete_save()
				quit(0)
		_:
			pass
	return false


func _drive_shipping_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	shipping_ui._unhandled_input(event)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:  # native 320x192 -> 4x for legibility
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
