extends "res://tests/test_case.gd"
## scripts/settings.gd (Milestone E part 2): the settings store's defaults, save/load and
## sanitising, the binding codes, the rebind swap rule, and the default bindings themselves
## (every action reachable from both a keyboard and a controller). A fresh Settings instance
## writes to a scratch file; the live InputMap and audio buses it touches are put back after
## every test (after_each), so nothing leaks into other tests or the player's real settings.

const SettingsScript := preload("res://scripts/settings.gd")
const FONT_CHARS := SettingsScript.FONT_CHARS
const TEST_PATH := "user://test_settings_scratch.cfg"

var _saved_codes := {}
var _saved_volumes := {}


func _init() -> void:
	_snapshot()


func _snapshot() -> void:
	for action in SettingsScript.REBINDABLE:
		_saved_codes[action] = SettingsScript.codes_for(InputMap.action_get_events(action))
	var audio := _audio()
	if audio != null:
		_saved_volumes = audio.bus_volumes.duplicate()


func after_each() -> void:
	for action in _saved_codes:
		InputMap.action_erase_events(action)
		for code in _saved_codes[action]:
			InputMap.action_add_event(action, SettingsScript.decode_event(code))
	var audio := _audio()
	if audio != null:
		for bus in _saved_volumes:
			audio.set_bus_volume(bus, float(_saved_volumes[bus]))
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func _audio() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Audio")


func _fresh() -> Node:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var s: Node = SettingsScript.new()
	s.settings_path = TEST_PATH
	s._capture_defaults()
	s.load_settings()
	return s


func _bad_chars(text: String) -> String:
	var bad := ""
	for i in text.length():
		if not FONT_CHARS.contains(text[i]):
			bad += text[i]
	return bad


## -- Values: defaults, sanitising, save/load --

func test_missing_file_loads_every_default() -> void:
	var s := _fresh()
	for key in SettingsScript.DEFAULTS:
		assert_eq(s.get_value(key), SettingsScript.DEFAULTS[key], key)
	assert_true(s.screen_shake(), "shake on by default")
	assert_false(s.reduce_flashes())
	assert_false(s.toggle_use(), "hold-to-use by default")
	assert_eq(s.text_chars_per_second(), 28.0, "normal speed is dialogue_ui's original 28 cps")
	s.free()


func test_defaults_match_the_audio_managers_own_mix() -> void:
	var audio := _audio()
	assert_true(audio != null, "Audio autoload present")
	if audio == null:
		return
	# Settings' defaults ARE the shipped mix, so a first boot sounds exactly as before.
	var fresh_mix := {"Master": 0.9, "Music": 0.55, "SFX": 0.8, "Ambience": 0.6}
	for key in SettingsScript.BUS_FOR_KEY:
		assert_eq(SettingsScript.DEFAULTS[key], fresh_mix[SettingsScript.BUS_FOR_KEY[key]], key)


func test_sanitize_clamps_and_rejects_bad_values() -> void:
	assert_eq(SettingsScript.sanitize("audio/music", 3.0), 1.0)
	assert_eq(SettingsScript.sanitize("audio/music", -1.0), 0.0)
	assert_eq(SettingsScript.sanitize("display/window_scale", 9), 4, "unknown scale -> default")
	assert_eq(SettingsScript.sanitize("display/window_scale", 2), 2)
	assert_eq(SettingsScript.sanitize("access/text_speed", "ludicrous"), "normal")
	assert_eq(SettingsScript.sanitize("access/use_mode", "toggle"), "toggle")
	assert_eq(SettingsScript.sanitize("access/screen_shake", 0), false)


func test_values_save_and_load_back() -> void:
	var s := _fresh()
	s.set_value("audio/music", 0.3)
	s.set_value("access/screen_shake", false)
	s.set_value("access/text_speed", "instant")
	s.set_value("display/window_scale", 3)
	s.free()
	var again: Node = SettingsScript.new()
	again.settings_path = TEST_PATH
	again._capture_defaults()
	again.load_settings()
	assert_eq(again.get_value("audio/music"), 0.3)
	assert_eq(again.get_value("access/screen_shake"), false)
	assert_eq(again.get_value("access/text_speed"), "instant")
	assert_eq(again.text_chars_per_second(), 0.0, "instant reads as 0 cps")
	assert_eq(again.get_value("display/window_scale"), 3)
	again.free()


