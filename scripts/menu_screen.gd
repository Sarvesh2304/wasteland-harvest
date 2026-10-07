extends CanvasLayer
## The in-game tabbed menu (playtest UX gap, 2026-07-12 — "there is no in-game menu at all"):
## pressing "toggle_inventory" (Tab) now opens THIS full menu, defaulting to the Inventory tab —
## Stardew's E-key convention — instead of the bare HUD backpack grid it used to flip.
## scripts/hud.gd's old toggle branch is gone; the grid itself lives on as this menu's
## Inventory-tab content (see bind() below — re-hosted, not rebuilt).
##
## Tabs (cycled with "build_cycle"/Q, the same browse key build mode uses — one direction only,
## deliberately: no unused input action exists to pair as "previous tab", and adding a new
## binding for a four-tab ring would bloat the Controls list this
## menu itself documents; revisit if the tab count ever grows):
##   1. INVENTORY — the HUD's existing 18-slot backpack GridContainer, re-parented in here at
##      bind() time. All widget building/painting stays in scripts/hud.gd, driven by the same
##      Inventory signals as always; only the node's parent changed.
##   2. BUILD — a read-only browse of scripts/building_db.gd's full catalog with each entry's
##      resource cost and live can-you-afford-it state. Affordability is BuildGrid.can_afford —
##      the exact function scripts/builder.gd's placement preview uses — fed the same
##      inventory.count_of() counts; the cost string is builder.gd's own cost_text(). Browse
##      only: placing still happens through the existing B-key build mode in the world.
##   3. ASSIGNMENTS — the live settler roster. Each row is an OptionButton whose choices are
##      completed, staffable buildings; choosing "Unassigned" releases the settler.
##   4. CONTROLS — a static key-reference list (see CONTROLS_REFERENCE's sync warning).
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
const RecipeDB := preload("res://scripts/recipe_db.gd")
const Crafting := preload("res://scripts/crafting.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const SkillsScript := preload("res://scripts/skills.gd")
const BuildingDB := preload("res://scripts/building_db.gd")
const Builder := preload("res://scripts/builder.gd")

## 2026-10-07 Milestone B: CRAFT (the recipe book, scripts/crafting.gd) and SKILLS tabs join the
## ring, right after the inventory. Tabs cycle forward with Q, and either way with Left/Right
## or the pad's shoulder buttons.
const TAB_NAMES: Array[String] = ["INVENTORY", "CRAFT", "SKILLS", "BUILD", "SETTLERS", "CONTROLS"]
const TAB_INVENTORY := 0
const TAB_CRAFT := 1
const TAB_SKILLS := 2
const TAB_BUILD := 3
const TAB_ASSIGNMENTS := 4
const TAB_CONTROLS := 5

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
## Current per project.godot (2026-10-07 input map): move WASD/arrows/stick; use_tool Space/C/
## LMB/pad X; interact E/X/F/RMB/pad A; hotbar 1-9 and LB/RB; toggle_inventory Tab/I/pad Y;
## build_toggle B; build_cycle Q; ui_cancel is Godot's built-in Esc.
const CONTROLS_REFERENCE := [
	{"keys": "W/A/S/D, Arrows, L-stick", "does": "Move",
		"actions": ["move_up", "move_down", "move_left", "move_right"]},
	{"keys": "Space, C, Left click, X", "does": "Use the held tool or item",
		"actions": ["use_tool"]},
	{"keys": "E, F, Right click, A", "does": "Interact, harvest, talk, pick up",
		"actions": ["interact"]},
	{"keys": "1-9, LB/RB", "does": "Select hotbar slot",
		"actions": ["hotbar_slot_1", "hotbar_slot_9", "hotbar_prev", "hotbar_next"]},
	{"keys": "B", "does": "Enter/leave build mode",
		"actions": ["build_toggle"]},
	{"keys": "Q", "does": "Cycle blueprint / menu tab",
		"actions": ["build_cycle"]},
	{"keys": "Tab, I, Y", "does": "Open/close this menu",
		"actions": ["toggle_inventory"]},
	{"keys": "Esc", "does": "Close menu / back out",
		"actions": ["ui_cancel"]},
]

@onready var box: Control = %Box
@onready var tab_row: HBoxContainer = %TabRow
@onready var inventory_tab: Control = %InventoryTab
@onready var build_tab: Control = %BuildTab
@onready var assignments_tab: Control = %AssignmentsTab
@onready var controls_tab: Control = %ControlsTab
@onready var build_rows: VBoxContainer = %BuildRows
@onready var assignments_rows: VBoxContainer = %AssignmentsRows
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
## Skills node (scripts/skills.gd), assigned by main.gd — recipe unlocks and the SKILLS tab.
var skills: Node = null

var _craft_tab: Control = null
var _craft_rows: VBoxContainer = null
var _craft_index := 0
var _craft_detail: Dictionary = {}
var _craft_status: Label = null
var _skills_tab: Control = null
var _skills_rows: VBoxContainer = null
const CRAFT_ROWS_VISIBLE := 7
const DIM_COLOR := Color("#8a7a63")
const LOCKED_COLOR := Color("#a8988a")
const GOOD_COLOR := Color("#3f6b2a")


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
	_build_craft_tab()
	_build_skills_tab()
	var hint := get_node_or_null("Root/Box/HintLabel") as Label
	if hint != null:
		hint.text = "Q / Left / Right: tabs    Tab / Esc: close"
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
	elif event.is_action_pressed("build_cycle") or event.is_action_pressed("move_right") \
			or event.is_action_pressed("hotbar_next"):
		tab_index = next_tab(tab_index)
		_quit_armed = false  # navigating away disarms, like the title screen's delete guard
		_refresh()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("hotbar_prev"):
		tab_index = prev_tab(tab_index)
		_quit_armed = false
		_refresh()
	elif tab_index == TAB_CRAFT and event.is_action_pressed("move_down"):
		_select_recipe(_craft_index + 1)
	elif tab_index == TAB_CRAFT and event.is_action_pressed("move_up"):
		_select_recipe(_craft_index - 1)
	elif tab_index == TAB_CRAFT and (event.is_action_pressed("use_tool") \
			or event.is_action_pressed("interact")):
		_craft_selected()
	elif event.is_action_pressed("use_tool"):
		if tab_index == TAB_ASSIGNMENTS:
			_refresh_assignments()
		else:
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
		GameState.save_game(_player, _player.zones, _player.settlers, _player.animals,
			_player.affinity)
	close()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func _refresh() -> void:
	for i in _tab_labels.size():
		_tab_labels[i].add_theme_color_override("font_color",
			TAB_ACTIVE_COLOR if i == tab_index else TAB_INACTIVE_COLOR)
	inventory_tab.visible = tab_index == TAB_INVENTORY
	_craft_tab.visible = tab_index == TAB_CRAFT
	_skills_tab.visible = tab_index == TAB_SKILLS
	build_tab.visible = tab_index == TAB_BUILD
	assignments_tab.visible = tab_index == TAB_ASSIGNMENTS
	controls_tab.visible = tab_index == TAB_CONTROLS
	if tab_index == TAB_BUILD:
		_refresh_build_rows()
	elif tab_index == TAB_ASSIGNMENTS:
		_refresh_assignments()
	elif tab_index == TAB_CRAFT:
		_refresh_craft()
	elif tab_index == TAB_SKILLS:
		_refresh_skills()
	quit_label.text = "Space / E — Craft" if tab_index == TAB_CRAFT else quit_hint(_quit_armed)
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


func _refresh_assignments() -> void:
	for child in assignments_rows.get_children():
		child.queue_free()
	if _player == null or _player.settlers == null:
		var empty_label := Label.new()
		empty_label.text = "No settler roster is available."
		assignments_rows.add_child(empty_label)
		return
	var roster: Array = _player.settlers.roster
	if roster.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No settlers yet — build Shelter Cabins and welcome a visitor."
		assignments_rows.add_child(empty_label)
		return
	for roster_index in roster.size():
		var entry: Dictionary = roster[roster_index]
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = String(entry.get("name", entry.get("id", "Settler")))
		name_label.custom_minimum_size.x = 74.0
		row.add_child(name_label)
		var picker := OptionButton.new()
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.add_item("Unassigned")
		picker.set_item_metadata(0, {})
		var options: Array[Dictionary] = _player.settlers.assignment_options_for_settler(
			String(entry.get("id", "")))
		var selected := 0
		for option in options:
			picker.add_item(String(option.get("display_name", option.get("building_id", ""))))
			var item_index := picker.item_count - 1
			picker.set_item_metadata(item_index, option)
			if _same_assignment(entry.get("assigned_building", {}), option):
				selected = item_index
		picker.select(selected)
		picker.item_selected.connect(_on_assignment_selected.bind(
			String(entry.get("id", "")), picker))
		row.add_child(picker)
		assignments_rows.add_child(row)


func _on_assignment_selected(option_index: int, settler_id: String, picker: OptionButton) -> void:
	var ref = picker.get_item_metadata(option_index)
	if ref is Dictionary and not (ref as Dictionary).is_empty():
		_player.settlers.assign_settler(settler_id, ref)
	else:
		_player.settlers.unassign_settler(settler_id)
	_refresh_assignments()


static func _same_assignment(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty():
		return false
	return String(a.get("zone_id", "")) == String(b.get("zone_id", "")) \
		and String(a.get("building_id", "")) == String(b.get("building_id", "")) \
		and Vector2i(a.get("top_left", Vector2i.ZERO)) == Vector2i(
			b.get("top_left", Vector2i.ZERO))


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


static func prev_tab(current: int) -> int:
	return BuildGrid.wrap_index(current, -1, TAB_NAMES.size())


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



## -- CRAFT tab (Milestone B, 2026-10-07) --

func _levels() -> Dictionary:
	var out := {}
	if skills != null:
		for skill in SkillsScript.SKILLS:
			out[skill] = skills.level(skill)
	return out


func _new_tab_root(tab_name: String) -> Control:
	var tab := Control.new()
	tab.name = tab_name
	tab.anchor_right = 1.0
	tab.anchor_bottom = 1.0
	tab.offset_left = 8.0
	tab.offset_top = 16.0
	tab.offset_right = -8.0
	tab.offset_bottom = -30.0
	tab.visible = false
	box.add_child(tab)
	return tab


func _label(text: String, color: Color = ROW_COLOR) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_craft_tab() -> void:
	_craft_tab = _new_tab_root("CraftTab")
	_craft_rows = VBoxContainer.new()
	_craft_rows.position = Vector2(0, 2)
	_craft_rows.size = Vector2(150, CRAFT_ROWS_VISIBLE * 16)
	_craft_rows.add_theme_constant_override("separation", 0)
	_craft_tab.add_child(_craft_rows)
	for i in CRAFT_ROWS_VISIBLE:
		# Each row is a panel (its stylebox is the selection highlight) around icon + name.
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(150, 16)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		row.add_theme_stylebox_override("panel", style)
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 3)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(inner)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon)
		var name_label := _label("")
		name_label.custom_minimum_size = Vector2(128, 16)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		inner.add_child(name_label)
		row.gui_input.connect(_on_craft_row_input.bind(i))
		_craft_rows.add_child(row)
	# Detail panel.
	var detail := VBoxContainer.new()
	detail.position = Vector2(156, 2)
	detail.size = Vector2(138, 118)
	detail.add_theme_constant_override("separation", 1)
	_craft_tab.add_child(detail)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 3)
	var big_icon := TextureRect.new()
	big_icon.custom_minimum_size = Vector2(16, 16)
	head.add_child(big_icon)
	var title := _label("")
	title.clip_text = true
	title.custom_minimum_size = Vector2(118, 16)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)
	detail.add_child(head)
	var desc := _label("", DIM_COLOR)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(138, 26)
	detail.add_child(desc)
	var needs := VBoxContainer.new()
	needs.add_theme_constant_override("separation", 0)
	detail.add_child(needs)
	var extra := _label("")
	detail.add_child(extra)
	var button := Button.new()
	button.text = "Craft"
	button.focus_mode = Control.FOCUS_NONE
	for pair in [["normal", "#7b5025"], ["hover", "#9a6631"], ["pressed", "#5c3a1b"],
			["disabled", "#c8b896"]]:
		var bstyle := StyleBoxFlat.new()
		bstyle.bg_color = Color(pair[1])
		bstyle.set_corner_radius_all(2)
		bstyle.content_margin_top = 2
		bstyle.content_margin_bottom = 2
		button.add_theme_stylebox_override(String(pair[0]), bstyle)
	button.add_theme_color_override("font_color", Color("#ffedb1"))
	button.add_theme_color_override("font_hover_color", Color("#fff6d6"))
	button.add_theme_color_override("font_disabled_color", Color("#8a7a63"))
	button.pressed.connect(_craft_selected)
	detail.add_child(button)
	_craft_status = _label("", GOOD_COLOR)
	_craft_status.position = Vector2(0, CRAFT_ROWS_VISIBLE * 16 + 3)
	_craft_status.size = Vector2(150, 10)
	_craft_tab.add_child(_craft_status)
	_craft_detail = {"icon": big_icon, "title": title, "desc": desc, "needs": needs,
		"extra": extra, "button": button}


