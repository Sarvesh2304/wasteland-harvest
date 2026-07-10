extends SceneTree
## Windowed screenshot driver for Phase 6's modal mutual-exclusion fix (scripts/modal_gate.gd —
## NOT headless, the GL renderer must actually draw). Boots scenes/main.tscn on Forest Edge,
## opens Mayor Harlan's dialogue via the real interaction path, then presses "B" (build_toggle)
## through builder.gd's real _unhandled_input — before the fix this silently engaged build mode
## underneath the open dialogue box; after the fix it's refused outright. Saves two viewport
## captures (4x nearest-neighbor upscaled from the native 320x192):
##   1. shot_modal_dialogue_open_4x.png — Harlan's dialogue box open, build preview absent
##   2. shot_modal_build_refused_4x.png — the SAME frame, after "B" was pressed: dialogue box
##      still open, no build preview/label appeared, proving the refusal visually rather than
##      just asserting builder.active == false in a headless check
##
## Run (windowed-game launch has standing approval per CLAUDE.md; this never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_modal_gate.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var test_map: Node
var npcs: Node
var dialogue_ui: Node
var builder: Node2D
var stage := 0
var stage_started_at := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	game_state = root.get_node("GameState")
	day_manager = root.get_node("DayManager")
	game_state.chosen_settlement_id = "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	match stage:
		0:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			test_map = main.get_node("TestMap")
			npcs = test_map.get_node("Npcs")
			dialogue_ui = main.get_node("DialogueUI")
			builder = main.get_node("Builder")
			day_manager.minutes_into_day = 720.0  # noon: unmodulated palette for a clean shot
			day_manager.time_paused = true
			_enter_stage(1)
		1:
			# -- Approach Harlan and open his dialogue via the real interaction path --
			if ticks < 5:
				var harlan: Node = _npc_by_id("mayor_harlan")
				var cell: Vector2i = test_map.world_to_cell(harlan.global_position)
				player.global_position = test_map.cell_to_world_center(cell + Vector2i(0, 1))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks == 5:
				player.use_tool()
				return false
			if ticks >= 45:  # ~0.75s into the typewriter reveal, matching screenshot_npc_dialogue.gd
				_capture("shot_modal_dialogue_open_4x.png")
				_enter_stage(2)
		2:
			# -- Press "B" through builder.gd's real _unhandled_input: must be refused --
			if ticks == 1:
				_drive_builder_action("build_toggle")
				return false
			if ticks >= 20:
				print("builder.active after B mid-dialogue: %s (expected false)" % builder.active)
				print("dialogue_ui.active after B mid-dialogue: %s (expected true)" % dialogue_ui.active)
				_capture("shot_modal_build_refused_4x.png")
				quit(0)
		_:
			pass
	return false


func _npc_by_id(id: String) -> Node:
	for npc in npcs.npcs():
		if String(npc.npc_id) == id:
			return npc
	return null


func _drive_builder_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	builder._unhandled_input(event)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:  # native 320x192 -> 4x for legibility
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
