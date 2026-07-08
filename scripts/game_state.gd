extends Node
## Cross-scene state autoload (ROADMAP.md Phase 4), registered alongside DayManager in
## project.godot's [autoload]. Two jobs:
##   1. Carry the player's settlement choice from scenes/settlement_select.tscn to
##      scenes/main.tscn (Stage 1), since Godot scene transitions don't otherwise share state.
##   2. Own the save system (Stage 3): has_save()/save_game()/load_save_from_disk() plus the
##      handoff of loaded data into a freshly-booted main.tscn. It lives here rather than in a
##      scene script because the resume decision happens BEFORE main.tscn exists (from
##      settlement_select.gd, at launch), and autoloads are the one thing guaranteed to be
##      alive on both sides of a scene change. The pure serialisation logic (Dictionary <->
##      JSON-safe shapes) is scripts/save_data.gd; this node is only the file I/O and the
##      live-node gather/apply glue around it.
##
## chosen_settlement_id defaults to SettlementDB.DEFAULT_ID so anything that boots main.tscn
## directly without going through the selection screen first (tools/runtime_smoke.gd, headless
## tests, or a developer running the scene standalone in-editor) still gets a sensible,
## fully-formed map rather than an unset/invalid id.
##
## Save file: FileAccess + JSON at user:// (Godot's per-app data directory — NOT inside the
## repo, so no save-file pollution in commits). `save_path` is a var, not a const, specifically
## so tests can point it at a throwaway filename and never inherit/leave stale state across
## headless runs (a hard requirement — see tools/runtime_smoke.gd's setup/cleanup stages).

const SettlementDB := preload("res://scripts/settlement_db.gd")
const SaveData := preload("res://scripts/save_data.gd")

## Emitted after a successful save_game() write — the HUD's transient "WORLD SAVED" notice
## (scripts/hud.gd) listens to this rather than being called directly, so the save system
## needs no reference to any UI.
signal game_saved

var chosen_settlement_id: String = SettlementDB.DEFAULT_ID

var save_path := "user://savegame.json"

## Loaded-but-not-yet-applied save data, set by load_save_from_disk() (called from
## settlement_select.gd before the scene change) and consumed exactly once by main.gd's
## _ready() via take_pending_save(). This two-step handoff exists because the nodes the data
## restores into (TestMap/Farm/Structures/Player) only come to life inside main.tscn — the
## same reason chosen_settlement_id lives here.
var _pending_save_data: Dictionary = {}


## Called by settlement_select.gd on confirm. Silently ignores an unknown id (keeps whatever was
## already set) rather than erroring, since a bad id would otherwise only surface as a confusing
## downstream failure in test_map.gd.
func choose_settlement(id: String) -> void:
	if SettlementDB.has_settlement(id):
		chosen_settlement_id = id


## -- Save system (Phase 4 Stage 3) --

func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Gathers all live mutable state (see save_data.gd's class doc for the exact shape) and writes
## it as JSON. The four nodes are passed in rather than looked up here so this autoload never
## assumes a particular scene layout — player.gd calls this from the bed interaction with the
## world references it already holds via bind_world().
func save_game(player: Node, test_map: Node, farm: Node, structures: Node) -> bool:
	var data := SaveData.build_save({
		"settlement_id": chosen_settlement_id,
		"day": DayManager.day,
		"minutes_into_day": DayManager.minutes_into_day,
		"player": player.save_state(),
		"map": test_map.save_state(),
		"farm": farm.save_state(),
		"structures": structures.save_state(),
	})
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


## Removes the save file (test cleanup; also the future "New Game" affordance's hook).
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
