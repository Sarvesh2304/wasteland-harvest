extends SceneTree
## Windowed screenshot driver for Phase 7 Stage 2's daily schedules (NOT headless — the GL
## renderer must actually draw). Boots scenes/main.tscn, binds the player into the TOWN zone,
## holds the clock at midday and lets the real scheduled-travel frames run until the named NPCs
## have walked to their MIDDAY waypoints — then captures them standing there, each at a cell that
## is demonstrably not its home cell:
##
##   1. shot_schedule_midday_4x.png — Mayor Harlan at the bulletin board (16,4) and Marta at her
##      store's east counter (20,10) in one frame, with the player standing mid-plaza between
##      them. Their home cells, (10,4) and (17,9), are elsewhere.
##   2. shot_schedule_gate_4x.png   — Scout Kael on his day watch two cells inside the town's
##      west gate (3,3), a 25-cell walk from his home cell (18,13) on the southern plaza edge.
##
## Each capture prints the NPC cells it actually photographed, so the shot and the log can be
## cross-checked against each other rather than either being taken on trust.
##
## ## Capturing on frame_post_draw, not inline (learned here, the hard way)
##
## The other screenshot tools in this folder grab root.get_texture().get_image() inline and quit
## immediately, which works when a tool takes exactly one shot. Taking TWO shots from different
## vantages inline does not: the second capture came back byte-identical to the first (caught by
## md5-ing the PNGs — the log lines looked perfectly fine), and stayed identical through a 10s
## settle, because the window's viewport texture read outside a draw callback can hand back a
## frame that is not the one currently on screen. Requesting the capture and taking it inside
## RenderingServer.frame_post_draw guarantees the pixels belong to a frame that was actually just
## drawn. Any future multi-shot tool here should do the same.
##
## Clock convention (same as tools/npc_schedule_smoke.gd): scripts/main.gd's _process re-derives
## DayManager.time_paused from the modal gate every frame, so a one-off time_paused = true gets
## overwritten; this tool re-teleports minutes_into_day each tick instead to hold midday steady.
##
## Run (windowed-game launch has standing approval per CLAUDE.md; this never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_npc_schedule.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done.

const NpcSchedule := preload("res://scripts/npc_schedule.gd")
const NpcGrid := preload("res://scripts/npc_grid.gd")

const NOON := 12 * 60
## Mid-plaza vantage: the 20x12-cell viewport centred here covers both the bulletin board (16,4)
## and the store counter (20,10).
const PLAZA_VIEW_CELL := Vector2i(18, 7)
## Just east of Kael's watch post, so the west gate, Kael and the player all frame together.
const GATE_VIEW_CELL := Vector2i(5, 4)
const MAX_TICKS_PER_STAGE := 5400
## Photogenic arrival: hold out for the NPC standing EXACTLY on its waypoint cell (it ambles
## through that cell every few idle windows once it has arrived), so the shot can't be argued
## with. After this many ticks, settle for anywhere inside the waypoint's wander box — which is
## all npc.gd itself promises — rather than never capturing at all.
const EXACT_CELL_PATIENCE := 2400
## Physics ticks between freezing the subjects and requesting the capture, so the camera has
## finished easing onto the new vantage.
const SETTLE_TICKS := 120

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var town_map: Node2D
var stage := 0
var stage_started_at := 0
## Tick the current stage's settle started on (-1 until the subject has arrived and frozen).
var _settle_from := -1
## File name requested for the next frame_post_draw capture ("" when none is pending).
var _pending_shot := ""
## Set by the draw callback once the requested file has been written.
var _shot_done := false


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	game_state = root.get_node("GameState")
	game_state.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	day_manager = root.get_node("DayManager")
	game_state.chosen_settlement_id = "open_plains"
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()
	_settle_from = -1
	_shot_done = false


func _npc(npc_id: String) -> Node:
	for npc in main.zones["town"]["npcs"].npcs():
		if String(npc.npc_id) == npc_id:
			return npc
	return null


func _cell_of(npc: Node) -> Vector2i:
	return town_map.world_to_cell(npc.global_position)


## See EXACT_CELL_PATIENCE above for the exact-cell-then-settle rule.
func _arrived(npc_id: String, ticks: int) -> bool:
	var npc: Node = _npc(npc_id)
	if npc == null:
		return false
	var waypoint := NpcSchedule.current_waypoint(
		NpcSchedule.schedule_for(npc_id), float(NOON))
	if _cell_of(npc) == waypoint and not bool(npc._stepping):
		return true
	if ticks < EXACT_CELL_PATIENCE:
		return false
	return NpcGrid.within_zone(_cell_of(npc), waypoint, int(npc.wander_radius))


func _park_player(cell: Vector2i) -> void:
	player.global_position = town_map.get_global_cell_center(cell)
	player.velocity = Vector2.ZERO
	player.facing = "south"


## Freeze-then-settle-then-capture, shared by both shots: the subjects are held still with the
## same set_talking() hook dialogue uses (so a long settle can't let them amble back off the
## waypoint), the camera is given SETTLE_TICKS to ease onto the vantage, and the capture itself
## happens on the next drawn frame. Returns true once the PNG is on disk.
func _shoot_when_ready(subjects: Array, file_name: String, ticks: int) -> bool:
	if _shot_done:
		return true
	if _settle_from < 0:
		for npc_id in subjects:
			if not _arrived(String(npc_id), ticks):
				return false
		for npc_id in subjects:
			_npc(String(npc_id)).set_talking(true)
		_settle_from = ticks
	if ticks - _settle_from < SETTLE_TICKS:
		return false
	if _pending_shot == "":
		var where := ""
		for npc_id in subjects:
			var npc: Node = _npc(String(npc_id))
			where += " %s at %s (home %s);" % [npc_id, _cell_of(npc), npc.home]
		print("SHOOTING %s —%s" % [file_name, where])
		_pending_shot = file_name
	return false


func _physics_process(_delta: float) -> bool:
	day_manager.minutes_into_day = float(NOON)  # hold midday (see the class doc)
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	if ticks > MAX_TICKS_PER_STAGE:
		print("SHOT FAILED: stage %d never completed" % stage)
		quit(1)
		return true
	match stage:
		0:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			main._bind_zone("town", PLAZA_VIEW_CELL)
			town_map = main.zones["town"]["map"]
			_enter_stage(1)
		1:
			# -- Harlan at the notice board and Marta at her counter, one frame --
			_park_player(PLAZA_VIEW_CELL)
			if _shoot_when_ready(["mayor_harlan", "marta"], "shot_schedule_midday_4x.png", ticks):
				_enter_stage(2)
		2:
			# -- Kael's 25-cell walk to the west gate watch post --
			_park_player(GATE_VIEW_CELL)
			if _shoot_when_ready(["scout_kael"], "shot_schedule_gate_4x.png", ticks):
				quit(0)
		_:
			pass
	return false


## The only place pixels are read: inside the draw callback, so the image is the frame that was
## just rendered rather than whatever the viewport texture happened to be holding.
func _on_frame_post_draw() -> void:
	if _pending_shot == "":
		return
	var file_name := _pending_shot
	_pending_shot = ""
	var image := root.get_texture().get_image()
	if image.get_width() < 640:  # native 320x192 -> 4x for legibility
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
	_shot_done = true
