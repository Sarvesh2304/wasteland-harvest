extends SceneTree
## Milestone E part 2 options smoke (2026-11-12): the settings store, the options screen and
## controller support, driven through the real screens.
##   1. Title -> Options (keyboard): the shared options screen opens over the title; Music down
##      two steps moves the real Music bus; Screen shake off; on CONTROLS, Journal rebound to K
##      through a real key press; Esc backs out to the title menu.
##   2. "Restart": the InputMap and audio are put back to project defaults and Settings reloads
##      user://...cfg from disk — every change comes back (and the file holds them).
##   3. In game (Forest Edge): K (the new binding) opens the menu on the JOURNAL tab; a hit with
##      shake off leaves the camera still; the in-game OPTIONS tab turns shake back on and the
##      next hit shakes; "Reset controls to defaults" puts Journal back on J.
##   4. Controller only (InputEventJoypadButton / JoypadMotion through Input.parse_input_event,
##      the path a real pad takes): Y opens the menu, RB changes tab, B closes; the right stick
##      aims; A talks to Marta, A through her dialogue into the store, A buys, d-pad up + A
##      leaves; Start + A + A saves and returns to the title; d-pad to Options and back with B;
##      d-pad to Load Game, A, A loads the save back into the world.
## Settings and saves go to scratch paths, so a run never touches the player's own files.
## Run: godot --headless --path . --audio-driver Dummy --script res://tools/options_smoke.gd

const SettingsScript := preload("res://scripts/settings.gd")

const SETTINGS_FILE := "user://options_smoke_settings.cfg"
const SAVES_DIR := "user://options_smoke_saves"

var settings: Node
var game_state: Node
var day_manager: Node
var audio: Node
var title: Node
var main: Node
var player: Node
var failures: Array[String] = []
var _step := ""


func _initialize() -> void:
	settings = root.get_node("Settings")
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	audio = root.get_node("Audio")
	# Before the autoloads' _ready(): Settings then loads (nothing) from the scratch file.
	settings.settings_path = SETTINGS_FILE
	_remove(SETTINGS_FILE)
	game_state.world_spawning_enabled = false
	day_manager.forced_weather = "clear"
	game_state.saves_dir = SAVES_DIR
	game_state.legacy_save_path = SAVES_DIR.path_join("legacy.json")
	game_state.save_path = SAVES_DIR.path_join("slot_1.json")
	_wipe_saves()
	_run()


func _run() -> void:
	await _frames(3)
	await _title_options()
	await _restart_settings()
	await _in_game()
	await _controller_pass()
	_finish()


## -- 1. Title -> Options, keyboard --

