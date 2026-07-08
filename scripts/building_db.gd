extends RefCounted
## Loader for data/buildings.json — the Phase 4 Stage 2 buildable-structure catalog (ROADMAP.md
## "Basic building placement"). Mirrors scripts/item_db.gd's shape exactly: static functions,
## JSON parsed once and cached, every consumer (scripts/builder.gd's placement mode,
## scripts/structures.gd's blueprint spawning, tests) goes through these accessors rather than
## touching the JSON directly.
##
## Scope note (same judgment-call style as structures.gd's header): the catalog holds just 2
## structures — a cheap 1x1 Shelter Tent and a 2x2 Storage Shed that becomes a working storage
## chest on completion. Stage 2 only needs to prove the place → spend → wait-a-day mechanic
## end-to-end with both a trivial and a multi-cell/functional structure; the full 12+ building
## library with real gameplay functions is explicitly Phase 8's checklist item, not this stage's.
##
## Not a `class_name` global (see scripts/item_db.gd's header for why) — callers must
## `const BuildingDB := preload("res://scripts/building_db.gd")`.

const PATH := "res://data/buildings.json"

static var _buildings: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var text := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(text)
	_buildings = parsed if parsed is Dictionary else {}
	_buildings.erase("_comment")


## Full building definition dictionary, or {} if building_id is unknown.
static func get_building(building_id: String) -> Dictionary:
	_ensure_loaded()
	return _buildings.get(building_id, {})


static func has_building(building_id: String) -> bool:
	_ensure_loaded()
	return _buildings.has(building_id)


static func all_buildings() -> Dictionary:
	_ensure_loaded()
	return _buildings


## Catalog order (JSON insertion order, which Godot Dictionaries preserve) — this is the order
## scripts/builder.gd's build_cycle action steps through.
static func ids() -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for key in _buildings.keys():
		out.append(String(key))
	return out


static func display_name(building_id: String) -> String:
	return String(get_building(building_id).get("name", ""))


## The BUILDING_COLORS key scripts/structures.gd paints the completed structure with.
static func kind(building_id: String) -> String:
	return String(get_building(building_id).get("kind", ""))


## Footprint size in cells (JSON [w, h] array -> Vector2i). Unknown ids read as 1x1.
static func size_of(building_id: String) -> Vector2i:
	var raw: Array = get_building(building_id).get("size", [1, 1])
	if raw.size() != 2:
		return Vector2i.ONE
	return Vector2i(int(raw[0]), int(raw[1]))


## Resource cost as {item_id: int count} (JSON numbers arrive as floats; normalized here).
static func cost(building_id: String) -> Dictionary:
	var out := {}
	for item_id in get_building(building_id).get("cost", {}):
		out[String(item_id)] = int(get_building(building_id)["cost"][item_id])
	return out


static func build_days(building_id: String) -> int:
	return int(get_building(building_id).get("build_days", 1))


## True for structures that act as a storage chest (a second Inventory instance, opened via the
## existing chest interaction — see scripts/structures.gd) once construction completes.
static func is_storage(building_id: String) -> bool:
	return bool(get_building(building_id).get("is_storage", false))


## Test-only hook, same as ItemDB.reload_from_disk (and named the same way, avoiding Script's
## built-in reload()).
static func reload_from_disk() -> void:
	_loaded = false
	_ensure_loaded()
