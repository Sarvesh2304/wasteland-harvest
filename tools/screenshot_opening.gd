extends SceneTree
## Windowed screenshot driver for the Milestone E opening (NOT headless — the GL renderer must
## draw): the reframed settlement picker, every intro page, character creation (rows, a changed
## look, the name editor), every montage page, the replay offer, and the Load list row carrying
## the player's name. 4x nearest-neighbour captures of the native 320x192.
##
## Run (windowed-game launch has standing approval per CLAUDE.md; never opens the editor):
##   WH_SHOT_DIR=/abs/dir xvfb-run -a -s "-screen 0 1280x768x24" godot --path . \
##     --rendering-driver opengl3 --audio-driver Dummy --script res://tools/screenshot_opening.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done.

const SAVES_DIR := "user://screenshot_opening_saves"
const META := "user://screenshot_opening_meta.cfg"

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var scene: Control
var stage := 0
var stage_started_at := 0
var shots := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	game_state = root.get_node("GameState")
	game_state.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	game_state.saves_dir = SAVES_DIR
	game_state.legacy_save_path = SAVES_DIR.path_join("legacy.json")
	game_state.save_path = SAVES_DIR.path_join("preboot.json")
	game_state.opening_meta_path = META
	_cleanup()
	_boot("res://scenes/settlement_select.tscn")


func _boot(path: String) -> void:
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
	scene = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	match stage:
		0:
			if ticks >= 20:
				_capture("shot_opening_00_settlement.png")
				scene._set_index(1)  # Forest Edge
				game_state.choose_settlement("forest_edge")
				game_state.start_new_slot()
				_boot("res://scenes/opening.tscn")
				_enter_stage(1)
		1, 2, 3:
			if ticks >= 110:  # let the caption finish revealing
				_capture("shot_opening_%02d_intro_%s.png" % [stage, scene.INTRO_PAGES[stage - 1]["art"]])
				_drive("use_tool")
				_enter_stage(stage + 1)
		4:
			if ticks >= 20:
				_capture("shot_opening_04_create_rows.png")
				for i in 2:
					_drive("move_down")  # -> LOOK
				_drive("move_right")     # Scavenger
				_drive("move_right")     # Tinker
				_drive("move_down")      # HAIR
				_drive("move_right")
				_enter_stage(5)
		5:
			if ticks >= 30:
				_capture("shot_opening_05_create_look.png")
				for i in 3:
					_drive("move_up")    # back to NAME
				_drive("use_tool")       # open the editor
				scene.creator.type_text("Juniper")
				_drive("move_down")
				_drive("move_right")
				_enter_stage(6)
		6:
			if ticks >= 20:
				_capture("shot_opening_06_create_name.png")
				_drive("ui_cancel")      # back on the rows, at PRONOUNS
				_drive("move_right")     # they -> he
				_drive("move_right")     # he -> she
				_enter_stage(7)
		7:
			if ticks >= 20:
				_capture("shot_opening_07_create_done.png")
				scene.creator.confirm()
				_enter_stage(8)
		8, 9, 10, 11:
			if ticks >= 120:
				_capture("shot_opening_%02d_montage_%s.png" % [stage, scene.MONTAGE_PAGES[stage - 8]["art"]])
				_drive("use_tool")  # the last page's press begins day 1
				_enter_stage(stage + 1 if stage < 11 else 15)
		15:
			if ticks >= 60:  # day 1 on the farm, in the chosen look
				_capture("shot_opening_14_day1_player.png")
				var main := current_scene
				# The replay offer: a later New Game, once the intro has been seen.
				main.queue_free()
				scene = null
				_boot("res://scenes/opening.tscn")
				_enter_stage(12)
		12:
			if ticks >= 20:
				_capture("shot_opening_12_offer.png")
				_write_named_slot()
				_boot("res://scenes/title_screen.tscn")
				_enter_stage(13)
		13:
			if ticks >= 20:
				var title := scene
				var event := InputEventAction.new()
				event.action = "move_down"
				event.pressed = true
				title._unhandled_input(event)
				event = InputEventAction.new()
				event.action = "use_tool"
				event.pressed = true
				title._unhandled_input(event)
				_enter_stage(14)
		14:
			if ticks >= 20:
				_capture("shot_opening_13_load_rows.png")
				_cleanup()
				print("SCREENSHOT OPENING: %d shots" % shots)
				quit(0)
	return false


func _drive(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	scene.handle_input(event)


func _write_named_slot() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVES_DIR))
	var rows := [
		[1, "open_plains", 3, 1783300000, {}],
		[2, "forest_edge", 12, 1783650000, {"name": "Juniper", "pronouns": "she", "appearance": {}}],
		[3, "riverside", 31, 1783728000, {"name": "Hollis", "pronouns": "he", "appearance": {}}],
	]
	for r in rows:
		var data := {"version": 2, "settlement_id": r[1], "day": r[2], "minutes_into_day": 360.0,
			"saved_unix": r[3]}
		if not (r[4] as Dictionary).is_empty():
			data["profile"] = r[4]
		var file := FileAccess.open(SAVES_DIR.path_join("slot_%d.json" % r[0]), FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()


func _cleanup() -> void:
	var abs_dir := ProjectSettings.globalize_path(SAVES_DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		for file_name in DirAccess.get_files_at(abs_dir):
			DirAccess.remove_absolute(abs_dir.path_join(file_name))
		DirAccess.remove_absolute(abs_dir)
	if FileAccess.file_exists(META):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(META))


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	shots += 1
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
