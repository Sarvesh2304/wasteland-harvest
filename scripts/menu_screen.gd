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
##   4. OPTIONS — (Milestone E part 2) the options screen, scripts/options_menu.gd: settings and
##      the live, rebindable controls list (it replaced the hand-maintained CONTROLS page). The
##      same screen the title screen's Options entry opens. While it's showing, Up/Down/Left/
##      Right and Space/E go to it; Q / LB / RB still change tab, and Tab / Esc still close —
##      except during a pending rebind, when every press goes to it (so Tab can be bound).
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
const QuestDB := preload("res://scripts/quest_db.gd")
const LoreDB := preload("res://scripts/lore_db.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")
const AffinityScript := preload("res://scripts/affinity.gd")
const NpcScript := preload("res://scripts/npc.gd")
const Weather := preload("res://scripts/weather.gd")
const Calendar := preload("res://scripts/calendar.gd")
const UIText := preload("res://scripts/ui_text.gd")
const MarketRules := preload("res://scripts/market_rules.gd")
const Builder := preload("res://scripts/builder.gd")

## 2026-10-07 Milestone B: CRAFT (the recipe book, scripts/crafting.gd) and SKILLS tabs join the
## ring, right after the inventory. Tabs cycle forward with Q, and either way with Left/Right
## or the pad's shoulder buttons.
## Milestone B (2026-10-08) adds JOURNAL (today and tomorrow, the request you hold, Town Works,
## the notes you've read) and PEOPLE (hearts, birthdays, tastes discovered). Eight names only fit
## the tab bar with INVENTORY shortened to ITEMS.
const TAB_NAMES: Array[String] = ["ITEMS", "CRAFT", "SKILLS", "JOURNAL", "PEOPLE", "BUILD", "SETTLERS", "OPTIONS"]
const TAB_INVENTORY := 0
const TAB_CRAFT := 1
const TAB_SKILLS := 2
const TAB_JOURNAL := 3
const TAB_PEOPLE := 4
const TAB_BUILD := 5
const TAB_ASSIGNMENTS := 6
const TAB_OPTIONS := 7
const OptionsMenu := preload("res://scripts/options_menu.gd")

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

