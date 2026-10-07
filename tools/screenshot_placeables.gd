extends SceneTree
## Windowed screenshots of crafted placeables (Milestone B, 2026-10-07): a chest, a working kiln,
## a smelter with a finished bar waiting, sprinklers, an oil lamp and a gnome on a gravel path —
## by day, at night (lamp lit, kiln fire glowing, the smelter's ready bubble), and the storage screen.
## Run: WH_SHOT_DIR=/abs/dir xvfb-run -a -s "-screen 0 1280x768x24" godot --path . \
##   --rendering-driver opengl3 --audio-driver Dummy --script res://tools/screenshot_placeables.gd

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var main: Node
var frames := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	var gs = root.get_node("GameState")
	gs.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	gs.save_path = "user://screenshot_placeables_save.json"
	gs.delete_save()
	gs.chosen_settlement_id = "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _physics_process(_delta: float) -> bool:
	frames += 1
	var dm = root.get_node("DayManager")
	var map: Node = main.zones["farm"]["map"]
	var objects: Node = map.get_node("Objects")
	var player: Node = main.get_node("Player")
	match frames:
		10:
			dm.time_paused = true
			dm.minutes_into_day = 11 * 60.0
			for item_cell in [["crate_chest", Vector2i(20, 6)], ["kiln", Vector2i(21, 6)],
					["smelter", Vector2i(22, 6)], ["oil_lamp", Vector2i(23, 6)],
					["scrap_gnome", Vector2i(19, 8)], ["quality_sprinkler", Vector2i(16, 9)],
					["bee_box", Vector2i(23, 8)], ["preserves_jar", Vector2i(24, 6)]]:
				objects.place_item(String(item_cell[0]), Vector2i(item_cell[1]))
			for c in [Vector2i(20, 7), Vector2i(21, 7), Vector2i(22, 7), Vector2i(23, 7), Vector2i(19, 7)]:
				map.place_floor(c, "gravel_path", map.get_node("Farm"))
			player.inventory.add_item("wood", 10)
			player.inventory.add_item("scrap_metal", 5)
			player.inventory.add_item("charcoal", 1)
			# Kiln working, smelter finished.
			player.inventory.select_hotbar(_slot(player, "wood"))
			_face(player, map, Vector2i(21, 6))
			objects.interact_placed(Vector2i(21, 6), player)
			player.inventory.select_hotbar(_slot(player, "scrap_metal"))
			_face(player, map, Vector2i(22, 6))
			objects.interact_placed(Vector2i(22, 6), player)
			dm.advance_minutes(5.0)
			objects.machine_state_at(Vector2i(22, 6))["ready_at"] = 0
			objects._refresh_placed_visuals()
			player.global_position = map.get_global_cell_center(Vector2i(21, 9))
			player.facing = "north"
		30:
			_capture("placeables_day")
			dm.minutes_into_day = 21.5 * 60.0
			# Keep the kiln cooking into the night so its fire glow shows.
			objects.machine_state_at(Vector2i(21, 6))["ready_at"] = objects._now() + 600
			objects._refresh_placed_visuals()
		40:
			_capture("placeables_night")
			dm.minutes_into_day = 11 * 60.0
			player.inventory.add_item("stone", 12)
			main.storage_ui.open_storage(objects.storage_at(Vector2i(20, 6)), Vector2i(20, 6), "Crate Chest")
			main.storage_ui.transfer_at(27 + _slot(player, "stone"))
		50:
			_capture("storage_screen")
			root.get_node("GameState").delete_save()
			quit(0)
	return false


func _slot(player: Node, item: String) -> int:
	for i in player.inventory.TOTAL_SLOTS:
		if String(player.inventory.get_slot(i).get("item_id", "")) == item:
			if i >= player.inventory.HOTBAR_SIZE:
				player.inventory.move_slot(i, player.inventory.HOTBAR_SIZE - 1)
				return player.inventory.HOTBAR_SIZE - 1
			return i
	return 0


func _face(player: Node, map: Node, cell: Vector2i) -> void:
	player.global_position = map.get_global_cell_center(cell + Vector2i(0, 1))
	player.facing = "north"


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	image.save_png(shot_dir.path_join(file_name + ".png"))
	print("SHOT " + file_name)
