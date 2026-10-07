extends SceneTree
## Real-time playtest of a new game's first day, driven through the player's REAL input path
## (held actions polled by player.gd's _physics_process — movement, the use button's repeat
## swings, the interact edge) rather than direct method calls, capturing frames along the way for
## visual review. Unlike the smoke tools this asserts almost nothing: it exists to watch the game
## being played (particles, pickups, wet soil, lighting, the HUD) and to prove a scripted day
## survives play end to end.
##
## Run (windowed-game launch has standing approval per CLAUDE.md; never opens the editor):
##   WH_SHOT_DIR=/abs/dir xvfb-run -a -s "-screen 0 1280x768x24" godot --path . \
##     --rendering-driver opengl3 --audio-driver Dummy --script res://tools/playtest_day1.gd

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var test_map: Node
var objects: Node
var farm: Node

## The scripted session: each step runs until done, then the next starts.
var steps: Array = []
var _step_frames := 0
var _swings := 0
var _was_using := false
var _log: Array[String] = []


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.world_spawning_enabled = false  # a deterministic field; the debris is placed below
	day_manager.forced_weather = "clear"
	game_state.save_path = "user://playtest_day1_save.json"
	game_state.saves_dir = "user://playtest_saves"
	game_state.delete_save()
	game_state.chosen_settlement_id = "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	steps = [
		{"wait": 0.4},
		{"setup": true},
		{"shot": "01_morning_arrival"},
		# Plant the starter patch's top row from the path above it.
		{"select": 5},
		{"walk": Vector2i(15, 7)}, {"face": "south"}, {"use": 1},
		{"walk": Vector2i(16, 7)}, {"face": "south"}, {"use": 1},
		{"walk": Vector2i(17, 7)}, {"face": "south"}, {"use": 1},
		{"walk": Vector2i(18, 7)}, {"face": "south"}, {"use": 1},
		{"shot": "02_planted"},
		{"select": 1},
		{"walk": Vector2i(18, 7)}, {"face": "south"}, {"use": 1},
		{"walk": Vector2i(17, 7)}, {"face": "south"}, {"use": 1},
		{"walk": Vector2i(16, 7)}, {"face": "south"}, {"use": 1},
		{"walk": Vector2i(15, 7)}, {"face": "south"}, {"use": 1},
		{"wait": 0.3},
		{"shot": "03_watered"},
		# Clear a weed patch with the scythe (held use = repeat swings).
		{"select": 4},
		{"walk": Vector2i(15, 6)},
		{"walk": Vector2i(21, 6)}, {"face": "south"}, {"use": 1},
		{"walk": Vector2i(22, 6)}, {"face": "south"}, {"use": 1},
		{"shot_after": 0.05, "name": "04_scythe_swing"},
		{"walk": Vector2i(23, 6)}, {"face": "south"}, {"use": 1},
		{"wait": 0.6},
		{"shot": "05_weeds_cleared"},
		# Fell the treeline tree east of (32,2): ten axe swings, then let the wood land.
		{"select": 2},
		{"walk": Vector2i(23, 5)}, {"walk": Vector2i(32, 5)}, {"walk": Vector2i(32, 2)}, {"face": "east"},
		{"use": 4},
		{"shot_after": 0.05, "name": "06_chopping"},
		{"use": 6},
		{"wait": 0.5},
		{"shot": "07_tree_falling"},
		{"wait": 1.6},
		{"walk": Vector2i(32, 3)},
		{"walk": Vector2i(35, 3)},
		{"wait": 1.2},
		{"shot": "08_wood_collected"},
		# Dusk and night lighting, then sleep at the farmhouse step.
		{"clock": 19.0 * 60.0},
		{"walk": Vector2i(33, 5)}, {"walk": Vector2i(18, 5)}, {"face": "north"},
		{"wait": 0.5},
		{"shot": "09_dusk"},
		{"clock": 22.5 * 60.0},
		{"wait": 0.5},
		{"shot": "10_night"},
		{"interact": true},
		{"wait": 2.0},
		{"shot": "11_next_morning"},
		{"walk": Vector2i(16, 7)}, {"face": "south"},
		{"wait": 0.3},
		{"shot": "12_crops_day2"},
		{"report": true},
	]


func _physics_process(_delta: float) -> bool:
	if main == null:
		return false
	if player == null and main.has_node("Player"):
		player = main.get_node("Player")
	if steps.is_empty():
		return false
	var step: Dictionary = steps[0]
	_step_frames += 1
	if _run_step(step):
		steps.pop_front()
		_step_frames = 0
		_swings = 0
	if _step_frames > 60 * 25:
		_log.append("STUCK on step %s" % str(step))
		_release_all()
		steps.pop_front()
		_step_frames = 0
	return false


