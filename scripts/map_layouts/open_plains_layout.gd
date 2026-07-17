extends RefCounted
## Open Plains starting layout (ROADMAP.md Phase 4 / MAPS.md §1) — the "better soil" lean.
##
## The original Phase 2/3 engine-proving test map, kept as this start's identity per Phase 4's
## explicit scope note ("Open Plains is the most similar in spirit to a generic flat test map").
## Largest contiguous farm plot of the three starts (x6-29, y6-14), fewest resource nodes
## (wood/stone/scrap are scarce here — everything else is bought, traded, or hauled back from
## expeditions).
##
## FARM ZONE ONLY since the Farm/Path/Town/Ranch zone split: the town core and Ranch/Sanctuary
## rows that used to continue south of row 15 now live in their own zone layouts
## (town_layout_standard.gd / ranch_layout_standard.gd — this start uses the standard variants,
## see settlement_db.gd's layout_for_zone()). Row 15, previously open ground continuing into
## the town rows, is now the farm's own south perimeter wall (verified empty of content in all
## 3 starts before conversion, so no farm coordinate moved). The east wall (column 35, already
## solid pre-split) gains a 2-cell 'G' gate-break at rows 4-5 — the zone exit to the new Path
## corridor (see zone_exits()); rows 4-5 verified clear of farmland/resource nodes at the
## x33-34 approach in all 3 starts.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size (shared across all 3 starts)

const ROWS: Array[String] = [
	"FFFFFFFFFFFFFFFFFgFFFFFFFFFFFFFFFFFF",
	"F..................................F",
	"F...............H..................F",
	"F..................................F",
	"F...............CSD................G",
	"F................@.................G",
	"F.....ffffffffffffffffffffffff.....F",
	"F...T.ffffffffffffffffffffffff.....F",
	"F.....ffffffffffffffffffffffff.....F",
	"F.....ffffffffffffffffffffffff.T...F",
	"F.....ffffffffffffffffffffffff.....F",
	"F.....ffffffffffffffffffffffff.....F",
	"F...O.ffffffffffffffffffffffff.....F",
	"F.....ffffffffffffffffffffffff.....F",
	"F.....ffffffffffffffffffffffff.....F",
	# Since the zone split: the farm's own south perimeter wall (was open ground continuing into
	# the town rows — see the class doc). The town core + ranch rows now live in
	# town_layout_standard.gd / ranch_layout_standard.gd.
	"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
]

## Farm-zone buildings only since the zone split — the town core (mayor's house, store, shacks,
## bulletin board) moved to town_layout_standard.gd and the ranch buildings to
## ranch_layout_standard.gd, both in their own zone-local frames.
const BUILDINGS: Array[Dictionary] = [
	{"id": "farmhouse", "kind": "farmhouse", "top_left": Vector2i(16, 2), "size": Vector2i(3, 2)},
	{"id": "chest", "kind": "chest", "top_left": Vector2i(16, 4), "size": Vector2i(1, 1)},
	# Phase 4 Stage 3: the bed sits at the farmhouse's south-east corner, mirroring the chest at
	# its south-west — interacting with it sleeps (auto-save + skip to morning), see structures.gd.
	{"id": "bed", "kind": "bed", "top_left": Vector2i(18, 4), "size": Vector2i(1, 1)},
	# Phase 5 Stage 3: the shipping box sits between the chest and the bed, completing the
	# farmhouse's south-face "service row" (chest 16 / box 17 / bed 18) — one step from the '@'
	# spawn cell directly below it, matching Stardew's bin-beside-the-farmhouse placement. Load
	# harvested crops in, sleep, and the sale's Credits arrive next morning — see structures.gd.
	{"id": "shipping_box", "kind": "shipping_box", "top_left": Vector2i(17, 4), "size": Vector2i(1, 1)},
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
