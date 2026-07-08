extends "res://tests/test_case.gd"
## Phase 4 Stage 3: pure save-serialisation logic (scripts/save_data.gd). Every round-trip test
## here goes through ACTUAL JSON text (JSON.stringify -> JSON.parse_string) rather than just
## encode->decode on the in-memory Dictionary, because JSON's type flattening (ints -> floats,
## Vector2i keys impossible) is precisely the failure mode this module exists to absorb.

const SaveData := preload("res://scripts/save_data.gd")


## Encode -> real JSON text -> parse -> decode, i.e. exactly what a save/load cycle does.
func _through_json(value):
	return JSON.parse_string(JSON.stringify(value))


func test_cell_key_round_trip() -> void:
	for cell in [Vector2i(0, 0), Vector2i(17, 4), Vector2i(-3, 12), Vector2i(35, 31)]:
		assert_eq(SaveData.parse_cell_key(SaveData.cell_key(cell)), cell, str(cell))


func test_parse_cell_key_malformed_is_zero() -> void:
	assert_eq(SaveData.parse_cell_key("garbage"), Vector2i.ZERO)
	assert_eq(SaveData.parse_cell_key(""), Vector2i.ZERO)


func test_cells_round_trip_through_json() -> void:
	var cells := [Vector2i(5, 20), Vector2i(6, 20), Vector2i(12, 3)]
	var decoded := SaveData.decode_cells(_through_json(SaveData.encode_cells(cells)))
	assert_eq(decoded.size(), 3)
	for i in cells.size():
		assert_eq(decoded[i], cells[i])


func test_plots_round_trip_through_json() -> void:
	var plots := {
		Vector2i(5, 20): {"crop_id": "mutant_potato", "stage": 2, "watered": true},
		Vector2i(6, 21): {"crop_id": "dustwheat", "stage": 0, "watered": false},
	}
	var decoded: Dictionary = SaveData.decode_plots(_through_json(SaveData.encode_plots(plots)))
	assert_eq(decoded.size(), 2)
	var plot: Dictionary = decoded[Vector2i(5, 20)]
	assert_eq(plot["crop_id"], "mutant_potato")
	assert_eq(plot["stage"], 2, "stage must come back as int, not JSON float")
	assert_true(plot["stage"] is int, "stage type is int after decode")
	assert_eq(plot["watered"], true)
	assert_eq(decoded[Vector2i(6, 21)]["stage"], 0)


func test_resource_nodes_round_trip_through_json() -> void:
	var nodes := {Vector2i(33, 2): "tree", Vector2i(34, 6): "ore"}
	var decoded: Dictionary = SaveData.decode_resource_nodes(
		_through_json(SaveData.encode_resource_nodes(nodes)))
	assert_eq(decoded.size(), 2)
	assert_eq(decoded[Vector2i(33, 2)], "tree")
	assert_eq(decoded[Vector2i(34, 6)], "ore")


func test_inventory_round_trip_through_json() -> void:
	var slots := [
		{"item_id": "hoe", "count": 1, "durability": 49},
		{"item_id": "wood", "count": 15},
		{},
		{"item_id": "seed_mutant_potato", "count": 4},
	]
	var decoded: Dictionary = SaveData.decode_inventory(
		_through_json(SaveData.encode_inventory(slots, 5)))
	assert_eq(decoded["selected_hotbar_index"], 5)
	var out_slots: Array = decoded["slots"]
	assert_eq(out_slots.size(), 4)
	assert_eq(out_slots[0], {"item_id": "hoe", "count": 1, "durability": 49})
	assert_true(out_slots[0]["durability"] is int, "durability re-normalised to int")
	assert_true(out_slots[0]["count"] is int, "count re-normalised to int")
	assert_eq(out_slots[1], {"item_id": "wood", "count": 15})
	assert_false(out_slots[1].has("durability"), "no durability key invented for stackables")
	assert_true((out_slots[2] as Dictionary).is_empty(), "empty slot stays empty")
	assert_eq(out_slots[3], {"item_id": "seed_mutant_potato", "count": 4})


