extends CanvasLayer
## HUD: day number, in-game clock, energy bar (Phase 2), plus Phase 3's hotbar (always visible,
## bottom-center — the 9 slots number keys 1-9 select) and a toggleable full-inventory grid
## (the "I" key, showing the remaining 18 backpack slots above the hotbar). Phase 4 adds a
## second, independently-toggled grid for the farmland storage chest's own Inventory instance
## (see scripts/structures.gd) — walking up to the chest and interacting opens/closes it.
##
## Lives on a CanvasLayer so the day/night CanvasModulate in main.tscn never darkens it.
## Listens to the DayManager autoload for time, and to the player's energy_changed signal
## (bound by main.gd) for the energy bar. Art: PixelLab-generated scavenged-metal panel and
## bar frame (art/ui/), with the bar fill drawn as flat palette colors (lamplight gold
## #ffc948 on warm near-black) so the readout stays legible at the 320x192 viewport.
##
## Slot widgets are built procedurally from Inventory.TOTAL_SLOTS rather than hand-authored in
## the .tscn (27 near-identical widgets would be pure boilerplate there) — same "generate from
## data" spirit as scripts/test_map.gd painting tiles from a layout's ASCII grid.
##
## Phase 4 scope note (documented, not an oversight): the chest UI displays and toggles a real
## second Inventory instance, satisfying ROADMAP.md's "opens a second Inventory instance... via
## a small UI" — but this session does not add item-transfer UX (drag/move-in) between the
## player's inventory and the chest's. That's a natural, low-risk follow-up for a later session;
## keeping this session's chest to display/toggle only matches its "keep the UI minimal" scope
## note and avoids inventing new input conventions this codebase doesn't have yet (no mouse
## drag-and-drop exists anywhere else in the UI).
##
## Phase 5 Stage 2 adds a small Credits plaque (top-left, mirroring the day/clock plaque's own
## top-right positioning) bound to the player's credits_changed signal — the same bind-a-signal-
## to-a-label shape as the energy bar, just without a fill/bar (a plain number reads fine for a
## value this small; a full bar would over-dramatize what's usually a two-digit balance).

const Inventory := preload("res://scripts/inventory.gd")
const ItemDB := preload("res://scripts/item_db.gd")

const HOTBAR_SIZE := Inventory.HOTBAR_SIZE
const SLOT_SIZE := 14.0
const SELECTED_COLOR := Color("#ffc948")  # lamplight gold — GDD.md §9 settlement anchor palette
const EMPTY_BG_COLOR := Color("#281a0b", 0.75)  # warm near-black, per §9

@onready var day_label: Label = %DayLabel
@onready var clock_label: Label = %ClockLabel
@onready var energy_fill: ProgressBar = %EnergyFill
@onready var credits_label: Label = %CreditsLabel
@onready var hotbar_row: HBoxContainer = %Hotbar
@onready var inventory_grid: GridContainer = %InventoryGrid
@onready var chest_grid: GridContainer = %ChestGrid
@onready var save_notice: Label = %SaveNotice

var inventory: Inventory = null
## Parallel to inventory.slots — one widget dict per slot: {frame, bg, icon, label}.
var _slot_widgets: Array = []

## Phase 4 chest UI state: whichever Inventory scripts/structures.gd last handed us via
## toggle_chest_ui(), and its own parallel widget array (same shape as _slot_widgets above).
var _chest_inventory: Inventory = null
var _chest_slot_widgets: Array = []


## The "WORLD SAVED" notice's timing (Phase 4 Stage 3): fully visible for HOLD seconds, then
## fades out over FADE seconds. Brief-but-unmissable; total ~2.4s.
const SAVE_NOTICE_HOLD := 1.6
const SAVE_NOTICE_FADE := 0.8

var _save_notice_tween: Tween = null


