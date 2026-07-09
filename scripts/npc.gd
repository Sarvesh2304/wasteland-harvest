extends CharacterBody2D
## NPC base class (ROADMAP.md Phase 5 Stage 1: "name, sprite, position, dialogue data, wanders
## within a defined zone"). Instantiated in code by scripts/npcs.gd from the active layout's
## npcs() data (the same data-driven spawn pattern structures.gd uses for buildings()) — there
## is deliberately no .tscn per NPC, since everything varies per-NPC is 3 data fields.
##
## Name + dialogue data live in data/dialogue.json keyed by npc_id (see dialogue_db.gd).
##
## Wandering: idle a random few seconds, then walk ONE validated cell and idle again — the pure
## zone/step rules live in scripts/npc_grid.gd, whose header documents why this is a grid
## random-walk rather than the checklist parenthetical's NavigationAgent2D (short version: this
## codebase has zero navigation infrastructure, validated single-cell steps can't clip or leave
## the zone by construction, and blocked-cell checks make NPCs respect player-built Phase 4
## structures with no navmesh re-baking). While `talking` (set by dialogue_ui.gd for the length
## of a conversation) the NPC freezes in place, mid-step included.
##
## Collision: layer 1 ("world", like buildings) so the player can't walk through people;
## mask 1|2 (world + player) so a step that runs into the player — or, in the one plaza corner
## where two wander zones overlap, another NPC — bails out early exactly like player.gd's
## _process_step() does, instead of pushing through.
##
## Sprite: a flat-color two-tone placeholder (body + darker head band), matching Phase 4's
## flat-color placeholder buildings — deliberately no PixelLab generation this stage, since
## Phase 6's "Art pass 1" checklist item explicitly covers proper pixel art for these exact
## 3 NPCs; documented here the way structures.gd documents the same call for buildings.
##
## Save/load: NPC state is deliberately not serialised — positions are cosmetic wander noise
## with no gameplay meaning yet (schedules are Phase 7's), so a reload simply respawns each NPC
## at its authored home cell.

const NpcGrid := preload("res://scripts/npc_grid.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")

const CELL_SIZE := 16.0
## Amble, not march: well under the player's 56 px/s so townsfolk read as unhurried.
const WALK_SPEED := 24.0
const IDLE_SECONDS_MIN := 2.0
const IDLE_SECONDS_MAX := 6.0

## Placeholder body fills per npc id — locked GDD.md §9 settlement-anchor hexes. Deliberately
## NOT the same hex as each NPC's associated building (structures.gd's BUILDING_COLORS): an
## early pass echoed Harlan's scavenged-metal house / Marta's dusty-amber store / a leaf-green
## "scout" read directly, which sounded thematic on paper but visually camouflaged every NPC
## against their own building (and, for Kael's leaf green, against the grass) the moment a
## screenshot was actually taken — caught via tools/screenshot_npc_dialogue.gd's first pass.
## These 3 are chosen purely for mutual contrast against grass green and each associated
## building, while staying within the same locked palette: worn wood dark (Harlan — a weathered
## founder read, distinct from his house's grey), lamplight gold (Marta — ties to the plaza's
## lamplight/warmth motif instead of duplicating her store's amber), scavenged metal (Kael — a
## scout's gear-coded neutral gray, now free since Harlan no longer uses it).
const NPC_COLORS := {
	"mayor_harlan": "#7b5025",
	"marta": "#ffc948",
	"scout_kael": "#9d9180",
}
const HEAD_COLOR := Color("#281a0b")  # warm near-black "head" band tops the body read

var npc_id := ""
var home := Vector2i.ZERO
var wander_radius := 2
## Frozen mid-conversation (set via set_talking by scripts/dialogue_ui.gd).
var talking := false

var _test_map: Node2D = null
var _idle_left := 0.0
var _stepping := false
var _step_target := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


