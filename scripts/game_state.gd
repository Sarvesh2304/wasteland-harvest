extends Node
## Cross-scene state autoload (ROADMAP.md Phase 4), registered alongside DayManager in
## project.godot's [autoload]. Two jobs:
##   1. Carry the player's settlement choice from scenes/settlement_select.tscn to
##      scenes/main.tscn (Stage 1), since Godot scene transitions don't otherwise share state.
##   2. Own the save system (Stage 3): has_save()/save_game()/load_save_from_disk() plus the
##      handoff of loaded data into a freshly-booted main.tscn. It lives here rather than in a
##      scene script because the load decision happens BEFORE main.tscn exists (from
##      title_screen.gd's Load flow, at launch — settlement_select.gd's auto-resume before the
##      2026-07-11 title screen), and autoloads are the one thing guaranteed to be alive on
##      both sides of a scene change. The pure serialisation logic (Dictionary <-> JSON-safe
##      shapes) is scripts/save_data.gd; the slot-file scheme is scripts/save_slots.gd; this
##      node is only the file I/O and the live-node gather/apply glue around them.
##
## chosen_settlement_id defaults to SettlementDB.DEFAULT_ID so anything that boots main.tscn
## directly without going through the selection screen first (tools/runtime_smoke.gd, headless
## tests, or a developer running the scene standalone in-editor) still gets a sensible,
## fully-formed map rather than an unset/invalid id.
##
## Save files: FileAccess + JSON at user:// (Godot's per-app data directory — NOT inside the
## repo, so no save-file pollution in commits). `save_path` is a var, not a const, specifically
## so tests can point it at a throwaway filename and never inherit/leave stale state across
## headless runs (a hard requirement — see tools/runtime_smoke.gd's setup/cleanup stages).
##
## Multi-slot saves (2026-07-11, see scripts/save_slots.gd's class doc for the storage scheme):
## `save_path` now means "the ACTIVE slot's file" rather than one fixed filename. The whole
## has_save()/save_game()/load_save_from_disk()/delete_save() surface is unchanged and still
## operates on save_path — which is exactly why every direct-boot tool (tools/runtime_smoke.gd,
## soak_test.gd, sleep_smoke.gd, screenshot_*.gd) that assigns save_path itself keeps working.
## The real game flow sets save_path through exactly two doors before main.tscn ever exists:
##   - start_new_slot()  — settlement_select.gd's confirm (a New Game from the title screen)
##   - load_slot(path)   — title_screen.gd's Load screen confirming a listed slot
## save_path's default stays the old single-slot filename purely as a direct-boot fallback
## (a dev running main.tscn standalone); the title screen adopts any save found there into a
## real slot via migrate_legacy_save(), so a pre-multi-slot playthrough is never orphaned.
## `saves_dir`/`legacy_save_path` are vars for the same test-redirection reason save_path is.

const SettlementDB := preload("res://scripts/settlement_db.gd")
const SaveData := preload("res://scripts/save_data.gd")
const SaveSlots := preload("res://scripts/save_slots.gd")

## Emitted after a successful save_game() write — the HUD's transient "WORLD SAVED" notice
## (scripts/hud.gd) listens to this rather than being called directly, so the save system
## needs no reference to any UI.
signal game_saved

var chosen_settlement_id: String = SettlementDB.DEFAULT_ID

var save_path := "user://savegame.json"

## Where slot files live / where a pre-multi-slot save is adopted from (see class doc). Vars —
## not consts — so test tooling can point a whole run at throwaway locations.
var saves_dir: String = SaveSlots.DEFAULT_SAVES_DIR
var legacy_save_path := "user://savegame.json"

## Loaded-but-not-yet-applied save data, set by load_save_from_disk() (called via load_slot()
## from title_screen.gd's Load panel before the scene change) and consumed exactly once by
## main.gd's _ready() via take_pending_save(). This two-step handoff exists because the nodes
## the data restores into (TestMap/Farm/Structures/Player) only come to life inside main.tscn —
## the same reason chosen_settlement_id lives here.
var _pending_save_data: Dictionary = {}


## Called by settlement_select.gd on confirm. Silently ignores an unknown id (keeps whatever was
## already set) rather than erroring, since a bad id would otherwise only surface as a confusing
## downstream failure in test_map.gd.
func choose_settlement(id: String) -> void:
	if SettlementDB.has_settlement(id):
		chosen_settlement_id = id


## -- Multi-slot plumbing (2026-07-11) --