@onready var box: Control = %Box
@onready var tab_row: HBoxContainer = %TabRow
@onready var inventory_tab: Control = %InventoryTab
@onready var build_tab: Control = %BuildTab
@onready var assignments_tab: Control = %AssignmentsTab
@onready var options_tab: Control = %ControlsTab
@onready var build_rows: VBoxContainer = %BuildRows
@onready var assignments_rows: VBoxContainer = %AssignmentsRows
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
## Milestone B: assigned by main.gd for the JOURNAL and PEOPLE tabs.
var quests: Node = null
var expedition: Node = null
var _journal_tab: Control = null
var _people_tab: Control = null
var _note_index := 0
## The JOURNAL's pages (Milestone D): up/down picks one; on Notes, E turns to the next note.
const JOURNAL_PAGES: Array[String] = ["Today", "Town", "Story", "Notes"]
const JOURNAL_TODAY := 0
const JOURNAL_TOWN := 1
const JOURNAL_STORY := 2
const JOURNAL_NOTES := 3
var journal_page := 0
## Assigned by main.gd: the market and caravan (Today), festivals and the story (later pages).
var market: Node = null
var caravan: Node = null
var festivals: Node = null
var story: Node = null
var _people_index := 0
## OPTIONS tab: the shared options screen (scripts/options_menu.gd).
var options: Control = null
var _hint_label: Label = null
## SETTLERS tab: the highlighted settler (Up/Down), whose job Space/A cycles.
var _assign_index := 0
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
	_journal_tab = _new_tab_root("JournalTab")
	_people_tab = _new_tab_root("PeopleTab")
	_build_gear_row()
	_hint_label = get_node_or_null("Root/Box/HintLabel") as Label
	_refresh_hint()
	# The OPTIONS tab hosts the shared options screen, filling the tab's own area.
	options = OptionsMenu.new()
	options.name = "Options"
	options.set_anchors_preset(Control.PRESET_FULL_RECT)
	options_tab.add_child(options)
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.input_device_changed.connect(func(_pad: bool) -> void:
			_refresh_hint()
			if active:
				_refresh())


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
	# A pending rebind on the OPTIONS tab gets every press (Tab and Esc included).
	if active and tab_index == TAB_OPTIONS and options != null and options.capturing:
		options.handle_input(event)
		return
	if event.is_action_pressed("toggle_inventory"):
		if active:
			close()
		else:
			open_menu()
	elif event.is_action_pressed("journal"):
		# The journal key (pad Back) opens straight onto the JOURNAL tab, and closes it again.
		if active and tab_index == TAB_JOURNAL:
			close()
		elif active:
			tab_index = TAB_JOURNAL
			_quit_armed = false
			_refresh()
		else:
			open_menu(TAB_JOURNAL)
	elif not active:
		return
	elif event.is_action_pressed("ui_cancel"):
		close()
	elif tab_index == TAB_OPTIONS and (event.is_action_pressed("build_cycle") \
			or event.is_action_pressed("hotbar_next") or event.is_action_pressed("hotbar_prev")):
		tab_index = next_tab(tab_index) if not event.is_action_pressed("hotbar_prev") \
			else prev_tab(tab_index)
		_refresh()
	elif tab_index == TAB_OPTIONS and options != null and options.handle_input(event):
		return
	elif tab_index == TAB_ASSIGNMENTS and (event.is_action_pressed("move_down") \
			or event.is_action_pressed("move_up")):
		_assign_index += 1 if event.is_action_pressed("move_down") else -1
		Audio.play_sfx("ui_hover", -10.0)
		_refresh_assignments()
	elif tab_index == TAB_ASSIGNMENTS and (event.is_action_pressed("use_tool") \
			or event.is_action_pressed("interact")):
		_cycle_assignment()
	elif tab_index == TAB_JOURNAL and event.is_action_pressed("interact") \
			and journal_page == JOURNAL_NOTES:
		_note_index += 1
		Audio.play_sfx("ui_hover", -10.0)
		_refresh_journal()
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
	elif tab_index == TAB_JOURNAL and (event.is_action_pressed("move_down") or event.is_action_pressed("move_up")):
		journal_page = posmod(journal_page + (1 if event.is_action_pressed("move_down") else -1), JOURNAL_PAGES.size())
		Audio.play_sfx("ui_hover", -10.0)
		_refresh_journal()
	elif tab_index == TAB_PEOPLE and (event.is_action_pressed("move_down") or event.is_action_pressed("move_up")):
		_people_index = posmod(_people_index + (1 if event.is_action_pressed("move_down") else -1),
			AffinityScript.NAMED_NPC_IDS.size())
		Audio.play_sfx("ui_hover", -10.0)
		_refresh_people()
	elif event.is_action_pressed("use_tool"):
		_quit_pressed()


## Opening is refused while any other modal surface is open (modal_gate.gd's standard recipe);
## closing below is never gated. Always lands on the Inventory tab, Stardew-style — the menu
## key means "check my stuff", not "wherever I left off".
func open_menu(start_tab: int = TAB_INVENTORY) -> void:
	if active or _player == null:
		return
	if modal_gate != null and modal_gate.is_any_open_except(self):
		return
	active = true
	tab_index = start_tab
	_quit_armed = false
	box.visible = true
	if options != null:
		options.reset_view()
	_refresh()


func close() -> void:
	active = false
	_quit_armed = false
	box.visible = false
	if options != null and options.capturing:
		options.cancel_capture()


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
	if String(_player.get("current_zone_id")) == "ruins":
		# The ruins are rebuilt every expedition and never saved: no quitting mid-run.
		Events.message.emit("You can't save out here. Get back to Kael's truck.")
		Audio.play_sfx("ui_error", -6.0)
		return
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
	if tab_index == TAB_INVENTORY:
		_refresh_gear()
	_craft_tab.visible = tab_index == TAB_CRAFT
	_skills_tab.visible = tab_index == TAB_SKILLS
	_journal_tab.visible = tab_index == TAB_JOURNAL
	_people_tab.visible = tab_index == TAB_PEOPLE
	build_tab.visible = tab_index == TAB_BUILD
	assignments_tab.visible = tab_index == TAB_ASSIGNMENTS
	options_tab.visible = tab_index == TAB_OPTIONS
	if tab_index == TAB_OPTIONS and options != null:
		options.refresh()
	if tab_index == TAB_BUILD:
		_refresh_build_rows()
	elif tab_index == TAB_ASSIGNMENTS:
		_refresh_assignments()
	elif tab_index == TAB_CRAFT:
		_refresh_craft()
	elif tab_index == TAB_SKILLS:
		_refresh_skills()
	elif tab_index == TAB_JOURNAL:
		_refresh_journal()
	elif tab_index == TAB_PEOPLE:
		_refresh_people()
	var go := _prompt("use_tool")
	quit_label.text = "%s / %s — Craft" % [go, _prompt("interact")] if tab_index == TAB_CRAFT \
		else ("" if tab_index == TAB_OPTIONS else quit_hint(_quit_armed, go))
	if tab_index == TAB_ASSIGNMENTS:
		quit_label.text = "%s — Change job   %s — Pick settler" % [go, _nav_prompt()]
	_refresh_hint()
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
	_assign_index = posmod(_assign_index, roster.size())
	for roster_index in roster.size():
		var entry: Dictionary = roster[roster_index]
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = ("> " if roster_index == _assign_index else "  ") \
			+ String(entry.get("name", entry.get("id", "Settler")))
		name_label.custom_minimum_size.x = 74.0
		if roster_index == _assign_index:
			name_label.add_theme_color_override("font_color", ACCENT_COLOR)
		row.add_child(name_label)
		var picker := OptionButton.new()
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.focus_mode = Control.FOCUS_NONE
		picker.add_item("Unassigned")
		picker.set_item_metadata(0, {})
		var job_options: Array[Dictionary] = _player.settlers.assignment_options_for_settler(
			String(entry.get("id", "")))
		var selected := 0
		for option in job_options:
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