func _on_craft_row_input(event: InputEvent, row: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var start := _craft_window_start()
		_select_recipe(start + row)
		if event.double_click:
			_craft_selected()


func _craft_window_start() -> int:
	var count := RecipeDB.ids().size()
	return clampi(_craft_index - CRAFT_ROWS_VISIBLE / 2, 0, maxi(count - CRAFT_ROWS_VISIBLE, 0))


func _select_recipe(index: int) -> void:
	var count := RecipeDB.ids().size()
	if count == 0:
		return
	_craft_index = wrapi(index, 0, count)
	_craft_status.text = ""
	_refresh_craft()


func _craft_selected() -> void:
	if _player == null:
		return
	var ids := RecipeDB.ids()
	if ids.is_empty():
		return
	var id := ids[_craft_index]
	var reason := Crafting.craft(id, _player, _levels())
	if reason == Crafting.OK:
		var made := RecipeDB.result_item(id)
		_craft_status.text = "Upgraded!" if made == "" else "Made %d x %s" % [
			RecipeDB.result_count(id), ItemDB.display_name(made)]
		_craft_status.add_theme_color_override("font_color", GOOD_COLOR)
		Audio.play_sfx("ui_purchase", -4.0)
	else:
		_craft_status.text = Crafting.reason_text(reason, id)
		_craft_status.add_theme_color_override("font_color", UNAFFORDABLE_COLOR)
		Audio.play_sfx("ui_error", -6.0)
	_refresh_craft()


func _refresh_craft() -> void:
	var ids := RecipeDB.ids()
	var levels := _levels()
	var start := _craft_window_start()
	for i in CRAFT_ROWS_VISIBLE:
		var row: PanelContainer = _craft_rows.get_child(i)
		var index := start + i
		var style := row.get_theme_stylebox("panel") as StyleBoxFlat
		var icon: TextureRect = row.get_child(0).get_child(0)
		var name_label: Label = row.get_child(0).get_child(1)
		if index >= ids.size():
			row.visible = false
			continue
		row.visible = true
		var id := ids[index]
		var unlocked := RecipeDB.is_unlocked(id, levels)
		var ready := Crafting.check(id, _player.inventory, int(_player.credits), levels) == Crafting.OK
		icon.texture = _recipe_icon(id) if unlocked else null
		name_label.text = _recipe_name(id) if unlocked else "???  (%s)" % RecipeDB.unlock_text(id)
		name_label.add_theme_color_override("font_color",
			ROW_COLOR if ready else (DIM_COLOR if unlocked else LOCKED_COLOR))
		style.bg_color = Color("#c5520f", 0.25) if index == _craft_index else Color(0, 0, 0, 0)
	_refresh_craft_detail(ids[_craft_index] if not ids.is_empty() else "", levels)


func _recipe_name(id: String) -> String:
	if RecipeDB.is_upgrade(id):
		var recipe := RecipeDB.get_recipe(id)
		return "%s Tier %d" % [ItemDB.display_name(String(recipe["upgrade"])), int(recipe["to_tier"])]
	var count := RecipeDB.result_count(id)
	var name_text := ItemDB.display_name(RecipeDB.result_item(id))
	return name_text if count == 1 else "%s x%d" % [name_text, count]


func _recipe_icon(id: String) -> Texture2D:
	var path := ""
	if RecipeDB.is_upgrade(id):
		var recipe := RecipeDB.get_recipe(id)
		path = "res://art/items/%s_t%d.png" % [String(recipe["upgrade"]), int(recipe["to_tier"])]
	else:
		path = ItemDB.icon_path(RecipeDB.result_item(id))
	return load(path) if path != "" and ResourceLoader.exists(path) else null


func _refresh_craft_detail(id: String, levels: Dictionary) -> void:
	var d := _craft_detail
	var needs: VBoxContainer = d["needs"]
	for child in needs.get_children():
		child.queue_free()
	if id == "":
		return
	var unlocked := RecipeDB.is_unlocked(id, levels)
	(d["icon"] as TextureRect).texture = _recipe_icon(id) if unlocked else null
	(d["title"] as Label).text = _recipe_name(id) if unlocked else "Locked recipe"
	var desc := ""
	if not unlocked:
		desc = "Reach %s to learn this." % RecipeDB.unlock_text(id)
	elif RecipeDB.is_upgrade(id):
		desc = "Bring your tier %d tool. Upgraded tools hit harder and reach further." \
			% (int(RecipeDB.get_recipe(id)["to_tier"]) - 1)
	else:
		desc = String(ItemDB.get_item(RecipeDB.result_item(id)).get("description", ""))
	(d["desc"] as Label).text = desc
	var need := RecipeDB.ingredients(id)
	for item in need:
		var have: int = _player.inventory.count_of(item)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		var path := ItemDB.icon_path(item)
		icon.texture = load(path) if path != "" and ResourceLoader.exists(path) else null
		row.add_child(icon)
		var enough: bool = have >= int(need[item])
		var label := _label("%s  %d/%d" % [ItemDB.display_name(item), have, int(need[item])],
			GOOD_COLOR if enough else UNAFFORDABLE_COLOR)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		needs.add_child(row)
	var cost := RecipeDB.credits_cost(id)
	(d["extra"] as Label).text = "" if cost == 0 else "%d Credits" % cost
	(d["extra"] as Label).add_theme_color_override("font_color",
		GOOD_COLOR if int(_player.credits) >= cost else UNAFFORDABLE_COLOR)
	(d["button"] as Button).disabled = Crafting.check(id, _player.inventory, int(_player.credits),
		levels) != Crafting.OK


## -- SKILLS tab --

func _build_skills_tab() -> void:
	_skills_tab = _new_tab_root("SkillsTab")
	_skills_rows = VBoxContainer.new()
	_skills_rows.position = Vector2(4, 4)
	_skills_rows.size = Vector2(288, 110)
	_skills_rows.add_theme_constant_override("separation", 4)
	_skills_tab.add_child(_skills_rows)


func _refresh_skills() -> void:
	for child in _skills_rows.get_children():
		child.queue_free()
	for skill in SkillsScript.SKILLS:
		var total := int(skills.xp.get(skill, 0)) if skills != null else 0
		var lvl := SkillsScript.level_for_xp(total)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_label := _label("%s  Lv %d" % [SkillsScript.NAMES[skill], lvl])
		name_label.custom_minimum_size = Vector2(92, 12)
		row.add_child(name_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(56, 8)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		bar.value = SkillsScript.progress_to_next(total)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var perk := _label(String(SkillsScript.PERK_TEXT[skill]), DIM_COLOR)
		perk.clip_text = true
		perk.custom_minimum_size = Vector2(130, 12)
		row.add_child(perk)
		_skills_rows.add_child(row)
