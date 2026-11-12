extends SceneTree
## Headless smoke scenario for the Milestone E opening (scenes/opening.tscn: intro -> character
## creation -> montage), driven through the REAL scenes with synthetic input, the way a
## controller player would (InputEventAction presses of the existing actions), plus a couple of
## real keyboard keystrokes for the typed-name path:
##   1. Title "New Game" -> the settlement picker, reframed as the parents' claim.
##   2. Confirming a settlement plays the intro (first launch: no replay offer); paging works,
##      and ESC skips the rest of it straight to character creation.
##   3. Creation: the name is entered on the on-screen letter grid (cursor walked with move_*,
##      cells pressed with use_tool, DONE pressed), a typed key adds a letter and an undrawable
##      typed character is filtered out; pronouns and hair colour are changed; BEGIN.
##   4. The montage plays and ESC skips to day 1: main.tscn boots with that name and look
##      (the player's SpriteFrames are the recoloured ones; NPC greetings use the name).
##   5. Save, back to the title, Load: the Load row shows the name, and the loaded game keeps
##      name / pronouns / appearance.
##   6. A second New Game offers to skip straight to the birth (the intro was seen).
##
## Test hygiene like title_smoke.gd: a throwaway saves dir and opening-meta file, wiped before
## and after. Run: godot --headless --path . --script res://tools/opening_smoke.gd

const SaveData := preload("res://scripts/save_data.gd")
const PlayerProfile := preload("res://scripts/player_profile.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")
const BASE_FRAMES := preload("res://art/characters/player/player_frames.tres")

const SAVES_DIR := "user://opening_smoke_saves"
const META := "user://opening_smoke_meta.cfg"
const MAX_TICKS_PER_STAGE := 1800

var game_state: Node
var day_manager: Node
var scene: Node
var stage := 0
var stage_started_at := 0
var failures: Array[String] = []
var _watchdog_tripped := false


func _initialize() -> void:
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.world_spawning_enabled = false
	day_manager.forced_weather = "clear"
	game_state.saves_dir = SAVES_DIR
	game_state.legacy_save_path = SAVES_DIR.path_join("legacy.json")
	game_state.save_path = SAVES_DIR.path_join("preboot.json")
	game_state.opening_meta_path = META
	_cleanup()
	_boot("res://scenes/title_screen.tscn")


