extends CanvasLayer
## The in-game tabbed menu (playtest UX gap, 2026-07-12 — "there is no in-game menu at all"):
## pressing "toggle_inventory" (Tab) now opens THIS full menu, defaulting to the Inventory tab —
## Stardew's E-key convention — instead of the bare HUD backpack grid it used to flip.
## scripts/hud.gd's old toggle branch is gone; the grid itself lives on as this menu's
## Inventory-tab content (see bind() below — re-hosted, not rebuilt).
##
## Tabs (cycled with "build_cycle"/Q, the same browse key build mode uses — one direction only,
## deliberately: no unused input action exists to pair as "previous tab", and adding a new
## binding for a 3-tab ring that wraps in at most 2 presses would bloat the Controls list this
## menu itself documents; revisit if the tab count ever grows):
##   1. INVENTORY — the HUD's existing 18-slot backpack GridContainer, re-parented in here at
##      bind() time. All widget building/painting stays in scripts/hud.gd, driven by the same
##      Inventory signals as always; only the node's parent changed.
##   2. BUILD — a read-only browse of scripts/building_db.gd's full catalog with each entry's
##      resource cost and live can-you-afford-it state. Affordability is BuildGrid.can_afford —
##      the exact function scripts/builder.gd's placement preview uses — fed the same
##      inventory.count_of() counts; the cost string is builder.gd's own cost_text(). Browse
##      only: placing still happens through the existing B-key build mode in the world.
##   3. CONTROLS — a static key-reference list (see CONTROLS_REFERENCE's sync warning).
## Plus an always-visible footer action on every tab: Save & Return to Title ("use_tool"/Space,
## guarded by a press-again-to-confirm arm — the same two-press guard title_screen.gd's slot
## delete uses — so a stray Space can't dump the player to the title mid-thought). The save is
## GameState.save_game() with the player's own world refs: the IDENTICAL call player.gd's
## bed/pass-out _end_day() makes (and tools/runtime_smoke.gd stage 81's mid-session save
## already exercises) — no second save codepath. Unlike _end_day() it does NOT advance the
## day or refill energy: quitting is not sleeping.
##
## A true modal surface, exactly like dialogue/store/shipping (NOT like the passive overlay the
## old grid was): registered with scripts/modal_gate.gd by main.gd, so build mode can't engage
## underneath it (and vice versa), main.gd's per-frame poll pauses DayManager time while it's
## open for free, and player.gd's _in_menu() freezes movement/tool polling. "ui_cancel" (Esc)
## or Tab again closes it, per every other modal's convention. Keyboard-only, reusing existing
## input actions — no new project.godot entries.

const BuildGrid := preload("res://scripts/build_grid.gd")
const BuildingDB := preload("res://scripts/building_db.gd")
const Builder := preload("res://scripts/builder.gd")

const TAB_NAMES: Array[String] = ["INVENTORY", "BUILD", "CONTROLS"]
const TAB_INVENTORY := 0
const TAB_BUILD := 1
const TAB_CONTROLS := 2

## Same modal palette as store_ui.gd/title_screen.gd's lists.
const TAB_ACTIVE_COLOR := Color("#c5520f")     # rust red — the established highlight
const TAB_INACTIVE_COLOR := Color("#7b5025")   # worn wood (dark) — unselected
const ROW_COLOR := Color("#281a0b")            # warm near-black body text on the cream panel
const AFFORDABLE_COLOR := Color("#7b5025")     # normal row — nothing to warn about
const UNAFFORDABLE_COLOR := Color("#c5520f")   # rust red — missing materials
const QUIT_ARMED_COLOR := Color("#d13b27")     # warning red, same as title_screen's delete arm
const QUIT_IDLE_COLOR := Color("#7b5025")

const QUIT_HINT := "Space — Save & Return to Title"
const QUIT_HINT_ARMED := "Space AGAIN — Save & Return to Title"

