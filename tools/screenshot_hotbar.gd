extends SceneTree
## Windowed screenshot driver for the 2026-08-09 HUD polish's hotbar item labels (NOT headless —
## the GL renderer must actually draw). Boots scenes/main.tscn on Forest Edge at noon (the
## unmodulated point of the sky gradient, so the shot shows the slots' true palette), fills all
## 9 hotbar slots with a deliberate mix, and saves two captures:
##   1. shot_hotbar_labels_4x.png — the whole 320x192 frame at 4x, for context.
##   2. shot_hotbar_labels_crop8x.png — just the hotbar strip at 8x, the only magnification at
##      which a 3-character 8px tag inside a 14px slot can honestly be judged.
##
## What it's proving: every slot below now draws data/items.json's `placeholder_label` (the
## field that file's own header has always described as "drawn in-engine by hud.gd", but which
## no code read until this session) along the slot's top edge, while the pre-existing
## durability/count badge keeps the bottom-right corner. The mix is chosen so both coexisting
## cases are on screen at once: 5 tools (durability numbers) and stacked seeds/resources (count
## numbers), all of them icon-less and therefore tag-bearing.
##
## Run (windowed-game launch has standing approval per CLAUDE.md; this never opens the editor):
##   WH_SHOT_DIR=/abs/output/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##     --script res://tools/screenshot_hotbar.gd
## Falls back to user:// when WH_SHOT_DIR is unset. Quits by itself when done.

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
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
			day_manager.minutes_into_day = 720.0  # noon: unmodulated palette for a clean shot
			day_manager.time_paused = true
			# Stand on open grass near the farmhouse so nothing overlaps the bottom strip.
			player.global_position = main.get_node("FarmMap").cell_to_world_center(Vector2i(17, 7))
			player.velocity = Vector2.ZERO
			player.facing = "south"
			# The starting loadout already fills slots 0-4 with the 5 tools (durability badges).
			# Top the row up with stacking goods so the count badge shares slots with a tag too.
			player.inventory.add_item("seed_mutant_potato", 12)
			player.inventory.add_item("seed_dustwheat", 3)
			player.inventory.add_item("wood", 24)
			player.inventory.add_item("scrap_metal", 7)
			player.inventory.select_hotbar(0)
			_enter_stage(1)
		1:
			if ticks >= 30:  # ~0.5s of rendered frames so the slots have painted
				_capture("shot_hotbar_labels_4x.png", 4, Rect2i())
				# The hotbar sits bottom-center: 9 slots of 14px + gaps, ~142px wide, in the
				# bottom 20px of the native 320x192 frame.
				_capture("shot_hotbar_labels_crop8x.png", 8, Rect2i(84, 168, 152, 24))
				quit(0)
		_:
			pass
	return false


## Saves the viewport, optionally cropped to a NATIVE-resolution rect first, upscaled by an
## integer nearest-neighbor factor (the project's standing pixel-art screenshot convention —
## any fractional scale turns the pixel font to mush; see art/ui/README.md).
func _capture(file_name: String, scale: int, crop: Rect2i) -> void:
	var image := root.get_texture().get_image()
	if crop.size != Vector2i.ZERO:
		image = image.get_region(crop)
	image.resize(image.get_width() * scale, image.get_height() * scale,
		Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
