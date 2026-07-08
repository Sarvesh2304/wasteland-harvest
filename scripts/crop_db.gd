extends RefCounted
## Loader for data/crops.json (ROADMAP Phase 3's 4 post-apoc crops). Same caching approach as
## ItemDB — see that file's header for the rationale. Not a `class_name` global for the same
## reason as ItemDB (see item_db.gd's header) — callers must `const CropDB :=
## preload("res://scripts/crop_db.gd")`.

const PATH := "res://data/crops.json"

static var _crops: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var text := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(text)
	_crops = parsed if parsed is Dictionary else {}
	_crops.erase("_comment")


static func get_crop(crop_id: String) -> Dictionary:
	_ensure_loaded()
	return _crops.get(crop_id, {})


static func has_crop(crop_id: String) -> bool:
	_ensure_loaded()
	return _crops.has(crop_id)


static func all_crops() -> Dictionary:
	_ensure_loaded()
	return _crops


static func growth_stages(crop_id: String) -> int:
	return int(get_crop(crop_id).get("growth_stages", 1))


static func stage_texture_path(crop_id: String, stage: int) -> String:
	var dir: String = String(get_crop(crop_id).get("sprite_dir", ""))
	return "%sstage_%d.png" % [dir, stage]


## Named reload_from_disk (not reload) — Script's built-in reload() would shadow it; see
## ItemDB's identical note.
static func reload_from_disk() -> void:
	_loaded = false
	_ensure_loaded()
