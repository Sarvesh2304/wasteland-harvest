extends Control
## Title screen (2026-07-11 playtest UX gap: "After saving, I cannot seem to start a new game
## ... a welcome window is needed", scoped by Sarvesh to a full Stardew-style multi-slot
## system) — the run/main_scene per project.godot, replacing settlement_select.tscn there. The
## resume-vs-new fork that settlement_select.gd's _ready() used to decide silently now lives
## here as an explicit player choice:
##   - New Game  -> scenes/settlement_select.tscn (unchanged in its own behavior: pick one of
##                  the 3 starts, confirm; it claims a fresh save slot on confirm)
##   - Load Game -> the in-scene Load panel: every existing slot listed most-recent first
##                  (settlement + day, via scripts/save_slots.gd), confirm one to restore it
##                  into scenes/main.tscn through the exact staged-load handoff the old
##                  auto-resume used (GameState.load_slot -> take_pending_save in main.gd).
##                  Q (the existing build_cycle action) deletes the highlighted slot with a
##                  press-again-to-confirm guard; ESC returns to the menu.
##   - Exit      -> get_tree().quit()
## "Load Game" is hidden entirely while no slot exists (first launch), Stardew-style.
##
## Keyboard-only, reusing existing input actions exactly like settlement_select.gd (see its
## matching comment for why reuse is safe here): move_up/move_down cycle, use_tool confirms,
## ui_cancel backs out of the Load panel, build_cycle deletes. Both panels live in this one
## scene (a `mode` switch) rather than a separate load_game.tscn because the Load panel needs
## instant, state-preserving back-navigation to the menu — a scene change would rebuild the
## world for what is UI-locally one screen.
##
## The Load list is windowed (MAX_VISIBLE_SLOTS rows) so any number of slots stays navigable
## inside the 320x192 viewport — there is deliberately NO cap on how many slots can exist
## (Stardew doesn't cap either; the id scheme in save_slots.gd is unbounded).
##
## Pure display/navigation math (menu_entries / format_slot_row / format_saved_date /
## scroll_start) is static and headlessly unit-tested in tests/test_title_screen.gd, the same
## split settlement_select.gd's wrap_index established.

const SaveSlots := preload("res://scripts/save_slots.gd")

const MENU_NEW_GAME := "New Game"
const MENU_LOAD_GAME := "Load Game"
const MENU_EXIT := "Exit"

## Same row palette as store_ui.gd/dialogue_ui.gd's cycle-then-confirm lists.
const ROW_COLOR := Color("#7b5025")            # worn wood (dark) — unselected row
const ROW_SELECTED_COLOR := Color("#c5520f")   # rust red — the established highlight
const DETAIL_COLOR := Color("#95ac49")         # faded field green
const HINT_COLOR := Color("#9d9180")           # scavenged metal
const DELETE_COLOR := Color("#d13b27")         # warning red for the pending-delete row

const MAX_VISIBLE_SLOTS := 6
const DELETE_CONFIRM_SUFFIX := " — Q AGAIN TO DELETE"

enum Mode { MENU, LOAD }

@onready var menu_panel: Control = %MenuPanel
@onready var load_panel: Control = %LoadPanel
@onready var menu_rows: VBoxContainer = %MenuRows
@onready var slot_rows: VBoxContainer = %SlotRows
@onready var detail_label: Label = %DetailLabel
@onready var empty_label: Label = %EmptyLabel

var mode: Mode = Mode.MENU
var _menu_entries: Array[String] = []
var _menu_index := 0
var _menu_labels: Array[Label] = []
## Load-panel state: summaries from GameState.list_slots() (each carries "path"), the
## highlighted index, and which index (or -1) is one Q-press away from deletion.
var _slots: Array[Dictionary] = []
var _slot_index := 0
var _pending_delete_index := -1
var _slot_labels: Array[Label] = []


func _ready() -> void:
	# Adopt a pre-multi-slot user://savegame.json into a real slot BEFORE the first listing,
	# so the reported "stuck" playthrough appears on the Load screen from this build's very
	# first boot (see save_slots.gd's migrate_legacy_save doc).
	GameState.migrate_legacy_save()
	_show_menu()


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.MENU:
		_menu_input(event)
	else:
		_load_input(event)


## -- Main menu --

func _show_menu() -> void:
	mode = Mode.MENU
	_slots = GameState.list_slots()
	_menu_entries = menu_entries(not _slots.is_empty())
	_menu_index = 0
	load_panel.visible = false
	menu_panel.visible = true
	_refresh_menu()


func _menu_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		_menu_index = wrapi(_menu_index - 1, 0, _menu_entries.size())
		_refresh_menu()
	elif event.is_action_pressed("move_down"):
		_menu_index = wrapi(_menu_index + 1, 0, _menu_entries.size())
		_refresh_menu()
	elif event.is_action_pressed("use_tool"):
		_confirm_menu()


func _confirm_menu() -> void:
	match _menu_entries[_menu_index]:
		MENU_NEW_GAME:
			# The picker claims the fresh slot itself on settlement confirm — nothing to
			# allocate from here (backing out of the picker is impossible this stage, but if
			# it ever isn't, no slot will have been touched by merely visiting it).
			set_process_unhandled_input(false)
			get_tree().change_scene_to_file("res://scenes/settlement_select.tscn")
		MENU_LOAD_GAME:
			_show_load()
		MENU_EXIT:
			get_tree().quit()


