extends SceneTree
## Performance probe (Milestone E): boots the real game and measures the wall-clock time of each
## frame (everything the engine does between two idle frames, headless so no draw) and the
## node/object counts in the heaviest everyday situations:
##   farm_full   - the farm with every tillable cell planted and watered (a late-game field)
##   town_fest   - the town on a festival day at noon, everyone gathered, lanterns up
##   ruins_d4    - a Core level (depth 4) with its enemies awake and chasing
##   night_skip  - the cost of one overnight day change with the full farm (ms, once)
## Rendering isn't measured here (headless); the budget is the script side: at 60 fps a frame is
## 16.7 ms, and the game should keep script work well under ~4 ms on a desktop.
## Run: godot --headless --path . --audio-driver Dummy --script res://tools/perf_probe.gd

const FRAMES := 240

var game_state: Node
var day_manager: Node
var main: Node
var player: Node
var stage := 0
var ticks := 0
var _samples: Array[float] = []
var _results: Dictionary = {}
var _last_usec := 0
var _sampling := false


func _initialize() -> void:
	# Headless runs sleep between frames (low-processor mode, 6.9 ms); measure the work alone.
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	Engine.max_fps = 0
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.world_spawning_enabled = true
	day_manager.forced_weather = "clear"
	game_state.saves_dir = "user://perf_probe_saves"
	game_state.legacy_save_path = "user://perf_probe_saves/legacy.json"
	game_state.save_path = "user://perf_probe_saves/slot_1.json"
	game_state.chosen_settlement_id = "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


## Frame time is measured here, once per idle frame (the physics callback below can run several
## times in one slow frame, and the engine's own monitors only update per frame).
func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if _sampling and _last_usec > 0:
		var ms := (now - _last_usec) / 1000.0
		if ms > 16.7 and OS.get_environment("WH_PERF_SPIKES") != "":
			print("SPIKE stage %d  %.1f ms  minute %.1f" % [stage, ms, day_manager.minutes_into_day])
		_samples.append(ms)
	_last_usec = now
	return false


func _sample() -> void:
	_sampling = true


func _report(name: String) -> void:
	_sampling = false
	var sorted := _samples.duplicate()
	sorted.sort()
	var mean := 0.0
	for s in sorted:
		mean += s
	mean /= maxf(sorted.size(), 1)
	var p95: float = sorted[int(sorted.size() * 0.95)] if not sorted.is_empty() else 0.0
	_results[name] = {"mean": mean, "p95": p95, "max": sorted.back() if not sorted.is_empty() else 0.0,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		# Only meaningful when rendering (run under a display, not --headless).
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))}
	print("PERF %-11s mean %6.2f ms  p95 %6.2f ms  max %6.2f ms  nodes %5d  objects %6d  draw calls %d" % [name, mean,
		p95, _results[name]["max"], _results[name]["nodes"], _results[name]["objects"], _results[name]["draws"]])
	_samples.clear()


func _plant_everything() -> int:
	var farm: Node = main.zones["farm"]["farm"]
	var map: Node2D = main.zones["farm"]["map"]
	var size: Vector2i = map.layout.size()
	var crop: String = farm.random_seasonal_crop()
	var planted := 0
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if farm.can_till(cell) and farm.till(cell) and farm.plant(cell, crop):
				farm.water(cell)
				planted += 1
	return planted


func _physics_process(_delta: float) -> bool:
	ticks += 1
	match stage:
		0:
			if ticks < 30:
				return false
			player = main.get_node("Player")
			day_manager.minutes_into_day = 10 * 60.0
			print("PERF planted %d cells" % _plant_everything())
			main._bind_zone("farm")
			stage = 1
			ticks = 0
		1:
			if ticks > 20:
				_sample()
			if ticks >= FRAMES + 20:
				_report("farm_full")
				var t0 := Time.get_ticks_usec()
				day_manager.skip_to_next_morning()
				print("PERF night_skip  %.1f ms (one overnight day change, full farm)" % ((Time.get_ticks_usec() - t0) / 1000.0))
				if main.confirm_ui.active:
					main.confirm_ui.choose(0)
				# To Planting Day, noon, in town.
				var target: int = 14
				while day_manager.day < target:
					day_manager.skip_to_next_morning()
					if main.confirm_ui.active:
						main.confirm_ui.choose(0)
				day_manager.minutes_into_day = 12 * 60.0
				main._bind_zone("town")
				stage = 2
				ticks = 0
		2:
			if ticks > 60:
				_sample()
			if ticks >= FRAMES + 60:
				_report("town_fest")
				main.expedition.max_depth = 4
				main.expedition.depart(4)
				stage = 3
				ticks = 0
		3:
			if ticks == 40:
				# Wake everything: the player stands in the middle of the level.
				var enemies: Node = main.ruins["enemies"]
				for e in enemies.get_children():
					if e.has_method("alert_to"):
						e.alert_to(player.global_position)
			if ticks > 40:
				_sample()
			if ticks >= FRAMES + 40:
				_report("ruins_d4")
				_finish()
				return true
	return false


func _finish() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists("perf_probe_saves"):
		for f in DirAccess.get_files_at("user://perf_probe_saves"):
			DirAccess.remove_absolute("user://perf_probe_saves/" + f)
	quit(0)
