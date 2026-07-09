extends RefCounted
## Shared pure-logic helpers for the Phase 4 starting-settlement layouts (Open Plains, Forest
## Edge, Riverside — scripts/map_layouts/*_layout.gd). Phase 2's single TestMapLayout has grown
## into three named layouts sharing one ASCII-grid + Wang-painting pipeline (per ROADMAP.md
## Phase 4: "generalize... to support three named layouts rather than inventing a new map
## system"); this file is the deduplicated logic all three wrap, so each concrete layout file is
## just its ROWS/BUILDINGS data plus thin static delegating wrappers (see e.g.
## open_plains_layout.gd) — same "pure functions operating on plain data" convention as
## farm_grid.gd/wang_tileset.gd, just parameterized over which map's data to read.
##
## ## Legend (extends Phase 2/3's '.'/'f'/'p'/'#'/'@'/'T'/'O' with Phase 4 additions)
##   'F'  perimeter fence (solid) — painted as a worn-wood-tinted rubble tile, see test_map.gd
##   'W'  water (solid) — painted as a blue-tinted rubble tile; river, pond, or creek per start
##   'G'  town's one main gate (walkable landmark; a break in the south fence line)
##   'g'  farm's small perimeter fence gap (walkable landmark; a break in the north fence line,
##        "closed later" per ROADMAP.md — no functional gameplay meaning yet, layout marker only)
##   'H'/'C'/'D'/'M'/'R'/'K'/'B'/'S'  building top-left markers (farmhouse/chest/bed/mayor's
##        house/store/settler shack/bulletin board/shipping box) — see class doc below on
##        multi-cell footprints. 'D' (the farmhouse beD, Phase 4 Stage 3) is 1x1 like the chest;
##        'B' was taken. 'S' (the Shipping box, Phase 5 Stage 3) is 1x1 too, and this time the
##        kind's own first letter was actually free.
##
## ## Multi-cell buildings
##
## A building occupies a rectangular footprint (top_left + size, both in cells) but the ASCII
## grid only carries its kind-letter at the top-left cell — every other footprint cell reads as
## plain grass ('.') in ROWS, exactly the way Phase 3's dual-grid tilling treats "cells are
## gameplay truth, corners/adjacent-cells are a rendering/placement detail" (see farm_grid.gd's
## class doc). scripts/structures.gd is the thing that actually turns a building's top_left+size
## into one solid StaticBody2D + one flat-color visual covering the whole footprint (reusing
## farm.gd's _spawn_resource_prop pattern, generalized to arbitrary rect size) — the ASCII marker
## exists only for human-readability of the source map and for is_solid()/is_tillable() to
## correctly treat every footprint cell (not just the marker) as blocked/untillable, matching the
## real collision a player will hit at runtime.

const FarmGrid := preload("res://scripts/farm_grid.gd")

const SOLID_TERRAIN_CHARS := ["F", "W", "#"]

## Phase 5 Stage 1: the three town-core NPCs (ROADMAP.md "First NPCs"), shared verbatim by all
## 3 starting layouts — the town core is one spatial template (MAPS.md §2), and since every
## town-core building coordinate is already identical across the 3 files, the NPC roster lives
## here once rather than being triplicated (a layout with a divergent town could stop delegating
## its npcs() here, the same way Riverside already diverges on farmhouse coordinates).
## Each entry: {id (dialogue key in data/dialogue.json), home (cell the NPC spawns at and
## wanders around), wander_radius (Chebyshev cell radius of the wander zone — see npc_grid.gd)}.
##   - mayor_harlan (10, 19): on the plaza directly south of his fortified house's door
##     (footprint x8-11, y16-18) — "half town hall, half keep", he holds court out front.
##   - marta (17, 24): directly north of her store (footprint x16-18, y25-26), out front with
##     the crates — MAPS.md's "economic heart" faces the plaza.
##   - scout_kael (18, 28): just inside the town's one main gate (the 'G' cells at x17-18,
##     y31 — confirmed against ForestEdgeLayout.gate_cells()). MAPS.md §2 puts expedition
##     departures and bandit-scout events at the gate, so the scout who watches the road to the
##     ruined city naturally posts up there — he's the last face you see walking out toward the
##     ruins and the first one coming home.
## wander_radius is deliberately 1 (a tight 3x3 zone), not larger: with homes spaced ~5 cells
## apart in y (19, 24, 28), a radius of 2 would let neighbouring NPCs' wander zones overlap by a
## cell (verified this the hard way — tools/runtime_smoke.gd's dialogue stages occasionally
## picked up the WRONG NPC at a shared boundary cell when this was 2, an intermittent failure
## that traced back to here); radius 1 keeps every zone strictly disjoint while still reading as
## "stands near home and ambles a little."
const TOWN_NPCS: Array[Dictionary] = [
	{"id": "mayor_harlan", "home": Vector2i(10, 19), "wander_radius": 1},
	{"id": "marta", "home": Vector2i(17, 24), "wander_radius": 1},
	{"id": "scout_kael", "home": Vector2i(18, 28), "wander_radius": 1},
]


static func size(rows: Array[String]) -> Vector2i:
	return Vector2i(rows[0].length(), rows.size())


