extends "res://tests/test_case.gd"
## Phase 4 map-layout data integrity, restructured for the Farm/Path/Town/Ranch zone split:
## the old "3 combined-map settlements" table is now the per-zone matrix "3 farm variants ×
## {path standard/riverside} × {town standard/riverside} × {ranch standard/riverside}".
## Structural checks (grids, footprints, solidity) run over ALL layouts; content checks live
## with the zone that owns that content (town-core buildings + TOWN_NPCS → town layouts, ranch
## compound + RANCH_NPCS → ranch layouts, farmland/spawn → farm layouts, Farm and Path both
## assert EMPTY rosters); gate_cells() counts are derived per zone. The zone-transition plan's
## Stage 3 completed the zone_exits() well-formedness gate: every exit's gate cells are real
## authored 'G' cells, every entry cell is unblocked (and not itself a gate) in the target
## zone, every target zone name resolves through the real SettlementDB dispatcher, and the
## full cross-zone graph is bidirectionally consistent — so a future zone addition can't
## silently create a one-way or dangling connection.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")
const SettlementDB := preload("res://scripts/settlement_db.gd")
const OpenPlainsLayout := preload("res://scripts/map_layouts/open_plains_layout.gd")
const ForestEdgeLayout := preload("res://scripts/map_layouts/forest_edge_layout.gd")
const RiversideLayout := preload("res://scripts/map_layouts/riverside_layout.gd")
const PathStandardLayout := preload("res://scripts/map_layouts/path_layout_standard.gd")
const PathRiversideLayout := preload("res://scripts/map_layouts/path_layout_riverside.gd")
const TownStandardLayout := preload("res://scripts/map_layouts/town_layout_standard.gd")
const TownRiversideLayout := preload("res://scripts/map_layouts/town_layout_riverside.gd")
const RanchStandardLayout := preload("res://scripts/map_layouts/ranch_layout_standard.gd")
const RanchRiversideLayout := preload("res://scripts/map_layouts/ranch_layout_riverside.gd")

const LEGAL_CHARS := [".", "f", ",", "p", "#", "@", "T", "O", "H", "C", "D", "M", "R", "K", "B", "S", "W", "F", "G",
	"g", "N", "Y", "P"]  # Ranch/Sanctuary markers (MAPS.md §3): raNch house, barn (Y), cooP
const FARM_BUILDING_KINDS := ["farmhouse", "chest", "bed", "shipping_box"]
const TOWN_BUILDING_KINDS := ["mayor_house", "store", "shack", "bulletin_board"]

const FARM_LAYOUTS := [OpenPlainsLayout, ForestEdgeLayout, RiversideLayout]
const FARM_NAMES := ["open_plains", "forest_edge", "riverside"]
const TOWN_LAYOUTS := [TownStandardLayout, TownRiversideLayout]
const TOWN_NAMES := ["town_standard", "town_riverside"]
const RANCH_LAYOUTS := [RanchStandardLayout, RanchRiversideLayout]
const RANCH_NAMES := ["ranch_standard", "ranch_riverside"]
const PATH_LAYOUTS := [PathStandardLayout, PathRiversideLayout]
const PATH_NAMES := ["path_standard", "path_riverside"]

const ALL_LAYOUTS := [OpenPlainsLayout, ForestEdgeLayout, RiversideLayout,
	PathStandardLayout, PathRiversideLayout, TownStandardLayout, TownRiversideLayout,
	RanchStandardLayout, RanchRiversideLayout]
const ALL_NAMES := ["open_plains", "forest_edge", "riverside",
	"path_standard", "path_riverside", "town_standard", "town_riverside",
	"ranch_standard", "ranch_riverside"]

## The standard/riverside zone pairings the game actually plays (settlement_db.layout_for_zone
## dispatches exactly these): one zone_map per variant, keyed by zone id. Forest Edge shares the
## standard Path/Town/Ranch variants but brings its own farm terrain — the graph checks below
## run it as a third pairing (standard zones + the Forest Edge farm) so all THREE playable
## worlds get the full consistency sweep, not just the two variant archetypes.
const VARIANT_ZONE_MAPS := {
	"standard": {"farm": OpenPlainsLayout, "path": PathStandardLayout,
		"town": TownStandardLayout, "ranch": RanchStandardLayout},
	"forest_edge": {"farm": ForestEdgeLayout, "path": PathStandardLayout,
		"town": TownStandardLayout, "ranch": RanchStandardLayout},
	"riverside": {"farm": RiversideLayout, "path": PathRiversideLayout,
		"town": TownRiversideLayout, "ranch": RanchRiversideLayout},
}
## The settlement id SettlementDB resolves each pairing under (layout_for_zone's second arg).
const VARIANT_SETTLEMENTS := {
	"standard": "open_plains", "forest_edge": "forest_edge", "riverside": "riverside"}


