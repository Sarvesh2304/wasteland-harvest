extends Node
## Settlement-wide livestock state (Phase 8 first complete vertical slice).
##
## Animals never die or disappear in this slice. A normal animal produces only when it was
## cared for on the previous in-game day; a mutant animal still produces after missed care,
## making the two catalog families a deterministic value/hardiness choice rather than a grim
## failure state. Production runs after Structures' day_started handler, so constructions
## completing this morning can house purchases from the next morning onward.

signal animal_yield_produced(items: Dictionary)
signal animal_purchased(animal_id: String)

const AnimalDB := preload("res://scripts/animal_db.gd")
const BuildingDB := preload("res://scripts/building_db.gd")

var _animals: Array[Dictionary] = []
var _completed_entries_provider: Callable
var _test_housing_entries: Array = []
var _using_test_entries := false


func _ready() -> void:
	DayManager.day_started.connect(_on_day_started)


func set_completed_entries_provider(provider: Callable) -> void:
	_completed_entries_provider = provider


## Headless tests can provide completed structures without booting Main's four maps.
func set_housing_entries_for_testing(entries: Array) -> void:
	_test_housing_entries = entries
	_using_test_entries = true


func clear_housing_entries_for_testing() -> void:
	_test_housing_entries.clear()
	_using_test_entries = false


func animals() -> Array[Dictionary]:
	return _animals.duplicate(true)


func animal_count() -> int:
	return _animals.size()


func capacity_for(housing: String) -> int:
	var total := 0
	for entry in _housing_entries():
		if BuildingDB.animal_housing(String(entry.get("building_id", ""))) == housing:
			total += BuildingDB.animal_capacity(String(entry.get("building_id", "")))
	return total


func occupied_capacity_for(housing: String) -> int:
	var count := 0
	for animal in _animals:
		if AnimalDB.housing(String(animal.get("animal_id", ""))) == housing:
			count += 1
	return count


func available_capacity_for(housing: String) -> int:
	return maxi(0, capacity_for(housing) - occupied_capacity_for(housing))


func has_available_housing(animal_id: String) -> bool:
	if not AnimalDB.has_animal(animal_id):
		return false
	return available_capacity_for(AnimalDB.housing(animal_id)) > 0


## Returns {ok, reason, remaining_credits}. The caller owns the player's Credits mutation so this
## method is useful both to the modal and to deterministic headless tests.
func attempt_purchase(animal_id: String, credits: int) -> Dictionary:
	if not AnimalDB.has_animal(animal_id):
		return {"ok": false, "reason": "unknown_animal", "remaining_credits": credits}
	var price := AnimalDB.price(animal_id)
	if credits < price:
		return {"ok": false, "reason": "not_enough_credits", "remaining_credits": credits}
	var housing := AnimalDB.housing(animal_id)
	var housing_index := _first_available_housing_index(housing)
	if housing_index < 0:
		return {"ok": false, "reason": "no_capacity", "remaining_credits": credits}
	_animals.append({
		"animal_id": animal_id,
		"housing": housing,
		"housing_index": housing_index,
		"last_care_day": 0,
	})
	animal_purchased.emit(animal_id)
	return {"ok": true, "reason": "", "remaining_credits": credits - price}


func care_all(day: int = -1) -> int:
	var care_day := DayManager.day if day < 0 else day
	for animal in _animals:
		animal["last_care_day"] = care_day
	return _animals.size()


func _on_day_started(day: int) -> void:
	if _animals.is_empty():
		return
	var yields := {}
	for animal in _animals:
		var animal_id := String(animal.get("animal_id", ""))
		if not AnimalDB.has_animal(animal_id):
			continue
		var cared_yesterday := int(animal.get("last_care_day", 0)) == day - 1
		if AnimalDB.is_normal(animal_id) and not cared_yesterday:
			animal["last_care_day"] = 0
			continue
		var item_id := AnimalDB.yield_item(animal_id)
		var count := AnimalDB.yield_count(animal_id)
		if not item_id.is_empty() and count > 0:
			yields[item_id] = int(yields.get(item_id, 0)) + count
		# Care is a per-day action. Mutant production still succeeds, but neither family carries
		# yesterday's care forward indefinitely.
		animal["last_care_day"] = 0
	if not yields.is_empty():
		animal_yield_produced.emit(yields)


func save_state() -> Dictionary:
	var out: Array = []
	for animal in _animals:
		out.append({
			"animal_id": String(animal.get("animal_id", "")),
			"housing": String(animal.get("housing", "")),
			"housing_index": int(animal.get("housing_index", -1)),
			"last_care_day": int(animal.get("last_care_day", 0)),
		})
	return {"animals": out}


func load_state(data: Dictionary) -> void:
	_animals.clear()
	for raw in data.get("animals", []):
		if not raw is Dictionary:
			continue
		var animal_id := String(raw.get("animal_id", ""))
		if not AnimalDB.has_animal(animal_id):
			continue
		_animals.append({
			"animal_id": animal_id,
			"housing": String(raw.get("housing", AnimalDB.housing(animal_id))),
			"housing_index": int(raw.get("housing_index", -1)),
			"last_care_day": int(raw.get("last_care_day", 0)),
		})


func _housing_entries() -> Array:
	if _using_test_entries:
		return _test_housing_entries
	if _completed_entries_provider.is_valid():
		return _completed_entries_provider.call()
	return []


func _first_available_housing_index(housing: String) -> int:
	var entries := _housing_entries()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		if BuildingDB.animal_housing(String(entry.get("building_id", ""))) != housing:
			continue
		var capacity := BuildingDB.animal_capacity(String(entry.get("building_id", "")))
		var used := 0
		# Index assignment is deterministic, while the count guard also keeps old saves with
		# missing indices safe and capacity-limited.
		for animal in _animals:
			if int(animal.get("housing_index", -1)) == i:
				used += 1
		if used < capacity:
			return i
	return -1
