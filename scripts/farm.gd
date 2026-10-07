extends Node2D
## Stateful farming layer for one zone (v2, 2026-10-07): soil wetness, fertiliser, planted plots
## and their crop sprites. The rules are pure functions in scripts/farm_grid.gd (growth, seasons,
## regrowth, yields); this node is the stateful dictionaries + scene glue around them.
## Trees, rocks and other world objects moved to scripts/world_objects.gd (the sibling "Objects"
## node) — tilling and planting just check it's not in the way.
##
## Expected as a child of a zone map (scenes/test_map.tscn); get_parent() is that map.

const FarmGrid := preload("res://scripts/farm_grid.gd")
const CropDB := preload("res://scripts/crop_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const SaveData := preload("res://scripts/save_data.gd")
const Calendar := preload("res://scripts/calendar.gd")

signal plot_changed(cell: Vector2i)
## A cell's wet (watered-today) state changed; the map repaints its wet-soil overlay.
signal wet_changed(cell: Vector2i)

## plant_check() results.
const OK := ""
const NO_SOIL := "no_soil"
const OCCUPIED := "occupied"
const WRONG_SEASON := "wrong_season"
const UNKNOWN_CROP := "unknown_crop"

## cell -> plot (see farm_grid.gd for the shape). Absence = bare ground.
var _plots: Dictionary = {}
## cell -> true for soil watered today (with or without a crop).
var _wet: Dictionary = {}
## cell -> fertiliser level (1 basic, 2 rich) laid on soil, consumed by the next planting.
var _fertilized: Dictionary = {}
var _crop_sprites: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var _test_map: Node2D


func _ready() -> void:
	_test_map = get_parent()
	y_sort_enabled = true
	_rng.randomize()
	DayManager.day_started.connect(_on_day_started)


func _objects() -> Node:
	return _test_map.get_node_or_null("Objects") if _test_map != null else null


func _season() -> String:
	return Calendar.season(DayManager.day)


## -- Tilling --

func can_till(cell: Vector2i) -> bool:
	if _plots.has(cell) or _test_map.is_tilled_at(cell) or _test_map.is_blocked_at(cell):
		return false
	var objects := _objects()
	if objects != null and objects.has_object(cell):
		return false
	return FarmGrid.is_tillable_terrain(_test_map.terrain_at(cell))


func till(cell: Vector2i) -> bool:
	if not can_till(cell):
		return false
	return _test_map.till_cell(cell)


func is_soil(cell: Vector2i) -> bool:
	return _test_map.is_soil_at(cell.x, cell.y)


## -- Planting --

## Why planting `crop_id` at `cell` would fail ("" = it wouldn't).
func plant_check(cell: Vector2i, crop_id: String) -> String:
	if not CropDB.has_crop(crop_id):
		return UNKNOWN_CROP
	if not is_soil(cell):
		return NO_SOIL
	var objects := _objects()
	if _plots.has(cell) or (objects != null and objects.has_object(cell)):
		return OCCUPIED
	if not CropDB.grows_in_season(crop_id, _season()):
		return WRONG_SEASON
	return OK


func can_plant(cell: Vector2i, crop_id: String = "") -> bool:
	if crop_id == "":
		var objects := _objects()
		return is_soil(cell) and not _plots.has(cell) and (objects == null or not objects.has_object(cell))
	return plant_check(cell, crop_id) == OK


func plant(cell: Vector2i, crop_id: String) -> bool:
	if plant_check(cell, crop_id) != OK:
		return false
	var plot := FarmGrid.new_plot(crop_id, int(_fertilized.get(cell, 0)))
	plot["watered"] = _wet.has(cell)
	_plots[cell] = plot
	_refresh_crop_sprite(cell, true)
	plot_changed.emit(cell)
	return true


## A random crop that grows this season (wild/mixed seeds).
func random_seasonal_crop() -> String:
	var options := CropDB.crops_for_season(_season())
	if options.is_empty():
		return ""
	return options[_rng.randi_range(0, options.size() - 1)]


## -- Fertiliser --

func can_fertilize(cell: Vector2i, level: int) -> bool:
	if level <= 0 or not is_soil(cell):
		return false
	if int(_fertilized.get(cell, 0)) >= level:
		return false
	var plot: Dictionary = _plots.get(cell, {})
	# Like Stardew: before planting, or on a seedling that hasn't grown yet.
	return plot.is_empty() or int(plot.get("growth", 0)) == 0


func fertilize(cell: Vector2i, level: int) -> bool:
	if not can_fertilize(cell, level):
		return false
	_fertilized[cell] = level
	if _plots.has(cell):
		var plot: Dictionary = _plots[cell]
		plot["fertilizer"] = level
		_plots[cell] = plot
	plot_changed.emit(cell)
	return true


func fertilizer_at(cell: Vector2i) -> int:
	return int(_fertilized.get(cell, 0))


## -- Watering --

## Any tilled soil can be watered once a day (it darkens); a crop on it counts as watered.
func can_water(cell: Vector2i) -> bool:
	return is_soil(cell) and not _wet.has(cell)


func water(cell: Vector2i) -> bool:
	if not can_water(cell):
		return false
	_set_wet(cell, true)
	if _plots.has(cell):
		var plot: Dictionary = _plots[cell]
		plot["watered"] = true
		_plots[cell] = plot
		plot_changed.emit(cell)
	return true


func is_watered(cell: Vector2i) -> bool:
	return _wet.has(cell)


func is_wet(cell: Vector2i) -> bool:
	return _wet.has(cell)


func wet_cells() -> Array:
	return _wet.keys()


## Planted cells that still need water today (rain collectors, hired labour, hints).
func waterable_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in _plots.keys():
		var plot: Dictionary = _plots[cell]
		if FarmGrid.needs_water(plot, CropDB.get_crop(String(plot.get("crop_id", "")))) \
				and not _wet.has(cell):
			out.append(cell)
	return out


## Rain: every soil cell in this zone is watered.
func water_all() -> void:
	var size: Vector2i = _test_map.layout.size()
	for y in size.y:
		for x in size.x:
			if is_soil(Vector2i(x, y)):
				water(Vector2i(x, y))


func _set_wet(cell: Vector2i, wet: bool) -> void:
	if wet == _wet.has(cell):
		return
	if wet:
		_wet[cell] = true
	else:
		_wet.erase(cell)
	wet_changed.emit(cell)


## -- Harvesting --

func can_harvest(cell: Vector2i) -> bool:
	var plot: Dictionary = _plots.get(cell, {})
	if plot.is_empty():
		return false
	return FarmGrid.is_mature(plot, CropDB.get_crop(String(plot.get("crop_id", ""))))


## Harvests a mature crop: returns {"item_id", "count", "crop_id"} or {}. Regrowing crops stay
## planted (dropping back regrow_days of growth); everything else leaves bare soil and uses up
## the cell's fertiliser.
func harvest(cell: Vector2i) -> Dictionary:
	var plot: Dictionary = _plots.get(cell, {})
	if plot.is_empty():
		return {}
	var crop_id := String(plot.get("crop_id", ""))
	var crop_def := CropDB.get_crop(crop_id)
	var result := FarmGrid.harvest_yield(plot, crop_def, _rng.randf(), _rng.randf())
	if result.is_empty():
		return {}
	var next := FarmGrid.after_harvest(plot, crop_def)
	if next.is_empty():
		_plots.erase(cell)
		_fertilized.erase(cell)
		_clear_crop_sprite(cell, true)
	else:
		next["watered"] = _wet.has(cell)
		_plots[cell] = next
		_refresh_crop_sprite(cell, true)
	plot_changed.emit(cell)
	result["crop_id"] = crop_id
	return result


## Farming XP for harvesting one unit of an item worth `price` (Stardew's curve).
static func harvest_xp(price: int) -> int:
	return maxi(1, int(round(16.0 * log(0.018 * float(maxi(price, 0)) + 1.0))))


func is_dead(cell: Vector2i) -> bool:
	return bool(_plots.get(cell, {}).get("dead", false))


## Removes a withered crop (any tool or the interact button); soil stays tilled.
func clear_dead(cell: Vector2i) -> bool:
	if not is_dead(cell):
		return false
	_plots.erase(cell)
	_clear_crop_sprite(cell, false)
	plot_changed.emit(cell)
	return true


func get_plot(cell: Vector2i) -> Dictionary:
	return _plots.get(cell, {})


func all_plots() -> Dictionary:
	return _plots


## Hired-labour work area: the layout's farmland plus every tillable cell bordering it.
func labor_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var seen := {}
	var map_size: Vector2i = _test_map.layout.size()
	for y in map_size.y:
		for x in map_size.x:
			var cell := Vector2i(x, y)
			if _test_map.layout.is_soil(x, y):
				cells.append(cell)
				seen[cell] = true
	for source in cells.duplicate():
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var candidate: Vector2i = source + offset
			if candidate.x < 0 or candidate.y < 0 \
					or candidate.x >= map_size.x or candidate.y >= map_size.y:
				continue
			if seen.has(candidate) or _test_map.is_blocked_at(candidate):
				continue
			if FarmGrid.is_tillable_terrain(String(_test_map.terrain_at(candidate))):
				cells.append(candidate)
				seen[candidate] = true
	return cells


## -- Daily tick --

## Morning: every plot grows if it was watered (season permitting), wet soil dries, then today's
## rain (if any) waters everything again.
func _on_day_started(day: int) -> void:
	var season := Calendar.season(day)
	for cell in _plots.keys():
		var plot: Dictionary = _plots[cell]
		plot["watered"] = _wet.has(cell)
		var crop_def := CropDB.get_crop(String(plot.get("crop_id", "")))
		_plots[cell] = FarmGrid.advance_plot(plot, crop_def, season)
	for cell in _wet.keys():
		_set_wet(cell, false)
	if DayManager.is_raining():
		water_all()
	for cell in _plots.keys():
		_refresh_crop_sprite(cell, false)
		plot_changed.emit(cell)


## -- Crop sprites --

func _refresh_crop_sprite(cell: Vector2i, pop: bool) -> void:
	var plot: Dictionary = _plots.get(cell, {})
	if plot.is_empty():
		_clear_crop_sprite(cell, false)
		return
	var crop_id := String(plot.get("crop_id", ""))
	var sprite: Sprite2D = _crop_sprites.get(cell)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		add_child(sprite)
		# Origin on the cell's bottom edge so crops y-sort with people and objects.
		sprite.position = _test_map.cell_to_world_center(cell) + Vector2(0, 8)
		_crop_sprites[cell] = sprite
	if bool(plot.get("dead", false)):
		sprite.texture = _dead_texture(crop_id)
	else:
		sprite.texture = _crop_texture(crop_id, int(plot.get("stage", 0)))
	var tex_size := sprite.texture.get_size()
	sprite.offset = Vector2(-tex_size.x * 0.5, -tex_size.y)
	if pop:
		sprite.scale = Vector2(0.7, 1.25)
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _clear_crop_sprite(cell: Vector2i, pop: bool) -> void:
	var sprite: Sprite2D = _crop_sprites.get(cell)
	_crop_sprites.erase(cell)
	if sprite == null:
		return
	if pop and sprite.is_inside_tree():
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "scale", Vector2(1.3, 0.6), 0.08)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.08)
		tw.tween_callback(sprite.queue_free)
	else:
		sprite.queue_free()


