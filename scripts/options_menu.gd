extends Control
## The options screen (Milestone E part 2, 2026-11-12): one reusable Control that the title
## screen (its Options entry) and the in-game menu (its OPTIONS tab) both host, so there is only
## one options UI. It's a view over the Settings autoload (scripts/settings.gd): every change is
## applied and saved the moment it's made.
##
## Two pages, picked on the top row (Left/Right or Space/A there):
##   SETTINGS — sound volumes, display, accessibility, and "restore default settings".
##   CONTROLS — every rebindable action with its keyboard key and controller button. Left/Right
##              picks the column, Space/A starts a rebind ("press a key..."), the next key (or
##              controller button / trigger) is bound, Esc or B cancels. Binding something
##              another action uses swaps the two, and the status line says so. The last row
##              resets every binding to project.godot's defaults.
##
## Keyboard, mouse-free and controller-complete: navigation reads the gameplay actions (move_*,
## use_tool, interact) and Godot's ui_* actions alike, so it follows the player's own bindings and
## still works on the d-pad and stick. The host routes input in through handle_input(event)
## (returns true when consumed); while a rebind is pending the host must pass EVERYTHING here
## (see `capturing`). ui_cancel isn't consumed, so the host decides what "back" means.
##
## Built in code (no .tscn): size it with anchors/offsets and it lays its rows out to fit,
## scrolling when they don't.

const PAGE_SETTINGS := 0
const PAGE_CONTROLS := 1
const PAGE_NAMES: Array[String] = ["SETTINGS", "CONTROLS"]

## The in-game menu's palette (scripts/menu_screen.gd).
const TEXT_COLOR := Color("#281a0b")
const ACCENT_COLOR := Color("#c5520f")
const WOOD_COLOR := Color("#7b5025")
const DIM_COLOR := Color("#8a7a63")
const CAPTION_COLOR := Color("#9d9180")
const GOOD_COLOR := Color("#3f6b2a")
const WARN_COLOR := Color("#d13b27")
const HIGHLIGHT_COLOR := Color("#e8d29a")
const TRACK_COLOR := Color("#c8b896")

const ROW_H := 10.0
const TOP_H := 12.0
const STATUS_H := 10.0
const VOLUME_STEP := 0.1

## Settings page rows (captions aren't selectable).
const SETTINGS_ROWS := [
	{"type": "caption", "text": "SOUND"},
	{"type": "slider", "key": "audio/master", "label": "Master volume"},
	{"type": "slider", "key": "audio/music", "label": "Music"},
	{"type": "slider", "key": "audio/sfx", "label": "Sound effects"},
	{"type": "slider", "key": "audio/ambience", "label": "Ambience"},
	{"type": "caption", "text": "DISPLAY"},
	{"type": "toggle", "key": "display/fullscreen", "label": "Fullscreen"},
	{"type": "choice", "key": "display/window_scale", "label": "Window size"},
	{"type": "toggle", "key": "display/vsync", "label": "VSync"},
	{"type": "caption", "text": "ACCESSIBILITY"},
	{"type": "toggle", "key": "access/screen_shake", "label": "Screen shake"},
	{"type": "toggle", "key": "access/reduce_flashes", "label": "Reduce flashes"},
	{"type": "choice", "key": "access/text_speed", "label": "Text speed"},
	{"type": "choice", "key": "access/use_mode", "label": "Use button"},
	{"type": "toggle", "key": "access/pause_on_focus_loss", "label": "Pause when unfocused"},
	{"type": "button", "id": "reset_settings", "label": "Restore default settings"},
]
const CHOICES := {
	"display/window_scale": [2, 3, 4, 5],
	"access/text_speed": ["slow", "normal", "fast", "instant"],
	"access/use_mode": ["hold", "toggle"],
}
const CHOICE_LABELS := {
	"access/text_speed": {"slow": "Slow", "normal": "Normal", "fast": "Fast", "instant": "Instant"},
	"access/use_mode": {"hold": "Hold to repeat", "toggle": "Tap to start/stop"},
}

## The Settings autoload (overridable for tests).
var settings: Node = null
var page := PAGE_SETTINGS
## 0 = the page row; 1.. = rows of the current page (captions skipped).
var selected := 0
## Controls page: 0 = keyboard column, 1 = controller column.
var column := 0
## True while waiting for the key/button to bind; the host must route every event here.
var capturing := false
var status := ""
var _status_color := GOOD_COLOR
var _capture_action := ""
var _capture_kind := ""
var _scroll := 0
## Edge filter for stick-driven navigation (one move per push, not one per motion event).
var _axis_held := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if settings == null:
		settings = get_node_or_null("/root/Settings")
	if settings != null:
		if not settings.input_device_changed.is_connected(_on_device_changed):
			settings.input_device_changed.connect(_on_device_changed)
	resized.connect(refresh)
	refresh()


