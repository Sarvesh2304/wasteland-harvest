extends "res://tests/test_case.gd"
## data/crops.json loading (Phase 3's 4 post-apoc crops). Confirms the file parses and every
## crop's stage count sits in the checklist's 4-6 range.

const CropDBScript := preload("res://scripts/crop_db.gd")


func test_loads_all_four_crops() -> void:
	var crops := CropDBScript.all_crops()
	assert_eq(crops.size(), 4)
	for expected in ["mutant_potato", "dustwheat", "ironroot", "sunbloom"]:
		assert_true(crops.has(expected), "missing crop %s" % expected)


func test_growth_stages_within_checklist_range() -> void:
	for crop_id in CropDBScript.all_crops():
		var stages := CropDBScript.growth_stages(crop_id)
		assert_true(stages >= 4 and stages <= 6,
			"%s has %d stages, expected 4-6 per ROADMAP.md Phase 3" % [crop_id, stages])


func test_stage_texture_path_format() -> void:
	var path := CropDBScript.stage_texture_path("dustwheat", 2)
	assert_eq(path, "res://art/crops/dustwheat/stage_2.png")


func test_yield_fields_present() -> void:
	for crop_id in CropDBScript.all_crops():
		var crop: Dictionary = CropDBScript.get_crop(crop_id)
		assert_true(crop.has("yield_item"), "%s missing yield_item" % crop_id)
		assert_true(int(crop.get("yield_quantity", 0)) > 0, "%s needs a positive yield_quantity" % crop_id)
