extends Control
## Settlement selection screen (ROADMAP.md Phase 4) — the new run/main_scene per project.godot,
## shown once at every launch (no save system exists yet, that's Stage 3, so there's no "resume"
## path to skip past this). Presents SettlementDB's 3 starts (name + lore blurb + resource lean)
## and, on confirm, stores the choice in the GameState autoload and transitions to
## scenes/main.tscn, which reads it back via scripts/test_map.gd's layout selection.
##
## Keyboard-only, reusing existing input actions rather than adding new ones to project.godot's
## [input] section (this screen is a separate scene from gameplay, so reusing action names here
## has no conflict): move_up/move_down (already W/S + arrows) cycle the highlighted settlement,
## use_tool (space/E) confirms it, and hotbar_slot_1/2/3 (keys 1/2/3) jump-select-and-confirm
## directly — a quicker path for players who already know which start they want.

const SettlementDB := preload("res://scripts/settlement_db.gd")

const NAME_COLOR := Color("#ffc948")     # lamplight gold
const LEAN_COLOR := Color("#95ac49")     # faded field green
const TEXT_COLOR := Color("#ffedb1")     # worn cream
const HINT_COLOR := Color("#9d9180")     # scavenged metal
const DOT_ACTIVE := Color("#ffc948")
const DOT_INACTIVE := Color("#7b5025")

@onready var name_label: Label = %NameLabel
@onready var lean_label: Label = %LeanLabel
@onready var lore_label: RichTextLabel = %LoreLabel
@onready var summary_label: Label = %SummaryLabel
@onready var dots: HBoxContainer = %Dots

var current_index := 0
var _settlements: Array[Dictionary] = []
var _dot_rects: Array[ColorRect] = []


func _ready() -> void:
	_settlements = SettlementDB.list()
	for i in _settlements.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(6, 6)
		dots.add_child(dot)
		_dot_rects.append(dot)
	_refresh_display()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up") or event.is_action_pressed("move_left"):
		_set_index(wrap_index(current_index, -1, _settlements.size()))
	elif event.is_action_pressed("move_down") or event.is_action_pressed("move_right"):
		_set_index(wrap_index(current_index, 1, _settlements.size()))
	elif event.is_action_pressed("use_tool"):
		_confirm(current_index)
	elif event.is_action_pressed("hotbar_slot_1"):
		_confirm(0)
	elif event.is_action_pressed("hotbar_slot_2"):
		_confirm(1)
	elif event.is_action_pressed("hotbar_slot_3"):
		_confirm(2)


func _set_index(index: int) -> void:
	current_index = index
	_refresh_display()


func _confirm(index: int) -> void:
	if index < 0 or index >= _settlements.size():
		return
	current_index = index
	GameState.choose_settlement(String(_settlements[index]["id"]))
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _refresh_display() -> void:
	var s: Dictionary = _settlements[current_index]
	name_label.text = String(s.get("name", ""))
	lean_label.text = "Resource Lean: %s" % String(s.get("resource_lean", ""))
	summary_label.text = String(s.get("summary", ""))
	lore_label.text = String(s.get("lore", ""))
	for i in _dot_rects.size():
		_dot_rects[i].color = DOT_ACTIVE if i == current_index else DOT_INACTIVE


## Pure index-wrapping math (testable headlessly, no Control/scene required): moves `current` by
## `delta` and wraps around `count` in either direction.
static func wrap_index(current: int, delta: int, count: int) -> int:
	if count <= 0:
		return 0
	return posmod(current + delta, count)
