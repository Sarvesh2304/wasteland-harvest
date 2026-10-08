extends Node2D
## Builds the active map at load from the pure layout data in scripts/map_layouts/*.gd (Phase 2's
## single TestMapLayout generalized in Phase 4 to 3 named layouts — see scripts/settlement_db.gd).
##
## ## Rendering v2 (2026-10-07)
## Painted from the generated art/env sheets (docs/ART_STYLE.md §4) through runtime-built
## TileSets (scripts/terrain_tiles.gd), with every placement decision in the pure
## scripts/ground_rules.gd. Bottom to top:
##  - Base: the season's grass, one of 8 seamless variants per cell (logical grid).
##  - Dual-grid overlays, one TileMapLayer each, offset (-8, -8) so visual tiles straddle cell
##    corners: old road ('p' away from water), dirt paths (':'), cobbled plaza (';'), rubble
##    ground ('#'), tilled soil, wet soil
##    (follows Farm.wet_changed) and animated water ('W', plus footbridge cells spanning it).
##  - Planks: dock boards and footbridges ('p' touching water), boards across the walkway.
##  - Decor: flowers, tufts and specks scattered on grass, thick on old fields (',').
##  - Scenery (y-sorted with the player): connecting fence sprites per zone style ('F'),
##    decorative gates (non-exit 'G') and rubble piles ('#').
## Collision is a StaticBody2D on the "world" layer covering every solid cell ('#', 'F', 'W'),
## merged into horizontal runs.
##
## A runtime "tilled" overlay (`_tilled`, Phase 3) sits on top of the static layout: hoeing a
## grass cell flips that cell's soil bit here rather than mutating the layout's ASCII data
## (which stays a fixed source-of-truth for the map's authored terrain). is_soil_at() is the
## combined query every ground-painting call uses.

const SettlementDB := preload("res://scripts/settlement_db.gd")
const FarmGrid := preload("res://scripts/farm_grid.gd")
const SaveData := preload("res://scripts/save_data.gd")
const GroundRules := preload("res://scripts/ground_rules.gd")
const TerrainTiles := preload("res://scripts/terrain_tiles.gd")
const Calendar := preload("res://scripts/calendar.gd")
const RuinsLayoutScript := preload("res://scripts/map_layouts/ruins_layout.gd")
## The overlay terrains a ruins level can contain (ruins_gen.gd's legend).
const RUINS_OVERLAYS: Array[String] = ["asphalt", "concrete", "rubble_ground", "dirt", "water"]

## All 3 map_layouts/*.gd scripts share this tile size; hardcoded (rather than read off
## `layout`) because it's needed before `layout` is resolved in some call orders and every start
## agrees on it anyway (Phase 1's locked 16px tile size).
const CELL_SIZE := 16

## Dual-grid overlays, bottom to top.
const OVERLAY_ORDER: Array[String] = ["road", "asphalt", "concrete", "dirt", "cobble", "gravel", "rubble_ground", "soil",
	"soil_wet", "water"]
## Crafted path items -> the floor they lay (Milestone B): painted with the matching overlay.
const FLOOR_ITEMS := {"gravel_path": "gravel", "cobble_path": "cobble"}
## Which sheet the old road ('p' away from water) uses per zone: broken concrete paving in the
## settlement, cracked asphalt on the old highway.
const ROAD_SHEET := {"path": "asphalt"}
const DEFAULT_ROAD_SHEET := "concrete"
const Z_BASE := -22
const Z_OVERLAY := -21  # + index in OVERLAY_ORDER (ten layers: -21..-12, under the planks)
const Z_PLANKS := -10
const Z_DECOR := -9

## Fence/gate art per zone: the farm and ranch are timber, the old highway is chain-link, the town
## hides behind a palisade.
const FENCE_STYLE := {"farm": "fence_wood", "path": "fence_chainlink", "town": "fence_palisade",
	"ranch": "fence_wood", "ruins": "ruin_wall_brick"}
const GATE_STYLE := {"farm": "gate_wood", "path": "gate_chainlink", "town": "gate_wood",
	"ranch": "gate_wood"}
const FENCE_DIR := "res://art/env/fences/"
const RUBBLE_PILES: Array[String] = ["res://art/env/ruins/rubble_pile_1.png",
	"res://art/env/ruins/rubble_pile_2.png"]

