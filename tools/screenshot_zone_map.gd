extends SceneTree
## Renders whole settlement zones at 1:1 (2026-10-08) for planning and checking what the town looks
## like: a SubViewport sharing the game world's canvas, sized to the zone, at noon (or at
## WH_SHOT_HOUR). One PNG per zone: zone_map_<zone>.png.
## Run: WH_SHOT_DIR=/abs/dir xvfb-run -a -s "-screen 0 1280x768x24" godot --path . \
##   --rendering-driver opengl3 --audio-driver Dummy --script res://tools/screenshot_zone_map.gd
## Optional: WH_ZONES="town,farm" (default: farm,path,town,ranch), WH_SHOT_HOUR=21,
## WH_SETTLEMENT=open_plains|forest_edge|riverside.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var main: Node
var frames := 0
var _zones: Array = []
var _vp: SubViewport = null
var _stage := 0
var _wait := 0
var _current := ""
var _hour := 12.0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	var spec := OS.get_environment("WH_ZONES")
	if spec == "":
		spec = "farm,path,town,ranch"
	for z in spec.split(","):
		_zones.append(z.strip_edges())
	if OS.get_environment("WH_SHOT_HOUR") != "":
		_hour = float(OS.get_environment("WH_SHOT_HOUR"))
	var gs = root.get_node("GameState")
	gs.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	gs.save_path = "user://screenshot_zone_map_save.json"
	var settlement := OS.get_environment("WH_SETTLEMENT")
	gs.chosen_settlement_id = settlement if settlement != "" else "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames < 10:
		return false
	var dm = root.get_node("DayManager")
	dm.time_paused = true
	dm.minutes_into_day = _hour * 60.0
	match _stage:
		0:
			if _zones.is_empty():
				root.get_node("GameState").delete_save()
				quit(0)
				return true
			_current = _zones.pop_front()
			if not main.zones.has(_current):
				print("NO ZONE " + _current)
				return false
			main._bind_zone(_current)
			dm.time_changed.emit(dm.day, dm.minutes_into_day)
			var map: Node2D = main.zones[_current]["map"]
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
			var name := "zone_map_%s.png" % _current
			img.save_png(shot_dir.path_join(name))
			print("SHOT " + name + " " + str(img.get_size()))
			_vp.queue_free()
			_vp = null
			_stage = 0
	return false
