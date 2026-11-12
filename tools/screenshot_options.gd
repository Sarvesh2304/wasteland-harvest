extends SceneTree
## Windowed screenshot driver for the Milestone E options screen (NOT headless — the GL renderer
## must draw). Captures, 4x nearest-neighbour from the native 320x192:
##   1. shot_options_title_menu_4x.png     — the title menu with its Options entry.
##   2. shot_options_title_settings_4x.png — Options over the title, SETTINGS page.
##   3. shot_options_title_controls_4x.png — the CONTROLS page mid-rebind.
##   4. shot_options_ingame_settings_4x.png — the in-game menu's OPTIONS tab (accessibility rows).
##   5. shot_options_ingame_controls_4x.png — its CONTROLS page with controller prompts.
## Settings and saves go to scratch paths, removed at the end.
## Run: WH_SHOT_DIR=<dir> xvfb-run -a -s "-screen 0 1280x768x24" godot --path . \
##   --rendering-driver opengl3 --audio-driver Dummy --script res://tools/screenshot_options.gd

const SETTINGS_FILE := "user://screenshot_options_settings.cfg"
const SAVES_DIR := "user://screenshot_options_saves"

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var settings: Node
var game_state: Node


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	settings = root.get_node("Settings")
	settings.settings_path = SETTINGS_FILE
	game_state = root.get_node("GameState")
	game_state.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	game_state.saves_dir = SAVES_DIR
	game_state.legacy_save_path = SAVES_DIR.path_join("legacy.json")
	game_state.save_path = SAVES_DIR.path_join("slot_1.json")
	_run()


func _run() -> void:
	await _frames(5)
	var title: Node = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
	root.add_child(title)
	current_scene = title
	await _frames(30)
	while title._menu_entries[title._menu_index] != "Options":
		_drive(title, "move_down")
	await _frames(5)
	_capture("shot_options_title_menu_4x.png")
	_drive(title, "use_tool")
	await _frames(2)
	title.options_menu.select("audio/music")
	await _frames(10)
	_capture("shot_options_title_settings_4x.png")
	title.options_menu.set_page(1)
	title.options_menu.select("use_tool")
	_drive(title, "use_tool")
	await _frames(10)
	_capture("shot_options_title_controls_4x.png")
	title.options_menu.cancel_capture()
	_drive(title, "ui_cancel")
	title.queue_free()
	await _frames(2)
	game_state.chosen_settlement_id = "forest_edge"
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(30)
	var menu: Node = main.get_node("MenuScreen")
	menu.open_menu(menu.TAB_OPTIONS)
	menu.options.select("access/text_speed")
	await _frames(10)
	_capture("shot_options_ingame_settings_4x.png")
	settings.using_pad = true
	settings.input_device_changed.emit(true)
	menu.options.set_page(1)
	menu.options.select("build_toggle")
	menu.options.column = 1
	menu.options.refresh()
	await _frames(10)
	_capture("shot_options_ingame_controls_4x.png")
	_cleanup()
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _drive(node: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	node._unhandled_input(event)


func _cleanup() -> void:
	if FileAccess.file_exists(SETTINGS_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_FILE))
	if DirAccess.dir_exists_absolute(SAVES_DIR):
		for f in DirAccess.get_files_at(SAVES_DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVES_DIR.path_join(f)))


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
