extends Control
## Character creation at the birth moment (Milestone E, GDD.md §3): the parents name their
## child, and the player picks pronouns and a look — a base preset plus hair colour, skin tone
## and outfit colour, previewed live on the walking player sprite (a palette swap of the real
## frames, scripts/player_look.gd). Hosted by scripts/opening.gd, which forwards input here
## while it shows this screen and listens for `finished`.
##
## Built entirely in code (one screen, no reuse elsewhere), 320x192:
##   - header: Doc Ama asking what the baby is called (pronoun-aware, updates live)
##   - left: the rows NAME / PRONOUNS / LOOK / HAIR / SKIN / OUTFIT / BEGIN
##   - right: the preview, the player walking and turning on a cream panel
##   - name editor: an overlay with the typed name and an on-screen letter grid
##
## Every action works with the existing input actions only, so a controller drives it all:
##   rows:   move_up/move_down choose a row; move_left/move_right change its option; use_tool
##           opens the name editor on NAME, steps forward on an option row, finishes on BEGIN.
##   editor: move_* walk the letter grid, use_tool presses the highlighted cell (letters, CAPS,
##           SPACE, DEL, DONE); ui_cancel closes it. A physical keyboard can simply TYPE —
##           printable keys go straight into the name (so W/A/S/D type letters there rather than
##           moving the cursor), Backspace deletes and Enter closes. Everything typed or picked
##           goes through PlayerProfile.filter_name(), so only drawable glyphs ever get in.
## The rules (filtering, grid layout and navigation, option cycling) are static functions in
## scripts/player_profile.gd and unit-tested there; this file is the view.

signal finished(player_name: String, pronouns: String, appearance: Dictionary)

const PlayerProfile := preload("res://scripts/player_profile.gd")
const PlayerLook := preload("res://scripts/player_look.gd")
const BASE_FRAMES := preload("res://art/characters/player/player_frames.tres")

const ROW_NAME := 0
const ROW_PRONOUNS := 1
const ROW_LOOK := 2
const ROW_HAIR := 3
const ROW_SKIN := 4
const ROW_OUTFIT := 5
const ROW_BEGIN := 6
const ROW_LABELS: Array[String] = ["NAME", "PRONOUNS", "LOOK", "HAIR", "SKIN", "OUTFIT", "BEGIN"]
## Look field each option row edits (NAME/PRONOUNS/BEGIN are handled separately).
const ROW_FIELDS := {ROW_LOOK: "preset", ROW_HAIR: "hair", ROW_SKIN: "skin", ROW_OUTFIT: "outfit"}

const TEXT_COLOR := Color("#ffedb1")       # worn cream
const LABEL_COLOR := Color("#9d9180")      # scavenged metal
const SELECTED_COLOR := Color("#ffc948")   # lamplight gold
const MARK_COLOR := Color("#c5520f")       # rust — the established highlight
const DIM_COLOR := Color("#7b5025")        # worn wood
const PANEL_BG := Color("#ffedb1")
const PANEL_EDGE := Color("#7b5025")
const PANEL_TEXT := Color("#281a0b")
const BG_COLOR := Color("#281a0b")

const ROWS_X := 12.0
const ROWS_Y := 34.0
const ROW_H := 16.0
const VALUE_X := 70.0
const PREVIEW_RECT := Rect2(206, 30, 102, 112)
const PREVIEW_SCALE := 3.0
const TURN_SECONDS := 1.6
const FACING_CYCLE: Array[String] = ["south", "east", "north", "west"]

const EDITOR_RECT := Rect2(8, 30, 190, 120)
const CELL := Vector2(17, 13)
const GRID_ORIGIN := Vector2(10, 34)   # inside the editor panel
const COMMAND_W := 42.0

var row_index := ROW_NAME
var player_name := ""
var pronouns: String = PlayerProfile.DEFAULT_PRONOUNS
var appearance: Dictionary = PlayerProfile.default_appearance()
var editing_name := false
var grid_cursor := Vector2i.ZERO
## null = auto caps (PlayerProfile.auto_caps), else the player's CAPS toggle.
var caps_override = null
## The suggestion shown greyed in an empty name field; used if the player confirms no name.
var placeholder_name := ""

