extends RefCounted
## Loader for data/items.json (ROADMAP Phase 3 "first 20 items").
##
## Deliberately NOT a `class_name` global: this codebase's established convention (see
## scripts/map_layouts/open_plains_layout.gd, scripts/wang_tileset.gd from Phase 1/2/4) is `const X :=
## preload(...)` in every file that needs it, because `class_name` globals only resolve once
## Godot's global script class cache has been rebuilt — which normally happens by opening the
## project in the editor GUI, something this build avoids per CLAUDE.md's team-model gate. Any
## script that calls ItemDB must `const ItemDB := preload("res://scripts/item_db.gd")` first.
##
## Static, cached on first access — item defs are read-only for the whole process, so there's
## no reason to re-parse the JSON file per lookup. Every consumer (Inventory, HUD, player tool
## dispatch) goes through this rather than touching the JSON directly, so the file format can
## change without hunting down callers.

const PATH := "res://data/items.json"

static var _items: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var text := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(text)
	_items = parsed if parsed is Dictionary else {}
	_items.erase("_comment")


## Full item definition dictionary, or {} if item_id is unknown.
static func get_item(item_id: String) -> Dictionary:
	_ensure_loaded()
	return _items.get(item_id, {})


static func has_item(item_id: String) -> bool:
	_ensure_loaded()
	return _items.has(item_id)


static func all_items() -> Dictionary:
	_ensure_loaded()
	return _items


static func stack_max(item_id: String) -> int:
	return int(get_item(item_id).get("stack_max", 1))


## Named is_tool_item (not is_tool) — GDScript's Script class already has a built-in
## is_tool() (checks for the @tool annotation), and calling ItemDB.is_tool(...) on this
## preloaded script resource resolved to that built-in instead of this static method.
static func is_tool_item(item_id: String) -> bool:
	return String(get_item(item_id).get("type", "")) == "tool"


static func is_seed(item_id: String) -> bool:
	return String(get_item(item_id).get("type", "")) == "seed"


static func durability_max(item_id: String) -> int:
	return int(get_item(item_id).get("durability_max", 0))


## Test-only hook: force a re-read of the JSON file (e.g. after editing fixtures). Named
## reload_from_disk (not reload) — Script has a built-in reload() that would shadow it, same
## class of collision as is_tool_item's rename above.
static func reload_from_disk() -> void:
	_loaded = false
	_ensure_loaded()
