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
## Daily schedules (Phase 7 Stage 2): an NPC listed in scripts/npc_schedule.gd's SCHEDULES walks
## to a time-of-day waypoint inside its OWN zone, then ambles around THAT cell instead of its
## home cell until the next waypoint comes due. Everything about it is additive — the pure
## time->cell lookup and the greedy travel step both live in npc_schedule.gd; an NPC with no
## schedule entry (every settler, any future roster addition) runs the identical random-walk code
## it ran before, gated behind one Dictionary lookup in _begin_step().
##
## Save/load: NPC state is still deliberately not serialised — a waypoint is a pure function of
## the clock, so a reload respawns each NPC on its authored home cell and the schedule walks it
## back to wherever the restored time says it should be, with nothing to persist. (Every
## authored schedule's 6:00 AM entry IS the home cell, so a fresh boot doesn't even walk.)

const NpcGrid := preload("res://scripts/npc_grid.gd")
const NpcSchedule := preload("res://scripts/npc_schedule.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")

const CELL_SIZE := 16.0
## Amble, not march: well under the player's 56 px/s so townsfolk read as unhurried.
const WALK_SPEED := 24.0
const IDLE_SECONDS_MIN := 2.0
const IDLE_SECONDS_MAX := 6.0
## Idle between steps while WALKING TO a scheduled waypoint, rather than the 2-6s amble pause:
## someone crossing town to open a shop or take up a watch post reads as purposeful, and at the
## amble pause a 25-cell walk would eat ~2 in-game hours of the window it's walking into. Short
## but non-zero so travel still steps cell-by-cell through the same validated one-cell walk (and
## so a blocked/boxed-in retry doesn't spin every physics frame).
const TRAVEL_IDLE_SECONDS := 0.3

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
	# Milestone B townsfolk (their code-generated art replaces these once it's on disk).
	"brask": "#5d6b3a",
	"wren": "#a5532a",
	"doc_ama": "#e8dcc0",
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
## Cached NpcSchedule.has_schedule(npc_id) — resolved once in setup() so the per-idle-window
## check costs nothing for the unscheduled majority (settlers).
var _scheduled := false
## True while the in-flight step is scheduled travel rather than a wander step.
var _traveling := false
## Flipped whenever a travel step is bounced by a BODY (another NPC or the player) rather than a
## map cell: the retry then leads with the other axis and walks around them. See
## NpcSchedule.next_travel_cell's swap_axis doc for the stall this fixes.
var _travel_swap_axis := false
## Milestone D: where a festival wants this NPC (scripts/festivals.gd sets it for the day);
## NO_GATHER the rest of the time.
const NO_GATHER := Vector2i(-1, -1)
var gather_cell := NO_GATHER
var _rng := RandomNumberGenerator.new()
## The real-art sprite (null when this npc_id has no NPC_FRAMES entry and uses the placeholder).
var _sprite: AnimatedSprite2D = null


## Called by scripts/npcs.gd before add_child (so _ready sees everything set).
func setup(id: String, home_cell: Vector2i, radius: int, test_map: Node2D) -> void:
	npc_id = id
	home = home_cell
	wander_radius = radius
	_test_map = test_map
	_scheduled = NpcSchedule.has_schedule(id)
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
	# get_global_cell_center, not cell_to_world_center: global_position must be compared in the
	# same frame as the cell center now that zones carry position offsets (the zone split).
	return global_position.distance_to(_test_map.get_global_cell_center(cell)) < CELL_SIZE * 0.75


## Pick a validated one-cell step (see class doc / npc_grid.gd). Also schedules the next idle
## window either way, so a boxed-in NPC quietly retries later instead of spinning.
##
## Phase 7 Stage 2: an NPC with a schedule ambles around its CURRENT WAYPOINT rather than its
## home cell, and walks toward that waypoint (npc_schedule.gd's greedy one-cell travel step)
## whenever it's further than wander_radius away — so "arrived" means inside the same 3x3 box the
## wander uses, and an NPC at work keeps ambling instead of standing frozen on one tile. An NPC
## with NO schedule takes the untouched original path below with `center` still being `home`.
func _begin_step() -> void:
	var current: Vector2i = _test_map.world_to_cell(global_position)
	var center := home
	if gather_cell != NO_GATHER:
		# Milestone D: a festival. Everyone walks to their spot in the square and ambles there.
		center = gather_cell
		if not NpcGrid.within_zone(current, center, wander_radius):
			_begin_travel_step(current, center)
			return
	elif _scheduled:
		center = NpcSchedule.current_waypoint(
			NpcSchedule.schedule_for(npc_id), _schedule_minutes())
		if not NpcGrid.within_zone(current, center, wander_radius):
			_begin_travel_step(current, center)
			return
	_idle_left = _rng.randf_range(IDLE_SECONDS_MIN, IDLE_SECONDS_MAX)
	_traveling = false
	var candidates := NpcGrid.candidate_steps(current, center, wander_radius,
		func(cell: Vector2i) -> bool: return not _test_map.is_blocked_at(cell))
	if candidates.is_empty():
		return
	_start_step_to(candidates[_rng.randi_range(0, candidates.size() - 1)], current)


