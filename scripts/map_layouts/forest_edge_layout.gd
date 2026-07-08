extends RefCounted
## Forest Edge starting layout (ROADMAP.md Phase 4 / MAPS.md §1) — the "ruin materials" lean.
##
## A reclaimed pre-war suburb: dense treeline along the farm's north/east edges (woven with
## collapsed-wall rubble and scrap piles — salvage within walking distance from day one, this
## start's resource lean), a south-west creek, and farmland broken into several smaller irregular
## patches rather than one clean rectangle ("worst total plantable area of the three", per
## MAPS.md). Shares the same town-core template as the other two starts.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size (shared across all 3 starts)

const ROWS: Array[String] = [
	"FFFFFFFFFFFFFFFFFgFFFFFFFFFFFFFFFFFF",
	"F...................T#T.T#T.O.T.T..F",
	"F...............H................T.F",
	"F.................................TF",
	"F...............C................T.F",
	"F................@.................F",
	"F.....ffffff.....................OTF",
	"F.....ffffff.ffffff................F",
	"F.....ffffff.ffffff..............T.F",
	"F.....ffffff.ffffff...............TF",
	"F......ffff......................O.F",
	"F.WWW..ffff..fffffff...............F",
	"F.WWW..ffff..fffffff.............TTF",
	"F.WWW..ffff..fffffff...............F",
	"F..................................F",
	"F..................................F",
	"F.......M..........................F",
	"F......................K...........F",
	"F..................................F",
	"F................B........K........F",
	"F..................................F",
	"F..................................F",
	"F..........................K.......F",
	"F..................................F",
	"F..................................F",
	"F...............R........K.........F",
	"F..................................F",
	"F.......................pppWWWWW...F",
	"F..........................WWWWW...F",
	"F..........................WWWWW...F",
	"F..........................WWWWW...F",
	"FFFFFFFFFFFFFFFFFGGFFFFFFFFFFFFFFFFF",
]

const BUILDINGS: Array[Dictionary] = [
	{"id": "mayor_house", "kind": "mayor_house", "top_left": Vector2i(8, 16), "size": Vector2i(4, 3)},
	{"id": "store", "kind": "store", "top_left": Vector2i(16, 25), "size": Vector2i(3, 2)},
	{"id": "bulletin_board", "kind": "bulletin_board", "top_left": Vector2i(17, 19), "size": Vector2i(1, 1)},
	{"id": "shack_1", "kind": "shack", "top_left": Vector2i(23, 17), "size": Vector2i(2, 2)},
	{"id": "shack_2", "kind": "shack", "top_left": Vector2i(26, 19), "size": Vector2i(2, 2)},
	{"id": "shack_3", "kind": "shack", "top_left": Vector2i(27, 22), "size": Vector2i(2, 2)},
	{"id": "shack_4", "kind": "shack", "top_left": Vector2i(25, 25), "size": Vector2i(2, 2)},
	{"id": "farmhouse", "kind": "farmhouse", "top_left": Vector2i(16, 2), "size": Vector2i(3, 2)},
	{"id": "chest", "kind": "chest", "top_left": Vector2i(16, 4), "size": Vector2i(1, 1)},
]


static func size() -> Vector2i:
	return LayoutCommon.size(ROWS)


static func cell(x: int, y: int) -> String:
	return LayoutCommon.cell(ROWS, x, y)


static func is_soil(x: int, y: int) -> bool:
	return LayoutCommon.is_soil(ROWS, x, y)


static func is_tree(x: int, y: int) -> bool:
	return LayoutCommon.is_tree(ROWS, x, y)


static func is_ore(x: int, y: int) -> bool:
	return LayoutCommon.is_ore(ROWS, x, y)


static func is_solid(x: int, y: int) -> bool:
	return LayoutCommon.is_solid(ROWS, BUILDINGS, x, y)


static func is_tillable(x: int, y: int) -> bool:
	return LayoutCommon.is_tillable(ROWS, BUILDINGS, x, y)


static func spawn_cell() -> Vector2i:
	return LayoutCommon.spawn_cell(ROWS)


static func resource_node_cells() -> Array[Dictionary]:
	return LayoutCommon.resource_node_cells(ROWS)


static func buildings() -> Array[Dictionary]:
	return BUILDINGS


static func building_at(x: int, y: int) -> Dictionary:
	return LayoutCommon.building_at(BUILDINGS, x, y)


static func water_cells() -> Array[Vector2i]:
	return LayoutCommon.water_cells(ROWS)


static func fence_cells() -> Array[Vector2i]:
	return LayoutCommon.fence_cells(ROWS)


static func dock_cells() -> Array[Vector2i]:
	return LayoutCommon.dock_cells(ROWS)


static func gate_cells() -> Array[Vector2i]:
	return LayoutCommon.gate_cells(ROWS)


static func farm_gap_cells() -> Array[Vector2i]:
	return LayoutCommon.farm_gap_cells(ROWS)


static func map_rect() -> Rect2:
	return LayoutCommon.map_rect(ROWS, CELL_SIZE)


static func cell_center(cell_coords: Vector2i) -> Vector2:
	return LayoutCommon.cell_center(cell_coords, CELL_SIZE)
