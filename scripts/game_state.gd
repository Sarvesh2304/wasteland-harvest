extends Node
## Tiny cross-scene state autoload (ROADMAP.md Phase 4), registered alongside DayManager in
## project.godot's [autoload]. Its only job this session: carry the player's settlement choice
## from scenes/settlement_select.tscn to scenes/main.tscn, since no save system exists yet
## (that's Stage 3) and Godot scene transitions don't otherwise share state between scenes.
##
## Defaults to SettlementDB.DEFAULT_ID so anything that boots main.tscn directly without going
## through the selection screen first (tools/runtime_smoke.gd, a future headless test, or a
## developer running the scene standalone in-editor) still gets a sensible, fully-formed map
## rather than an unset/invalid id.

const SettlementDB := preload("res://scripts/settlement_db.gd")

var chosen_settlement_id: String = SettlementDB.DEFAULT_ID


## Called by settlement_select.gd on confirm. Silently ignores an unknown id (keeps whatever was
## already set) rather than erroring, since a bad id would otherwise only surface as a confusing
## downstream failure in test_map.gd.
func choose_settlement(id: String) -> void:
	if SettlementDB.has_settlement(id):
		chosen_settlement_id = id
