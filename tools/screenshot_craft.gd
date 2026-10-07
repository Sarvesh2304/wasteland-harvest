extends SceneTree
## Windowed screenshots of the menu's CRAFT and SKILLS tabs (Milestone B, 2026-10-07).
## Run: WH_SHOT_DIR=/abs/dir xvfb-run -a -s "-screen 0 1280x768x24" godot --path . \
##   --rendering-driver opengl3 --audio-driver Dummy --script res://tools/screenshot_craft.gd

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var main: Node
var frames := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	var gs = root.get_node("GameState")
	gs.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	gs.save_path = "user://screenshot_craft_save.json"
	gs.delete_save()
	gs.chosen_settlement_id = "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _physics_process(_delta: float) -> bool:
	frames += 1
	var menu: Node = main.get_node("MenuScreen")
	var player: Node = main.get_node("Player")
	match frames:
		10:
			root.get_node("DayManager").time_paused = true
			for pair in [["wood", 40], ["stone", 30], ["scrap_metal", 10], ["glass", 2],
					["tree_sap", 5], ["fiber", 10], ["copper_wire", 1]]:
				player.inventory.add_item(pair[0], pair[1])
			main.get_node("Skills").add_xp("farming", 450)
			main.get_node("Skills").add_xp("foraging", 120)
			main.get_node("Skills").add_xp("scavenging", 60)
			menu.open_menu()
			menu.tab_index = menu.TAB_CRAFT
			menu._refresh()
			menu._select_recipe(0)
		20:
			_capture("craft_tab")
			menu._craft_selected()
		24:
			_capture("craft_tab_after_craft")
			menu.tab_index = menu.TAB_SKILLS
			menu._refresh()
		30:
			_capture("skills_tab")
			menu.tab_index = menu.TAB_CONTROLS
			menu._refresh()
		36:
			_capture("controls_tab")
			root.get_node("GameState").delete_save()
			quit(0)
	return false


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	image.save_png(shot_dir.path_join(file_name + ".png"))
	print("SHOT " + file_name)
