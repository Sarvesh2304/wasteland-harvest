extends RefCounted
## Ruins loot tables (data/loot_tables.json, Milestone C 2026-10-08). Static module, same shape as
## recipe_db.gd: lazy JSON load, pure queries. world_objects.gd rolls a container's table when it's
## searched; enemies.gd rolls an enemy's table when it dies. Deterministic for a given rng.

const PATH := "res://data/loot_tables.json"
const ItemDB := preload("res://scripts/item_db.gd")

static var _tables: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and parsed.get("tables") is Dictionary:
		_tables = parsed["tables"]


static func table_ids() -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for id in _tables:
		out.append(String(id))
	out.sort()
	return out


static func has_table(id: String) -> bool:
	_ensure_loaded()
	return _tables.has(id)


## [min, max] draws for `id` at `tier` (the nearest defined tier at or below it).
static func rolls_for(id: String, tier: int) -> Vector2i:
	_ensure_loaded()
	var rolls: Dictionary = (_tables.get(id, {}) as Dictionary).get("rolls", {})
	var best := -1
	var out := Vector2i(1, 1)
	for key in rolls:
		var t := int(key)
		if t <= tier and t > best:
			best = t
			var pair: Array = rolls[key]
			out = Vector2i(int(pair[0]), int(pair[1]))
	return out


## The entries available at `tier` (each from its min_tier up).
static func entries_for(id: String, tier: int) -> Array:
	_ensure_loaded()
	var out: Array = []
	for e in (_tables.get(id, {}) as Dictionary).get("entries", []):
		if int((e as Dictionary).get("min_tier", 1)) <= tier:
			out.append(e)
	return out


## Rolls `table_id` at `tier`: [{item_id, count}], merged by item, in first-drawn order.
static func roll(table_id: String, tier: int, rng: RandomNumberGenerator) -> Array:
	_ensure_loaded()
	if not _tables.has(table_id):
		return []
	var table: Dictionary = _tables[table_id]
	var pool := entries_for(table_id, tier)
	var nothing := int(table.get("nothing", 0))
	var total := nothing
	for e in pool:
		total += int(e["weight"])
	if total <= 0:
		return []
	var r := rolls_for(table_id, tier)
	var draws := rng.randi_range(r.x, r.y)
	var counts := {}
	var order: Array[String] = []
	for i in draws:
		var pick := rng.randi_range(0, total - 1)
		if pick < nothing:
			continue
		pick -= nothing
		for e in pool:
			pick -= int(e["weight"])
			if pick < 0:
				var item := String(e["item"])
				var n := rng.randi_range(int(e.get("min", 1)), int(e.get("max", 1)))
				if not counts.has(item):
					order.append(item)
					counts[item] = 0
				counts[item] = int(counts[item]) + n
				break
	var out: Array = []
	for item in order:
		out.append({"item_id": item, "count": int(counts[item])})
	return out


## Expected Credits value of one roll of `table_id` at `tier` (sell values), for balance tests.
static func expected_value(table_id: String, tier: int) -> float:
	_ensure_loaded()
	if not _tables.has(table_id):
		return 0.0
	var pool := entries_for(table_id, tier)
	var total := float(int((_tables[table_id] as Dictionary).get("nothing", 0)))
	for e in pool:
		total += float(e["weight"])
	if total <= 0.0:
		return 0.0
	var per_draw := 0.0
	for e in pool:
		var avg := (float(e.get("min", 1)) + float(e.get("max", 1))) / 2.0
		per_draw += float(e["weight"]) / total * avg * float(ItemDB.sell_value(String(e["item"])))
	var r := rolls_for(table_id, tier)
	return per_draw * (float(r.x) + float(r.y)) / 2.0


static func reload_from_disk() -> void:
	_loaded = false
	_tables = {}
	_ensure_loaded()