var _base: TileMapLayer = null
var _overlays: Dictionary = {}  # terrain -> TileMapLayer
var _planks: TileMapLayer = null
var _decor: TileMapLayer = null
var _scenery: Node2D = null
var _walls: StaticBody2D = null
var _plank_info: Dictionary = {"planks": {}, "road": {}, "bridge": {}}
var _wet: Dictionary = {}
var _season := "spring"
var _fence_count := 0
## Player-laid floors (Milestone B): cell -> "gravel" | "cobble".
var _floors: Dictionary = {}
var _wall_cells := 0

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

## Runtime-blocked cells (Phase 4 Stage 2), keyed by logical cell coord — the footprints of
## player-placed structures (pending blueprints AND completed buildings, registered by
## scripts/structures.gd's place_blueprint). Same overlay-on-static-layout pattern as _tilled:
## the layout's ASCII stays the authored source of truth, runtime changes layer on top, and
## is_blocked_at() is the combined query everything (tilling guards, placement-validity checks)
## reads. Nothing un-places a building, but Phase 8 Stage 2 (fencing & perimeter system) adds a
## real unblock case: a completed non-solid structure (a Gate — see BuildingDB.solid()) lifts its
## own footprint back out of this overlay via unblock_cells() below, so it reads as walkable.
var _runtime_blocked: Dictionary = {}


## Which zone this instance paints ("farm"/"path"/"town"/"ranch") — set per instance in
## scenes/main.tscn since the zone split. The script keeps its test_map.gd filename despite now
## being the generic any-zone map script, to avoid a rename ripple through every tool/test path
## string.
@export var zone_id := "farm"


func _enter_tree() -> void:
	layout = SettlementDB.layout_for_zone(zone_id, GameState.chosen_settlement_id)


func _ready() -> void:
	build()
	var farm := get_node_or_null("Farm")
	if farm != null and farm.has_signal("wet_changed"):
		farm.wet_changed.connect(_on_wet_changed)
	DayManager.day_started.connect(_on_day_started)


func build() -> void:
	_ensure_layers()
	_season = Calendar.season(DayManager.day)
	_plank_info = GroundRules.classify_planks(layout)
	_sync_wet()
	var size: Vector2i = layout.size()
	_base.clear()
	_planks.clear()
	_decor.clear()
	for terrain in OVERLAY_ORDER:
		(_overlays[terrain] as TileMapLayer).clear()
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			_paint_base(cell)
			_paint_decor(cell)
	for terrain in OVERLAY_ORDER:
		if zone_id == "ruins" and not RUINS_OVERLAYS.has(terrain):
			continue  # never present in a ruins level (cleared above): skip ~half the painting
		for vy in size.y + 1:
			for vx in size.x + 1:
				_paint_overlay(terrain, Vector2i(vx, vy))
	var plank_map: Dictionary = _plank_info["planks"]
	for cell in plank_map:
		var source := TerrainTiles.SOURCE_PLANKS_V if plank_map[cell] == "v" else TerrainTiles.SOURCE_PLANKS_H
		_planks.set_cell(cell, source, Vector2i(GroundRules.variant(cell, 21, 4), 0))
	_build_scenery()
	_build_walls()


func _ensure_layers() -> void:
	if _base != null:
		return
	_base = _new_layer("GroundBase", TerrainTiles.base_set(), Z_BASE, Vector2.ZERO)
	for i in OVERLAY_ORDER.size():
		var terrain := OVERLAY_ORDER[i]
		_overlays[terrain] = _new_layer("Ground_" + terrain, TerrainTiles.overlay_set(_sheet_for(terrain)),
			Z_OVERLAY + i, Vector2(-CELL_SIZE / 2.0, -CELL_SIZE / 2.0))
	_planks = _new_layer("GroundPlanks", TerrainTiles.plank_set(), Z_PLANKS, Vector2.ZERO)
	_decor = _new_layer("GroundDecor", TerrainTiles.decor_set(), Z_DECOR, Vector2.ZERO)
	_scenery = Node2D.new()
	_scenery.name = "Scenery"
	_scenery.y_sort_enabled = true
	add_child(_scenery)
	_walls = StaticBody2D.new()
	_walls.name = "Walls"
	_walls.collision_layer = 1  # "world" — see project.godot [layer_names]
	_walls.collision_mask = 0
	add_child(_walls)


func _new_layer(layer_name: String, tile_set: TileSet, z: int, offset: Vector2) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.z_index = z
	layer.position = offset
	layer.collision_enabled = false
	add_child(layer)
	move_child(layer, 0)
	return layer


