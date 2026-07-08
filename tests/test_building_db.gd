extends "res://tests/test_case.gd"
## BuildingDB data integrity (ROADMAP.md Phase 4 Stage 2): the buildable-structure catalog is
## well-formed, costs resolve against the real item database AND against resources the player
## can actually gather in-game, and every kind has a placeholder color in structures.gd —
## mirroring tests/test_settlement_db.gd's data-integrity style.

const BuildingDB := preload("res://scripts/building_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const StructuresScript := preload("res://scripts/structures.gd")

## The only resources with an actual in-game gather source right now (axe -> 3 wood, pickaxe ->
## 2 stone + 1 scrap_metal, see scripts/farm.gd's chop()/mine()). A cost line outside this set
## would make a structure unbuildable in practice even though the item exists in items.json.
const GATHERABLE_RESOURCES := ["wood", "stone", "scrap_metal"]


func test_catalog_has_exactly_two_structures() -> void:
	# Stage 2 scope guard: 2 structures prove the mechanic; the 12+ library is Phase 8's item.
	assert_eq(BuildingDB.ids().size(), 2)


func test_ids_order_matches_catalog() -> void:
	assert_eq(BuildingDB.ids(), ["shelter_tent", "storage_shed"] as Array[String])


func test_every_building_is_well_formed() -> void:
	for id in BuildingDB.ids():
		assert_true(BuildingDB.display_name(id).length() > 0, "%s has a display name" % id)
		assert_true(BuildingDB.kind(id).length() > 0, "%s has a kind" % id)
		var size := BuildingDB.size_of(id)
		assert_true(size.x >= 1 and size.y >= 1, "%s has a positive footprint" % id)
		assert_true(BuildingDB.build_days(id) >= 1, "%s takes at least one day to build" % id)
		assert_true(BuildingDB.cost(id).size() > 0, "%s costs something" % id)


func test_costs_resolve_against_item_db() -> void:
	for id in BuildingDB.ids():
		for item_id in BuildingDB.cost(id):
			assert_true(ItemDB.has_item(item_id),
				"%s cost item '%s' exists in item_db" % [id, item_id])
			assert_true(int(BuildingDB.cost(id)[item_id]) > 0,
				"%s cost of '%s' is positive" % [id, item_id])


func test_costs_use_only_gatherable_resources() -> void:
	for id in BuildingDB.ids():
		for item_id in BuildingDB.cost(id):
			assert_true(item_id in GATHERABLE_RESOURCES,
				"%s cost item '%s' has a real gather source" % [id, item_id])


func test_every_kind_has_a_placeholder_color() -> void:
	for id in BuildingDB.ids():
		assert_true(StructuresScript.BUILDING_COLORS.has(BuildingDB.kind(id)),
			"structures.gd has a color for kind '%s'" % BuildingDB.kind(id))


func test_storage_flags() -> void:
	assert_true(BuildingDB.is_storage("storage_shed"), "the shed is a storage structure")
	assert_false(BuildingDB.is_storage("shelter_tent"), "the tent is not")


func test_expected_footprints() -> void:
	assert_eq(BuildingDB.size_of("shelter_tent"), Vector2i(1, 1))
	assert_eq(BuildingDB.size_of("storage_shed"), Vector2i(2, 2))


func test_unknown_id_reads_as_empty() -> void:
	assert_true(BuildingDB.get_building("nonexistent").is_empty())
	assert_false(BuildingDB.has_building("nonexistent"))
	assert_eq(BuildingDB.size_of("nonexistent"), Vector2i.ONE)
	assert_eq(BuildingDB.build_days("nonexistent"), 1)
	assert_true(BuildingDB.cost("nonexistent").is_empty())
