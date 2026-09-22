extends SceneTree
## Headless smoke scenario for the 2026-07-11 title screen + multi-slot save system
## (scenes/title_screen.tscn / scripts/save_slots.gd), separate from tools/runtime_smoke.gd
## the same way sleep_smoke.gd is: runtime_smoke drives ONE playthrough's slot through the
## title flow end-to-end; this file is the multi-slot matrix — several slots coexisting —
## proving specifically:
##   1. The Load panel lists MULTIPLE existing slots, most-recently-saved first, each row
##      carrying its own settlement/day.
##   2. Loading a SPECIFIC slot restores THAT slot's state (day/settlement/layout), and the
##      load touches no slot file's bytes — including the loaded one's.
##   3. New Game from the title allocates a fresh slot id (high-water + 1), whose file only
##      appears at the first save — and writing it leaves every other slot's bytes untouched.
##   4. The Load panel's Q-then-Q-again delete removes exactly the highlighted slot's file
##      (first Q only arms; navigation would disarm), and other slots survive.
##   5. Exit actually quits: driven LAST through the real menu input path — this process
##      ending with exit code 0 is itself the assertion, and a watchdog stage fails the run
##      with code 1 if the quit never happens. (Failures found earlier skip the Exit drive
##      and quit(1) explicitly, so a red run can never masquerade as the clean-exit success.)
##
## Slots are seeded as files directly (minimal valid saves: version + settlement_id + day +
## saved_unix) rather than played into existence — this file tests the slot machinery, not
## the world serialisation runtime_smoke already covers; main.gd's _apply_save tolerates the
## absent sections by design (every load_state() defaults missing fields).
##
## Same test hygiene as runtime_smoke.gd: a test-only saves dir (game_state.saves_dir) with
## legacy_save_path redirected, wiped before the run and before the final Exit drive.
##
## Run: godot --headless --path . --script res://tools/title_smoke.gd

const ForestEdgeLayout := preload("res://scripts/map_layouts/forest_edge_layout.gd")
const RiversideLayout := preload("res://scripts/map_layouts/riverside_layout.gd")
const SaveData := preload("res://scripts/save_data.gd")

const SAVES_DIR := "user://title_smoke_saves"

var game_state: Node
var day_manager: Node
var title: Control
var select: Control
var main: Node
var stage := 0
var stage_started_at := 0
var failures: Array[String] = []
## Byte snapshots keyed by slot id, for the "no other slot's file was touched" checks.
var _slot_bytes: Dictionary = {}


func _initialize() -> void:
	day_manager = root.get_node("DayManager")
	game_state = root.get_node("GameState")
	game_state.saves_dir = SAVES_DIR
	game_state.legacy_save_path = SAVES_DIR.path_join("legacy.json")
	game_state.save_path = SAVES_DIR.path_join("preboot.json")  # inert until New Game allocates
	_delete_test_saves()
	# Two coexisting playthroughs: slot 1 (Open Plains, day 3, saved earlier) and slot 2
	# (Forest Edge, day 7, saved later — so it must list FIRST).
	_write_slot(1, "open_plains", 3, 100)
	_write_slot(2, "forest_edge", 7, 300)
	_snapshot_slot(1)
	_snapshot_slot(2)
	_boot_title()


func _boot_title() -> void:
	title = (load("res://scenes/title_screen.tscn") as PackedScene).instantiate()
	root.add_child(title)
	current_scene = title