## One cell of scheduled travel toward `target` (Phase 7 Stage 2). Same validated single-cell
## walk as the wander — only the cell CHOICE differs (greedy toward the waypoint instead of a
## random in-zone neighbour), so travel can no more clip terrain or ignore a player-built
## structure than wandering can. A blocked-in NPC stays put and retries after the short travel
## idle.
func _begin_travel_step(current: Vector2i, target: Vector2i) -> void:
	_idle_left = TRAVEL_IDLE_SECONDS
	_traveling = true
	var next_cell := NpcSchedule.next_travel_cell(current, target,
		func(cell: Vector2i) -> bool: return not _test_map.is_blocked_at(cell),
		_travel_swap_axis)
	if next_cell == current:
		return
	_start_step_to(next_cell, current)


## Commit to walking from `current` into the already-validated neighbouring `target_cell`.
func _start_step_to(target_cell: Vector2i, current: Vector2i) -> void:
	facing = facing_from_step(target_cell - current, facing)
	# World-space target: _process_step measures against global_position, so the zone's
	# position offset must be included (the zone split — see occupies_cell's same fix).
	_step_target = _test_map.get_global_cell_center(target_cell)
	_stepping = true


## The clock the schedule is read against (DayManager autoload, minutes-into-day 0..1439).
## Isolated in its own method so a headless test/tool can stub it without a booted autoload.
func _schedule_minutes() -> float:
	return float(DayManager.minutes_into_day)


## One-cell walk toward _step_target, bailing early on any collision (player or another NPC in
## the way) — the same shape as player.gd's _process_step().
func _process_step() -> void:
	var to_target := _step_target - global_position
	if to_target.length() <= 1.0:
		global_position = _step_target
		velocity = Vector2.ZERO
		_stepping = false
		# A step that actually landed clears any detour preference (Phase 7 Stage 2).
		_travel_swap_axis = false
		return
	velocity = to_target.normalized() * WALK_SPEED
	_play("walk")
	move_and_slide()
	if get_slide_collision_count() > 0:
		velocity = Vector2.ZERO
		_stepping = false
		# Bounced off a live body mid-travel: lead with the other axis next time so a scheduled
		# NPC walks around whoever is standing there instead of shoving at them (Phase 7 Stage 2).
		if _traveling:
			_travel_swap_axis = not _travel_swap_axis


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
	var frames := frames_for(npc_id)
	if frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_sprite.position = SPRITE_OFFSET
		add_child(_sprite)
		_play("idle")
		return
	_build_placeholder_sprite()


## -- Milestone B: the "!" over someone waiting on your accepted request --

const QUEST_MARKER_PATH := "res://art/ui/quest_marker.png"
var _quest_marker: Node2D = null


func set_quest_marker(on: bool) -> void:
	if on and _quest_marker == null:
		if ResourceLoader.exists(QUEST_MARKER_PATH):
			var sprite := Sprite2D.new()
			sprite.texture = load(QUEST_MARKER_PATH)
			_quest_marker = sprite
		else:
			var label := Label.new()
			label.text = "!"
			label.add_theme_color_override("font_color", Color("#ffc948"))
			label.position = Vector2(-2, -6)
			_quest_marker = Node2D.new()
			_quest_marker.add_child(label)
		_quest_marker.position = Vector2(0, -27)
		_quest_marker.z_index = 5
		add_child(_quest_marker)
		var bob := create_tween().set_loops()
		bob.tween_property(_quest_marker, "position:y", -29.0, 0.45).set_trans(Tween.TRANS_SINE)
		bob.tween_property(_quest_marker, "position:y", -27.0, 0.45).set_trans(Tween.TRANS_SINE)
	if _quest_marker != null:
		_quest_marker.visible = on


func has_quest_marker() -> bool:
	return _quest_marker != null and _quest_marker.visible


## The NPC's SpriteFrames: the preloaded PixelLab sets, else art/characters/<id>/<id>_frames.tres
## if it exists (Milestone B's code-generated townsfolk follow that convention), else null.
static func frames_for(id: String) -> SpriteFrames:
	if NPC_FRAMES.has(id):
		return NPC_FRAMES[id]
	var path := "res://art/characters/%s/%s_frames.tres" % [id, id]
	if id != "" and ResourceLoader.exists(path):
		return load(path)
	return null


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
