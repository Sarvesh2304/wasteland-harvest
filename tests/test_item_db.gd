extends "res://tests/test_case.gd"
## data/items.json loading (Phase 3's "first 20 items"). Confirms the file parses, every entry
## has the fields the rest of the game depends on, and the count matches the checklist.

const ItemDBScript := preload("res://scripts/item_db.gd")


func test_loads_exactly_twenty_items() -> void:
	assert_eq(ItemDBScript.all_items().size(), 20, "ROADMAP Phase 3 calls for the first 20 items")


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


func test_icon_or_placeholder_present() -> void:
	for item_id in ItemDBScript.all_items():
		var item: Dictionary = ItemDBScript.get_item(item_id)
		var has_icon: bool = String(item.get("icon", "")) != ""
		var has_placeholder: bool = item.has("placeholder_color") and item.has("placeholder_label")
		assert_true(has_icon or has_placeholder,
			"%s has neither real icon art nor a placeholder color/label" % item_id)