## HAND-MAINTAINED controls reference. There is NO automated sync between this table and
## project.godot's [input] bindings — if a binding ever changes there, the "keys" strings here
## MUST be updated by hand, or this screen becomes worse than no controls screen at all.
## tests/test_menu_screen.gd only guards the weaker half (every action named here still exists
## in the InputMap), which catches renamed/removed actions but NOT rebound keys.
## Current per project.godot: move WASD+arrows; use_tool Space/E; hotbar 1-9;
## toggle_inventory Tab; build_toggle B; build_cycle Q; ui_cancel is Godot's built-in Esc.
const CONTROLS_REFERENCE := [
	{"keys": "W/A/S/D or Arrows", "does": "Move",
		"actions": ["move_up", "move_down", "move_left", "move_right"]},
	{"keys": "Space or E", "does": "Use tool / interact / confirm",
		"actions": ["use_tool"]},
	{"keys": "1-9", "does": "Select hotbar slot",
		"actions": ["hotbar_slot_1", "hotbar_slot_9"]},
	{"keys": "B", "does": "Enter/leave build mode",
		"actions": ["build_toggle"]},
	{"keys": "Q", "does": "Cycle blueprint / menu tab",
		"actions": ["build_cycle"]},
	{"keys": "Tab", "does": "Open/close this menu",
		"actions": ["toggle_inventory"]},
	{"keys": "Esc", "does": "Close menu / back out",
		"actions": ["ui_cancel"]},
]

@onready var box: Control = %Box
@onready var tab_row: HBoxContainer = %TabRow
@onready var inventory_tab: Control = %InventoryTab
@onready var build_tab: Control = %BuildTab
@onready var controls_tab: Control = %ControlsTab
@onready var build_rows: VBoxContainer = %BuildRows
@onready var controls_rows: VBoxContainer = %ControlsRows
@onready var quit_label: Label = %QuitLabel

## True while the menu is open — the modal gate and player.gd's _in_menu() both read this
## directly, the same shape as dialogue_ui/store_ui/builder's `active`.
var active := false
## The shared modal mutual-exclusion registry (scripts/modal_gate.gd), assigned by main.gd —
## open_menu() refuses while any other modal surface is open, per modal_gate.gd's recipe.
var modal_gate: RefCounted = null

var tab_index := TAB_INVENTORY

var _player: Node = null
var _inventory_grid: Control = null
var _tab_labels: Array[Label] = []
var _build_row_labels: Array[Label] = []
## Press-again-to-confirm state for Save & Return to Title (see class doc).
var _quit_armed := false


func _ready() -> void:
	box.visible = false
	for name_text in TAB_NAMES:
		var label := Label.new()
		label.text = name_text
		tab_row.add_child(label)
		_tab_labels.append(label)
	for id in BuildingDB.ids():
		var label := Label.new()
		build_rows.add_child(label)
		_build_row_labels.append(label)
	# Controls rows are static text — built once here, never refreshed.
	for line in controls_lines():
		var label := Label.new()
		label.text = line
		label.add_theme_color_override("font_color", ROW_COLOR)
		controls_rows.add_child(label)


## Wired by main.gd once the player and HUD exist. Adopts the HUD's backpack GridContainer as
## the Inventory tab's content: hud.gd built (and keeps painting) the slot widgets through its
## captured node reference, which reparenting leaves intact — the grid logic is genuinely
## re-hosted, not duplicated. Its old always-hidden HUD visibility flips to always-visible here;
## the tab container's own visibility now decides when it shows.
func bind(player: Node, inventory_grid: Control) -> void:
	_player = player
	_inventory_grid = inventory_grid
	if inventory_grid.get_parent() != null:
		inventory_grid.get_parent().remove_child(inventory_grid)
	inventory_tab.add_child(inventory_grid)
	inventory_grid.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		if active:
			close()
		else:
			open_menu()
	elif not active:
		return
	elif event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("build_cycle"):
		tab_index = next_tab(tab_index)
		_quit_armed = false  # navigating away disarms, like the title screen's delete guard
		_refresh()
	elif event.is_action_pressed("use_tool"):
		_quit_pressed()


## Opening is refused while any other modal surface is open (modal_gate.gd's standard recipe);
## closing below is never gated. Always lands on the Inventory tab, Stardew-style — the menu
## key means "check my stuff", not "wherever I left off".
func open_menu() -> void:
	if active or _player == null:
		return
	if modal_gate != null and modal_gate.is_any_open_except(self):
		return
	active = true
	tab_index = TAB_INVENTORY
	_quit_armed = false
	box.visible = true
	_refresh()


