extends "res://tests/test_case.gd"
## scripts/save_slots.gd (2026-07-11 multi-slot save system): the pure slot-identity math
## (file-name parsing, id allocation, summaries, ordering) plus the thin directory I/O
## (list_slots / migrate_legacy_save) against a throwaway user:// directory that is created
## and fully removed inside each test — the same never-inherit/never-leave-stale-state rule
## the smoke tools follow for save files.

const SaveSlots := preload("res://scripts/save_slots.gd")
const SaveData := preload("res://scripts/save_data.gd")

const TMP_DIR := "user://test_save_slots_tmp"
const TMP_LEGACY := "user://test_save_slots_legacy.json"


## -- Pure: file-name <-> slot id --

func test_slot_file_name_and_path() -> void:
	assert_eq(SaveSlots.slot_file_name(1), "slot_1.json")
	assert_eq(SaveSlots.slot_file_name(12), "slot_12.json")
	assert_eq(SaveSlots.slot_path("user://saves", 3), "user://saves/slot_3.json")


func test_parse_slot_id_accepts_canonical_names() -> void:
	assert_eq(SaveSlots.parse_slot_id("slot_1.json"), 1)
	assert_eq(SaveSlots.parse_slot_id("slot_42.json"), 42)


func test_parse_slot_id_rejects_everything_else() -> void:
	assert_eq(SaveSlots.parse_slot_id("savegame.json"), -1, "non-slot file")
	assert_eq(SaveSlots.parse_slot_id("slot_.json"), -1, "no digits")
	assert_eq(SaveSlots.parse_slot_id("slot_abc.json"), -1, "non-numeric")
	assert_eq(SaveSlots.parse_slot_id("slot_007.json"), -1, "non-canonical zero padding")
	assert_eq(SaveSlots.parse_slot_id("slot_+3.json"), -1, "non-canonical sign")
	assert_eq(SaveSlots.parse_slot_id("slot_-2.json"), -1, "negative id")
	assert_eq(SaveSlots.parse_slot_id("slot_0.json"), -1, "ids start at 1")
	assert_eq(SaveSlots.parse_slot_id("slot_3.txt"), -1, "wrong extension")
	assert_eq(SaveSlots.parse_slot_id("slot_3.json.bak"), -1, "trailing suffix")


func test_parse_slot_id_round_trips_slot_file_name() -> void:
	for id in [1, 2, 9, 10, 123]:
		assert_eq(SaveSlots.parse_slot_id(SaveSlots.slot_file_name(id)), id)


## -- Pure: id allocation --

func test_next_slot_id_starts_at_one() -> void:
	assert_eq(SaveSlots.next_slot_id([]), 1)


func test_next_slot_id_is_high_water_plus_one() -> void:
	assert_eq(SaveSlots.next_slot_id([1, 2, 3]), 4)
	assert_eq(SaveSlots.next_slot_id([2, 5]), 6, "gaps below the high-water mark are not reused")
	assert_eq(SaveSlots.next_slot_id([3]), 4, "deleting 1-2 must not resurrect their ids")


## -- Pure: summaries + ordering --

func test_summarize_extracts_header_fields() -> void:
	var s := SaveSlots.summarize(3, {
		"settlement_id": "forest_edge", "day": 12, "saved_unix": 5000, "farm": {"huge": "blob"},
	})
	assert_eq(s["slot_id"], 3)
	assert_eq(s["settlement_id"], "forest_edge")
	assert_eq(s["settlement_name"], "Forest Edge", "display name resolved from SettlementDB")
	assert_eq(s["day"], 12)
	assert_eq(s["saved_unix"], 5000)


func test_summarize_defaults_and_unknown_settlement() -> void:
	var s := SaveSlots.summarize(1, {"settlement_id": "atlantis"})
	assert_eq(s["settlement_name"], "atlantis", "unknown settlement falls back to the raw id")
	assert_eq(s["day"], 1, "missing day defaults to 1")
	assert_eq(s["saved_unix"], 0, "pre-timestamp saves read as 0")


