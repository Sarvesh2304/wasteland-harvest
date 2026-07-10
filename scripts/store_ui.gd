extends CanvasLayer
## Marta's store (ROADMAP.md Phase 5 Stage 2: "Town store — Marta sells seeds/basic tools/food;
## UI shows name/description/price; currency is Credits"). scripts/shop_db.gd owns the pure
## catalog/pricing math; this node is just the stateful presentation shell around it — same
## dialogue_ui.gd/dialogue_db.gd split.
##
## Opened via scripts/dialogue_ui.gd's store_requested signal (main.gd wires it to open_store()
## here), itself reached by choosing "Let's see what you've got" in Marta's dialogue tree (see
## data/dialogue.json's "stocktake" node -> a choice whose "next" is dialogue_ui.gd's
## OPEN_STORE_SENTINEL) — one level deeper than the existing player -> main.gd -> DialogueUI
## handoff, same shape.
##
## Keyboard-only, reusing existing input actions — no new project.godot entries needed:
##   - "move_up"/"move_down" cycle the highlighted row, the same cycle-then-confirm shape
##     settlement_select.gd/dialogue_ui.gd's choice-cycling already use.
##   - "use_tool" on an item row buys ONE of it if funds allow (repeatable — buying several of
##     the same item is just pressing it again, no need to back out and re-navigate), and on the
##     trailing "Leave" row closes the store instead. Reusing the existing "browse a list, confirm
##     one" shape for "close" too (rather than inventing a new dedicated close key/action) is
##     deliberate: it's exactly dialogue_ui.gd's own confirm-a-choice interaction, just with one
##     of the choices being "leave" instead of "go to another node."
##
## Buy-only (ROADMAP Phase 5 Stage 2 vs Stage 3): this UI never removes/credits anything for
## selling crops — that's the shipping box's separate job next stage. Every purchase routes
## through scripts/inventory.gd's existing add_item(), never a new mutation path.
##
## While open, player.gd's _physics_process freezes entirely (its _in_store() gate, mirroring
## _in_dialogue()) so the player can't wander off mid-purchase; close() unconditionally
## unfreezes it, so a purchase (or a refusal) can never leave the player stuck.

const ShopDB := preload("res://scripts/shop_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")

const ROW_COLOR := Color("#7b5025")            # worn wood (dark) — unselected row
const ROW_SELECTED_COLOR := Color("#c5520f")   # rust red — matches dialogue_ui's choice highlight
const LEAVE_TEXT := "Leave"
const LEAVE_DESCRIPTION := "Thanks for stopping by."

@onready var box: Control = %Box
@onready var credits_label: Label = %CreditsLabel
@onready var rows_box: VBoxContainer = %RowsBox
@onready var description_label: Label = %DescriptionLabel
@onready var status_label: Label = %StatusLabel
@onready var hint_label: Label = %HintLabel

## True while the store is open — player.gd's _in_store() reads this directly (same shape as
## dialogue_ui.gd's `active`/builder.gd's `active`).
var active := false
## Phase 6: the shared modal mutual-exclusion registry (scripts/modal_gate.gd), assigned by
## main.gd — open_store() refuses while any other modal surface is open (see dialogue_ui.gd's
## matching comment; the dialogue→store handoff still works because dialogue_ui closes itself
## BEFORE emitting store_requested).
var modal_gate: RefCounted = null

var _player: Node = null
## The catalog's item ids plus a trailing "" sentinel for the "Leave" row.
var _row_ids: Array[String] = []
var _row_labels: Array[Label] = []
var _index := 0


func _ready() -> void:
	box.visible = false
	_row_ids = ShopDB.stock_ids().duplicate()
	_row_ids.append("")  # trailing Leave row
	for child in rows_box.get_children():
		_row_labels.append(child as Label)


## Wired by main.gd, mirroring builder.gd's bind() — the player reference is needed since the
## actual purchase (Credits deduction + inventory grant) happens here. Also subscribes to the
## player's credits_changed so the displayed balance stays live even if it changes for a reason
## other than this UI's own _confirm() (e.g. a future Stage 3 shipping-box sale landing while the
## store happens to be open) — the same "bind once in bind(), react while active" shape hud.gd's
## own bind_player() uses for its energy/credits displays.
func bind(player: Node) -> void:
	_player = player
	_player.credits_changed.connect(_on_credits_changed)


## Opens the store, bound to `target_npc` (accepted for parity with dialogue_ui.gd's
## open_dialogue(npc) signature and to leave room for a future multi-shopkeeper roster — this
## stage there is only one store, so the catalog itself doesn't vary by npc).
func open_store(_target_npc: Node) -> void:
	if active or _player == null:
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
	# Esc leaves the store — same additive Stardew-convention shortcut as dialogue_ui.gd's
	# (see its matching comment); the Leave row keeps working exactly as before.
	if event.is_action_pressed("ui_cancel"):
		close()
		return
	if event.is_action_pressed("move_up"):
		_index = wrapi(_index - 1, 0, _row_ids.size())
		status_label.text = ""
		_refresh()
	elif event.is_action_pressed("move_down"):
		_index = wrapi(_index + 1, 0, _row_ids.size())
		status_label.text = ""
		_refresh()
	elif event.is_action_pressed("use_tool"):
		_confirm()


## Buys the highlighted item, or closes the store if the highlighted row is the trailing "Leave"
## entry. Insufficient funds are a silent-but-visible refusal (a status message, no crash, no
## partial deduction) — never a negative balance and never a shrug with no feedback at all.
func _confirm() -> void:
	var item_id := _row_ids[_index]
	if item_id == "":
		close()
		return
	var result := ShopDB.attempt_purchase(_player.credits, item_id)
	if not result["ok"]:
		status_label.text = "Not enough Credits."
		return
	# set_credits() emits credits_changed, which _on_credits_changed() turns back into a _refresh()
	# call while active — no need to also refresh explicitly here (see bind()'s comment).
	_player.set_credits(int(result["credits"]))
	# Tools need a fresh full-durability instance (mirrors player._give_starting_loadout()'s own
	# Inventory.add_item(id, 1, durability) call); everything else is a plain stackable grant.
	var durability := ItemDB.durability_max(item_id) if ItemDB.is_tool_item(item_id) else -1
	_player.inventory.add_item(item_id, 1, durability)
	status_label.text = "Bought %s." % String(ItemDB.get_item(item_id).get("name", item_id))


## Live balance update while open (see bind()'s comment) — a no-op while closed, since there's
## nothing to redraw and _player/labels are only meaningfully current while active anyway.
func _on_credits_changed(_current: int) -> void:
	if active:
		_refresh()


func _refresh() -> void:
	credits_label.text = "Credits: %d" % (_player.credits if _player != null else 0)
	for i in _row_labels.size():
		var label := _row_labels[i]
		if i >= _row_ids.size():
			label.visible = false
			continue
		label.visible = true
		var item_id := _row_ids[i]
		label.text = LEAVE_TEXT if item_id == "" \
			else "%s — %d Cr" % [String(ItemDB.get_item(item_id).get("name", item_id)), ShopDB.price(item_id)]
		label.add_theme_color_override("font_color",
			ROW_SELECTED_COLOR if i == _index else ROW_COLOR)
	var current_id := _row_ids[_index]
	description_label.text = LEAVE_DESCRIPTION if current_id == "" \
		else String(ItemDB.get_item(current_id).get("description", ""))
