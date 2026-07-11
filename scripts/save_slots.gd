extends RefCounted
## Multi-slot save storage (2026-07-11 playtest UX gap: "after saving, I cannot start a new
## game" -> full Stardew-style multi-slot system per Sarvesh's explicit scope choice). Each
## playthrough owns one file, `slot_<n>.json`, inside a saves directory (default
## `user://saves`); the slot id `<n>` is a positive integer allocated at new-game time as
## (highest existing id + 1) — ids are never reused while a higher one exists, so "slot 3"
## can't silently become a different playthrough after a delete. The file's CONTENT is exactly
## the single-file save save_data.gd already defines (same SAVE_VERSION, same shape) plus an
## optional `saved_unix` timestamp game_state.gd stamps at write time so the Load screen can
## sort by most-recently-played; WHERE the file lives is the only thing that changed.
##
## ## Slot naming (deliberate, not a placeholder)
## There is no text-entry widget anywhere in this codebase, and building one just to name a
## save was judged out of scope for this fix (see the session report). Slots are therefore
## auto-described from data every save already carries: the Load screen renders
## "<slot id>. <Settlement Name> — Day <n>" via title_screen.gd's format_slot_row(), which is
## unambiguous across same-settlement playthroughs (distinct slot ids + day counts) without
## asking the player to type anything.
##
## ## Why there is NO manifest file
## The Load screen's listing is a directory scan that parses each slot file and keeps only the
## top-level header fields (settlement_id/day/saved_unix). A sidecar manifest was considered
## and rejected: save files are a few KB (the whole world state of a 36x32 map), so a full
## JSON parse per slot is microseconds and only happens on the title/Load screens — while a
## manifest is a second source of truth that desyncs the moment anything writes or deletes a
## slot file without going through a manifest API (the test tooling points GameState.save_path
## at throwaway files by design, and a player deleting a file in Finder is a supported
## Stardew-ism). Scanning the files themselves means the list is always exactly the truth.
##
## Every function here is static; the pure ones (parse_slot_id / next_slot_id / slot_path /
## summarize / compare_summaries) are unit-tested headlessly in tests/test_save_slots.gd, the
## same convention as save_data.gd. The thin I/O ones (list_slots / migrate_legacy_save) take
## the saves dir as a PARAMETER rather than hardcoding user://saves — the same
## redirect-for-tests requirement that made game_state.gd's save_path a var (tools/*.gd point
## GameState.saves_dir at throwaway directories so repeated runs never inherit stale state and
## never touch a real playthrough's slots).

const SaveData := preload("res://scripts/save_data.gd")
const SettlementDB := preload("res://scripts/settlement_db.gd")

const DEFAULT_SAVES_DIR := "user://saves"
const SLOT_FILE_PREFIX := "slot_"
const SLOT_FILE_SUFFIX := ".json"


## -- Pure slot-identity math --

static func slot_file_name(slot_id: int) -> String:
	return "%s%d%s" % [SLOT_FILE_PREFIX, slot_id, SLOT_FILE_SUFFIX]


static func slot_path(saves_dir: String, slot_id: int) -> String:
	return saves_dir.path_join(slot_file_name(slot_id))


## Extracts the slot id from a file name, or -1 for anything that isn't a canonical slot file
## ("slot_007.json", "slot_-2.json", "slot_.json", "notes.txt" all rejected) — the directory
## scan uses this to ignore stray files rather than choking on them.
static func parse_slot_id(file_name: String) -> int:
	if not file_name.begins_with(SLOT_FILE_PREFIX) or not file_name.ends_with(SLOT_FILE_SUFFIX):
		return -1
	var digits := file_name.substr(SLOT_FILE_PREFIX.length(),
		file_name.length() - SLOT_FILE_PREFIX.length() - SLOT_FILE_SUFFIX.length())
	if not digits.is_valid_int():
		return -1
	var id := int(digits)
	# Round-trip check rejects non-canonical spellings ("007", "+3") so one playthrough can
	# never be listed twice under two file names.
	if id < 1 or str(id) != digits:
		return -1
	return id


## Highest existing id + 1 (minimum 1). Never reuses a freed id below the high-water mark —
## see class doc.
static func next_slot_id(existing_ids: Array) -> int:
	var highest := 0
	for id in existing_ids:
		highest = maxi(highest, int(id))
	return highest + 1


## The Load screen's lightweight per-slot row data, extracted from a parsed save Dictionary.
## settlement_name falls back to the raw id for a settlement this build doesn't know (the slot
## still lists; loading it is what validates it).
static func summarize(slot_id: int, data: Dictionary) -> Dictionary:
	var settlement_id := String(data.get("settlement_id", ""))
	var settlement := SettlementDB.get_settlement(settlement_id)
	return {
		"slot_id": slot_id,
		"settlement_id": settlement_id,
		"settlement_name": String(settlement.get("name", settlement_id)),
		"day": int(data.get("day", 1)),
		"saved_unix": int(data.get("saved_unix", 0)),
	}


## Sort predicate: most-recently-saved first; ties (e.g. pre-timestamp saves, all 0) fall back
## to newest slot id first, so the ordering is total and stable.
static func compare_summaries(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("saved_unix", 0)) != int(b.get("saved_unix", 0)):
		return int(a.get("saved_unix", 0)) > int(b.get("saved_unix", 0))
	return int(a.get("slot_id", 0)) > int(b.get("slot_id", 0))


## -- Thin file I/O --

## Scans `saves_dir` for slot files and returns their summaries (plus each one's full "path")
## sorted most-recent first. A missing directory is simply "no slots yet"; a file that doesn't
## parse as a valid save is skipped (it can't be loaded, so listing it would only offer the
## player a dead row).
static func list_slots(saves_dir: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(saves_dir):
		return out
	for file_name in DirAccess.get_files_at(saves_dir):
		var slot_id := parse_slot_id(file_name)
		if slot_id < 0:
			continue
		var path := saves_dir.path_join(file_name)
		var data := SaveData.parse_save(FileAccess.get_file_as_string(path))
		if data.is_empty():
			continue
		var summary := summarize(slot_id, data)
		summary["path"] = path
		out.append(summary)
	out.sort_custom(compare_summaries)
	return out


## One-time adoption of the pre-multi-slot single save (`user://savegame.json`): a valid save
## sitting at the legacy path is MOVED into the saves dir as a fresh slot, so the playthrough
## Sarvesh reported being locked into shows up on the very first Load screen instead of being
## orphaned. Called from title_screen.gd's _ready() (the earliest moment the new flow owns).
## A missing or unparseable legacy file is left alone (nothing listable to adopt). Returns
## whether a migration happened.
static func migrate_legacy_save(legacy_path: String, saves_dir: String) -> bool:
	if not FileAccess.file_exists(legacy_path):
		return false
	if SaveData.parse_save(FileAccess.get_file_as_string(legacy_path)).is_empty():
		return false
	var existing_ids: Array = []
	for summary in list_slots(saves_dir):
		existing_ids.append(summary["slot_id"])
	var dest := slot_path(saves_dir, next_slot_id(existing_ids))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saves_dir))
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(legacy_path),
		ProjectSettings.globalize_path(dest)) == OK
