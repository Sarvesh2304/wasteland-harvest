extends "res://tests/test_case.gd"
## data/world_objects.json + scripts/world_object_db.gd — what each world object is, which tool
## breaks it, what it drops.

const WorldObjectDB := preload("res://scripts/world_object_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")


func test_every_kind_is_well_formed() -> void:
	var kinds := WorldObjectDB.all_kinds()
	assert_true(kinds.size() >= 20, "a full set of world objects (got %d)" % kinds.size())
	for kind in kinds:
		assert_true(WorldObjectDB.display_name(kind) != "", "%s has a name" % kind)
		assert_true(WorldObjectDB.hp_of(kind) >= 1, "%s has HP" % kind)
		assert_true(WorldObjectDB.tool_of(kind) != "", "%s names its tool" % kind)
		assert_true(WorldObjectDB.sprite_path(kind, "spring", 1).begins_with("res://art/"),
			"%s has a sprite path" % kind)
		var size := WorldObjectDB.size_of(kind)
		assert_true(size.x >= 1 and size.y >= 1, "%s has a footprint" % kind)


func test_drops_and_links_point_at_real_things() -> void:
	var rng := RandomNumberGenerator.new()
	for kind in WorldObjectDB.all_kinds():
		var next := WorldObjectDB.becomes(kind)
		if next != "":
			assert_true(WorldObjectDB.has_kind(next), "%s becomes a real kind (%s)" % [kind, next])
		if WorldObjectDB.is_forage(kind):
			assert_true(ItemDB.has_item(WorldObjectDB.forage_item(kind)),
				"%s forages a real item" % kind)
		for seed_value in 20:
			rng.seed = seed_value
			for drop in WorldObjectDB.roll_drops(kind, rng):
				assert_true(ItemDB.has_item(String(drop["item_id"])),
					"%s drops a real item (%s)" % [kind, drop["item_id"]])
				assert_true(int(drop["count"]) >= 1, "%s drops at least one" % kind)


func test_trees_fall_into_stumps_and_drop_wood() -> void:
	assert_eq(WorldObjectDB.becomes("tree_ashwood"), "stump_ashwood")
	assert_eq(WorldObjectDB.becomes("stump_ashwood"), "", "a stump is the end of the line")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var wood := 0
	for drop in WorldObjectDB.roll_drops("tree_ashwood", rng):
		if drop["item_id"] == "wood":
			wood += int(drop["count"])
	assert_true(wood >= 8 and wood <= 12, "a felled ashwood drops 8-12 wood (got %d)" % wood)


func test_tool_effects() -> void:
	assert_eq(WorldObjectDB.tool_effect("tree_ashwood", "axe", 1), WorldObjectDB.HIT)
	assert_eq(WorldObjectDB.tool_effect("tree_ashwood", "pickaxe", 4), WorldObjectDB.WRONG_TOOL)
	assert_eq(WorldObjectDB.tool_effect("rock_large", "pickaxe", 1), WorldObjectDB.TOO_WEAK,
		"big rocks need an upgraded pickaxe")
	assert_eq(WorldObjectDB.tool_effect("rock_large", "pickaxe", 2), WorldObjectDB.HIT)
	assert_eq(WorldObjectDB.tool_effect("weeds", "hoe", 1), WorldObjectDB.HIT,
		"any clearing tool cuts weeds")
	assert_eq(WorldObjectDB.tool_effect("weeds", "weapon", 1), WorldObjectDB.HIT)
	assert_eq(WorldObjectDB.tool_effect("weeds", "", 1), WorldObjectDB.WRONG_TOOL, "bare hands don't")
	assert_eq(WorldObjectDB.tool_effect("forage_wild_greens", "axe", 4), WorldObjectDB.WRONG_TOOL,
		"forage is picked by hand, never swung at")


func test_damage_scales_with_tier() -> void:
	assert_eq(WorldObjectDB.damage_for_tier(1), 1)
	assert_eq(WorldObjectDB.damage_for_tier(4), 4)
	assert_eq(WorldObjectDB.damage_for_tier(9), 4, "clamped to the top tier")
	assert_eq(WorldObjectDB.damage_for_tier(0), 1, "and to the bottom")


func test_sprite_path_substitution() -> void:
	assert_eq(WorldObjectDB.sprite_path("tree_pine", "winter", 1), "res://art/env/trees/pine_winter.png")
	assert_eq(WorldObjectDB.sprite_path("rock_small", "spring", 2), "res://art/env/debris/rock_small_2.png")
	assert_eq(WorldObjectDB.sprite_path("rock_small", "spring", 99), "res://art/env/debris/rock_small_3.png",
		"variant clamps to the variant count")


func test_spawn_layers() -> void:
	var debris := WorldObjectDB.kinds_spawning_on("debris")
	assert_true(debris.has("weeds") and debris.has("twig"), "daily debris includes weeds and twigs")
	for season in ["spring", "summer", "autumn", "winter"]:
		var forage := WorldObjectDB.kinds_spawning_on("forage_" + season)
		assert_true(forage.size() >= 3, "%s has 3+ forage kinds" % season)
		for kind in forage:
			assert_true(WorldObjectDB.is_forage(kind), "%s is forage" % kind)