func close() -> void:
	active = false
	_quit_armed = false
	box.visible = false


## First press arms; second press saves and leaves. Any tab cycle, close, or re-open disarms.
func _quit_pressed() -> void:
	if not _quit_armed:
		_quit_armed = true
		_refresh()
		return
	_save_and_return_to_title()


## The real save, then the title screen. GameState.save_game with the player's zones dict is
## byte-for-byte the bed/pass-out save path (player.gd's _end_day) minus the day advance; the
## same empty-dict guard as _end_day keeps a not-fully-bound player (tests) from crashing. The
## scene change mirrors title_screen.gd's own change_scene_to_file hops, and main.gd's
## _exit_tree already guarantees the paused clock can't leak into the next boot.
func _save_and_return_to_title() -> void:
	if not _player.zones.is_empty():
		GameState.save_game(_player, _player.zones)
	close()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func _refresh() -> void:
	for i in _tab_labels.size():
		_tab_labels[i].add_theme_color_override("font_color",
			TAB_ACTIVE_COLOR if i == tab_index else TAB_INACTIVE_COLOR)
	inventory_tab.visible = tab_index == TAB_INVENTORY
	build_tab.visible = tab_index == TAB_BUILD
	controls_tab.visible = tab_index == TAB_CONTROLS
	if tab_index == TAB_BUILD:
		_refresh_build_rows()
	quit_label.text = quit_hint(_quit_armed)
	quit_label.add_theme_color_override("font_color",
		QUIT_ARMED_COLOR if _quit_armed else QUIT_IDLE_COLOR)


## Repaints the Build tab from the live inventory. Refreshed on every _refresh() rather than
## signal-driven: the inventory can't change while the menu is open (the player is frozen and
## time is paused), so open/tab-switch is the only moment the answer can differ.
func _refresh_build_rows() -> void:
	var rows := catalog_rows(BuildingDB.ids(), _have_counts())
	for i in _build_row_labels.size():
		var row: Dictionary = rows[i]
		_build_row_labels[i].text = build_row_text(row)
		_build_row_labels[i].add_theme_color_override("font_color",
			AFFORDABLE_COLOR if row["affordable"] else UNAFFORDABLE_COLOR)


## Owned counts for every item any catalog entry costs — the same inventory.count_of() gather
## builder.gd's _can_afford() does per-building, unioned across the catalog so the pure
## catalog_rows() below can stay a plain Dictionary-in function.
func _have_counts() -> Dictionary:
	var have := {}
	for id in BuildingDB.ids():
		for item_id in BuildingDB.cost(id):
			have[item_id] = _player.inventory.count_of(String(item_id))
	return have


## -- Pure display math (headlessly unit-tested in tests/test_menu_screen.gd) --

## Forward-only tab ring (see class doc for why one direction) — the same wrap math build
## mode's catalog cycling uses.
static func next_tab(current: int) -> int:
	return BuildGrid.wrap_index(current, 1, TAB_NAMES.size())


## One row per catalog id: display name, builder.gd's own cost string, and affordability via
## BuildGrid.can_afford — the exact math the placement preview's green/red already runs, never
## a reimplementation. `have` maps item_id -> owned count (missing keys read as 0).
static func catalog_rows(ids: Array[String], have: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id in ids:
		rows.append({
			"id": id,
			"name": BuildingDB.display_name(id),
			"cost_text": Builder.cost_text(id),
			"affordable": BuildGrid.can_afford(have, BuildingDB.cost(id)),
		})
	return rows


## Text is the affordability signal alongside color (color alone would be lost on a screenshot
## skim — and eventually on colorblind players).
static func build_row_text(row: Dictionary) -> String:
	var suffix := "" if bool(row["affordable"]) else "  — missing materials"
	return "%s — %s%s" % [String(row["name"]), String(row["cost_text"]), suffix]


static func controls_lines() -> Array[String]:
	var lines: Array[String] = []
	for entry in CONTROLS_REFERENCE:
		lines.append("%s — %s" % [String(entry["keys"]), String(entry["does"])])
	return lines


static func quit_hint(armed: bool) -> String:
	return QUIT_HINT_ARMED if armed else QUIT_HINT