## Runs one frame of `step`; true when it's finished.
func _run_step(step: Dictionary) -> bool:
	var seconds := _step_frames / 60.0
	if step.has("wait"):
		return seconds >= float(step["wait"])
	if step.has("setup"):
		test_map = main.zones["farm"]["map"]
		objects = test_map.get_node("Objects")
		farm = test_map.get_node("Farm")
		day_manager.minutes_into_day = 8.0 * 60.0
		for c in [Vector2i(21, 7), Vector2i(22, 7), Vector2i(23, 7), Vector2i(22, 8), Vector2i(24, 7)]:
			objects.place("weeds", c)
		objects.place("tallgrass", Vector2i(21, 8))
		objects.place("rock_small", Vector2i(24, 8))
		objects.place("twig", Vector2i(20, 8))
		return true
	if step.has("shot"):
		_capture(String(step["shot"]))
		return true
	if step.has("shot_after"):
		if seconds >= float(step["shot_after"]):
			_capture(String(step["name"]))
			return true
		return false
	if step.has("select"):
		player.inventory.select_hotbar(int(step["select"]))
		return true
	if step.has("face"):
		player.facing = String(step["face"])
		return true
	if step.has("clock"):
		day_manager.minutes_into_day = float(step["clock"])
		return true
	if step.has("walk"):
		return _walk_toward(Vector2i(step["walk"]))
	if step.has("use"):
		# Hold the use button until `use` swings have started (each swing is an animation-locked
		# action; holding repeats it, the Stardew way).
		Input.action_press("use_tool")
		var using: bool = player.using_tool
		if using and not _was_using:
			_swings += 1
		_was_using = using
		if _swings >= int(step["use"]) and not using:
			Input.action_release("use_tool")
			return true
		if _swings >= int(step["use"]) and using:
			Input.action_release("use_tool")
		return false
	if step.has("interact"):
		if _step_frames == 1:
			Input.action_press("interact")
			return false
		Input.action_release("interact")
		return _step_frames > 3
	if step.has("report"):
		_report()
		quit(0)
		return true
	return true


## Walks to `cell` like a player would: a BFS path over open cells (layout solids, buildings and
## solid world objects are walls), following it waypoint by waypoint with the movement keys.
## True on arrival.
var _path: Array[Vector2i] = []
var _path_goal := Vector2i(-1, -1)


func _walk_toward(cell: Vector2i) -> bool:
	if _path_goal != cell or (_path.is_empty() and _player_cell() != cell):
		_path_goal = cell
		_path = _find_path(_player_cell(), cell)
		if _path.is_empty() and _player_cell() != cell:
			_log.append("no path to %s" % cell)
			_release_moves()
			return true
	var next: Vector2i = _path[0] if not _path.is_empty() else cell
	var target: Vector2 = test_map.get_global_cell_center(next)
	var d := target - player.global_position
	_release_moves()
	if absf(d.x) <= 1.5 and absf(d.y) <= 1.5:
		if not _path.is_empty():
			_path.pop_front()
		if _path.is_empty():
			player.velocity = Vector2.ZERO
			_path_goal = Vector2i(-1, -1)
			return true
		return false
	if absf(d.x) > 1.5:
		Input.action_press("move_right" if d.x > 0 else "move_left")
	if absf(d.y) > 1.5:
		Input.action_press("move_down" if d.y > 0 else "move_up")
	return false


func _player_cell() -> Vector2i:
	return test_map.world_to_cell(player.global_position)


func _open(c: Vector2i) -> bool:
	return not test_map.is_blocked_at(c) and not objects.is_solid_at(c)


func _find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			break
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = c + d
			if came.has(n) or not _open(n) or n.x < 0 or n.y < 0 or n.x > 200 or n.y > 200:
				continue
			came[n] = c
			queue.append(n)
	var path: Array[Vector2i] = []
	if not came.has(to):
		return path
	var c2 := to
	while c2 != from:
		path.push_front(c2)
		c2 = came[c2]
	return path


func _release_moves() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func _release_all() -> void:
	_release_moves()
	Input.action_release("use_tool")
	Input.action_release("interact")


func _report() -> void:
	_release_all()
	var planted := 0
	var watered := 0
	for x in range(15, 19):
		var plot: Dictionary = farm.get_plot(Vector2i(x, 8))
		if not plot.is_empty():
			planted += 1
			if int(plot.get("growth", 0)) >= 1:
				watered += 1
	print("PLAYTEST: day %d, planted %d, grew overnight %d, wood %d, energy %.0f" % [
		day_manager.day, planted, watered, player.inventory.count_of("wood"), player.energy])
	for line in _log:
		print("PLAYTEST: " + line)
	game_state.delete_save()


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name + ".png")
	image.save_png(path)
	print("SHOT %s" % path)
