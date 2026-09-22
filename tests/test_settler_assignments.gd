extends "res://tests/test_case.gd"
## Phase 8 Stage 4 vertical slice: data-driven building compatibility, assignment capacity,
## JSON persistence, safe weekly wage math, and the real farm-labor call order. The fake nodes
## below expose the same public APIs used by scripts/settlers.gd, keeping this test headless while
## still exercising the assignment coordinator rather than a duplicate test-only algorithm.

const SettlersScript := preload("res://scripts/settlers.gd")
const SaveData := preload("res://scripts/save_data.gd")


class FakeStructures:
	extends Node
	var entries: Array[Dictionary] = []

	func completed_entries() -> Array[Dictionary]:
		return entries


class FakePlayer:
	extends Node
	var credits := 0


class FakeFarm:
	extends Node
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var plots := {Vector2i(0, 0): {"crop_id": "mutant_potato", "stage": 4, "watered": false}}
	var calls: Array[String] = []

	func labor_cells() -> Array[Vector2i]:
		return cells

	func can_harvest(cell: Vector2i) -> bool:
		return cell == Vector2i(0, 0) and not plots.get(cell, {}).is_empty()

	func harvest(cell: Vector2i) -> Dictionary:
		calls.append("harvest")
		plots.erase(cell)
		return {"item_id": "mutant_potato", "count": 1}

	func can_water(cell: Vector2i) -> bool:
		return cell == Vector2i(2, 0)

	func water(cell: Vector2i) -> bool:
		calls.append("water")
		return true

	func get_plot(cell: Vector2i) -> Dictionary:
		return plots.get(cell, {})

	func can_till(cell: Vector2i) -> bool:
		return cell == Vector2i(1, 0)

	func till(cell: Vector2i) -> bool:
		calls.append("till")
		return true

	func can_plant(cell: Vector2i) -> bool:
		return cell == Vector2i(1, 0)

	func plant(cell: Vector2i, _crop_id: String) -> bool:
		calls.append("plant")
		plots[cell] = {"crop_id": "mutant_potato", "stage": 0, "watered": false}
		return true


class FakeMain:
	extends Node
	var player: FakePlayer
	var farm: FakeFarm
	var structures: FakeStructures
	var zones := {}

	func _init() -> void:
		player = FakePlayer.new()
		farm = FakeFarm.new()
		structures = FakeStructures.new()
		add_child(player)
		add_child(farm)
		add_child(structures)
		zones = {"farm": {"farm": farm, "structures": structures}}

	func _all_completed_entries() -> Array:
		return structures.entries


class SignalReceiver:
	extends Node
	var yielded := {}
	var charged := 0

	func on_yield(items: Dictionary) -> void:
		yielded = items

	func on_salary(amount: int) -> void:
		charged += amount


func _entry(id: String, cell: Vector2i) -> Dictionary:
	return {"building_id": id, "kind": id, "top_left": cell, "size": Vector2i.ONE, "placed_day": 1}


func _make_settlers() -> Dictionary:
	var main := FakeMain.new()
	main.structures.entries = [_entry("greenhouse", Vector2i(4, 4))]
	var settlers := SettlersScript.new()
	settlers._main = main
	settlers.roster = [{
		"id": "settler_1", "name": "Ellery", "home_cell": Vector2i.ZERO,
		"assigned_building": {},
	}]
	return {"main": main, "settlers": settlers}


func _free_env(env: Dictionary) -> void:
	(env["settlers"] as Node).free()
	(env["main"] as Node).free()


func test_building_schema_exposes_a_farm_laborer_contract() -> void:
	var env := _make_settlers()
	var settlers = env["settlers"]
	var options: Array[Dictionary] = settlers.assignment_options_for_settler("settler_1")
	assert_eq(options.size(), 1)
	assert_eq(options[0]["building_id"], "greenhouse")
	assert_eq(options[0]["role"], "farm_laborer")
	_free_env(env)


func test_assignment_and_capacity_are_enforced_and_unassignment_is_reversible() -> void:
	var env := _make_settlers()
	var settlers = env["settlers"]
	var ref: Dictionary = settlers.assignment_options_for_settler("settler_1")[0]
	assert_true(settlers.assign_settler("settler_1", ref))
	assert_eq(settlers.roster[0]["assigned_building"]["top_left"], Vector2i(4, 4))
	settlers.roster.append({
		"id": "settler_2", "name": "Doss", "home_cell": Vector2i.ONE,
		"assigned_building": {},
	})
	assert_false(settlers.assign_settler("settler_2", ref), "one greenhouse has one labor slot")
	assert_true(settlers.unassign_settler("settler_1"))
	assert_true(settlers.roster[0]["assigned_building"].is_empty())
	assert_true(settlers.assign_settler("settler_2", ref), "slot is reusable after unassignment")
	_free_env(env)


func test_assignment_reference_round_trips_through_save_data() -> void:
	var saved := SaveData.encode_settlers(3, [{
		"id": "settler_1", "name": "Ellery", "home_cell": Vector2i(2, 3),
		"assigned_building": {
			"zone_id": "farm", "building_id": "greenhouse", "top_left": Vector2i(4, 4),
		},
	}], {}, 7)
	var decoded := SaveData.decode_settlers(saved)
	assert_eq(decoded["next_salary_day"], 7)
	assert_eq(decoded["roster"][0]["assigned_building"]["zone_id"], "farm")
	assert_eq(decoded["roster"][0]["assigned_building"]["top_left"], Vector2i(4, 4))


func test_farm_laborer_runs_harvest_water_till_and_plant_in_order() -> void:
	var env := _make_settlers()
	var settlers = env["settlers"]
	var ref: Dictionary = settlers.assignment_options_for_settler("settler_1")[0]
	assert_true(settlers.assign_settler("settler_1", ref))
	var receiver := SignalReceiver.new()
	settlers.labor_yield_produced.connect(receiver.on_yield)
	settlers._process_assignments(1)
	assert_eq(receiver.yielded, {"mutant_potato": 1})
	assert_eq((env["main"] as FakeMain).farm.calls, ["harvest", "water", "till", "plant"])
	receiver.free()
	_free_env(env)


func test_weekly_salary_only_charges_available_credits() -> void:
	var env := _make_settlers()
	var settlers = env["settlers"]
	var ref: Dictionary = settlers.assignment_options_for_settler("settler_1")[0]
	assert_true(settlers.assign_settler("settler_1", ref))
	(env["main"] as FakeMain).player.credits = 5
	var receiver := SignalReceiver.new()
	settlers.salary_charged.connect(receiver.on_salary)
	settlers.next_salary_day = 7
	settlers._process_assignments(7)
	assert_eq(receiver.charged, -5, "the 20-Credit wage is capped at the available balance")
	assert_true((env["main"] as FakeMain).player.credits >= 0)
	assert_eq(settlers.next_salary_day, 14, "payday advances exactly once")
	receiver.free()
	_free_env(env)


func test_salary_math_clamps_negative_inputs_without_a_fail_state() -> void:
	assert_eq(SettlersScript.safe_salary_payment(-10, 20),
		{"paid": 0, "remaining": 0, "shortfall": 20})
	assert_eq(SettlersScript.safe_salary_payment(100, -3),
		{"paid": 0, "remaining": 100, "shortfall": 0})