## Terrain character at a cell; out-of-bounds reads as grass so the dual-grid ground painter can
## sample one cell beyond every edge without special cases (Phase 2 convention, unchanged).
static func cell(rows: Array[String], x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return "."
	return rows[y][x]


static func is_soil(rows: Array[String], x: int, y: int) -> bool:
	return cell(rows, x, y) == "f"


static func is_tree(rows: Array[String], x: int, y: int) -> bool:
	return cell(rows, x, y) == "T"


static func is_ore(rows: Array[String], x: int, y: int) -> bool:
	return cell(rows, x, y) == "O"


## True if (x, y) falls inside any building's rectangular footprint (not just its marker cell) —
## see class doc above on why this must be checked separately from the raw ASCII char.
static func is_inside_any_building(buildings: Array[Dictionary], x: int, y: int) -> bool:
	for b in buildings:
		var top_left: Vector2i = b["top_left"]
		var footprint_size: Vector2i = b["size"]
		if x >= top_left.x and x < top_left.x + footprint_size.x \
				and y >= top_left.y and y < top_left.y + footprint_size.y:
			return true
	return false


## Which building (if any) occupies (x, y); {} if none. Used by structures.gd/player.gd to
## resolve chest interaction and by tests to sanity-check placements.
static func building_at(buildings: Array[Dictionary], x: int, y: int) -> Dictionary:
	for b in buildings:
		var top_left: Vector2i = b["top_left"]
		var footprint_size: Vector2i = b["size"]
		if x >= top_left.x and x < top_left.x + footprint_size.x \
				and y >= top_left.y and y < top_left.y + footprint_size.y:
			return b
	return {}


## Physically blocked: fence/water/rubble terrain, or inside any building's footprint. Used for
## the player's/farm's tilling and (indirectly, via structures.gd's real collision bodies)
## movement-blocking checks.
static func is_solid(rows: Array[String], buildings: Array[Dictionary], x: int, y: int) -> bool:
	if cell(rows, x, y) in SOLID_TERRAIN_CHARS:
		return true
	return is_inside_any_building(buildings, x, y)


## True where a hoe may till: open grass/spawn cell, not already-tilled farmland, not a
## building/fence/water/dock/decor cell. Delegates the base terrain-char rule to FarmGrid (single
## source of truth, per farm_grid.gd's own header) and additionally excludes building footprints,
## which the base rule alone can't see (see class doc above).
static func is_tillable(rows: Array[String], buildings: Array[Dictionary], x: int, y: int) -> bool:
	if is_inside_any_building(buildings, x, y):
		return false
	return FarmGrid.is_tillable_terrain(cell(rows, x, y))


static func spawn_cell(rows: Array[String]) -> Vector2i:
	for y in rows.size():
		var x := rows[y].find("@")
		if x != -1:
			return Vector2i(x, y)
	return size(rows) / 2  # fallback: map center


## All 'T'/'O' resource-node cells, as {cell: Vector2i, kind: "tree"|"ore"} — same shape as
## Phase 2/3's TestMapLayout.resource_node_cells(), scanned once by scripts/farm.gd at map build.
static func resource_node_cells(rows: Array[String]) -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for y in rows.size():
		for x in rows[y].length():
			var c := rows[y][x]
			if c == "T":
				nodes.append({"cell": Vector2i(x, y), "kind": "tree"})
			elif c == "O":
				nodes.append({"cell": Vector2i(x, y), "kind": "ore"})
	return nodes


## All 'W' water cells — painted solid+blue-tinted by test_map.gd's Water TileMapLayer.
static func water_cells(rows: Array[String]) -> Array[Vector2i]:
	return _cells_with_char(rows, "W")


## All 'F' fence cells — painted solid+wood-tinted by test_map.gd's Fence TileMapLayer.
static func fence_cells(rows: Array[String]) -> Array[Vector2i]:
	return _cells_with_char(rows, "F")


## All 'p' plank cells — dock boards, painted via the existing Decor layer (walkable, no
## collision), exactly like Phase 2's ruined-shack floor use of the same character/tile.
static func dock_cells(rows: Array[String]) -> Array[Vector2i]:
	return _cells_with_char(rows, "p")


## The town's one main gate — a (usually 2-cell-wide) walkable break in the fence line.
static func gate_cells(rows: Array[String]) -> Array[Vector2i]:
	return _cells_with_char(rows, "G")


## The farm's small perimeter fence gap (ROADMAP Phase 4: "closed later") — walkable, layout
## marker only, no functional logic yet.
static func farm_gap_cells(rows: Array[String]) -> Array[Vector2i]:
	return _cells_with_char(rows, "g")


static func _cells_with_char(rows: Array[String], target: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == target:
				cells.append(Vector2i(x, y))
	return cells


## Map bounds in world pixels — the rect the camera is clamped to.
static func map_rect(rows: Array[String], cell_size: int) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size(rows)) * float(cell_size))


## World-space center of a cell (player spawn position etc.).
static func cell_center(cell_coords: Vector2i, cell_size: int) -> Vector2:
	return (Vector2(cell_coords) + Vector2(0.5, 0.5)) * float(cell_size)