## -- Structural checks over every zone layout --

func test_all_layouts_are_rectangular() -> void:
	for layout in ALL_LAYOUTS:
		var rows: Array[String] = layout.ROWS
		var width: int = rows[0].length()
		for y in rows.size():
			assert_eq(rows[y].length(), width, "row %d width" % y)


func test_all_layouts_only_legal_characters() -> void:
	for i in ALL_LAYOUTS.size():
		var layout = ALL_LAYOUTS[i]
		var rows: Array[String] = layout.ROWS
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				assert_true(row[x] in LEGAL_CHARS,
					"%s cell (%d,%d) is '%s'" % [ALL_NAMES[i], x, y, row[x]])


func test_building_footprints_dont_overlap_each_other() -> void:
	for i in ALL_LAYOUTS.size():
		var layout = ALL_LAYOUTS[i]
		var occupied := {}
		for b in layout.buildings():
			var top_left: Vector2i = b["top_left"]
			var footprint_size: Vector2i = b["size"]
			for y in range(top_left.y, top_left.y + footprint_size.y):
				for x in range(top_left.x, top_left.x + footprint_size.x):
					var c := Vector2i(x, y)
					assert_false(occupied.has(c),
						"%s building '%s' overlaps '%s' at %s" \
							% [ALL_NAMES[i], b["id"], occupied.get(c, ""), c])
					occupied[c] = b["id"]


func test_is_tillable_excludes_buildings_fence_water() -> void:
	for i in ALL_LAYOUTS.size():
		var layout = ALL_LAYOUTS[i]
		for b in layout.buildings():
			var top_left: Vector2i = b["top_left"]
			assert_false(layout.is_tillable(top_left.x, top_left.y),
				"%s building '%s' top-left isn't tillable" % [ALL_NAMES[i], b["id"]])
		for c in layout.fence_cells():
			assert_false(layout.is_tillable(c.x, c.y), "%s fence cell isn't tillable" % ALL_NAMES[i])
		for c in layout.water_cells():
			assert_false(layout.is_tillable(c.x, c.y), "%s water cell isn't tillable" % ALL_NAMES[i])


func test_is_solid_covers_full_building_footprint_not_just_marker() -> void:
	# The regression this guards: a building's ASCII marker only sits at its top-left cell — the
	# rest of its footprint still reads as plain grass in ROWS (see layout_common.gd's class
	# doc). is_solid()/is_tillable() must treat every footprint cell as blocked, not just the
	# marker, or a player could till/walk through the "inside" of a building's other cells.
	for i in ALL_LAYOUTS.size():
		var layout = ALL_LAYOUTS[i]
		for b in layout.buildings():
			var top_left: Vector2i = b["top_left"]
			var footprint_size: Vector2i = b["size"]
			for y in range(top_left.y, top_left.y + footprint_size.y):
				for x in range(top_left.x, top_left.x + footprint_size.x):
					assert_true(layout.is_solid(x, y),
						"%s '%s' footprint cell (%d,%d) should be solid" % [ALL_NAMES[i], b["id"], x, y])


func test_resource_nodes_not_on_farmland_or_buildings() -> void:
	for i in ALL_LAYOUTS.size():
		var layout = ALL_LAYOUTS[i]
		for entry in layout.resource_node_cells():
			var cell: Vector2i = entry["cell"]
			assert_false(layout.is_soil(cell.x, cell.y), "%s resource node not on farmland" % ALL_NAMES[i])
			assert_false(layout.is_solid(cell.x, cell.y), "%s resource node cell itself not solid" % ALL_NAMES[i])


func test_out_of_bounds_reads_as_grass() -> void:
	for layout in ALL_LAYOUTS:
		assert_eq(layout.cell(-1, -1), ".", "dual-grid sampling beyond edges sees grass")
		assert_eq(layout.cell(9999, 3), ".")


func test_world_space_math() -> void:
	for layout in ALL_LAYOUTS:
		var size: Vector2i = layout.size()
		assert_eq(layout.map_rect(), Rect2(0, 0, size.x * 16, size.y * 16))
		assert_eq(layout.cell_center(Vector2i(0, 0)), Vector2(8, 8), "cell centers at half-tile")


## -- Zone exits: the full well-formedness gate (zone-transition plan, Stage 3) --

