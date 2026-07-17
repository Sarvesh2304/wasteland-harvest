extends RefCounted
## Riverside starting layout (ROADMAP.md Phase 4 / MAPS.md §1) — the "water access" lean.
##
## The river runs the full western edge of the map, replacing the west perimeter fence entirely
## ("the river IS the western wall", MAPS.md §1). Farmland is a narrow irrigated ribbon along
## the bank; the farmhouse sits "on a low bluff above the floodline" per MAPS.md, so its
## position (and the chest/spawn near it) differs from the other two starts' shared
## coordinates. Fewest resource nodes of the three (stone/scrap are scarcest here).
##
## FARM ZONE ONLY since the Farm/Path/Town/Ranch zone split: the town core and Ranch/Sanctuary
## rows moved to town_layout_riverside.gd / ranch_layout_riverside.gd (this start uses the
## riverside variants — see settlement_db.gd's layout_for_zone()). Row 15 is now the farm's own
## south perimeter wall (west column stays river), and the east wall gains the 2-cell 'G'
## zone-exit gate at rows 4-5 — see open_plains_layout.gd's class doc for the full frame notes.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size (shared across all 3 starts)

const ROWS: Array[String] = [
	"WFFFFFFFFFFFFFFFFgFFFFFFFFFFFFFFFFFF",
	"W..................................F",
	"W.fffffff..........................F",
	"W.fffffffH.........................F",
	"W.fffffff..........................G",
	"W.fffffffCSD.......................G",
	"W.fffffff.@........................F",
	"W.fffffff..........................F",
	"W.fffffff.....................T....F",
	"W.fffffff..........................F",
	"W.fffffff..........................F",
	"W.fffffff......................O...F",
	"W.fffffff..........................F",
	"W.fffffff..........................F",
	"W.fffffff..........................F",
	# Since the zone split: the farm's own south perimeter wall (west column stays river — see
	# the class doc). The town core + ranch rows now live in town_layout_riverside.gd /
	# ranch_layout_riverside.gd.
	"WFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
]

## Farm-zone buildings only since the zone split — the town core and ranch buildings moved to
## town_layout_riverside.gd / ranch_layout_riverside.gd in their own zone-local frames.
const BUILDINGS: Array[Dictionary] = [
	{"id": "farmhouse", "kind": "farmhouse", "top_left": Vector2i(9, 3), "size": Vector2i(3, 2)},
	{"id": "chest", "kind": "chest", "top_left": Vector2i(9, 5), "size": Vector2i(1, 1)},
	# Phase 4 Stage 3: the bed sits at the farmhouse's south-east corner, mirroring the chest at
	# its south-west — interacting with it sleeps (auto-save + skip to morning), see structures.gd.
	{"id": "bed", "kind": "bed", "top_left": Vector2i(11, 5), "size": Vector2i(1, 1)},
	# Phase 5 Stage 3: the shipping box sits between the chest and the bed, completing the
	# farmhouse's south-face "service row" (chest 9 / box 10 / bed 11) — one step from the '@'
	# spawn cell directly below it, same relative placement as the other two starts even though
	# Riverside's farmhouse coordinates diverge. See structures.gd for the interaction.
	{"id": "shipping_box", "kind": "shipping_box", "top_left": Vector2i(10, 5), "size": Vector2i(1, 1)},
]


## Zone transition (see test_map.gd's zone_exit_at / main.gd's _on_zone_exit_requested): the
## east-wall gate-break to the new Path corridor, landing just inside Path's own west gate.
static func zone_exits() -> Array[Dictionary]:
	return [
		{"gate_cells": [Vector2i(35, 4), Vector2i(35, 5)], "target_zone": "path",
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


## No NPCs live on the farm — the town-core roster moved to the Town zone layouts and the ranch
## keeper to the Ranch zone layouts, along with their rows (see the class doc).
static func npcs() -> Array[Dictionary]:
	return []


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
