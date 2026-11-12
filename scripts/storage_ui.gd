extends CanvasLayer
## The storage screen (Milestone B, 2026-10-07): a chest's 27 slots above the player's pack,
## with a cursor. Confirm (Space/E/pad A) or a click moves the whole stack under the cursor to
## the other side; Esc, Tab or interacting with the chest again closes it. Opened by any storage:
## the farm's layout chest and built sheds (structures.gd's chest_toggled) and crafted chests
## (world_objects.gd's storage_opened). Replaces the old HUD chest grid, which could only show a
## chest's contents, never move anything in or out.
##
## A true modal surface (scripts/modal_gate.gd), built in code by main.gd: the player freezes
## while it's open and the clock pauses, like every other menu.

const ItemDB := preload("res://scripts/item_db.gd")
const InventoryScript := preload("res://scripts/inventory.gd")

const COLS := 9
const SLOT := 18.0
const GAP := 1.0
const PANEL_BG := Color("#ffedb1")
const PANEL_EDGE := Color("#7b5025")
const TEXT := Color("#281a0b")
const DIM := Color("#8a7a63")
const SLOT_BG := Color("#5c4a33")
const CURSOR := Color("#c5520f")

var active := false
var modal_gate: RefCounted = null

var _player: Node = null
var _storage = null  # Inventory
var _cell := Vector2i.ZERO
var _cursor := 0
var _title: Label = null
var _box: Control = null
var _hint: Label = null
const HINT := "E or click: move stack"
## Milestone D: set while a trading post's shelf is open (its structures node and top-left cell).
var _post := Vector2i(-1, -1)
var _post_structures: Node = null
var _widgets: Array = []  # 54 slot dicts: 0..26 storage, 27..53 pack


func bind(player: Node) -> void:
	_player = player


func _ready() -> void:
	layer = 20
	_build()
	_box.visible = false


## Opens `inventory` (a chest's storage) at `cell`; interacting with the same storage again
## closes it (toggle, matching the old chest grid's behaviour).
func open_storage(inventory, cell: Vector2i, title: String = "Storage") -> void:
	if active and inventory == _storage:
		close()
		return
	if active or _player == null or inventory == null:
		return
	if modal_gate != null and modal_gate.is_any_open_except(self):
		return
	_storage = inventory
	_cell = cell
	_title.text = title
	_post = Vector2i(-1, -1)
	_post_structures = null
	_hint.text = HINT
	_cursor = 27 + int(_player.inventory.selected_hotbar_index)
	if not _storage.changed.is_connected(_refresh):
		_storage.changed.connect(_refresh)
	if not _player.inventory.changed.is_connected(_refresh):
		_player.inventory.changed.connect(_refresh)
	active = true
	_box.visible = true
	_refresh()


## Milestone D: opens a trading post's shelf (docs/LIVING_SETTLEMENT.md §3). Same screen, with the
## post's markup in the title and Q to change it.
func open_post(inventory, cell: Vector2i, structures: Node, top_left: Vector2i) -> void:
	open_storage(inventory, cell, "Trading Post")
	if not active or _storage != inventory:
		return
	_post = top_left
	_post_structures = structures
	_hint.text = "E: move stack   Q: markup"
	_refresh_post_title()


func _refresh_post_title() -> void:
	if _post_structures == null:
		return
	var clerk: bool = _post_structures.clerk_check.is_valid() and bool(_post_structures.clerk_check.call(_post))
	_title.text = "Trading Post — " + _post_structures.post_summary(_post_structures.post_markup(_post), clerk)


func close() -> void:
	if not active:
		return
	active = false
	_box.visible = false
	if _storage != null and _storage.changed.is_connected(_refresh):
		_storage.changed.disconnect(_refresh)
	Audio.play_sfx("chest_close", -6.0)
	_storage = null


func storage() -> Variant:
	return _storage


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_inventory"):
		close()
	elif event.is_action_pressed("move_right"):
		_move(1, 0)
	elif event.is_action_pressed("move_left"):
		_move(-1, 0)
	elif event.is_action_pressed("move_down"):
		_move(0, 1)
	elif event.is_action_pressed("move_up"):
		_move(0, -1)
	elif event.is_action_pressed("use_tool") or event.is_action_pressed("interact"):
		transfer_at(_cursor)
	elif event.is_action_pressed("build_cycle") and _post_structures != null:
		_post_structures.cycle_post_markup(_post)
		Audio.play_sfx("ui_hover", -8.0)
		_refresh_post_title()


func _move(dx: int, dy: int) -> void:
	_cursor = cursor_after(_cursor, dx, dy)
	_refresh()


## Moves the stack in slot `index` (0..26 storage, 27..53 pack) to the other side.
func transfer_at(index: int) -> bool:
	if not active:
		return false
	var from_storage := index < 27
	var from_inv = _storage if from_storage else _player.inventory
	var to_inv = _player.inventory if from_storage else _storage
	var moved := transfer(from_inv, index if from_storage else index - 27, to_inv)
	if moved:
		Audio.play_sfx("pickup", -6.0, 0.06)
	else:
		Audio.play_sfx("ui_error", -8.0)
	_refresh()
	return moved


