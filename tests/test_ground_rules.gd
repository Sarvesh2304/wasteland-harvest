extends "res://tests/test_case.gd"
## scripts/ground_rules.gd — the pure painting rules behind the 2026-10-07 terrain renderer.

const GroundRules := preload("res://scripts/ground_rules.gd")
const ForestEdgeLayout := preload("res://scripts/map_layouts/forest_edge_layout.gd")
const TownRiversideLayout := preload("res://scripts/map_layouts/town_layout_riverside.gd")
const PathStandardLayout := preload("res://scripts/map_layouts/path_layout_standard.gd")


func test_corner_masks_follow_the_sheet_contract() -> void:
	assert_eq(GroundRules.corner_mask(false, false, false, false), 0)
	assert_eq(GroundRules.corner_mask(true, false, false, false), 8, "NW = 8")
	assert_eq(GroundRules.corner_mask(false, true, false, false), 4, "NE = 4")
	assert_eq(GroundRules.corner_mask(false, false, true, false), 2, "SW = 2")
	assert_eq(GroundRules.corner_mask(false, false, false, true), 1, "SE = 1")
	assert_eq(GroundRules.corner_mask(true, true, true, true), GroundRules.FULL)
	assert_eq(GroundRules.overlay_atlas(6), Vector2i(2, 1), "mask m sits at column m % 4, row m / 4")
	assert_eq(GroundRules.overlay_atlas(15), Vector2i(3, 3))


func test_visual_mask_samples_the_four_cells_around_a_corner() -> void:
	var soil := {Vector2i(5, 5): true}
	var is_in := func(c: Vector2i) -> bool: return soil.has(c)
	# Visual tile (5,5) has the soil cell in its SE corner; (6,6) has it in its NW corner.
	assert_eq(GroundRules.visual_mask(Vector2i(5, 5), is_in), GroundRules.SE)
	assert_eq(GroundRules.visual_mask(Vector2i(6, 5), is_in), GroundRules.SW)
	assert_eq(GroundRules.visual_mask(Vector2i(5, 6), is_in), GroundRules.NE)
	assert_eq(GroundRules.visual_mask(Vector2i(6, 6), is_in), GroundRules.NW)
	assert_eq(GroundRules.visual_mask(Vector2i(8, 8), is_in), 0)
	var touching := GroundRules.visuals_touching(Vector2i(5, 5))
	assert_eq(touching.size(), 4)
	for v in touching:
		assert_ne(GroundRules.visual_mask(v, is_in), 0, "visual %s touches the cell" % v)


func test_fence_masks_and_regions() -> void:
	assert_eq(GroundRules.fence_mask(true, false, false, false), 1, "N = 1")
	assert_eq(GroundRules.fence_mask(false, true, false, true), 10, "E + W = a straight rail")
	assert_eq(GroundRules.fence_region(0), Rect2i(0, 0, 16, 32))
	assert_eq(GroundRules.fence_region(10), Rect2i(32, 64, 16, 32))


func test_variants_are_deterministic_and_in_range() -> void:
	for x in 20:
		var c := Vector2i(x, 3)
		var v := GroundRules.variant(c, 5, 4)
		assert_true(v >= 0 and v < 4)
		assert_eq(GroundRules.variant(c, 5, 4), v, "same cell, same pick")
		var w := GroundRules.weighted_variant(c, 3, GroundRules.GRASS_VARIANT_WEIGHTS)
		assert_true(w >= 0 and w < GroundRules.GRASS_VARIANT_WEIGHTS.size())
	assert_eq(GroundRules.variant(Vector2i(1, 1), 5, 1), 0)


func test_decor_names_point_at_real_art() -> void:
	for season in ["spring", "summer", "autumn", "winter"]:
		for x in 60:
			for old_field in [false, true]:
				var name := GroundRules.decor_for(Vector2i(x, 7), season, old_field)
				if name != "":
					assert_true(ResourceLoader.exists("res://art/env/decor/%s.png" % name),
						"decor %s exists" % name)


func test_old_fields_get_more_decor_than_grass() -> void:
	var grass := 0
	var field := 0
	for x in 200:
		if GroundRules.decor_for(Vector2i(x, 11), "spring", false) != "":
			grass += 1
		if GroundRules.decor_for(Vector2i(x, 11), "spring", true) != "":
			field += 1
	assert_true(field > grass * 2, "old fields are rough (%d vs %d of 200)" % [field, grass])


func test_planks_vs_road() -> void:
	var fe := GroundRules.classify_planks(ForestEdgeLayout)
	var bridge_cells: Dictionary = fe["planks"]
	for x in [6, 7, 8, 9]:
		assert_true(bridge_cells.has(Vector2i(x, 21)), "the creek footbridge (%d,21) is decking" % x)
	assert_eq(bridge_cells[Vector2i(7, 21)], "v", "an east-west footbridge has north-south boards")
	assert_true((fe["bridge"] as Dictionary).has(Vector2i(7, 21)), "water flows under mid-bridge")
	assert_false((fe["bridge"] as Dictionary).has(Vector2i(6, 21)), "but not under the abutment")
	assert_true((fe["road"] as Dictionary).has(Vector2i(20, 15)), "the buried main street is road")
	var town := GroundRules.classify_planks(TownRiversideLayout)
	assert_true((town["planks"] as Dictionary).has(Vector2i(1, 4)),
		"the river-gate landing (diagonal to the water) is decking")
	var path := GroundRules.classify_planks(PathStandardLayout)
	assert_true((path["planks"] as Dictionary).is_empty(), "the dry highway has no decking")
	assert_true((path["road"] as Dictionary).size() > 30, "it's all road")
