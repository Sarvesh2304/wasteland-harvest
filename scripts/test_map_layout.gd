extends RefCounted
## Phase 2 test-map layout as pure data (ROADMAP Phase 2: "small test map — farmland +
## surrounding area").
##
## This is the engine-proving map, NOT one of MAPS.md's three starting settlements (those are
## Phase 4 work). Kept as an ASCII grid in a plain script so the layout is diffable, easily
## edited, and headlessly testable (tests/test_map_layout.gd) — scenes/test_map.tscn's builder
## script (scripts/test_map.gd) paints TileMapLayers from this at load.
##
## Legend:
##   '.'  grass (settlement sheet, lower terrain)
##   'f'  tilled farm soil (settlement sheet, upper terrain) — blended into grass via Wang edges
##   'p'  worn plank floor (ruins sheet, upper terrain) — a ruined shack floor, walkable
##   '#'  concrete rubble (ruins sheet, lower terrain) — solid, collides (world layer)
##   '@'  player spawn (grass underneath)
##   'T'  dead tree stump (grass underneath) — axe resource node, yields wood (Phase 3)
##   'O'  scrap/ore pile (grass underneath) — pickaxe resource node, yields stone + scrap metal
##
## 'T'/'O' are deliberately minimal placeholder resource nodes (Phase 3 scope call, see
## scripts/farm.gd): flat-color props, not PixelLab art, one-time single-hit yield, no
## respawn/regrowth system — real "gathering out in the world" content is Phase 9's job.

const FarmGrid := preload("res://scripts/farm_grid.gd")

const CELL_SIZE := 16  # px, the locked Phase 1 tile size

const ROWS: Array[String] = [
	"################################",
	"#..............................#",
	"#....................####......#",
	"#.....#..............#ppp#.....#",
	"#....................#ppp#.....#",
	"#....................#ppp......#",
	"#....................##.##.....#",
	"#....ffffffff..................#",
	"#....ffffffff.......#..........#",
	"#....ffffffff..@...............#",
	"#....ffffffff..................#",
	"#....ffffffff.........##.......#",
	"#....ffffffff..................#",
	"#..............................#",
	"#...#..........###.............#",
	"#...............#.............##",
	"#..............................#",
	"#.......#...............###....#",
	"#...................T..O..T..O.#",
	"################################",
]


static func size() -> Vector2i:
	return Vector2i(ROWS[0].length(), ROWS.size())


## Terrain character at a cell; out-of-bounds reads as grass so the dual-grid ground painter
## can sample one cell beyond every edge without special cases.
static func cell(x: int, y: int) -> String:
	if y < 0 or y >= ROWS.size() or x < 0 or x >= ROWS[y].length():
		return "."
	return ROWS[y][x]


static func is_soil(x: int, y: int) -> bool:
	return cell(x, y) == "f"


static func is_solid(x: int, y: int) -> bool:
	return cell(x, y) == "#"


## Cell characters this map spawns a resource-node prop on top of (see scripts/farm.gd) —
## everywhere else in the world the ground under these cells is plain grass.
static func is_tree(x: int, y: int) -> bool:
	return cell(x, y) == "T"


static func is_ore(x: int, y: int) -> bool:
	return cell(x, y) == "O"


## True where a hoe may till: open grass and the spawn cell (grass underneath), not already-
## tilled farmland, plank floors, rubble, or resource-node cells. Delegates to FarmGrid so the
## tillability rule has exactly one definition (see farm_grid.gd's class doc for the full
## dual-grid semantics writeup).
static func is_tillable(x: int, y: int) -> bool:
	return FarmGrid.is_tillable_terrain(cell(x, y))


static func spawn_cell() -> Vector2i:
	for y in ROWS.size():
		var x := ROWS[y].find("@")
		if x != -1:
			return Vector2i(x, y)
	return size() / 2  # fallback: map center


## All 'T'/'O' resource-node cells, as {cell: Vector2i, kind: "tree"|"ore"}. Scanned once by
## scripts/farm.gd at map build time to spawn the placeholder props.
static func resource_node_cells() -> Array[Dictionary]:
	var nodes: Array[Dictionary] = []
	for y in ROWS.size():
		for x in ROWS[y].length():
			var c := ROWS[y][x]
			if c == "T":
				nodes.append({"cell": Vector2i(x, y), "kind": "tree"})
			elif c == "O":
				nodes.append({"cell": Vector2i(x, y), "kind": "ore"})
	return nodes


## Map bounds in world pixels — the rect the camera is clamped to.
static func map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size()) * float(CELL_SIZE))


## World-space center of a cell (player spawn position etc.).
static func cell_center(cell_coords: Vector2i) -> Vector2:
	return (Vector2(cell_coords) + Vector2(0.5, 0.5)) * float(CELL_SIZE)
