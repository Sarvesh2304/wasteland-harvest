extends SceneTree
## Windowed screenshot driver for a brand-new game's farm (2026-10-07 reclaim-the-farm): boots
## scenes/main.tscn with world spawning ON (the overgrowth scatter runs exactly as in a real new
## game), then captures the arrival view at 4x and a 1:1 overview of the whole farm zone (the
## render resolution is raised to the map's size for that one frame).
##
## Run (windowed-game launch has standing approval per CLAUDE.md; never opens the editor):
##   WH_SHOT_DIR=/abs/dir WH_SETTLEMENT=forest_edge xvfb-run -a -s "-screen 0 1280x768x24" \
##     godot --path . --rendering-driver opengl3 --audio-driver Dummy \
##     --script res://tools/screenshot_farm_start.gd
## Falls back to user:// and forest_edge when the variables are unset. Quits by itself.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var settlement: String = OS.get_environment("WH_SETTLEMENT")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var stage := 0
var stage_started_at := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	if settlement == "":
		settlement = "forest_edge"
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.world_spawning_enabled = true
	day_manager.forced_weather = "clear"
	game_state.save_path = "user://screenshot_farm_start_save.json"
	game_state.delete_save()
	game_state.chosen_settlement_id = settlement
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	player = main.get_node("Player")


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	match stage:
		0:
			if ticks < 20:
				return false
			day_manager.minutes_into_day = 720.0
			day_manager.time_paused = true
			_enter_stage(1)
		1:
			if ticks == 8:  # HUD v2 check: a couple of pickup toasts
				root.get_node("Events").item_gained.emit("wood", 5)
				root.get_node("Events").item_gained.emit("wild_greens", 1)
			if ticks == 20:
				_capture("farm_start_%s_arrival_4x.png" % settlement)
				var camera: Camera2D = main.get_node("GameCamera")
				camera.target = null
				camera.set_process(false)
				main.get_node("HUD").visible = false
				_frame_zone(ZONES[0])
				_enter_stage(2)
		2:
			# One 1:1 overview per zone, the render resolution raised to the zone's map size.
			if ticks == 10:
				_capture("farm_start_%s_overview_%s_1x.png" % [settlement, ZONES[_zone_index]])
				_zone_index += 1
				if _zone_index >= ZONES.size():
					game_state.delete_save()
					quit(0)
					return false
				_frame_zone(ZONES[_zone_index])
				_enter_stage(2)
	return false


const ZONES: Array[String] = ["farm", "path", "town", "ranch"]
var _zone_index := 0


func _frame_zone(zone: String) -> void:
	var map: Node2D = main.zones[zone]["map"]
	var rect: Rect2 = map.get_global_map_rect()
	var camera: Camera2D = main.get_node("GameCamera")
	root.content_scale_size = Vector2i(rect.size)
	root.size = Vector2i(rect.size)
	camera.zoom = Vector2.ONE
	camera.global_position = rect.get_center()


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
