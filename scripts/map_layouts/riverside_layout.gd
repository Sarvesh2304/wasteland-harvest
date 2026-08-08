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
## riverside variants — see settlement_db.gd's layout_for_zone()).
##
## ## 72x32 (pre-Stage-4 farm expansion, 2026-08-09)
##
## Was 36x16 — see open_plains_layout.gd's class doc for the shared frame notes. Re-authored,
## not tiled: the homestead keeps its authored cells (farmhouse x9-11/y3-4, the chest/box/bed
## service row on y5, the '@' spawn at (10,6)) and the rest states this start's identity at the
## size it actually needs:
##   - the RIVER is now three columns wide (x0-2) for the whole height, widening to x0-4 through
##     a slow bend at y18-27 — MAPS.md §1's "slow, wide bend", which one column could only imply;
##   - the IRRIGATED RIBBON hugs it: silt rows on the bank beside the bluff (x3-8), a bluff-top
##     plot east of the house, and wider lower terraces (x5-14) where the bank flattens south of
##     y16, plus one outer terrace at x16-22. 273 pre-tilled cells, up from 91 — more than Forest
##     Edge, far less than Open Plains, and still unmistakably a ribbon;
##   - an OXBOW flood pool at x26-30/y25-28, left behind when the bend moved;
##   - everything east of x~23 stays open dry ground with only 10 scattered nodes on it. That
##     emptiness is deliberate and is the trade-off MAPS.md §1 names outright: "farther east the
##     ground rises and dries into gravel and scrub — expansion that way costs effort."
##
## The east/south perimeter gates sit at the same cells as the other two farm variants; the
## west "wall" stays river, so tests/test_map_layouts.gd's west-column check still holds.

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size (shared across all 3 starts)

const ROWS: Array[String] = [
	"WWWFFFFFFFFFFFFFFgFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
	"WWW....................................................................F",
	"WWW.ffff...............................................................F",
	"WWWffffffH.......................T.....................................F",
	"WWWffffff..............................................................F",
	"WWWffffffCSD.............T.............................................F",
	"WWWffffff.@............................................................F",
	"WWWffffff.....fffff........................T...........................F",
	"WWWffffff.....ffffff...................................................F",
	"WWWffffff.....ffffff...............O......................T............F",
	"WWWffffff.....ffffff...................................................F",
	"WWWffffff......fffff...................................................F",
	"WWWffffff..............................................................F",
	"WWWffffff..............................................................F",
	"WWW.fffff..............................................................F",
	"WWW....................................................................G",
	# South of the bluff the bank flattens out and the terraces widen — the map's real
	# farmland, still a ribbon, still hard against the water.
	"WWW...ffffffff.........................................................G",
	"WWW..ffffffffff..ffffff................................................F",
	"WWWW.ffffffffff.fffffff................................................F",
	"WWWW.ffffffffff.fffffff..........................O.....................F",
	"WWWW.ffffffffff.fffffff......................................O.........F",
	"WWWWWffffffffff.fffffff................................................F",
	"WWWWWffffffffff.fffffff................................................F",
	"WWWWWffffffffff.fffffff.........................................T......F",
	"WWWWWffffffffff.ffffff.................................................F",
	# The oxbow: a flood pool the river left behind when the bend moved (MAPS.md §1's
	# 'silt rows flood in heavy Spring Rains storms').
	"WWWWWffffffffff............WWWW........................................F",
	"WWWW.ffffffffff...........WWWWW.....................T..................F",
	"WWWW..ffffffff............WWWWW........................................F",
	"WWW.......................WWWW.........................................F",
	"WWW............................................T.......................F",
	"WWW....................................................................F",
	"WWWFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFGGFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
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
## east-wall gate-break to the Path corridor, landing just inside Path's own west gate. The
## south gate ((35,31)/(36,31)) carries no entry yet — this variant pairs with its own
## ranch_layout_riverside.gd, so its column choice is independent, but matching the other two
## farms keeps one set of coordinates to reason about. Wiring it is the next stage.
static func zone_exits() -> Array[Dictionary]:
	return [
		{"gate_cells": [Vector2i(71, 15), Vector2i(71, 16)], "target_zone": "path",
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
