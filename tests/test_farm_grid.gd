extends "res://tests/test_case.gd"
## scripts/farm_grid.gd — pure plot rules (v2, 2026-10-07): growth in watered days, a dry day
## pauses growth (never kills), seasons wither crops, regrowth, yields.

const FarmGridScript := preload("res://scripts/farm_grid.gd")

## A synthetic 4-stage spring crop (sum 4 days) and a regrowing one, so these tests don't depend
## on the live data file's tuning.
const RADISH := {"name": "Test Radish", "seasons": ["spring"], "stage_days": [1, 1, 1, 1],
	"regrow_days": 0, "yield_item": "rain_radish", "yield_min": 1, "yield_max": 1, "extra_chance": 0.0}
const BERRY := {"name": "Test Berry", "seasons": ["spring", "summer"], "stage_days": [1, 1, 2, 2, 2],
	"regrow_days": 4, "yield_item": "bloodberry", "yield_min": 1, "yield_max": 3, "extra_chance": 0.0}


func test_tillable_terrain() -> void:
	assert_true(FarmGridScript.is_tillable_terrain("."), "grass is tillable")
	assert_true(FarmGridScript.is_tillable_terrain("@"), "spawn cell (grass) is tillable")
	assert_false(FarmGridScript.is_tillable_terrain("f"), "already-tilled farmland is not")
	assert_false(FarmGridScript.is_tillable_terrain("p"), "plank floor is not")
	assert_false(FarmGridScript.is_tillable_terrain("#"), "rubble is not")
	assert_true(FarmGridScript.is_tillable_terrain(","), "overgrown old field is tillable")
	assert_true(FarmGridScript.is_old_field_terrain(","))
	assert_false(FarmGridScript.is_old_field_terrain("."), "plain grass isn't an old field")


func test_new_plot_shape() -> void:
	var plot := FarmGridScript.new_plot("rain_radish", 1)
	assert_eq(plot["growth"], 0)
	assert_eq(plot["stage"], 0)
	assert_eq(plot["fertilizer"], 1)
	assert_false(plot["watered"])
	assert_false(plot["dead"])


func test_watered_plot_grows_one_day() -> void:
	var plot := FarmGridScript.new_plot("rain_radish")
	plot["watered"] = true
	var next := FarmGridScript.advance_plot(plot, RADISH, "spring")
	assert_eq(next["growth"], 1, "a watered day counts")
	assert_eq(next["stage"], 1)
	assert_false(next["watered"], "the morning tick consumes the water")


func test_dry_day_pauses_growth_and_never_kills() -> void:
	var plot := FarmGridScript.new_plot("rain_radish")
	plot["growth"] = 2
	var next := FarmGridScript.advance_plot(plot, RADISH, "spring")
	assert_false(next.is_empty(), "an unwatered crop no longer vanishes overnight")
	assert_eq(next["growth"], 2, "growth simply pauses")
	assert_false(next["dead"], "and nothing dies")


func test_mature_plot_holds_without_water() -> void:
	var plot := FarmGridScript.new_plot("rain_radish")
	plot["growth"] = 4
	assert_true(FarmGridScript.is_mature(plot, RADISH))
	var next := FarmGridScript.advance_plot(plot, RADISH, "spring")
	assert_eq(next["growth"], 4)
	assert_true(FarmGridScript.is_mature(next, RADISH))


func test_out_of_season_crop_withers() -> void:
	var plot := FarmGridScript.new_plot("rain_radish")
	plot["growth"] = 2
	plot["watered"] = true
	var next := FarmGridScript.advance_plot(plot, RADISH, "summer")
	assert_true(next["dead"], "spring crops die when summer arrives")
	assert_false(FarmGridScript.is_mature(next, RADISH), "dead crops are never harvestable")
	var after := FarmGridScript.advance_plot(next, RADISH, "spring")
	assert_true(after["dead"], "a dead crop stays dead")


func test_empty_season_ignores_seasons() -> void:
	var plot := FarmGridScript.new_plot("rain_radish")
	plot["watered"] = true
	var next := FarmGridScript.advance_plot(plot, RADISH, "")
	assert_false(next["dead"])
	assert_eq(next["growth"], 1)


func test_normalize_upgrades_stage_only_plots() -> void:
	var legacy := {"crop_id": "bloodberry", "stage": 3, "watered": true}
	var plot := FarmGridScript.normalize_plot(legacy, BERRY)
	assert_eq(plot["growth"], 4, "stage 3 of [1,1,2,2,2] begins after 4 watered days")
	assert_eq(plot["stage"], 3)
	assert_eq(plot["fertilizer"], 0)
	assert_false(plot["dead"])


func test_empty_plot_is_noop() -> void:
	assert_eq(FarmGridScript.advance_plot({}, RADISH, "spring"), {})
	assert_eq(FarmGridScript.advance_plot({"crop_id": ""}, RADISH, "spring"), {"crop_id": ""})


func test_harvest_requires_maturity() -> void:
	var plot := FarmGridScript.new_plot("rain_radish")
	plot["growth"] = 3
	assert_eq(FarmGridScript.harvest_yield(plot, RADISH), {}, "not before maturity")
	plot["growth"] = 4
	var result := FarmGridScript.harvest_yield(plot, RADISH)
	assert_eq(result["item_id"], "rain_radish")
	assert_eq(result["count"], 1)


func test_harvest_count_range_and_fertilizer_bonus() -> void:
	assert_eq(FarmGridScript.harvest_count(BERRY, 0, 0.0, 1.0), 1, "lowest roll = yield_min")
	assert_eq(FarmGridScript.harvest_count(BERRY, 0, 0.999, 1.0), 3, "highest roll = yield_max")
	assert_eq(FarmGridScript.harvest_count(RADISH, 0, 0.0, 0.1), 1, "no extra without chance")
	assert_eq(FarmGridScript.harvest_count(RADISH, 1, 0.0, 0.1), 2, "basic fertiliser: +15% extra")
	assert_eq(FarmGridScript.harvest_count(RADISH, 2, 0.0, 0.25), 2, "rich fertiliser: +30% extra")
	assert_eq(FarmGridScript.harvest_count(RADISH, 2, 0.0, 0.35), 1, "roll above the chance: no extra")


func test_after_harvest_regrows_or_clears() -> void:
	var radish := FarmGridScript.new_plot("rain_radish")
	radish["growth"] = 4
	assert_eq(FarmGridScript.after_harvest(radish, RADISH), {}, "one-shot crops leave bare soil")
	var berry := FarmGridScript.new_plot("bloodberry", 2)
	berry["growth"] = 8
	var regrown := FarmGridScript.after_harvest(berry, BERRY)
	assert_eq(regrown["growth"], 4, "drops back regrow_days (8 - 4)")
	assert_false(FarmGridScript.is_mature(regrown, BERRY))
	assert_eq(regrown["fertilizer"], 2, "keeps its fertiliser")


func test_needs_water() -> void:
	var plot := FarmGridScript.new_plot("rain_radish")
	assert_true(FarmGridScript.needs_water(plot, RADISH))
	plot["watered"] = true
	assert_false(FarmGridScript.needs_water(plot, RADISH), "already watered")
	plot["watered"] = false
	plot["growth"] = 4
	assert_false(FarmGridScript.needs_water(plot, RADISH), "mature crops don't need water")
	plot["growth"] = 1
	plot["dead"] = true
	assert_false(FarmGridScript.needs_water(plot, RADISH), "dead crops don't need water")
