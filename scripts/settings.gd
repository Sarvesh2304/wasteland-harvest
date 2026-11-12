extends Node
## Player settings (autoload "Settings", Milestone E part 2, 2026-11-12): one persistent store at
## user://settings.cfg (a ConfigFile), loaded at boot — the autoload sits after Audio and Fx in
## project.godot, so its _ready() runs before the title screen exists and before anything plays —
## and applied the moment a value changes. The options screen (scripts/options_menu.gd, hosted by
## both the title screen and the in-game menu's OPTIONS tab) is just a view over this node.
##
## What lives here:
##   - sound: master / music / sound effects / ambience volumes (linear 0..1, shown as %), pushed
##     straight into scripts/audio_manager.gd's buses. The UI bus follows the sound-effects
##     slider at its default ratio (UI clicks are sound effects to a player).
##   - display: fullscreen, windowed scale (x2..x5 of the 320x192 viewport), vsync.
##   - accessibility: screen shake (gates scripts/game_camera.gd's shake()), reduce flashes (hit
##     flashes, the hurt vignette, muzzle flashes), dialogue text speed (incl. instant), the use
##     button's hold-vs-toggle repeat (scripts/player.gd), pause when the window loses focus.
##   - controls: every rebindable action's keyboard key and controller button, written as
##     overrides of project.godot's [input] defaults and applied through InputMap at boot.
##
## Bindings model. Each REBINDABLE action has two "slots": its FIRST keyboard key and its FIRST
## controller input (button, or trigger/axis motion), in project.godot's own event order. The
## options screen rebinds a slot in place; every other event the action carries (the arrow keys
## behind W/A/S/D, the left stick behind the d-pad, the mouse buttons) stays as it is. A rebind
## onto an input another action already uses SWAPS the two (the other action gets this slot's old
## input), so nothing is ever silently left unbound or double-bound; rebind() reports the swap so
## the screen can say so. Escape and the pad's B button are reserved (they back out of menus and
## cancel a pending rebind), so they can't be bound. Overrides are stored per action as the
## action's full event list (see encode_event); an action matching its default isn't stored, so a
## future project.godot change to an untouched action still reaches the player.
##
## Also tracks the last input device (keyboard+mouse vs controller) so on-screen hints can show
## the right names: prompt("use_tool") is "Space" or "A".
##
## Pure helpers (encode/decode, display names, the swap rule) are static and unit-tested in
## tests/test_settings.gd; tools/options_smoke.gd drives the real screens.

signal changed(key: String)
signal bindings_changed
signal input_device_changed(using_pad: bool)

const SETTINGS_PATH := "user://settings.cfg"

const TEXT_SPEEDS: Array[String] = ["slow", "normal", "fast", "instant"]
## Characters per second for each text speed (0 = instant).
const TEXT_SPEED_CPS := {"slow": 16.0, "normal": 28.0, "fast": 56.0, "instant": 0.0}
const USE_MODES: Array[String] = ["hold", "toggle"]
const WINDOW_SCALES: Array[int] = [2, 3, 4, 5]
const BASE_VIEWPORT := Vector2i(320, 192)
## The UI bus rides the sound-effects slider at audio_manager.gd's default ratio (0.7 / 0.8).
const UI_TO_SFX_RATIO := 0.875

const DEFAULTS := {
	"audio/master": 0.9,
	"audio/music": 0.55,
	"audio/sfx": 0.8,
	"audio/ambience": 0.6,
	"display/fullscreen": false,
	"display/window_scale": 4,
	"display/vsync": true,
	"access/screen_shake": true,
	"access/reduce_flashes": false,
	"access/text_speed": "normal",
	"access/use_mode": "hold",
	"access/pause_on_focus_loss": false,
}
const BUS_FOR_KEY := {"audio/master": "Master", "audio/music": "Music", "audio/sfx": "SFX",
	"audio/ambience": "Ambience"}

## Every gameplay action the options screen lists, in display order, with its label.
const REBINDABLE: Array[String] = ["move_up", "move_down", "move_left", "move_right", "use_tool",
	"interact", "toggle_inventory", "journal", "hotbar_prev", "hotbar_next", "build_toggle",
	"build_cycle", "hotbar_slot_1", "hotbar_slot_2", "hotbar_slot_3", "hotbar_slot_4",
	"hotbar_slot_5", "hotbar_slot_6", "hotbar_slot_7", "hotbar_slot_8", "hotbar_slot_9"]