## Whether logical `cell` belongs to an overlay terrain.
func _in_terrain(terrain: String, cell: Vector2i) -> bool:
	match terrain:
		"soil":
			return is_soil_at(cell.x, cell.y)
		"soil_wet":
			return _wet.has(cell) and is_soil_at(cell.x, cell.y)
		"water":
			return String(layout.cell(cell.x, cell.y)) == "W" or (_plank_info["bridge"] as Dictionary).has(cell)
		"rubble_ground":
			var ch := String(layout.cell(cell.x, cell.y))
			return ch == "#" or ch == "r"
		# Milestone C ruins ground: streets and sidewalks (buildings stand on concrete).
		"asphalt":
			return String(layout.cell(cell.x, cell.y)) == "a"
		"concrete":
			var c := String(layout.cell(cell.x, cell.y))
			return c == "c" or c == "X"
		"dirt":
			return String(layout.cell(cell.x, cell.y)) == ":"
		"cobble":
			return String(layout.cell(cell.x, cell.y)) == ";" or _floors.get(cell, "") == "cobble"
		"gravel":
			return _floors.get(cell, "") == "gravel"
		"road":
			return (_plank_info["road"] as Dictionary).has(cell)
	return false


## The art sheet an overlay layer paints with.
func _sheet_for(terrain: String) -> String:
	if terrain == "road":
		return String(ROAD_SHEET.get(zone_id, DEFAULT_ROAD_SHEET))
	return terrain


func _paint_overlay(terrain: String, visual: Vector2i) -> void:
	var layer: TileMapLayer = _overlays[terrain]
	var mask := GroundRules.corner_mask(
		_in_terrain(terrain, visual + Vector2i(-1, -1)),
		_in_terrain(terrain, visual + Vector2i(0, -1)),
		_in_terrain(terrain, visual + Vector2i(-1, 0)),
		_in_terrain(terrain, visual))
	if mask == 0:
		layer.erase_cell(visual)
	elif mask == GroundRules.FULL:
		var v := GroundRules.variant(visual, 13, TerrainTiles.full_variants(_sheet_for(terrain)))
		layer.set_cell(visual, TerrainTiles.SOURCE_FULL, Vector2i(v, 0))
	else:
		layer.set_cell(visual, TerrainTiles.SOURCE_EDGE, GroundRules.overlay_atlas(mask))


func _repaint_overlay_around(terrain: String, cell: Vector2i) -> void:
	for visual in GroundRules.visuals_touching(cell):
		_paint_overlay(terrain, visual)


func _paint_base(cell: Vector2i) -> void:
	if zone_id == "ruins":
		_base.set_cell(cell, TerrainTiles.ruins_source(),
			Vector2i(GroundRules.weighted_variant(cell, 3, GroundRules.GRASS_VARIANT_WEIGHTS), 0))
		return
	_base.set_cell(cell, TerrainTiles.season_source(_season),
		Vector2i(GroundRules.weighted_variant(cell, 3, GroundRules.GRASS_VARIANT_WEIGHTS), 0))


func _paint_decor(cell: Vector2i) -> void:
	if zone_id == "ruins":
		_decor.erase_cell(cell)  # nothing blooms in the ruins
		return
	var ch := String(layout.cell(cell.x, cell.y))
	var grassy := ch == "." or ch == "," or ch == "@" or ch == "T" or ch == "O"
	if not grassy or is_soil_at(cell.x, cell.y) or layout.is_solid(cell.x, cell.y) \
			or _floors.has(cell):
		_decor.erase_cell(cell)
		return
	var source := TerrainTiles.decor_source(GroundRules.decor_for(cell, _season, ch == ","))
	if source < 0:
		_decor.erase_cell(cell)
	else:
		_decor.set_cell(cell, source, Vector2i.ZERO)