func test_zone_exits_gate_cells_are_real_gates() -> void:
	for i in ALL_LAYOUTS.size():
		var layout = ALL_LAYOUTS[i]
		var gate_cells: Array[Vector2i] = layout.gate_cells()
		assert_true(layout.zone_exits().size() > 0, "%s has at least one zone exit" % ALL_NAMES[i])
		for exit in layout.zone_exits():
			assert_true(String(exit["target_zone"]) in ["farm", "path", "town", "ranch"],
				"%s exit targets a real zone" % ALL_NAMES[i])
			for cell in exit["gate_cells"]:
				assert_true(cell in gate_cells,
					"%s exit gate cell %s is an authored 'G' cell" % [ALL_NAMES[i], cell])


func test_zone_exit_entry_cells_are_walkable_in_target_zone() -> void:
	# An exit's entry cell must be open ground in the matching variant of its target zone, and
	# must not itself be a gate cell there (or arrival would instantly re-trigger a warp back).
	for variant_name in VARIANT_ZONE_MAPS:
		var zone_map: Dictionary = VARIANT_ZONE_MAPS[variant_name]
		for zone_id in zone_map:
			var layout = zone_map[zone_id]
			for exit in layout.zone_exits():
				var target_id := String(exit["target_zone"])
				var entry: Vector2i = exit["entry_cell"]
				var target = zone_map[target_id]
				assert_false(target.is_solid(entry.x, entry.y),
					"%s(%s) exit → %s entry %s is walkable" % [zone_id, variant_name, target_id, entry])
				assert_false(entry in target.gate_cells(),
					"%s(%s) exit → %s entry %s is not itself a gate" % [zone_id, variant_name, target_id, entry])


func test_zone_exits_resolve_through_settlement_db() -> void:
	# Every target zone NAME must resolve — through the real dispatcher the game boots with
	# (settlement_db.layout_for_zone), to exactly the layout this variant pairing expects. This
	# is the "every target zone name resolves" gate with teeth: layout_for_zone's unknown-id
	# fallback returns the FARM layout, so a typo'd target would resolve to the wrong zone
	# silently at runtime — here it fails loudly instead.
	for variant_name in VARIANT_ZONE_MAPS:
		var zone_map: Dictionary = VARIANT_ZONE_MAPS[variant_name]
		var settlement_id := String(VARIANT_SETTLEMENTS[variant_name])
		for zone_id in zone_map:
			for exit in zone_map[zone_id].zone_exits():
				var target_id := String(exit["target_zone"])
				assert_true(zone_map.has(target_id),
					"%s(%s) exit targets a known zone id ('%s')" % [zone_id, variant_name, target_id])
				if not zone_map.has(target_id):
					continue
				assert_eq(SettlementDB.layout_for_zone(target_id, settlement_id), zone_map[target_id],
					"%s(%s) exit target '%s' resolves via SettlementDB to this pairing's layout"
						% [zone_id, variant_name, target_id])


func test_zone_exits_graph_is_bidirectionally_consistent() -> void:
	# The cross-zone graph gate: for every exit A→B, B must carry a matching reverse exit B→A
	# (no one-way or dangling connections — a future zone addition that forgets the return trip
	# fails here, not in play), and A→B's entry cell must sit orthogonally adjacent to one of
	# B's reverse gate cells — the geometric statement that both sides describe the SAME doorway
	# (arriving anywhere else would mean the two zones disagree about where the seam is).
	for variant_name in VARIANT_ZONE_MAPS:
		var zone_map: Dictionary = VARIANT_ZONE_MAPS[variant_name]
		for zone_id in zone_map:
			for exit in zone_map[zone_id].zone_exits():
				var target_id := String(exit["target_zone"])
				var reverse: Dictionary = {}
				for back in zone_map[target_id].zone_exits():
					if String(back["target_zone"]) == zone_id:
						reverse = back
				assert_false(reverse.is_empty(),
					"%s(%s): %s carries a reverse exit back to %s" \
						% [zone_id, variant_name, target_id, zone_id])
				if reverse.is_empty():
					continue
				var entry: Vector2i = exit["entry_cell"]
				var beside_return_gate := false
				for gate_cell in reverse["gate_cells"]:
					var d: Vector2i = (Vector2i(gate_cell) - entry).abs()
					if d.x + d.y == 1:
						beside_return_gate = true
				assert_true(beside_return_gate,
					"%s(%s)→%s entry %s lands orthogonally beside the return gate %s" \
						% [zone_id, variant_name, target_id, entry, str(reverse["gate_cells"])])


## -- Farm-zone checks (the 3 starting layouts, farm-only since the split) --

