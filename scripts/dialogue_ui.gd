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
##
## Phase 5 Stage 2: a choice's "next" can also be the OPEN_STORE_SENTINEL below (see
## data/dialogue.json's class doc) — landing on it closes this box and emits store_requested
## instead of advancing to another node, so Marta's "Let's see what you've got" choice opens
## scripts/store_ui.gd rather than just printing more text.
##
## Phase 7 Stage 3 (affinity) adds two responsibilities here, both deliberately in this
## presentation shell rather than in the pure dialogue_db.gd (same domain-split reasoning as the
## sentinels above):
##   1. THE TALK TICK. A real conversation opening awards a once-per-day affinity point
##      (affinity.try_award_talk, which owns both the named-NPC gate and the daily cap). "Real"
##      means the player walked up and talked: open_dialogue() below. The scripted entry point
##      open_dialogue_at() — the Day-28 food-shortage beat and main.gd's "not_yet" ranch-store
##      branch — never awards, since neither is the player choosing to strike up a conversation.
##      Both still funnel through the same _open_dialogue_at(); the two public entry points
##      differ only in the `award_affinity` flag they pass, so there is exactly one open path.
##   2. CHOICE FILTERING. Every rendered/traversed choice list goes through _available_choices()
##      (DialogueDB.choice_available per choice), so a choice carrying "min_affinity" is hidden
##      below that value. Filtering happens in ONE place and every consumer — the up/down
##      selection, the reveal-gated visibility, the hint text and _advance()'s own traversal —
##      reads that same filtered list, so the highlighted index can never address a hidden option.

const DialogueDB := preload("res://scripts/dialogue_db.gd")

## Reveal rate for the character-by-character typewriter effect.
const CHARS_PER_SECOND := 28.0
## Comfortably longer than any authored line takes to reveal at CHARS_PER_SECOND — "instantly
## reveal the rest" just fast-forwards _elapsed past this, no special-cased skip flag needed.
const INSTANT_REVEAL_ELAPSED := 999.0

## Recognized only here (the presentation shell), not in scripts/dialogue_db.gd, which stays a
## domain-agnostic pure traversal module with no concept of "a store."
const OPEN_STORE_SENTINEL := "OPEN_STORE"
const OPEN_RANCH_STORE_SENTINEL := "OPEN_RANCH_STORE"

## Phase 8 Stage 3 (settler arrivals): the same runtime-sentinel pattern as OPEN_STORE_SENTINEL
## above, recognized only here — a visiting settler's greeting tree (scripts/settlers.gd's
## _greeting_dialogue, registered via dialogue_db.gd's register_runtime) ends its 2-choice branch
## on one of these instead of another node id.
const SETTLER_ACCEPT_SENTINEL := "SETTLER_ACCEPT"
const SETTLER_REJECT_SENTINEL := "SETTLER_REJECT"

const CHOICE_COLOR := Color("#7b5025")            # worn wood (dark) — unselected choice
const CHOICE_SELECTED_COLOR := Color("#c5520f")   # rust red — reads as "this one's highlighted"

## Phase 5 Stage 2: fired when a conversation's choice leads to OPEN_STORE_SENTINEL — main.gd
## wires this to scripts/store_ui.gd's open_store(), the same one-level-deeper handoff shape as
## player.gd's own npc_dialogue_requested -> main.gd -> DialogueUI.open_dialogue().
signal store_requested(npc: Node)
signal ranch_store_requested(npc: Node)

## Phase 8 Stage 3: fired when a conversation's choice leads to SETTLER_ACCEPT_SENTINEL/
## SETTLER_REJECT_SENTINEL — main.gd wires this to scripts/settlers.gd's resolve_visitor(),
## the same one-level-deeper handoff shape as store_requested above.
signal settler_decision_requested(npc: Node, accepted: bool)

@onready var box: Control = %Box
@onready var name_label: Label = %NameLabel
@onready var body_label: Label = %BodyLabel
@onready var choices_box: VBoxContainer = %ChoicesBox
@onready var hint_label: Label = %HintLabel

## True while a conversation is open — player.gd's _in_dialogue() reads this directly (same
## shape as builder.gd's `active`).
var active := false
## Phase 6: the shared modal mutual-exclusion registry (scripts/modal_gate.gd), assigned by
## main.gd — open_dialogue() refuses while any other modal surface (build mode, store, shipping
## UI) is open. Structurally this was already unreachable (player.use_tool(), the only trigger,
## can't fire while build mode or another freeze-surface is active), but the gate makes the
## invariant explicit rather than incidental to player.gd's dispatch details.
var modal_gate: RefCounted = null
## Phase 7 Stage 3: the settlement-wide relationship track (scripts/affinity.gd), assigned by
## main.gd at boot like modal_gate above. null when unbound (a bare DialogueUI in a test or tool),
## in which case the talk tick is skipped and choice filtering runs against a value of 0 — i.e.
## exactly today's behaviour, since no authored choice carries "min_affinity" yet.
var affinity: Node = null
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
func open_dialogue(target_npc: Node) -> bool:
	return _open_dialogue_at(target_npc, DialogueDB.start_node_id(String(target_npc.npc_id)), true)


## Opens an authored alternate entry point for a scripted beat while retaining the same NPC,
## presentation, input handling, and normal interaction path. The beat caller owns its one-time
## save flag; this method only reports whether the modal actually opened. Never awards affinity
## (see class doc item 1) — a beat the game starts at the player is not the player choosing to
## talk, and the Day-28 shortage in particular fires unprompted at day start.
func open_dialogue_at(target_npc: Node, start_node_id: String) -> bool:
	return _open_dialogue_at(target_npc, start_node_id, false)