## Points the save system at a FRESH slot file for a brand-new playthrough — called by
## settlement_select.gd the moment a settlement is confirmed, so the game knows where its
## auto-saves go from the first minute. Allocation is eager (the slot id/path is claimed here)
## but the FILE is lazy (created by the first save_game, i.e. the first sleep) — quitting
## before ever sleeping leaves no empty husk on the Load screen, exactly like Stardew only
## materialising a farm after the first night. Two consecutive never-saved new games reusing
## the same id is therefore harmless: at most one of them ever writes.
## Also clears any staged load and resets the DayManager clock to the day-1 morning defaults,
## so a new game is identical whether or not this process previously loaded a slot.
func start_new_slot() -> void:
	var existing_ids: Array = []
	for summary in SaveSlots.list_slots(saves_dir):
		existing_ids.append(summary["slot_id"])
	save_path = SaveSlots.slot_path(saves_dir, SaveSlots.next_slot_id(existing_ids))
	_pending_save_data = {}
	DayManager.day = 1
	DayManager.minutes_into_day = float(DayManager.DAY_START_MINUTES)


## Activates a listed slot and stages its data for main.tscn — the Load screen's confirm.
## On failure (deleted/corrupted between listing and confirming) save_path is left pointing at
## the bad slot, but nothing else changed; the caller stays on the Load screen and relists.
func load_slot(path: String) -> bool:
	save_path = path
	return load_save_from_disk()


## The Load screen's row data (see save_slots.gd's list_slots/summarize).
func list_slots() -> Array[Dictionary]:
	return SaveSlots.list_slots(saves_dir)


## One-time adoption of a pre-multi-slot `user://savegame.json` (see save_slots.gd's
## migrate_legacy_save doc) — title_screen.gd calls this once per boot before listing slots.
func migrate_legacy_save() -> void:
	SaveSlots.migrate_legacy_save(legacy_save_path, saves_dir)


## -- Save system (Phase 4 Stage 3) --

func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Gathers all live mutable state (see save_data.gd's class doc for the exact v2 shape) and
## writes it as JSON. Since the zone split, world state is gathered PER ZONE from the
## always-instantiated cluster: `zones` is main.gd's {zone_id: {map, farm, structures, npcs}}
## dict (player.zones aliases it), passed in rather than looked up here so this autoload never
## assumes a particular scene layout — player.gd calls this from _end_day with the dict it
## already holds. The gather loop is deliberately uniform across zones (no per-zone branching):
## a zone with no farmland/chest just serialises empty defaults, keeping the shape
## forward-compatible (see the plan's save-shape note).
func save_game(player: Node, zones: Dictionary, settlers: Node = null) -> bool:
	var zones_out := {}
	for zone_id in zones:
		var zone: Dictionary = zones[zone_id]
		zones_out[zone_id] = {
			"map": zone["map"].save_state(),
			"farm": zone["farm"].save_state(),
			"structures": zone["structures"].save_state(),
		}
	var data := SaveData.build_save({
		"settlement_id": chosen_settlement_id,
		"day": DayManager.day,
		"minutes_into_day": DayManager.minutes_into_day,
		# Wall-clock stamp for the Load screen's most-recent-first ordering (see
		# save_slots.gd's compare_summaries) — optional metadata, not part of world state.
		"saved_unix": int(Time.get_unix_time_from_system()),
		"player": player.save_state(),
		"zones": zones_out,
		# Phase 8 Stage 3: additive "settlers" key (see save_data.gd's class doc) — settlers is
		# optional (defaults null) purely so any call site that genuinely has no settlement-wide
		# roster to save (none exist in this codebase, but keeps the signature change backward-
		# defensive) doesn't crash rather than silently writing {}.
		"settlers": settlers.save_state() if settlers != null else {},
	})
	# Slot files live in a subdirectory that won't exist before the first-ever save (slot
	# allocation is eager, file creation lazy — see start_new_slot()); a no-op for paths whose
	# directory already exists, e.g. the user:// roots every test tool points save_path at.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()))
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("save_game: cannot open %s (error %d)" % [save_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	game_saved.emit()
	return true


## Reads + validates the save file and stages it for main.tscn. Returns false (leaving all
## state untouched, so the caller falls through to the new-game picker) if the file is missing,
## unparseable, the wrong version, or names a settlement this build doesn't know. On success,
## chosen_settlement_id is set immediately — it must be in place BEFORE main.tscn instantiates,
## because test_map.gd resolves its layout from it in _enter_tree() (the same
## before-children's-_ready() ordering constraint the settlement picker already relies on).
func load_save_from_disk() -> bool:
	if not has_save():
		return false
	var data := SaveData.parse_save(FileAccess.get_file_as_string(save_path))
	if data.is_empty():
		return false
	var settlement_id := String(data.get("settlement_id", ""))
	if not SettlementDB.has_settlement(settlement_id):
		return false
	chosen_settlement_id = settlement_id
	_pending_save_data = data
	return true


## One-shot consumer for main.gd's _ready(): returns the staged save data (empty = this is a
## fresh new game, grant the starting bonus instead) and clears it, so a later in-session
## return to main.tscn can't accidentally re-apply a stale load.
func take_pending_save() -> Dictionary:
	var data := _pending_save_data
	_pending_save_data = {}
	return data


## Removes the ACTIVE slot's file (test cleanup, mostly). The Load panel's per-slot delete
## (title_screen.gd's _delete_pressed) removes listed files directly instead, since the slot
## being deleted there is usually not the active save_path.
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
