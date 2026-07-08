extends "res://tests/test_case.gd"
## Pure building-placement math (ROADMAP.md Phase 4 Stage 2): footprint anchoring per facing,
## footprint enumeration, map-bounds checks, cost affordability, and construction-day-completion
## — all static functions in scripts/build_grid.gd, tested headlessly with no scene.

const BuildGrid := preload("res://scripts/build_grid.gd")
const BuildingDB := preload("res://scripts/building_db.gd")
const SettlementDB := preload("res://scripts/settlement_db.gd")


## -- anchored_top_left: the footprint always extends AWAY from the player --

func test_anchor_south_and_east_keep_target_as_top_left() -> void:
	assert_eq(BuildGrid.anchored_top_left(Vector2i(5, 5), Vector2i(2, 3), "south"), Vector2i(5, 5))
	assert_eq(BuildGrid.anchored_top_left(Vector2i(5, 5), Vector2i(2, 3), "east"), Vector2i(5, 5))


func test_anchor_north_shifts_up_by_height() -> void:
	assert_eq(BuildGrid.anchored_top_left(Vector2i(5, 5), Vector2i(2, 3), "north"), Vector2i(5, 3))


func test_anchor_west_shifts_left_by_width() -> void:
	assert_eq(BuildGrid.anchored_top_left(Vector2i(5, 5), Vector2i(2, 3), "west"), Vector2i(4, 5))


func test_anchor_1x1_is_target_for_every_facing() -> void:
	for facing in ["north", "south", "east", "west"]:
		assert_eq(BuildGrid.anchored_top_left(Vector2i(7, 9), Vector2i.ONE, facing), Vector2i(7, 9),
			"1x1 anchored at target when facing %s" % facing)


func test_anchored_footprint_never_contains_the_player_cell() -> void:
	# The rule's whole point (see build_grid.gd's comment): a player one cell behind the target
	# can never be inside the body they place. Player at (5,5), target one cell ahead per facing.
	var size := Vector2i(2, 2)
	var player := Vector2i(5, 5)
	var facings := {"south": Vector2i(0, 1), "north": Vector2i(0, -1),
		"east": Vector2i(1, 0), "west": Vector2i(-1, 0)}
	for facing in facings:
		var target: Vector2i = player + facings[facing]
		var top_left: Vector2i = BuildGrid.anchored_top_left(target, size, facing)
		assert_false(player in BuildGrid.footprint_cells(top_left, size),
			"facing %s keeps the player outside the footprint" % facing)


## -- footprint_cells --

func test_footprint_cells_enumerates_the_rectangle() -> void:
	var cells := BuildGrid.footprint_cells(Vector2i(3, 16), Vector2i(2, 2))
	assert_eq(cells.size(), 4)
	for expected in [Vector2i(3, 16), Vector2i(4, 16), Vector2i(3, 17), Vector2i(4, 17)]:
		assert_true(expected in cells, "footprint contains %s" % expected)


func test_footprint_cells_1x1_is_just_the_anchor() -> void:
	assert_eq(BuildGrid.footprint_cells(Vector2i(9, 9), Vector2i.ONE), [Vector2i(9, 9)] as Array[Vector2i])


## -- cells_within_map --

func test_footprint_inside_map_is_within() -> void:
	assert_true(BuildGrid.cells_within_map(Vector2i(1, 1), Vector2i(2, 2), Vector2i(36, 31)))


func test_footprint_clipping_an_edge_is_not_within() -> void:
	assert_false(BuildGrid.cells_within_map(Vector2i(35, 1), Vector2i(2, 2), Vector2i(36, 31)),
		"hangs off the east edge")
	assert_false(BuildGrid.cells_within_map(Vector2i(-1, 1), Vector2i(2, 2), Vector2i(36, 31)),
		"hangs off the west edge")
	assert_false(BuildGrid.cells_within_map(Vector2i(1, 30), Vector2i(2, 2), Vector2i(36, 31)),
		"hangs off the south edge")


## -- can_afford --

func test_can_afford_exact_amounts() -> void:
	assert_true(BuildGrid.can_afford({"wood": 12, "stone": 4}, {"wood": 12, "stone": 4}))


func test_cannot_afford_missing_or_short_items() -> void:
	assert_false(BuildGrid.can_afford({"wood": 11, "stone": 4}, {"wood": 12, "stone": 4}),
		"one wood short")
	assert_false(BuildGrid.can_afford({"wood": 12}, {"wood": 12, "stone": 4}),
		"stone entirely missing")


func test_empty_cost_is_always_affordable() -> void:
	assert_true(BuildGrid.can_afford({}, {}))


func test_forest_edge_starting_bonus_affords_the_shed() -> void:
	# Design intent lock (see data/buildings.json's _comment): the "ruin materials" start can
	# build the Storage Shed on day 1 from its starting bonus alone.
	var have := {}
	for entry in SettlementDB.starting_items("forest_edge"):
		have[String(entry["item_id"])] = int(entry["count"])
	assert_true(BuildGrid.can_afford(have, BuildingDB.cost("storage_shed")))


## -- is_construction_complete --

func test_not_complete_on_the_day_it_was_placed() -> void:
	assert_false(BuildGrid.is_construction_complete(3, 3, 1))


func test_complete_the_next_day() -> void:
	assert_true(BuildGrid.is_construction_complete(3, 4, 1))


func test_complete_stays_true_after_extra_days() -> void:
	assert_true(BuildGrid.is_construction_complete(3, 9, 1))


func test_respects_longer_build_days() -> void:
	assert_false(BuildGrid.is_construction_complete(3, 4, 2))
	assert_true(BuildGrid.is_construction_complete(3, 5, 2))


## -- wrap_index --

func test_wrap_index_wraps_both_directions() -> void:
	assert_eq(BuildGrid.wrap_index(1, 1, 2), 0)
	assert_eq(BuildGrid.wrap_index(0, -1, 2), 1)
	assert_eq(BuildGrid.wrap_index(0, 1, 2), 1)
	assert_eq(BuildGrid.wrap_index(0, 1, 0), 0, "empty catalog stays at 0")