func test_structure_entry_round_trip_drops_visual() -> void:
	var entry := {
		"building_id": "storage_shed",
		"kind": "storage_shed",
		"top_left": Vector2i(3, 16),
		"size": Vector2i(2, 2),
		"placed_day": 7,
		"visual": ColorRect.new(),  # the live entry's node reference — must NOT be serialised
	}
	var encoded: Dictionary = SaveData.encode_structure_entry(entry)
	assert_false(encoded.has("visual"), "visual ColorRect dropped on encode")
	var decoded: Dictionary = SaveData.decode_structure_entry(_through_json(encoded))
	assert_eq(decoded["building_id"], "storage_shed")
	assert_eq(decoded["kind"], "storage_shed")
	assert_eq(decoded["top_left"], Vector2i(3, 16))
	assert_eq(decoded["size"], Vector2i(2, 2))
	assert_eq(decoded["placed_day"], 7)
	assert_true(decoded["placed_day"] is int, "placed_day re-normalised to int")
	(entry["visual"] as ColorRect).free()


func test_build_save_stamps_version() -> void:
	var data := SaveData.build_save({"settlement_id": "riverside", "day": 3})
	assert_eq(data["version"], SaveData.SAVE_VERSION)
	assert_eq(data["settlement_id"], "riverside", "sections preserved")
	assert_eq(data["day"], 3)


func test_parse_save_full_round_trip() -> void:
	var save := SaveData.build_save({
		"settlement_id": "forest_edge",
		"day": 9,
		"minutes_into_day": 360.0,
		"player": {"x": 296.0, "y": 88.0, "facing": "north", "energy": 100.0,
			"inventory": SaveData.encode_inventory([{"item_id": "wood", "count": 3}], 0)},
		"map": {"tilled": SaveData.encode_cells([Vector2i(5, 20)])},
		"farm": {"plots": SaveData.encode_plots(
				{Vector2i(5, 20): {"crop_id": "mutant_potato", "stage": 1, "watered": false}}),
			"resource_nodes": SaveData.encode_resource_nodes({Vector2i(20, 1): "tree"})},
		"structures": {"pending": [], "completed": [], "storage": {}, "chest": {}},
	})
	var parsed := SaveData.parse_save(JSON.stringify(save, "\t"))
	assert_false(parsed.is_empty(), "well-formed save text parses")
	assert_eq(String(parsed["settlement_id"]), "forest_edge")
	assert_eq(int(parsed["day"]), 9)
	assert_eq(SaveData.decode_cells(parsed["map"]["tilled"]), [Vector2i(5, 20)] as Array[Vector2i])
	assert_eq(SaveData.decode_plots(parsed["farm"]["plots"])[Vector2i(5, 20)]["stage"], 1)


func test_parse_save_rejects_garbage() -> void:
	assert_true(SaveData.parse_save("not json at all {{{").is_empty(), "unparseable text")
	assert_true(SaveData.parse_save("").is_empty(), "empty file")
	assert_true(SaveData.parse_save("[1, 2, 3]").is_empty(), "non-Dictionary root")


func test_parse_save_rejects_bad_version_or_missing_settlement() -> void:
	assert_true(SaveData.parse_save(JSON.stringify(
		{"settlement_id": "open_plains"})).is_empty(), "missing version")
	assert_true(SaveData.parse_save(JSON.stringify(
		{"version": 999, "settlement_id": "open_plains"})).is_empty(), "future/unknown version")
	assert_true(SaveData.parse_save(JSON.stringify(
		{"version": SaveData.SAVE_VERSION})).is_empty(), "missing settlement_id")
	assert_true(SaveData.parse_save(JSON.stringify(
		{"version": SaveData.SAVE_VERSION, "settlement_id": ""})).is_empty(), "empty settlement_id")


func test_decode_inventory_defaults_when_empty() -> void:
	var decoded: Dictionary = SaveData.decode_inventory({})
	assert_eq(decoded["selected_hotbar_index"], 0)
	assert_true((decoded["slots"] as Array).is_empty())