## Watchdog (ported from tools/runtime_smoke.gd's fix after a real incident there — a
## duplicate match-arm stage number hijacked a transition and the run looped silently for 12+
## minutes at near-zero CPU before being caught by hand). Comfortably above every in-stage tick
## wait in this file (<=20) so it never fires on a healthy run, but guarantees a future stall
## fails LOUDLY with the exact stuck stage instead of hanging indefinitely.
const MAX_TICKS_PER_STAGE := 1800
var _watchdog_tripped := false


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	if ticks > MAX_TICKS_PER_STAGE and not _watchdog_tripped:
		_watchdog_tripped = true
		push_error("title_smoke watchdog: stuck in stage %d for %d ticks" % [stage, ticks])
		_check(false, "TIMED OUT after %d ticks with no stage transition (watchdog)" % ticks)
		return _finish()
	match stage:
		0:
			# -- Claim 1: the menu sees the slots; the Load panel lists both, newest first --
			if ticks < 10:
				return false
			_check(title._menu_entries == ["New Game", "Load Game", "Exit"],
				"menu offers all three options with slots present (got %s)" \
					% str(title._menu_entries))
			_drive("move_down")
			_drive("use_tool")
			_check(title.mode == title.Mode.LOAD, "Load panel opened")
			_check(title._slots.size() == 2, "both slots listed (got %d)" % title._slots.size())
			if title._slots.size() == 2:
				_check(int(title._slots[0]["slot_id"]) == 2 and int(title._slots[1]["slot_id"]) == 1,
					"most-recently-saved slot (2) lists first (got %s)" % str(title._slots))
				_check(String(title._slots[0]["settlement_name"]) == "Forest Edge"
						and int(title._slots[0]["day"]) == 7,
					"row 0 carries slot 2's own settlement/day")
				_check(String(title._slots[1]["settlement_name"]) == "Open Plains"
						and int(title._slots[1]["day"]) == 3,
					"row 1 carries slot 1's own settlement/day")
			# -- Claim 2 setup: confirm the highlighted row 0 = slot 2 (Forest Edge, day 7) --
			_drive("use_tool")
			_enter_stage(1)
		1:
			if ticks < 20:  # let the load's change_scene_to_file complete
				return false
			main = current_scene
			_check(main != null and main.name == "Main", "loading a slot booted main.tscn")
			if main == null or main.name != "Main":
				return _finish()
			_check(day_manager.day == 7, "slot 2's day restored (7, got %d)" % day_manager.day)
			_check(game_state.chosen_settlement_id == "forest_edge",
				"slot 2's settlement restored — NOT slot 1's")
			# Since the zone split the farm zone's map (FarmMap) is the settlement-specific one —
			# the layout-identity check the old single TestMap carried lives there now.
			_check(main.get_node("FarmMap").layout == ForestEdgeLayout,
				"the world painted slot 2's layout")
			_check(game_state.save_path == SAVES_DIR.path_join("slot_2.json"),
				"save_path is the LOADED slot's file, so its auto-saves stay in their lane")
			_check(_slot_unchanged(1), "loading slot 2 did not touch slot 1's file")
			_check(_slot_unchanged(2), "loading is read-only — slot 2's own file unchanged")
			_enter_stage(2)
		2:
			# -- Claim 3: New Game allocates a fresh slot and leaves the others alone --
			if ticks < 5:
				return false
			main.queue_free()
			main = null
			_boot_title()
			_enter_stage(3)
		3:
			if ticks < 10:
				return false
			_drive("use_tool")  # New Game is pre-highlighted at index 0
			_enter_stage(4)
		4:
			if ticks < 15:
				return false
			select = current_scene
			_check(select != null and select.name == "SettlementSelect",
				"New Game reached the settlement picker")
			if select == null or select.name != "SettlementSelect":
				return _finish()
			select._confirm(2)  # Riverside — distinct from both seeded slots
			_check(game_state.save_path == SAVES_DIR.path_join("slot_3.json"),
				"the new game claimed fresh slot 3 = high-water 2 + 1 (got %s)" \
					% game_state.save_path)
			_check(not FileAccess.file_exists(SAVES_DIR.path_join("slot_3.json")),
				"slot 3's file stays lazy until the first save")
			_enter_stage(5)
		5:
			if ticks < 20:
				return false
			main = current_scene
			_check(main != null and main.name == "Main", "the picker's confirm booted main.tscn")
			if main == null or main.name != "Main":
				return _finish()
			_check(day_manager.day == 1, "the new game starts on day 1, not a loaded day")
			_check(main.get_node("FarmMap").layout == RiversideLayout,
				"the new game painted its OWN settlement's layout")
			# First save materialises the slot — through the same GameState.save_game the bed
			# uses (runtime_smoke stage 81's convention for a non-bed save), on the zone-split
			# signature: the whole always-instantiated zones dict, not one map's node trio.
			_check(game_state.save_game(main.get_node("Player"), main.zones, main.get_node("Settlers"), main.get_node("Animals")),
				"the new game's first save wrote")
			_check(FileAccess.file_exists(SAVES_DIR.path_join("slot_3.json")),
				"slot 3's file now exists")
			_check(_slot_unchanged(1) and _slot_unchanged(2),
				"creating + saving the new game touched NO other slot's file bytes")
			_enter_stage(6)
		6:
			# -- Claim 4: the Load panel's two-press delete removes exactly one slot --
			if ticks < 5:
				return false
			main.queue_free()
			main = null
			_boot_title()
			_enter_stage(7)
		7:
			if ticks < 10:
				return false
			_drive("move_down")
			_drive("use_tool")
			_check(title.mode == title.Mode.LOAD, "Load panel opened for the delete check")
			_check(title._slots.size() == 3, "all three slots listed now")
			_check(title._slots.size() > 0 and int(title._slots[0]["slot_id"]) == 3,
				"the just-saved slot 3 lists first")
			_drive("build_cycle")  # Q: arm delete on the highlighted slot 3
			_check(FileAccess.file_exists(SAVES_DIR.path_join("slot_3.json")),
				"first Q only ARMS the delete — file still there")
			_check(title._pending_delete_index == 0, "row 0 is armed for deletion")
			_drive("build_cycle")  # Q again: delete for real
			_check(not FileAccess.file_exists(SAVES_DIR.path_join("slot_3.json")),
				"second Q deleted slot 3's file")
			_check(title._slots.size() == 2, "the list relisted down to 2")
			_check(FileAccess.file_exists(SAVES_DIR.path_join("slot_1.json"))
					and FileAccess.file_exists(SAVES_DIR.path_join("slot_2.json")),
				"the delete took ONLY the armed slot's file")
			_drive("ui_cancel")  # ESC back to the menu
			_check(title.mode == title.Mode.MENU, "ESC returned to the menu")
			_check(title._menu_entries.size() == 3,
				"Load Game still offered — slots remain after the single delete")
			_enter_stage(8)
		8:
			# -- Claim 5: Exit actually quits. Clean up FIRST (nothing runs after quit), then
			#    drive Exit through the real input path; the process ending with code 0 is the
			#    assertion, and stage 9 is the watchdog that fails the run if it never does. --
			if ticks < 5:
				return false
			_delete_test_saves()
			if not failures.is_empty():
				return _finish()  # never let a red run exit 0 through the Exit drive
			print("TITLE SMOKE: all checks passed — driving Exit; a clean quit(0) ends the run")
			_drive("move_up")  # index 0 wraps straight up to Exit (the last row)
			_check(title._menu_index == title._menu_entries.size() - 1, "wrapped up to Exit")
			_drive("use_tool")  # -> get_tree().quit()
			_enter_stage(9)
		9:
			if ticks > 60:
				print("TITLE SMOKE FAIL: Exit was confirmed but the game never quit")
				quit(1)
				return true
		_:
			pass
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("stage %d: %s" % [stage, message])


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()


