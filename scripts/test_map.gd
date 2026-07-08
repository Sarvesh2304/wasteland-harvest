extends Node2D
## Builds the active map at load by painting TileMapLayers from the pure layout data in
## scripts/map_layouts/*.gd (Phase 2's single TestMapLayout generalized in Phase 4 to 3 named
## layouts — see scripts/settlement_db.gd), using the Wang-corner lookup in scripts/wang_tileset.gd.
##
## Layers (all share tilemaps/wasteland_tileset.tres):
##  - Ground: grass/soil dual-grid. Each visual tile samples the terrain of the four layout
##    cells meeting at its corners and picks the matching Wang transition tile, so farmland
##    blends naturally into the surrounding meadow. The layer sits offset (-8, -8) in the
##    scene so visual tiles straddle logical cell corners (standard dual-grid trick).
##  - Decor: walkable plank floors ('p'), no collision — reused for Phase 4's dock boards
##    exactly as Phase 2 used it for ruined-shack floors (same tile, same walkability).
##  - Obstacles: solid rubble ('#'). These atlas tiles carry physics polygons on the tileset's
##    physics layer 0 (collision layer 1 = "world"), which is what the player collides with.
##  - Fence (Phase 4): solid perimeter ('F'), reuses the same solid ruins tile as Obstacles
##    (same physics polygon) but modulated worn-wood to read as fence/palisade rather than
##    rubble — a "simple recolor of existing tile art" per ROADMAP.md's scope note, no new art.
##  - Water (Phase 4): solid water body/river tiles ('W'), same solid-tile reuse, modulated a
##    cool blue-grey (GDD.md §9 "Rain-sky blue-grey") so it reads as water — same reasoning as
##    Fence above.
##
## scripts/structures.gd (a sibling child, like Farm) reads this node's `layout` to spawn the
## Phase 4 building volumes (farmhouse/mayor's house/store/shacks/chest/bulletin board) as real
## collidable StaticBody2D props, the same way Phase 3's Farm spawns tree/ore resource nodes.
##
## Phase 3 adds a runtime "tilled" overlay (`_tilled`) on top of the static layout: hoeing a
## grass cell flips that cell's soil bit here rather than mutating the layout's ASCII data
## (which stays a fixed source-of-truth for the map's authored terrain). is_soil_at() is the
## combined query every ground-painting call uses. See scripts/farm_grid.gd's class doc for the
## full reasoning on why tilling targets logical cells while the dual-grid handles corners.

const SettlementDB := preload("res://scripts/settlement_db.gd")
const WangTileset := preload("res://scripts/wang_tileset.gd")
const FarmGrid := preload("res://scripts/farm_grid.gd")

## All 3 map_layouts/*.gd scripts share this tile size; hardcoded (rather than read off
## `layout`) because it's needed before `layout` is resolved in some call orders and every start
## agrees on it anyway (Phase 1's locked 16px tile size).
const CELL_SIZE := 16

## Atlas source ids inside tilemaps/wasteland_tileset.tres.
const SOURCE_SETTLEMENT := 0
const SOURCE_RUINS := 1

## Placeholder tints for Fence/Water (see class doc above) — locked GDD.md §9 palette hexes.
const FENCE_TINT := Color("#7b5025")  # worn wood (dark) — "beams, door frames, shadowed wood"
const WATER_TINT := Color("#7fa1b7")  # Spring Rains' rain-sky blue-grey, reused as a water tint

@onready var ground: TileMapLayer = $Ground
@onready var decor: TileMapLayer = $Decor
@onready var obstacles: TileMapLayer = $Obstacles
@onready var fence: TileMapLayer = $Fence
@onready var water: TileMapLayer = $Water

## The active map_layouts/*.gd script for this playthrough (every member is a static func,
## called directly on this reference — see settlement_db.gd's layout_for_id() header comment).
## Resolved in _enter_tree() (top-down: parent before children), not _ready() (bottom-up:
## children before parent), specifically so child nodes' _ready() — Farm and Structures both
## read `get_parent().layout` from their own _ready() — always see it already set. See
## structures.gd/farm.gd for the reader side.
var layout = null

## Runtime-tilled cells (Phase 3), keyed by logical cell coord. Absence = not tilled by the
## player; the layout's static 'f' cells are tilled from map load regardless of this overlay.
var _tilled: Dictionary = {}


func _enter_tree() -> void:
	layout = SettlementDB.layout_for_id(GameState.chosen_settlement_id)


func _ready() -> void:
	fence.modulate = FENCE_TINT
	water.modulate = WATER_TINT
	build()


func build() -> void:
	ground.clear()
	decor.clear()
	obstacles.clear()
	fence.clear()
	water.clear()
	var size: Vector2i = layout.size()
	# Dual-grid ground: one more visual tile than logical cells on each axis.
	for y in size.y + 1:
		for x in size.x + 1:
			_paint_ground_tile(Vector2i(x, y))
	# Decor + obstacles + fence + water are direct per-cell placements.
	for y in size.y:
		for x in size.x:
			match layout.cell(x, y):
				"p":
					decor.set_cell(Vector2i(x, y), SOURCE_RUINS, WangTileset.ALL_UPPER)
				"#":
					obstacles.set_cell(Vector2i(x, y), SOURCE_RUINS, WangTileset.ALL_LOWER)
				"F":
					fence.set_cell(Vector2i(x, y), SOURCE_RUINS, WangTileset.ALL_LOWER)
				"W":
					water.set_cell(Vector2i(x, y), SOURCE_RUINS, WangTileset.ALL_LOWER)


## Combined soil query: static farmland from the layout OR a runtime-tilled cell.
func is_soil_at(x: int, y: int) -> bool:
	return layout.is_soil(x, y) or _tilled.get(Vector2i(x, y), false)


func is_tilled_at(cell: Vector2i) -> bool:
	return _tilled.get(cell, false)


## Physically blocked terrain: fence/water/rubble, or inside a building's footprint (see
## scripts/map_layouts/layout_common.gd's is_solid()). Used by farm.gd's tilling guard so a
## player can't till a building's footprint cell that happens to read as plain grass in the
## layout's ASCII data (see layout_common.gd's class doc on why that gap needs an explicit check).
func is_blocked_at(cell: Vector2i) -> bool:
	return layout.is_solid(cell.x, cell.y)


## Till one logical cell (a hoe's effect): flips it into the soil overlay and repaints exactly
## the (up to four) visual dual-grid tiles whose corners touch it. Returns false if the cell
## isn't tillable terrain or is already tilled — callers (scripts/farm.gd) check first via
## Farm.can_till, this is the belt-and-suspenders guard.
func till_cell(cell: Vector2i) -> bool:
	if _tilled.get(cell, false):
		return false
	if not layout.is_tillable(cell.x, cell.y):
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
	return layout.cell_center(cell)


func terrain_at(cell: Vector2i) -> String:
	return layout.cell(cell.x, cell.y)


## Map bounds in world pixels — main.gd hands this to the camera for clamping.
func get_map_rect() -> Rect2:
	return layout.map_rect()


## Where the player spawns (the '@' cell's center).
func get_spawn_position() -> Vector2:
	return layout.cell_center(layout.spawn_cell())
