extends RefCounted
## Town zone layout, RIVERSIDE variant — extracted from the old combined riverside map's town
## core (rows 16-31 of the pre-split riverside ROWS) as part of the Farm/Path/Town/Ranch zone
## split. See town_layout_standard.gd for the full frame/gate documentation (old rows 16-31 →
## local rows 1-16, +1 prepend for the new north wall, all coordinates shifted by (0, -15));
## this file is the literal-duplication sibling, per the farm layout files' own convention. That
## file also documents the 2026-08-09 ranch relocation this variant mirrors: the south-wall gate
## at x17-18 row 16 is resealed to plain fence and the "ranch" zone exit is gone, leaving the west
## gate as the Town's only connection.
##
## Riverside differences (MAPS.md §1 "the river IS the western wall"):
##   - The west column is river 'W' the whole way down, not fence — including the new north wall
##     row (its x0 stays 'W' so the river reads as flowing through the zone edge).
##   - The west gate to the Path zone (x0, rows 4-5) is therefore a break in the RIVER, not a
##     fence: the Path zone's riverside variant ends in a plank bridge over this same river
##     (path_layout_riverside.gd), and the two 'p' landing cells at x1 here are where that
##     bridge meets the town bank. A gap in a river is a known cosmetic rough edge at 16px —
##     flagged for the screenshot pass rather than silently ignored.
##   - The water feature is the bank dock at row 7 ("Wppp"), not the standard variant's
##     south-east pond.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size (shared across all zones)

const ROWS: Array[String] = [
	"WFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
	"W.......M..........................F",
	"W......................K...........F",
	"W..................................F",
	"Gp:::::::::::;;;;B;;;;.:..K........F",
	"Gp:::::::::::;;;;;;;;;.:...........F",
	"W..:.........;;;;;;;;;:::::::......F",
	"Wppp.........;;;;;;;;;..:..K.......F",
	"W............;;;;;;;;;..:..........F",
	"W...............:::.....:..........F",
	"W...............R........K.........F",
	"W..................................F",
	"W..................................F",
	"W..................................F",
	"W..................................F",
	"W..................................F",
	"WFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
]

## Old combined-map coordinates minus (0, 15) — identical to the standard variant's list (the
## town-core template is shared; only terrain differs).
const BUILDINGS: Array[Dictionary] = [
	{"id": "mayor_house", "kind": "mayor_house", "top_left": Vector2i(8, 1), "size": Vector2i(4, 3)},
	{"id": "store", "kind": "store", "top_left": Vector2i(16, 10), "size": Vector2i(3, 2)},
	{"id": "bulletin_board", "kind": "bulletin_board", "top_left": Vector2i(17, 4), "size": Vector2i(1, 1)},
	{"id": "shack_1", "kind": "shack", "top_left": Vector2i(23, 2), "size": Vector2i(2, 2)},
	{"id": "shack_2", "kind": "shack", "top_left": Vector2i(26, 4), "size": Vector2i(2, 2)},
	{"id": "shack_3", "kind": "shack", "top_left": Vector2i(27, 7), "size": Vector2i(2, 2)},
	{"id": "shack_4", "kind": "shack", "top_left": Vector2i(25, 10), "size": Vector2i(2, 2)},
	# Milestone B (2026-10-08): the one-room clinic the player was born in, roof caved in; the
	# "clinic" Town Works project rebuilds it (structures.set_building_art -> town_clinic).
	{"id": "clinic", "kind": "town_clinic_ruined", "top_left": Vector2i(2, 12), "size": Vector2i(4, 3)},
]


## Same single gate / target as the standard variant (see town_layout_standard.gd's doc).
static func zone_exits() -> Array[Dictionary]:
	return [
		{"gate_cells": [Vector2i(0, 4), Vector2i(0, 5)], "target_zone": "path",
			"entry_cell": Vector2i(22, 4)},
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


## 2026-10-07 town dressing: the shared plaza/street props (layout_common.gd's TOWN_DECOR).
static func decor_props() -> Array[Dictionary]:
	return LayoutCommon.TOWN_DECOR


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