func _boot(path: String) -> void:
	if scene != null and is_instance_valid(scene):
		scene.queue_free()
	scene = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	if ticks > MAX_TICKS_PER_STAGE and not _watchdog_tripped:
		_watchdog_tripped = true
		_check(false, "TIMED OUT in stage %d (watchdog)" % stage)
		return _finish()
	match stage:
		0:
			if ticks < 10:
				return false
			_check(scene._menu_entries[0] == "New Game" and not scene._menu_entries.has("Load Game"),
				"first launch: New Game first, no Load Game (got %s)" % str(scene._menu_entries))
			_press(scene, "use_tool")  # New Game
			_enter_stage(1)
		1:
			if ticks < 15:
				return false
			scene = current_scene
			if not _check(scene != null and scene.name == "SettlementSelect", "New Game -> the settlement picker"):
				return _finish()
			_check(String(scene.get_node("TitleLabel").text).contains("PARENTS"),
				"the picker is framed as the parents' claim (got '%s')" % scene.get_node("TitleLabel").text)
			_press(scene, "move_down")   # Forest Edge
			_press(scene, "use_tool")
			_check(game_state.chosen_settlement_id == "forest_edge", "Forest Edge chosen")
			_enter_stage(2)
		2:
			if ticks < 15:
				return false
			scene = current_scene
			if not _check(scene != null and scene.name == "Opening", "confirming a settlement plays the opening"):
				return _finish()
			_check(scene.mode == scene.Mode.INTRO, "first time: the intro plays (no replay offer)")
			_check(scene.page_index == 0, "intro starts on page 1")
			_check(String(scene._caption.text).contains("Forest Edge"), "page 1 names the chosen settlement")
			_press(scene, "use_tool")    # finishes the typing caption
			_check(scene.page_index == 0, "the first press only finishes the caption")
			_press(scene, "use_tool")    # next page
			_check(scene.page_index == 1, "the second press turns the page")
			_press(scene, "move_left")
			_check(scene.page_index == 0, "move_left goes back a page")
			_press(scene, "ui_cancel")   # skip the intro
			_check(scene.mode == scene.Mode.CREATE, "ESC skips the intro to character creation")
			_enter_stage(3)
		3:
			if ticks < 5:
				return false
			var creator: Control = scene.creator
			if not _check(creator != null and creator.is_inside_tree(), "the creator is up"):
				return _finish()
			_check(creator.row_index == creator.ROW_NAME, "creation starts on NAME")
			_press(scene, "use_tool")
			_check(creator.editing_name, "SPACE on NAME opens the name editor")
			# Letter grid: walk to each cell and press it (auto-caps makes the first a capital).
			for ch in ["K", "i", "t"]:
				_walk_grid_to(creator, ch)
				_press(scene, "use_tool")
			_check(creator.player_name == "Kit", "grid entry spelled 'Kit' (got '%s')" % creator.player_name)
			# A real keyboard: a typed letter goes in, an undrawable character is filtered out.
			_type_key(scene, KEY_O, "o")
			_type_key(scene, KEY_3, "#")
			_check(creator.player_name == "Kito", "typed 'o' added, '#' filtered (got '%s')" % creator.player_name)
			_walk_grid_to(creator, PlayerProfile.GRID_DONE)
			_press(scene, "use_tool")
			_check(not creator.editing_name, "DONE closes the editor")
			_check(creator.row_index == creator.ROW_PRONOUNS, "...and moves on to PRONOUNS")
			_press(scene, "move_right")  # they -> he
			_check(creator.pronouns == "he", "pronouns changed to he (got %s)" % creator.pronouns)
			_press(scene, "move_down")   # LOOK
			_press(scene, "move_down")   # HAIR
			_press(scene, "move_right")
			_press(scene, "move_right")
			_check(int(creator.appearance["hair"]) == 2, "hair colour stepped to Auburn")
			_check(creator._preview.sprite_frames != BASE_FRAMES, "the live preview shows the new look")
			for i in 3:
				_press(scene, "move_down")  # SKIN, OUTFIT, BEGIN
			_check(creator.row_index == creator.ROW_BEGIN, "reached BEGIN")
			_press(scene, "use_tool")
			_check(game_state.player_name == "Kito", "GameState has the name")
			_check(game_state.player_pronouns == "he", "GameState has the pronouns")
			_check(int(game_state.player_appearance["hair"]) == 2, "GameState has the look")
			_check(scene.mode == scene.Mode.MONTAGE, "BEGIN plays the montage")
			_enter_stage(4)
		4:
			if ticks < 5:
				return false
			_press(scene, "use_tool")
			_press(scene, "use_tool")
			_check(scene.page_index == 1, "montage pages advance")
			_press(scene, "ui_cancel")   # skip to day 1
			_enter_stage(5)
		5:
			if ticks < 25:
				return false
			scene = current_scene
			if not _check(scene != null and scene.name == "Main", "the montage ends in main.tscn"):
				return _finish()
			_check(day_manager.day == 1, "day 1")
			_check_player_dressed("new game")
			_check(DialogueDB.fill(String(DialogueDB.dialogue_node("mayor_harlan", "greet").get("text", "")), {}).contains("Kito"),
				"Harlan greets the player by name")
			var cfg := ConfigFile.new()
			_check(cfg.load(META) == OK and bool(cfg.get_value("opening", "seen", false)), "the intro is marked seen")
			_check(game_state.save_game(scene.get_node("Player"), scene.zones, scene.get_node("Settlers"),
				scene.get_node("Animals"), scene.get_node("Affinity")), "the first save wrote")
			var data := SaveData.parse_save(FileAccess.get_file_as_string(game_state.save_path))
			var profile: Dictionary = data.get("profile", {})
			_check(String(profile.get("name", "")) == "Kito" and String(profile.get("pronouns", "")) == "he"
				and int((profile.get("appearance", {}) as Dictionary).get("hair", -1)) == 2,
				"the save file carries the profile (got %s)" % str(profile))
			# Forget everything, as a fresh launch would, then go back to the title.
			game_state.set_profile("", "they", PlayerProfile.default_appearance())
			_boot("res://scenes/title_screen.tscn")
			_enter_stage(6)
		6:
			if ticks < 10:
				return false
			_press(scene, "move_down")
			_press(scene, "use_tool")    # Load Game
			_check(scene.mode == scene.Mode.LOAD, "Load panel open")
			var row := String(scene._slot_labels[0].text) if not scene._slot_labels.is_empty() else ""
			_check(row.contains("Kito") and row.contains("Forest Edge"), "the Load row shows the name (got '%s')" % row)
			_press(scene, "use_tool")
			_enter_stage(7)
		7:
			if ticks < 25:
				return false
			scene = current_scene
			if not _check(scene != null and scene.name == "Main", "loading boots main.tscn"):
				return _finish()
			_check(game_state.player_name == "Kito", "the name survives save + load")
			_check(game_state.player_pronouns == "he", "the pronouns survive save + load")
			_check(int(game_state.player_appearance["hair"]) == 2, "the look survives save + load")
			_check_player_dressed("loaded game")
			var line: String = scene.get_node("MenuScreen").profile_line(game_state.player_name,
				game_state.player_pronouns, game_state.chosen_settlement_id)
			_check(line.begins_with("Kito"), "the menu's profile line names the player (got '%s')" % line)
			_boot("res://scenes/title_screen.tscn")
			_enter_stage(8)
		8:
			if ticks < 10:
				return false
			_press(scene, "use_tool")    # New Game again
			_enter_stage(9)
		9:
			if ticks < 15:
				return false
			scene = current_scene
			_press(scene, "use_tool")    # confirm the default settlement
			_enter_stage(10)
		10:
			if ticks < 15:
				return false
			scene = current_scene
			if not _check(scene != null and scene.name == "Opening", "second New Game reaches the opening"):
				return _finish()
			_check(scene.mode == scene.Mode.OFFER, "seen before: the opening offers to skip")
			_check(game_state.player_name == "", "a new playthrough starts with no name")
			_press(scene, "use_tool")    # "Skip to the birth" is pre-selected
			_check(scene.mode == scene.Mode.CREATE, "skip goes straight to character creation")
			return _finish()
	return false


