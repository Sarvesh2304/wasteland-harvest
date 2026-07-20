extends Node2D
## Stateful farming layer (ROADMAP Phase 3): owns planted-plot state, crop sprites, and the two
## placeholder resource nodes (tree/ore), and is the single entry point player.gd calls into for
## till/plant/water/harvest/chop/mine. All the actual rules live in scripts/farm_grid.gd as pure
## functions — this node is just the stateful Dictionary + scene-tree glue around them, same
## split as scripts/day_manager.gd (pure sky_color()/format_clock() vs. stateful _process()).
##
## Expected in the scene tree as a child of TestMap (see scenes/test_map.tscn) so get_parent()
## is the TestMap node it repaints tilled soil through and reads terrain from.

const FarmGrid := preload("res://scripts/farm_grid.gd")
const CropDB := preload("res://scripts/crop_db.gd")
const SaveData := preload("res://scripts/save_data.gd")

signal plot_changed(cell: Vector2i)
signal resource_node_removed(cell: Vector2i)

## cell -> {crop_id, stage, watered}. Absence = bare ground (tilled or not).
var _plots: Dictionary = {}
## cell -> "tree" | "ore".
var _resource_nodes: Dictionary = {}
var _crop_sprites: Dictionary = {}
var _resource_bodies: Dictionary = {}

var _test_map: Node2D


func _ready() -> void:
	_test_map = get_parent()
	for entry in _test_map.layout.resource_node_cells():
		var cell: Vector2i = entry["cell"]
		_resource_nodes[cell] = String(entry["kind"])
		_spawn_resource_prop(cell, String(entry["kind"]))
	DayManager.day_started.connect(_on_day_started)


## -- Tilling --

func can_till(cell: Vector2i) -> bool:
	if _resource_nodes.has(cell) or _plots.has(cell):
		return false
	if _test_map.is_tilled_at(cell):
		return false
	# Phase 4: a building's footprint can include cells that still read as plain grass in the
	# layout's ASCII data (only the top-left cell carries the building's marker char — see
	# map_layouts/layout_common.gd's class doc), so the terrain-char check alone isn't enough to
	# keep a hoe out from under a farmhouse/mayor's house/shack. is_blocked_at() closes that gap.
	if _test_map.is_blocked_at(cell):
		return false
	return FarmGrid.is_tillable_terrain(_test_map.terrain_at(cell))


func till(cell: Vector2i) -> bool:
	if not can_till(cell):
		return false
	return _test_map.till_cell(cell)


## -- Planting --

func can_plant(cell: Vector2i) -> bool:
	return _test_map.is_soil_at(cell.x, cell.y) and not _plots.has(cell)


func plant(cell: Vector2i, crop_id: String) -> bool:
	if not can_plant(cell) or not CropDB.has_crop(crop_id):
		return false
	_plots[cell] = {"crop_id": crop_id, "stage": 0, "watered": false}
	_refresh_crop_sprite(cell)
	plot_changed.emit(cell)
	return true


## -- Watering --

func can_water(cell: Vector2i) -> bool:
	var plot: Dictionary = _plots.get(cell, {})
	if plot.is_empty() or bool(plot.get("watered", false)):
		return false
	return not FarmGrid.is_mature(plot, CropDB.growth_stages(String(plot.get("crop_id", ""))))


func water(cell: Vector2i) -> bool:
	if not can_water(cell):
		return false
	var plot: Dictionary = _plots[cell]
	plot["watered"] = true
	_plots[cell] = plot
	_refresh_crop_sprite(cell)
	plot_changed.emit(cell)
	return true


func is_watered(cell: Vector2i) -> bool:
	return bool(_plots.get(cell, {}).get("watered", false))


## Phase 8 Stage 1: every planted-but-not-yet-watered cell in THIS zone's farmland (can_water()'s
## own rule — a mature crop no longer needs watering, so it's excluded too), in Dictionary
## iteration order. Consumed by scripts/building_effects.gd's Rain Collector tick, which is the
## only reason a caller outside this node needs to enumerate plots rather than check one cell at
## a time — kept here (not exposed as raw _plots access) so farm.gd stays the single owner of
## what "waterable" means.
func waterable_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in _plots.keys():
		if can_water(cell):
			out.append(cell)
	return out


## -- Harvesting --

func can_harvest(cell: Vector2i) -> bool:
	var plot: Dictionary = _plots.get(cell, {})
	if plot.is_empty():
		return false
	return FarmGrid.is_mature(plot, CropDB.growth_stages(String(plot.get("crop_id", ""))))


## {} if nothing harvestable, else {item_id, count}. Plot returns to bare tilled soil.
func harvest(cell: Vector2i) -> Dictionary:
	var plot: Dictionary = _plots.get(cell, {})
	if plot.is_empty():
		return {}
	var crop_def := CropDB.get_crop(String(plot.get("crop_id", "")))
	var result := FarmGrid.harvest_yield(plot, crop_def)
	if result.is_empty():
		return {}
	_plots.erase(cell)
	_clear_crop_sprite(cell)
	plot_changed.emit(cell)
	return result


func get_plot(cell: Vector2i) -> Dictionary:
	return _plots.get(cell, {})


## -- Resource nodes (Phase 3 minimal scope: single-hit, no respawn — see map_layouts/layout_common.gd) --

func can_chop(cell: Vector2i) -> bool:
	return _resource_nodes.get(cell, "") == "tree"