func test_compare_summaries_most_recent_first_then_newest_slot() -> void:
	var older := {"slot_id": 5, "saved_unix": 100}
	var newer := {"slot_id": 1, "saved_unix": 300}
	assert_true(SaveSlots.compare_summaries(newer, older), "newer timestamp sorts first")
	assert_false(SaveSlots.compare_summaries(older, newer))
	var tie_low := {"slot_id": 2, "saved_unix": 0}
	var tie_high := {"slot_id": 7, "saved_unix": 0}
	assert_true(SaveSlots.compare_summaries(tie_high, tie_low),
		"timestamp ties fall back to newest slot id first")


## -- I/O: listing a real directory --

func test_list_slots_missing_dir_is_no_slots() -> void:
	_remove_tmp()
	assert_eq(SaveSlots.list_slots(TMP_DIR).size(), 0)


func test_list_slots_scans_parses_and_sorts() -> void:
	_remove_tmp()
	_write_slot(1, "open_plains", 3, 100)
	_write_slot(2, "forest_edge", 7, 300)
	_write_file(TMP_DIR.path_join("notes.txt"), "not a save")
	_write_file(TMP_DIR.path_join("slot_9.json"), "{corrupt")
	var slots := SaveSlots.list_slots(TMP_DIR)
	assert_eq(slots.size(), 2, "stray + corrupt files are skipped, not listed")
	if slots.size() == 2:
		assert_eq(slots[0]["slot_id"], 2, "most recently saved listed first")
		assert_eq(slots[0]["settlement_name"], "Forest Edge")
		assert_eq(slots[0]["day"], 7)
		assert_eq(slots[0]["path"], TMP_DIR.path_join("slot_2.json"))
		assert_eq(slots[1]["slot_id"], 1)
	_remove_tmp()


## -- I/O: legacy single-save adoption --

func test_migrate_legacy_save_moves_into_next_slot() -> void:
	_remove_tmp()
	_write_slot(1, "open_plains", 3, 100)
	_write_file(TMP_LEGACY, JSON.stringify(_save_dict("riverside", 9, 200)))
	assert_true(SaveSlots.migrate_legacy_save(TMP_LEGACY, TMP_DIR))
	assert_false(FileAccess.file_exists(TMP_LEGACY), "legacy file was moved, not copied")
	var slots := SaveSlots.list_slots(TMP_DIR)
	assert_eq(slots.size(), 2)
	if slots.size() == 2:
		assert_eq(slots[0]["slot_id"], 2, "adopted into the next free slot id")
		assert_eq(slots[0]["settlement_id"], "riverside", "adopted save kept its content")
		assert_eq(slots[0]["day"], 9)
	assert_false(SaveSlots.migrate_legacy_save(TMP_LEGACY, TMP_DIR),
		"a second migration finds nothing to adopt")
	_remove_tmp()


func test_migrate_legacy_save_ignores_missing_and_corrupt() -> void:
	_remove_tmp()
	assert_false(SaveSlots.migrate_legacy_save(TMP_LEGACY, TMP_DIR), "missing legacy file")
	_write_file(TMP_LEGACY, "{not json")
	assert_false(SaveSlots.migrate_legacy_save(TMP_LEGACY, TMP_DIR), "corrupt legacy file")
	assert_true(FileAccess.file_exists(TMP_LEGACY), "corrupt file left in place, not destroyed")
	assert_eq(SaveSlots.list_slots(TMP_DIR).size(), 0, "nothing was adopted")
	_remove_tmp()


## -- helpers --

func _save_dict(settlement_id: String, day: int, saved_unix: int) -> Dictionary:
	# SAVE_VERSION symbolically, not a literal: a listable fixture must always be a
	# current-version save (parse/summarize reject mismatched versions by design — v1 saves
	# were invalidated by the zone split's v2 reshape).
	return {"version": SaveData.SAVE_VERSION, "settlement_id": settlement_id, "day": day,
		"saved_unix": saved_unix}


func _write_slot(id: int, settlement_id: String, day: int, saved_unix: int) -> void:
	_write_file(SaveSlots.slot_path(TMP_DIR, id),
		JSON.stringify(_save_dict(settlement_id, day, saved_unix)))


func _write_file(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove_tmp() -> void:
	if FileAccess.file_exists(TMP_LEGACY):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_LEGACY))
	var abs_dir := ProjectSettings.globalize_path(TMP_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		return
	for file_name in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(file_name))
	DirAccess.remove_absolute(abs_dir)