## Fences, decorative gates and rubble piles: y-sorted sprites sharing the player's draw order.
func _build_scenery() -> void:
	for child in _scenery.get_children():
		child.queue_free()
	_fence_count = 0
	var style := String(FENCE_STYLE.get(zone_id, "fence_wood"))
	if zone_id == "ruins" and layout != null and layout.get("level") is Dictionary:
		style = String((layout.get("level") as Dictionary).get("wall_style", style))
	var fence_path := FENCE_DIR + style + ".png"
	if not ResourceLoader.exists(fence_path):
		fence_path = FENCE_DIR + "fence_chainlink.png"
	var fence_tex: Texture2D = load(fence_path)
	var gate_tex: Texture2D = load(FENCE_DIR + String(GATE_STYLE.get(zone_id, "gate_wood")) + ".png")
	var size: Vector2i = layout.size()
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			match String(layout.cell(x, y)):
				"F":
					var mask := GroundRules.fence_mask(_fence_joins(cell + Vector2i.UP),
						_fence_joins(cell + Vector2i.RIGHT), _fence_joins(cell + Vector2i.DOWN),
						_fence_joins(cell + Vector2i.LEFT))
					_add_cell_sprite(cell, fence_tex, GroundRules.fence_region(mask))
					_fence_count += 1
				"G":
					if zone_exit_at(cell).is_empty():
						_add_cell_sprite(cell, gate_tex, Rect2i(16, 0, 16, 32))  # open frame
				"#":
					var tex: Texture2D = load(RUBBLE_PILES[GroundRules.variant(cell, 17, RUBBLE_PILES.size())])
					var sprite := Sprite2D.new()
					sprite.texture = tex
					sprite.centered = false
					sprite.position = Vector2(x * CELL_SIZE + CELL_SIZE / 2.0, (y + 1) * CELL_SIZE)
					sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
					sprite.flip_h = GroundRules.variant(cell, 18, 2) == 1
					_scenery.add_child(sprite)


## A fence post joins toward a neighbouring fence, or a gate that sits in the fence line.
func _fence_joins(cell: Vector2i) -> bool:
	var ch := String(layout.cell(cell.x, cell.y))
	return ch == "F" or (ch == "G" and zone_exit_at(cell).is_empty())


## A 16x32 frame standing on `cell`: its bottom 16x16 covers the cell, its top half overhangs the
## cell to the north; y-sorted from the cell's bottom edge.
func _add_cell_sprite(cell: Vector2i, texture: Texture2D, region: Rect2i) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(region)
	sprite.centered = false
	sprite.position = Vector2(cell.x * CELL_SIZE, (cell.y + 1) * CELL_SIZE)
	sprite.offset = Vector2(0, -region.size.y)
	_scenery.add_child(sprite)


## One collision rectangle per horizontal run of solid layout cells.
func _build_walls() -> void:
	for child in _walls.get_children():
		child.queue_free()
	_wall_cells = 0
	var size: Vector2i = layout.size()
	for y in size.y:
		var x := 0
		while x < size.x:
			if not _solid_terrain(x, y):
				x += 1
				continue
			var start := x
			while x < size.x and _solid_terrain(x, y):
				x += 1
			var run := x - start
			_wall_cells += run
			var shape := RectangleShape2D.new()
			shape.size = Vector2(run * CELL_SIZE, CELL_SIZE)
			var col := CollisionShape2D.new()
			col.shape = shape
			col.position = Vector2((start + run / 2.0) * CELL_SIZE, (y + 0.5) * CELL_SIZE)
			_walls.add_child(col)


func _solid_terrain(x: int, y: int) -> bool:
	return String(layout.cell(x, y)) in ["#", "F", "W", "X"]


## -- The ruins zone (Milestone C, 2026-10-07) --

## Swaps in a generated level (scripts/ruins_gen.gd output, wrapped as a RuinsLayout) and
## repaints everything. Only the ruins map does this; its objects and enemies are respawned by
## main.gd's expedition flow right after.
func load_ruins_level(level: Dictionary) -> void:
	layout = RuinsLayoutScript.new(level)
	_floors.clear()
	_tilled.clear()
	_runtime_blocked.clear()
	build()


## Painted-layer stats for the smoke tools: {base, fences, wall_cells, planks, road, water}.
func render_stats() -> Dictionary:
	return {
		"base": _base.get_used_cells().size(),
		"fences": _fence_count,
		"wall_cells": _wall_cells,
		"planks": _planks.get_used_cells().size(),
		"road": (_plank_info["road"] as Dictionary).size(),
		"water": (_overlays["water"] as TileMapLayer).get_used_cells().size(),
		"decor": _decor.get_used_cells().size(),
	}


func _sync_wet() -> void:
	_wet.clear()
	var farm := get_node_or_null("Farm")
	if farm != null and farm.has_method("wet_cells"):
		for cell in farm.wet_cells():
			_wet[cell] = true


