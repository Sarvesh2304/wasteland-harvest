extends RefCounted
## Open Plains starting layout (ROADMAP.md Phase 4 / MAPS.md §1) — the "better soil" lean.
##
## The original Phase 2/3 engine-proving test map, kept as this start's identity per Phase 4's
## explicit scope note ("Open Plains is the most similar in spirit to a generic flat test map").
## Largest contiguous farm plot of the three starts by a wide margin, few resource nodes
## (wood/stone/scrap are scarce here — everything else is bought, traded, or hauled back from
## expeditions).
##
## FARM ZONE ONLY since the Farm/Path/Town/Ranch zone split: the town core and Ranch/Sanctuary
## rows that used to continue south of the farm now live in their own zone layouts
## (town_layout_standard.gd / ranch_layout_standard.gd — this start uses the standard variants,
## see settlement_db.gd's layout_for_zone()).
##
## ## 72x32 (pre-Stage-4 farm expansion, 2026-08-09)
##
## Was 36x16. Sarvesh played the build and found the farm noticeably smaller than intended;
## the target size (roughly double per axis — 4x the area) was confirmed with him directly. The
## grid is RE-AUTHORED at the new size rather than tiled twice: the homestead keeps its authored
## cells (farmhouse x16-18/y2-3, the chest/box/bed service row on y4, the '@' spawn at (17,5) —
## every companion tool anchors off those, and none of them needed to move), and everything
## below it is recomposed for the space:
##   - one contiguous field, x8-57 / y10-25 (768 pre-tilled cells, up from 216), with chamfered
##     corners and a cart-track notch at x30-33 so it reads as a worked holding rather than a
##     bare rectangle — MAPS.md §1's "big, clean, rectangular farm plots";
##   - a wide open apron north, west, east and south of it: the sightlines-are-total identity,
##     and the working ground the two gates open onto;
##   - 12 scattered resource nodes (was 3), all out on the margins — still the sparsest wood/
##     stone/scrap of the three starts once Forest Edge's treeline is counted.
##
## ## Perimeter and gates
##
## Row 0 carries the small 'g' fence gap (x17, "closed later" — no gameplay meaning yet); row 31
## is the south perimeter wall and column 71 the east wall.
##   - EAST GATE, 'G' at (71,15)/(71,16): the zone exit to the Path corridor (see zone_exits()).
##     It moved from the old rows 4-5 to the new grid's vertical middle. path_layout_standard.gd
##     and path_layout_riverside.gd both hardcode a farm-local `entry_cell` just inside it —
##     that literal was updated by hand to (70,15) along with this move; it is NOT derived.
##   - SOUTH GATE, 'G' at (35,31)/(36,31): authored here, deliberately the SAME two columns as
##     forest_edge_layout.gd, because both farms pair with the one shared ranch_layout_standard.gd
##     (see tests/test_map_layouts.gd's VARIANT_ZONE_MAPS) and the Ranch's single return exit can
##     only carry one entry_cell. WIRED as of the 2026-08-09 ranch relocation: it is the zone exit
##     to the Ranch/Sanctuary, which used to hang off the TOWN's south gate. MAPS.md §3 always
##     described the Sanctuary as sitting "south of the farm ... reached by its own short path off
##     the farm-to-plaza route" — the old Town↔Ranch seam was an artifact of how the pre-split
##     combined map stacked its rows, not a design call, and this restores the documented intent.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size (shared across all 3 starts)

const ROWS: Array[String] = [
	"FFFFFFFFFFFFFFFFFgFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
	"F......................................................................F",
	"F...............H......................................................F",
	"F......................................................T...............F",
	"F...............CSD....................................................F",
	"F................@............................................T........F",
	"F..T...................................................................F",
	"F......................................................................F",
	"F......................................................................F",
	"F......................................................................F",
	# The field proper: one contiguous block, x8-57 / y10-25, corners chamfered and one
	# cart track notched in from the homestead — 768 pre-tilled cells, by a wide margin
	# the largest plantable area of the three starts (MAPS.md §1).
	"F...........ffffffffffffffffff....ffffffffffffffffffff.................F",
	"F...........ffffffffffffffffffffffffffffffffffffffffff.................F",
	"F.......ffffffffffffffffffffffffffffffffffffffffffffffffff.....T.......F",
	"F.......ffffffffffffffffffffffffffffffffffffffffffffffffff.............F",
	"F...O...ffffffffffffffffffffffffffffffffffffffffffffffffff.............F",
	"F.......ffffffffffffffffffffffffffffffffffffffffffffffffff.............G",
	"F.......ffffffffffffffffffffffffffffffffffffffffffffffffff.............G",
	"F.T.....ffffffffffffffffffffffffffffffffffffffffffffffffff.............F",
	"F.......ffffffffffffffffffffffffffffffffffffffffffffffffff.............F",
	"F.......ffffffffffffffffffffffffffffffffffffffffffffffffff.......O.....F",
	"F.......ffffffffffffffffffffffffffffffffffffffffffffffffff.............F",
	"F....T..ffffffffffffffffffffffffffffffffffffffffffffffffff.............F",
	"F.......ffffffffffffffffffffffffffffffffffffffffffffffffff.O...........F",
	"F.......ffffffffffffffffffffffffffffffffffffffffffffffffff.........T...F",
	"F..........ffffffffffffffffffffffffffffffffffffffffffff................F",
	"F..........ffffffffffffffffffffffffffffffffffffffffffff................F",
	# South of the field: open working ground running to the new south perimeter wall and
	# its gate-break at x35-36 (see zone_exits() — the Ranch/Sanctuary lies behind it).
	"F......................................................................F",
	"F......................................................................F",
	"F.....T................................................................F",
	"F...........................................................T..........F",
	"F......................................................................F",
	"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFGGFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
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


## Zone transitions (see test_map.gd's zone_exit_at / main.gd's _on_zone_exit_requested): the
## east-wall gate-break to the Path corridor, landing just inside Path's own west gate, and the
## south-wall gate-break to the Ranch/Sanctuary, landing at (17,16) — the perimeter yard cell
## directly north of the Ranch's own south gate at (17,17)/(18,17). Both entry cells are
## target-zone-local and hand-maintained (nothing derives them from the neighbour's geometry);
## tests/test_map_layouts.gd's bidirectional-consistency check is what keeps the two sides honest.
static func zone_exits() -> Array[Dictionary]:
	return [
		{"gate_cells": [Vector2i(71, 15), Vector2i(71, 16)], "target_zone": "path",
			"entry_cell": Vector2i(1, 4)},
		{"gate_cells": [Vector2i(35, 31), Vector2i(36, 31)], "target_zone": "ranch",
			"entry_cell": Vector2i(17, 16)},
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
