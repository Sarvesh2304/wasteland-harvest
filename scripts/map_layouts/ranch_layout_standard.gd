extends RefCounted
## Ranch/Sanctuary zone layout, STANDARD variant (Open Plains + Forest Edge starts) — extracted
## from the old combined maps' southern extension (rows 32-48 of the pre-split ROWS; MAPS.md §3,
## shared verbatim by those two starts) as part of the Farm/Path/Town/Ranch zone split.
##
## Coordinate frame: the old combined rows 32-48 map to LOCAL rows 1-17 — a +1 prepend, NOT the
## zero-shift the planning doc hoped for. Re-verified at implementation time (as the plan itself
## required): the old ranch approach's north boundary was the TOWN's south wall (old row 31),
## which belongs to the Town zone after the split — so a split Ranch zone would have had an open
## north edge into the void. Local row 0 is therefore a new copy of that wall as seen from the
## ranch side, with the same 'G' gate cells at x17-18; every old ranch coordinate shifts by
## (0, -31).
##
## Gates ('G'):
##   - NORTH wall (x17-18, row 0): the zone exit back to Town (see zone_exits()) — stepping on
##     it warps to the town plaza side of the same gate.
##   - The compound's own inner gate (x17-18, row 4, old row 35) is UNCHANGED and stays a purely
##     cosmetic walkable break between the approach yard and the fenced compound — NOT a zone
##     exit, exactly as before the split.
##
## The riverside variant (ranch_layout_riverside.gd) differs only in its west column (river 'W'
## instead of fence 'F') — literal duplication with this cross-reference comment, matching the
## farm layout files' own convention.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size (shared across all zones)

const ROWS: Array[String] = [
	"FFFFFFFFFFFFFFFFFGGFFFFFFFFFFFFFFFFF",
	"F..................................F",
	"F..................................F",
	"F..................................F",
	"F....FFFFFFFFFFFFGGFFFFFFFFFFFF....F",
	"F....F........................F....F",
	"F....F......N.................F....F",
	"F....F........................F....F",
	"F....F........................F....F",
	"F....FY..................P....F....F",
	"F....F........................F....F",
	"F....F........................F....F",
	"F....F.....F.........F......F.F....F",
	"F....F.....F.........F......F.F....F",
	"F....FFFFFFF.........FFFFFFFF.F....F",
	"F....FFFFFFFFFFFFFFFFFFFFFFFFFF....F",
	"F..................................F",
	"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
]

## Old combined-map coordinates minus (0, 31) — see the class doc's frame note. Markers N/Y/P
## in ROWS; art at art/buildings/<kind>.png.
const BUILDINGS: Array[Dictionary] = [
	{"id": "ranch_house", "kind": "ranch_house", "top_left": Vector2i(12, 6), "size": Vector2i(3, 2)},
	{"id": "ranch_barn", "kind": "ranch_barn", "top_left": Vector2i(6, 9), "size": Vector2i(4, 3)},
	{"id": "ranch_coop", "kind": "ranch_coop", "top_left": Vector2i(25, 9), "size": Vector2i(2, 2)},
]


## One exit: the north gate back to Town. The compound's inner gate (row 4) is deliberately
## absent here — cosmetic/walkable only, see the class doc.
static func zone_exits() -> Array[Dictionary]:
	return [
		{"gate_cells": [Vector2i(17, 0), Vector2i(18, 0)], "target_zone": "town",
			"entry_cell": Vector2i(17, 15)},
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