func _on_wet_changed(cell: Vector2i) -> void:
	var farm := get_node_or_null("Farm")
	var wet: bool = farm != null and farm.is_wet(cell)
	if wet == _wet.has(cell):
		return
	if wet:
		_wet[cell] = true
	else:
		_wet.erase(cell)
	_repaint_overlay_around("soil_wet", cell)


func _on_day_started(day: int) -> void:
	var season := Calendar.season(day)
	if season == _season or zone_id == "ruins":
		return
	_season = season
	var size: Vector2i = layout.size()
	for y in size.y:
		for x in size.x:
			_paint_base(Vector2i(x, y))
			_paint_decor(Vector2i(x, y))


## -- Player-laid floors (Milestone B, 2026-10-07) --

func floor_kind_for_item(item_id: String) -> String:
	return String(FLOOR_ITEMS.get(item_id, ""))


func has_floor(cell: Vector2i) -> bool:
	return _floors.has(cell)


## Open ground the player can pave: grass, old field or dirt, not soil, not blocked, nothing on it.
func can_place_floor(cell: Vector2i, farm: Node = null) -> bool:
	var size: Vector2i = layout.size()
	if cell.x < 1 or cell.y < 1 or cell.x >= size.x - 1 or cell.y >= size.y - 1:
		return false
	if _floors.has(cell) or is_blocked_at(cell) or is_soil_at(cell.x, cell.y):
		return false
	var ch := String(layout.cell(cell.x, cell.y))
	if not (ch == "." or ch == "," or ch == "@" or ch == ":"):
		return false
	var objects := get_node_or_null("Objects")
	if objects != null and objects.has_object(cell):
		return false
	return farm == null or farm.get_plot(cell).is_empty()


func place_floor(cell: Vector2i, item_id: String, farm: Node = null) -> bool:
	var kind := floor_kind_for_item(item_id)
	if kind == "" or not can_place_floor(cell, farm):
		return false
	_floors[cell] = kind
	_repaint_floor(cell)
	Audio.play_sfx_at("footstep_stone", get_global_cell_center(cell), -2.0)
	return true


## Pulls a floor back up (pickaxe); returns the path item to give back ("" = no floor).
func remove_floor(cell: Vector2i) -> String:
	if not _floors.has(cell):
		return ""
	var kind := String(_floors[cell])
	_floors.erase(cell)
	_repaint_floor(cell)
	for item in FLOOR_ITEMS:
		if FLOOR_ITEMS[item] == kind:
			return String(item)
	return ""


func _repaint_floor(cell: Vector2i) -> void:
	if _base == null:
		return
	_repaint_overlay_around("gravel", cell)
	_repaint_overlay_around("cobble", cell)
	_paint_decor(cell)


## Old-road and plank cells (footstep surfaces).
func is_path_at(cell: Vector2i) -> bool:
	return (_plank_info["road"] as Dictionary).has(cell) or (_plank_info["planks"] as Dictionary).has(cell) \
		or _floors.has(cell)


func is_plank_at(cell: Vector2i) -> bool:
	return (_plank_info["planks"] as Dictionary).has(cell)


## Combined soil query: static farmland from the layout OR a runtime-tilled cell.
func is_soil_at(x: int, y: int) -> bool:
	return layout.is_soil(x, y) or _tilled.get(Vector2i(x, y), false)


func is_tilled_at(cell: Vector2i) -> bool:
	return _tilled.get(cell, false)


## Physically blocked terrain: fence/water/rubble, inside a layout building's footprint (see
## scripts/map_layouts/layout_common.gd's is_solid()), or inside a player-placed structure's
## footprint (the _runtime_blocked overlay). Used by farm.gd's tilling guard so a player can't
## till a building's footprint cell that happens to read as plain grass in the layout's ASCII
## data (see layout_common.gd's class doc on why that gap needs an explicit check), and by
## structures.gd's can_place() so new blueprints can't overlap anything solid.
func is_blocked_at(cell: Vector2i) -> bool:
	return layout.is_solid(cell.x, cell.y) or _runtime_blocked.has(cell)


## Register a player-placed structure's footprint cells as blocked (scripts/structures.gd calls
## this the moment a blueprint is placed — the site is off-limits from placement, not completion).
func block_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_runtime_blocked[cell] = true


