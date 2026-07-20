extends "res://tests/test_case.gd"
## BuildingDB data integrity (ROADMAP.md Phase 4 Stage 2, grown by Phase 8 Stage 1 into the full
## 12-building library, then by Phase 8 Stage 2's fencing & perimeter system to 16): the
## buildable-structure catalog is well-formed, costs resolve against the real item database AND
## against resources the player can actually gather in-game, every kind has a placeholder color
## in structures.gd, and the new interaction/daily_yield/capacity_unlock/effect (Stage 1) plus
## solid/durability_max (Stage 2) accessors read correctly — mirroring
## tests/test_settlement_db.gd's data-integrity style.

const BuildingDB := preload("res://scripts/building_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const StructuresScript := preload("res://scripts/structures.gd")

## The only resources with an actual in-game gather source right now (axe -> 3 wood, pickaxe ->
## 2 stone + 1 scrap_metal, see scripts/farm.gd's chop()/mine()). A cost line outside this set
## would make a structure unbuildable in practice even though the item exists in items.json.
const GATHERABLE_RESOURCES := ["wood", "stone", "scrap_metal"]

const EXPECTED_IDS: Array[String] = [
	"shelter_tent", "storage_shed", "workshop", "clinic", "trading_post", "watchtower",
	"greenhouse", "compost_pit", "rain_collector", "solar_panel", "antenna_tower",
	"community_kitchen", "fence_wood", "fence_chainlink", "fence_concrete", "gate_wood",
]


func test_catalog_has_exactly_sixteen_structures() -> void:
	# Phase 8 Stage 1's 12-building library + Stage 2's 4 fence/gate entries.
	assert_eq(BuildingDB.ids().size(), 16)


func test_ids_order_matches_catalog() -> void:
	assert_eq(BuildingDB.ids(), EXPECTED_IDS)


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
	assert_true(BuildingDB.is_storage("storage_shed"), "the barn is a storage structure")
	assert_false(BuildingDB.is_storage("shelter_tent"), "the cabin is not")
	# is_storage() is a thin wrapper over interaction() == "storage" (Stage 1's schema migration).
	assert_eq(BuildingDB.interaction("storage_shed"), "storage")
	assert_eq(BuildingDB.interaction("shelter_tent"), "")


func test_expected_footprints() -> void:
	assert_eq(BuildingDB.size_of("shelter_tent"), Vector2i(1, 1))
	assert_eq(BuildingDB.size_of("storage_shed"), Vector2i(2, 2))


func test_unknown_id_reads_as_empty() -> void:
	assert_true(BuildingDB.get_building("nonexistent").is_empty())
	assert_false(BuildingDB.has_building("nonexistent"))
	assert_eq(BuildingDB.size_of("nonexistent"), Vector2i.ONE)
	assert_eq(BuildingDB.build_days("nonexistent"), 1)
	assert_true(BuildingDB.cost("nonexistent").is_empty())
	assert_eq(BuildingDB.interaction("nonexistent"), "")
	assert_true(BuildingDB.daily_yield("nonexistent").is_empty())
	assert_true(BuildingDB.capacity_unlock("nonexistent").is_empty())
	assert_eq(BuildingDB.effect("nonexistent"), "")


## -- Phase 8 Stage 1: the new interaction/daily_yield/capacity_unlock/effect accessors --

func test_interaction_recognizes_trading_post() -> void:
	# Data-only this stage (Stage 4 wires the actual staffed UI) — but the accessor must already
	# recognize the value.
	assert_eq(BuildingDB.interaction("trading_post"), "trading_post")


func test_daily_yield_matches_the_building_table() -> void:
	assert_eq(BuildingDB.daily_yield("workshop"), {"scrap_metal": 1})
	assert_eq(BuildingDB.daily_yield("greenhouse"), {"seed_sunbloom": 1})
	assert_eq(BuildingDB.daily_yield("compost_pit"), {"fertilizer": 1})
	assert_eq(BuildingDB.daily_yield("community_kitchen"), {"cooked_meal": 1})
	assert_true(BuildingDB.daily_yield("shelter_tent").is_empty(), "the cabin has no daily yield")


func test_daily_yield_items_resolve_against_item_db() -> void:
	for id in BuildingDB.ids():
		for item_id in BuildingDB.daily_yield(id):
			assert_true(ItemDB.has_item(item_id),
				"%s daily_yield item '%s' exists in item_db" % [id, item_id])


func test_capacity_unlock_matches_the_building_table() -> void:
	# Values round-trip through JSON as floats (like every other *_db.gd loader here) — compared
	# as floats rather than int()-normalized, since capacity_unlock() deliberately doesn't force
	# a single numeric type (build_energy_discount is genuinely fractional).
	assert_eq(BuildingDB.capacity_unlock("shelter_tent"), {"population_cap": 1.0})
	assert_eq(BuildingDB.capacity_unlock("clinic"), {"energy_max": 10.0})
	assert_eq(BuildingDB.capacity_unlock("solar_panel"), {"build_energy_discount": 0.25})
	assert_true(BuildingDB.capacity_unlock("workshop").is_empty(),
		"the workshop has no capacity unlock")


func test_capacity_unlock_returns_a_copy_not_the_cached_dict() -> void:
	var first := BuildingDB.capacity_unlock("shelter_tent")
	first["population_cap"] = 999
	assert_eq(BuildingDB.capacity_unlock("shelter_tent"), {"population_cap": 1.0},
		"mutating a returned dict must not corrupt the cached catalog")


func test_effect_matches_the_building_table() -> void:
	assert_eq(BuildingDB.effect("watchtower"), "watchtower_lookout")
	assert_eq(BuildingDB.effect("rain_collector"), "rain_collector_water")
	assert_eq(BuildingDB.effect("antenna_tower"), "antenna_signal")
	assert_eq(BuildingDB.effect("shelter_tent"), "")


func test_only_wood_stone_scrap_metal_cost_items_across_the_whole_library() -> void:
	# Stage 1's explicit constraint (buildings.json's own comment): every one of the 16
	# buildings' costs is gatherable, not just the original 2.
	for id in BuildingDB.ids():
		for item_id in BuildingDB.cost(id):
			assert_true(item_id in GATHERABLE_RESOURCES,
				"%s cost item '%s' is wood/stone/scrap_metal only" % [id, item_id])


## -- Phase 8 Stage 2 (fencing & perimeter system): solid() / durability_max() --

func test_solid_defaults_true_for_every_pre_stage_2_building() -> void:
	# The whole point of solid()'s default: not one pre-existing entry needed a data change.
	for id in EXPECTED_IDS:
		if id in ["gate_wood"]:
			continue
		assert_true(BuildingDB.solid(id), "%s defaults to solid" % id)


func test_gate_is_the_only_non_solid_building() -> void:
	assert_false(BuildingDB.solid("gate_wood"), "the gate is not solid")
	assert_true(BuildingDB.solid("fence_wood"), "a fence is solid")
	assert_true(BuildingDB.solid("fence_chainlink"), "a fence is solid")
	assert_true(BuildingDB.solid("fence_concrete"), "a fence is solid")


func test_solid_defaults_true_for_an_unknown_id() -> void:
	assert_true(BuildingDB.solid("nonexistent"), "unknown ids read as solid")


func test_durability_max_matches_the_fence_gate_table() -> void:
	assert_eq(BuildingDB.durability_max("fence_wood"), 20)
	assert_eq(BuildingDB.durability_max("fence_chainlink"), 45)
	assert_eq(BuildingDB.durability_max("fence_concrete"), 80)
	assert_eq(BuildingDB.durability_max("gate_wood"), 20)


func test_durability_max_is_zero_for_buildings_without_one() -> void:
	assert_eq(BuildingDB.durability_max("shelter_tent"), 0)
	assert_eq(BuildingDB.durability_max("nonexistent"), 0)


func test_fence_and_gate_kinds_are_distinct() -> void:
	assert_eq(BuildingDB.kind("fence_wood"), "fence")
	assert_eq(BuildingDB.kind("fence_chainlink"), "fence")
	assert_eq(BuildingDB.kind("fence_concrete"), "fence")
	assert_eq(BuildingDB.kind("gate_wood"), "gate")
