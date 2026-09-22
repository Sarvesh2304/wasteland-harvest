extends RefCounted
## Data-driven livestock catalog for Phase 8's first Barn/Coop vertical slice.
## The catalog deliberately contains no runtime state; scripts/animals.gd owns purchases, care,
## housing and production, while this loader keeps the shop and tick on identical definitions.

const PATH := "res://data/animals.json"

static var _animals: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_animals = parsed if parsed is Dictionary else {}
	_animals.erase("_comment")


static func ids() -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for key in _animals:
		out.append(String(key))
	return out


static func get_animal(animal_id: String) -> Dictionary:
	_ensure_loaded()
	return _animals.get(animal_id, {})


static func has_animal(animal_id: String) -> bool:
	_ensure_loaded()
	return _animals.has(animal_id)


static func display_name(animal_id: String) -> String:
	return String(get_animal(animal_id).get("name", ""))


static func housing(animal_id: String) -> String:
	return String(get_animal(animal_id).get("housing", ""))


static func is_normal(animal_id: String) -> bool:
	return bool(get_animal(animal_id).get("normal", false))


static func price(animal_id: String) -> int:
	return maxi(0, int(get_animal(animal_id).get("price", 0)))


static func yield_item(animal_id: String) -> String:
	return String(get_animal(animal_id).get("yield_item", ""))


static func yield_count(animal_id: String) -> int:
	return maxi(0, int(get_animal(animal_id).get("yield_count", 0)))


static func description(animal_id: String) -> String:
	return String(get_animal(animal_id).get("description", ""))


static func reload_from_disk() -> void:
	_loaded = false
	_ensure_loaded()
