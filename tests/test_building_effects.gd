extends "res://tests/test_case.gd"
## Phase 8 Stage 1: pure-function tests for scripts/building_effects.gd —
## recompute_capacity_unlocks(), settler_arrival_modifiers(), and the Rain Collector's
## water-tick selection math. All three are fed plain Dictionaries/Arrays (completed-entry
## shapes, cell lists) with no scene/Node required, matching this codebase's established
## headless-pure-function test convention (tests/test_build_grid.gd, tests/test_farm_grid.gd).

const BuildingEffects := preload("res://scripts/building_effects.gd")


## Minimal completed-entry stand-in: only building_id matters to every function under test here.
static func _entry(building_id: String) -> Dictionary:
	return {"building_id": building_id, "kind": building_id, "top_left": Vector2i.ZERO,
		"size": Vector2i.ONE, "placed_day": 1}


## -- recompute_capacity_unlocks() --

func test_recompute_capacity_unlocks_empty_list_reads_as_all_zero() -> void:
	var out := BuildingEffects.recompute_capacity_unlocks([])
	assert_eq(out, {"population_cap": 0, "energy_max": 0, "build_energy_discount": 0})


func test_recompute_capacity_unlocks_single_shelter_cabin() -> void:
	var out := BuildingEffects.recompute_capacity_unlocks([_entry("shelter_tent")])
	assert_eq(int(out["population_cap"]), 1)
	assert_eq(int(out["energy_max"]), 0)
	assert_eq(float(out["build_energy_discount"]), 0.0)


func test_recompute_capacity_unlocks_sums_across_multiple_completed_structures() -> void:
	var entries := [
		_entry("shelter_tent"), _entry("shelter_tent"),  # 2 cabins -> population_cap 2
		_entry("clinic"),                                 # +10 energy_max
		_entry("solar_panel"),                            # +0.25 build_energy_discount
	]
	var out := BuildingEffects.recompute_capacity_unlocks(entries)
	assert_eq(int(out["population_cap"]), 2)
	assert_eq(int(out["energy_max"]), 10)
	assert_eq(float(out["build_energy_discount"]), 0.25)


func test_recompute_capacity_unlocks_ignores_buildings_with_no_unlock() -> void:
	# Workshop grants a daily_yield, not a capacity_unlock — must contribute nothing here.
	var out := BuildingEffects.recompute_capacity_unlocks(
		[_entry("workshop"), _entry("storage_shed")])
	assert_eq(out, {"population_cap": 0, "energy_max": 0, "build_energy_discount": 0})


func test_recompute_capacity_unlocks_ignores_unknown_building_ids() -> void:
	var out := BuildingEffects.recompute_capacity_unlocks([_entry("not_a_real_building")])
	assert_eq(out, {"population_cap": 0, "energy_max": 0, "build_energy_discount": 0})


func test_recompute_capacity_unlocks_is_pure_recomputation_not_incremental() -> void:
	# Calling twice with the same (smaller) input must give the same result as calling once —
	# proof this never accumulates state across calls (the whole point of "recompute in full").
	var one_cabin := [_entry("shelter_tent")]
	var first := BuildingEffects.recompute_capacity_unlocks(one_cabin)
	var second := BuildingEffects.recompute_capacity_unlocks(one_cabin)
	assert_eq(first, second)


## -- settler_arrival_modifiers() (no consumer yet — Stage 3's arrival roll will use this) --

func test_settler_arrival_modifiers_empty_list_reads_as_zero() -> void:
	var out := BuildingEffects.settler_arrival_modifiers([])
	assert_eq(float(out["arrival_chance_bonus"]), 0.0)
	assert_eq(int(out["cooldown_reduction_days"]), 0)


func test_settler_arrival_modifiers_one_watchtower() -> void:
	var out := BuildingEffects.settler_arrival_modifiers([_entry("watchtower")])
	assert_eq(float(out["arrival_chance_bonus"]), BuildingEffects.WATCHTOWER_ARRIVAL_CHANCE_BONUS)
	assert_eq(int(out["cooldown_reduction_days"]), 0)


func test_settler_arrival_modifiers_two_antenna_towers() -> void:
	var out := BuildingEffects.settler_arrival_modifiers(
		[_entry("antenna_tower"), _entry("antenna_tower")])
	assert_eq(float(out["arrival_chance_bonus"]), 0.0)
	assert_eq(int(out["cooldown_reduction_days"]), 2 * BuildingEffects.ANTENNA_COOLDOWN_REDUCTION_DAYS)


func test_settler_arrival_modifiers_mixed_and_irrelevant_buildings() -> void:
	var entries := [
		_entry("watchtower"), _entry("watchtower"),  # x2 chance bonus
		_entry("antenna_tower"),                      # x1 cooldown reduction
		_entry("shelter_tent"), _entry("storage_shed"), _entry("workshop"),  # no effect field
	]
	var out := BuildingEffects.settler_arrival_modifiers(entries)
	assert_eq(float(out["arrival_chance_bonus"]), 2 * BuildingEffects.WATCHTOWER_ARRIVAL_CHANCE_BONUS)
	assert_eq(int(out["cooldown_reduction_days"]), BuildingEffects.ANTENNA_COOLDOWN_REDUCTION_DAYS)


## -- Rain Collector water-tick math (select_rain_collector_targets — pure cell-list capping) --

func test_select_rain_collector_targets_returns_all_when_under_the_limit() -> void:
	var cells: Array = [Vector2i(1, 1), Vector2i(2, 2)]
	assert_eq(BuildingEffects.select_rain_collector_targets(cells, 3), cells)


func test_select_rain_collector_targets_caps_at_the_limit_in_order() -> void:
	var cells: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	var result := BuildingEffects.select_rain_collector_targets(cells, 3)
	assert_eq(result, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])


func test_select_rain_collector_targets_exact_limit_returns_all() -> void:
	var cells: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	assert_eq(BuildingEffects.select_rain_collector_targets(cells, 3), cells)


func test_select_rain_collector_targets_empty_input_is_empty_output() -> void:
	assert_true(BuildingEffects.select_rain_collector_targets([], 3).is_empty())


func test_select_rain_collector_targets_zero_limit_is_empty_output() -> void:
	var cells: Array = [Vector2i(0, 0), Vector2i(1, 0)]
	assert_true(BuildingEffects.select_rain_collector_targets(cells, 0).is_empty())


func test_rain_collector_default_limit_matches_the_stage_1_plan() -> void:
	# The Stage 1 plan's exact number: up to 3 plots per Rain Collector per morning.
	assert_eq(BuildingEffects.RAIN_COLLECTOR_WATER_LIMIT, 3)
