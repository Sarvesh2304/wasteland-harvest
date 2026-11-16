extends SceneTree
## World consistency audit (2026-11-16, after the ranch-entrance playtest bug): boots the real
## game once per starting settlement and, in every zone, checks the world the player actually
## walks (the layout plus everything placed at runtime: buildings, decor props, fixed objects),
## treating trees, rocks and other tool-clearable objects as passable:
##   1. every arrival cell (each zone exit's entry_cell, the farm's spawn, and where Kael's truck
##      drops the player home from the ruins) is walkable;
##   2. every gate can be reached from the zone's arrival cells;
##   3. no open ground is cut off from every arrival (reported as regions, with a sample cell);
##   4. every NPC can be walked up to (its home or a neighbour is reachable);
##   5. every building can be walked up to (some cell beside its footprint is reachable).
## NPCs are ignored as obstacles: they wander and step aside.
## Prints "WORLD AUDIT: all checks passed" and exits 0, or each problem and exits 1.
## Run: godot --headless --path . --audio-driver Dummy --script res://tools/world_audit.gd

const WorldObjectDB := preload("res://scripts/world_object_db.gd")
const SETTLEMENTS: Array[String] = ["open_plains", "forest_edge", "riverside"]
const ZONES: Array[String] = ["farm", "path", "town", "ranch"]
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var game_state: Node
var main: Node = null
var index := 0
var ticks := 0
var problems: Array[String] = []
var checks := 0


func _initialize() -> void:
	game_state = root.get_node("GameState")
	game_state.saves_dir = "user://world_audit_saves"
	game_state.legacy_save_path = "user://world_audit_saves/legacy.json"
	game_state.save_path = "user://world_audit_saves/slot_1.json"
	if "opening_enabled" in game_state:
		game_state.opening_enabled = false
	_boot()


func _boot() -> void:
	game_state.chosen_settlement_id = SETTLEMENTS[index]
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	ticks = 0


func _physics_process(_delta: float) -> bool:
	ticks += 1
	if main == null:
		if ticks >= 3:
			_boot()
		return false
	if ticks < 20:
		return false
	_audit(SETTLEMENTS[index])
	main.queue_free()
	main = null
	ticks = 0
	index += 1
	if index >= SETTLEMENTS.size():
		_finish()
		return true
	return false


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		problems.append(message)