## -- Pure rules (unit tested) --

## Moves one slot's whole stack from `from_inv` into `to_inv` (merging into matching stacks,
## then empty slots). Tool instances move whole into an empty slot. Whatever doesn't fit stays.
## True if anything moved.
static func transfer(from_inv, index: int, to_inv) -> bool:
	var slot: Dictionary = from_inv.get_slot(index)
	if slot.is_empty():
		return false
	if slot.has("durability"):
		for i in to_inv.slots.size():
			if (to_inv.get_slot(i) as Dictionary).is_empty():
				to_inv.set_slot(i, slot)
				from_inv.set_slot(index, {})
				return true
		return false
	var item := String(slot.get("item_id", ""))
	var count := int(slot.get("count", 0))
	var leftover: int = to_inv.add_item(item, count)
	if leftover >= count:
		return false
	from_inv.set_slot(index, {} if leftover <= 0 else {"item_id": item, "count": leftover})
	return true


## Cursor movement over the two stacked 3x9 grids (54 cells): left/right wrap within a row,
## up/down walk the 6 rows and wrap top to bottom.
static func cursor_after(cursor: int, dx: int, dy: int) -> int:
	var row := cursor / COLS
	var col := cursor % COLS
	col = wrapi(col + dx, 0, COLS)
	row = wrapi(row + dy, 0, 6)
	return row * COLS + col


## -- View --

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_box = Control.new()
	var width := COLS * SLOT + (COLS - 1) * GAP + 16.0
	var height := 2 * (3 * SLOT + 2 * GAP) + 44.0
	_box.position = Vector2((320.0 - width) / 2.0, (192.0 - height) / 2.0 - 6.0)
	_box.size = Vector2(width, height)
	root.add_child(_box)
	var edge := ColorRect.new()
	edge.color = PANEL_EDGE
	edge.size = _box.size
	_box.add_child(edge)
	var bg := ColorRect.new()
	bg.color = PANEL_BG
	bg.position = Vector2(2, 2)
	bg.size = _box.size - Vector2(4, 4)
	_box.add_child(bg)
	_title = _text("Storage", Vector2(8, 3), TEXT)
	var y := 13.0
	for i in 27:
		_widgets.append(_slot_widget(Vector2(8 + (i % COLS) * (SLOT + GAP), y + (i / COLS) * (SLOT + GAP)), i))
	y += 3 * (SLOT + GAP) + 2.0
	_text("Your pack", Vector2(8, y), DIM)
	y += 10.0
	for i in 27:
		_widgets.append(_slot_widget(Vector2(8 + (i % COLS) * (SLOT + GAP), y + (i / COLS) * (SLOT + GAP)), 27 + i))
	y += 3 * (SLOT + GAP)
	_hint = _text(HINT, Vector2(8, y), DIM)
	var settings := get_node_or_null("/root/Settings")
	var close_hint := _text("%s: close" % (String(settings.back_prompt()) if settings != null else "Esc"),
		Vector2(8, y), DIM)
	close_hint.size.x = width - 16.0
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _text(text: String, pos: Vector2, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(label)
	return label


func _slot_widget(pos: Vector2, index: int) -> Dictionary:
	var frame := ColorRect.new()
	frame.position = pos
	frame.size = Vector2(SLOT, SLOT)
	frame.color = Color(0, 0, 0, 0)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_cursor = index
			transfer_at(index))
	_box.add_child(frame)
	var bg := ColorRect.new()
	bg.position = Vector2(1, 1)
	bg.size = Vector2(SLOT - 2, SLOT - 2)
	bg.color = SLOT_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bg)
	var icon := TextureRect.new()
	icon.position = Vector2(1, 1)
	icon.size = Vector2(16, 16)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	var count := Label.new()
	count.position = Vector2(0, SLOT - 9)
	count.size = Vector2(SLOT - 1, 8)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_color_override("font_color", Color("#ffedb1"))
	count.add_theme_color_override("font_outline_color", TEXT)
	count.add_theme_constant_override("outline_size", 2)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(count)
	return {"frame": frame, "icon": icon, "count": count}


func _refresh() -> void:
	if not active or _storage == null:
		return
	for i in _widgets.size():
		var w: Dictionary = _widgets[i]
		var slot: Dictionary = _storage.get_slot(i) if i < 27 else _player.inventory.get_slot(i - 27)
		(w["frame"] as ColorRect).color = CURSOR if i == _cursor else Color(0, 0, 0, 0)
		var icon: TextureRect = w["icon"]
		var count: Label = w["count"]
		if slot.is_empty():
			icon.texture = null
			count.text = ""
			continue
		var item := String(slot.get("item_id", ""))
		var path := ItemDB.icon_path(item, int(slot.get("tier", 1)))
		icon.texture = load(path) if path != "" and ResourceLoader.exists(path) else null
		var n := int(slot.get("count", 1))
		count.text = str(n) if n > 1 and not slot.has("durability") else ""
