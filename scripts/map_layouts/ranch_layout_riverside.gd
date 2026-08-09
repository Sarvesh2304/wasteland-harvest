extends RefCounted
## Ranch/Sanctuary zone layout, RIVERSIDE variant — extracted from the old combined riverside
## map's southern extension (rows 32-48) as part of the Farm/Path/Town/Ranch zone split. See
## ranch_layout_standard.gd for the full frame/gate documentation (old rows 32-48 → local rows
## 1-17, +1 prepend for the new north wall row, all coordinates shifted by (0, -31)); this file
## is the literal-duplication sibling, per the farm layout files' own convention. That file also
## documents the 2026-08-09 relocation this variant mirrors cell-for-cell: the north gate at
## x17-18 row 0 resealed to solid fence, a new zone gate at x17-18 row 17, the single exit
## re-pointed from Town to the Farm, and the same-day second cosmetic break at x17-18 row 15
## that connects the new arrival straight into the compound instead of around it.
##
## Riverside difference (MAPS.md §1 "the river IS the western wall"): the west column is river
## 'W' the whole way down, including both perimeter wall rows — otherwise identical to standard.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size (shared across all zones)

const ROWS: Array[String] = [
	"WFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
	"W..................................F",
	"W..................................F",
	"W..................................F",
	"W....FFFFFFFFFFFFGGFFFFFFFFFFFF....F",
	"W....F........................F....F",
	"W....F......N.................F....F",
	"W....F........................F....F",
	"W....F........................F....F",
	"W....FY..................P....F....F",
	"W....F........................F....F",
	"W....F........................F....F",
	"W....F.....F.........F......F.F....F",
	"W....F.....F.........F......F.F....F",
	"W....FFFFFFF.........FFFFFFFF.F....F",
	"W....FFFFFFFFFFFFGGFFFFFFFFFFFF....F",
	"W..................................F",
	"WFFFFFFFFFFFFFFFFGGFFFFFFFFFFFFFFFFF",
]

## Identical to the standard variant's list (the compound template is shared; only the west
## column terrain differs) — old combined-map coordinates minus (0, 31).
const BUILDINGS: Array[Dictionary] = [
	{"id": "ranch_house", "kind": "ranch_house", "top_left": Vector2i(12, 6), "size": Vector2i(3, 2)},
	{"id": "ranch_barn", "kind": "ranch_barn", "top_left": Vector2i(6, 9), "size": Vector2i(4, 3)},
	{"id": "ranch_coop", "kind": "ranch_coop", "top_left": Vector2i(25, 9), "size": Vector2i(2, 2)},
]


## Same single exit as the standard variant (see ranch_layout_standard.gd's doc): the south gate
## out to the Farm. riverside_layout.gd places its own south gate at the same (35,31)/(36,31)
## cells the other two farms use, so the entry cell is identical here too.
static func zone_exits() -> Array[Dictionary]:
	return [
		{"gate_cells": [Vector2i(17, 17), Vector2i(18, 17)], "target_zone": "farm",
			"entry_cell": Vector2i(35, 30)},
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


## The ranch keeper (see LayoutCommon.RANCH_NPCS's doc — coordinates are already
## ranch-zone-local since the zone split).
static func npcs() -> Array[Dictionary]:
	return LayoutCommon.RANCH_NPCS


## Ranch/Sanctuary decorative animal props (MAPS.md §3) — static non-collidable Sprite2D
## critters spawned by scripts/props.gd (no animal-entity system yet).
static func decor_props() -> Array[Dictionary]:
	return LayoutCommon.RANCH_DECOR


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