## Space/A on the SETTLERS tab: the highlighted settler's next job (Unassigned, then each
## completed staffable building, wrapping) — the pad and keyboard route to the same choice the
## mouse makes in the row's dropdown.
func _cycle_assignment() -> void:
	if _player == null or _player.settlers == null or _player.settlers.roster.is_empty():
		return
	var rows := assignments_rows.get_children().filter(func(c: Node) -> bool:
		return c is HBoxContainer and not c.is_queued_for_deletion())
	var roster: Array = _player.settlers.roster
	var index := posmod(_assign_index, roster.size())
	if index >= rows.size():
		return
	var picker := (rows[index] as HBoxContainer).get_child(1) as OptionButton
	if picker == null or picker.item_count <= 1:
		Audio.play_sfx("ui_error", -8.0)
		return
	Audio.play_sfx("ui_tab", -8.0)
	_on_assignment_selected((picker.selected + 1) % picker.item_count,
		String(roster[index].get("id", "")), picker)


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
	have["credits"] = int(_player.credits)
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
			# Milestone E: a building's Credits fee, read from have["credits"].
			"affordable": BuildGrid.can_afford(have, BuildingDB.cost(id))
				and int(have.get("credits", 0)) >= BuildingDB.credits(id),
		})
	return rows


## Text is the affordability signal alongside color (color alone would be lost on a screenshot
## skim — and eventually on colorblind players).
static func build_row_text(row: Dictionary) -> String:
	var suffix := "" if bool(row["affordable"]) else "  — missing materials"
	return "%s — %s%s" % [String(row["name"]), String(row["cost_text"]), suffix]


## The footer's Save & Return line; `go` names the use button on the device in use.
static func quit_hint(armed: bool, go: String = "Space") -> String:
	return (QUIT_HINT_ARMED if armed else QUIT_HINT).replace("Space", go)


## The bottom hint: how to change tab and close, in the current device's names.
static func hint_text(pad: bool) -> String:
	if pad:
		return "LB / RB: tabs    Y / B: close"
	return "Q / Left / Right: tabs    Tab / Esc: close"


func _refresh_hint() -> void:
	if _hint_label == null:
		return
	var settings := get_node_or_null("/root/Settings")
	var pad := settings != null and bool(settings.using_pad)
	var text := hint_text(pad)
	if tab_index == TAB_OPTIONS and active:
		text = "LB / RB: tabs    B: close" if pad else "Q: tabs    Tab / Esc: close"
	_hint_label.text = text


func _prompt(action: String) -> String:
	var settings := get_node_or_null("/root/Settings")
	return String(settings.prompt(action)) if settings != null else "Space"


func _nav_prompt() -> String:
	var settings := get_node_or_null("/root/Settings")
	return String(settings.nav_prompt()) if settings != null else "Up/Down"



## -- CRAFT tab (Milestone B, 2026-10-07) --

func _levels() -> Dictionary:
	if skills != null and skills.has_method("crafting_levels"):
		return skills.crafting_levels()
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


## -- Worn gear (Milestone C) --
## A row under the backpack grid: the head/body/feet slots (click to take a piece off; wear one
## by using it from the hotbar) and the numbers that matter on an expedition.