var _header: Label
var _row_labels: Array[Label] = []
var _row_values: Array[Label] = []
var _marker: Label
var _hint: Label
var _preview: AnimatedSprite2D
var _preview_caption: Label
var _editor: Control
var _editor_name: Label
var _editor_cells: Array = []    # rows of Labels, matching PlayerProfile.grid_rows()
var _editor_cell_bgs: Array = []
var _editor_hint: Label
var _turn_elapsed := 0.0
var _facing_index := 0
var _blink := 0.0
var _done := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder_name = PlayerProfile.suggested_name(int(Time.get_ticks_usec()))
	_build()
	_refresh()


## Pre-fills from an earlier visit (or from tests); safe before or after _ready.
func setup(initial_name: String, initial_pronouns: String, initial_look: Dictionary) -> void:
	player_name = PlayerProfile.filter_name(initial_name)
	pronouns = PlayerProfile.normalize_pronouns(initial_pronouns)
	appearance = PlayerProfile.normalize_appearance(initial_look)
	if is_inside_tree() and _header != null:
		_refresh()


func _process(delta: float) -> void:
	_turn_elapsed += delta
	if _turn_elapsed >= TURN_SECONDS:
		_turn_elapsed = 0.0
		_facing_index = (_facing_index + 1) % FACING_CYCLE.size()
		_play_preview()
	if editing_name:
		_blink += delta
		_refresh_editor_name()


## -- Input (opening.gd forwards every event here while this screen is up) --

func handle_input(event: InputEvent) -> void:
	if _done:
		return
	if editing_name:
		_editor_input(event)
	else:
		_rows_input(event)


func _rows_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		row_index = posmod(row_index - 1, ROW_LABELS.size())
	elif event.is_action_pressed("move_down"):
		row_index = posmod(row_index + 1, ROW_LABELS.size())
	elif event.is_action_pressed("move_left"):
		_change(-1)
	elif event.is_action_pressed("move_right"):
		_change(1)
	elif event.is_action_pressed("use_tool") or _is_enter(event):
		match row_index:
			ROW_NAME:
				open_name_editor()
				return
			ROW_BEGIN:
				confirm()
				return
			_:
				_change(1)
	else:
		return
	_refresh()


func _change(delta: int) -> void:
	match row_index:
		ROW_PRONOUNS:
			var i := PlayerProfile.PRONOUNS.find(pronouns)
			pronouns = PlayerProfile.PRONOUNS[posmod(i + delta, PlayerProfile.PRONOUNS.size())]
		ROW_LOOK, ROW_HAIR, ROW_SKIN, ROW_OUTFIT:
			appearance = PlayerProfile.cycle(appearance, String(ROW_FIELDS[row_index]), delta)
			_apply_preview_look()


func _editor_input(event: InputEvent) -> void:
	# A physical keyboard types: printable keys go into the name before any action mapping
	# sees them (so W/A/S/D/C/E/Q/Space are letters here, not moves or presses).
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if key.keycode == KEY_BACKSPACE or key.physical_keycode == KEY_BACKSPACE:
			type_backspace()
			return
		if _is_enter(event):
			close_name_editor()
			return
		if key.unicode >= 32 and not key.ctrl_pressed and not key.meta_pressed:
			if not key.echo or key.unicode != 32:
				type_text(char(key.unicode))
			return
	if event.is_action_pressed("ui_cancel"):
		close_name_editor()
		return
	var rows := PlayerProfile.grid_rows(_caps_on())
	var delta := Vector2i.ZERO
	if event.is_action_pressed("move_up"):
		delta = Vector2i(0, -1)
	elif event.is_action_pressed("move_down"):
		delta = Vector2i(0, 1)
	elif event.is_action_pressed("move_left"):
		delta = Vector2i(-1, 0)
	elif event.is_action_pressed("move_right"):
		delta = Vector2i(1, 0)
	elif event.is_action_pressed("use_tool"):
		press_grid_cell()
		return
	if delta != Vector2i.ZERO:
		grid_cursor = PlayerProfile.grid_move(grid_cursor, delta, rows)
		_refresh_editor()


