extends SceneTree
## Compiles every script under res://scripts and res://tests at runtime, after the autoloads
## exist (a script passed straight to --check-only can't see autoload names), and reports any
## that fail. Quick feedback while editing.
## Run: godot --headless --path . --script res://tools/compile_check.gd


func _initialize() -> void:
	var failed: Array[String] = []
	var count := 0
	for dir in ["res://scripts", "res://scripts/map_layouts", "res://tests"]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".gd"):
				continue
			var path: String = dir.path_join(file)
			count += 1
			var script = load(path)
			if script == null or not (script as GDScript).can_instantiate():
				failed.append(path)
	if failed.is_empty():
		print("COMPILE CHECK: %d scripts OK" % count)
		quit(0)
	else:
		for f in failed:
			print("COMPILE CHECK FAIL: " + f)
		quit(1)