func test_farm_layouts_exactly_one_spawn() -> void:
	for i in FARM_LAYOUTS.size():
		var layout = FARM_LAYOUTS[i]
		var rows: Array[String] = layout.ROWS
		var count := 0
		for y in rows.size():
			for x in rows[y].length():
				if rows[y][x] == "@":
					count += 1
		assert_eq(count, 1, "%s exactly one '@' spawn marker" % FARM_NAMES[i])
		var spawn: Vector2i = layout.spawn_cell()
		assert_false(layout.is_solid(spawn.x, spawn.y), "%s spawn is not blocked" % FARM_NAMES[i])
		assert_true(layout.is_tillable(spawn.x, spawn.y), "%s spawn cell (grass) is tillable" % FARM_NAMES[i])


func test_farm_layouts_have_farm_building_kinds_only() -> void:
	for i in FARM_LAYOUTS.size():
		var layout = FARM_LAYOUTS[i]
		var kinds := {}
		for b in layout.buildings():
			kinds[String(b["kind"])] = kinds.get(String(b["kind"]), 0) + 1
		for kind in FARM_BUILDING_KINDS:
			assert_eq(kinds.get(kind, 0), 1, "%s has exactly one '%s'" % [FARM_NAMES[i], kind])
		for kind in TOWN_BUILDING_KINDS:
			assert_eq(kinds.get(kind, 0), 0,
				"%s no longer hosts town building '%s' (moved to the town zone)" % [FARM_NAMES[i], kind])


func test_bed_is_1x1_and_reachable() -> void:
	# Phase 4 Stage 3: every start has exactly one farmhouse bed, 1x1 like the chest, with at
	# least one walkable orthogonal neighbour cell the player can stand on to interact with it.
	for i in FARM_LAYOUTS.size():
		var layout = FARM_LAYOUTS[i]
		var beds: Array[Dictionary] = []
		for b in layout.buildings():
			if String(b["kind"]) == "bed":
				beds.append(b)
		assert_eq(beds.size(), 1, "%s has exactly one bed" % FARM_NAMES[i])
		var bed: Dictionary = beds[0]
		assert_eq(bed["size"], Vector2i(1, 1), "%s bed is 1x1" % FARM_NAMES[i])
		var cell: Vector2i = bed["top_left"]
		var reachable := false
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + offset
			if not layout.is_solid(n.x, n.y):
				reachable = true
		assert_true(reachable, "%s bed has a walkable neighbour to interact from" % FARM_NAMES[i])


func test_shipping_box_is_1x1_beside_chest_and_bed_and_reachable() -> void:
	# Phase 5 Stage 3: every start has exactly one shipping box, 1x1 like the chest/bed, sitting
	# in the same farmhouse "service row" as both (same y, x strictly between the chest's and the
	# bed's — the authored chest/box/bed line each layout file documents), with at least one
	# walkable orthogonal neighbour to interact from.
	for i in FARM_LAYOUTS.size():
		var layout = FARM_LAYOUTS[i]
		var boxes: Array[Dictionary] = []
		var chest_cell := Vector2i(-1, -1)
		var bed_cell := Vector2i(-1, -1)
		for b in layout.buildings():
			match String(b["kind"]):
				"shipping_box": boxes.append(b)
				"chest": chest_cell = b["top_left"]
				"bed": bed_cell = b["top_left"]
		assert_eq(boxes.size(), 1, "%s has exactly one shipping box" % FARM_NAMES[i])
		var box: Dictionary = boxes[0]
		assert_eq(box["size"], Vector2i(1, 1), "%s shipping box is 1x1" % FARM_NAMES[i])
		var cell: Vector2i = box["top_left"]
		assert_eq(cell.y, chest_cell.y, "%s box shares the chest's row" % FARM_NAMES[i])
		assert_eq(cell.y, bed_cell.y, "%s box shares the bed's row" % FARM_NAMES[i])
		assert_true(chest_cell.x < cell.x and cell.x < bed_cell.x,
			"%s box sits between the chest and the bed" % FARM_NAMES[i])
		var reachable := false
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + offset
			if not layout.is_solid(n.x, n.y):
				reachable = true
		assert_true(reachable, "%s shipping box has a walkable neighbour" % FARM_NAMES[i])


