extends SceneTree
## Windowed screenshot driver for the 2026-07-12 in-game tabbed menu (scripts/menu_screen.gd —
## NOT headless, the GL renderer must actually draw). Boots scenes/main.tscn on Forest Edge,
## opens the menu through its real "toggle_inventory" input path, and cycles its tabs with the
## real "build_cycle" presses, saving one capture per tab (4x nearest-neighbor upscaled from the
## native 320x192) plus the armed Save & Return footer:
##   1. shot_menu_inventory_4x.png — the Inventory tab hosting the HUD's reparented backpack grid
##   2. shot_menu_build_4x.png — the Build tab's catalog rows; 5 wood is removed first (15 -> 10)
##      so the tent shows affordable and the shed shows the rust-red "missing materials" state in
##      the SAME shot, rather than an all-affordable fresh-start view
##   3. shot_menu_controls_4x.png — the Controls key-reference tab
##   4. shot_menu_quit_armed_4x.png — the footer after one Space press: the press-again-to-confirm
##      warning state
##
## Run (windowed-game launch has standing approval per CLAUDE.md; this never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_menu.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var menu_screen: Node
var stage := 0
var stage_started_at := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
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
			menu_screen = main.get_node("MenuScreen")
			day_manager.minutes_into_day = 720.0  # noon: unmodulated palette for clean shots
			# 15 -> 10 wood: Shelter Tent (6 wood) stays affordable, Storage Shed (12 wood)
			# reads "missing materials" — both Build-tab row states in one frame.
			player.inventory.remove_item("wood", 5)
			_drive_menu_action("toggle_inventory")
			print("menu open: %s, tab: %d (expected 0/Inventory)" \
				% [menu_screen.active, menu_screen.tab_index])
			_enter_stage(1)
		1:
			if ticks >= 20:
				_capture("shot_menu_inventory_4x.png")
				_drive_menu_action("build_cycle")
				print("tab after Q: %d (expected 1/Build)" % menu_screen.tab_index)
				_enter_stage(2)
		2:
			if ticks >= 20:
				_capture("shot_menu_build_4x.png")
				_drive_menu_action("build_cycle")
				print("tab after Q: %d (expected 2/Controls)" % menu_screen.tab_index)
				_enter_stage(3)
		3:
			if ticks >= 20:
				_capture("shot_menu_controls_4x.png")
				_drive_menu_action("use_tool")  # first Space press: arms Save & Return
				print("quit armed: %s (expected true)" % menu_screen._quit_armed)
				_enter_stage(4)
		4:
			if ticks >= 20:
				_capture("shot_menu_quit_armed_4x.png")
				quit(0)
		_:
			pass
	return false


func _drive_menu_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	menu_screen._unhandled_input(event)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:  # native 320x192 -> 4x for legibility
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
