extends CanvasLayer
## Silas's ranch modal. It deliberately follows Marta's keyboard-only store contract while adding
## one deterministic Care all action; the actual purchase/capacity rules live in animals.gd.

const AnimalDB := preload("res://scripts/animal_db.gd")

const CARE_ID := "__CARE__"
const ROW_COLOR := Color("#7b5025")
const ROW_SELECTED_COLOR := Color("#c5520f")

@onready var box: Control = %Box
@onready var credits_label: Label = %CreditsLabel
@onready var rows_box: VBoxContainer = %RowsBox
@onready var description_label: Label = %DescriptionLabel
@onready var status_label: Label = %StatusLabel

var active := false
var modal_gate: RefCounted = null
var _player: Node
var _animals: Node
var _row_ids: Array[String] = []
var _row_labels: Array[Label] = []
var _index := 0


func _ready() -> void:
	box.visible = false
	_row_ids = AnimalDB.ids()
	_row_ids.append(CARE_ID)
	_row_ids.append("")
	for child in rows_box.get_children():
		_row_labels.append(child as Label)


func bind(player: Node, animals: Node) -> void:
	_player = player
	_animals = animals
	_player.credits_changed.connect(_on_credits_changed)


func open_ranch(_target_npc: Node) -> void:
	if active or _player == null or _animals == null:
		return
	if modal_gate != null and modal_gate.is_any_open_except(self):
		return
	active = true
	box.visible = true
	_index = 0
	status_label.text = ""
	_refresh()


func close() -> void:
	active = false
	box.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("move_up"):
		_index = wrapi(_index - 1, 0, _row_ids.size())
		status_label.text = ""
		_refresh()
	elif event.is_action_pressed("move_down"):
		_index = wrapi(_index + 1, 0, _row_ids.size())
		status_label.text = ""
		_refresh()
	elif event.is_action_pressed("use_tool"):
		_confirm()


func _confirm() -> void:
	var id := _row_ids[_index]
	if id.is_empty():
		close()
		return
	if id == CARE_ID:
		status_label.text = "Cared for %d animals." % _animals.care_all(DayManager.day)
		return
	var result: Dictionary = _animals.attempt_purchase(id, _player.credits)
	if not bool(result.get("ok", false)):
		if result.get("reason", "") == "no_capacity":
			status_label.text = "Build a %s first." % AnimalDB.housing(id).capitalize()
		else:
			status_label.text = "Not enough Credits."
		return
	_player.set_credits(int(result["remaining_credits"]))
	status_label.text = "Bought %s." % AnimalDB.display_name(id)
	_refresh()


func _on_credits_changed(_current: int) -> void:
	if active:
		_refresh()


func _refresh() -> void:
	var hint := get_node_or_null("Root/Box/HintLabel") as Label
	if hint != null:
		hint.text = preload("res://scripts/settings.gd").list_hint_for(get_node_or_null("/root/Settings"), "buy/care/leave")  # names the pad's buttons on a pad
	credits_label.text = "Credits: %d" % (_player.credits if _player != null else 0)
	for i in _row_labels.size():
		var label := _row_labels[i]
		if i >= _row_ids.size():
			label.visible = false
			continue
		label.visible = true
		var id := _row_ids[i]
		if id.is_empty():
			label.text = "Leave"
		elif id == CARE_ID:
			label.text = "Care all animals"
		else:
			label.text = "%s — %d Cr" % [AnimalDB.display_name(id), AnimalDB.price(id)]
		label.add_theme_color_override("font_color",
			ROW_SELECTED_COLOR if i == _index else ROW_COLOR)
	var current_id := _row_ids[_index]
	if current_id.is_empty():
		description_label.text = "Thanks for stopping by."
	elif current_id == CARE_ID:
		description_label.text = "Give every animal its daily care. Normal animals need this to produce tomorrow."
	else:
		description_label.text = AnimalDB.description(current_id)
