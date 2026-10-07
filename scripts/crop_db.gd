extends RefCounted
## data/crops.json access (v2, 2026-10-07): growth is measured in WATERED DAYS. stage_days[i] is
## how many watered days a plant spends in stage i; a crop shows len(stage_days)+1 sprites
## (stage_0 just planted ... stage_N mature). An entry without stage_days (a pre-v2 data file)
## falls back to its old growth_stages count with one day per stage, so older content still loads.

const PATH := "res://data/crops.json"

static var _crops: Dictionary = {}
static var _seed_to_crop: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var text := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(text)
	_crops = parsed if parsed is Dictionary else {}
	_crops.erase("_comment")
	_seed_to_crop.clear()
	for crop_id in _crops:
		var seed_item := String(_crops[crop_id].get("seed_item", ""))
		if seed_item != "":
			_seed_to_crop[seed_item] = String(crop_id)


static func get_crop(crop_id: String) -> Dictionary:
	_ensure_loaded()
	return _crops.get(crop_id, {})


static func has_crop(crop_id: String) -> bool:
	_ensure_loaded()
	return _crops.has(crop_id)


static func all_crops() -> Dictionary:
	_ensure_loaded()
	return _crops


static func crop_for_seed(seed_item: String) -> String:
	_ensure_loaded()
	return String(_seed_to_crop.get(seed_item, ""))


## Watered days spent in each growth stage (see class doc for the pre-v2 fallback).
static func stage_days_of(crop_def: Dictionary) -> Array:
	var days = crop_def.get("stage_days", null)
	if days is Array and not (days as Array).is_empty():
		return days
	var legacy := maxi(int(crop_def.get("growth_stages", 1)) - 1, 0)
	var out: Array = []
	for i in legacy:
		out.append(1)
	return out


static func stage_days(crop_id: String) -> Array:
	return stage_days_of(get_crop(crop_id))


## Number of distinct sprites/stages, mature stage included.
static func growth_stages(crop_id: String) -> int:
	if not has_crop(crop_id):
		return 1
	return stage_days(crop_id).size() + 1


static func total_days_of(crop_def: Dictionary) -> int:
	var total := 0
	for d in stage_days_of(crop_def):
		total += int(d)
	return total


static func total_days(crop_id: String) -> int:
	return total_days_of(get_crop(crop_id))


## Which stage a plant that has grown `growth` watered days shows.
static func stage_for_growth_of(crop_def: Dictionary, growth: int) -> int:
	var stage := 0
	var acc := 0
	for d in stage_days_of(crop_def):
		acc += int(d)
		if growth >= acc:
			stage += 1
		else:
			break
	return stage


static func stage_for_growth(crop_id: String, growth: int) -> int:
	return stage_for_growth_of(get_crop(crop_id), growth)


## The watered-day count at which `stage` begins (inverse of stage_for_growth, clamped).
static func growth_at_stage_of(crop_def: Dictionary, stage: int) -> int:
	var days := stage_days_of(crop_def)
	var acc := 0
	for i in mini(maxi(stage, 0), days.size()):
		acc += int(days[i])
	return acc


static func growth_at_stage(crop_id: String, stage: int) -> int:
	return growth_at_stage_of(get_crop(crop_id), stage)


static func regrow_days(crop_id: String) -> int:
	return int(get_crop(crop_id).get("regrow_days", 0))


static func seasons_of(crop_def: Dictionary) -> Array:
	var s = crop_def.get("seasons", null)
	return s if s is Array else []


## An empty season list (pre-v2 data) means "grows any time".
static func grows_in_season_of(crop_def: Dictionary, season: String) -> bool:
	var s := seasons_of(crop_def)
	return s.is_empty() or season == "" or s.has(season)


static func grows_in_season(crop_id: String, season: String) -> bool:
	return grows_in_season_of(get_crop(crop_id), season)


## Crops plantable in `season`, in data-file order.
static func crops_for_season(season: String) -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for crop_id in _crops:
		var s := seasons_of(_crops[crop_id])
		if s.has(season):
			out.append(String(crop_id))
	return out


static func stage_texture_path(crop_id: String, stage: int) -> String:
	var dir: String = String(get_crop(crop_id).get("sprite_dir", ""))
	return "%sstage_%d.png" % [dir, stage]


static func dead_texture_path(crop_id: String) -> String:
	var dir: String = String(get_crop(crop_id).get("sprite_dir", ""))
	return "%sstage_dead.png" % dir


static func reload_from_disk() -> void:
	_loaded = false
	_ensure_loaded()