## Back to the top of the first page (hosts call this each time the screen opens).
func reset_view() -> void:
	page = PAGE_SETTINGS
	selected = 0
	column = 0
	_scroll = 0
	capturing = false
	status = ""
	refresh()


func _on_device_changed(_pad: bool) -> void:
	if is_visible_in_tree():
		refresh()


## -- Rows --

func rows() -> Array:
	if page == PAGE_SETTINGS:
		return SETTINGS_ROWS
	var out: Array = []
	for action in settings.REBINDABLE:
		out.append({"type": "binding", "action": action, "label": settings.ACTION_LABELS.get(action, action)})
	out.append({"type": "button", "id": "reset_bindings", "label": "Reset controls to defaults"})
	return out


## Selectable rows of the current page, in order (index i is selection i + 1).
func selectable_rows() -> Array:
	var out: Array = []
	for row in rows():
		if String(row["type"]) != "caption":
			out.append(row)
	return out


## The selected row's dict ({"type": "pages"} for the page row).
func selected_row() -> Dictionary:
	if selected == 0:
		return {"type": "pages"}
	var sel := selectable_rows()
	return sel[selected - 1] if selected - 1 < sel.size() else {}


## Selects the row for a settings key or action (smoke/test helper); false if not on this page.
func select(key_or_action: String) -> bool:
	var sel := selectable_rows()
	for i in sel.size():
		if String(sel[i].get("key", sel[i].get("action", sel[i].get("id", "")))) == key_or_action:
			selected = i + 1
			refresh()
			return true
	return false


func set_page(index: int) -> void:
	page = posmod(index, PAGE_NAMES.size())
	selected = 0
	column = 0
	_scroll = 0
	status = ""
	refresh()


## -- Input --

func handle_input(event: InputEvent) -> bool:
	if capturing:
		_capture_input(event)
		return true
	if _nav(event, ["move_up", "ui_up"]):
		_move(-1)
	elif _nav(event, ["move_down", "ui_down"]):
		_move(1)
	elif _nav(event, ["move_left", "ui_left"]):
		change(-1)
	elif _nav(event, ["move_right", "ui_right"]):
		change(1)
	elif _nav(event, ["use_tool", "interact", "ui_accept"]):
		activate()
	else:
		return false
	return true


## Pressed (not echo) on any of `actions`; for stick motion only on the push, not every event.
func _nav(event: InputEvent, actions: Array) -> bool:
	for action in actions:
		if not InputMap.has_action(action):
			continue
		if event is InputEventJoypadMotion:
			if event.is_action_pressed(action):
				if _axis_held.get(action, false):
					return false
				_axis_held[action] = true
				return true
			if event.is_action_released(action) or event.is_action(action):
				_axis_held[action] = false
			continue
		if event.is_action_pressed(action):
			return true
	return false


func _move(step: int) -> void:
	var count := selectable_rows().size() + 1
	selected = wrapi(selected + step, 0, count)
	status = ""
	_play("ui_hover", -10.0)
	refresh()


## Left/Right on the selected row: page switch, value change, or controls column.
func change(step: int) -> void:
	var row := selected_row()
	match String(row.get("type", "")):
		"pages":
			set_page(page + step)
			_play("ui_tab", -8.0)
			return
		"slider":
			var key := String(row["key"])
			settings.set_value(key, clampf(float(settings.get_value(key)) + VOLUME_STEP * step, 0.0, 1.0))
			_play("ui_hover", -4.0)
		"toggle":
			settings.set_value(String(row["key"]), not bool(settings.get_value(String(row["key"]))))
			_play("ui_tab", -8.0)
		"choice":
			var key2 := String(row["key"])
			var options: Array = CHOICES[key2]
			var at := options.find(settings.get_value(key2))
			settings.set_value(key2, options[posmod(at + step, options.size())])
			_play("ui_tab", -8.0)
		"binding":
			column = posmod(column + step, 2)
			_play("ui_hover", -10.0)
	status = ""
	refresh()