const GEAR_SLOTS: Array[String] = ["head", "body", "feet"]
var _gear_slots: Dictionary = {}  # slot -> {"frame": ColorRect, "icon": TextureRect}
var _gear_stats: Label = null


func _build_gear_row() -> void:
	var row := HBoxContainer.new()
	row.name = "GearRow"
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_top = -20
	row.offset_bottom = -2
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_tab.add_child(row)
	var label := Label.new()
	label.text = "Worn"
	label.add_theme_color_override("font_color", ROW_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	for slot in GEAR_SLOTS:
		var frame := ColorRect.new()
		frame.custom_minimum_size = Vector2(18, 18)
		frame.color = Color("#5c4a33")
		frame.tooltip_text = slot.capitalize()
		var icon := TextureRect.new()
		icon.position = Vector2(1, 1)
		icon.size = Vector2(16, 16)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(icon)
		var which := slot
		frame.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and _player != null:
				if _player.unequip(which):
					Audio.play_sfx("ui_close", -6.0)
				_refresh_gear())
		row.add_child(frame)
		_gear_slots[slot] = {"frame": frame, "icon": icon}
	_gear_stats = Label.new()
	_gear_stats.add_theme_color_override("font_color", ROW_COLOR)
	_gear_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_gear_stats)


func _refresh_gear() -> void:
	if _player == null or _gear_stats == null or not _player.has_method("armor"):
		return
	for slot in GEAR_SLOTS:
		var id := String(_player.equipment.get(slot, ""))
		var w: Dictionary = _gear_slots[slot]
		var path := ItemDB.icon_path(id) if id != "" else ""
		(w["icon"] as TextureRect).texture = load(path) if path != "" and ResourceLoader.exists(path) else null
		(w["frame"] as ColorRect).tooltip_text = "%s: %s" % [slot.capitalize(), ItemDB.display_name(id) if id != "" else "nothing"]
	_gear_stats.text = "HP %d/%d  Armour %d  Rad resist %d%%  Rads %d" % [int(_player.hp),
		int(_player.effective_max_hp()), int(_player.armor()), int(round(_player.rad_resist() * 100.0)),
		int(_player.rads)]


## -- Milestone B: JOURNAL --

const ACCENT_COLOR := Color("#c5520f")
const HEART_COLOR := Color("#c5372f")


func _refresh_journal() -> void:
	for child in _journal_tab.get_children():
		child.queue_free()
	for i in JOURNAL_PAGES.size():
		_put(_journal_tab, ("> " if i == journal_page else "  ") + JOURNAL_PAGES[i], Vector2(0, i * 12), 60,
			ACCENT_COLOR if i == journal_page else ROW_COLOR)
	_put(_journal_tab, "↑↓ page", Vector2(0, 110), 60, DIM_COLOR)
	var pane := Control.new()
	pane.position = Vector2(JOURNAL_PANE_X, 0)
	pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_journal_tab.add_child(pane)
	match journal_page:
		JOURNAL_TODAY:
			_journal_today(pane)
		JOURNAL_TOWN:
			_journal_town(pane)
		JOURNAL_STORY:
			_journal_story(pane)
		JOURNAL_NOTES:
			_journal_notes(pane)


const JOURNAL_PANE_X := 64.0
const JOURNAL_PANE_W := 232.0


func _journal_today(pane: Control) -> void:
	var w := JOURNAL_PANE_W
	var day: int = DayManager.day
	var y := 0.0
	y += _wrap_put(pane, "%s. %s today; tomorrow, %s." % [Calendar.date_text(day),
		Weather.display_name(DayManager.weather_today), Weather.display_name(DayManager.weather_tomorrow).to_lower()],
		Vector2(0, y), w, ROW_COLOR) + 4
	if festivals != null:
		var next: Dictionary = festivals.next_festival(day)
		if not next.is_empty():
			var ahead := int(next["in_days"])
			y += _wrap_put(pane, "%s: %s." % [String(next["name"]), "today, in the square" if ahead == 0
				else ("tomorrow" if ahead == 1 else "in %d days" % ahead)], Vector2(0, y), w,
				GOOD_COLOR if ahead == 0 else DIM_COLOR) + 4
	_put(pane, "MARKET", Vector2(0, y), w, ACCENT_COLOR)
	y += 10
	var lines: Array[String] = []
	if market != null and not market.demand.is_empty():
		var names: Array[String] = []
		for item_id in market.demand:
			names.append(ItemDB.display_name(String(item_id)))
		lines.append("Marta's short of %s (+40%%)." % ", ".join(names))
	if market != null:
		var low: Array[String] = []
		for item_id in market.flooded().slice(0, 3):
			low.append("%s %s" % [ItemDB.display_name(item_id), MarketRules.trend_text(market.multiplier_for(item_id))])
		if not low.is_empty():
			lines.append("Flooded: %s." % ", ".join(low))
	if lines.is_empty():
		lines.append("Prices are steady.")
	if caravan != null:
		var ahead: int = caravan.days_until_next(day)
		if ahead == 0:
			lines.append("Tully's caravan is at the stall today.")
		elif ahead > 0:
			lines.append("Tully's caravan comes %s." % ("tomorrow" if ahead == 1 else "in %d days" % ahead))
	y += _wrap_put(pane, " ".join(lines), Vector2(0, y), w, DIM_COLOR) + 4
	_put(pane, "REQUEST", Vector2(0, y), w, ACCENT_COLOR)
	y += 10
	var request_text := "None. The notice board in the square posts one each morning."
	if quests != null and not quests.active.is_empty():
		var req: Dictionary = quests.active
		request_text = "%s: %s" % [QuestDB.title_of(req), _request_progress(req, day)]
	_wrap_put(pane, request_text, Vector2(0, y), w, DIM_COLOR)