func _finish() -> bool:
	_delete_test_saves()
	if failures.is_empty():
		print("TITLE SMOKE: ok")
		quit(0)
	else:
		for failure in failures:
			print("TITLE SMOKE FAIL: %s" % failure)
		quit(1)
	return true


func _drive(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	title._unhandled_input(event)


## -- Seeded-slot + hygiene helpers --

func _write_slot(id: int, settlement_id: String, day: int, saved_unix: int) -> void:
	var path := SAVES_DIR.path_join("slot_%d.json" % id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVES_DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		# The CURRENT save version, not a literal: a seeded slot must stay loadable across
		# version bumps (v1 slots are now correctly rejected by parse_save — that rejection has
		# its own test in tests/test_save_data.gd, it isn't this file's job to re-prove).
		"version": SaveData.SAVE_VERSION, "settlement_id": settlement_id, "day": day,
		"minutes_into_day": 360.0, "saved_unix": saved_unix,
	}, "\t"))
	file.close()


func _snapshot_slot(id: int) -> void:
	_slot_bytes[id] = FileAccess.get_file_as_bytes(SAVES_DIR.path_join("slot_%d.json" % id))


func _slot_unchanged(id: int) -> bool:
	return FileAccess.get_file_as_bytes(SAVES_DIR.path_join("slot_%d.json" % id)) \
		== _slot_bytes[id]


func _delete_test_saves() -> void:
	var abs_dir := ProjectSettings.globalize_path(SAVES_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	for file_name in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(file_name))
	DirAccess.remove_absolute(abs_dir)