func test_shipping_box_marker_char_matches_building_cell() -> void:
	# The 'S' ASCII marker and the BUILDINGS entry are two statements of the same fact — they
	# must agree (the same guarantee every other marker/building pair gets implicitly via
	# is_solid, made explicit here since the pair was authored by hand in 3 files).
	for i in FARM_LAYOUTS.size():
		var layout = FARM_LAYOUTS[i]
		var marker_cells: Array[Vector2i] = []
		var rows: Array[String] = layout.ROWS
		for y in rows.size():
			for x in rows[y].length():
				if rows[y][x] == "S":
					marker_cells.append(Vector2i(x, y))
		assert_eq(marker_cells.size(), 1, "%s has exactly one 'S' marker" % FARM_NAMES[i])
		var box: Dictionary = {}
		for b in layout.buildings():
			if String(b["kind"]) == "shipping_box":
				box = b
		assert_eq(marker_cells[0], box["top_left"],
			"%s 'S' marker sits at the shipping box's authored cell" % FARM_NAMES[i])


func test_farm_layouts_have_farmland_resource_nodes_and_gap() -> void:
	for i in FARM_LAYOUTS.size():
		var layout = FARM_LAYOUTS[i]
		var rows: Array[String] = layout.ROWS
		var soil_count := 0
		for y in rows.size():
			for x in rows[y].length():
				if rows[y][x] == "f":
					soil_count += 1
		assert_true(soil_count > 0, "%s has tillable/pre-tilled farmland" % FARM_NAMES[i])
		assert_true(layout.resource_node_cells().size() > 0, "%s has at least one resource node" % FARM_NAMES[i])
		assert_true(layout.farm_gap_cells().size() > 0, "%s has the farm's perimeter fence gap" % FARM_NAMES[i])


func test_farm_layouts_are_the_expanded_72x32_grid() -> void:
	# Pre-Stage-4 farm expansion (2026-08-09): all 3 farm variants share one 72x32 frame, and the
	# homestead template (farmhouse + the chest/box/bed service row + the spawn) is what every
	# companion tool anchors against — so the size and that template are asserted together here
	# rather than left implicit. The other structural tests above are size-agnostic by design and
	# deliberately stay that way; this is the single place the number itself is pinned.
	for i in FARM_LAYOUTS.size():
		var layout = FARM_LAYOUTS[i]
		assert_eq(layout.size(), Vector2i(72, 32), "%s is the expanded 72x32 farm" % FARM_NAMES[i])
		assert_eq(layout.map_rect(), Rect2(0, 0, 72 * 16, 32 * 16),
			"%s world-space bounds follow the new size" % FARM_NAMES[i])


func test_farm_layouts_have_the_east_path_gate_and_the_south_ranch_gate() -> void:
	# The zone split's east-wall gate-break (2 'G' cells, targeting the Path zone) plus the
	# expansion's south-wall gate-break (2 more), wired to the Ranch by the 2026-08-09 relocation
	# — so the farm now carries 4 gate cells and TWO zone exits, and it is the only zone with more
	# than one neighbour (Path east, Ranch south).
	for i in FARM_LAYOUTS.size():
		var layout = FARM_LAYOUTS[i]
		var gates: Array[Vector2i] = layout.gate_cells()
		assert_eq(gates.size(), 4,
			"%s has the 2-cell east gate + the 2-cell south gate" % FARM_NAMES[i])
		var east_x: int = layout.size().x - 1
		var south_y: int = layout.size().y - 1
		var east_gates: Array[Vector2i] = []
		var south_gates: Array[Vector2i] = []
		for cell in gates:
			if cell.x == east_x:
				east_gates.append(cell)
			elif cell.y == south_y:
				south_gates.append(cell)
			else:
				assert_true(false,
					"%s gate cell %s is in neither perimeter wall" % [FARM_NAMES[i], cell])
		assert_eq(east_gates.size(), 2, "%s east gate is 2 cells" % FARM_NAMES[i])
		assert_eq(south_gates.size(), 2, "%s south gate is 2 cells" % FARM_NAMES[i])
		for cell in south_gates:
			assert_false(layout.is_solid(cell.x, cell.y - 1),
				"%s south gate cell %s has open ground just inside it" % [FARM_NAMES[i], cell])
		for cell in east_gates:
			assert_false(layout.is_solid(cell.x - 1, cell.y),
				"%s east gate cell %s has open ground just inside it" % [FARM_NAMES[i], cell])
		assert_eq(layout.zone_exits().size(), 2,
			"%s has two zone exits (east->path, south->ranch)" % FARM_NAMES[i])
		var targets_by_gate := {}
		for exit in layout.zone_exits():
			for cell in exit["gate_cells"]:
				targets_by_gate[cell] = String(exit["target_zone"])
		for cell in east_gates:
			assert_eq(String(targets_by_gate.get(cell, "")), "path",
				"%s east gate cell %s exits to the path" % [FARM_NAMES[i], cell])
		for cell in south_gates:
			assert_eq(String(targets_by_gate.get(cell, "")), "ranch",
				"%s south gate cell %s exits to the ranch" % [FARM_NAMES[i], cell])
		assert_true(layout.npcs().is_empty(), "%s farm hosts no NPCs since the split" % FARM_NAMES[i])
		assert_true(layout.decor_props().is_empty(), "%s farm has no decor props" % FARM_NAMES[i])