func _is_enter(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	var k := (event as InputEventKey).keycode
	return k == KEY_ENTER or k == KEY_KP_ENTER


## -- Name editing (public so tools/opening_smoke.gd and tests can drive it precisely) --

func open_name_editor() -> void:
	editing_name = true
	grid_cursor = Vector2i.ZERO
	caps_override = null
	_blink = 0.0
	_refresh()


func close_name_editor() -> void:
	editing_name = false
	player_name = PlayerProfile.filter_name(player_name).strip_edges(false, true)
	# Back on the rows, step down to the next choice — the natural flow is top to bottom.
	row_index = ROW_PRONOUNS
	_refresh()


func type_text(text: String) -> void:
	player_name = PlayerProfile.append_to_name(player_name, text)
	caps_override = null
	_refresh_editor()


func type_backspace() -> void:
	player_name = PlayerProfile.delete_last(player_name)
	caps_override = null
	_refresh_editor()


func press_grid_cell() -> void:
	var rows := PlayerProfile.grid_rows(_caps_on())
	var cell := String((rows[grid_cursor.y] as Array)[grid_cursor.x])
	var result := PlayerProfile.grid_press(player_name, cell, caps_override)
	player_name = String(result["name"])
	caps_override = result["caps_override"]
	if bool(result["done"]):
		close_name_editor()
		return
	_refresh_editor()


## Moves the grid cursor onto a character's cell (tools/opening_smoke.gd uses this to plan its
## move_* presses). Returns the cell, or (-1,-1) if the character isn't on the grid.
func grid_cell_of(ch: String) -> Vector2i:
	var rows := PlayerProfile.grid_rows(_caps_on())
	for y in rows.size():
		var row: Array = rows[y]
		for x in row.size():
			if String(row[x]) == ch:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _caps_on() -> bool:
	return PlayerProfile.auto_caps(player_name) if caps_override == null else bool(caps_override)


## BEGIN: an empty name takes the placeholder suggestion (the parents always pick something).
func confirm() -> void:
	if _done:
		return
	var final_name := PlayerProfile.finalize_name(player_name)
	if final_name == "":
		final_name = placeholder_name
	player_name = final_name
	_done = true
	finished.emit(final_name, pronouns, appearance.duplicate())


## -- View --

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_header = _label("", Vector2(8, 6), Vector2(304, 20), TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in ROW_LABELS.size():
		var y := ROWS_Y + i * ROW_H + (6.0 if i == ROW_BEGIN else 0.0)
		_row_labels.append(_label(ROW_LABELS[i], Vector2(ROWS_X + 8, y), Vector2(60, 10), LABEL_COLOR))
		_row_values.append(_label("", Vector2(VALUE_X, y), Vector2(130, 10), TEXT_COLOR))
	_marker = _label("→", Vector2(ROWS_X, ROWS_Y), Vector2(8, 10), MARK_COLOR)
	# Preview: the clinic's lamplit plank room (the birth happens here), the player walking in it.
	_rect(PREVIEW_RECT.position - Vector2(2, 2), PREVIEW_RECT.size + Vector2(4, 4), PANEL_EDGE)
	_rect(PREVIEW_RECT.position - Vector2(1, 1), PREVIEW_RECT.size + Vector2(2, 2), Color("#b77c3e"))
	var floor_h := 30.0
	var wall_h := PREVIEW_RECT.size.y - floor_h
	_rect(PREVIEW_RECT.position, Vector2(PREVIEW_RECT.size.x, wall_h), Color("#5c3a1b"))
	for y in range(6, int(wall_h), 7):  # wall planks
		_rect(PREVIEW_RECT.position + Vector2(0, y), Vector2(PREVIEW_RECT.size.x, 1), Color("#4a2e15"))
	for i in 5:  # plank seams, staggered
		var sx := 9.0 + float((i * 37) % int(PREVIEW_RECT.size.x - 10))
		_rect(PREVIEW_RECT.position + Vector2(sx, 7 * i + 1), Vector2(1, 5), Color("#4a2e15"))
	# lamplight pooled on the wall behind the figure (two stepped bands, no airbrush)
	_rect(PREVIEW_RECT.position + Vector2(24, 10), Vector2(PREVIEW_RECT.size.x - 48, wall_h - 10), Color("#7b5025", 0.55))
	_rect(PREVIEW_RECT.position + Vector2(36, 18), Vector2(PREVIEW_RECT.size.x - 72, wall_h - 18), Color("#9a6631", 0.45))
	var floor_y := PREVIEW_RECT.position.y + wall_h
	_rect(Vector2(PREVIEW_RECT.position.x, floor_y), Vector2(PREVIEW_RECT.size.x, floor_h), Color("#9a6631"))
	_rect(Vector2(PREVIEW_RECT.position.x, floor_y), Vector2(PREVIEW_RECT.size.x, 2), Color("#3d2612"))
	for y in [8.0, 17.0, 26.0]:  # floorboards
		_rect(Vector2(PREVIEW_RECT.position.x, floor_y + y), Vector2(PREVIEW_RECT.size.x, 1), Color("#7b5025"))
	var shadow := ColorRect.new()
	shadow.color = Color("#281a0b", 0.35)
	shadow.size = Vector2(30, 3)
	shadow.position = PREVIEW_RECT.position + Vector2(PREVIEW_RECT.size.x / 2.0 - 15, PREVIEW_RECT.size.y - 22)
	add_child(shadow)
	_preview = AnimatedSprite2D.new()
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	# The sprite's feet sit on frame row 20 of 24; put them on the shadow.
	_preview.position = PREVIEW_RECT.position + Vector2(PREVIEW_RECT.size.x / 2.0,
		PREVIEW_RECT.size.y - 22 - (20.0 - 12.0) * PREVIEW_SCALE)
	_preview.sprite_frames = BASE_FRAMES
	add_child(_preview)
	_preview_caption = _label("", PREVIEW_RECT.position + Vector2(0, PREVIEW_RECT.size.y + 4),
		Vector2(PREVIEW_RECT.size.x, 10), LABEL_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_hint = _label("", Vector2(0, 181), Vector2(320, 10), LABEL_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_build_editor()
	_apply_preview_look()


func _build_editor() -> void:
	_editor = Control.new()
	_editor.position = EDITOR_RECT.position
	_editor.size = EDITOR_RECT.size
	_editor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_editor)
	var edge := ColorRect.new()
	edge.color = PANEL_EDGE
	edge.position = Vector2(-1, -1)
	edge.size = EDITOR_RECT.size + Vector2(2, 2)
	_editor.add_child(edge)
	var panel := ColorRect.new()
	panel.color = PANEL_BG
	panel.size = EDITOR_RECT.size
	_editor.add_child(panel)
	var title := _label("WHAT WILL THEY CALL YOU?", Vector2(0, 4), Vector2(EDITOR_RECT.size.x, 10),
		DIM_COLOR, HORIZONTAL_ALIGNMENT_CENTER, _editor)
	title.name = "EditorTitle"
	var field := ColorRect.new()
	field.color = Color("#f6dfa0")
	field.position = Vector2(30, 16)
	field.size = Vector2(EDITOR_RECT.size.x - 60, 13)
	_editor.add_child(field)
	var field_line := ColorRect.new()
	field_line.color = PANEL_EDGE
	field_line.position = field.position + Vector2(0, 12)
	field_line.size = Vector2(field.size.x, 1)
	_editor.add_child(field_line)
	_editor_name = _label("", Vector2(30, 17), Vector2(field.size.x, 10), PANEL_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER, _editor)
	var rows := PlayerProfile.grid_rows(true)
	for y in rows.size():
		var labels: Array[Label] = []
		var bgs: Array[ColorRect] = []
		var row: Array = rows[y]
		var command_row := y == rows.size() - 1
		for x in row.size():
			var pos := GRID_ORIGIN + Vector2(x * CELL.x, y * CELL.y + (4.0 if command_row else 0.0))
			var w := COMMAND_W if command_row else CELL.x
			if command_row:
				pos.x = GRID_ORIGIN.x + x * (COMMAND_W + 1.0)
			var cell_bg := ColorRect.new()
			cell_bg.position = pos
			cell_bg.size = Vector2(w - 1, CELL.y - 1)
			cell_bg.color = Color(0, 0, 0, 0)
			_editor.add_child(cell_bg)
			bgs.append(cell_bg)
			labels.append(_label("", pos + Vector2(0, 1), Vector2(w - 1, 10), PANEL_TEXT,
				HORIZONTAL_ALIGNMENT_CENTER, _editor))
		_editor_cells.append(labels)
		_editor_cell_bgs.append(bgs)
	_editor_hint = _label("Type, or pick letters", Vector2(0, EDITOR_RECT.size.y - 12),
		Vector2(EDITOR_RECT.size.x, 10), DIM_COLOR, HORIZONTAL_ALIGNMENT_CENTER, _editor)


func _rect(pos: Vector2, size_: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size_
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _label(text: String, pos: Vector2, size_: Vector2, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size_
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	(parent if parent != null else self).add_child(label)
	return label


func _refresh() -> void:
	if _header == null:
		return
	var forms := PlayerProfile.pronoun_tokens(pronouns)
	_header.text = "“Well, then,” said Doc Ama, “what are we calling %s?”" % String(forms["them"])
	for i in ROW_LABELS.size():
		var selected := i == row_index and not editing_name
		_row_labels[i].add_theme_color_override("font_color",
			SELECTED_COLOR if selected else (TEXT_COLOR if i == ROW_BEGIN else LABEL_COLOR))
		_row_values[i].add_theme_color_override("font_color", SELECTED_COLOR if selected else TEXT_COLOR)
		_row_values[i].text = _row_value_text(i, selected)
	_marker.position = Vector2(ROWS_X, _row_labels[row_index].position.y)
	_marker.visible = not editing_name
	_editor.visible = editing_name
	if editing_name:
		_hint.text = "↑↓←→ letters   SPACE pick   ESC done"
	elif row_index == ROW_NAME:
		_hint.text = "↑↓ choose   SPACE name your child"
	elif row_index == ROW_BEGIN:
		_hint.text = "↑↓ choose   SPACE begin"
	else:
		_hint.text = "↑↓ choose   ←→ change"
	_preview_caption.text = PlayerProfile.option_name("preset", int(appearance["preset"]))
	_refresh_editor()


func _row_value_text(i: int, selected: bool) -> String:
	match i:
		ROW_NAME:
			# Same two-character lead-in as the option rows, so every value lines up.
			if player_name == "":
				return "  (%s)" % placeholder_name
			return "  " + player_name
		ROW_PRONOUNS:
			return _arrows(String(PlayerProfile.PRONOUN_LABELS[pronouns]), selected)
		ROW_LOOK, ROW_HAIR, ROW_SKIN, ROW_OUTFIT:
			var field := String(ROW_FIELDS[i])
			return _arrows(PlayerProfile.option_name(field, int(appearance[field])), selected)
		ROW_BEGIN:
			return ""
	return ""


func _arrows(text: String, selected: bool) -> String:
	return ("← %s →" % text) if selected else ("  %s" % text)


func _refresh_editor() -> void:
	if _editor == null or not editing_name:
		return
	var rows := PlayerProfile.grid_rows(_caps_on())
	for y in rows.size():
		var row: Array = rows[y]
		for x in row.size():
			var label: Label = _editor_cells[y][x]
			var cell_bg: ColorRect = _editor_cell_bgs[y][x]
			var text := String(row[x])
			label.text = text
			var on := Vector2i(x, y) == grid_cursor
			cell_bg.color = MARK_COLOR if on else (Color("#f0d89a") if y == rows.size() - 1 else Color(0, 0, 0, 0))
			label.add_theme_color_override("font_color", PANEL_BG if on else PANEL_TEXT)
	_refresh_editor_name()


func _refresh_editor_name() -> void:
	if _editor_name == null:
		return
	var cursor := "_" if int(_blink * 2.0) % 2 == 0 and player_name.length() < PlayerProfile.NAME_MAX else " "
	if player_name == "":
		_editor_name.text = cursor
	else:
		_editor_name.text = player_name + cursor


func _apply_preview_look() -> void:
	if _preview == null:
		return
	_preview.sprite_frames = PlayerLook.build_frames(BASE_FRAMES, appearance)
	_play_preview()


func _play_preview() -> void:
	if _preview == null:
		return
	var anim := "walk_%s" % FACING_CYCLE[_facing_index]
	if _preview.sprite_frames.has_animation(anim):
		_preview.play(anim)
