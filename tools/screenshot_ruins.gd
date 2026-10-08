extends SceneTree
## Windowed screenshots of an expedition (Milestone C, 2026-10-08): arriving in the ruins (the
## district banner, health/rad bars), a fight in progress (an enemy's telegraph, a swing), the
## ride-out prompt at Kael's truck, and the ruins by night.
## Run: WH_SHOT_DIR=/abs/dir xvfb-run -a -s "-screen 0 1280x768x24" godot --path . \
##   --rendering-driver opengl3 --audio-driver Dummy --script res://tools/screenshot_ruins.gd
## Optional: WH_RUINS_DEPTH=2 (default 1), WH_RUINS_SEED=<int>.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var main: Node
var player: Node
var frames := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	var gs = root.get_node("GameState")
	gs.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	gs.save_path = "user://screenshot_ruins_save.json"
	gs.delete_save()
	gs.chosen_settlement_id = "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _physics_process(_delta: float) -> bool:
	frames += 1
	var dm = root.get_node("DayManager")
	match frames:
		10:
			player = main.get_node("Player")
			dm.minutes_into_day = 9 * 60.0
			main._bind_zone("path", Vector2i(11, 3))
			player.facing = "north"
		20:
			_capture("ruins_truck_home")
			player.interact()
		30:
			_capture("ruins_prompt")
			main.confirm_ui.choose(1)
			var depth := int(OS.get_environment("WH_RUINS_DEPTH")) if OS.get_environment("WH_RUINS_DEPTH") != "" else 1
			main.expedition.depart()
			if depth > 1:
				main.expedition.enter_level(depth)
			dm.time_paused = true
		70:
			_capture("ruins_arrival")
			# Walk toward the nearest enemy and start a fight.
			var e := _nearest_enemy()
			if e != null:
				player.global_position = e.global_position + Vector2(-26, 4)
				player.facing = "east"
				player.inventory.add_item("machete", 1)
				_select("machete")
				player.take_hit(18, e.global_position, 60.0)
		100:
			player._iframes = 99.0
			var e2 := _nearest_enemy()
			if e2 != null:
				player.global_position = e2.global_position + Vector2(-14, 2)
				player.facing = "east"
				player.use_tool()
		104:
			_capture("ruins_fight")
		110:
			dm.minutes_into_day = 22.0 * 60.0
			dm.time_changed.emit(dm.day, dm.minutes_into_day)
		125:
			_capture("ruins_night")
			root.get_node("GameState").delete_save()
			quit(0)
	return false


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for e in main.ruins["enemies"].live_enemies():
		var d: float = (e as Node2D).global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _select(item_id: String) -> void:
	for i in player.inventory.TOTAL_SLOTS:
		if String(player.inventory.get_slot(i).get("item_id", "")) == item_id:
			if i >= player.inventory.HOTBAR_SIZE:
				player.inventory.move_slot(i, player.inventory.HOTBAR_SIZE - 1)
				i = player.inventory.HOTBAR_SIZE - 1
			player.inventory.select_hotbar(i)
			return


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	image.save_png(shot_dir.path_join(file_name + ".png"))
	print("SHOT " + file_name)
