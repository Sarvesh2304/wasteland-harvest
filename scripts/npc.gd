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
## Sprite (Phase 6 "Art pass 1"): a real AnimatedSprite2D driven by per-NPC PixelLab
## SpriteFrames (NPC_FRAMES below) — the same idle_<facing>/walk_<facing> animation-name
## convention scenes/player.tscn + scripts/player.gd established (see player.gd's _play()).
## NPCs never use tools, so there is deliberately no tool_* set (see art/characters/README.md's
## animation-scope note). `facing` is derived from each wander step's direction the way
## player.gd derives it from input; since wander steps are always one cardinal cell
## (npc_grid.gd's candidate_steps), the derivation is exact, never diagonal-ambiguous.
## An npc_id with no NPC_FRAMES entry (a future roster addition whose art doesn't exist yet)
## falls back to Phase 5's flat-color two-tone placeholder rect, so a new NPC is visible and
## testable before its art pass.
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

## Phase 6 Art pass 1: real PixelLab SpriteFrames per npc id (generated through the exact
## pipeline art/characters/README.md documents for the player — 16px character, 24x24 canvas,
## low top-down, 4 directions, idle + walk). Each design keeps its Phase 5 placeholder identity
## color as its dominant costume tone (see NPC_COLORS below) so the mutual-contrast reasoning
## that picked those colors still holds with real art.
const NPC_FRAMES := {
	"mayor_harlan": preload("res://art/characters/mayor_harlan/mayor_harlan_frames.tres"),
	"marta": preload("res://art/characters/marta/marta_frames.tres"),
	"scout_kael": preload("res://art/characters/scout_kael/scout_kael_frames.tres"),
	# Ranch/Sanctuary keeper (MAPS.md §3), same pipeline as the town three (16px char, 24x24
	# canvas, low top-down, 4 directions, idle + walk):
	"rancher_silas": preload("res://art/characters/rancher_silas/rancher_silas_frames.tres"),
}
## Matches player.tscn's Sprite offset: the 24x24 canvas is centered with feet toward the cell
## center, so the sprite rides a little above the feet-box collision shape.
const SPRITE_OFFSET := Vector2(0, -5)

## Placeholder body fills per npc id — locked GDD.md §9 settlement-anchor hexes, kept as the
## fallback for roster ids with no NPC_FRAMES art yet (and as each character's palette anchor:
## real art keeps its placeholder identity color as the dominant costume tone). Deliberately
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
	# Ranch/Sanctuary keeper (MAPS.md §3): rust-red duster — distinct from the town three, and
	# reads against the compound's grass. (He's far south, so overlap with Harlan's brown is moot.)
	"rancher_silas": "#9e4b34",
}
const HEAD_COLOR := Color("#281a0b")  # warm near-black "head" band tops the body read

var npc_id := ""
var home := Vector2i.ZERO
var wander_radius := 2
## Frozen mid-conversation (set via set_talking by scripts/dialogue_ui.gd).
var talking := false
## Which way the NPC faces, driving animation names ("idle_south" etc.) — same convention and
## same retained-when-still rule as player.gd's facing. Updated only when a wander step begins
## (steps are the only thing that moves an NPC), so idling keeps the last walked direction.
var facing := "south"

var _test_map: Node2D = null
var _idle_left := 0.0
var _stepping := false
var _step_target := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
## The real-art sprite (null when this npc_id has no NPC_FRAMES entry and uses the placeholder).
var _sprite: AnimatedSprite2D = null


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
	_build_sprite()
	_idle_left = _rng.randf_range(IDLE_SECONDS_MIN, IDLE_SECONDS_MAX)


func _physics_process(_delta: float) -> void:
	if talking:
		velocity = Vector2.ZERO
		_play("idle")
		return
	if _stepping:
		_process_step()
		return
	_play("idle")
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
	var target_cell: Vector2i = candidates[_rng.randi_range(0, candidates.size() - 1)]
	facing = facing_from_step(target_cell - current, facing)
	_step_target = _test_map.cell_to_world_center(target_cell)
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
	_play("walk")
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


## Real art when this npc_id has a NPC_FRAMES entry; Phase 5's flat-color placeholder otherwise
## (see the class doc's sprite section for why the fallback is kept).
func _build_sprite() -> void:
	if NPC_FRAMES.has(npc_id):
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = NPC_FRAMES[npc_id]
		_sprite.position = SPRITE_OFFSET
		add_child(_sprite)
		_play("idle")
		return
	_build_placeholder_sprite()


## Same animation-selection rule as player.gd's _play(): "<action>_<facing>", switched only when
## it actually changes (so looping animations aren't restarted every physics frame), guarded on
## the animation existing. No-op on the placeholder path (_sprite is null).
func _play(action: String) -> void:
	if _sprite == null:
		return
	var animation := "%s_%s" % [action, facing]
	if _sprite.sprite_frames.has_animation(animation) \
			and (_sprite.animation != animation or not _sprite.is_playing()):
		_sprite.play(animation)


## Pure facing rule for a one-cell cardinal wander step (headless-testable like player.gd's
## facing_from_input, which it mirrors — horizontal wins ties, though npc_grid.gd's cardinal-only
## steps can never actually produce one; Vector2i.ZERO keeps the current facing).
static func facing_from_step(step: Vector2i, current: String) -> String:
	if step == Vector2i.ZERO:
		return current
	if absi(step.x) >= absi(step.y) and step.x != 0:
		return "east" if step.x > 0 else "west"
	return "south" if step.y > 0 else "north"


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
