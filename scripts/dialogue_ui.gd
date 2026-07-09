extends CanvasLayer
## Phase 5 Stage 1 dialogue box (ROADMAP.md "interact near an NPC to open a dialogue box,
## character-by-character text, basic branching, dialogue stored in JSON for easy editing").
## Tree traversal itself is scripts/dialogue_db.gd's pure static functions; this node is just
## the stateful presentation shell around them — same farm.gd/farm_grid.gd split.
##
## Opened via player.gd's npc_dialogue_requested signal (main.gd wires it to open_dialogue()
## here, mirroring structures.gd's chest_toggled -> hud.toggle_chest_ui() pattern) rather than a
## direct method call from player.gd, so player.gd stays instance-testable without a real
## DialogueUI scene existing (tests/test_player.gd).
##
## Keyboard-only, reusing existing input actions — no new project.godot entries needed:
##   - "use_tool" (Space/E) advances: on a node whose text hasn't finished revealing, the first
##     press instantly reveals the rest (Stardew's "skip the typewriter" convention rather than
##     forcing players to wait out every line); once revealed, the next press moves on to
##     whichever node is next (following the currently-highlighted choice, if the node has any),
##     and pressing it on a terminal node (no "next", no choices) closes the box.
##   - "move_up"/"move_down" (W/S + arrows), only meaningful once the current node's text is
##     fully revealed AND it has choices, move the highlighted option — the same cycle-then-
##     confirm shape settlement_select.gd's picker already uses, reused here rather than
##     inventing a new "pick a response" binding.
## While open, player.gd's _physics_process freezes entirely (its _in_dialogue() gate) and the
## talking NPC freezes too (npc.gd's set_talking) — close() unfreezes both unconditionally, so a
## conversation can never leave the player or the NPC stuck.

const DialogueDB := preload("res://scripts/dialogue_db.gd")

## Reveal rate for the character-by-character typewriter effect.
const CHARS_PER_SECOND := 28.0
## Comfortably longer than any authored line takes to reveal at CHARS_PER_SECOND — "instantly
## reveal the rest" just fast-forwards _elapsed past this, no special-cased skip flag needed.
const INSTANT_REVEAL_ELAPSED := 999.0

const CHOICE_COLOR := Color("#7b5025")            # worn wood (dark) — unselected choice
const CHOICE_SELECTED_COLOR := Color("#c5520f")   # rust red — reads as "this one's highlighted"

@onready var box: Control = %Box
@onready var name_label: Label = %NameLabel
@onready var body_label: Label = %BodyLabel
@onready var choices_box: VBoxContainer = %ChoicesBox
@onready var hint_label: Label = %HintLabel

## True while a conversation is open — player.gd's _in_dialogue() reads this directly (same
## shape as builder.gd's `active`).
var active := false
var npc: Node = null

var _node_id := ""
var _full_text := ""
var _elapsed := 0.0
var _choice_index := 0
var _choice_labels: Array[Label] = []


func _ready() -> void:
	box.visible = false
	for child in choices_box.get_children():
		_choice_labels.append(child as Label)


func _process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	_refresh_body()


## Opens a dialogue for `target_npc` at its data's start node. Called by main.gd, wired to
## player.gd's npc_dialogue_requested signal. A no-op if the npc has no dialogue.json entry
## (defensive — every roster NPC has one, see tests/test_dialogue_db.gd).
func open_dialogue(target_npc: Node) -> void:
	if active or not DialogueDB.has_dialogue(String(target_npc.npc_id)):
		return
	npc = target_npc
	npc.set_talking(true)
	active = true
	box.visible = true
	name_label.text = DialogueDB.display_name(String(npc.npc_id))
	_goto_node(DialogueDB.start_node_id(String(npc.npc_id)))


func close() -> void:
	active = false
	box.visible = false
	if npc != null:
		npc.set_talking(false)
	npc = null


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	var choices := DialogueDB.node_choices(_current_node())
	if not choices.is_empty() and _is_fully_revealed():
		if event.is_action_pressed("move_up"):
			_choice_index = wrapi(_choice_index - 1, 0, choices.size())
			_refresh_choices()
			return
		elif event.is_action_pressed("move_down"):
			_choice_index = wrapi(_choice_index + 1, 0, choices.size())
			_refresh_choices()
			return
	if event.is_action_pressed("use_tool"):
		_advance()


func _advance() -> void:
	if not _is_fully_revealed():
		_elapsed = INSTANT_REVEAL_ELAPSED
		_refresh_body()
		return
	var next_id := DialogueDB.advance_from(_current_node(), _choice_index)
	if next_id == "":
		close()
	else:
		_goto_node(next_id)


func _goto_node(node_id: String) -> void:
	_node_id = node_id
	_elapsed = 0.0
	_choice_index = 0
	_full_text = String(_current_node().get("text", ""))
	_refresh_body()
	_refresh_choices()


func _current_node() -> Dictionary:
	return DialogueDB.dialogue_node(String(npc.npc_id), _node_id)


func _is_fully_revealed() -> bool:
	return DialogueDB.visible_chars(_full_text.length(), _elapsed, CHARS_PER_SECOND) \
		>= _full_text.length()


func _refresh_body() -> void:
	var count := DialogueDB.visible_chars(_full_text.length(), _elapsed, CHARS_PER_SECOND)
	body_label.text = _full_text.substr(0, count)
	var revealed := _is_fully_revealed()
	hint_label.text = "" if not revealed else _hint_text()
	# Choices are populated as soon as their node loads (_refresh_choices, below) but only shown
	# once the line has finished typing — matching hint_label's own reveal-gated visibility, and
	# avoiding the odd read of a response menu appearing mid-sentence.
	choices_box.visible = revealed and not DialogueDB.node_choices(_current_node()).is_empty()


func _hint_text() -> String:
	if not DialogueDB.node_choices(_current_node()).is_empty():
		return "Up/Down to choose, Space to confirm"
	return "Space to continue"


func _refresh_choices() -> void:
	var choices := DialogueDB.node_choices(_current_node())
	for i in _choice_labels.size():
		var label := _choice_labels[i]
		if i < choices.size():
			label.visible = true
			label.text = String(choices[i].get("text", ""))
			label.add_theme_color_override("font_color",
				CHOICE_SELECTED_COLOR if i == _choice_index else CHOICE_COLOR)
		else:
			label.visible = false
