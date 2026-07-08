extends "res://tests/test_case.gd"
## SettlementDB data integrity (ROADMAP.md Phase 4): 3 settlements with unique ids, well-formed
## starting-item bonuses that resolve against the real item database, and correct layout
## resolution (including the default fallback used when no selection has been made yet).

const SettlementDB := preload("res://scripts/settlement_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const OpenPlainsLayout := preload("res://scripts/map_layouts/open_plains_layout.gd")
const ForestEdgeLayout := preload("res://scripts/map_layouts/forest_edge_layout.gd")
const RiversideLayout := preload("res://scripts/map_layouts/riverside_layout.gd")


func test_exactly_three_settlements() -> void:
	assert_eq(SettlementDB.list().size(), 3)


func test_settlement_ids_are_unique() -> void:
	var ids := {}
	for s in SettlementDB.list():
		var id := String(s["id"])
		assert_false(ids.has(id), "duplicate settlement id '%s'" % id)
		ids[id] = true


func test_every_settlement_has_name_lore_and_lean() -> void:
	for s in SettlementDB.list():
		assert_true(String(s.get("name", "")).length() > 0, "%s has a name" % s["id"])
		assert_true(String(s.get("lore", "")).length() > 20, "%s has a real lore blurb" % s["id"])
		assert_true(String(s.get("resource_lean", "")).length() > 0, "%s has a resource lean" % s["id"])
		assert_true(String(s.get("summary", "")).length() > 0, "%s has a summary" % s["id"])


func test_starting_items_resolve_against_item_db() -> void:
	for s in SettlementDB.list():
		var items: Array = s.get("starting_items", [])
		assert_true(items.size() > 0, "%s grants at least one starting-resource bonus" % s["id"])
		for entry in items:
			var item_id := String(entry.get("item_id", ""))
			assert_true(ItemDB.has_item(item_id), "%s bonus item '%s' exists in item_db" % [s["id"], item_id])
			assert_true(int(entry.get("count", 0)) > 0, "%s bonus item '%s' has a positive count" % [s["id"], item_id])


func test_get_settlement_by_id() -> void:
	var open_plains := SettlementDB.get_settlement("open_plains")
	assert_eq(String(open_plains.get("name", "")), "Open Plains")
	assert_true(SettlementDB.get_settlement("nonexistent_id").is_empty())


func test_has_settlement() -> void:
	assert_true(SettlementDB.has_settlement("forest_edge"))
	assert_true(SettlementDB.has_settlement("riverside"))
	assert_false(SettlementDB.has_settlement("nowhere"))


func test_layout_for_id_maps_correctly() -> void:
	assert_eq(SettlementDB.layout_for_id("open_plains"), OpenPlainsLayout)
	assert_eq(SettlementDB.layout_for_id("forest_edge"), ForestEdgeLayout)
	assert_eq(SettlementDB.layout_for_id("riverside"), RiversideLayout)


func test_layout_for_id_falls_back_to_default_for_unknown_id() -> void:
	assert_eq(SettlementDB.layout_for_id("totally_unknown"), OpenPlainsLayout)


func test_default_id_is_a_real_settlement() -> void:
	assert_true(SettlementDB.has_settlement(SettlementDB.DEFAULT_ID))


func test_starting_items_helper_matches_settlement_data() -> void:
	var direct: Array = SettlementDB.get_settlement("riverside")["starting_items"]
	var via_helper := SettlementDB.starting_items("riverside")
	assert_eq(via_helper.size(), direct.size())


func test_starting_items_unknown_id_returns_empty() -> void:
	assert_true(SettlementDB.starting_items("nowhere").is_empty())
