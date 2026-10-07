extends "res://tests/test_case.gd"
## Milestone B placeables: data/machines.json + scripts/machine_db.gd, the placed kinds in
## data/world_objects.json, and scripts/storage_ui.gd's transfer rules.

const MachineDB := preload("res://scripts/machine_db.gd")
const WorldObjectDB := preload("res://scripts/world_object_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const StorageUI := preload("res://scripts/storage_ui.gd")
const InventoryScript := preload("res://scripts/inventory.gd")


func test_every_machine_recipe_uses_real_items() -> void:
	for id in MachineDB.all_machines():
		for r in MachineDB.recipes(id):
			for item in r.get("inputs", []):
				assert_true(ItemDB.has_item(String(item)), "%s input %s exists" % [id, item])
			assert_true(ItemDB.has_item(String(r["output"])), "%s output %s exists" % [id, r["output"]])
			if String(r.get("fuel", "")) != "":
				assert_true(ItemDB.has_item(String(r["fuel"])), "%s fuel exists" % id)
			assert_true(int(r.get("minutes", 0)) > 0, "%s takes time" % id)
		var p := MachineDB.produces(id)
		if not p.is_empty():
			assert_true(ItemDB.has_item(String(p["output"])), "%s produces a real item" % id)


func test_every_placeable_item_has_a_placed_kind_or_floor() -> void:
	for item_id in ItemDB.all_items():
		if String(ItemDB.get_item(item_id).get("type", "")) != "placeable":
			continue
		if item_id.ends_with("_path"):
			continue  # paths become floor, not objects (test_map.gd's FLOOR_ITEMS)
		var kind := WorldObjectDB.kind_for_item(item_id)
		assert_true(kind != "", "%s places an object" % item_id)
		assert_true(WorldObjectDB.is_placed(kind), "%s is marked placed" % kind)
		assert_eq(WorldObjectDB.item_of(kind), item_id, "%s picks back up as its item" % kind)
		var machine := WorldObjectDB.machine_of(kind)
		if machine != "":
			assert_true(MachineDB.has_machine(machine), "%s runs a real machine" % kind)


func test_machine_recipe_lookup_and_loading() -> void:
	var kiln := MachineDB.recipe_for("kiln", "wood")
	assert_eq(kiln["output"], "charcoal")
	assert_true(MachineDB.recipe_for("kiln", "stone").is_empty(), "the kiln won't take stone")
	assert_true(MachineDB.accepts("preserves_jar", "bloodberry"))
	assert_eq(MachineDB.recipe_for("preserves_jar", "rain_radish")["output"], "pickled_veg")
	var smelt := MachineDB.recipe_for("smelter", "scrap_metal")
	assert_false(MachineDB.can_load(smelt, 5, 0), "the smelter needs charcoal fuel")
	assert_true(MachineDB.can_load(smelt, 5, 1))
	assert_false(MachineDB.can_load(smelt, 4, 1), "and a full batch")


func test_passive_producers_and_clock() -> void:
	var bees := MachineDB.produces("bee_box")
	assert_false(MachineDB.passive_due(bees, 2, "clear"))
	assert_true(MachineDB.passive_due(bees, 3, "clear"), "honey every 3 mornings")
	var rod := MachineDB.produces("rad_rod")
	assert_false(MachineDB.passive_due(rod, 1, "clear"))
	assert_true(MachineDB.passive_due(rod, 1, "storm"), "batteries on storm mornings")
	assert_eq(MachineDB.absolute_minutes(1, 360.0), 360)
	assert_eq(MachineDB.absolute_minutes(2, 0.0), 1440, "the clock survives sleep")


func test_pickup_tools_and_sprinkler_patterns() -> void:
	assert_eq(WorldObjectDB.tool_effect("placed_kiln", "pickaxe", 1), WorldObjectDB.HIT)
	assert_eq(WorldObjectDB.tool_effect("placed_kiln", "axe", 1), WorldObjectDB.HIT)
	assert_eq(WorldObjectDB.tool_effect("placed_kiln", "hoe", 4), WorldObjectDB.WRONG_TOOL,
		"a hoe swing never knocks a machine loose")
	assert_eq(WorldObjectDB.sprinkler_cells(Vector2i(5, 5), 1).size(), 4)
	assert_eq(WorldObjectDB.sprinkler_cells(Vector2i(5, 5), 2).size(), 8)
	assert_eq(WorldObjectDB.sprinkler_cells(Vector2i(5, 5), 3).size(), 24)
	assert_false(WorldObjectDB.sprinkler_cells(Vector2i(5, 5), 1).has(Vector2i(6, 6)),
		"the basic sprinkler skips diagonals")


func test_storage_transfer_moves_whole_stacks() -> void:
	var pack := InventoryScript.new()
	var chest := InventoryScript.new()
	pack.add_item("wood", 30)
	assert_true(StorageUI.transfer(pack, 0, chest))
	assert_eq(chest.count_of("wood"), 30)
	assert_eq(pack.count_of("wood"), 0)
	assert_false(StorageUI.transfer(pack, 0, chest), "an empty slot moves nothing")
	pack.add_tool("axe", 2)
	assert_true(StorageUI.transfer(pack, 0, chest), "tools move whole")
	assert_eq(int(chest.get_slot(1)["tier"]), 2, "keeping their tier")


func test_storage_cursor_moves_over_both_grids() -> void:
	assert_eq(StorageUI.cursor_after(0, 1, 0), 1)
	assert_eq(StorageUI.cursor_after(8, 1, 0), 0, "left/right wrap within a row")
	assert_eq(StorageUI.cursor_after(20, 0, 1), 29, "down from the chest's last row into the pack")
	assert_eq(StorageUI.cursor_after(4, 0, -1), 49, "up from the top wraps to the bottom row")
