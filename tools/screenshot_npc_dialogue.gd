extends SceneTree
## Windowed screenshot driver for Phase 5 Stage 1's NPCs + dialogue box (NOT headless — the GL
## renderer must actually draw). Boots scenes/main.tscn on Forest Edge and saves three viewport
## captures (4x nearest-neighbor upscaled from the native 320x192):
##   1. shot_npc_harlan_4x.png       — Mayor Harlan standing near his fortified house, undisturbed
##   2. shot_npc_dialogue_4x.png     — the dialogue box open on Harlan's opening line
##   3. shot_npc_dialogue_choice_4x.png — the box mid-branch, showing both response options with
##      the second one highlighted (proves "basic branching" renders, not just linear text)
##
## Run (windowed-game launch has standing approval per CLAUDE.md; this never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_npc_dialogue.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var test_map: Node
var npcs: Node
var dialogue_ui: Node
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
			day_manager.minutes_into_day = 720.0  # noon: unmodulated palette for a clean shot
			day_manager.time_paused = true
			_enter_stage(1)
		1:
			# -- Stand the player one cell south of Harlan, facing him, undisturbed --
			if ticks < 5:
				var harlan: Node = _npc_by_id("mayor_harlan")
				var cell: Vector2i = test_map.world_to_cell(harlan.global_position)
				player.global_position = test_map.cell_to_world_center(cell + Vector2i(0, 1))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks >= 30:  # ~0.5s of rendered frames so the camera settles
				_capture("shot_npc_harlan_4x.png")
				_enter_stage(2)
		2:
			# -- Open the dialogue box via the real interaction path, capture the opening line --
			# NOTE: ticks is never actually 0 on a stage's first call (_enter_stage() runs from
			# the tail of the PREVIOUS stage's physics frame, one tick before this stage's body
			# first executes) — matching tools/runtime_smoke.gd's documented convention, so the
			# one-shot action below must key off `ticks == 1`, not `ticks == 0`.
			if ticks == 1:
				player.use_tool()
				return false
			if ticks >= 45:  # ~0.75s into the typewriter reveal — legibly mid-type, not just 2-3 chars
				_capture("shot_npc_dialogue_4x.png")
				_enter_stage(3)
		3:
			# -- Advance to the branch point and capture both choices with one highlighted --
			if ticks == 1:
				_drive_dialogue_action("use_tool")  # reveal "greet"
				_drive_dialogue_action("use_tool")  # advance -> founding
				_drive_dialogue_action("use_tool")  # reveal founding
				_drive_dialogue_action("use_tool")  # advance -> offer (the branch)
				_drive_dialogue_action("use_tool")  # reveal the branch prompt
				_drive_dialogue_action("move_down")  # highlight the 2nd option
				return false
			if ticks >= 20:
				_capture("shot_npc_dialogue_choice_4x.png")
				quit(0)
		_:
			pass
	return false


func _npc_by_id(id: String) -> Node:
	for npc in npcs.npcs():
		if String(npc.npc_id) == id:
			return npc
	return null


func _drive_dialogue_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	dialogue_ui._unhandled_input(event)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:  # native 320x192 -> 4x for legibility
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