func _check_player_dressed(context: String) -> void:
	var sprite: AnimatedSprite2D = scene.get_node("Player").get_node("Sprite")
	_check(sprite.sprite_frames != BASE_FRAMES, "%s: the player wears the chosen look" % context)
	_check(sprite.sprite_frames != null and sprite.sprite_frames.has_animation("walk_south")
		and sprite.sprite_frames.get_frame_count("tool_east") == BASE_FRAMES.get_frame_count("tool_east"),
		"%s: the recoloured frames keep every animation" % context)


## Walks the creator's letter-grid cursor to `cell` with real move_* presses.
func _walk_grid_to(creator: Control, cell: String) -> void:
	var target: Vector2i = creator.grid_cell_of(cell)
	if not _check(target.x >= 0, "'%s' is on the grid" % cell):
		return
	var guard := 0
	while creator.grid_cursor.y != target.y and guard < 20:
		_press(scene, "move_down")
		guard += 1
	while creator.grid_cursor.x != target.x and guard < 40:
		_press(scene, "move_right")
		guard += 1
	_check(creator.grid_cursor == target, "cursor reached '%s'" % cell)


func _press(target: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	if target.has_method("handle_input"):
		target.handle_input(event)
	else:
		target._unhandled_input(event)


func _type_key(target: Node, keycode: Key, text: String) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.unicode = text.unicode_at(0)
	event.pressed = true
	target.handle_input(event)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append("stage %d: %s" % [stage, message])
	return condition


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()


func _finish() -> bool:
	_cleanup()
	if failures.is_empty():
		print("OPENING SMOKE: all checks passed")
		quit(0)
	else:
		for f in failures:
			print("OPENING SMOKE FAIL: %s" % f)
		quit(1)
	return true


func _cleanup() -> void:
	var abs_dir := ProjectSettings.globalize_path(SAVES_DIR)
	if DirAccess.dir_exists_absolute(abs_dir):
		for file_name in DirAccess.get_files_at(abs_dir):
			DirAccess.remove_absolute(abs_dir.path_join(file_name))
		DirAccess.remove_absolute(abs_dir)
	if FileAccess.file_exists(META):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(META))
