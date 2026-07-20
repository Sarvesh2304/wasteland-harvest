extends RefCounted
## Loader for data/buildings.json — the buildable-structure catalog (ROADMAP.md "Basic building
## placement", grown by Phase 8 Stage 1 into the full 12-building library). Mirrors
## scripts/item_db.gd's shape exactly: static functions, JSON parsed once and cached, every
## consumer (scripts/builder.gd's placement mode, scripts/structures.gd's blueprint spawning,
## tests) goes through these accessors rather than touching the JSON directly.
##
## Phase 8 Stage 1 generalized the per-building dispatch: a new functional building kind is now
## data (daily_yield/capacity_unlock/effect below) plus at most one small bespoke callable in
## scripts/building_effects.gd, rather than a hardcoded field here + a hardcoded branch in
## structures.gd/player.gd for every new kind.
##
## Phase 8 Stage 2 (fencing & perimeter system) added solid()/durability_max() for the 4 new
## fence/gate catalog entries — see those accessors below for the exact defaulting rules.
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


## Phase 8 Stage 1: the generalized interaction dispatch — "" (no interaction), "storage" (a
## second Inventory instance, opened via the existing chest interaction — see
## scripts/structures.gd), or "trading_post" (data-only this stage; unreachable/unstaffed until
## Stage 4 wires an actual UI to it).
static func interaction(building_id: String) -> String:
	return String(get_building(building_id).get("interaction", ""))


## True for structures that act as a storage chest once construction completes. Kept as a thin
## wrapper over interaction() so no existing call site (structures.gd's chest logic) needed to
## change when the old "is_storage" bool was migrated to the "interaction" string field.
static func is_storage(building_id: String) -> bool:
	return interaction(building_id) == "storage"


## Item-count bonus granted to the player's inventory once per in-game day for every completed
## structure of this kind (structures.gd's day-tick loop sums this across all completed
## entries) — {} for kinds with no daily yield. Numeric values normalized to int (JSON numbers
## arrive as floats), matching cost()'s own normalization.
static func daily_yield(building_id: String) -> Dictionary:
	var out := {}
	for item_id in get_building(building_id).get("daily_yield", {}):
		out[String(item_id)] = int(get_building(building_id)["daily_yield"][item_id])
	return out


## One-time bonus(es) unlocked by completing this kind — e.g. {"population_cap": 1},
## {"energy_max": 10}, {"build_energy_discount": 0.25} — summed across every completed structure
## by scripts/building_effects.gd's recompute_capacity_unlocks(). {} for kinds with no unlock.
## Returned as a fresh copy so a caller can't mutate the cached JSON data in place.
static func capacity_unlock(building_id: String) -> Dictionary:
	var raw: Dictionary = get_building(building_id).get("capacity_unlock", {})
	return raw.duplicate()


## The bespoke effect key for this kind, or "" if it has none. Two different consumers read this:
## a key present in scripts/building_effects.gd's EFFECTS dict is a mutating day-tick callable
## (only "rain_collector_water" so far); a key with no EFFECTS entry (e.g. "watchtower_lookout",
## "antenna_signal") is instead read directly by a later stage's own logic (Stage 3's settler-
## arrival roll) rather than ever being called from here.
static func effect(building_id: String) -> String:
	return String(get_building(building_id).get("effect", ""))


## Phase 8 Stage 2 (fencing & perimeter system): the fence/gate's stored durability ceiling —
## displayed only, no decay/damage system consumes it yet (no raid system exists), the same
## data-ahead-of-its-system precedent as daily_yield's fertilizer/cooked_meal items. 0 for any
## building with no durability_max field (every non-fence/gate kind today).
static func durability_max(building_id: String) -> int:
	return int(get_building(building_id).get("durability_max", 0))


## Whether a completed structure of this kind blocks movement. Defaults to true for every
## existing building (only the new gate_wood entry sets "solid": false in buildings.json), so
## no pre-Stage-2 data needed to change. Read by scripts/structures.gd's _complete_construction
## (skip the CollisionShape2D / unblock the footprint cells for a non-solid completed structure).
static func solid(building_id: String) -> bool:
	return bool(get_building(building_id).get("solid", true))


## Test-only hook, same as ItemDB.reload_from_disk (and named the same way, avoiding Script's
## built-in reload()).
static func reload_from_disk() -> void:
	_loaded = false
	_ensure_loaded()