func _title_options() -> void:
	_step = "title options"
	_check(not bool(settings.get_value("access/reduce_flashes")), "fresh settings are the defaults")
	title = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
	root.add_child(title)
	current_scene = title
	await _frames(5)
	var at: int = title._menu_entries.find("Options")
	_check(at != -1, "the title offers Options (%s)" % str(title._menu_entries))
	for i in at:
		_drive(title, "move_down")
	_drive(title, "use_tool")
	_check(title.mode == title.Mode.OPTIONS, "Options opened")
	var opts: Control = title.options_menu
	_check(opts != null and opts.is_visible_in_tree(), "the options screen shows over the title")
	if opts == null:
		return
	await _frames(1)
	_check(opts.visible_texts().has("Master volume"), "the settings page lists Master volume")
	# Music: two steps down.
	_check(opts.select("audio/music"), "Music row found")
	_drive(title, "move_left")
	_drive(title, "move_left")
	_check(is_equal_approx(float(settings.get_value("audio/music")), 0.35), "Music at 35%% (%s)"
		% str(settings.get_value("audio/music")))
	_check(is_equal_approx(audio.get_bus_volume("Music"), 0.35), "the Music bus moved")
	_check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.35)) < 0.01,
		"the AudioServer bus is at 35%")
	# Screen shake off.
	_check(opts.select("access/screen_shake"), "Screen shake row found")
	_drive(title, "use_tool")
	_check(not bool(settings.get_value("access/screen_shake")), "screen shake is off")
	# CONTROLS page: rebind Journal (J) to K with a real key press.
	opts.selected = 0
	_drive(title, "move_right")
	_check(opts.page == opts.PAGE_CONTROLS, "the CONTROLS page is up")
	_check(opts.visible_texts().has("Journal"), "Journal is listed")
	_check(opts.select("journal"), "Journal row found")
	_drive(title, "use_tool")
	_check(opts.capturing, "waiting for a key")
	title._unhandled_input(_key(KEY_ESCAPE))
	_check(not opts.capturing and title.mode == title.Mode.OPTIONS, "Esc cancels the rebind, not the screen")
	_check(settings.binding_name("journal", "key") == "J", "still J after cancelling")
	_drive(title, "use_tool")
	title._unhandled_input(_key(KEY_K))
	_check(not opts.capturing, "the key press was taken")
	_check(settings.binding_name("journal", "key") == "K", "Journal is on K (%s)" % settings.binding_name("journal", "key"))
	_check(_key(KEY_K).is_action_pressed("journal") and not _key(KEY_J).is_action_pressed("journal"),
		"the InputMap follows")
	# A conflicting rebind swaps: Journal onto B (build mode) and straight back.
	_drive(title, "use_tool")
	title._unhandled_input(_key(KEY_B))
	_check(String(opts.status).begins_with("Swapped with Build mode"), "the swap is reported (%s)" % opts.status)
	_check(settings.binding_name("build_toggle", "key") == "K", "build mode took K")
	_drive(title, "use_tool")
	title._unhandled_input(_key(KEY_K))
	_check(settings.binding_name("build_toggle", "key") == "B" and settings.binding_name("journal", "key") == "K",
		"and swapped back")
	_drive(title, "ui_cancel")
	_check(title.mode == title.Mode.MENU, "Esc returns to the title menu")
	_check(title._menu_entries[title._menu_index] == "Options", "on the Options row")
	_check(FileAccess.file_exists(SETTINGS_FILE), "settings were saved")
	title.queue_free()
	title = null
	await _frames(2)


## -- 2. Settings survive a restart --

func _restart_settings() -> void:
	_step = "restart"
	InputMap.load_from_project_settings()
	for key in SettingsScript.BUS_FOR_KEY:
		audio.set_bus_volume(SettingsScript.BUS_FOR_KEY[key], float(SettingsScript.DEFAULTS[key]))
	settings.values = {}
	settings.load_settings()
	_check(is_equal_approx(float(settings.get_value("audio/music")), 0.35), "Music is back at 35%")
	_check(is_equal_approx(audio.get_bus_volume("Music"), 0.35), "and applied to the bus at load")
	_check(not bool(settings.get_value("access/screen_shake")), "shake still off")
	_check(_key(KEY_K).is_action_pressed("journal"), "Journal still on K")
	var cfg := ConfigFile.new()
	_check(cfg.load(SETTINGS_FILE) == OK, "the file parses")
	_check(cfg.has_section_key("input", "journal") and not cfg.has_section_key("input", "use_tool"),
		"only the changed action is stored")
	await _frames(1)


## -- 3. In game --

