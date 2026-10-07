extends RefCounted
## Forest Edge starting layout (ROADMAP.md Phase 4 / MAPS.md §1) — the "ruin materials" lean.
##
## A reclaimed pre-war suburb: dense treeline along the farm's north/east edges (woven with
## collapsed-wall rubble and scrap piles — salvage within walking distance from day one, this
## start's resource lean), a south-west creek, and farmland broken into several smaller irregular
## patches rather than one clean rectangle ("worst total plantable area of the three", per
## MAPS.md).
##
## FARM ZONE ONLY since the Farm/Path/Town/Ranch zone split: the town core and Ranch/Sanctuary
## rows moved to town_layout_standard.gd / ranch_layout_standard.gd (this start uses the
## standard variants — see settlement_db.gd's layout_for_zone()).
##
## ## 72x32 (pre-Stage-4 farm expansion, 2026-08-09)
##
## Was 36x16 — see open_plains_layout.gd's class doc for the shared frame notes (why it grew,
## the perimeter, and the two gates, whose cells are IDENTICAL across all three farm variants).
## Re-authored for the new size, keeping this start's character and gaining room to state it
## properly:
##   - the TREELINE now runs the full north edge as three thinning rows (y1-3) and the full east
##     edge as seven thinning columns (x64-70), woven with '#' collapsed-wall rubble and 'O'
##     salvage — 124 nodes in all, the resource lean made literal;
##   - the CREEK enters at the west bank around y10 and winds out through the south-west corner
##     to the south wall, with a plank footbridge at (6-9, 21) so the west bank stays one walk;
##   - the FARMLAND is 9 small irregular patches scattered across the clearing (222 pre-tilled
##     cells, up from 79 — still comfortably the worst plantable total of the three);
##   - rows 13-14 are the old suburb's BURIED MAIN STREET, a clear double verge running the full
##     width, with the surviving stretch of pavement ('p') exposed on row 15;
##   - a collapsed FOUNDATION with salvage still inside it stands out in the south-east scrub.
##
## Every cell tools/runtime_smoke.gd and tools/soak_test.gd anchor against (this is the farm
## they both play) was re-verified against this grid and deliberately kept clear during the
## re-author, so none of those constants had to move: the homestead cells, the build clearing at
## x23-35/y7-12 (shed, tent), the row 13-14 verge (farming plots, fence/gate walk-through), the
## (33,2) chop tree with its standing cell at (32,2), the never-chopped control tree at (20,1),
## and the creek cell at (2,11).
##
## ## Reclaim-the-farm (2026-10-07)
## The farmland described above is now OLD FIELD (',') — overgrown, tillable, fertile once hoed —
## except one 4x3 'f' starter patch beside the homestead (x15-18, y8-10), so a new game opens on a farm
## that has to be won back from the weeds (see layout_common.gd's legend).

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size (shared across all 3 starts)

const ROWS: Array[String] = [
	"FFFFFFFFFFFFFFFFFgFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
	# The treeline: three thinning rows along the whole north edge (and cols 64-70 down the
	# east), woven with collapsed-wall rubble '#' and salvage 'O' — this start's whole
	# resource lean is that all of it is inside walking distance (MAPS.md §1).
	"FTTTTTTTT..TT.......T...T..T.T.TT#..TO..TTTT.TT.TTT..TTT......T.T..TT..F",
	"FT.#..T....T.T..H....T.T..TO...#.T#.O...T.....T....TT........T.OT.T..TTF",
	"F.TT.T....T.TT........TT.T...TT..T.......T#.............T.......T#.T.T.F",
	"F...............CSD...............................................T..T.F",
	"F................@...............................................T...TTF",
	"F......,,,,,...........................,,,,,,,......T..................F",
	"F.....,,,,,,,.........................,,,,,,,,.......T............T.TT.F",
	"F.....,,,,,,,..ffff,..................,,,,,,,,.........T..........TT.TTF",
	"F.....,,,,,,,..ffff,,.................,,,,,,,...................T..TTTTF",
	"F.WW..,,,,,,,..ffff,,.........................T......................T#F",
	"F.WWW..,,,,,,..,,,,,,........................T..T.................#..TTF",
	"F.WWW...........,,,,,.......................T..T...................#T..F",
	# Rows 13-14 are the old suburb's buried main street: a clear double verge running the
	# full width, with the surviving stretch of its pavement exposed on row 15.
	"F.WWW..................................................................F",
	"F..WW..................................................................F",
	"F..WWW......ppppppppppppppppppp...ppppppppppp..........................G",
	"F...WWW................................................................G",
	"F....WW...................,,,,,.................,,,,,,................TF",
	"F....WWW.......,,,,,,.....,,,,,,................,,,,,,................#F",
	"F.....WW......,,,,,,,.....,,,,,,......,,,,,.....,,,,,..............T.T.F",
	"F.....WWW.....,,,,,,,.....,,,,,,......,,,,,,.......................O.TTF",
	"F.....pppp....,,,,,,..................,,,,,,.....................TT.TTTF",
	"F......WW.............................,,,,,,.......................T..TF",
	"F.......WW.............................,,,,,.........................T.F",
	"F.......WW..............,,,,,,........................................TF",
	# A collapsed suburban foundation out in the south-east scrub, salvage still inside it
	# — the same 'under the moss there are foundations' image as the treeline ruins.
	"F........WW.............,,,,,,....................#######..............F",
	"F........WW.....,,,,,....,,,,,....................#.O...#.........TT..TF",
	"F.........WW....,,,,,.............................#...O.#..............F",
	"F.........WW.....,,,,.............................##.####.............TF",
	"F..........WW....................................................T.....F",
	"F..........WW......................................................TT..F",
	"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFGGFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
]

## Farm-zone buildings only since the zone split — the town core and ranch buildings moved to
## town_layout_standard.gd / ranch_layout_standard.gd in their own zone-local frames.
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
## south gate ((35,31)/(36,31) — the same two columns open_plains_layout.gd uses, since both pair
## with the shared ranch_layout_standard.gd), wired to the Ranch/Sanctuary by the 2026-08-09
## relocation. Its entry cell (17,16) is ranch-local and MUST match open_plains_layout.gd's, since
## the one shared Ranch layout can carry only one return exit.
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
