extends CanvasLayer
## HUD: day number, in-game clock, energy bar (Phase 2), plus Phase 3's hotbar (always visible,
## bottom-center — the 9 slots number keys 1-9 select) and a toggleable full-inventory grid
## (the "I" key, showing the remaining 18 backpack slots above the hotbar).
##
## Lives on a CanvasLayer so the day/night CanvasModulate in main.tscn never darkens it.
## Listens to the DayManager autoload for time, and to the player's energy_changed signal
## (bound by main.gd) for the energy bar. Art: PixelLab-generated scavenged-metal panel and
## bar frame (art/ui/), with the bar fill drawn as flat palette colors (lamplight gold
## #e8c268 on warm near-black) so the readout stays legible at the 320x192 viewport.
##
## Slot widgets are built procedurally from Inventory.TOTAL_SLOTS rather than hand-authored in
## the .tscn (27 near-identical widgets would be pure boilerplate there) — same "generate from
## data" spirit as scripts/test_map.gd painting tiles from TestMapLayout.

const Inventory := preload("res://scripts/inventory.gd")
const ItemDB := preload("res://scripts/item_db.gd")

const HOTBAR_SIZE := Inventory.HOTBAR_SIZE
const SLOT_SIZE := 14.0
const SELECTED_COLOR := Color("#e8c268")  # lamplight gold — GDD.md §9 settlement anchor palette
const EMPTY_BG_COLOR := Color(0.141, 0.102, 0.063, 0.75)  # warm near-black, per §9

@onready var day_label: Label = %DayLabel
@onready var clock_label: Label = %ClockLabel
@onready var energy_fill: ProgressBar = %EnergyFill
@onready var hotbar_row: HBoxContainer = %Hotbar
@onready var inventory_grid: GridContainer = %InventoryGrid

var inventory: Inventory = null
## Parallel to inventory.slots — one widget dict per slot: {frame, bg, icon, label}.
var _slot_widgets: Array = []


func _ready() -> void:
	DayManager.time_changed.connect(_on_time_changed)
	_on_time_changed(DayManager.day, DayManager.minutes_into_day)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		inventory_grid.visible = not inventory_grid.visible


## Called by main.gd once the player exists.
func bind_player(player: Node) -> void:
	player.energy_changed.connect(_on_energy_changed)
	_on_energy_changed(player.energy, player.max_energy)


## Called by main.gd once the player's Inventory exists. Builds the slot widgets once, then
## keeps them in sync via Inventory's signals.
func bind_inventory(inv: Inventory) -> void:
	inventory = inv
	_build_slot_widgets()
	inventory.changed.connect(_refresh_all_slots)
	inventory.hotbar_selection_changed.connect(func(_index: int) -> void: _refresh_all_slots())
	_refresh_all_slots()


func _build_slot_widgets() -> void:
	_slot_widgets.clear()
	for i in Inventory.TOTAL_SLOTS:
		var parent: Control = hotbar_row if i < HOTBAR_SIZE else inventory_grid
		_slot_widgets.append(_make_slot_widget(parent))


func _make_slot_widget(parent: Control) -> Dictionary:
	var frame := ColorRect.new()
	frame.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	frame.color = Color.TRANSPARENT
	parent.add_child(frame)

	var bg := ColorRect.new()
	bg.position = Vector2(1, 1)
	bg.size = Vector2(SLOT_SIZE - 2, SLOT_SIZE - 2)
	bg.color = EMPTY_BG_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bg)

	var icon := TextureRect.new()
	icon.position = Vector2(2, 2)
	icon.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)

	var label := Label.new()
	label.position = Vector2(0, SLOT_SIZE - 7)
	label.size = Vector2(SLOT_SIZE - 1, 7)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 6)
	label.add_theme_color_override("font_color", Color(0.914, 0.863, 0.698))
	label.add_theme_color_override("font_outline_color", Color(0.141, 0.102, 0.063))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(label)

	return {"frame": frame, "bg": bg, "icon": icon, "label": label}


func _refresh_all_slots() -> void:
	for i in _slot_widgets.size():
		_refresh_slot(i)


func _refresh_slot(index: int) -> void:
	var widget: Dictionary = _slot_widgets[index]
	var slot: Dictionary = inventory.get_slot(index)
	var frame: ColorRect = widget["frame"]
	var bg: ColorRect = widget["bg"]
	var icon: TextureRect = widget["icon"]
	var label: Label = widget["label"]

	var selected := index < HOTBAR_SIZE and index == inventory.selected_hotbar_index
	frame.color = SELECTED_COLOR if selected else Color.TRANSPARENT

	if slot.is_empty():
		bg.color = EMPTY_BG_COLOR
		icon.texture = null
		label.text = ""
		return

	var item_id := String(slot.get("item_id", ""))
	var item_def := ItemDB.get_item(item_id)
	var icon_path := String(item_def.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
		bg.color = EMPTY_BG_COLOR
	else:
		icon.texture = null
		bg.color = Color(String(item_def.get("placeholder_color", "#8c8478")))

	if slot.has("durability"):
		label.text = str(int(slot["durability"]))
	elif int(slot.get("count", 1)) > 1:
		label.text = str(int(slot["count"]))
	else:
		label.text = ""


func _on_time_changed(day: int, minutes_into_day: float) -> void:
	# time_changed fires every frame; only touch the labels when the visible text changes.
	var day_text := "Day %d" % day
	if day_label.text != day_text:
		day_label.text = day_text
	var clock := DayManager.format_clock(minutes_into_day)
	if clock_label.text != clock:
		clock_label.text = clock


func _on_energy_changed(current: float, max_energy: float) -> void:
	energy_fill.max_value = max_energy
	energy_fill.value = current