## Space/A on the selected row.
func activate() -> void:
	var row := selected_row()
	match String(row.get("type", "")):
		"pages":
			change(1)
		"toggle", "choice":
			change(1)
		"slider":
			pass
		"binding":
			start_capture(String(row["action"]), settings.KIND_PAD if column == 1 else settings.KIND_KEY)
		"button":
			if String(row["id"]) == "reset_bindings":
				settings.reset_bindings()
				_set_status("Controls reset to defaults.", GOOD_COLOR)
			else:
				settings.reset_settings()
				_set_status("Settings restored to defaults.", GOOD_COLOR)
			_play("ui_confirm", -6.0)
			refresh()


func start_capture(action: String, kind: String) -> void:
	capturing = true
	_capture_action = action
	_capture_kind = kind
	_set_status(("Press a key for %s.  Esc cancels." if kind == settings.KIND_KEY
		else "Press a controller button for %s.  B cancels.") \
		% String(settings.ACTION_LABELS.get(action, action)), ACCENT_COLOR)
	refresh()


func cancel_capture() -> void:
	capturing = false
	_set_status("Cancelled.", DIM_COLOR)
	refresh()


func _capture_input(event: InputEvent) -> void:
	if settings.is_cancel_event(event):
		cancel_capture()
		return
	if not settings.capturable(event, _capture_kind):
		if (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed() \
				and not event.is_echo():
			_set_status("That's a %s. Press a %s, or %s to cancel." % [
				"key" if event is InputEventKey else "controller button",
				"key" if _capture_kind == settings.KIND_KEY else "controller button",
				"Esc" if _capture_kind == settings.KIND_KEY else "B"], WARN_COLOR)
			refresh()
		return
	var result: Dictionary = settings.rebind(_capture_action, _capture_kind, event)
	capturing = false
	_set_status(String(result["message"]), GOOD_COLOR if bool(result["ok"]) else WARN_COLOR)
	_play("ui_confirm" if bool(result["ok"]) else "ui_error", -6.0)
	refresh()


func _set_status(text: String, color: Color) -> void:
	status = text
	_status_color = color


func _play(sound: String, db: float) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.play_sfx(sound, db)


## -- Drawing --

func refresh() -> void:
	if not is_inside_tree() or settings == null:
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var w := size.x
	_draw_pages(w)
	var y := TOP_H
	if page == PAGE_CONTROLS:
		_text("KEYBOARD", Vector2(_key_x(w), y), _col_w(w), CAPTION_COLOR)
		_text("CONTROLLER", Vector2(_pad_x(w), y), _col_w(w), CAPTION_COLOR)
		y += ROW_H
	var all := rows()
	var visible_rows := maxi(int((size.y - y - STATUS_H - 2.0) / ROW_H), 1)
	var sel_index := _selected_row_index(all)
	if selected == 0:
		_scroll = 0
	elif sel_index < _scroll:
		_scroll = sel_index
	elif sel_index >= _scroll + visible_rows:
		_scroll = sel_index - visible_rows + 1
	_scroll = clampi(_scroll, 0, maxi(all.size() - visible_rows, 0))
	# Pull a caption into view with the first row under it.
	if _scroll > 0 and String(all[_scroll - 1]["type"]) == "caption" and sel_index < _scroll + visible_rows - 1:
		_scroll -= 1
	for i in range(_scroll, mini(all.size(), _scroll + visible_rows)):
		_draw_row(all[i], i == sel_index and selected > 0, Vector2(0, y), w)
		y += ROW_H
	if _scroll > 0:
		_text("↑", Vector2(w - 8, TOP_H + (ROW_H if page == PAGE_CONTROLS else 0.0)), 8, DIM_COLOR)
	if _scroll + visible_rows < all.size():
		_text("↓", Vector2(w - 8, y - ROW_H), 8, DIM_COLOR)
	var line := status if status != "" else _hint()
	_text(line, Vector2(0, size.y - STATUS_H), w, _status_color if status != "" else DIM_COLOR,
		HORIZONTAL_ALIGNMENT_CENTER)


## Index into `all` of the selected row (0 for the page row).
func _selected_row_index(all: Array) -> int:
	if selected == 0:
		return 0
	var n := 0
	for i in all.size():
		if String(all[i]["type"]) != "caption":
			n += 1
			if n == selected:
				return i
	return 0


func _hint() -> String:
	var pick := String(settings.prompt("use_tool"))
	match String(selected_row().get("type", "")):
		"pages":
			return "←→ page"
		"slider":
			return "←→ adjust"
		"toggle", "choice":
			return "←→ change"
		"binding":
			return "←→ column   %s rebind" % pick
		"button":
			return "%s confirm" % pick
	return ""


func _draw_pages(w: float) -> void:
	var x := 4.0
	for i in PAGE_NAMES.size():
		var on_page := i == page
		var name_text := PAGE_NAMES[i]
		var width := name_text.length() * 5.0 + 8.0
		if on_page and selected == 0:
			_box(Rect2(x - 3, 0, width, ROW_H), HIGHLIGHT_COLOR)
		_text(name_text, Vector2(x, 0), width, ACCENT_COLOR if on_page else WOOD_COLOR)
		x += width + 6.0
	_box(Rect2(0, TOP_H - 2, w, 1), TRACK_COLOR)


func _draw_row(row: Dictionary, is_selected: bool, at: Vector2, w: float) -> void:
	var kind := String(row["type"])
	if kind == "caption":
		_text(String(row["text"]), at + Vector2(2, 0), w, CAPTION_COLOR)
		return
	if is_selected and kind != "binding":
		_box(Rect2(at.x, at.y, w, ROW_H), HIGHLIGHT_COLOR)
	var label_color := ACCENT_COLOR if is_selected else TEXT_COLOR
	var vx := floorf(w * 0.52)
	var vw := w - vx - 10.0
	match kind:
		"slider":
			_text(String(row["label"]), at + Vector2(8, 0), vx - 8, label_color)
			var v := float(settings.get_value(String(row["key"])))
			var track := Rect2(at.x + vx, at.y + 3, 60, 4)
			_box(track, TRACK_COLOR)
			_box(Rect2(track.position, Vector2(roundf(60.0 * v), 4)), ACCENT_COLOR if is_selected else WOOD_COLOR)
			_text("%d%%" % int(round(v * 100.0)), at + Vector2(vx + 66, 0), 30, label_color)
		"toggle", "choice":
			_text(String(row["label"]), at + Vector2(8, 0), vx - 8, label_color)
			var value_text := _value_text(String(row["key"]))
			var dim := String(row["key"]) == "display/window_scale" and bool(settings.get_value("display/fullscreen"))
			if is_selected:
				value_text = "← %s →" % value_text
			_text(value_text, at + Vector2(vx, 0), vw, DIM_COLOR if dim else label_color)
		"button":
			_text(String(row["label"]), at + Vector2(8, 0), w - 8, label_color)
		"binding":
			var action := String(row["action"])
			if is_selected:
				_box(Rect2(at.x, at.y, w, ROW_H), Color(HIGHLIGHT_COLOR, 0.45))
				var cx := _key_x(w) if column == 0 else _pad_x(w)
				_box(Rect2(at.x + cx - 3, at.y, _col_w(w), ROW_H), HIGHLIGHT_COLOR)
			_text(String(row["label"]), at + Vector2(8, 0), _key_x(w) - 12, label_color)
			for c in 2:
				var kind_name: String = settings.KIND_KEY if c == 0 else settings.KIND_PAD
				var text := String(settings.binding_name(action, kind_name))
				var color := TEXT_COLOR
				if text == "":
					text = "—"
					color = DIM_COLOR
				if capturing and is_selected and c == column:
					text = "press..."
					color = ACCENT_COLOR
				elif is_selected and c == column:
					color = ACCENT_COLOR
				_text(text, at + Vector2(_key_x(w) if c == 0 else _pad_x(w), 0), _col_w(w) - 4, color)


func _value_text(key: String) -> String:
	var v = settings.get_value(key)
	if CHOICE_LABELS.has(key):
		return String(CHOICE_LABELS[key].get(v, str(v)))
	if key == "display/window_scale":
		var px: Vector2i = settings.window_size_for(int(v))
		return "x%d  %d x %d" % [int(v), px.x, px.y]
	return "On" if bool(v) else "Off"


func _key_x(w: float) -> float:
	return floorf(w * 0.44)


func _pad_x(w: float) -> float:
	return floorf(w * 0.72)


func _col_w(w: float) -> float:
	return floorf(w * 0.28)


func _text(text: String, at: Vector2, width: float, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = align
	label.position = at
	add_child(label)
	label.size = Vector2(width, ROW_H)
	return label


func _box(rect: Rect2, color: Color) -> void:
	var box := ColorRect.new()
	box.color = color
	box.position = rect.position
	box.size = rect.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)


## The visible text of every Label (smoke/screenshot checks).
func visible_texts() -> Array[String]:
	var out: Array[String] = []
	for child in get_children():
		if child is Label and not child.is_queued_for_deletion():
			out.append(String(child.text))
	return out