const ACTION_LABELS := {
	"move_up": "Move up", "move_down": "Move down", "move_left": "Move left",
	"move_right": "Move right", "use_tool": "Use tool / confirm", "interact": "Interact / talk",
	"toggle_inventory": "Menu", "journal": "Journal", "hotbar_prev": "Hotbar previous",
	"hotbar_next": "Hotbar next", "build_toggle": "Build mode", "build_cycle": "Next blueprint / tab",
	"hotbar_slot_1": "Hotbar slot 1", "hotbar_slot_2": "Hotbar slot 2",
	"hotbar_slot_3": "Hotbar slot 3", "hotbar_slot_4": "Hotbar slot 4",
	"hotbar_slot_5": "Hotbar slot 5", "hotbar_slot_6": "Hotbar slot 6",
	"hotbar_slot_7": "Hotbar slot 7", "hotbar_slot_8": "Hotbar slot 8",
	"hotbar_slot_9": "Hotbar slot 9",
}
## Actions with no controller default by design: the pad picks hotbar slots with LB/RB. They can
## still be given a controller button on the options screen.
const PAD_OPTIONAL: Array[String] = ["hotbar_slot_1", "hotbar_slot_2", "hotbar_slot_3",
	"hotbar_slot_4", "hotbar_slot_5", "hotbar_slot_6", "hotbar_slot_7", "hotbar_slot_8",
	"hotbar_slot_9"]
## Inputs that can never be bound (they back out of menus and cancel a pending rebind).
const RESERVED: Array[String] = ["k:4194305", "b:1"]  # Escape, pad B

const KIND_KEY := "key"
const KIND_PAD := "pad"

## The glyphs the UI font has (tests/test_dialogue_content.gd's FONT_CHARS): display names are
## built from these only.
const FONT_CHARS := " !\"'()+,-./0123456789:;?ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz–—‘’“”…↑↓←→%♥♡{}"

## Key names Godot spells as one CamelCase word, or with glyphs the font lacks, in plain words.
const KEY_WORDS := {
	KEY_SPACE: "Space", KEY_ESCAPE: "Esc", KEY_ENTER: "Enter", KEY_KP_ENTER: "Num Enter",
	KEY_TAB: "Tab", KEY_BACKSPACE: "Backspace", KEY_UP: "Up", KEY_DOWN: "Down", KEY_LEFT: "Left",
	KEY_RIGHT: "Right", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_META: "Meta",
	KEY_CAPSLOCK: "Caps Lock", KEY_PAGEUP: "Page Up", KEY_PAGEDOWN: "Page Down",
	KEY_HOME: "Home", KEY_END: "End", KEY_INSERT: "Insert", KEY_DELETE: "Delete",
	KEY_MINUS: "-", KEY_EQUAL: "Equals", KEY_BRACKETLEFT: "Left Bracket",
	KEY_BRACKETRIGHT: "Right Bracket", KEY_BACKSLASH: "Backslash", KEY_SEMICOLON: ";",
	KEY_APOSTROPHE: "'", KEY_QUOTELEFT: "Backtick", KEY_COMMA: ",", KEY_PERIOD: ".",
	KEY_SLASH: "/", KEY_KP_ADD: "Num +", KEY_KP_SUBTRACT: "Num -", KEY_KP_MULTIPLY: "Num Times",
	KEY_KP_DIVIDE: "Num /", KEY_KP_PERIOD: "Num .", KEY_NUMBERSIGN: "Hash", KEY_AMPERSAND: "And",
	KEY_ASTERISK: "Star", KEY_DOLLAR: "Dollar", KEY_AT: "At", KEY_UNDERSCORE: "Underscore",
	KEY_LESS: "Less", KEY_GREATER: "Greater", KEY_ASCIICIRCUM: "Caret", KEY_ASCIITILDE: "Tilde",
	KEY_BRACELEFT: "{", KEY_BRACERIGHT: "}", KEY_BAR: "Bar",
}
## Xbox-layout names (the default layout the controller bindings are written for).
const PAD_BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "LS click", JOY_BUTTON_RIGHT_STICK: "RS click",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad Up", JOY_BUTTON_DPAD_DOWN: "D-pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-pad Left", JOY_BUTTON_DPAD_RIGHT: "D-pad Right",
	JOY_BUTTON_MISC1: "Share", JOY_BUTTON_PADDLE1: "Paddle 1", JOY_BUTTON_PADDLE2: "Paddle 2",
	JOY_BUTTON_PADDLE3: "Paddle 3", JOY_BUTTON_PADDLE4: "Paddle 4", JOY_BUTTON_TOUCHPAD: "Touchpad",
}
const PAD_AXIS_NAMES := {
	"a:0:-": "L-stick Left", "a:0:+": "L-stick Right", "a:1:-": "L-stick Up", "a:1:+": "L-stick Down",
	"a:2:-": "R-stick Left", "a:2:+": "R-stick Right", "a:3:-": "R-stick Up", "a:3:+": "R-stick Down",
	"a:4:+": "LT", "a:5:+": "RT", "a:4:-": "LT", "a:5:-": "RT",
}
## A controller press counts once an axis passes this (triggers, sticks) during a rebind.
const AXIS_CAPTURE_THRESHOLD := 0.7