## The one shared open path. `award_affinity` distinguishes a real player-initiated conversation
## from a scripted beat; the award itself only lands if the box ACTUALLY opened (an already-open
## box, a missing dialogue entry, or another modal holding the gate all return early before it),
## so a refused open can never hand out a point.
func _open_dialogue_at(target_npc: Node, start_node_id: String, award_affinity: bool) -> bool:
	if active or not DialogueDB.has_dialogue(String(target_npc.npc_id)):
		return false
	if modal_gate != null and modal_gate.is_any_open_except(self):
		return false
	npc = target_npc
	npc.set_talking(true)
	active = true
	box.visible = true
	name_label.text = DialogueDB.display_name(String(npc.npc_id))
	if award_affinity and affinity != null:
		# affinity.gd owns both gates (named NPCs only, once per day) — this call site stays
		# deliberately unconditional so the rules live in one place.
		affinity.try_award_talk(String(npc.npc_id), DayManager.day)
	_goto_node(start_node_id)
	return true


func close() -> void:
	active = false
	box.visible = false
	if npc != null:
		npc.set_talking(false)
	npc = null


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	# Esc backs out of the conversation (playtest UX gap, 2026-07-10 — Stardew's "Esc closes
	# whatever menu you're in" convention). Godot's built-in "ui_cancel" action (Escape) is used
	# as-is; project.godot doesn't override it. Additive: the existing close paths (advancing
	# past a terminal node) are untouched, and close() already unfreezes player and NPC
	# unconditionally, so backing out mid-conversation can never leave either stuck.
	if event.is_action_pressed("ui_cancel"):
		close()
		return
	var choices := _available_choices()
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
	# advance_from() is fed the FILTERED node (see _filtered_node) so the highlighted index means
	# the same thing here as it does on screen. A branch whose every choice is gated out therefore
	# falls through to the node's own "next" (absent on a branch node -> "" -> close), rather than
	# silently following a hidden option.
	var next_id := DialogueDB.advance_from(_filtered_node(), _choice_index)
	if next_id == OPEN_STORE_SENTINEL:
		_open_store()
	elif next_id == OPEN_RANCH_STORE_SENTINEL:
		_open_ranch_store()
	elif next_id == SETTLER_ACCEPT_SENTINEL:
		_resolve_settler_decision(true)
	elif next_id == SETTLER_REJECT_SENTINEL:
		_resolve_settler_decision(false)
	elif next_id == "":
		close()
	else:
		_goto_node(next_id)


## Closes the conversation and hands off to scripts/store_ui.gd (see class doc / the sentinel's
## comment above). Captures `npc` before close() clears the field.
func _open_store() -> void:
	var target_npc := npc
	close()
	store_requested.emit(target_npc)


func _open_ranch_store() -> void:
	var target_npc := npc
	close()
	ranch_store_requested.emit(target_npc)


## Closes the conversation and hands off to scripts/settlers.gd's resolve_visitor() (see class
## doc / the sentinels' comment above). Captures `npc` before close() clears the field, same
## shape as _open_store().
func _resolve_settler_decision(accepted: bool) -> void:
	var target_npc := npc
	close()
	settler_decision_requested.emit(target_npc, accepted)


func _goto_node(node_id: String) -> void:
	_node_id = node_id
	_elapsed = 0.0
	_choice_index = 0
	_full_text = String(_current_node().get("text", ""))
	_refresh_body()
	_refresh_choices()


func _current_node() -> Dictionary:
	return DialogueDB.dialogue_node(String(npc.npc_id), _node_id)


## -- Phase 7 Stage 3: affinity-gated choices (see class doc item 2) --

## The player's current relationship value with the NPC being spoken to; 0 when this box has no
## affinity node bound or no NPC (the same value a never-met NPC has, so an unbound UI renders
## exactly what a first meeting would).
func _affinity_value() -> int:
	if affinity == null or npc == null:
		return 0
	return int(affinity.value_for(String(npc.npc_id)))


## The current node's choices with every affinity-gated one removed. The single source of truth
## for "which options exist right now" — selection, rendering, visibility and traversal all read
## this, never DialogueDB.node_choices directly.
func _available_choices() -> Array:
	var value := _affinity_value()
	var out: Array = []
	for choice in DialogueDB.node_choices(_current_node()):
		if choice is Dictionary and DialogueDB.choice_available(choice, value):
			out.append(choice)
	return out


## The current node with its choices replaced by the available ones, so the pure
## DialogueDB.advance_from() can be reused verbatim on the list the player actually sees. A
## shallow duplicate: the cached node in dialogue_db.gd's dictionary is never mutated.
func _filtered_node() -> Dictionary:
	var node := _current_node()
	if not node.has("choices"):
		return node
	var filtered := node.duplicate()
	filtered["choices"] = _available_choices()
	return filtered


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
	choices_box.visible = revealed and not _available_choices().is_empty()


func _hint_text() -> String:
	if not _available_choices().is_empty():
		return "Up/Down to choose, Space to confirm"
	return "Space to continue"


func _refresh_choices() -> void:
	var choices := _available_choices()
	for i in _choice_labels.size():
		var label := _choice_labels[i]
		if i < choices.size():
			label.visible = true
			label.text = String(choices[i].get("text", ""))
			label.add_theme_color_override("font_color",
				CHOICE_SELECTED_COLOR if i == _choice_index else CHOICE_COLOR)
		else:
			label.visible = false