## Called by scripts/npcs.gd before add_child (so _ready sees everything set).
func setup(id: String, home_cell: Vector2i, radius: int, test_map: Node2D) -> void:
	npc_id = id
	home = home_cell
	wander_radius = radius
	_test_map = test_map
	name = id


func _ready() -> void:
	collision_layer = 1      # "world" — see project.godot [layer_names]; player bumps into NPCs
	collision_mask = 1 | 2   # world + player: steps stop on contact rather than overlapping
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING  # same top-down mode as player.tscn
	_build_collision_shape()
	_build_placeholder_sprite()
	_idle_left = _rng.randf_range(IDLE_SECONDS_MIN, IDLE_SECONDS_MAX)


func _physics_process(_delta: float) -> void:
	if talking:
		velocity = Vector2.ZERO
		return
	if _stepping:
		_process_step()
		return
	_idle_left -= get_physics_process_delta_time()
	if _idle_left <= 0.0:
		_begin_step()


## Freeze/unfreeze for dialogue. Freezing cancels any in-flight step; the NPC just resumes
## idling wherever it stood (between two adjacent open cells, so never anywhere illegal).
func set_talking(value: bool) -> void:
	talking = value
	if value:
		velocity = Vector2.ZERO
		_stepping = false
		_idle_left = _rng.randf_range(IDLE_SECONDS_MIN, IDLE_SECONDS_MAX)


## Whether this NPC is the interaction target for a facing cell (player.gd's use_tool dispatch).
## Cell equality alone would drop interactions against an NPC caught mid-step between two cells,
## so a near-the-cell-center distance check backs it up — the "resolve against where the thing
## visibly is, not raw tile geometry" convention CLAUDE.md carries over from Blood Fields.
func occupies_cell(cell: Vector2i) -> bool:
	if _test_map.world_to_cell(global_position) == cell:
		return true
	return global_position.distance_to(_test_map.cell_to_world_center(cell)) < CELL_SIZE * 0.75


## Pick a validated one-cell wander step (see class doc / npc_grid.gd). Also schedules the next
## idle window either way, so a boxed-in NPC quietly retries later instead of spinning.
func _begin_step() -> void:
	_idle_left = _rng.randf_range(IDLE_SECONDS_MIN, IDLE_SECONDS_MAX)
	var current: Vector2i = _test_map.world_to_cell(global_position)
	var candidates := NpcGrid.candidate_steps(current, home, wander_radius,
		func(cell: Vector2i) -> bool: return not _test_map.is_blocked_at(cell))
	if candidates.is_empty():
		return
	_step_target = _test_map.cell_to_world_center(candidates[_rng.randi_range(0, candidates.size() - 1)])
	_stepping = true


## One-cell walk toward _step_target, bailing early on any collision (player or another NPC in
## the way) — the same shape as player.gd's _process_step().
func _process_step() -> void:
	var to_target := _step_target - global_position
	if to_target.length() <= 1.0:
		global_position = _step_target
		velocity = Vector2.ZERO
		_stepping = false
		return
	velocity = to_target.normalized() * WALK_SPEED
	move_and_slide()
	if get_slide_collision_count() > 0:
		velocity = Vector2.ZERO
		_stepping = false


func _build_collision_shape() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)  # feet-box, same as player.tscn's
	shape.shape = rect
	shape.position = Vector2(0, 2)
	add_child(shape)


## Two-tone flat-color stand-in (see class doc): a body rect in the NPC's identity color with a
## darker head band, feet at the cell center like the player sprite's offset.
func _build_placeholder_sprite() -> void:
	var body := ColorRect.new()
	body.size = Vector2(10, 13)
	body.position = Vector2(-5, -8)
	body.color = Color(String(NPC_COLORS.get(npc_id, "#8c8478")))
	add_child(body)
	var head := ColorRect.new()
	head.size = Vector2(6, 4)
	head.position = Vector2(-3, -12)
	head.color = HEAD_COLOR
	add_child(head)