func _in_game() -> void:
	_step = "in game"
	game_state.chosen_settlement_id = "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(12)
	player = main.get_node("Player")
	day_manager.minutes_into_day = 9 * 60.0
	var menu: Node = main.get_node("MenuScreen")
	# The rebound key, through the real input path.
	await _tap_key(KEY_K)
	_check(menu.active and menu.tab_index == menu.TAB_JOURNAL, "K opened the menu on the JOURNAL tab")
	await _tap_key(KEY_K)
	_check(not menu.active, "K again closes it")
	# A hit with shake off: the camera stays put.
	var camera: Node = root.get_node("Fx")._camera
	_check(camera != null, "the game camera is registered")
	if camera == null:
		return
	player.take_hit(4, player.global_position + Vector2(20, 0), 0.0)
	_check(float(camera._shake_time_left) == 0.0, "no shake on a hit with shake off")
	await _frames(2)
	_check(camera.offset == Vector2.ZERO, "camera offset stays zero")
	# The in-game OPTIONS tab: shake back on.
	menu.open_menu()
	_drive(menu, "hotbar_prev")  # ITEMS wraps back to OPTIONS
	_check(menu.tab_index == menu.TAB_OPTIONS and menu.options.is_visible_in_tree(), "OPTIONS tab shows the options screen")
	_check(menu.options.select("access/screen_shake"), "shake row found in game")
	_drive(menu, "move_right")
	_check(bool(settings.get_value("access/screen_shake")), "shake back on")
	_check(menu.active, "Left/Right changed the value, not the tab")
	_drive(menu, "ui_cancel")
	_check(not menu.active, "Esc closes the menu")
	await _frames(2)
	player._iframes = 0.0
	player.take_hit(4, player.global_position + Vector2(20, 0), 0.0)
	_check(float(camera._shake_time_left) > 0.0, "and the next hit shakes")
	# Reset controls from the in-game screen.
	menu.open_menu(menu.TAB_OPTIONS)
	menu.options.set_page(menu.options.PAGE_CONTROLS)
	_check(menu.options.select("reset_bindings"), "reset row found")
	_drive(menu, "use_tool")
	_check(settings.binding_name("journal", "key") == "J", "reset put Journal back on J")
	_check(settings.binding_overrides().is_empty(), "no overrides left")
	# A rebind on the in-game screen gets the Tab key itself (every press goes to it).
	_check(menu.options.select("journal"), "journal row found")
	_drive(menu, "use_tool")
	menu._unhandled_input(_key(KEY_ESCAPE))
	_check(menu.active and not menu.options.capturing, "Esc cancelled the rebind and left the menu open")
	_drive(menu, "ui_cancel")
	_check(not menu.active, "then Esc closes")
	player.set_hp(player.effective_max_hp())
	await _frames(30)  # let the knockback and iframes settle
	# Toggle-mode use button: a tap starts the repeat, a second tap stops it, a modal stops it.
	settings.set_value("access/use_mode", "toggle")
	await _tap_action("use_tool")
	await _frames(8)
	_check(player._use_latched and player._use_pressed(), "a tap keeps using in toggle mode")
	await _tap_action("use_tool")
	_check(not player._use_latched, "a second tap stops")
	await _tap_action("use_tool")
	_check(player._use_latched, "started again")
	menu.open_menu()
	await _frames(3)
	_check(not player._use_latched, "opening the menu releases it")
	menu.close()
	settings.set_value("access/use_mode", "hold")
	for i in 240:  # let the last swing finish (animations run on real time)
		if not player.using_tool:
			break
		await physics_frame


## -- 4. Controller only --

