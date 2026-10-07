extends RefCounted
## Machine recipes (data/machines.json, Milestone B 2026-10-07): what each placed machine accepts
## and makes, and how long it takes. Static and pure; scripts/world_objects.gd runs the machines.

const PATH := "res://data/machines.json"

static var _machines: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and parsed.get("machines") is Dictionary:
		_machines = parsed["machines"]


static func all_machines() -> Dictionary:
	_ensure_loaded()
	return _machines


static func has_machine(id: String) -> bool:
	_ensure_loaded()
	return _machines.has(id)


static func display_name(id: String) -> String:
	_ensure_loaded()
	return String(_machines.get(id, {}).get("name", id.capitalize()))


static func recipes(id: String) -> Array:
	_ensure_loaded()
	var r = _machines.get(id, {}).get("recipes", [])
	return r if r is Array else []


## The recipe `id` uses for `item_id` ({} = it doesn't take that item).
static func recipe_for(id: String, item_id: String) -> Dictionary:
	for r in recipes(id):
		if (r.get("inputs", []) as Array).has(item_id):
			return r
	return {}


static func accepts(id: String, item_id: String) -> bool:
	return not recipe_for(id, item_id).is_empty()


## A passive producer's rule ({} for machines you load by hand).
static func produces(id: String) -> Dictionary:
	_ensure_loaded()
	var p = _machines.get(id, {}).get("produces", {})
	return p if p is Dictionary else {}


## Pure: whether a loaded batch can start — enough of the input (and fuel) in hand.
static func can_load(recipe: Dictionary, input_have: int, fuel_have: int) -> bool:
	if recipe.is_empty():
		return false
	if input_have < int(recipe.get("count", 1)):
		return false
	if String(recipe.get("fuel", "")) != "" and fuel_have < int(recipe.get("fuel_count", 1)):
		return false
	return true


## Pure: an absolute game-minute clock (day 1, 6:00 AM = 360) so batches survive sleep.
static func absolute_minutes(day: int, minutes_into_day: float) -> int:
	return (maxi(day, 1) - 1) * 1440 + int(minutes_into_day)


## Pure: whether a passive producer makes something this morning.
static func passive_due(rule: Dictionary, days_since: int, weather: String) -> bool:
	if rule.is_empty():
		return false
	var every := int(rule.get("every_days", 0))
	if every > 0 and days_since < every:
		return false
	var wants = rule.get("weather", [])
	if wants is Array and not (wants as Array).is_empty() and not (wants as Array).has(weather):
		return false
	return true
