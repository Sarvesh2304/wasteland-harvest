extends CanvasLayer
## The shipping box's crop-loading UI (ROADMAP.md Phase 5 Stage 3: "Shipping box — place
## harvested crops before sleeping; Credits added next morning"). scripts/shipping_db.gd owns
## the pure roster/valuation math; this node is the stateful presentation shell around it —
## the same shop_db.gd/store_ui.gd split, and structurally this file IS store_ui.gd's shape
## with buy flipped to load: a fixed row list, cycle-then-confirm, a trailing Leave row.
##
## Opened via player.gd's shipping_box_requested signal (main.gd wires it to open_box() here),
## fired from use_tool()'s priority dispatch when the player interacts facing the box — a direct
## world interaction like the chest/bed, not a dialogue-nested one like the store.
##
## Keyboard-only, reusing existing input actions — no new project.godot entries:
##   - "move_up"/"move_down" cycle the highlighted row (settlement_select.gd's shape).
##   - "use_tool" on a crop row loads ONE unit of it from the player's inventory into the box
##     (repeatable — hold-free repeated presses to load more), and on the trailing "Leave" row
##     closes the UI. One-unit-per-confirm deliberately matches store_ui.gd's one-per-confirm
##     buying exactly, so the economy's two ends share one muscle memory; a load-whole-stack
##     shortcut is cheap to add later if real play wants it, but inventing a second confirm
##     convention now would cost more consistency than it saves presses at this stage's tiny
##     harvest sizes.
##
## Rows are the FIXED shippable roster (ShippingDB.shippable_ids() — all 4 crops), not just
## what the player currently holds: stable row positions can't shift under the cursor as counts
## hit zero mid-session, and a "held 0" row confirming to a status refusal teaches the roster.
##
## One-way (Stardew's bin convention, documented in shipping_db.gd/structures.gd): nothing here
## takes an item back out — no retrieval flow exists to build, and the overnight sale is the
## box's only outlet.
##
## While open, player.gd's _physics_process freezes entirely (its _in_shipping() gate, mirroring
## _in_store()); close() unconditionally unfreezes, so the player can never be left stuck.

const ShippingDB := preload("res://scripts/shipping_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")

const ROW_COLOR := Color("#7b5025")            # worn wood (dark) — unselected row
const ROW_SELECTED_COLOR := Color("#c5520f")   # rust red — matches store_ui/dialogue_ui highlights
const LEAVE_TEXT := "Leave"
const INFO_TEXT := "Crops ship overnight. Credits arrive in the morning — no taking them back out."

@onready var box: Control = %Box
@onready var value_label: Label = %ValueLabel
@onready var rows_box: VBoxContainer = %RowsBox
@onready var info_label: Label = %InfoLabel
@onready var status_label: Label = %StatusLabel
@onready var hint_label: Label = %HintLabel

## True while the UI is open — player.gd's _in_shipping() reads this directly (same shape as
## store_ui.gd's/dialogue_ui.gd's/builder.gd's `active`).
var active := false
## Phase 6: the shared modal mutual-exclusion registry (scripts/modal_gate.gd), assigned by
## main.gd — open_box() refuses while any other modal surface is open (see dialogue_ui.gd's
## matching comment for why this is explicit belt-and-suspenders, not a reachable-today gap).
var modal_gate: RefCounted = null

var _player: Node = null
var _structures: Node = null
## The shippable crop ids plus a trailing "" sentinel for the "Leave" row.
var _row_ids: Array[String] = []
var _row_labels: Array[Label] = []
var _index := 0


func _ready() -> void:
	box.visible = false
	_row_ids = ShippingDB.shippable_ids().duplicate()
	_row_ids.append("")  # trailing Leave row
	for child in rows_box.get_children():
		_row_labels.append(child as Label)
	info_label.text = INFO_TEXT


## Wired by main.gd, mirroring store_ui.bind() — the player reference for inventory reads/
## removals, plus structures (the box contents' owner, see structures.gd's shipping section).
func bind(player: Node, structures: Node) -> void:
	_player = player
	_structures = structures


func open_box() -> void:
	if active or _player == null or _structures == null:
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
	# Esc leaves the loading UI — same additive Stardew-convention shortcut as dialogue_ui.gd's
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


## Loads one unit of the highlighted crop, or closes on the trailing "Leave" row. Holding
## nothing of the highlighted crop is a visible refusal (status message, nothing moved) — the
## same silent-but-visible standard store_ui's insufficient-funds path set. Removal happens
## only AFTER structures accepted the deposit, so a refusal can never eat the item; with a
## positive count_of() and a crop-typed row id, add_to_shipping_box can't actually refuse, but
## the ordering keeps the invariant structural rather than incidental.
func _confirm() -> void:
	var item_id := _row_ids[_index]
	if item_id == "":
		close()
		return
	if _player.inventory.count_of(item_id) <= 0:
		status_label.text = "None to load."
		return
	if not _structures.add_to_shipping_box(item_id, 1):
		status_label.text = "The box refuses that."  # unreachable for a crop row; see above
		return
	_player.inventory.remove_item(item_id, 1)
	status_label.text = "Loaded 1 %s." % String(ItemDB.get_item(item_id).get("name", item_id))
	_refresh()


func _refresh() -> void:
	var contents: Dictionary = _structures.shipping_contents
	value_label.text = "In box: %d Cr" % ShippingDB.sale_total(contents)
	for i in _row_labels.size():
		var label := _row_labels[i]
		if i >= _row_ids.size():
			label.visible = false
			continue
		label.visible = true
		var item_id := _row_ids[i]
		if item_id == "":
			label.text = LEAVE_TEXT
		else:
			label.text = "%s — %d Cr each — held %d, in box %d" % [
				String(ItemDB.get_item(item_id).get("name", item_id)),
				ShippingDB.unit_value(item_id),
				_player.inventory.count_of(item_id),
				int(contents.get(item_id, 0)),
			]
		label.add_theme_color_override("font_color",
			ROW_SELECTED_COLOR if i == _index else ROW_COLOR)