func _refresh_menu() -> void:
	_sync_row_labels(menu_rows, _menu_labels, _menu_entries.size())
	for i in _menu_entries.size():
		_menu_labels[i].text = _menu_entries[i]
		_menu_labels[i].add_theme_color_override("font_color",
			ROW_SELECTED_COLOR if i == _menu_index else ROW_COLOR)


## -- Load panel --

func _show_load() -> void:
	mode = Mode.LOAD
	_slots = GameState.list_slots()
	_slot_index = 0
	_pending_delete_index = -1
	menu_panel.visible = false
	load_panel.visible = true
	_refresh_load()


func _load_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_show_menu()
		return
	if event.is_action_pressed("move_up"):
		_slot_index = wrapi(_slot_index - 1, 0, maxi(_slots.size(), 1))
		_pending_delete_index = -1
		_refresh_load()
	elif event.is_action_pressed("move_down"):
		_slot_index = wrapi(_slot_index + 1, 0, maxi(_slots.size(), 1))
		_pending_delete_index = -1
		_refresh_load()
	elif event.is_action_pressed("use_tool"):
		_confirm_slot()
	elif event.is_action_pressed("build_cycle"):
		_delete_pressed()


func _confirm_slot() -> void:
	if _slot_index >= _slots.size():
		return
	# GameState.load_slot points save_path at this slot and stages its data; main.tscn's
	# _ready() consumes it via take_pending_save() — the identical handoff the old
	# settlement_select resume path used, so restore behavior is unchanged by construction.
	if GameState.load_slot(String(_slots[_slot_index]["path"])):
		set_process_unhandled_input(false)
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	# Deleted/corrupted between listing and confirming: relist rather than crash or load the
	# wrong world; the dead row disappears (list_slots skips unparseable files).
	_show_load()


## Stardew-parity slot deletion, guarded by a second press: the first Q marks the row (text +
## warning color make the armed state unmissable), the second Q on the SAME row deletes the
## file; any navigation in between disarms it.
func _delete_pressed() -> void:
	if _slot_index >= _slots.size():
		return
	if _pending_delete_index != _slot_index:
		_pending_delete_index = _slot_index
		_refresh_load()
		return
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(String(_slots[_slot_index]["path"])))
	_slots = GameState.list_slots()
	if _slots.is_empty():
		# Nothing left to load — back to the menu, which re-derives entries and so drops
		# the Load Game option entirely.
		_show_menu()
		return
	_slot_index = mini(_slot_index, _slots.size() - 1)
	_pending_delete_index = -1
	_refresh_load()


func _refresh_load() -> void:
	empty_label.visible = _slots.is_empty()
	var start := scroll_start(_slot_index, _slots.size(), MAX_VISIBLE_SLOTS)
	var visible_count := mini(_slots.size() - start, MAX_VISIBLE_SLOTS)
	_sync_row_labels(slot_rows, _slot_labels, maxi(visible_count, 0))
	for row in visible_count:
		var i := start + row
		var text := format_slot_row(_slots[i])
		if i == _pending_delete_index:
			text += DELETE_CONFIRM_SUFFIX
		_slot_labels[row].text = text
		_slot_labels[row].add_theme_color_override("font_color",
			DELETE_COLOR if i == _pending_delete_index
			else (ROW_SELECTED_COLOR if i == _slot_index else ROW_COLOR))
	detail_label.text = "" if _slots.is_empty() \
		else format_saved_date(int(_slots[_slot_index].get("saved_unix", 0)))


## -- Shared row-label pool --

## Grows/shrinks a VBox's Label children to exactly `count` (menu and slot lists both build
## their rows dynamically, like settlement_select.gd's dots — the row count isn't knowable at
## scene-authoring time once slots are unbounded).
func _sync_row_labels(box: VBoxContainer, labels: Array[Label], count: int) -> void:
	while labels.size() < count:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
		labels.append(label)
	for i in labels.size():
		labels[i].visible = i < count


## -- Pure display/navigation math (headlessly unit-tested, no scene needed) --

## The menu's rows: Load Game only exists while there's something to load.
static func menu_entries(has_slots: bool) -> Array[String]:
	if has_slots:
		return [MENU_NEW_GAME, MENU_LOAD_GAME, MENU_EXIT]
	return [MENU_NEW_GAME, MENU_EXIT]


## One Load-screen row: "<slot id>. <Settlement Name> — Day <n>" (the documented auto-naming
## scheme — see save_slots.gd's class doc for why slots aren't free-text named).
static func format_slot_row(summary: Dictionary) -> String:
	return "%d. %s — Day %d" % [int(summary.get("slot_id", 0)),
		String(summary.get("settlement_name", "")), int(summary.get("day", 1))]


## The highlighted slot's detail line: real-world last-played date from the save's saved_unix
## stamp ("" for pre-stamp saves, which simply show no date rather than a fake one).
static func format_saved_date(saved_unix: int) -> String:
	if saved_unix <= 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(saved_unix)
	return "Last played %04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]


## First visible row index for a windowed list: keeps the selection centered where possible,
## clamped to the list's ends — stateless, so it can't drift and is trivially testable.
static func scroll_start(selected: int, count: int, max_visible: int) -> int:
	if count <= max_visible:
		return 0
	return clampi(selected - max_visible / 2, 0, count - max_visible)
