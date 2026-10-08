extends SceneTree
## Renders whole generated ruins levels at 1:1 (Milestone C, 2026-10-08) for judging layouts: a
## SubViewport sharing the game world's canvas, sized to the map, at noon. One PNG per level:
## ruins_map_d<depth>_s<seed>.png.
## Run: WH_SHOT_DIR=/abs/dir xvfb-run -a -s "-screen 0 1280x768x24" godot --path . \
##   --rendering-driver opengl3 --audio-driver Dummy --script res://tools/screenshot_ruins_map.gd
## Optional: WH_RUINS_LEVELS="1:11,2:4242" (depth:seed pairs).

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var main: Node
var frames := 0
var _levels: Array = []
var _vp: SubViewport = null
var _stage := 0
var _wait := 0
var _current: Array = []


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	var spec := OS.get_environment("WH_RUINS_LEVELS")
	if spec == "":
		spec = "1:11,2:4242,3:90210"
	for pair in spec.split(","):
		var parts := pair.split(":")
		_levels.append([int(parts[0]), int(parts[1])])
	var gs = root.get_node("GameState")
	gs.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	gs.save_path = "user://screenshot_ruins_map_save.json"
	gs.chosen_settlement_id = "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames < 10:
		return false
	var dm = root.get_node("DayManager")
	dm.time_paused = true
	dm.minutes_into_day = 12 * 60.0
	match _stage:
		0:
			if _levels.is_empty():
				root.get_node("GameState").delete_save()
				quit(0)
				return true
			_current = _levels.pop_front()
			var ex: Node = main.expedition
			ex.active = true
			var lvl: Dictionary = ex.generate(int(_current[0]), int(_current[1]))
			ex.depth = int(_current[0])
			ex.level = lvl
			ex.populate(lvl)
			main.enter_ruins(Vector2i(lvl["entry"]))
			dm.time_changed.emit(dm.day, dm.minutes_into_day)
			# Freeze the enemies where they spawned, for a clean map.
			main.ruins["enemies"].process_mode = Node.PROCESS_MODE_DISABLED
			var map: Node2D = main.ruins["map"]
			var rect: Rect2 = map.get_global_map_rect()
			_vp = SubViewport.new()
			_vp.size = Vector2i(rect.size)
			_vp.world_2d = root.world_2d
			_vp.transparent_bg = false
			_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			var cam := Camera2D.new()
			cam.position = rect.get_center()
			_vp.add_child(cam)
			root.add_child(_vp)
			cam.make_current()
			_wait = 0
			_stage = 1
		1:
			_wait += 1
			if _wait < 14:
				return false
			var img := _vp.get_texture().get_image()
			var name := "ruins_map_d%d_s%d.png" % [int(_current[0]), int(_current[1])]
			img.save_png(shot_dir.path_join(name))
			print("SHOT " + name + " " + str(img.get_size()))
			_vp.queue_free()
			_vp = null
			main.ruins["enemies"].process_mode = Node.PROCESS_MODE_INHERIT
			_stage = 0
	return false