func test_open_plains_and_forest_edge_share_south_gate_columns() -> void:
	# The hard constraint behind the expansion's south-gate placement: VARIANT_ZONE_MAPS pairs
	# BOTH the "standard" (Open Plains) and "forest_edge" farms with the same
	# RanchStandardLayout, and the Ranch's single return exit into the farm can carry only ONE
	# entry_cell — so the two farms' south gates must sit at identical columns or one of the two
	# playable worlds gets a misaligned seam. Kept as its own assertion even now that the
	# relocation has wired both sides, because the failure mode is a wrong arrival cell in ONE of
	# the two pairings rather than an obvious crash: the bidirectional-consistency check above
	# would still pass if a future edit moved only open_plains' gate and updated the Ranch to
	# match, silently stranding forest_edge.
	var columns: Array = []
	for layout in [OpenPlainsLayout, ForestEdgeLayout]:
		var south_y: int = layout.size().y - 1
		var cols: Array[int] = []
		for cell in layout.gate_cells():
			if cell.y == south_y:
				cols.append(cell.x)
		cols.sort()
		columns.append(cols)
	assert_eq(columns[0].size(), 2, "open_plains has a 2-cell south gate")
	assert_eq(columns[0], columns[1],
		"open_plains and forest_edge place their south gate at the same columns (%s vs %s)"
			% [str(columns[0]), str(columns[1])])


## -- Town-zone checks --

func test_town_layouts_have_town_core() -> void:
	for i in TOWN_LAYOUTS.size():
		var layout = TOWN_LAYOUTS[i]
		var kinds := {}
		for b in layout.buildings():
			kinds[String(b["kind"])] = kinds.get(String(b["kind"]), 0) + 1
		for kind in TOWN_BUILDING_KINDS:
			assert_true(kinds.get(kind, 0) > 0, "%s missing building kind '%s'" % [TOWN_NAMES[i], kind])
		assert_true(kinds.get("shack", 0) >= 3, "%s has at least 3 settler shacks" % TOWN_NAMES[i])
		assert_true(layout.dock_cells().size() > 0, "%s has dock plank cells" % TOWN_NAMES[i])
		assert_true(layout.water_cells().size() > 0, "%s has a water body" % TOWN_NAMES[i])
		# Since the 2026-08-09 ranch relocation the south wall is resealed plain fence and the
		# Town is a leaf of the zone graph — the 2-cell west path gate is all that is left.
		assert_eq(layout.gate_cells().size(), 2,
			"%s has only the 2-cell west path gate" % TOWN_NAMES[i])
		var south_y: int = layout.size().y - 1
		for cell in layout.gate_cells():
			assert_eq(cell.x, 0, "%s gate cell %s is in the west wall" % [TOWN_NAMES[i], cell])
			assert_true(cell.y != south_y,
				"%s has no south-wall gate left" % TOWN_NAMES[i])
		assert_eq(layout.zone_exits().size(), 1, "%s has one zone exit" % TOWN_NAMES[i])
		assert_eq(String(layout.zone_exits()[0]["target_zone"]), "path",
			"%s's only exit is the Path corridor" % TOWN_NAMES[i])


func test_town_layouts_expose_the_town_npc_roster() -> void:
	for i in TOWN_LAYOUTS.size():
		var layout = TOWN_LAYOUTS[i]
		assert_eq(layout.npcs(), LayoutCommon.TOWN_NPCS,
			"%s's npcs() is the shared town-core roster" % TOWN_NAMES[i])
		for entry in layout.npcs():
			var home: Vector2i = entry["home"]
			assert_false(layout.is_solid(home.x, home.y),
				"%s npc '%s' home cell %s isn't blocked" % [TOWN_NAMES[i], entry["id"], home])


func test_npc_roster_has_three_unique_ids_and_positive_radius() -> void:
	var ids := {}
	for entry in LayoutCommon.TOWN_NPCS:
		var id := String(entry["id"])
		assert_false(ids.has(id), "npc id '%s' is unique in the roster" % id)
		ids[id] = true
		assert_true(int(entry["wander_radius"]) > 0, "%s has a positive wander radius" % id)
	assert_eq(ids.size(), 3, "exactly 3 town-core NPCs")


