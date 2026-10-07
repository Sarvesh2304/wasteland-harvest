extends SceneTree
## Windowed screenshot driver for Phase 6 Art pass 1's buildings half (NOT headless — the GL
## renderer must actually draw). Boots scenes/main.tscn on Forest Edge and saves three viewport
## captures (4x nearest-neighbor upscaled from the native 320x192):
##   1. shot_buildings_town_4x.png — the town core (mayor's house, store, shacks, bulletin
##      board) rendered with the real PixelLab art from art/buildings/.
##   2. shot_buildings_farmhouse_props_4x.png — the farmhouse plus its 1x1 service row (chest /
##      shipping box / bed) up close, confirming the 32->16 downscaled props read at game scale.
##   3. shot_buildings_blueprint_vs_complete_4x.png — a COMPLETED storage shed (real art)
##      standing beside a just-placed shelter-tent BLUEPRINT (translucent blue, unchanged),
##      proving the under-construction -> final visual swap still works with textures in place.
##
## Run (windowed-game launch has standing approval per CLAUDE.md; this never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_buildings.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done. Uses a test-only
## save filename, deleted before and after — same hygiene rule as tools/screenshot_shipping.gd.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var test_map: Node
var structures: Node
var stage := 0
var stage_started_at := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	game_state = root.get_node("GameState")
	game_state.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	day_manager = root.get_node("DayManager")
	game_state.save_path = "user://screenshot_buildings_save.json"
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
			test_map = main.get_node("TownMap")  # zone split: the town-core buildings live here now
			structures = test_map.get_node("Structures")
			day_manager.minutes_into_day = 720.0  # noon: unmodulated palette for clean shots
			day_manager.time_paused = true
			_enter_stage(1)
		1:
			# -- Shot 1: stand in the plaza so the town cluster fills the viewport --
			if ticks < 5:
				player.global_position = test_map.cell_to_world_center(Vector2i(18, 21))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks >= 20:
				_capture("shot_buildings_town_4x.png")
				_enter_stage(10)
		10:
			# -- Shot 1b: center Marta's store (16-18, 25-26), which shot 1's hotbar covers --
			if ticks < 5:
				player.global_position = test_map.cell_to_world_center(Vector2i(21, 24))
				player.velocity = Vector2.ZERO
				player.facing = "west"
				return false
			if ticks >= 20:
				_capture("shot_buildings_store_4x.png")
				_enter_stage(2)
		2:
			# -- Shot 2: the farmhouse + its 1x1 service row (chest 16 / box 17 / bed 18, y=4) --
			if ticks < 5:
				player.global_position = test_map.cell_to_world_center(Vector2i(17, 6))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks >= 20:
				_capture("shot_buildings_farmhouse_props_4x.png")
				_enter_stage(3)
		3:
			# -- Shot 3 setup: place a storage shed at (3,16) (runtime_smoke's proven-valid
			#    spot), advance a morning so it COMPLETES (blueprint -> real art swap), then
			#    place a shelter-tent blueprint beside it at (6,16) that stays pending --
			if ticks == 1:
				var placed: bool = structures.place_blueprint("storage_shed", Vector2i(3, 16))
				assert(placed, "storage shed blueprint placement failed")
				return false
			if ticks == 5:
				day_manager.skip_to_next_morning()  # completes the shed (build_days = 1)
				day_manager.minutes_into_day = 720.0  # re-pin to noon
				return false
			if ticks == 10:
				var placed: bool = structures.place_blueprint("shelter_tent", Vector2i(6, 16))
				assert(placed, "shelter tent blueprint placement failed")
				player.global_position = test_map.cell_to_world_center(Vector2i(5, 19))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks >= 25:
				_capture("shot_buildings_blueprint_vs_complete_4x.png")
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
