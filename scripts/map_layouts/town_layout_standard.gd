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
## Gates ('G') — one, and it is a zone exit (see zone_exits()):
##   - WEST wall (x0, rows 4-5): gate-break to the Path zone (the Farm↔Town corridor).
##     Rows chosen where the full row is verified clear of buildings west of the plaza.
##
## ## South wall resealed (pre-Stage-4 ranch relocation, 2026-08-09)
##
## Row 16 used to carry a 2-cell gate at x17-18 (the pre-split map's row 31) that was the Ranch
## zone's only connection. The Ranch moved to sit south of the FARM, where MAPS.md §3 always
## placed it, so that gate is gone and row 16 is plain solid fence again. Deliberately NO stub or
## placeholder structure went in its place: nothing is designed for Town's south side yet, and
## this project only builds a visible stub when there IS a concrete future feature behind it (the
## Path zone's sealed checkpoint is the precedent). Nothing else in the town reaches that wall —
## the closest building is the store at rows 10-11, and scout_kael's home (18,13) is three rows
## clear of it (his dialogue is about the expedition road east, not the ranch — see
## layout_common.gd's TOWN_NPCS doc).
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
	"G::::::::::::;;;;B;;;;.:..K........F",
	"G::::::::::::;;;;;;;;;.:...........F",
	"F............;;;;;;;;;:::::::......F",
	"F............;;;;;;;;;..:..K.......F",
	"F............;;;;;;;;;..:..........F",
	"F...............:::::::::..........F",
	"F...............R......:.K.........F",
	"F......................:...........F",
	"F.......................pppWWWWW...F",
	"F..........................WWWWW...F",
	"F..........................WWWWW...F",
	"F..........................WWWWW...F",
	"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
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
	# Milestone B (2026-10-08): the one-room clinic the player was born in, roof caved in; the
	# "clinic" Town Works project rebuilds it (structures.set_building_art -> town_clinic).
	{"id": "clinic", "kind": "town_clinic_ruined", "top_left": Vector2i(2, 12), "size": Vector2i(4, 3)},
]


## Zone transition (see test_map.gd's zone_exit_at / main.gd's _on_zone_exit_requested):
## stepping onto a gate cell warps the player to target_zone at entry_cell (target-zone-local).
## Since the 2026-08-09 ranch relocation the Town is a LEAF of the zone graph — the west gate to
## the Path corridor is its only connection (see the class doc's south-wall note).
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
