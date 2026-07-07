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
	"#..............................#",
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


static func spawn_cell() -> Vector2i:
	for y in ROWS.size():
		var x := ROWS[y].find("@")
		if x != -1:
			return Vector2i(x, y)
	return size() / 2  # fallback: map center


## Map bounds in world pixels — the rect the camera is clamped to.
static func map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size()) * float(CELL_SIZE))


## World-space center of a cell (player spawn position etc.).
static func cell_center(cell_coords: Vector2i) -> Vector2:
	return (Vector2(cell_coords) + Vector2(0.5, 0.5)) * float(CELL_SIZE)
