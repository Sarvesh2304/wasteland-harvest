extends RefCounted
## Town zone layout, STANDARD variant (Open Plains + Forest Edge starts) — extracted from the
## old combined maps' town core (rows 16-31 of the pre-split open_plains/forest_edge ROWS, which
## were already identical between those two starts; MAPS.md §2's shared town template) as part
## of the Farm/Path/Town/Ranch zone split.
##
## Coordinate frame: the old combined rows 16-31 map to LOCAL rows 1-16 — a +1 prepend, NOT the
## zero-shift the planning doc hoped for. Re-verified at implementation time (as the plan itself
## required): the old combined map had NO wall between farm row 15 and town row 16 (the farm
## simply continued into the town), so a split Town zone would have had an open north edge into
## the void. Local row 0 is therefore a brand-new solid north perimeter wall; every old town
## coordinate shifts by (0, -15).
##
## Gates ('G'), both zone exits — see zone_exits():
##   - WEST wall (x0, rows 4-5): new gate-break to the Path zone (the Farm↔Town corridor).
##     Rows chosen where the full row is verified clear of buildings west of the plaza.
##   - SOUTH wall (x17-18, row 16): the pre-existing town main gate, now the Ranch zone exit —
##     unchanged cells from the pre-split map's row 31.
##
## The riverside variant (town_layout_riverside.gd) differs only in its west column (river 'W'
## instead of fence 'F', with a plank landing at the west gate) and its water feature (bank dock
## instead of the south-east pond) — literal duplication with this cross-reference comment,
## matching the farm layout files' own convention.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size (shared across all zones)

const ROWS: Array[String] = [
	"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
	"F.......M..........................F",
	"F......................K...........F",
	"F..................................F",
	"G................B........K........F",
	"G..................................F",
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

## Old combined-map coordinates minus (0, 15) — see the class doc's frame note.
const BUILDINGS: Array[Dictionary] = [
	{"id": "mayor_house", "kind": "mayor_house", "top_left": Vector2i(8, 1), "size": Vector2i(4, 3)},
	{"id": "store", "kind": "store", "top_left": Vector2i(16, 10), "size": Vector2i(3, 2)},
	{"id": "bulletin_board", "kind": "bulletin_board", "top_left": Vector2i(17, 4), "size": Vector2i(1, 1)},
	{"id": "shack_1", "kind": "shack", "top_left": Vector2i(23, 2), "size": Vector2i(2, 2)},
	{"id": "shack_2", "kind": "shack", "top_left": Vector2i(26, 4), "size": Vector2i(2, 2)},
	{"id": "shack_3", "kind": "shack", "top_left": Vector2i(27, 7), "size": Vector2i(2, 2)},
	{"id": "shack_4", "kind": "shack", "top_left": Vector2i(25, 10), "size": Vector2i(2, 2)},
]


## Zone transitions (see test_map.gd's zone_exit_at / main.gd's _on_zone_exit_requested):
## stepping onto a gate cell warps the player to target_zone at entry_cell (target-zone-local).
static func zone_exits() -> Array[Dictionary]:
	return [
		{"gate_cells": [Vector2i(0, 4), Vector2i(0, 5)], "target_zone": "path",
			"entry_cell": Vector2i(22, 4)},
		{"gate_cells": [Vector2i(17, 16), Vector2i(18, 16)], "target_zone": "ranch",
			"entry_cell": Vector2i(17, 1)},
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


## The shared town-core roster (see LayoutCommon.TOWN_NPCS's doc — coordinates are already
## town-zone-local since the zone split).
static func npcs() -> Array[Dictionary]:
	return LayoutCommon.TOWN_NPCS


static func decor_props() -> Array[Dictionary]:
	return []


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
