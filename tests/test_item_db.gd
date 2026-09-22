extends "res://tests/test_case.gd"
## data/items.json loading (Phase 3's "first 20 items"). Confirms the file parses, every entry
## has the fields the rest of the game depends on, and the count matches the checklist.

const ItemDBScript := preload("res://scripts/item_db.gd")


func test_loads_expected_item_catalog() -> void:
	assert_eq(ItemDBScript.all_items().size(), 26,
		"base catalog plus coffee, fertilizer, and the four livestock products")


func test_known_items_resolve() -> void:
	assert_true(ItemDBScript.has_item("hoe"))
	assert_true(ItemDBScript.has_item("mutant_potato"))
	assert_false(ItemDBScript.has_item("does_not_exist"))


func test_every_item_has_type_and_stack_max() -> void:
	for item_id in ItemDBScript.all_items():
		var item: Dictionary = ItemDBScript.get_item(item_id)
		assert_true(item.has("type"), "%s missing type" % item_id)
		assert_true(item.has("stack_max"), "%s missing stack_max" % item_id)


func test_tools_are_not_stackable() -> void:
	for tool_id in ["hoe", "watering_can", "axe", "pickaxe", "bag"]:
		assert_true(ItemDBScript.is_tool_item(tool_id), "%s should be type tool" % tool_id)
		assert_eq(ItemDBScript.stack_max(tool_id), 1, "%s must not stack" % tool_id)
		assert_true(ItemDBScript.durability_max(tool_id) > 0, "%s needs durability_max" % tool_id)


func test_seeds_link_to_a_valid_crop() -> void:
	const CropDBScript := preload("res://scripts/crop_db.gd")
	for item_id in ItemDBScript.all_items():
		if ItemDBScript.is_seed(item_id):
			var crop_id := String(ItemDBScript.get_item(item_id).get("crop_id", ""))
			assert_true(CropDBScript.has_crop(crop_id), "%s points at an unknown crop" % item_id)


## -- 2026-07-11 forced-sleep session: edibility + the rare stay-awake coffee --

func test_edibility_follows_the_food_type() -> void:
	for food_id in ["preserved_food", "cooked_meal", "coffee"]:
		assert_true(ItemDBScript.is_edible(food_id), "%s is edible" % food_id)
		assert_true(ItemDBScript.energy_restored(food_id) > 0,
			"%s restores energy when eaten" % food_id)
	for other_id in ["mutant_potato", "wood", "hoe", "seed_dustwheat"]:
		assert_false(ItemDBScript.is_edible(other_id),
			"%s is not directly edible (crops must be cooked/shipped, not snacked raw)" % other_id)
		assert_eq(ItemDBScript.energy_restored(other_id), 0,
			"%s grants no energy" % other_id)


func test_coffee_is_the_rare_stay_awake_item() -> void:
	assert_true(ItemDBScript.grants_stay_awake("coffee"),
		"coffee arms the stay-awake-tonight charge")
	for other_id in ["preserved_food", "cooked_meal", "mutant_potato", "hoe"]:
		assert_false(ItemDBScript.grants_stay_awake(other_id),
			"%s must not suppress the 2 AM rule" % other_id)
	# "Rare" must be enforceable in data: meaningfully pricier than every other item, livestock
	# products included — see items.json's _comment.
	var coffee_value := int(ItemDBScript.get_item("coffee").get("value", 0))
	for item_id in ItemDBScript.all_items():
		if item_id == "coffee":
			continue
		assert_true(coffee_value >= 2 * int(ItemDBScript.get_item(item_id).get("value", 0)),
			"coffee (%d Cr) is at least twice %s's price" % [coffee_value, item_id])


func test_icon_or_placeholder_present() -> void:
	for item_id in ItemDBScript.all_items():
		var item: Dictionary = ItemDBScript.get_item(item_id)
		var has_icon: bool = String(item.get("icon", "")) != ""
		var has_placeholder: bool = item.has("placeholder_color") and item.has("placeholder_label")
		assert_true(has_icon or has_placeholder,
			"%s has neither real icon art nor a placeholder color/label" % item_id)
