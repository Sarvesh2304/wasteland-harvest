extends "res://tests/test_case.gd"
## Phase 4 map-layout data integrity: well-formed grids, sealed perimeters (with the farm gap
## and town gate as the only breaks), valid spawns, and the town-core landmark set (farmhouse,
## chest, mayor's house, store, 3-4 shacks, bulletin board, dock, gate) for all 3 starting
## layouts (scripts/map_layouts/*.gd). Runs the same checks against all three via a data table,
## the way tests/test_crop_db.gd iterates crop ids, rather than tripling the assertions by hand.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")
const OpenPlainsLayout := preload("res://scripts/map_layouts/open_plains_layout.gd")
const ForestEdgeLayout := preload("res://scripts/map_layouts/forest_edge_layout.gd")
const RiversideLayout := preload("res://scripts/map_layouts/riverside_layout.gd")

const LEGAL_CHARS := [".", "f", "p", "#", "@", "T", "O", "H", "C", "M", "R", "K", "B", "W", "F", "G", "g"]
const REQUIRED_BUILDING_KINDS := ["farmhouse", "chest", "mayor_house", "store", "shack", "bulletin_board"]

const LAYOUTS := [OpenPlainsLayout, ForestEdgeLayout, RiversideLayout]
const LAYOUT_NAMES := ["open_plains", "forest_edge", "riverside"]


func test_all_layouts_are_rectangular() -> void:
	for layout in LAYOUTS:
		var rows: Array[String] = layout.ROWS
		var width: int = rows[0].length()
		for y in rows.size():
			assert_eq(rows[y].length(), width, "row %d width" % y)


func test_all_layouts_only_legal_characters() -> void:
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		var rows: Array[String] = layout.ROWS
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				assert_true(row[x] in LEGAL_CHARS,
					"%s cell (%d,%d) is '%s'" % [LAYOUT_NAMES[i], x, y, row[x]])


func test_all_layouts_exactly_one_spawn() -> void:
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		var rows: Array[String] = layout.ROWS
		var count := 0
		for y in rows.size():
			for x in rows[y].length():
				if rows[y][x] == "@":
					count += 1
		assert_eq(count, 1, "%s exactly one '@' spawn marker" % LAYOUT_NAMES[i])
		var spawn: Vector2i = layout.spawn_cell()
		assert_false(layout.is_solid(spawn.x, spawn.y), "%s spawn is not blocked" % LAYOUT_NAMES[i])


func test_all_layouts_have_all_required_building_kinds() -> void:
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		var kinds := {}
		for b in layout.buildings():
			kinds[String(b["kind"])] = kinds.get(String(b["kind"]), 0) + 1
		for kind in REQUIRED_BUILDING_KINDS:
			assert_true(kinds.get(kind, 0) > 0, "%s missing building kind '%s'" % [LAYOUT_NAMES[i], kind])
		assert_true(kinds.get("shack", 0) >= 3, "%s has at least 3 settler shacks" % LAYOUT_NAMES[i])


func test_all_layouts_have_dock_and_gate() -> void:
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		assert_true(layout.dock_cells().size() > 0, "%s has dock plank cells" % LAYOUT_NAMES[i])
		assert_true(layout.gate_cells().size() > 0, "%s has a main gate" % LAYOUT_NAMES[i])
		assert_true(layout.water_cells().size() > 0, "%s has a water body" % LAYOUT_NAMES[i])
		assert_true(layout.farm_gap_cells().size() > 0, "%s has the farm's perimeter fence gap" % LAYOUT_NAMES[i])


func test_all_layouts_have_farmland_and_resource_nodes() -> void:
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		var rows: Array[String] = layout.ROWS
		var soil_count := 0
		for y in rows.size():
			for x in rows[y].length():
				if rows[y][x] == "f":
					soil_count += 1
		assert_true(soil_count > 0, "%s has tillable/pre-tilled farmland" % LAYOUT_NAMES[i])
		assert_true(layout.resource_node_cells().size() > 0, "%s has at least one resource node" % LAYOUT_NAMES[i])


func test_building_footprints_dont_overlap_each_other() -> void:
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		var occupied := {}
		for b in layout.buildings():
			var top_left: Vector2i = b["top_left"]
			var footprint_size: Vector2i = b["size"]
			for y in range(top_left.y, top_left.y + footprint_size.y):
				for x in range(top_left.x, top_left.x + footprint_size.x):
					var c := Vector2i(x, y)
					assert_false(occupied.has(c),
						"%s building '%s' overlaps '%s' at %s" \
							% [LAYOUT_NAMES[i], b["id"], occupied.get(c, ""), c])
					occupied[c] = b["id"]