## -- Ranch-zone checks (MAPS.md §3) --

func test_ranch_layouts_have_ranch_buildings() -> void:
	for i in RANCH_LAYOUTS.size():
		var layout = RANCH_LAYOUTS[i]
		var kinds := {}
		for b in layout.buildings():
			kinds[String(b["kind"])] = kinds.get(String(b["kind"]), 0) + 1
		for kind in ["ranch_house", "ranch_barn", "ranch_coop"]:
			assert_eq(kinds.get(kind, 0), 1, "%s has exactly one %s" % [RANCH_NAMES[i], kind])
		# The south zone gate (2 cells) + TWO cosmetic inner compound gates (2 cells each: the
		# pre-existing row-4 break, plus a row-15 break added the same day as the relocation to
		# remove the detour it otherwise left between the south arrival and the compound
		# interior) = 6. Still only 1 real zone_exits() entry — asserted below — so a silent
		# reversal (an extra exit, or the wrong wall growing a gate) can't hide behind the count.
		assert_eq(layout.gate_cells().size(), 6,
			"%s has the south farm gate + 2 cosmetic inner gates = 6 'G' cells" % RANCH_NAMES[i])
		var south_y: int = layout.size().y - 1
		var south_gates: Array[Vector2i] = []
		for cell in layout.gate_cells():
			assert_true(cell.y != 0, "%s north wall is resealed (no 'G' in row 0)" % RANCH_NAMES[i])
			if cell.y == south_y:
				south_gates.append(cell)
		assert_eq(south_gates.size(), 2, "%s south zone gate is 2 cells" % RANCH_NAMES[i])
		for cell in south_gates:
			assert_false(layout.is_solid(cell.x, cell.y - 1),
				"%s south gate cell %s has open ground just inside it" % [RANCH_NAMES[i], cell])
		# The new row-15 inner gate: confirm it's genuinely open on both sides (the approach
		# yard below and the compound interior above), not just present in the wall string.
		for gx in [17, 18]:
			assert_false(layout.is_solid(gx, 14),
				"%s (%d,14) is open north of the row-15 inner gate" % [RANCH_NAMES[i], gx])
			assert_false(layout.is_solid(gx, 16),
				"%s (%d,16) is open south of the row-15 inner gate" % [RANCH_NAMES[i], gx])
		assert_eq(layout.zone_exits().size(), 1, "%s has one zone exit" % RANCH_NAMES[i])
		assert_eq(String(layout.zone_exits()[0]["target_zone"]), "farm",
			"%s's only exit leads back to the farm" % RANCH_NAMES[i])


func test_ranch_layouts_expose_the_ranch_npc_roster() -> void:
	# Per-zone roster split (zone-transition Stage 3): the ranch asserts RANCH_NPCS and ONLY
	# RANCH_NPCS — the exact-equality mirror of the town's TOWN_NPCS check above, so a
	# misplaced NPC can't hide behind a weaker contains-the-keeper check.
	for i in RANCH_LAYOUTS.size():
		var layout = RANCH_LAYOUTS[i]
		assert_eq(layout.npcs(), LayoutCommon.RANCH_NPCS,
			"%s's npcs() is exactly the shared ranch roster" % RANCH_NAMES[i])
		var homes := {}
		for entry in layout.npcs():
			homes[String(entry["id"])] = entry["home"]
		assert_true(homes.has("rancher_silas"), "%s roster includes the ranch keeper" % RANCH_NAMES[i])
		var home: Vector2i = homes["rancher_silas"]
		assert_false(layout.is_solid(home.x, home.y),
			"%s ranch keeper's home cell %s isn't blocked" % [RANCH_NAMES[i], home])


func test_ranch_layouts_decor_props_are_on_open_ground() -> void:
	# Decorative animal props stand on grass inside the compound — never on a building, fence,
	# water, or off-map cell (they'd render nonsensically otherwise).
	for i in RANCH_LAYOUTS.size():
		var layout = RANCH_LAYOUTS[i]
		var props: Array[Dictionary] = layout.decor_props()
		assert_true(props.size() > 0, "%s has ranch decor props" % RANCH_NAMES[i])
		var size: Vector2i = layout.size()
		for prop in props:
			var cell: Vector2i = prop["cell"]
			assert_true(cell.x >= 0 and cell.x < size.x and cell.y >= 0 and cell.y < size.y,
				"%s decor prop %s is in bounds" % [RANCH_NAMES[i], cell])
			assert_false(layout.is_solid(cell.x, cell.y),
				"%s decor prop cell %s isn't blocked" % [RANCH_NAMES[i], cell])


