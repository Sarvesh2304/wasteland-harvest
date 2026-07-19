extends SceneTree
## Windowed screenshot driver for Phase 5 Stage 2's town store (NOT headless — the GL renderer
## must actually draw). Boots scenes/main.tscn on Forest Edge and saves two viewport captures
## (4x nearest-neighbor upscaled from the native 320x192):
##   1. shot_store_browse_4x.png  — the store open, browsing with some Credits already granted,
##      showing the row list (name + price) and the highlighted item's description + Credits
##      balance all visible at once (ROADMAP's "UI shows name/description/price").
##   2. shot_store_bought_4x.png  — right after a purchase, showing the deducted Credits balance
##      and the "Bought ..." status message.
##
## Run (windowed-game launch has standing approval per CLAUDE.md; this never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_store.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var test_map: Node
var npcs: Node
var dialogue_ui: Node
var store_ui: Node
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
			test_map = main.get_node("TownMap")  # zone split: Marta/the store live in the town zone
			npcs = test_map.get_node("Npcs")
			dialogue_ui = main.get_node("DialogueUI")
			store_ui = main.get_node("StoreUI")
			day_manager.minutes_into_day = 720.0  # noon: unmodulated palette for a clean shot
			day_manager.time_paused = true
			_enter_stage(1)
		1:
			# -- Stand the player one cell from Marta, facing her, then talk her into opening
			#    the store via the real dialogue path (reveal greet -> advance -> reveal
			#    stocktake -> confirm "Let's see what you've got") --
			if ticks < 5:
				var marta: Node = _npc_by_id("marta")
				var cell: Vector2i = test_map.world_to_cell(marta.global_position)
				player.global_position = test_map.cell_to_world_center(cell + Vector2i(0, -1))
				player.velocity = Vector2.ZERO
				player.facing = "south"
				return false
			if ticks == 5:
				player.use_tool()
				_drive_dialogue_action("use_tool")  # reveal "greet"
				_drive_dialogue_action("use_tool")  # advance greet -> stocktake
				_drive_dialogue_action("use_tool")  # reveal stocktake's branch prompt
				_drive_dialogue_action("use_tool")  # confirm "Let's see what you've got" -> store
				return false
			if ticks >= 20:
				# Grant Credits and cycle to a tool row so the screenshot shows a seed, a food
				# item, and a tool all visible in-frame at once, description included.
				player.set_credits(60)
				for i in 6:
					_drive_store_action("move_down")  # lands on the hoe row (index 6)
				_enter_stage(2)
		2:
			if ticks >= 15:  # a few rendered frames so the fresh layout settles
				_capture("shot_store_browse_4x.png")
				_enter_stage(3)
		3:
			# -- Buy the highlighted item (hoe, 24 Cr) and capture the post-purchase state --
			if ticks == 1:
				_drive_store_action("use_tool")
				return false
			if ticks >= 15:
				_capture("shot_store_bought_4x.png")
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


func _drive_store_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	store_ui._unhandled_input(event)


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:  # native 320x192 -> 4x for legibility
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
