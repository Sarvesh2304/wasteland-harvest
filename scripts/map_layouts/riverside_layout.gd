extends RefCounted
## Riverside starting layout (ROADMAP.md Phase 4 / MAPS.md §1) — the "water access" lean.
##
## The river runs the full western edge of the map — both farmland and town rows — replacing
## the west perimeter fence entirely ("the river IS the western wall", MAPS.md §1). Farmland is
## a narrow irrigated ribbon along the bank; the farmhouse sits just north of town "on a low
## bluff above the floodline" per MAPS.md, so its position (and the chest/spawn near it) differs
## from the other two starts' shared coordinates. Fewest resource nodes of the three (stone/scrap
## are scarcest here). Town's dock juts directly from the plaza-adjacent bank into the river
## rather than a separate town-edge pool.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size (shared across all 3 starts)

const ROWS: Array[String] = [
	"WFFFFFFFFFFFFFFFFgFFFFFFFFFFFFFFFFFF",
	"W..................................F",
	"W.fffffff..........................F",
	"W.fffffffH.........................F",
	"W.fffffff..........................F",
	"W.fffffffC.D.......................F",
	"W.fffffff.@........................F",
	"W.fffffff..........................F",
	"W.fffffff.....................T....F",
	"W.fffffff..........................F",
	"W.fffffff..........................F",
	"W.fffffff......................O...F",
	"W.fffffff..........................F",
	"W.fffffff..........................F",
	"W.fffffff..........................F",
	"W..................................F",
	"W.......M..........................F",
	"W......................K...........F",
	"W..................................F",
	"W................B........K........F",
	"W..................................F",
	"W..................................F",
	"Wppp.......................K.......F",
	"W..................................F",
	"W..................................F",
	"W...............R........K.........F",
	"W..................................F",
	"W..................................F",
	"W..................................F",
	"W..................................F",
	"W..................................F",
	"WFFFFFFFFFFFFFFFFGGFFFFFFFFFFFFFFFFF",
]

const BUILDINGS: Array[Dictionary] = [
	{"id": "mayor_house", "kind": "mayor_house", "top_left": Vector2i(8, 16), "size": Vector2i(4, 3)},
	{"id": "store", "kind": "store", "top_left": Vector2i(16, 25), "size": Vector2i(3, 2)},
	{"id": "bulletin_board", "kind": "bulletin_board", "top_left": Vector2i(17, 19), "size": Vector2i(1, 1)},
	{"id": "shack_1", "kind": "shack", "top_left": Vector2i(23, 17), "size": Vector2i(2, 2)},
	{"id": "shack_2", "kind": "shack", "top_left": Vector2i(26, 19), "size": Vector2i(2, 2)},
	{"id": "shack_3", "kind": "shack", "top_left": Vector2i(27, 22), "size": Vector2i(2, 2)},
	{"id": "shack_4", "kind": "shack", "top_left": Vector2i(25, 25), "size": Vector2i(2, 2)},
	{"id": "farmhouse", "kind": "farmhouse", "top_left": Vector2i(9, 3), "size": Vector2i(3, 2)},
	{"id": "chest", "kind": "chest", "top_left": Vector2i(9, 5), "size": Vector2i(1, 1)},
	# Phase 4 Stage 3: the bed sits at the farmhouse's south-east corner, mirroring the chest at
	# its south-west — interacting with it sleeps (auto-save + skip to morning), see structures.gd.
	{"id": "bed", "kind": "bed", "top_left": Vector2i(11, 5), "size": Vector2i(1, 1)},
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
