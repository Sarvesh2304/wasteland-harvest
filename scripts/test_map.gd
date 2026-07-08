extends Node2D
## Builds the Phase 2 test map at load by painting TileMapLayers from the pure layout data in
## scripts/test_map_layout.gd, using the Wang-corner lookup in scripts/wang_tileset.gd.
##
## Layers (all share tilemaps/wasteland_tileset.tres):
##  - Ground: grass/soil dual-grid. Each visual tile samples the terrain of the four layout
##    cells meeting at its corners and picks the matching Wang transition tile, so farmland
##    blends naturally into the surrounding meadow. The layer sits offset (-8, -8) in the
##    scene so visual tiles straddle logical cell corners (standard dual-grid trick).
##  - Decor: walkable plank floors ('p'), no collision.
##  - Obstacles: solid rubble ('#'). These atlas tiles carry physics polygons on the tileset's
##    physics layer 0 (collision layer 1 = "world"), which is what the player collides with.
##
## Phase 3 adds a runtime "tilled" overlay (`_tilled`) on top of the static layout: hoeing a
## grass cell flips that cell's soil bit here rather than mutating TestMapLayout's ASCII data
## (which stays a fixed source-of-truth for the map's authored terrain). is_soil_at() is the
## combined query every ground-painting call uses. See scripts/farm_grid.gd's class doc for the
## full reasoning on why tilling targets logical cells while the dual-grid handles corners.

const TestMapLayout := preload("res://scripts/test_map_layout.gd")
const WangTileset := preload("res://scripts/wang_tileset.gd")
const FarmGrid := preload("res://scripts/farm_grid.gd")
const CELL_SIZE := TestMapLayout.CELL_SIZE

## Atlas source ids inside tilemaps/wasteland_tileset.tres.
const SOURCE_SETTLEMENT := 0
const SOURCE_RUINS := 1

@onready var ground: TileMapLayer = $Ground
@onready var decor: TileMapLayer = $Decor
@onready var obstacles: TileMapLayer = $Obstacles

## Runtime-tilled cells (Phase 3), keyed by logical cell coord. Absence = not tilled by the
## player; TestMapLayout's static 'f' cells are tilled from map load regardless of this overlay.
var _tilled: Dictionary = {}


func _ready() -> void:
	build()


func build() -> void:
	ground.clear()
	decor.clear()
	obstacles.clear()
	var size := TestMapLayout.size()
	# Dual-grid ground: one more visual tile than logical cells on each axis.
	for y in size.y + 1:
		for x in size.x + 1:
			_paint_ground_tile(Vector2i(x, y))
	# Decor + obstacles are direct per-cell placements.
	for y in size.y:
		for x in size.x:
			match TestMapLayout.cell(x, y):
				"p":
					decor.set_cell(Vector2i(x, y), SOURCE_RUINS, WangTileset.ALL_UPPER)
				"#":
					obstacles.set_cell(Vector2i(x, y), SOURCE_RUINS, WangTileset.ALL_LOWER)


## Combined soil query: static farmland from the layout OR a runtime-tilled cell.
func is_soil_at(x: int, y: int) -> bool:
	return TestMapLayout.is_soil(x, y) or _tilled.get(Vector2i(x, y), false)


func is_tilled_at(cell: Vector2i) -> bool:
	return _tilled.get(cell, false)


## Till one logical cell (a hoe's effect): flips it into the soil overlay and repaints exactly
## the (up to four) visual dual-grid tiles whose corners touch it. Returns false if the cell
## isn't tillable terrain or is already tilled — callers (scripts/farm.gd) check first via
## FarmGrid.is_tillable_terrain, this is the belt-and-suspenders guard.
func till_cell(cell: Vector2i) -> bool:
	if _tilled.get(cell, false):
		return false
	if not FarmGrid.is_tillable_terrain(TestMapLayout.cell(cell.x, cell.y)):
		return false
	_tilled[cell] = true
	_repaint_ground_around(cell)
	return true


## Repaints the four visual tiles whose corners sample this logical cell (see build()'s loop:
## visual tile (vx, vy) samples logical cells (vx-1,vy-1)..(vx,vy)), i.e. visual tiles
## cell, cell+(1,0), cell+(0,1), cell+(1,1).
func _repaint_ground_around(cell: Vector2i) -> void:
	for offset in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		_paint_ground_tile(cell + offset)


func _paint_ground_tile(visual_tile: Vector2i) -> void:
	var atlas := WangTileset.atlas_for_corners(
		is_soil_at(visual_tile.x - 1, visual_tile.y - 1),
		is_soil_at(visual_tile.x, visual_tile.y - 1),
		is_soil_at(visual_tile.x - 1, visual_tile.y),
		is_soil_at(visual_tile.x, visual_tile.y)
	)
	ground.set_cell(visual_tile, SOURCE_SETTLEMENT, atlas)


## World position -> logical cell coordinate (floor division by the 16px tile size).
func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / CELL_SIZE), floori(world_pos.y / CELL_SIZE))


func cell_to_world_center(cell: Vector2i) -> Vector2:
	return TestMapLayout.cell_center(cell)


func terrain_at(cell: Vector2i) -> String:
	return TestMapLayout.cell(cell.x, cell.y)


## Map bounds in world pixels — main.gd hands this to the camera for clamping.
func get_map_rect() -> Rect2:
	return TestMapLayout.map_rect()


## Where the player spawns (the '@' cell's center).
func get_spawn_position() -> Vector2:
	return TestMapLayout.cell_center(TestMapLayout.spawn_cell())
