extends RefCounted
## The Path zone, RIVERSIDE variant — the Farm↔Town corridor for the Riverside start. See
## path_layout_standard.gd for the full design documentation (corridor rows, ruined road,
## sealed checkpoint, wrecked-car landmark, zone exits); this file is the literal-duplication
## sibling, per the farm layout files' own convention.
##
## Riverside difference: the river that forms Riverside's western town wall (MAPS.md §1 "the
## river IS the western wall") crosses this corridor's east end (the 'W' band at x21-22,
## flowing through the north/south zone edges), so the walk rows cross it on a plank bridge
## ('p' at x21-22, rows 4-5) that lands on the matching plank cells on the town bank
## (town_layout_riverside.gd's west gate landing). The dead road accordingly ends at the
## riverbank rather than running the full width.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size (shared across all zones)

const ROWS: Array[String] = [
	"FFFFFFFFFFFFFFFFFFFFFWWF",
	"F........F####F......WWF",
	"F..........pp........WWF",
	"F..........pp........WWF",
	"G..........pp........ppG",
	"G..........pp........ppG",
	"F.pppppppppppppppppp.WWF",
	"F.pppppppppppppppppp.WWF",
	"F....................WWF",
	"F....................WWF",
	"F....................WWF",
	"FFFFFFFFFFFFFFFFFFFFFWWF",
]

const BUILDINGS: Array[Dictionary] = []


## Same gate cells / targets as the standard variant (the east entry lands on the bridge
## planks, then the town-side landing) — see path_layout_standard.gd's doc.
static func zone_exits() -> Array[Dictionary]:
	return [
		{"gate_cells": [Vector2i(0, 4), Vector2i(0, 5)], "target_zone": "farm",
			"entry_cell": Vector2i(34, 4)},
		{"gate_cells": [Vector2i(23, 4), Vector2i(23, 5)], "target_zone": "town",
			"entry_cell": Vector2i(1, 4)},
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


static func npcs() -> Array[Dictionary]:
	return []


## Same dressing as the standard variant, with the road-crack weeds kept west of the riverbank
## (the road ends at x19 here) — see path_layout_standard.gd's decor_props() doc.
static func decor_props() -> Array[Dictionary]:
	return [
		{"kind": "wrecked_car", "cell": Vector2i(7, 6)},
		{"kind": "weed_tuft", "cell": Vector2i(3, 6)},
		{"kind": "weed_tuft", "cell": Vector2i(5, 7)},
		{"kind": "weed_tuft", "cell": Vector2i(10, 7)},
		{"kind": "weed_tuft", "cell": Vector2i(14, 6)},
		{"kind": "weed_tuft", "cell": Vector2i(17, 7)},
		{"kind": "weed_tuft", "cell": Vector2i(19, 6)},
		{"kind": "weed_tuft", "cell": Vector2i(12, 2)},
	]


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