func can_mine(cell: Vector2i) -> bool:
	return _resource_nodes.get(cell, "") == "ore"


## Array of {item_id, count} yields (a resource node can grant more than one item type).
func chop(cell: Vector2i) -> Array[Dictionary]:
	if not can_chop(cell):
		return []
	_remove_resource_node(cell)
	return [{"item_id": "wood", "count": 3}]


func mine(cell: Vector2i) -> Array[Dictionary]:
	if not can_mine(cell):
		return []
	_remove_resource_node(cell)
	return [{"item_id": "stone", "count": 2}, {"item_id": "scrap_metal", "count": 1}]


func _remove_resource_node(cell: Vector2i) -> void:
	_resource_nodes.erase(cell)
	var body: Node = _resource_bodies.get(cell)
	if body != null:
		body.queue_free()
	_resource_bodies.erase(cell)
	resource_node_removed.emit(cell)


func _spawn_resource_prop(cell: Vector2i, kind: String) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1  # "world" — see project.godot [layer_names]
	body.collision_mask = 0
	body.position = _test_map.cell_to_world_center(cell)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	shape.shape = rect
	body.add_child(shape)
	var visual := ColorRect.new()
	visual.size = Vector2(12, 12)
	visual.position = Vector2(-6, -6)
	# Flat-color placeholder (Phase 3 scope call, see map_layouts/layout_common.gd's legend comment):
	# ash-brown stump for trees, concrete-grey for ore, both from the locked GDD §9 palette.
	visual.color = Color("#7b5025") if kind == "tree" else Color("#9d9180")
	body.add_child(visual)
	add_child(body)
	_resource_bodies[cell] = body


## -- Save/load (Phase 4 Stage 3; see scripts/save_data.gd's class doc for the shape) --

func save_state() -> Dictionary:
	return {
		"plots": SaveData.encode_plots(_plots),
		# Nodes still STANDING; a chopped tree / mined ore is simply absent, so it stays gone
		# after a reload (Phase 3's documented single-hit/no-respawn rule).
		"resource_nodes": SaveData.encode_resource_nodes(_resource_nodes),
	}


## Applies a loaded save on top of the layout-authored state _ready() already built: prunes the
## resource nodes the saved playthrough had cleared (removing their collision bodies through the
## same _remove_resource_node path chopping/mining uses), then installs the saved plots and
## spawns their crop sprites at the correct stage/watered tint.
func load_state(data: Dictionary) -> void:
	var remaining := SaveData.decode_resource_nodes(data.get("resource_nodes", {}))
	for cell in _resource_nodes.keys():
		if not remaining.has(cell):
			_remove_resource_node(cell)
	_plots = SaveData.decode_plots(data.get("plots", {}))
	for cell in _plots.keys():
		_refresh_crop_sprite(cell)
		plot_changed.emit(cell)


## -- Daily growth tick --

func _on_day_started(_day: int) -> void:
	var wilted: Array[Vector2i] = []
	for cell in _plots.keys():
		var plot: Dictionary = _plots[cell]
		var growth_stages := CropDB.growth_stages(String(plot.get("crop_id", "")))
		var next_plot := FarmGrid.advance_plot(plot, growth_stages)
		if next_plot.is_empty():
			wilted.append(cell)
		else:
			_plots[cell] = next_plot
	for cell in wilted:
		_plots.erase(cell)
		_clear_crop_sprite(cell)
		plot_changed.emit(cell)
	for cell in _plots.keys():
		_refresh_crop_sprite(cell)


## -- Crop sprite presentation --

func _refresh_crop_sprite(cell: Vector2i) -> void:
	var plot: Dictionary = _plots.get(cell, {})
	if plot.is_empty():
		_clear_crop_sprite(cell)
		return
	var crop_id := String(plot.get("crop_id", ""))
	var stage := int(plot.get("stage", 0))
	var sprite: Sprite2D = _crop_sprites.get(cell)
	if sprite == null:
		sprite = Sprite2D.new()
		add_child(sprite)
		sprite.position = _test_map.cell_to_world_center(cell)
		_crop_sprites[cell] = sprite
	sprite.texture = _crop_texture(crop_id, stage)
	# Watered visual indicator (checklist requirement): a faint cool-blue tint on the crop
	# sprite while its watered flag is set for the day; back to neutral once consumed at the
	# next morning tick. Simple, cheap, and reads clearly at the 16px tile scale.
	sprite.modulate = Color(0.78, 0.87, 1.0) if bool(plot.get("watered", false)) else Color.WHITE


func _clear_crop_sprite(cell: Vector2i) -> void:
	var sprite: Sprite2D = _crop_sprites.get(cell)
	if sprite != null:
		sprite.queue_free()
	_crop_sprites.erase(cell)


## Real PixelLab art if the stage file exists (art/crops/<crop>/stage_N.png — see
## art/crops/README.md for provenance); otherwise a flat-color placeholder that darkens-to-
## amber across stages, so the game still runs (and headless tests still pass) even before/
## without the generated art present.
func _crop_texture(crop_id: String, stage: int) -> Texture2D:
	var path := CropDB.stage_texture_path(crop_id, stage)
	if ResourceLoader.exists(path):
		return load(path)
	var growth_stages: int = maxi(CropDB.growth_stages(crop_id) - 1, 1)
	var t := float(stage) / float(growth_stages)
	var color: Color = Color("#95ac49").lerp(Color("#e1982a"), t)
	var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
