extends CanvasLayer
## A small modal prompt (Milestone C, 2026-10-07): a title, a few lines of text and one or two
## choices. Used for the expedition's decisions (ride out with Kael, go deeper, head home) and,
## with a single choice, as the reader for lore notes. Built in code by main.gd and registered
## with the modal gate like every other modal (the clock pauses, the player freezes).
##
## Keys: left/right (or up/down) move between the choices, Space/E/Enter confirm, Esc picks the
## last choice (always the safe "no"). Mouse: click a choice.

const PANEL_BG := Color("#ffedb1")
const PANEL_EDGE := Color("#7b5025")
const TEXT := Color("#281a0b")
const DIM := Color("#6b5a43")
const CHOICE_BG := Color("#e8d29a")
const CHOICE_ACTIVE := Color("#c5520f")
const WIDTH := 220.0

signal chosen(index: int)

var active := false
var modal_gate: RefCounted = null

var _box: Control = null
var _title: Label = null
var _body: Label = null
var _choice_nodes: Array = []
var _choice_labels: Array[String] = []
var _cursor := 0
var _callback: Callable = Callable()
var _armed := false


func _ready() -> void:
	layer = 21
	_build()
	_box.visible = false


## Shows the prompt. `on_choice` gets the chosen index (Esc = the last choice).
## Returns false if another modal is already open.
func ask(title: String, body: String, choices: Array, on_choice: Callable) -> bool:
	if active:
		return false
	if modal_gate != null and modal_gate.is_any_open_except(self):
		return false
	_title.text = title
	_body.text = body
	_choice_labels.clear()
	for c in choices:
		_choice_labels.append(String(c))
	_callback = on_choice
	_cursor = 0
	_armed = false
	_rebuild_choices()
	_layout()
	active = true
	_box.visible = true
	Audio.play_sfx("ui_open", -6.0)
	return true


## A read-only page (a lore note): one "Close" choice.
func show_text(title: String, body: String, on_close: Callable = Callable()) -> bool:
	return ask(title, body, ["Close"], func(_i: int) -> void:
		if on_close.is_valid():
			on_close.call())


func choose(index: int) -> void:
	if not active:
		return
	active = false
	_box.visible = false
	Audio.play_sfx("ui_confirm" if index == 0 else "ui_close", -6.0)
	var cb := _callback
	_callback = Callable()
	chosen.emit(index)
	if cb.is_valid():
		cb.call(index)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	# The press that opened the prompt (E on the truck) must be released before E confirms.
	if not _armed:
		if event.is_action_released("interact") or event.is_action_released("use_tool") \
				or event is InputEventMouseMotion:
			_armed = true
		if not (event.is_action_pressed("ui_cancel") or event.is_action_pressed("move_left") \
				or event.is_action_pressed("move_right")):
			return
	if event.is_action_pressed("ui_cancel"):
		choose(_choice_labels.size() - 1)
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		_move(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		_move(1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("use_tool") \
			or event.is_action_pressed("ui_accept"):
		choose(_cursor)
	get_viewport().set_input_as_handled()


func _move(step: int) -> void:
	_cursor = posmod(_cursor + step, maxi(_choice_labels.size(), 1))
	Audio.play_sfx("ui_hover", -10.0)
	_refresh_choices()


## -- View --

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_box = Control.new()
	root.add_child(_box)
	_title = _label(Vector2(8, 4), TEXT)
	_body = _label(Vector2(8, 16), DIM)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size = Vector2(WIDTH - 16.0, 10)


func _label(pos: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(label)
	return label


func _layout() -> void:
	_body.size = Vector2(WIDTH - 16.0, 10)
	_body.reset_size()
	_body.size.x = WIDTH - 16.0
	var body_h := maxf(_body.get_combined_minimum_size().y, 10.0)
	var choices_y := 18.0 + body_h + 4.0
	var height := choices_y + 16.0
	_box.size = Vector2(WIDTH, height)
	_box.position = Vector2((320.0 - WIDTH) / 2.0, (192.0 - height) / 2.0 - 8.0)
	for child in _box.get_children():
		if child.name == "Edge":
			(child as ColorRect).size = _box.size
		elif child.name == "Bg":
			(child as ColorRect).size = _box.size - Vector2(4, 4)
	var n := _choice_nodes.size()
	var w := (WIDTH - 16.0 - 4.0 * float(n - 1)) / float(maxi(n, 1))
	for i in n:
		var c: ColorRect = _choice_nodes[i]
		c.position = Vector2(8.0 + i * (w + 4.0), choices_y)
		c.size = Vector2(w, 12)
		var label: Label = c.get_child(0)
		label.size = c.size
	_refresh_choices()


func _rebuild_choices() -> void:
	for c in _choice_nodes:
		(c as Node).queue_free()
	_choice_nodes.clear()
	if _box.get_node_or_null("Edge") == null:
		var edge := ColorRect.new()
		edge.name = "Edge"
		edge.color = PANEL_EDGE
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_child(edge)
		_box.move_child(edge, 0)
		var bg := ColorRect.new()
		bg.name = "Bg"
		bg.color = PANEL_BG
		bg.position = Vector2(2, 2)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_child(bg)
		_box.move_child(bg, 1)
	for i in _choice_labels.size():
		var c := ColorRect.new()
		c.color = CHOICE_BG
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		var index := i
		c.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				choose(index))
		c.mouse_entered.connect(func() -> void:
			_cursor = index
			_refresh_choices())
		var label := Label.new()
		label.text = _choice_labels[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", TEXT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(label)
		_box.add_child(c)
		_choice_nodes.append(c)


func _refresh_choices() -> void:
	for i in _choice_nodes.size():
		var c: ColorRect = _choice_nodes[i]
		c.color = CHOICE_ACTIVE if i == _cursor else CHOICE_BG
		var label: Label = c.get_child(0)
		label.add_theme_color_override("font_color", PANEL_BG if i == _cursor else TEXT)
