extends "res://tests/test_case.gd"
## Pure farming rules (Phase 3): tillability, growth advancement, watering/wilting, harvest
## yield. See scripts/farm_grid.gd's class doc for the dual-grid tilling and watering/wilting
## design rationale this exercises.

const FarmGridScript := preload("res://scripts/farm_grid.gd")


func test_tillable_terrain() -> void:
	assert_true(FarmGridScript.is_tillable_terrain("."), "grass is tillable")
	assert_true(FarmGridScript.is_tillable_terrain("@"), "spawn cell (grass) is tillable")
	assert_false(FarmGridScript.is_tillable_terrain("f"), "already-tilled farmland is not")
	assert_false(FarmGridScript.is_tillable_terrain("p"), "plank floor is not")
	assert_false(FarmGridScript.is_tillable_terrain("#"), "rubble is not")


func test_advance_plot_grows_when_watered() -> void:
	var plot := {"crop_id": "dustwheat", "stage": 0, "watered": true}
	var next := FarmGridScript.advance_plot(plot, 4)
	assert_eq(next["stage"], 1, "watered crop advances one stage")
	assert_false(next["watered"], "watered flag consumed by the day tick")


func test_advance_plot_wilts_when_unwatered() -> void:
	var plot := {"crop_id": "dustwheat", "stage": 1, "watered": false}
	var next := FarmGridScript.advance_plot(plot, 4)
	assert_true(next.is_empty(), "an unwatered, not-yet-mature crop wilts (checklist's literal rule)")


func test_advance_plot_mature_needs_no_water() -> void:
	var plot := {"crop_id": "dustwheat", "stage": 3, "watered": false}
	var next := FarmGridScript.advance_plot(plot, 4)
	assert_eq(next, plot, "a mature, unwatered crop holds indefinitely rather than wilting")


func test_advance_plot_caps_at_final_stage() -> void:
	var plot := {"crop_id": "dustwheat", "stage": 2, "watered": true}
	var next := FarmGridScript.advance_plot(plot, 4)
	assert_eq(next["stage"], 3, "advancing from the second-to-last stage reaches the final stage")


func test_advance_plot_empty_plot_is_noop() -> void:
	assert_eq(FarmGridScript.advance_plot({}, 5), {})
	assert_eq(FarmGridScript.advance_plot({"crop_id": ""}, 5), {"crop_id": ""})


func test_is_mature() -> void:
	assert_true(FarmGridScript.is_mature({"crop_id": "sunbloom", "stage": 5}, 6))
	assert_false(FarmGridScript.is_mature({"crop_id": "sunbloom", "stage": 4}, 6))
	assert_false(FarmGridScript.is_mature({}, 6), "empty plot is never mature")


func test_harvest_yield_requires_maturity() -> void:
	var crop_def := {"growth_stages": 5, "yield_item": "mutant_potato", "yield_quantity": 1}
	var immature := {"crop_id": "mutant_potato", "stage": 2, "watered": true}
	assert_eq(FarmGridScript.harvest_yield(immature, crop_def), {},
		"can't harvest before the final stage")
	var mature := {"crop_id": "mutant_potato", "stage": 4, "watered": false}
	var result := FarmGridScript.harvest_yield(mature, crop_def)
	assert_eq(result["item_id"], "mutant_potato")
	assert_eq(result["count"], 1)
