extends SceneTree
## Windowed screenshot driver for Phase 6 Art pass 1's NPC art (NOT headless — the GL renderer
## must actually draw). Boots scenes/main.tscn on Forest Edge and saves four viewport captures
## (4x nearest-neighbor upscaled from the native 320x192):
##   1. shot_art_harlan_4x.png — player standing next to Mayor Harlan's new sprite
##   2. shot_art_marta_4x.png  — same for Marta
##   3. shot_art_kael_4x.png   — same for Scout Kael
##   4. shot_art_walk_4x.png   — one NPC captured mid-wander-step, walk animation playing
##      (the capture logs which animation the sprite was playing, proving walk_<facing> ran)
##
## Run (windowed-game launch has standing approval per CLAUDE.md; this never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_npc_art.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var test_map: Node
var npcs: Node
var stage := 0
var stage_started_at := 0
## Stages 1-3 share one body — this walks the roster in order.
var npc_order := ["mayor_harlan", "marta", "scout_kael"]
var walk_npc: Node = null
var walk_step_started := -1


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
			test_map = main.get_node("TownMap")  # zone split: the town-core NPCs live here now
			npcs = test_map.get_node("Npcs")
			day_manager.minutes_into_day = 720.0  # noon: unmodulated palette for a clean shot
			day_manager.time_paused = true
			# Freeze every NPC's wander during the portrait stages so each stands still on its
			# home cell; unfrozen one at a time for the walk shot.
			for npc in npcs.npcs():
				npc.talking = true
			_enter_stage(1)
		1, 2, 3:
			# -- Portrait: stand the player one cell south of the NPC, facing it, settle, snap --
			var id: String = npc_order[stage - 1]
			if ticks < 5:
				var npc: Node = _npc_by_id(id)
				var cell: Vector2i = test_map.world_to_cell(npc.global_position)
				player.global_position = test_map.cell_to_world_center(cell + Vector2i(0, 1))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks >= 30:  # ~0.5s of rendered frames so the camera settles
				_capture("shot_art_%s_4x.png" % id.trim_prefix("mayor_").trim_prefix("scout_"))
				_enter_stage(stage + 1)
		4:
			# -- Mid-walk: unfreeze one NPC, force an immediate wander step, snap mid-stride --
			if ticks == 1:
				walk_npc = _npc_by_id("marta")
				walk_npc.talking = false
			if walk_npc != null and not bool(walk_npc._stepping):
				# Not stepping yet (or a step bailed early on a collision): force a retry now.
				walk_step_started = -1
				walk_npc._idle_left = 0.0
			elif walk_step_started < 0:
				walk_step_started = ticks
			# Snap ~8 physics frames into a surviving step — legibly mid-stride at 24 px/s.
			if walk_step_started >= 0 and ticks - walk_step_started >= 8:
				var sprite: AnimatedSprite2D = walk_npc._sprite
				print("WALK CHECK: marta playing '%s' (facing %s), frame %d" %
					[sprite.animation, walk_npc.facing, sprite.frame])
				_capture("shot_art_walk_4x.png")
				quit(0)
			if ticks > 240:  # ~4s with no surviving step (boxed in?) — bail loudly, don't hang
				print("WALK CHECK: FAILED - marta never completed 8 frames of a wander step")
				quit(1)
		_:
			pass
	return false


func _npc_by_id(id: String) -> Node:
	for npc in npcs.npcs():
		if String(npc.npc_id) == id:
			return npc
	return null


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:  # native 320x192 -> 4x for legibility
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
