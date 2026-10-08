extends SceneTree
## Milestone C ruins-levels smoke (2026-10-08): generated levels loaded through the real
## expedition loader, depths 1-4 x a few seeds. For each:
##   - it builds in reasonable time;
##   - the player can stand at the entry;
##   - the truck and stairs exist;
##   - an A* path runs from the entry to the stairs' approach cell;
##   - enemies, containers and breakables spawned as listed;
##   - no enemy starts on a solid cell.
## Run: godot --headless --path . --audio-driver Dummy --script res://tools/ruins_levels_smoke.gd

const SEEDS := [11, 4242, 90210]
const MAX_BUILD_MS := 400.0

var main: Node
var player: Node
var failures: Array[String] = []
var ticks := 0
var _queue: Array = []
var _current: Dictionary = {}
var _report: Array[String] = []


func _initialize() -> void:
	var gs = root.get_node("GameState")
	gs.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	gs.save_path = "user://ruins_levels_smoke_save.json"
	gs.chosen_settlement_id = "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for depth in [1, 2, 3, 4]:
		for s in SEEDS:
			_queue.append({"depth": depth, "seed": s})


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append("depth %d seed %d: %s" % [int(_current.get("depth", 0)), int(_current.get("seed", 0)), message])


func _physics_process(_delta: float) -> bool:
	ticks += 1
	if ticks < 10:
		return false
	if ticks == 10:
		player = main.get_node("Player")
		main.expedition.active = true
	if (ticks - 10) % 4 != 0:
		return false
	if _queue.is_empty():
		_finish()
		return true
	_current = _queue.pop_front()
	_run_one(int(_current["depth"]), int(_current["seed"]))
	return false


func _run_one(depth: int, seed_value: int) -> void:
	var ex: Node = main.expedition
	var t0 := Time.get_ticks_usec()
	var lvl: Dictionary = ex.generate(depth, seed_value)
	var t1 := Time.get_ticks_usec()
	ex.depth = depth
	ex.level = lvl
	ex.populate(lvl)
	main.enter_ruins(Vector2i(lvl["entry"]))
	var t2 := Time.get_ticks_usec()
	var gen_ms := (t1 - t0) / 1000.0
	var build_ms := (t2 - t1) / 1000.0
	_check(gen_ms + build_ms < MAX_BUILD_MS, "generate %.0f ms + build %.0f ms is too slow" % [gen_ms, build_ms])
	var map: Node = main.ruins["map"]
	var objects: Node = main.ruins["objects"]
	var director: Node = main.ruins["enemies"]
	var entry: Vector2i = lvl["entry"]
	_check(not map.layout.is_solid(entry.x, entry.y), "entry cell is open ground")
	_check(not objects.is_solid_at(entry), "nothing solid stands on the entry")
	_check(objects.count_kinds(["kaels_truck"]) == 1, "one truck")
	_check(objects.count_kinds(["subway_stairs"]) == 1, "one set of stairs")
	var stairs: Vector2i = lvl["stairs"]
	var approach := stairs + Vector2i(0, 2)
	var path: PackedVector2Array = director.path_between(map.get_global_cell_center(entry),
		map.get_global_cell_center(approach))
	_check(path.size() >= 2 and path[path.size() - 1].distance_to(map.get_global_cell_center(approach)) < 9.0,
		"a path runs from the entry to the stairs (%d points)" % path.size())
	var expected_enemies := (lvl.get("enemies", []) as Array).size()
	_check(director.live_count() == expected_enemies, "all %d enemies spawned (%d live)" % [expected_enemies, director.live_count()])
	for e in lvl.get("enemies", []):
		var c: Vector2i = e["cell"]
		_check(not map.layout.is_solid(c.x, c.y) and not objects.is_solid_at(c),
			"enemy %s at %s starts on open ground" % [e["type"], c])
	var placed := 0
	for group in ["buildings", "props", "containers", "breakables"]:
		placed += (lvl.get(group, []) as Array).size()
	var rad_barrels := 0
	for r in lvl.get("rad", []):
		if String(r.get("kind", "")) == "rad_barrel":
			rad_barrels += 1
	var total: int = objects.all_objects().size()
	_check(total == placed + rad_barrels + 2, "every object placed (%d of %d)" % [total, placed + rad_barrels + 2])
	_report.append("d%d s%-5d %dx%d gen %5.1fms build %5.1fms  enemies %2d containers %2d objects %3d  %s" % [
		depth, seed_value, int(Vector2i(lvl["size"]).x), int(Vector2i(lvl["size"]).y), gen_ms, build_ms,
		expected_enemies, (lvl.get("containers", []) as Array).size(), total, String(lvl.get("name", ""))])


func _finish() -> void:
	main.expedition.active = false
	for line in _report:
		print(line)
	root.get_node("GameState").delete_save()
	if failures.is_empty():
		print("RUINS LEVELS SMOKE: all checks passed (%d levels)." % _report.size())
		quit(0)
	else:
		for f in failures:
			print("RUINS LEVELS SMOKE FAIL: " + f)
		quit(1)
