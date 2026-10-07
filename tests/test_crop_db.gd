extends "res://tests/test_case.gd"
## data/crops.json + scripts/crop_db.gd (v2, 2026-10-07).

const CropDBScript := preload("res://scripts/crop_db.gd")
const ItemDBScript := preload("res://scripts/item_db.gd")
const Calendar := preload("res://scripts/calendar.gd")


func test_roster_covers_every_season() -> void:
	var crops := CropDBScript.all_crops()
	assert_true(crops.size() >= 12, "at least 12 crops (got %d)" % crops.size())
	for season in Calendar.SEASONS:
		assert_true(CropDBScript.crops_for_season(season).size() >= 1, "%s has crops" % season)
	for season in ["spring", "summer", "autumn"]:
		assert_true(CropDBScript.crops_for_season(season).size() >= 4,
			"%s has at least 4 crops" % season)


func test_original_four_crops_still_exist() -> void:
	for expected in ["mutant_potato", "dustwheat", "ironroot", "sunbloom"]:
		assert_true(CropDBScript.has_crop(expected), "missing crop %s" % expected)


func test_growth_stages_within_range() -> void:
	for crop_id in CropDBScript.all_crops():
		var stages := CropDBScript.growth_stages(crop_id)
		assert_true(stages >= 4 and stages <= 7,
			"%s has %d stages, expected 4-7" % [crop_id, stages])


func test_every_crop_links_seed_and_yield_items() -> void:
	for crop_id in CropDBScript.all_crops():
		var crop: Dictionary = CropDBScript.get_crop(crop_id)
		var yield_item := String(crop.get("yield_item", ""))
		var seed_item := String(crop.get("seed_item", ""))
		assert_true(ItemDBScript.has_item(yield_item), "%s yields a real item (%s)" % [crop_id, yield_item])
		assert_true(ItemDBScript.is_seed(seed_item), "%s has a real seed item (%s)" % [crop_id, seed_item])
		assert_eq(CropDBScript.crop_for_seed(seed_item), crop_id, "seed -> crop lookup")
		assert_true(int(crop.get("yield_min", 0)) >= 1, "%s yields at least one" % crop_id)


func test_stage_for_growth_follows_stage_days() -> void:
	# mutant_potato: [1, 1, 2, 2] -> stages begin at 0, 1, 2, 4, mature at 6.
	assert_eq(CropDBScript.total_days("mutant_potato"), 6)
	assert_eq(CropDBScript.stage_for_growth("mutant_potato", 0), 0)
	assert_eq(CropDBScript.stage_for_growth("mutant_potato", 1), 1)
	assert_eq(CropDBScript.stage_for_growth("mutant_potato", 3), 2)
	assert_eq(CropDBScript.stage_for_growth("mutant_potato", 4), 3)
	assert_eq(CropDBScript.stage_for_growth("mutant_potato", 6), 4)
	assert_eq(CropDBScript.growth_at_stage("mutant_potato", 3), 4)


func test_every_crop_profits_over_one_season() -> void:
	# Planted on day 1 of its season and harvested every time it matures, a crop's minimum
	# yield must beat its seed price — regrowers by many harvests, one-shots in one.
	for crop_id in CropDBScript.all_crops():
		var crop: Dictionary = CropDBScript.get_crop(crop_id)
		var seed_price := ItemDBScript.buy_price(String(crop["seed_item"]))
		var unit := ItemDBScript.sell_value(String(crop["yield_item"]))
		var total := CropDBScript.total_days(crop_id)
		var regrow := CropDBScript.regrow_days(crop_id)
		var harvests := 1
		if regrow > 0:
			harvests += int((28 - total) / regrow)
		var season_value := harvests * unit * int(crop.get("yield_min", 1))
		assert_true(season_value > seed_price,
			"%s: %d harvest(s) worth %d vs seed %d" % [crop_id, harvests, season_value, seed_price])
		assert_true(total <= 27, "%s matures within one 28-day season" % crop_id)


func test_stage_texture_path_format() -> void:
	var path := CropDBScript.stage_texture_path("dustwheat", 2)
	assert_eq(path, "res://art/crops/dustwheat/stage_2.png")


func test_season_queries() -> void:
	assert_true(CropDBScript.grows_in_season("rain_radish", "spring"))
	assert_false(CropDBScript.grows_in_season("rain_radish", "summer"))
	assert_true(CropDBScript.grows_in_season("dust_corn", "summer"))
	assert_true(CropDBScript.grows_in_season("dust_corn", "autumn"))
	assert_true(CropDBScript.grows_in_season("rain_radish", ""), "no season = no restriction")