func _journal_town(pane: Control) -> void:
	var w := JOURNAL_PANE_W
	_put(pane, "TOWN WORKS", Vector2(0, 0), w, ACCENT_COLOR)
	var y := 12.0
	for id in QuestDB.project_ids():
		var project := QuestDB.project(id)
		var status := ""
		var detail := String(project.get("reward", ""))
		var color := DIM_COLOR
		if quests == null:
			pass
		elif quests.is_finished(id):
			status = "Done"
			color = GOOD_COLOR
		elif quests.is_funded(id):
			status = "Tonight"
			detail = "Fully funded. Harlan's crew builds it tonight."
		else:
			status = "%d%%" % int(round(QuestDB.progress(id, quests.given_to(id)) * 100.0))
			var left: Dictionary = QuestDB.remaining(id, quests.given_to(id))
			var parts: Array[String] = []
			for key in left:
				parts.append("%d Cr" % int(left[key]) if key == "credits" else QuestDB.amount_text(String(key), int(left[key])))
			detail = "Needs " + ", ".join(parts) + "."
		_put(pane, String(project.get("name", id)), Vector2(0, y), w - 44, ROW_COLOR)
		_put(pane, status, Vector2(w - 44, y), 44, color).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		y += 10
		var detail_label := _put(pane, detail, Vector2(6, y), w - 6, color)
		detail_label.tooltip_text = detail
		y += 14


func _journal_story(pane: Control) -> void:
	var w := JOURNAL_PANE_W
	var info: Dictionary = story.journal_entry() if story != null else {}
	if info.is_empty():
		_put(pane, "THE STORY SO FAR", Vector2(0, 0), w, ACCENT_COLOR)
		_wrap_put(pane, "You were born here, and the farm is yours now. Get it back on its feet; the town is watching, fondly.",
			Vector2(0, 12), w, DIM_COLOR)
		return
	_put(pane, String(info.get("title", "")), Vector2(0, 0), w, ACCENT_COLOR)
	var y := 12.0
	y += _wrap_put(pane, String(info.get("journal", "")), Vector2(0, y), w, ROW_COLOR) + 6
	var past: Array = info.get("past", [])
	if not past.is_empty():
		_wrap_put(pane, "Before: " + ", ".join(past) + ".", Vector2(0, y), w, DIM_COLOR)


func _journal_notes(pane: Control) -> void:
	var w := JOURNAL_PANE_W
	var read: Array = expedition.notes_read if expedition != null else []
	_put(pane, "NOTES  (%d of %d found)" % [read.size(), LoreDB.notes().size()], Vector2(0, 0), w, ACCENT_COLOR)
	if read.is_empty():
		_wrap_put(pane, "Old notes turn up in the ruins. Read one and it's kept here.", Vector2(0, 12), w, DIM_COLOR)
		return
	_note_index = posmod(_note_index, read.size())
	var note := LoreDB.note(String(read[_note_index]))
	_put(pane, "%d. %s" % [_note_index + 1, String(note.get("title", ""))], Vector2(0, 14), w, ROW_COLOR)
	_wrap_put(pane, String(note.get("text", "")), Vector2(0, 26), w, DIM_COLOR)
	if read.size() > 1:
		_put(pane, "E: next note", Vector2(0, 110), w, DIM_COLOR)