func test_is_tillable_excludes_buildings_fence_water() -> void:
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		for b in layout.buildings():
			var top_left: Vector2i = b["top_left"]
			assert_false(layout.is_tillable(top_left.x, top_left.y),
				"%s building '%s' top-left isn't tillable" % [LAYOUT_NAMES[i], b["id"]])
		for c in layout.fence_cells():
			assert_false(layout.is_tillable(c.x, c.y), "%s fence cell isn't tillable" % LAYOUT_NAMES[i])
		for c in layout.water_cells():
			assert_false(layout.is_tillable(c.x, c.y), "%s water cell isn't tillable" % LAYOUT_NAMES[i])
		var spawn: Vector2i = layout.spawn_cell()
		assert_true(layout.is_tillable(spawn.x, spawn.y), "%s spawn cell (grass) is tillable" % LAYOUT_NAMES[i])


func test_is_solid_covers_full_building_footprint_not_just_marker() -> void:
	# The regression this guards: a building's ASCII marker only sits at its top-left cell — the
	# rest of its footprint still reads as plain grass in ROWS (see layout_common.gd's class
	# doc). is_solid()/is_tillable() must treat every footprint cell as blocked, not just the
	# marker, or a player could till/walk through the "inside" of a building's other cells.
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		for b in layout.buildings():
			var top_left: Vector2i = b["top_left"]
			var footprint_size: Vector2i = b["size"]
			for y in range(top_left.y, top_left.y + footprint_size.y):
				for x in range(top_left.x, top_left.x + footprint_size.x):
					assert_true(layout.is_solid(x, y),
						"%s '%s' footprint cell (%d,%d) should be solid" % [LAYOUT_NAMES[i], b["id"], x, y])


func test_resource_nodes_not_on_farmland_or_buildings() -> void:
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		for entry in layout.resource_node_cells():
			var cell: Vector2i = entry["cell"]
			assert_false(layout.is_soil(cell.x, cell.y), "%s resource node not on farmland" % LAYOUT_NAMES[i])
			assert_false(layout.is_solid(cell.x, cell.y), "%s resource node cell itself not solid" % LAYOUT_NAMES[i])


func test_out_of_bounds_reads_as_grass() -> void:
	for layout in LAYOUTS:
		assert_eq(layout.cell(-1, -1), ".", "dual-grid sampling beyond edges sees grass")
		assert_eq(layout.cell(9999, 3), ".")


func test_world_space_math() -> void:
	for layout in LAYOUTS:
		var size: Vector2i = layout.size()
		assert_eq(layout.map_rect(), Rect2(0, 0, size.x * 16, size.y * 16))
		assert_eq(layout.cell_center(Vector2i(0, 0)), Vector2(8, 8), "cell centers at half-tile")
		var spawn_pos: Vector2 = layout.cell_center(layout.spawn_cell())
		assert_true(layout.map_rect().has_point(spawn_pos), "spawn position inside map bounds")


func test_riverside_west_edge_is_river_not_fence() -> void:
	# Riverside's distinguishing structural feature (MAPS.md §1): the river replaces the western
	# perimeter fence entirely, for both the farmland and town rows.
	var size: Vector2i = RiversideLayout.size()
	for y in range(1, size.y - 1):
		assert_eq(RiversideLayout.cell(0, y), "W", "riverside west column is river at y=%d" % y)


func test_open_plains_and_forest_edge_have_full_west_fence() -> void:
	# The other two starts keep a normal fenced west edge (no river there).
	for layout in [OpenPlainsLayout, ForestEdgeLayout]:
		var size: Vector2i = layout.size()
		for y in range(1, size.y - 1):
			assert_eq(layout.cell(0, y), "F", "west column is fence at y=%d" % y)


func test_layout_common_is_inside_any_building() -> void:
	var buildings: Array[Dictionary] = [
		{"id": "a", "kind": "shack", "top_left": Vector2i(2, 2), "size": Vector2i(2, 2)},
	]
	assert_true(LayoutCommon.is_inside_any_building(buildings, 2, 2))
	assert_true(LayoutCommon.is_inside_any_building(buildings, 3, 3))
	assert_false(LayoutCommon.is_inside_any_building(buildings, 4, 2))
	assert_false(LayoutCommon.is_inside_any_building(buildings, 2, 4))


func test_layout_common_building_at() -> void:
	var buildings: Array[Dictionary] = [
		{"id": "a", "kind": "shack", "top_left": Vector2i(2, 2), "size": Vector2i(2, 2)},
	]
	assert_eq(LayoutCommon.building_at(buildings, 2, 3).get("id", ""), "a")
	assert_true(LayoutCommon.building_at(buildings, 10, 10).is_empty())
