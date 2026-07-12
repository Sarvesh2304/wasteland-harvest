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

const LEGAL_CHARS := [".", "f", "p", "#", "@", "T", "O", "H", "C", "D", "M", "R", "K", "B", "S", "W", "F", "G", "g",
	"N", "Y", "P"]  # Ranch/Sanctuary markers (MAPS.md §3): raNch house, barn (Y), cooP
const REQUIRED_BUILDING_KINDS := ["farmhouse", "chest", "bed", "shipping_box", "mayor_house", "store", "shack", "bulletin_board"]

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


func test_bed_is_1x1_and_reachable() -> void:
	# Phase 4 Stage 3: every start has exactly one farmhouse bed, 1x1 like the chest, with at
	# least one walkable orthogonal neighbour cell the player can stand on to interact with it.
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		var beds: Array[Dictionary] = []
		for b in layout.buildings():
			if String(b["kind"]) == "bed":
				beds.append(b)
		assert_eq(beds.size(), 1, "%s has exactly one bed" % LAYOUT_NAMES[i])
		var bed: Dictionary = beds[0]
		assert_eq(bed["size"], Vector2i(1, 1), "%s bed is 1x1" % LAYOUT_NAMES[i])
		var cell: Vector2i = bed["top_left"]
		var reachable := false
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + offset
			if not layout.is_solid(n.x, n.y):
				reachable = true
		assert_true(reachable, "%s bed has a walkable neighbour to interact from" % LAYOUT_NAMES[i])


func test_shipping_box_is_1x1_beside_chest_and_bed_and_reachable() -> void:
	# Phase 5 Stage 3: every start has exactly one shipping box, 1x1 like the chest/bed, sitting
	# in the same farmhouse "service row" as both (same y, x strictly between the chest's and the
	# bed's — the authored chest/box/bed line each layout file documents), with at least one
	# walkable orthogonal neighbour to interact from.
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		var boxes: Array[Dictionary] = []
		var chest_cell := Vector2i(-1, -1)
		var bed_cell := Vector2i(-1, -1)
		for b in layout.buildings():
			match String(b["kind"]):
				"shipping_box": boxes.append(b)
				"chest": chest_cell = b["top_left"]
				"bed": bed_cell = b["top_left"]
		assert_eq(boxes.size(), 1, "%s has exactly one shipping box" % LAYOUT_NAMES[i])
		var box: Dictionary = boxes[0]
		assert_eq(box["size"], Vector2i(1, 1), "%s shipping box is 1x1" % LAYOUT_NAMES[i])
		var cell: Vector2i = box["top_left"]
		assert_eq(cell.y, chest_cell.y, "%s box shares the chest's row" % LAYOUT_NAMES[i])
		assert_eq(cell.y, bed_cell.y, "%s box shares the bed's row" % LAYOUT_NAMES[i])
		assert_true(chest_cell.x < cell.x and cell.x < bed_cell.x,
			"%s box sits between the chest and the bed" % LAYOUT_NAMES[i])
		var reachable := false
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + offset
			if not layout.is_solid(n.x, n.y):
				reachable = true
		assert_true(reachable, "%s shipping box has a walkable neighbour" % LAYOUT_NAMES[i])


func test_shipping_box_marker_char_matches_building_cell() -> void:
	# The 'S' ASCII marker and the BUILDINGS entry are two statements of the same fact — they
	# must agree (the same guarantee every other marker/building pair gets implicitly via
	# is_solid, made explicit here since the pair was authored by hand in 3 files).
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		var marker_cells: Array[Vector2i] = []
		var rows: Array[String] = layout.ROWS
		for y in rows.size():
			for x in rows[y].length():
				if rows[y][x] == "S":
					marker_cells.append(Vector2i(x, y))
		assert_eq(marker_cells.size(), 1, "%s has exactly one 'S' marker" % LAYOUT_NAMES[i])
		var box: Dictionary = {}
		for b in layout.buildings():
			if String(b["kind"]) == "shipping_box":
				box = b
		assert_eq(marker_cells[0], box["top_left"],
			"%s 'S' marker sits at the shipping box's authored cell" % LAYOUT_NAMES[i])


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


## -- Phase 5 Stage 1: shared town-core NPC roster (LayoutCommon.TOWN_NPCS) --

func test_all_layouts_expose_the_shared_npc_roster() -> void:
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		var npcs: Array[Dictionary] = layout.npcs()
		assert_eq(npcs, LayoutCommon.all_npcs(),
			"%s's npcs() is the same shared roster (town core + ranch keeper)" % LAYOUT_NAMES[i])


func test_all_layouts_npc_home_cells_are_walkable() -> void:
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		for entry in layout.npcs():
			var home: Vector2i = entry["home"]
			assert_false(layout.is_solid(home.x, home.y),
				"%s npc '%s' home cell %s isn't blocked" % [LAYOUT_NAMES[i], entry["id"], home])


func test_npc_roster_has_three_unique_ids_and_positive_radius() -> void:
	var ids := {}
	for entry in LayoutCommon.TOWN_NPCS:
		var id := String(entry["id"])
		assert_false(ids.has(id), "npc id '%s' is unique in the roster" % id)
		ids[id] = true
		assert_true(int(entry["wander_radius"]) > 0, "%s has a positive wander radius" % id)
	assert_eq(ids.size(), 3, "exactly 3 town-core NPCs")


## -- MAPS.md §3: the Ranch/Sanctuary southern compound (shared verbatim by all 3 starts) --

func test_all_layouts_have_ranch_buildings() -> void:
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		var kinds := {}
		for b in layout.buildings():
			kinds[String(b["kind"])] = kinds.get(String(b["kind"]), 0) + 1
		for kind in ["ranch_house", "ranch_barn", "ranch_coop"]:
			assert_eq(kinds.get(kind, 0), 1, "%s has exactly one %s" % [LAYOUT_NAMES[i], kind])


func test_all_layouts_have_the_ranch_keeper_npc() -> void:
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		var homes := {}
		for entry in layout.npcs():
			homes[String(entry["id"])] = entry["home"]
		assert_true(homes.has("rancher_silas"), "%s roster includes the ranch keeper" % LAYOUT_NAMES[i])
		var home: Vector2i = homes["rancher_silas"]
		assert_false(layout.is_solid(home.x, home.y),
			"%s ranch keeper's home cell %s isn't blocked" % [LAYOUT_NAMES[i], home])


func test_all_layouts_ranch_decor_props_are_on_open_ground() -> void:
	# Decorative animal props stand on grass inside the compound — never on a building, fence,
	# water, or off-map cell (they'd render nonsensically otherwise).
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		var props: Array[Dictionary] = layout.decor_props()
		assert_true(props.size() > 0, "%s has ranch decor props" % LAYOUT_NAMES[i])
		var size: Vector2i = layout.size()
		for prop in props:
			var cell: Vector2i = prop["cell"]
			assert_true(cell.x >= 0 and cell.x < size.x and cell.y >= 0 and cell.y < size.y,
				"%s decor prop %s is in bounds" % [LAYOUT_NAMES[i], cell])
			assert_false(layout.is_solid(cell.x, cell.y),
				"%s decor prop cell %s isn't blocked" % [LAYOUT_NAMES[i], cell])


func test_all_layouts_have_town_and_ranch_gates() -> void:
	# The town's main south gate (2 cells) plus the ranch compound's own entrance gate (2 cells).
	for i in LAYOUTS.size():
		var layout = LAYOUTS[i]
		assert_eq(layout.gate_cells().size(), 4,
			"%s has the town gate + ranch gate = 4 'G' cells" % LAYOUT_NAMES[i])