func _audit(settlement: String) -> void:
	for zone_id in ZONES:
		if not main.zones.has(zone_id):
			continue
		var zone: Dictionary = main.zones[zone_id]
		var map: Node2D = zone["map"]
		var layout = map.layout
		var size: Vector2i = layout.size()
		var objects: Node = zone["objects"]
		var where := "%s/%s" % [settlement, zone_id]

		# Self-test hook: WH_AUDIT_BLOCK="zone:x,y" puts one extra obstacle in the world before the
		# flood fill, to prove the checks really fire (e.g. "ranch:17,1" blocks the ranch arrival).
		var fault := Vector2i(-99, -99)
		var fault_env := OS.get_environment("WH_AUDIT_BLOCK")
		if fault_env.begins_with(zone_id + ":"):
			var xy := fault_env.get_slice(":", 1).split(",")
			fault = Vector2i(int(xy[0]), int(xy[1]))

		var blocked := func(c: Vector2i) -> bool:
			if c == fault:
				return true
			if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
				return true
			if map.is_blocked_at(c):
				return true
			if objects.is_solid_at(c):
				var tool := WorldObjectDB.tool_of(String(objects.kind_at(c)))
				return tool == "" or tool == "none"
			return false

		# Arrival cells: every exit in the cluster that targets this zone, plus the farm spawn.
		var arrivals: Array[Vector2i] = []
		for other_id in ZONES:
			if not main.zones.has(other_id):
				continue
			for exit in main.zones[other_id]["map"].layout.zone_exits():
				if String(exit["target_zone"]) == zone_id:
					arrivals.append(Vector2i(exit["entry_cell"]))
		# Coming home from the ruins: Kael's truck drops the player here.
		# (Read through main: preloading expedition.gd here, before the autoloads exist, breaks it.)
		if zone_id == String(main.ExpeditionScript.HOME_TRUCK_ZONE):
			arrivals.append(main.ExpeditionScript.HOME_RETURN_CELL)
		if zone_id == "farm":
			# The new-game spawn: the '@' marker in the farm's ROWS.
			for y in size.y:
				for x in size.x:
					if String(layout.cell(x, y)) == "@":
						arrivals.append(Vector2i(x, y))
		for a in arrivals:
			_check(not blocked.call(a), "%s: arrival cell %s is blocked" % [where, a])

		# Flood fill from every arrival.
		var reach := {}
		var queue: Array[Vector2i] = []
		for a in arrivals:
			if not blocked.call(a) and not reach.has(a):
				reach[a] = true
				queue.append(a)
		while not queue.is_empty():
			var c: Vector2i = queue.pop_back()
			for d in DIRS:
				var n := c + d
				if not reach.has(n) and not blocked.call(n):
					reach[n] = true
					queue.append(n)

		if OS.get_environment("WH_AUDIT_VERBOSE") != "":
			print("AUDIT %s: %d arrivals, %d cells reachable, %d npcs, %d buildings" % [where, arrivals.size(),
				reach.size(), zone["npcs"].npcs().size(), layout.buildings().size()])
		var near_reach := func(c: Vector2i) -> bool:
			if reach.has(c):
				return true
			for d in DIRS:
				if reach.has(c + d):
					return true
			return false

		for g in layout.gate_cells():
			# Only real zone gates (on the edge) must be reachable; inner compound gates are
			# covered by the open-ground check below.
			if g.x == 0 or g.y == 0 or g.x == size.x - 1 or g.y == size.y - 1:
				_check(near_reach.call(g), "%s: gate %s can't be reached from any arrival" % [where, g])

		# Open ground cut off from every arrival, grouped into regions.
		var seen := {}
		for y in size.y:
			for x in size.x:
				var c := Vector2i(x, y)
				if reach.has(c) or seen.has(c) or blocked.call(c):
					continue
				var region: Array[Vector2i] = [c]
				seen[c] = true
				var i := 0
				while i < region.size():
					for d in DIRS:
						var n: Vector2i = region[i] + d
						if not seen.has(n) and not reach.has(n) and not blocked.call(n):
							seen[n] = true
							region.append(n)
					i += 1
				_check(false, "%s: %d open cell(s) can't be reached, e.g. %s" % [where, region.size(), c])

		for npc in zone["npcs"].npcs():
			_check(near_reach.call(Vector2i(npc.home)), "%s: %s (home %s) can't be walked up to"
				% [where, String(npc.npc_id), npc.home])

		for b in layout.buildings():
			var tl: Vector2i = b["top_left"]
			var bs: Vector2i = b["size"]
			var ok := false
			for x in range(tl.x - 1, tl.x + bs.x + 1):
				for y in range(tl.y - 1, tl.y + bs.y + 1):
					var inside := x >= tl.x and x < tl.x + bs.x and y >= tl.y and y < tl.y + bs.y
					if not inside and reach.has(Vector2i(x, y)):
						ok = true
			_check(ok, "%s: building %s at %s can't be walked up to" % [where, String(b.get("id", b["kind"])), tl])


func _finish() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists("world_audit_saves"):
		for f in DirAccess.get_files_at("user://world_audit_saves"):
			DirAccess.remove_absolute("user://world_audit_saves/" + f)
	if problems.is_empty():
		print("WORLD AUDIT: all checks passed (%d checks, %d settlements x %d zones)." % [checks,
			SETTLEMENTS.size(), ZONES.size()])
		quit(0)
	else:
		for p in problems:
			print("WORLD AUDIT FAIL: %s" % p)
		print("WORLD AUDIT: %d of %d checks failed." % [problems.size(), checks])
		quit(1)
