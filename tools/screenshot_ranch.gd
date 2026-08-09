extends SceneTree
## Windowed screenshot driver for the MAPS.md §3 Ranch/Sanctuary southern compound (NOT headless —
## the GL renderer must actually draw). Boots scenes/main.tscn on Open Plains (the plainest
## surroundings; the compound is identical across all 3 starts) and saves viewport captures (4x
## nearest-neighbor upscaled from native 320x192) of the finished compound: an overview, the ranch
## house up close (the flat-vs-isometric check that mattered for the town buildings), the
## barn/coop pens with their decorative cows/goats, and finally the keeper NPC Silas's dialogue
## box open (same real-interaction-path pattern as tools/screenshot_npc_dialogue.gd's Harlan shot).
##
## ## Repaired 2026-08-09 (was silently broken since the zone split, found during the ranch
## ## relocation)
##
## Two independent bugs, both introduced when the Ranch became its own zone and neither caught by
## anything (this tool has no assertions — it just saved four screenshots of the wrong place):
##   1. Every waypoint was a PRE-SPLIT ABSOLUTE row number — (17,42), (13,40), (9,43), (24,43) —
##      from the old combined 36x49 map. The Ranch's local frame is 36x18 (max y=17), so all four
##      were off the bottom of the grid. They are now the same cells in the local frame, i.e. the
##      documented (0,-31) shift: (17,11), (13,9), (9,12), (24,12).
##   2. `test_map.cell_to_world_center()` returns ZONE-LOCAL pixels (see test_map.gd's own doc),
##      but the result was assigned to `player.global_position`, and each zone sits at its own
##      position offset under Main — so even a valid cell would have placed the player outside the
##      ranch. Every placement now goes through `main._bind_zone("ranch", cell)`, the same call
##      tools/screenshot_zones.gd uses, which also re-points the player's world refs and the
##      camera clamp at the ranch instead of leaving them bound to the farm.
##
## Run (windowed-game launch has standing approval per CLAUDE.md; never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_ranch.gd
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
	game_state.save_path = "user://screenshot_ranch_save.json"
	game_state.delete_save()
	game_state.chosen_settlement_id = "open_plains"
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
			test_map = main.get_node("RanchMap")  # zone split: the ranch compound is its own zone
			npcs = test_map.get_node("Npcs")
			dialogue_ui = main.get_node("DialogueUI")
			day_manager.minutes_into_day = 720.0  # noon: unmodulated palette for clean shots
			day_manager.time_paused = true
			_enter_stage(1)
		1:
			# -- Overview: stand in the compound yard so house/barn/coop/pens/animals all frame up --
			if ticks < 5:
				_place(Vector2i(17, 11), "south")
				return false
			if ticks >= 20:
				_capture("shot_ranch_overview_4x.png")
				_enter_stage(2)
		2:
			# -- Ranch house up close: the flat-shading / not-isometric read check --
			if ticks < 5:
				_place(Vector2i(13, 9), "north")
				return false
			if ticks >= 20:
				_capture("shot_ranch_house_4x.png")
				_enter_stage(3)
		3:
			# -- Barn + the west cow pen --
			if ticks < 5:
				_place(Vector2i(9, 12), "south")
				return false
			if ticks >= 20:
				_capture("shot_ranch_barn_cows_4x.png")
				_enter_stage(4)
		4:
			# -- Coop + the east mutant-goat pen --
			if ticks < 5:
				_place(Vector2i(24, 12), "south")
				return false
			if ticks >= 20:
				_capture("shot_ranch_coop_goats_4x.png")
				_enter_stage(5)
		5:
			# -- Stand next to Silas and open his dialogue via the real interaction path --
			if ticks < 5:
				var silas: Node = _npc_by_id("rancher_silas")
				# world_to_cell() DOES handle the zone offset (it to_local()s first) — it was only
				# the reverse direction that was broken here. See the class doc.
				var cell: Vector2i = test_map.world_to_cell(silas.global_position)
				_place(cell + Vector2i(0, 1), "north")
				return false
			# NOTE: ticks is never actually 0 on a stage's first call (_enter_stage() runs from the
			# tail of the previous stage's physics frame) — matching screenshot_npc_dialogue.gd's
			# documented convention, so the one-shot action below keys off ticks == 6, not 0 or 1.
			if ticks == 6:
				player.use_tool()
				return false
			if ticks >= 45:  # ~0.75s into the typewriter reveal — legibly mid-type
				_capture("shot_ranch_silas_dialogue_4x.png")
				game_state.delete_save()
				quit(0)
		_:
			pass
	return false


## Ranch-local cell -> the player standing there, facing `facing`. Goes through main._bind_zone
## (rather than writing global_position directly) so the player's world refs and the camera clamp
## follow into the ranch zone too — see the class doc's repair note.
func _place(cell: Vector2i, facing: String) -> void:
	main._bind_zone("ranch", cell)
	player.velocity = Vector2.ZERO
	player.facing = facing


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