func _request_progress(req: Dictionary, day: int) -> String:
	var left: int = quests.days_left(day)
	var when := "due today" if left <= 0 else ("1 day left" if left == 1 else "%d days left" % left)
	var who := DialogueDB.display_name(String(req.get("npc", "")))
	if String(req.get("kind", "")) == "hunt":
		return "%s for %s, %d of %d done, %s." % [QuestDB.enemy_name(String(req.get("enemy", "any")), 2),
			who, int(req.get("progress", 0)), int(req["count"]), when]
	var have: int = int(_player.inventory.count_of(String(req["item"]))) if _player != null else 0
	return "%s for %s (you have %d), %s." % [QuestDB.amount_text(String(req["item"]), int(req["count"])),
		who, have, when]


## -- Milestone B: PEOPLE --

func _refresh_people() -> void:
	for child in _people_tab.get_children():
		child.queue_free()
	var affinity: Node = _player.affinity if _player != null else null
	var day: int = DayManager.day
	var ids := AffinityScript.NAMED_NPC_IDS
	for i in ids.size():
		var id: String = ids[i]
		var y := float(i) * 14.0
		if i == _people_index:
			var bar := ColorRect.new()
			bar.color = Color("#e8d29a")
			bar.position = Vector2(-2, y - 1)
			bar.size = Vector2(300, 14)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_people_tab.add_child(bar)
		var frames := NpcScript.frames_for(id)
		if frames != null and frames.has_animation("idle_south"):
			var face := TextureRect.new()
			var atlas := AtlasTexture.new()
			atlas.atlas = frames.get_frame_texture("idle_south", 0)
			atlas.region = Rect2(4, 1, 16, 12)
			face.texture = atlas
			face.position = Vector2(0, y)
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_people_tab.add_child(face)
		_put(_people_tab, DialogueDB.display_name(id), Vector2(20, y + 2), 64, ROW_COLOR)
		var hearts: int = int(affinity.value_for(id)) if affinity != null else 0
		_put(_people_tab, "♥".repeat(hearts), Vector2(86, y + 2), 60, HEART_COLOR)
		_put(_people_tab, "♡".repeat(10 - hearts), Vector2(86 + hearts * 6, y + 2), 60, DIM_COLOR)
		var b := DialogueDB.birthday(id)
		if not b.is_empty():
			_put(_people_tab, "%s %d" % [Calendar.SEASON_SHORT.get(String(b["season"]), ""), int(b["day"])],
				Vector2(152, y + 2), 60, DIM_COLOR)
		if affinity != null:
			_put(_people_tab, "talked" if affinity.talked_today(id, day) else "", Vector2(214, y + 2), 40, GOOD_COLOR)
			_put(_people_tab, "gift" if affinity.gifted_today(id, day) else "", Vector2(256, y + 2), 40, GOOD_COLOR)
	_people_index = posmod(_people_index, ids.size())
	var picked: String = ids[_people_index]
	var known: Dictionary = affinity.known_gifts(picked) if affinity != null else {}
	var parts: Array[String] = []
	for reaction in ["loved", "liked", "neutral", "disliked", "hated"]:
		var names: Array[String] = []
		for item_id in known:
			if String(known[item_id]) == reaction:
				names.append(ItemDB.display_name(String(item_id)))
		if not names.is_empty():
			names.sort()
			parts.append("%s %s" % [String(reaction).capitalize(), ", ".join(names)])
	var detail := "Gifts you've tried on %s: %s." % [DialogueDB.display_name(picked), "; ".join(parts)] \
		if not parts.is_empty() else "Give %s something to learn what they like. One gift a day, two a week." \
		% DialogueDB.display_name(picked)
	_wrap_put(_people_tab, detail, Vector2(0, float(ids.size()) * 14.0 + 2.0), 296, DIM_COLOR)


## -- Small layout helpers for the code-built tabs --

func _put(parent: Control, text: String, at: Vector2, width: float, color: Color) -> Label:
	var label := _label(text, color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS  # before the size: see notice_ui.gd
	label.position = at
	parent.add_child(label)
	label.size = Vector2(width, 10)
	return label


## A wrapped paragraph; returns its height (measured with the font: see ui_text.gd).
func _wrap_put(parent: Control, text: String, at: Vector2, width: float, color: Color) -> float:
	var label := _label(text, color)
	label.position = at
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	var h := UIText.wrapped_height(label, text, width)
	label.size = Vector2(width, h)
	return h