func _controller_pass() -> void:
	_step = "controller"
	var menu: Node = main.get_node("MenuScreen")
	var dialogue: Node = main.get_node("DialogueUI")
	var store: Node = main.get_node("StoreUI")
	await _pad(JOY_BUTTON_Y)
	_check(settings.using_pad, "Settings saw the controller")
	_check(menu.active and menu.tab_index == menu.TAB_INVENTORY, "Y opens the menu")
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	_check(menu.tab_index == menu.TAB_CRAFT, "RB changes tab")
	await _pad(JOY_BUTTON_B)
	_check(not menu.active, "B closes the menu")
	# Right stick aims (and turns the player).
	player.facing = "south"
	await _stick(JOY_AXIS_RIGHT_X, 1.0, 3)
	_check(player.facing == "east", "the right stick turned the player east (%s)" % player.facing)
	_check(player._aim_vector().is_equal_approx(Vector2(1, 0)), "and aims east")
	await _stick(JOY_AXIS_RIGHT_X, 0.0, 2)
	_check(player._aim_vector() == Vector2(1, 0) and player._stick_aim == Vector2.ZERO,
		"at rest, aim falls back to facing")
	# HUD prompt names the pad's buttons now.
	var hud: Node = main.get_node("HUD")
	_check(hud._key_name("use_tool") == "A" and hud._key_name("interact") == "X",
		"HUD prompts read A / X on the pad")
	# Talk to Marta and shop, pad only.
	main._bind_zone("town")
	var map: Node = main.zones["town"]["map"]
	var marta: Node = null
	for npc in main.zones["town"]["npcs"].npcs():
		if String(npc.npc_id) == "marta":
			marta = npc
	_check(marta != null, "Marta is in town")
	if marta == null:
		return
	var cell: Vector2i = map.world_to_cell(marta.global_position)
	player.global_position = map.get_global_cell_center(cell + Vector2i(0, -1))
	player.velocity = Vector2.ZERO
	player.facing = "south"
	player.set_credits(500)
	await _frames(3)
	await _pad(JOY_BUTTON_A)
	_check(dialogue.active, "A talked to Marta")
	_check(String(dialogue._hint_text()).contains("A"), "the dialogue hint names A (%s)" % dialogue._hint_text())
	for i in 4:
		if store.active:
			break
		await _pad(JOY_BUTTON_A)
	_check(store.active, "A through her dialogue opened the store")
	if store.active:
		var credits := int(player.credits)
		var item: String = store._row_ids[0]
		var had: int = player.inventory.count_of(item)
		await _pad(JOY_BUTTON_A)
		_check(int(player.credits) < credits and player.inventory.count_of(item) == had + 1,
			"A bought a %s (%d -> %d credits)" % [item, credits, int(player.credits)])
		await _pad(JOY_BUTTON_DPAD_UP)
		_check(store._index == store._row_ids.size() - 1, "d-pad up wrapped to Leave")
		await _pad(JOY_BUTTON_A)
		_check(not store.active and not dialogue.active, "A on Leave closed the store")
	await _frames(5)
	# Save & return to the title from the menu, pad only.
	await _pad(JOY_BUTTON_START)
	_check(menu.active, "Start opens the menu")
	_check(String(menu.quit_label.text).begins_with("A"), "the footer names A (%s)" % menu.quit_label.text)
	await _pad(JOY_BUTTON_A)
	await _pad(JOY_BUTTON_A)
	await _frames(10)
	title = current_scene
	_check(title != null and title.name == "TitleScreen", "A, A saved and returned to the title")
	if title == null or title.name != "TitleScreen":
		return
	main = null
	await _frames(5)
	var entries: Array = title._menu_entries
	_check(entries.has("Load Game"), "Load Game is offered (%s)" % str(entries))
	# Options from the title with the pad, and back with B.
	for i in entries.find("Options"):
		await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	_check(title.mode == title.Mode.OPTIONS, "A opened Options from the title")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var row: Dictionary = title.options_menu.selected_row()
	_check(String(row.get("key", "")) == "audio/music", "the d-pad moves through rows (%s)" % str(row))
	await _stick(JOY_AXIS_LEFT_Y, 1.0, 1)
	await _stick(JOY_AXIS_LEFT_Y, 0.98, 1)  # a held stick's jitter is one push, not two
	await _stick(JOY_AXIS_LEFT_Y, 0.0, 1)
	row = title.options_menu.selected_row()
	_check(String(row.get("key", "")) == "audio/sfx", "one stick push = one row (%s)" % str(row))
	await _pad(JOY_BUTTON_B)
	_check(title.mode == title.Mode.MENU, "B came back to the title menu")
	# Load Game, pad only.
	while title._menu_entries[title._menu_index] != "Load Game":
		await _pad(JOY_BUTTON_DPAD_UP)
	await _pad(JOY_BUTTON_A)
	_check(title.mode == title.Mode.LOAD, "A opened Load Game")
	await _pad(JOY_BUTTON_A)
	await _frames(15)
	_check(current_scene != null and current_scene.name == "Main", "A loaded the save into the world")


## -- Helpers --

func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _drive(node: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	node._unhandled_input(event)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e


func _tap_key(code: Key) -> void:
	var e := _key(code)
	Input.parse_input_event(e)
	await _physics(2)
	var up := e.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await _physics(2)


func _tap_action(action: String) -> void:
	Input.action_press(action)
	await _physics(2)
	Input.action_release(action)
	await _physics(2)


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _pad(button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = true
	e.pressure = 1.0
	Input.parse_input_event(e)
	await _physics(2)  # gameplay polls the pad on physics ticks
	var up := e.duplicate() as InputEventJoypadButton
	up.pressed = false
	up.pressure = 0.0
	Input.parse_input_event(up)
	await _physics(3)


func _stick(axis: JoyAxis, value: float, frames: int) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)
	await _physics(frames)


var _checks := 0


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		failures.append("%s: %s" % [_step, message])


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _wipe_saves() -> void:
	if DirAccess.dir_exists_absolute(SAVES_DIR):
		for f in DirAccess.get_files_at(SAVES_DIR):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVES_DIR.path_join(f)))


func _finish() -> void:
	_remove(SETTINGS_FILE)
	_wipe_saves()
	if failures.is_empty():
		print("OPTIONS SMOKE: all checks passed (%d checks)" % _checks)
		quit(0)
	else:
		for f in failures:
			print("OPTIONS SMOKE FAIL: " + f)
		quit(1)