func test_garbage_in_the_file_falls_back_safely() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", "loud")
	cfg.set_value("display", "window_scale", 77)
	cfg.set_value("access", "text_speed", 12)
	cfg.set_value("input", "not_an_action", PackedStringArray(["k:65"]))
	cfg.save(TEST_PATH)
	var s: Node = SettingsScript.new()
	s.settings_path = TEST_PATH
	s._capture_defaults()
	s.load_settings()
	assert_eq(s.get_value("audio/master"), 0.0, "unparseable volume reads as silence, not a crash")
	assert_eq(s.get_value("display/window_scale"), 4)
	assert_eq(s.get_value("access/text_speed"), "normal")
	s.free()


func test_volume_change_reaches_the_bus_immediately() -> void:
	var audio := _audio()
	if audio == null:
		return
	if AudioServer.get_bus_index("Music") == -1:
		audio._ensure_buses()  # the runner tests before autoloads' _ready() runs
	var s := _fresh()
	s.set_value("audio/music", 0.25)
	assert_eq(audio.get_bus_volume("Music"), 0.25)
	assert_true(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
		- linear_to_db(0.25)) < 0.01, "the real bus moved")
	s.set_value("audio/sfx", 0.4)
	assert_true(absf(audio.get_bus_volume("UI") - 0.4 * SettingsScript.UI_TO_SFX_RATIO) < 0.001,
		"the UI bus rides the sound-effects slider")
	s.set_value("audio/master", 0.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")), "0% mutes")
	s.free()


func test_reset_settings_restores_defaults() -> void:
	var s := _fresh()
	s.set_value("access/reduce_flashes", true)
	s.set_value("audio/ambience", 0.1)
	s.reset_settings()
	assert_eq(s.get_value("access/reduce_flashes"), false)
	assert_eq(s.get_value("audio/ambience"), 0.6)
	s.free()


func test_window_size_is_an_exact_viewport_multiple() -> void:
	assert_eq(SettingsScript.window_size_for(4), Vector2i(1280, 768), "x4 is project.godot's own size")
	assert_eq(SettingsScript.window_size_for(2), Vector2i(640, 384))


## -- Binding codes --

func test_event_codes_round_trip() -> void:
	for code in ["k:87", "k:32", "kc:4194305", "m:1", "b:0", "b:10", "a:4:+", "a:1:-"]:
		assert_eq(SettingsScript.encode_event(SettingsScript.decode_event(code)), code, code)
	assert_eq(SettingsScript.decode_event("nonsense"), null)
	assert_eq(SettingsScript.kind_of("k:87"), SettingsScript.KIND_KEY)
	assert_eq(SettingsScript.kind_of("a:5:+"), SettingsScript.KIND_PAD)
	assert_eq(SettingsScript.kind_of("m:1"), "", "the mouse has no rebind slot")


func test_display_names_use_only_the_fonts_glyphs() -> void:
	var codes: Array[String] = []
	for key in [KEY_SPACE, KEY_EQUAL, KEY_MINUS, KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_BACKSLASH,
			KEY_QUOTELEFT, KEY_NUMBERSIGN, KEY_AMPERSAND, KEY_ASTERISK, KEY_LESS, KEY_GREATER,
			KEY_UNDERSCORE, KEY_AT, KEY_DOLLAR, KEY_KP_MULTIPLY, KEY_KP_ADD, KEY_F5, KEY_TAB, KEY_UP]:
		codes.append("k:%d" % key)
	for b in range(0, 21):
		codes.append("b:%d" % b)
	for a in ["a:0:-", "a:1:+", "a:4:+", "a:5:+", "a:3:-"]:
		codes.append(a)
	for code in codes:
		var text := SettingsScript.display_name(code)
		assert_true(text.strip_edges() != "", "%s has a name" % code)
		assert_eq(_bad_chars(text), "", "%s -> '%s' uses only font glyphs" % [code, text])
	assert_eq(SettingsScript.display_name("k:%d" % KEY_EQUAL), "Equals", "= becomes a word")
	assert_eq(SettingsScript.display_name("b:%d" % JOY_BUTTON_A), "A")
	assert_eq(SettingsScript.display_name("a:4:+"), "LT")


## -- The swap rule --

func _table() -> Dictionary:
	return {
		"use_tool": PackedStringArray(["k:32", "k:67", "m:1", "b:0"]),
		"interact": PackedStringArray(["k:69", "k:88", "m:2", "b:2"]),
		"move_up": PackedStringArray(["k:87", "k:4194320", "b:11", "a:1:-"]),
		"journal": PackedStringArray(["k:74", "b:4"]),
		"hotbar_slot_1": PackedStringArray(["k:49"]),
	}


func test_rebind_to_a_free_key_replaces_the_slot_in_place() -> void:
	var out := SettingsScript.rebind_codes(_table(), "journal", "key", "k:75")
	assert_eq(out["table"]["journal"], PackedStringArray(["k:75", "b:4"]))
	assert_eq(String(out["swapped_with"]), "")


func test_rebind_onto_another_actions_key_swaps_them() -> void:
	var out := SettingsScript.rebind_codes(_table(), "use_tool", "key", "k:69")  # Space -> E
	assert_eq(out["table"]["use_tool"], PackedStringArray(["k:69", "k:67", "m:1", "b:0"]))
	assert_eq(out["table"]["interact"], PackedStringArray(["k:32", "k:88", "m:2", "b:2"]),
		"interact takes Space in E's place")
	assert_eq(String(out["swapped_with"]), "interact")


func test_rebind_pad_slot_swaps_buttons_and_leaves_keys_alone() -> void:
	var out := SettingsScript.rebind_codes(_table(), "use_tool", "pad", "b:2")
	assert_eq(out["table"]["use_tool"], PackedStringArray(["k:32", "k:67", "m:1", "b:2"]))
	assert_eq(out["table"]["interact"], PackedStringArray(["k:69", "k:88", "m:2", "b:0"]))


func test_rebind_onto_an_extra_binding_takes_it_over() -> void:
	# The Up arrow is move_up's extra; giving it to journal swaps journal's J into its place.
	var out := SettingsScript.rebind_codes(_table(), "journal", "key", "k:4194320")
	assert_eq(out["table"]["journal"], PackedStringArray(["k:4194320", "b:4"]))
	assert_eq(out["table"]["move_up"], PackedStringArray(["k:87", "k:74", "b:11", "a:1:-"]))


func test_rebind_onto_its_own_extra_just_promotes_it() -> void:
	var out := SettingsScript.rebind_codes(_table(), "move_up", "key", "k:4194320")
	assert_eq(out["table"]["move_up"], PackedStringArray(["k:4194320", "b:11", "a:1:-"]),
		"no duplicate left behind")


func test_rebind_into_an_empty_slot_appends_and_takes_from_the_other() -> void:
	var out := SettingsScript.rebind_codes(_table(), "hotbar_slot_1", "pad", "b:4")
	assert_eq(out["table"]["hotbar_slot_1"], PackedStringArray(["k:49", "b:4"]))
	assert_eq(out["table"]["journal"], PackedStringArray(["k:74"]),
		"nothing to swap back, so the other action just loses it (the screen warns)")
	assert_eq(String(out["swapped_with"]), "journal")


func test_rebind_to_the_same_input_changes_nothing() -> void:
	var out := SettingsScript.rebind_codes(_table(), "use_tool", "key", "k:32")
	assert_eq(out["table"], _table())


## -- Live rebinding through the InputMap, persisted --

func test_live_rebind_swaps_saves_and_reloads() -> void:
	var s := _fresh()
	var result: Dictionary = s.rebind("use_tool", "key", SettingsScript.decode_event("k:%d" % KEY_E))
	assert_true(bool(result["ok"]))
	assert_eq(String(result["swapped_with"]), "interact")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.pressed = true
	assert_true(e.is_action_pressed("use_tool"), "E now uses the tool")
	assert_false(e.is_action_pressed("interact"), "and no longer interacts")
	assert_eq(s.binding_name("interact", "key"), "Space", "interact got Space")
	assert_true(s.binding_overrides().has("use_tool"))
	# A fresh boot reads the override back.
	InputMap.load_from_project_settings()
	var again: Node = SettingsScript.new()
	again.settings_path = TEST_PATH
	again._capture_defaults()
	again.load_settings()
	assert_true(e.is_action_pressed("use_tool"), "the rebind survives a restart")
	again.reset_bindings()
	assert_false(e.is_action_pressed("use_tool"), "reset puts Space back")
	assert_true(e.is_action_pressed("interact"))
	assert_true(again.binding_overrides().is_empty(), "nothing left to store")
	s.free()
	again.free()


func test_reserved_and_wrong_kind_inputs_are_refused() -> void:
	var s := _fresh()
	var esc: Dictionary = s.rebind("journal", "key", SettingsScript.decode_event("k:%d" % KEY_ESCAPE))
	assert_false(bool(esc["ok"]), "Escape stays the back key")
	var b: Dictionary = s.rebind("journal", "pad", SettingsScript.decode_event("b:%d" % JOY_BUTTON_B))
	assert_false(bool(b["ok"]), "B stays the back button")
	var wrong: Dictionary = s.rebind("journal", "key", SettingsScript.decode_event("b:3"))
	assert_false(bool(wrong["ok"]), "a button can't fill the keyboard slot")
	assert_eq(s.binding_name("journal", "key"), "J", "nothing changed")
	assert_true(_bad_chars(String(esc["message"])) == "", "refusal text is font-safe")
	s.free()


func test_capture_filters() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	assert_true(SettingsScript.capturable(key, "key"))
	assert_false(SettingsScript.capturable(key, "pad"))
	var small := InputEventJoypadMotion.new()
	small.axis = JOY_AXIS_TRIGGER_RIGHT
	small.axis_value = 0.3
	assert_false(SettingsScript.capturable(small, "pad"), "a resting/drifting axis isn't a press")
	small.axis_value = 0.9
	assert_true(SettingsScript.capturable(small, "pad"))
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	assert_true(SettingsScript.is_cancel_event(b))
	assert_eq(SettingsScript.axis_state(0.5, 0.3), 1)
	assert_eq(SettingsScript.axis_state(-0.1, 0.3), 0)


## -- The shipped default bindings --

func test_every_action_has_a_keyboard_and_a_controller_default() -> void:
	for action in SettingsScript.REBINDABLE:
		assert_true(InputMap.has_action(action), "%s exists" % action)
		var codes := SettingsScript.codes_for(SettingsScript.project_default_events(action))
		assert_ne(SettingsScript.slot_of(codes, "key"), "", "%s has a keyboard default" % action)
		if not SettingsScript.PAD_OPTIONAL.has(action):
			assert_ne(SettingsScript.slot_of(codes, "pad"), "", "%s has a controller default" % action)
		assert_true(SettingsScript.ACTION_LABELS.has(action), "%s has a label" % action)
		assert_eq(_bad_chars(String(SettingsScript.ACTION_LABELS.get(action, ""))), "")


func test_every_gameplay_action_in_project_godot_is_listed() -> void:
	# A new [input] action must be added to the options screen (or explicitly left off here).
	var not_rebindable := ["aim_up", "aim_down", "aim_left", "aim_right"]
	for prop in ProjectSettings.get_property_list():
		var name := String(prop["name"])
		if not name.begins_with("input/") or name.begins_with("input/ui_"):
			continue
		var action := name.substr(6)
		assert_true(SettingsScript.REBINDABLE.has(action) or not_rebindable.has(action),
			"%s is on the options screen" % action)


func test_default_bindings_never_share_an_input() -> void:
	var seen := {}
	for action in SettingsScript.REBINDABLE:
		for code in SettingsScript.codes_for(SettingsScript.project_default_events(action)):
			assert_false(seen.has(code), "%s is bound to both %s and %s" % [code, seen.get(code, ""), action])
			seen[code] = action


func test_controller_layout_is_the_documented_one() -> void:
	var pad := func(action: String) -> String:
		return SettingsScript.slot_of(SettingsScript.codes_for(
			SettingsScript.project_default_events(action)), "pad")
	assert_eq(pad.call("use_tool"), "b:%d" % JOY_BUTTON_A, "A uses / confirms")
	assert_eq(pad.call("interact"), "b:%d" % JOY_BUTTON_X, "X interacts")
	assert_eq(pad.call("toggle_inventory"), "b:%d" % JOY_BUTTON_Y, "Y opens the menu")
	assert_eq(pad.call("journal"), "b:%d" % JOY_BUTTON_BACK)
	assert_eq(pad.call("hotbar_prev"), "b:%d" % JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(pad.call("hotbar_next"), "b:%d" % JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(pad.call("build_toggle"), "a:4:+", "LT toggles build mode")
	assert_eq(pad.call("build_cycle"), "a:5:+", "RT cycles")
	var cancel := SettingsScript.codes_for(InputMap.action_get_events("ui_cancel"))
	assert_true(cancel.has("b:%d" % JOY_BUTTON_B), "B backs out of every menu")
	assert_true(SettingsScript.codes_for(InputMap.action_get_events("ui_accept")).has("b:%d" % JOY_BUTTON_A))
	assert_true(InputMap.has_action("aim_right"), "right-stick aiming exists")
