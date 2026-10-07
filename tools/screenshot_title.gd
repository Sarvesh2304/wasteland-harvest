extends SceneTree
## Windowed screenshot driver for the 2026-07-11 title screen / multi-slot Load flow (NOT
## headless — the GL renderer must actually draw). Seeds three save slots into a throwaway
## saves dir, boots scenes/title_screen.tscn, and saves two viewport captures (4x
## nearest-neighbor upscaled from the native 320x192):
##   1. shot_title_menu_4x.png — the title menu with all three options (New Game highlighted).
##   2. shot_title_load_4x.png — the Load panel listing the three slots (settlement + day
##      rows, newest first, with the highlighted row's last-played detail line).
##
## Uses a throwaway saves dir (game_state.saves_dir redirected, legacy_save_path neutralized —
## same hygiene as tools/title_smoke.gd) and deletes it before quitting.
##
## Run (windowed-game launch has standing approval per CLAUDE.md; this never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_title.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done.

const SAVES_DIR := "user://screenshot_title_saves"

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var title: Control
var stage := 0
var stage_started_at := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	game_state = root.get_node("GameState")
	game_state.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	game_state.saves_dir = SAVES_DIR
	game_state.legacy_save_path = SAVES_DIR.path_join("legacy.json")
	game_state.save_path = SAVES_DIR.path_join("preboot.json")
	_delete_test_saves()
	# Three believable playthroughs for the Load panel to show.
	_write_slot(1, "open_plains", 3, 1783300000)
	_write_slot(2, "forest_edge", 12, 1783650000)
	_write_slot(3, "riverside", 5, 1783728000)
	title = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
	root.add_child(title)
	current_scene = title


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	match stage:
		0:
			if ticks >= 30:  # let the first frames actually draw
				_capture("shot_title_menu_4x.png")
				_drive("move_down")
				_drive("use_tool")  # New Game -> Load Game -> confirm: open the Load panel
				_enter_stage(1)
		1:
			if ticks >= 20:
				_capture("shot_title_load_4x.png")
				_delete_test_saves()
				quit(0)
		_:
			pass
	return false


func _drive(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	title._unhandled_input(event)


func _write_slot(id: int, settlement_id: String, day: int, saved_unix: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVES_DIR))
	var file := FileAccess.open(SAVES_DIR.path_join("slot_%d.json" % id), FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 1, "settlement_id": settlement_id, "day": day,
		"minutes_into_day": 360.0, "saved_unix": saved_unix,
	}, "\t"))
	file.close()


func _delete_test_saves() -> void:
	var abs_dir := ProjectSettings.globalize_path(SAVES_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	for file_name in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(file_name))
	DirAccess.remove_absolute(abs_dir)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:  # native 320x192 -> 4x for legibility
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
