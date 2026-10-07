extends RefCounted
## Builds (once per run, then cached) the TileSets the terrain renderer paints with, straight from
## the art/env sheets (docs/ART_STYLE.md §4) — no hand-maintained .tres to drift out of sync with
## the generated art. scripts/ground_rules.gd decides what goes where; scripts/test_map.gd paints.

const TERRAIN_DIR := "res://art/env/terrain/"
const DECOR_DIR := "res://art/env/decor/"
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const TILE := Vector2i(16, 16)

## Overlay sheets: 64x64 edge sheet (16 corner masks) + 64x16 "_full" sheet (4 variants).
const OVERLAYS: Array[String] = ["asphalt", "rubble_ground", "soil", "soil_wet", "water", "dirt",
	"cobble", "concrete", "gravel", "sand"]
## Every overlay TileSet uses these two source ids.
const SOURCE_EDGE := 0
const SOURCE_FULL := 1
const WATER_FRAMES := 4
const WATER_FRAME_SECONDS := 0.3

## Plank TileSet source ids (64x16 sheets of 4 variants each).
const SOURCE_PLANKS_V := 0
const SOURCE_PLANKS_H := 1

static var _overlay_sets := {}
static var _base_set: TileSet = null
static var _plank_set: TileSet = null
static var _decor_set: TileSet = null
static var _decor_ids := {}


## One TileSet per overlay terrain (so each can live on its own stacked layer).
static func overlay_set(terrain: String) -> TileSet:
	if _overlay_sets.has(terrain):
		return _overlay_sets[terrain]
	var ts := _new_set()
	var edge := _atlas(load(TERRAIN_DIR + terrain + ".png"))
	var full := _atlas(load(TERRAIN_DIR + terrain + "_full.png"))
	ts.add_source(edge, SOURCE_EDGE)
	ts.add_source(full, SOURCE_FULL)
	var animated := terrain == "water"
	for mask in range(1, 16):
		var coords := Vector2i(mask % 4, mask / 4)
		edge.create_tile(coords)
		if animated:
			# Frames are whole 64x64 sheets side by side: frame k of tile (c, r) sits at
			# column c + 4k, i.e. three tiles of separation between frames.
			edge.set_tile_animation_separation(coords, Vector2i(3, 0))
			edge.set_tile_animation_frames_count(coords, WATER_FRAMES)
			for f in WATER_FRAMES:
				edge.set_tile_animation_frame_duration(coords, f, WATER_FRAME_SECONDS)
	if animated:
		full.create_tile(Vector2i.ZERO)
		full.set_tile_animation_frames_count(Vector2i.ZERO, WATER_FRAMES)
		for f in WATER_FRAMES:
			full.set_tile_animation_frame_duration(Vector2i.ZERO, f, WATER_FRAME_SECONDS)
	else:
		for i in 4:
			full.create_tile(Vector2i(i, 0))
	_overlay_sets[terrain] = ts
	return ts


## How many "_full" variants a terrain has (animated water has one, whose frames animate).
static func full_variants(terrain: String) -> int:
	return 1 if terrain == "water" else 4


## Seasonal grass base: source id = season index, 8 variants at (0..7, 0).
static func base_set() -> TileSet:
	if _base_set != null:
		return _base_set
	_base_set = _new_set()
	for i in SEASONS.size():
		var src := _atlas(load(TERRAIN_DIR + "grass_" + SEASONS[i] + ".png"))
		_base_set.add_source(src, i)
		for v in 8:
			src.create_tile(Vector2i(v, 0))
	return _base_set


static func season_source(season: String) -> int:
	return maxi(SEASONS.find(season), 0)


static func plank_set() -> TileSet:
	if _plank_set != null:
		return _plank_set
	_plank_set = _new_set()
	for pair in [[SOURCE_PLANKS_V, "planks_v"], [SOURCE_PLANKS_H, "planks_h"]]:
		var src := _atlas(load(TERRAIN_DIR + String(pair[1]) + ".png"))
		_plank_set.add_source(src, int(pair[0]))
		for v in 4:
			src.create_tile(Vector2i(v, 0))
	return _plank_set


## Decor (flowers, tufts, specks, leaves): one single-tile source per art/env/decor PNG.
static func decor_set() -> TileSet:
	if _decor_set != null:
		return _decor_set
	_decor_set = _new_set()
	var files := DirAccess.get_files_at(DECOR_DIR)
	var names: Array[String] = []
	for f in files:
		# Exported builds list "x.png.import"/"x.png.remap" instead of the PNG itself.
		var name := String(f).replace(".import", "").replace(".remap", "")
		if name.ends_with(".png") and not names.has(name.get_basename()):
			names.append(name.get_basename())
	names.sort()
	for i in names.size():
		var src := _atlas(load(DECOR_DIR + names[i] + ".png"))
		_decor_set.add_source(src, i)
		src.create_tile(Vector2i.ZERO)
		_decor_ids[names[i]] = i
	return _decor_set


## Source id of a decor sprite by name (-1 = unknown).
static func decor_source(name: String) -> int:
	decor_set()
	return int(_decor_ids.get(name, -1))


static func _new_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = TILE
	return ts


static func _atlas(texture: Texture2D) -> TileSetAtlasSource:
	var src := TileSetAtlasSource.new()
	src.texture = texture
	src.texture_region_size = TILE
	return src