func _crop_texture(crop_id: String, stage: int) -> Texture2D:
	var path := CropDB.stage_texture_path(crop_id, stage)
	if ResourceLoader.exists(path):
		return load(path)
	var growth_stages: int = maxi(CropDB.growth_stages(crop_id) - 1, 1)
	var t := float(stage) / float(growth_stages)
	var color: Color = Color("#95ac49").lerp(Color("#e1982a"), t)
	var h := 4 + int(10.0 * t)
	var image := Image.create(10, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(16 - h, 16):
		for x in range(2, 8):
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _dead_texture(crop_id: String) -> Texture2D:
	var path := CropDB.dead_texture_path(crop_id)
	if ResourceLoader.exists(path):
		return load(path)
	var image := Image.create(10, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in range(4, 12):
		for x in range(3, 7):
			image.set_pixel(x, y, Color("#78634c"))
	return ImageTexture.create_from_image(image)


## -- Save / load --

func save_state() -> Dictionary:
	return {
		"plots": SaveData.encode_plots(_plots),
		"wet": SaveData.encode_cells(_wet.keys()),
		"fertilized": SaveData.encode_cell_ints(_fertilized),
	}


## `data` is this zone's saved farm section. Pre-v2 saves carried "resource_nodes" here (now
## world objects — main.gd hands that part to the Objects node) and stage-only plots, which
## normalize_plot upgrades. A plot sitting on cells that aren't soil any more (the farm layouts
## lost their big pre-tilled fields on 2026-10-07) gets its cell re-tilled so nothing floats.
func load_state(data: Dictionary) -> void:
	for cell in _crop_sprites.keys():
		_clear_crop_sprite(cell, false)
	_plots.clear()
	var decoded := SaveData.decode_plots(data.get("plots", {}))
	for cell in decoded:
		var plot: Dictionary = decoded[cell]
		var crop_def := CropDB.get_crop(String(plot.get("crop_id", "")))
		_plots[cell] = FarmGrid.normalize_plot(plot, crop_def)
		if not is_soil(cell):
			_test_map.force_till(cell)
	for cell in _wet.keys():
		_set_wet(cell, false)
	for cell in SaveData.decode_cells(data.get("wet", [])):
		_set_wet(cell, true)
	_fertilized = SaveData.decode_cell_ints(data.get("fertilized", {}))
	for cell in _plots.keys():
		_refresh_crop_sprite(cell, false)
		plot_changed.emit(cell)