var settings_path := SETTINGS_PATH
var values: Dictionary = {}
## True when the last real input came from a controller (drives prompt()).
var using_pad := false
## project.godot's own events per rebindable action (the "reset to defaults" target).
var _default_events: Dictionary = {}
var _paused_by_focus := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_defaults()
	load_settings()


## -- Values --

func get_value(key: String):
	return values.get(key, DEFAULTS.get(key))


## Sets, applies and (by default) saves one setting.
func set_value(key: String, value, save := true) -> void:
	if not DEFAULTS.has(key):
		push_warning("Settings: unknown key %s" % key)
		return
	values[key] = sanitize(key, value)
	_apply(key)
	if save:
		save_settings()
	changed.emit(key)


## Convenience reads used by gameplay code.
func screen_shake() -> bool:
	return bool(get_value("access/screen_shake"))


func reduce_flashes() -> bool:
	return bool(get_value("access/reduce_flashes"))


func toggle_use() -> bool:
	return String(get_value("access/use_mode")) == "toggle"


## Dialogue reveal speed in characters per second; 0 means show the whole line at once.
func text_chars_per_second() -> float:
	return float(TEXT_SPEED_CPS.get(String(get_value("access/text_speed")), 28.0))


## Clamps/normalises a value to its key's legal range (bad file contents can't break anything).
static func sanitize(key: String, value):
	var default = DEFAULTS.get(key)
	match key:
		"audio/master", "audio/music", "audio/sfx", "audio/ambience":
			return clampf(snappedf(float(value), 0.01), 0.0, 1.0)
		"display/window_scale":
			var scale := int(value)
			return scale if WINDOW_SCALES.has(scale) else int(default)
		"access/text_speed":
			return String(value) if TEXT_SPEEDS.has(String(value)) else String(default)
		"access/use_mode":
			return String(value) if USE_MODES.has(String(value)) else String(default)
	if default is bool:
		return bool(value)
	return value


## -- Persistence --

func load_settings() -> void:
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	var overrides := {}
	if cfg.load(settings_path) == OK:
		for key in DEFAULTS:
			var parts := String(key).split("/")
			if cfg.has_section_key(parts[0], parts[1]):
				values[key] = sanitize(key, cfg.get_value(parts[0], parts[1]))
		if cfg.has_section("input"):
			for action in cfg.get_section_keys("input"):
				overrides[action] = cfg.get_value("input", action)
	apply_all()
	apply_bindings(overrides)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in DEFAULTS:
		var parts := String(key).split("/")
		cfg.set_value(parts[0], parts[1], values.get(key, DEFAULTS[key]))
	var overrides := binding_overrides()
	for action in overrides:
		cfg.set_value("input", action, overrides[action])
	var err := cfg.save(settings_path)
	if err != OK:
		push_warning("Settings: could not save %s (%d)" % [settings_path, err])


## Every non-binding setting back to its default (bindings have their own reset).
func reset_settings() -> void:
	values = DEFAULTS.duplicate()
	apply_all()
	save_settings()
	for key in DEFAULTS:
		changed.emit(key)


## -- Applying --

