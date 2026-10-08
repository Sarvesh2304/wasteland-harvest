extends RefCounted
## Lore notes (data/lore_notes.json, Milestone C 2026-10-08). Static module: lazy JSON load, pure
## queries. main.gd reads the next unread note when the player uses an Old Note; the expedition
## save section remembers which have been read.

const PATH := "res://data/lore_notes.json"
const MAX_TEXT := 300
const MAX_TITLE := 24

static var _notes: Array = []
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and parsed.get("notes") is Array:
		_notes = parsed["notes"]


static func notes() -> Array:
	_ensure_loaded()
	return _notes


static func note(id: String) -> Dictionary:
	for n in notes():
		if String((n as Dictionary).get("id", "")) == id:
			return n
	return {}


## The first note (in file order) not in `read_ids` whose min_depth <= `max_depth`; {} if none.
static func next_unread(read_ids: Array, max_depth: int) -> Dictionary:
	for n in notes():
		var d: Dictionary = n
		if int(d.get("min_depth", 1)) <= max_depth and not read_ids.has(String(d.get("id", ""))):
			return d
	return {}


static func reload_from_disk() -> void:
	_loaded = false
	_notes = []
	_ensure_loaded()
