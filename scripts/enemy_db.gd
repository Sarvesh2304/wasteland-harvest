extends RefCounted
## Enemy catalogue (data/enemies.json, Milestone C 2026-10-07). Static module, same shape as
## item_db.gd / recipe_db.gd: lazy JSON load, pure queries. scripts/enemy.gd reads its stats
## from here; scripts/enemies.gd spawns them.

const PATH := "res://data/enemies.json"
const SHEET_DIR := "res://art/characters/enemies/"
## Sheet layout shared by every enemy (tools/art/enemies): 24x24 frames, 4 columns x 14 rows.
const FRAME := 24
const COLUMNS := 4
const ROWS := 14
const ROW_IDLE := 0      # + facing index (S, N, E, W), 2 frames
const ROW_WALK := 4      # + facing index, 4 frames
const ROW_ATTACK := 8    # + facing index, 4 frames: windup, telegraph, strike, recover
const ROW_HURT := 12     # column = facing index
const ROW_DEATH := 13    # 4 frames, the last is the corpse
const FACING_INDEX := {"south": 0, "north": 1, "east": 2, "west": 3}

## Every field an enemy entry may omit, with its default.
const DEFAULTS := {
	"name": "Enemy", "hp": 20, "speed": 14, "chase_speed": 30, "damage": 8, "rads": 0,
	"attack": "melee", "attack_range": 14, "windup": 0.5, "strike": 0.12, "recover": 0.4,
	"cooldown": 0.5, "sight": 90, "hearing": 60, "lose_track": 5.0, "weight": 1.0,
	"stagger": 0.3, "radius": 5, "xp": 5, "loot": "", "splat": "blood", "sounds": {},
}

static var _enemies: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and parsed.get("enemies") is Dictionary:
		_enemies = parsed["enemies"]


static func ids() -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	for id in _enemies:
		out.append(String(id))
	out.sort()
	return out


static func has_enemy(id: String) -> bool:
	_ensure_loaded()
	return _enemies.has(id)


## The full stat block for `id` with defaults filled in ({} for an unknown id).
static func get_enemy(id: String) -> Dictionary:
	_ensure_loaded()
	if not _enemies.has(id):
		return {}
	var out := DEFAULTS.duplicate(true)
	var raw: Dictionary = _enemies[id]
	for key in raw:
		out[key] = raw[key]
	return out


static func sheet_path(id: String) -> String:
	return SHEET_DIR + id + ".png"


## Sound name for an event ("idle", "alert", "hurt", "die", "attack"), "" if none.
static func sound(id: String, event: String) -> String:
	return String((get_enemy(id).get("sounds", {}) as Dictionary).get(event, ""))


## Pure: the sheet frame index (row * COLUMNS + column) for an animation state.
## `anim` is idle/walk/attack/hurt/death; `step` is the frame within it.
static func frame_index(anim: String, facing: String, step: int) -> int:
	var f := int(FACING_INDEX.get(facing, 0))
	match anim:
		"idle":
			return (ROW_IDLE + f) * COLUMNS + posmod(step, 2)
		"walk":
			return (ROW_WALK + f) * COLUMNS + posmod(step, 4)
		"attack":
			return (ROW_ATTACK + f) * COLUMNS + clampi(step, 0, 3)
		"hurt":
			return ROW_HURT * COLUMNS + f
		"death":
			return ROW_DEATH * COLUMNS + clampi(step, 0, 3)
	return 0


## Pure: the 4-way facing for a movement or aim vector (horizontal wins ties).
static func facing_for(v: Vector2, current: String) -> String:
	if v.length_squared() < 0.0001:
		return current
	if absf(v.x) >= absf(v.y):
		return "east" if v.x > 0.0 else "west"
	return "south" if v.y > 0.0 else "north"


static func reload_from_disk() -> void:
	_loaded = false
	_enemies = {}
	_ensure_loaded()
