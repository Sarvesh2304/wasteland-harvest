extends SceneTree
## Ad-hoc windowed capture to visually verify the new Ranch Store modal (scripts/ranch_store_ui.gd
## / scenes/ranch_store_ui.tscn) actually fits the 320x192 viewport. Bypasses the real "build a
## Barn/Coop first" gate by calling ranch_store_ui.open_ranch() directly — this tool exists only
## to look at the modal, not to prove how a player reaches it (tools/settler_smoke.gd-style
## smokes cover the real path headlessly).
##
## Run: WH_SHOT_DIR=/abs/dir ~/Downloads/Godot.app/Contents/MacOS/Godot --path . \
##   --script res://tools/screenshot_ranch_store.gd

var shot_dir: String = OS.get_environment("WH_SHOT_DIR")
var main: Node
var stage := 0
var stage_started_at := 0


func _initialize() -> void:
	if shot_dir == "":
		shot_dir = "user://"
	root.get_node("GameState").chosen_settlement_id = "forest_edge"
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
			var ranch_store: Node = main.get_node("RanchStoreUI")
			var ranch_npcs: Node = main.zones["ranch"]["npcs"]
			var silas: Node = null
			for npc in ranch_npcs.npcs():
				if String(npc.npc_id) == "rancher_silas":
					silas = npc
					break
			ranch_store.open_ranch(silas)
			print("ranch store active: %s" % ranch_store.active)
			_enter_stage(1)
		1:
			if ticks >= 20:
				_capture("shot_ranch_store_4x.png")
				quit(0)
		_:
			pass
	return false


func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	if image.get_width() < 640:
		image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var path := shot_dir.path_join(file_name)
	var err := image.save_png(path)
	print("SHOT %s -> %s" % [("saved" if err == OK else "FAILED (%d)" % err), path])
