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

const TestMapLayout := preload("res://scripts/test_map_layout.gd")
const WangTileset := preload("res://scripts/wang_tileset.gd")

## Atlas source ids inside tilemaps/wasteland_tileset.tres.
const SOURCE_SETTLEMENT := 0
const SOURCE_RUINS := 1

@onready var ground: TileMapLayer = $Ground
@onready var decor: TileMapLayer = $Decor
@onready var obstacles: TileMapLayer = $Obstacles


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
			var atlas := WangTileset.atlas_for_corners(
				TestMapLayout.is_soil(x - 1, y - 1),
				TestMapLayout.is_soil(x, y - 1),
				TestMapLayout.is_soil(x - 1, y),
				TestMapLayout.is_soil(x, y)
			)
			ground.set_cell(Vector2i(x, y), SOURCE_SETTLEMENT, atlas)
	# Decor + obstacles are direct per-cell placements.
	for y in size.y:
		for x in size.x:
			match TestMapLayout.cell(x, y):
				"p":
					decor.set_cell(Vector2i(x, y), SOURCE_RUINS, WangTileset.ALL_UPPER)
				"#":
					obstacles.set_cell(Vector2i(x, y), SOURCE_RUINS, WangTileset.ALL_LOWER)


## Map bounds in world pixels — main.gd hands this to the camera for clamping.
func get_map_rect() -> Rect2:
	return TestMapLayout.map_rect()


## Where the player spawns (the '@' cell's center).
func get_spawn_position() -> Vector2:
	return TestMapLayout.cell_center(TestMapLayout.spawn_cell())