## Phase 8 Stage 2 (fencing & perimeter system): the block_cells() counterpart, called by
## scripts/structures.gd's _complete_construction() when a completed structure's BuildingDB.solid()
## reads false (so far, only the Gate) — its footprint stops reading as blocked, becoming walkable
## the moment construction finishes. Mirrors block_cells()'s per-cell loop exactly; erase() is a
## no-op for a cell that was never in the overlay, so this is always safe to call.
func unblock_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_runtime_blocked.erase(cell)


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
	_on_soil_changed(cell)
	return true


## Save-restore helper: marks a cell tilled without the tillable-terrain check (a saved crop
## must never end up floating on grass after a layout change).
func force_till(cell: Vector2i) -> void:
	if is_soil_at(cell.x, cell.y):
		return
	_tilled[cell] = true
	_on_soil_changed(cell)


## A cell turned to soil: repaint the soil layers around it and clear its decor.
func _on_soil_changed(cell: Vector2i) -> void:
	if _base == null:
		return
	_repaint_overlay_around("soil", cell)
	_repaint_overlay_around("soil_wet", cell)
	_decor.erase_cell(cell)


## -- Save/load (Phase 4 Stage 3; see scripts/save_data.gd's class doc for the shape) --
## Only the _tilled overlay is serialised. _runtime_blocked is deliberately NOT — it's derived
## from placed/completed structures, and structures.gd's load_state() re-registers each restored
## footprint via the same block_cells() call place_blueprint() makes live, so save and load
## can't diverge on what counts as blocked.

func save_state() -> Dictionary:
	var floors := {}
	for cell in _floors:
		floors[SaveData.cell_key(cell)] = String(_floors[cell])
	return {"tilled": SaveData.encode_cells(_tilled.keys()), "floors": floors}


func load_state(data: Dictionary) -> void:
	for cell in SaveData.decode_cells(data.get("tilled", [])):
		# Direct overlay write + repaint rather than till_cell(): the cell already passed the
		# is_tillable guard when it was legally tilled in the saved session — restoring is a
		# replay of established fact, not a new gameplay action to re-validate.
		_tilled[cell] = true
		_on_soil_changed(cell)
	var floors = data.get("floors", {})
	if floors is Dictionary:
		for key in floors:
			var cell := SaveData.parse_cell_key(String(key))
			_floors[cell] = String(floors[key])
			_repaint_floor(cell)


## World position -> logical cell coordinate (floor division by the 16px tile size).
## Since the zone split, each zone instance sits at a distinct position offset under Main (a
## pure non-collision trick — each zone has its own camera view), so the caller's world position
## must be brought into this zone's local frame first. Every existing caller keeps passing raw
## global_position unchanged: to_local() is a no-op for the origin-anchored farm and correct for
## free for the offset zones.
func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := to_local(world_pos)
	return Vector2i(floori(local.x / CELL_SIZE), floori(local.y / CELL_SIZE))


func cell_to_world_center(cell: Vector2i) -> Vector2:
	return layout.cell_center(cell)


## Zone-local cell -> WORLD-space center (the reverse of world_to_cell's frame fix) — for the
## call sites that position things living outside this zone's subtree: the player teleport on
## zone entry, NPC step targets, the builder's preview.
func get_global_cell_center(cell: Vector2i) -> Vector2:
	return to_global(cell_to_world_center(cell))


func terrain_at(cell: Vector2i) -> String:
	return layout.cell(cell.x, cell.y)


## Map bounds in ZONE-LOCAL pixels (kept for the tests/tools that predate the zone split).
func get_map_rect() -> Rect2:
	return layout.map_rect()


## Map bounds in WORLD pixels — main.gd hands this to the camera for clamping, so the clamp
## follows the zone's position offset.
func get_global_map_rect() -> Rect2:
	var r := get_map_rect()
	return Rect2(to_global(r.position), r.size)


## Where the player spawns (the '@' cell's center), zone-local — main.gd converts via
## to_global for the actual boot teleport.
func get_spawn_position() -> Vector2:
	return layout.cell_center(layout.spawn_cell())


## The zone_exits() entry whose gate cells contain `cell`, or {} if the cell is not a
## transition gate. player.gd polls this each physics frame with its own current cell; main.gd
## acts on the resulting {gate_cells, target_zone, entry_cell} via the zone fade.
func zone_exit_at(cell: Vector2i) -> Dictionary:
	if layout == null:
		return {}
	for exit in layout.zone_exits():
		if cell in exit["gate_cells"]:
			return exit
	return {}
