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
## ranch side; every old ranch coordinate shifts by (0, -31).
##
## ## Relocated south of the FARM (pre-Stage-4 ranch relocation, 2026-08-09)
##
## The compound was reached through the TOWN's south gate until now — an artifact of where the
## old combined map happened to stack its rows, not a design decision. MAPS.md §3 always placed
## the Sanctuary "south of the farm ... reached by its own short path off the farm-to-plaza
## route", and Sarvesh confirmed that intent when he played the build. So the zone's one exit
## moved from the NORTH wall to the SOUTH wall and now points at the Farm:
##   - row 0 (the old north gate at x17-18) is RESEALED to plain solid fence 'F'. Nothing else in
##     this file referenced it — RANCH_NPCS' home (17,9) and RANCH_DECOR's 5 cells are anchored to
##     the compound's own buildings, so no NPC/decor/building coordinate moved;
##   - row 17 (previously fully solid) carries the new 2-cell gate at x17-18, chosen to line up
##     with the compound's own inner gate (also x17-18, row 4) so the whole zone reads as one
##     north-south spine; row 16 is a full open row, so the cell just inside the new gate is
##     clear in both variants.
##
## A second cosmetic break was added at (17,15)/(18,15) the same day, closing a gap flagged during
## review: without it, the compound's own south wall (row 15) sat between the new arrival cell and
## the interior, forcing a ~39-cell walk around the perimeter to the row-4 inner gate instead of a
## straight walk in. Column x17 was already open the whole way from row 5 to row 14, so this break
## makes the approach yard and the fenced compound one unbroken north-south spine, matching the
## row-4 gate it lines up under. Confirmed with Sarvesh before adding it (compound re-authoring
## wasn't in the original relocation scope, so this wasn't done silently).
##
## Gates ('G'):
##   - SOUTH wall (x17-18, row 17): the zone exit to the Farm (see zone_exits()) — stepping on it
##     warps to (35,30), the open working ground just inside the Farm's own south gate at
##     (35,31)/(36,31). Those farm columns are shared by open_plains_layout.gd AND
##     forest_edge_layout.gd precisely because both pair with THIS file (see
##     tests/test_map_layouts.gd's VARIANT_ZONE_MAPS) and one exit can carry only one entry_cell.
##   - The compound's own TWO inner gates (x17-18 at both row 4 and row 15) are UNCHANGED/NEW-BUT-
##     COSMETIC walkable breaks — NOT zone exits. Row 4 predates the split; row 15 was added
##     alongside the relocation specifically to remove the detour above.
##
## The riverside variant (ranch_layout_riverside.gd) differs only in its west column (river 'W'
## instead of fence 'F') — literal duplication with this cross-reference comment, matching the
## farm layout files' own convention.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size (shared across all zones)

const ROWS: Array[String] = [
	"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
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
	"F....FFFFFFFFFFFFGGFFFFFFFFFFFF....F",
	"F..................................F",
	"FFFFFFFFFFFFFFFFFGGFFFFFFFFFFFFFFFFF",
]

## Old combined-map coordinates minus (0, 31) — see the class doc's frame note. Markers N/Y/P
## in ROWS; art at art/buildings/<kind>.png.
const BUILDINGS: Array[Dictionary] = [
	{"id": "ranch_house", "kind": "ranch_house", "top_left": Vector2i(12, 6), "size": Vector2i(3, 2)},
	{"id": "ranch_barn", "kind": "ranch_barn", "top_left": Vector2i(6, 9), "size": Vector2i(4, 3)},
	{"id": "ranch_coop", "kind": "ranch_coop", "top_left": Vector2i(25, 9), "size": Vector2i(2, 2)},
]


## One exit: the SOUTH gate out to the Farm (relocated 2026-08-09 — see the class doc). The
## entry cell (35,30) is the open working ground directly north of the Farm's own south gate at
## (35,31)/(36,31), identical in all three farm variants. The compound's inner gate (row 4) is
## deliberately absent here — cosmetic/walkable only, see the class doc.
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
