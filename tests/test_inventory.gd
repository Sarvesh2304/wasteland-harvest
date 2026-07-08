extends "res://tests/test_case.gd"
## Inventory slot math (Phase 3): stacking, overflow, removal, tool durability. Exercises the
## pure static functions directly (no Inventory instance / Node tree required) plus a couple of
## checks through a live Inventory instance for the signal-emitting wrapper behavior.

const InventoryScript := preload("res://scripts/inventory.gd")


func _empty_slots(n: int) -> Array:
	var slots: Array = []
	slots.resize(n)
	for i in n:
		slots[i] = {}
	return slots


func test_add_to_slots_fills_existing_stack_first() -> void:
	var slots := _empty_slots(3)
	slots[0] = {"item_id": "wood", "count": 5}
	var result := InventoryScript.add_to_slots(slots, "wood", 10, 99)
	assert_eq(result["leftover"], 0)
	assert_eq(result["slots"][0]["count"], 15, "existing stack absorbed the addition first")
	assert_true(result["slots"][1].is_empty(), "no new slot used when the stack had room")


func test_add_to_slots_overflows_into_new_stack_at_cap() -> void:
	var slots := _empty_slots(3)
	slots[0] = {"item_id": "wood", "count": 95}
	var result := InventoryScript.add_to_slots(slots, "wood", 10, 99)
	assert_eq(result["slots"][0]["count"], 99, "first stack tops out at stack_max")
	assert_eq(result["slots"][1], {"item_id": "wood", "count": 6}, "remainder spills into a new stack")
	assert_eq(result["leftover"], 0)


func test_add_to_slots_reports_leftover_when_full() -> void:
	var slots := _empty_slots(1)
	slots[0] = {"item_id": "wood", "count": 99}
	var result := InventoryScript.add_to_slots(slots, "wood", 5, 99)
	assert_eq(result["leftover"], 5, "no room anywhere: all 5 reported as leftover")


func test_add_tool_to_slots_never_stacks() -> void:
	var slots := _empty_slots(2)
	var result := InventoryScript.add_tool_to_slots(slots, "hoe", 50)
	assert_true(result["placed"])
	assert_eq(result["slots"][0], {"item_id": "hoe", "count": 1, "durability": 50})
	var second := InventoryScript.add_tool_to_slots(result["slots"], "hoe", 50)
	assert_true(second["placed"])
	assert_ne(second["slots"][1], {}, "second tool claims its own slot rather than stacking")


func test_add_tool_to_slots_fails_when_full() -> void:
	var slots := _empty_slots(1)
	slots[0] = {"item_id": "axe", "count": 1, "durability": 10}
	var result := InventoryScript.add_tool_to_slots(slots, "hoe", 50)
	assert_false(result["placed"], "no empty slot available")


func test_remove_from_slots() -> void:
	var slots := _empty_slots(2)
	slots[0] = {"item_id": "stone", "count": 3}
	slots[1] = {"item_id": "stone", "count": 4}
	var result := InventoryScript.remove_from_slots(slots, "stone", 5)
	assert_eq(result["removed"], 5)
	assert_true(result["slots"][0].is_empty(), "first stack fully consumed")
	assert_eq(result["slots"][1]["count"], 2, "second stack partially consumed")


func test_remove_from_slots_caps_at_available() -> void:
	var slots := _empty_slots(1)
	slots[0] = {"item_id": "stone", "count": 2}
	var result := InventoryScript.remove_from_slots(slots, "stone", 10)
	assert_eq(result["removed"], 2, "can't remove more than is actually there")


func test_instance_add_and_select_hotbar() -> void:
	var inv := InventoryScript.new()
	var leftover := inv.add_item("wood", 5)
	assert_eq(leftover, 0)
	assert_eq(inv.count_of("wood"), 5)
	inv.select_hotbar(3)
	assert_eq(inv.selected_hotbar_index, 3)
	# No inv.free(): Inventory is RefCounted now, freed automatically when it goes out of scope.


func test_instance_damage_selected_tool_breaks_at_zero() -> void:
	var inv := InventoryScript.new()
	inv.add_item("hoe", 1, 2)  # durability 2
	inv.select_hotbar(0)
	var broke := inv.damage_selected_tool(1)
	assert_false(broke, "still has 1 durability left")
	broke = inv.damage_selected_tool(1)
	assert_true(broke, "hit zero this call")
	assert_eq(inv.get_selected_slot()["durability"], 0)
