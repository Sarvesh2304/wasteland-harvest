extends RefCounted
## data/world_objects.json access plus the pure rules for hitting, breaking and picking world
## objects (trees, stumps, rocks, scrap, weeds, branches, junk, forage). scripts/world_objects.gd
## is the stateful per-zone node that applies them. See the JSON's _comment for the schema.

const PATH := "res://data/world_objects.json"

## Hit outcomes returned by tool_effect().
const HIT := "hit"
const WRONG_TOOL := "wrong_tool"
const TOO_WEAK := "too_weak"

## Tool kinds that can clear 'any'-tool debris (weeds). The watering can is deliberately absent.
const CLEARING_TOOLS: Array[String] = ["hoe", "axe", "pickaxe", "scythe", "weapon"]

static var _kinds: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_kinds = parsed if parsed is Dictionary else {}
	_kinds.erase("_comment")


static func get_kind(kind: String) -> Dictionary:
	_ensure_loaded()
	return _kinds.get(kind, {})


static func has_kind(kind: String) -> bool:
	_ensure_loaded()
	return _kinds.has(kind)


static func all_kinds() -> Dictionary:
	_ensure_loaded()
	return _kinds


static func display_name(kind: String) -> String:
	return String(get_kind(kind).get("name", kind))


static func size_of(kind: String) -> Vector2i:
	var s = get_kind(kind).get("size", [1, 1])
	if s is Array and (s as Array).size() == 2:
		return Vector2i(int(s[0]), int(s[1]))
	return Vector2i.ONE


static func is_solid(kind: String) -> bool:
	return bool(get_kind(kind).get("solid", true))


static func tool_of(kind: String) -> String:
	return String(get_kind(kind).get("tool", ""))


static func hp_of(kind: String) -> int:
	return maxi(int(get_kind(kind).get("hp", 1)), 1)


static func min_tier(kind: String) -> int:
	return maxi(int(get_kind(kind).get("min_tier", 1)), 1)


static func variant_count(kind: String) -> int:
	return maxi(int(get_kind(kind).get("variants", 1)), 1)


static func is_forage(kind: String) -> bool:
	return tool_of(kind) == "hand"


static func forage_item(kind: String) -> String:
	return String(get_kind(kind).get("forage_item", ""))


static func becomes(kind: String) -> String:
	return String(get_kind(kind).get("becomes", ""))


static func falls(kind: String) -> bool:
	return bool(get_kind(kind).get("fall", false))


static func xp_of(kind: String) -> Dictionary:
	var xp = get_kind(kind).get("xp", {})
	return xp if xp is Dictionary else {}


static func sound_hit(kind: String) -> String:
	return String(get_kind(kind).get("sound_hit", ""))


static func sound_break(kind: String) -> String:
	return String(get_kind(kind).get("sound_break", ""))


## Sprite path with {season} and {v} substituted (variant is 1-based in file names).
static func sprite_path(kind: String, season: String, variant: int) -> String:
	var path := String(get_kind(kind).get("sprite", ""))
	return path.replace("{season}", season).replace("{v}", str(clampi(variant, 1, variant_count(kind))))


## Kinds whose spawn_on matches `layer` ("debris", "forage_spring", ...), in data order.
static func kinds_spawning_on(layer: String) -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for kind in _kinds:
		if String(_kinds[kind].get("spawn_on", "")) == layer:
			out.append(String(kind))
	return out


## Whether swinging `tool_kind` (a farming tool kind, or "weapon") of `tier` at this object does
## anything: HIT, WRONG_TOOL or TOO_WEAK. The scythe also cuts 'any'-tool debris and tall grass.
static func tool_effect(kind: String, tool_kind: String, tier: int) -> String:
	var needed := tool_of(kind)
	if needed == "" or needed == "hand" or tool_kind == "":
		return WRONG_TOOL
	if needed == "any":
		return HIT if CLEARING_TOOLS.has(tool_kind) else WRONG_TOOL
	if needed != tool_kind:
		return WRONG_TOOL
	if tier < min_tier(kind):
		return TOO_WEAK
	return HIT


## Damage one swing deals: the tool tier (Rusty 1 ... Pre-War 4).
static func damage_for_tier(tier: int) -> int:
	return clampi(tier, 1, 4)


## Rolls a kind's drop table. `rng` supplies randomness so callers/tests control determinism.
static func roll_drops(kind: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var drops = get_kind(kind).get("drops", [])
	if not (drops is Array):
		return out
	for d in drops:
		if not (d is Dictionary):
			continue
		var chance := float(d.get("chance", 1.0))
		if chance < 1.0 and rng.randf() >= chance:
			continue
		var lo := int(d.get("min", 1))
		var hi := maxi(int(d.get("max", lo)), lo)
		var count := rng.randi_range(lo, hi)
		if count > 0:
			out.append({"item_id": String(d.get("item", "")), "count": count})
	return out


static func reload_from_disk() -> void:
	_loaded = false
	_ensure_loaded()