func _ready() -> void:
	DayManager.time_changed.connect(_on_time_changed)
	_on_time_changed(DayManager.day, DayManager.minutes_into_day)
	# Phase 4 Stage 3: transient "WORLD SAVED" notice, driven by the GameState autoload's
	# game_saved signal (fired from the bed's auto-save) — the save system stays UI-agnostic.
	GameState.game_saved.connect(_on_game_saved)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		inventory_grid.visible = not inventory_grid.visible


## Called by main.gd once the player exists.
func bind_player(player: Node) -> void:
	player.energy_changed.connect(_on_energy_changed)
	_on_energy_changed(player.energy, player.max_energy)
	player.credits_changed.connect(_on_credits_changed)
	_on_credits_changed(player.credits)


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
	# Count/durability text inherits the project theme's pixel font at its native 8px base size
	# (art/ui/ui_theme.tres) — no per-node size override, so it stays crisp at the 4x stretch.
	label.position = Vector2(0, SLOT_SIZE - 8)
	label.size = Vector2(SLOT_SIZE - 1, 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_color_override("font_color", Color("#ffedb1"))
	label.add_theme_color_override("font_outline_color", Color("#281a0b"))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(label)

	return {"frame": frame, "bg": bg, "icon": icon, "label": label}


func _refresh_all_slots() -> void:
	for i in _slot_widgets.size():
		_refresh_slot(i)


func _refresh_slot(index: int) -> void:
	var selected := index < HOTBAR_SIZE and index == inventory.selected_hotbar_index
	_paint_slot(_slot_widgets[index], inventory.get_slot(index), selected)


## Shared slot-painting logic (Phase 2/3's original single-inventory HUD, generalized in Phase 4
## so the chest UI below can reuse it verbatim for a second, independent Inventory instance).
func _paint_slot(widget: Dictionary, slot: Dictionary, selected: bool) -> void:
	var frame: ColorRect = widget["frame"]
	var bg: ColorRect = widget["bg"]
	var icon: TextureRect = widget["icon"]
	var label: Label = widget["label"]

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


## -- Phase 4: farmland storage chest UI --

## Called by main.gd (wired to scripts/structures.gd's chest_toggled signal) whenever the player
## interacts with the chest. Re-interacting while it's already open closes it again (a simple
## toggle, matching the "I" key's inventory_grid behaviour above) rather than needing a separate
## close affordance.
func toggle_chest_ui(inv: Inventory, _cell: Vector2i) -> void:
	if _chest_inventory == inv and chest_grid.visible:
		chest_grid.visible = false
		return
	if _chest_inventory != inv:
		_chest_inventory = inv
		if _chest_slot_widgets.is_empty():
			_build_chest_slot_widgets()
		if not inv.changed.is_connected(_refresh_all_chest_slots):
			inv.changed.connect(_refresh_all_chest_slots)
		_refresh_all_chest_slots()
	chest_grid.visible = true


func _build_chest_slot_widgets() -> void:
	_chest_slot_widgets.clear()
	for i in Inventory.TOTAL_SLOTS:
		_chest_slot_widgets.append(_make_slot_widget(chest_grid))


func _refresh_all_chest_slots() -> void:
	for i in _chest_slot_widgets.size():
		_paint_slot(_chest_slot_widgets[i], _chest_inventory.get_slot(i), false)


## Shows the "WORLD SAVED" notice (16px — the theme's one sanctioned larger size, per
## art/ui/README.md's integer-multiple font convention; colors set in hud.tscn to the HUD's
## established lamplight-gold-on-warm-black) and fades it out. A save landing while the
## previous notice is still fading restarts the sequence from fully visible.
func _on_game_saved() -> void:
	if _save_notice_tween != null:
		_save_notice_tween.kill()
	save_notice.modulate = Color.WHITE
	save_notice.visible = true
	_save_notice_tween = create_tween()
	_save_notice_tween.tween_interval(SAVE_NOTICE_HOLD)
	_save_notice_tween.tween_property(save_notice, "modulate:a", 0.0, SAVE_NOTICE_FADE)
	_save_notice_tween.tween_callback(func() -> void: save_notice.visible = false)


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


func _on_credits_changed(current: int) -> void:
	credits_label.text = "%d Cr" % current
