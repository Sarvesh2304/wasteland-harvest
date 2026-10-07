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
## Rows (2026-10-07) are the shippable items the player is CARRYING, in backpack order, plus
## Leave — with ~100 sellable items in the catalogue a fixed roster would be a wall of zeros.
## Confirming loads the whole carried amount of that item at once (Stardew's bin takes stacks).
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
const INFO_TEXT := "Everything in the box sells overnight. Credits arrive in the morning."

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
	_row_ids = [""]
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
	_rebuild_rows()
	_refresh()


## Carried shippable items in backpack order, plus the trailing Leave row ("").
func _rebuild_rows() -> void:
	_row_ids.clear()
	for slot in _player.inventory.slots:
		var item_id := String((slot as Dictionary).get("item_id", ""))
		if item_id != "" and ShippingDB.is_shippable(item_id) and not _row_ids.has(item_id):
			_row_ids.append(item_id)
	_row_ids.append("")
	_index = clampi(_index, 0, _row_ids.size() - 1)


func close() -> void:
	if active:
		Audio.play_sfx("chest_close", -6.0)
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
		Audio.play_sfx("ui_hover", -8.0)
		_refresh()
	elif event.is_action_pressed("move_down"):
		_index = wrapi(_index + 1, 0, _row_ids.size())
		status_label.text = ""
		Audio.play_sfx("ui_hover", -8.0)
		_refresh()
	elif event.is_action_pressed("use_tool"):
		_confirm()


## Loads everything carried of the highlighted item, or closes on the trailing "Leave" row.
## Removal happens only AFTER structures accepted the deposit, so a refusal can never eat items.
func _confirm() -> void:
	var item_id := _row_ids[_index]
	if item_id == "":
		close()
		return
	var count: int = _player.inventory.count_of(item_id)
	if count <= 0:
		status_label.text = "None to load."
		Audio.play_sfx("ui_error", -6.0)
		return
	if not _structures.add_to_shipping_box(item_id, count):
		status_label.text = "The box refuses that."
		Audio.play_sfx("ui_error", -6.0)
		return
	_player.inventory.remove_item(item_id, count)
	Audio.play_sfx("ship", -3.0)
	status_label.text = "Loaded %d %s." % [count, String(ItemDB.get_item(item_id).get("name", item_id))]
	_rebuild_rows()
	_refresh()


func _refresh() -> void:
	var contents: Dictionary = _structures.shipping_contents
	value_label.text = "In box: %d Cr" % ShippingDB.sale_total(contents)
	var window := _row_labels.size()
	var start := clampi(_index - window / 2, 0, maxi(_row_ids.size() - window, 0))
	for slot in window:
		var label := _row_labels[slot]
		var i := start + slot
		if i >= _row_ids.size():
			label.visible = false
			continue
		label.visible = true
		var item_id := _row_ids[i]
		if item_id == "":
			label.text = LEAVE_TEXT
		else:
			var held: int = _player.inventory.count_of(item_id)
			label.text = "%s x%d — %d Cr" % [
				String(ItemDB.get_item(item_id).get("name", item_id)), held,
				ShippingDB.unit_value(item_id) * held,
			]
		label.add_theme_color_override("font_color",
			ROW_SELECTED_COLOR if i == _index else ROW_COLOR)