func apply_all() -> void:
	for key in DEFAULTS:
		_apply(key)


func _apply(key: String) -> void:
	if BUS_FOR_KEY.has(key):
		var audio := _autoload("Audio")
		if audio != null:
			audio.set_bus_volume(BUS_FOR_KEY[key], float(get_value(key)))
			if key == "audio/sfx":
				audio.set_bus_volume("UI", float(get_value(key)) * UI_TO_SFX_RATIO)
		return
	if key.begins_with("display/"):
		_apply_display()


func _apply_display() -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var fullscreen := bool(get_value("display/fullscreen"))
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen:
		if is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var want := window_size_for(int(get_value("display/window_scale")))
		if DisplayServer.window_get_size() != want:
			DisplayServer.window_set_size(want)
			var screen := DisplayServer.window_get_current_screen()
			var area := DisplayServer.screen_get_usable_rect(screen)
			if area.size.x >= want.x and area.size.y >= want.y:
				DisplayServer.window_set_position(area.position + (area.size - want) / 2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED
		if bool(get_value("display/vsync")) else DisplayServer.VSYNC_DISABLED)


static func window_size_for(scale: int) -> Vector2i:
	return BASE_VIEWPORT * scale


func _autoload(autoload_name: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(autoload_name) if tree != null else null


## -- Focus pause --

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if bool(get_value("access/pause_on_focus_loss")) and is_inside_tree() \
				and not get_tree().paused and _in_gameplay():
			get_tree().paused = true
			_paused_by_focus = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _paused_by_focus and is_inside_tree():
			get_tree().paused = false
		_paused_by_focus = false


func _in_gameplay() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.get("zones") != null


## -- Last input device --

## Stick/trigger state per (device, axis): -1, 0 or +1 past STICK_EDGE.
var _axis_state := {}
## Matches the move_* actions' deadzone, so a push registers exactly when movement does.
const STICK_EDGE := 0.3


func _input(event: InputEvent) -> void:
	# A held stick sends a stream of motion events; event-driven menus would read every one of
	# them as another press. Only the events that cross into or out of a direction go through
	# (polling — Input.get_vector, is_action_pressed — is untouched, so walking is unaffected).
	if event is InputEventJoypadMotion:
		var id := "%d:%d" % [event.device, event.axis]
		var state := axis_state(event.axis_value, STICK_EDGE)
		if int(_axis_state.get(id, 0)) == state and is_inside_tree():
			get_viewport().set_input_as_handled()
		_axis_state[id] = state
	var pad := using_pad
	if event is InputEventJoypadButton and event.pressed:
		pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		pad = true
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		pad = false
	elif event is InputEventMouseMotion and event.relative.length() > 4.0:
		pad = false
	if pad != using_pad:
		using_pad = pad
		input_device_changed.emit(pad)


## The short name of what to press for `action` on the device in use ("Space" / "A").
func prompt(action: String) -> String:
	var kind := KIND_PAD if using_pad else KIND_KEY
	var name_text := binding_name(action, kind)
	if name_text == "" and kind == KIND_PAD:
		name_text = binding_name(action, KIND_KEY)
	return name_text


## The words for up/down list navigation on the device in use.
func nav_prompt() -> String:
	return "D-pad" if using_pad else "Up/Down"


func back_prompt() -> String:
	return "B" if using_pad else "Esc"


## -- Bindings --

func _capture_defaults() -> void:
	_default_events.clear()
	for action in REBINDABLE:
		_default_events[action] = project_default_events(action)


## project.godot's events for an action (never the live InputMap, which may hold overrides).
static func project_default_events(action: String) -> Array:
	var out: Array = []
	var setting = ProjectSettings.get_setting("input/" + action)
	if setting is Dictionary and (setting as Dictionary).has("events"):
		for event in setting["events"]:
			if event is InputEvent:
				out.append((event as InputEvent).duplicate())
	return out


func default_codes(action: String) -> PackedStringArray:
	return codes_for(_default_events.get(action, []))


func current_codes(action: String) -> PackedStringArray:
	if not InputMap.has_action(action):
		return PackedStringArray()
	return codes_for(InputMap.action_get_events(action))


static func codes_for(events: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for event in events:
		var code := encode_event(event)
		if code != "":
			out.append(code)
	return out


## Stored overrides: action -> its full event code list, for actions that differ from default.
func binding_overrides() -> Dictionary:
	var out := {}
	for action in REBINDABLE:
		var now := current_codes(action)
		if now != default_codes(action):
			out[action] = now
	return out


## Rebuilds every rebindable action from its defaults plus `overrides` (action -> codes).
func apply_bindings(overrides: Dictionary = {}) -> void:
	for action in REBINDABLE:
		if not InputMap.has_action(action):
			continue
		var codes: PackedStringArray = default_codes(action)
		if overrides.has(action):
			codes = PackedStringArray(overrides[action])
		_set_action_codes(action, codes)
	bindings_changed.emit()


func _set_action_codes(action: String, codes: PackedStringArray) -> void:
	InputMap.action_erase_events(action)
	for code in codes:
		var event := decode_event(code)
		if event != null:
			InputMap.action_add_event(action, event)


func reset_bindings() -> void:
	apply_bindings({})
	save_settings()


## The current code in an action's key or pad slot ("" when it has none).
func slot_code(action: String, kind: String) -> String:
	return slot_of(current_codes(action), kind)


func binding_name(action: String, kind: String) -> String:
	return display_name(slot_code(action, kind))


## Rebinds `action`'s `kind` slot to `event`. Returns {"ok": bool, "swapped_with": action or "",
## "message": text for the screen}. Swaps with whichever other action held that input.
func rebind(action: String, kind: String, event: InputEvent) -> Dictionary:
	var code := encode_event(event)
	if not REBINDABLE.has(action) or code == "" or kind_of(code) != kind:
		return {"ok": false, "swapped_with": "", "message": "That can't be bound here."}
	if RESERVED.has(code):
		return {"ok": false, "swapped_with": "", "message": "%s is kept for going back." % display_name(code)}
	var table := {}
	for a in REBINDABLE:
		table[a] = current_codes(a)
	var result := rebind_codes(table, action, kind, code)
	for a in result["table"]:
		if result["table"][a] != table[a]:
			_set_action_codes(a, result["table"][a])
	save_settings()
	bindings_changed.emit()
	var other := String(result["swapped_with"])
	var message := "%s: %s" % [String(ACTION_LABELS.get(action, action)), display_name(code)]
	if other != "":
		message = "Swapped with %s." % String(ACTION_LABELS.get(other, other))
	return {"ok": true, "swapped_with": other, "message": message}


## -- Pure binding rules (unit tested) --

## "k:<physical keycode>", "kc:<keycode>", "m:<mouse button>", "b:<joy button>",
## "a:<axis>:<+|->"; "" for anything else.
static func encode_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.physical_keycode != 0:
			return "k:%d" % int(key.physical_keycode)
		if key.keycode != 0:
			return "kc:%d" % int(key.keycode)
		return ""
	if event is InputEventMouseButton:
		return "m:%d" % int((event as InputEventMouseButton).button_index)
	if event is InputEventJoypadButton:
		return "b:%d" % int((event as InputEventJoypadButton).button_index)
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) < 0.01:
			return ""
		return "a:%d:%s" % [int(motion.axis), "+" if motion.axis_value > 0.0 else "-"]
	return ""


static func decode_event(code: String) -> InputEvent:
	var parts := code.split(":")
	if parts.size() < 2 or not parts[1].is_valid_int():
		return null
	var n := int(parts[1])
	match parts[0]:
		"k":
			var key := InputEventKey.new()
			key.physical_keycode = n as Key
			return key
		"kc":
			var keyc := InputEventKey.new()
			keyc.keycode = n as Key
			return keyc
		"m":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = n as MouseButton
			return mouse
		"b":
			var button := InputEventJoypadButton.new()
			button.button_index = n as JoyButton
			return button
		"a":
			if parts.size() < 3:
				return null
			var motion := InputEventJoypadMotion.new()
			motion.axis = n as JoyAxis
			motion.axis_value = 1.0 if parts[2] == "+" else -1.0
			return motion
	return null


## Which slot a code fills: KIND_KEY (keyboard), KIND_PAD (controller) or "" (mouse etc.).
static func kind_of(code: String) -> String:
	if code.begins_with("k:") or code.begins_with("kc:"):
		return KIND_KEY
	if code.begins_with("b:") or code.begins_with("a:"):
		return KIND_PAD
	return ""


static func slot_of(codes: PackedStringArray, kind: String) -> String:
	for code in codes:
		if kind_of(code) == kind:
			return code
	return ""


## The swap rule on a plain table (action -> PackedStringArray of codes). Puts `code` in
## `action`'s `kind` slot (in place, or appended when the slot is empty); any other action that
## already used `code` gets the slot's old code in its place (or loses it when there was none).
## Returns {"table": new table, "swapped_with": first other action touched, or ""}.
static func rebind_codes(table: Dictionary, action: String, kind: String, code: String) -> Dictionary:
	var out := {}
	for a in table:
		out[a] = PackedStringArray(table[a])
	var mine: PackedStringArray = out.get(action, PackedStringArray())
	var old := slot_of(mine, kind)
	var swapped := ""
	if old == code:
		return {"table": out, "swapped_with": ""}
	for a in out:
		if a == action:
			continue
		var theirs: PackedStringArray = out[a]
		var at := theirs.find(code)
		if at == -1:
			continue
		if swapped == "":
			swapped = String(a)
		if old != "" and not theirs.has(old):
			theirs[at] = old
		else:
			theirs.remove_at(at)
		out[a] = theirs
	# The action's own extra copy of the code (e.g. W -> Up when Up is already an extra) goes.
	var dup := mine.find(code)
	if dup != -1:
		mine.remove_at(dup)
	var slot_at := -1
	for i in mine.size():
		if kind_of(mine[i]) == kind:
			slot_at = i
			break
	if slot_at == -1:
		mine.append(code)
	else:
		mine[slot_at] = code
	out[action] = mine
	return {"table": out, "swapped_with": swapped}


## Font-safe display name for a code ("Space", "Equals", "A", "LT", "Left click").
static func display_name(code: String) -> String:
	if code == "":
		return ""
	var parts := code.split(":")
	var n := int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else 0
	var text := ""
	match parts[0]:
		"k", "kc":
			text = key_word(n)
		"m":
			text = {MOUSE_BUTTON_LEFT: "Left click", MOUSE_BUTTON_RIGHT: "Right click",
				MOUSE_BUTTON_MIDDLE: "Middle click"}.get(n, "Mouse %d" % n)
		"b":
			text = String(PAD_BUTTON_NAMES.get(n, "Button %d" % n))
		"a":
			text = String(PAD_AXIS_NAMES.get(code, "Axis %d" % n))
	return font_safe(text)


static func key_word(keycode: int) -> String:
	if KEY_WORDS.has(keycode):
		return String(KEY_WORDS[keycode])
	var text := OS.get_keycode_string(keycode)
	if text.begins_with("Kp "):
		text = "Num " + text.substr(3)
	return text


## Replaces any glyph the UI font lacks with nothing (a last line of defence; names above are
## already written in plain words).
static func font_safe(text: String) -> String:
	var out := ""
	for i in text.length():
		if FONT_CHARS.contains(text[i]):
			out += text[i]
	return out if out.strip_edges() != "" else "Key"


static func axis_state(value: float, edge: float) -> int:
	if value >= edge:
		return 1
	if value <= -edge:
		return -1
	return 0


## True when a pressed event may be captured for a `kind` rebind.
static func capturable(event: InputEvent, kind: String) -> bool:
	if event == null or event.is_echo():
		return false
	if kind == KIND_KEY:
		return event is InputEventKey and event.pressed
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) >= AXIS_CAPTURE_THRESHOLD
	return false


## The press used to cancel a pending rebind (Escape or the pad's B).
static func is_cancel_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.is_echo():
		return event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_B
	return false


## True while any non-mouse input bound to `action` is physically held (player.gd: a left click
## over the HUD belongs to the HUD, but Space/A held at the same time still counts).
static func held_without_mouse(action: String) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			if (key.physical_keycode != 0 and Input.is_physical_key_pressed(key.physical_keycode)) \
					or (key.keycode != 0 and Input.is_key_pressed(key.keycode)):
				return true
		elif event is InputEventJoypadButton:
			for device in Input.get_connected_joypads():
				if Input.is_joy_button_pressed(device, (event as InputEventJoypadButton).button_index):
					return true
	return false
