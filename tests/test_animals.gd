extends "res://tests/test_case.gd"
## Focused Phase 8 livestock contract tests: capacity, Credits, exact yields, care hardness,
## deterministic first-compatible housing assignment, daily ordering, and persistence.

const AnimalsScript := preload("res://scripts/animals.gd")
const AnimalDB := preload("res://scripts/animal_db.gd")
const SaveData := preload("res://scripts/save_data.gd")


static func _entry(building_id: String) -> Dictionary:
	return {"building_id": building_id}


func _make_animals(entries: Array) -> Node:
	var animals: Node = AnimalsScript.new()
	animals.set_housing_entries_for_testing(entries)
	return animals


func test_purchase_deducts_exact_credits_and_rejects_full_capacity() -> void:
	var animals := _make_animals([_entry("coop")])
	var first: Dictionary = animals.attempt_purchase("normal_chicken", 200)
	assert_true(first["ok"])
	assert_eq(first["remaining_credits"], 90)
	for i in 3:
		assert_true(animals.attempt_purchase("mutant_chicken", 1000)["ok"])
	var full: Dictionary = animals.attempt_purchase("mutant_chicken", 1000)
	assert_false(full["ok"])
	assert_eq(full["reason"], "no_capacity")
	assert_eq(animals.animal_count(), 4)
	animals.free()


func test_incompatible_housing_is_rejected_without_spending() -> void:
	var animals := _make_animals([_entry("barn")])
	var result: Dictionary = animals.attempt_purchase("normal_chicken", 1000)
	assert_false(result["ok"])
	assert_eq(result["reason"], "no_capacity")
	assert_eq(result["remaining_credits"], 1000)
	animals.free()


func test_normal_needs_care_but_mutant_produces_after_missed_care() -> void:
	var animals := _make_animals([_entry("barn"), _entry("coop")])
	assert_true(animals.attempt_purchase("normal_cow", 1000)["ok"])
	assert_true(animals.attempt_purchase("mutant_goat", 1000)["ok"])
	var produced: Array[Dictionary] = []
	animals.animal_yield_produced.connect(func(items: Dictionary) -> void: produced.append(items))
	animals._on_day_started(2)
	assert_eq(produced, [{"mutant_goat_milk": 1}])
	animals.care_all(2)
	animals._on_day_started(3)
	assert_eq(produced, [{"mutant_goat_milk": 1}, {"milk": 1, "mutant_goat_milk": 1}])
	animals.free()


func test_save_data_round_trip_preserves_animal_state() -> void:
	var encoded := SaveData.encode_animals({
		"animals": [{
			"animal_id": "normal_chicken", "housing": "coop",
			"housing_index": 2, "last_care_day": 7,
		}],
	})
	var decoded := SaveData.decode_animals(encoded)
	assert_eq(decoded, encoded)
	assert_eq(AnimalDB.yield_item("normal_chicken"), "egg")


func test_manager_save_load_round_trip_preserves_owned_animal() -> void:
	var source := _make_animals([_entry("coop")])
	source.attempt_purchase("normal_chicken", 500)
	source.care_all(7)
	var restored := _make_animals([_entry("coop")])
	restored.load_state(source.save_state())
	assert_eq(restored.animals(), source.animals())
	source.free()
	restored.free()