## -- Path-zone checks (the zone split's new corridor) --

func test_path_layouts_are_a_bare_corridor_with_dressing() -> void:
	for i in PATH_LAYOUTS.size():
		var layout = PATH_LAYOUTS[i]
		assert_true(layout.buildings().is_empty(), "%s has no buildings" % PATH_NAMES[i])
		assert_true(layout.npcs().is_empty(), "%s has no NPCs" % PATH_NAMES[i])
		assert_true(layout.resource_node_cells().is_empty(),
			"%s has no choppable/minable nodes" % PATH_NAMES[i])
		# The west Farm gate (2) + east Town gate (2).
		assert_eq(layout.gate_cells().size(), 4, "%s has 4 zone-gate cells" % PATH_NAMES[i])
		assert_true(layout.dock_cells().size() > 0,
			"%s has road/plank cells (the ruined road)" % PATH_NAMES[i])
		# The dressing: exactly one wrecked-car landmark, plus weeds, all on open ground.
		var cars := 0
		for prop in layout.decor_props():
			if String(prop["kind"]) == "wrecked_car":
				cars += 1
			var cell: Vector2i = prop["cell"]
			assert_false(layout.is_solid(cell.x, cell.y),
				"%s prop cell %s isn't blocked" % [PATH_NAMES[i], cell])
		assert_eq(cars, 1, "%s has exactly one wrecked-car landmark" % PATH_NAMES[i])


func test_path_checkpoint_is_sealed() -> void:
	# The locked checkpoint structure (north side): its rubble-sealed gateway must be SOLID —
	# the "visible but impassable" guarantee ("structure now, system later," like the ranch's
	# unbuilt buy-animal shop). Cells (10-13, 1) per the authored ROWS.
	for i in PATH_LAYOUTS.size():
		var layout = PATH_LAYOUTS[i]
		for x in range(10, 14):
			assert_true(layout.is_solid(x, 1),
				"%s checkpoint gateway cell (%d,1) is sealed/solid" % [PATH_NAMES[i], x])


## -- Riverside identity (MAPS.md §1) --

func test_riverside_west_edge_is_river_not_fence() -> void:
	# Riverside's distinguishing structural feature: the river replaces the western perimeter
	# fence entirely — on the farm AND on the town/ranch zone variants (their west columns are
	# 'W' except the town's 2 west-gate cells, where the Path bridge lands).
	var size: Vector2i = RiversideLayout.size()
	for y in range(1, size.y - 1):
		assert_eq(RiversideLayout.cell(0, y), "W", "riverside farm west column is river at y=%d" % y)
	for layout in [TownRiversideLayout, RanchRiversideLayout]:
		for y in layout.size().y:
			assert_true(layout.cell(0, y) in ["W", "G"],
				"riverside zone west column is river (or the bridge gate) at y=%d" % y)


func test_open_plains_and_forest_edge_have_full_west_fence() -> void:
	# The other two starts keep a normal fenced west edge (no river there).
	for layout in [OpenPlainsLayout, ForestEdgeLayout]:
		var size: Vector2i = layout.size()
		for y in range(1, size.y - 1):
			assert_eq(layout.cell(0, y), "F", "west column is fence at y=%d" % y)


## -- LayoutCommon pure helpers --

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


## 2026-10-07 reclaim-the-farm: a new game starts on a small tilled patch beside the homestead,
## with the rest of the old farmland overgrown (',') and waiting to be won back.
func test_farm_layouts_start_with_a_starter_patch_and_old_fields() -> void:
	for i in FARM_LAYOUTS.size():
		var layout = FARM_LAYOUTS[i]
		var rows: Array[String] = layout.ROWS
		var spawn: Vector2i = layout.spawn_cell()
		var soil := 0
		var old_field := 0
		for y in rows.size():
			for x in rows[y].length():
				match rows[y][x]:
					"f":
						soil += 1
						assert_true(absi(x - spawn.x) <= 8 and absi(y - spawn.y) <= 8,
							"%s starter soil (%d,%d) sits near the homestead" % [FARM_NAMES[i], x, y])
					",":
						old_field += 1
						assert_true(layout.is_tillable(x, y), "%s old field is tillable" % FARM_NAMES[i])
						assert_false(layout.is_soil(x, y), "%s old field starts untilled" % FARM_NAMES[i])
		assert_eq(soil, 12, "%s keeps a 4x3 starter patch" % FARM_NAMES[i])
		assert_true(old_field >= 150, "%s has old fields to reclaim (%d)" % [FARM_NAMES[i], old_field])
