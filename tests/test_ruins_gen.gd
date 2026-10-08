extends "res://tests/test_case.gd"
## scripts/ruins_gen.gd, the street-grid ruins generator (Milestone C). Every rule its class doc
## promises, over depths 1-4 x many seeds:
##   - deterministic;
##   - legend-only rows and a solid border;
##   - entry, truck and stairs geometry;
##   - footprints never overlap and never sit on solid ground;
##   - building cells are exactly the X cells, with nothing inside their overhang;
##   - every enemy, note, container and breakable is reachable from the entry;
##   - enemies keep their distance from the truck;
##   - counts per depth, and kinds that exist in the world-object and enemy data;
##   - speed.

const RuinsGen := preload("res://scripts/ruins_gen.gd")
const WorldObjectDB := preload("res://scripts/world_object_db.gd")
const EnemyDB := preload("res://scripts/enemy_db.gd")

const SEEDS := 12


func _levels() -> Array:
	var out: Array = []
	for depth in [1, 2, 3, 4]:
		for s in SEEDS:
			out.append(RuinsGen.generate(depth, 1000 + s * 77))
	return out


func test_deterministic() -> void:
	for depth in [1, 3]:
		var a := RuinsGen.generate(depth, 99)
		var b := RuinsGen.generate(depth, 99)
		assert_eq(a["rows"], b["rows"], "same rows (depth %d)" % depth)
		assert_eq(a["enemies"], b["enemies"], "same enemies (depth %d)" % depth)
		assert_eq(a["containers"], b["containers"], "same containers (depth %d)" % depth)
		assert_ne(a["rows"], RuinsGen.generate(depth, 100)["rows"], "another seed, another city")


func test_rows_legend_and_border() -> void:
	for lvl in _levels():
		var size: Vector2i = lvl["size"]
		var rows: Array = lvl["rows"]
		assert_eq(rows.size(), size.y)
		for y in rows.size():
			var row := String(rows[y])
			assert_eq(row.length(), size.x, "row %d width" % y)
			for x in row.length():
				var ch := row[x]
				assert_true(".acr:F#XW".contains(ch), "legend char '%s'" % ch)
				if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
					assert_false(RuinsGen.is_walkable_char(ch), "the border is solid at %d,%d" % [x, y])


func test_entry_truck_and_stairs() -> void:
	for lvl in _levels():
		var rows: Array = lvl["rows"]
		var entry: Vector2i = lvl["entry"]
		var truck: Vector2i = lvl["truck"]
		assert_eq(entry, truck + Vector2i(1, 1), "the player arrives just south of the truck")
		assert_true(RuinsGen.is_walkable_char(String(rows[entry.y])[entry.x]), "the entry is open ground")
		var stairs: Vector2i = lvl["stairs"]
		var dist := RuinsGen.distances(lvl, entry)
		assert_true(dist.has(stairs + Vector2i(0, 2)), "the stairs can be reached")
		assert_true(Vector2(stairs).distance_to(Vector2(entry)) > 12.0, "the stairs are a walk away")


func test_footprints_never_overlap_or_sit_on_solid() -> void:
	for lvl in _levels():
		var rows: Array = lvl["rows"]
		var seen := {}
		var check := func(kind: String, anchor: Vector2i, sz: Vector2i, on_x: bool) -> void:
			for dy in sz.y:
				for dx in sz.x:
					var c := anchor + Vector2i(dx, dy)
					assert_false(seen.has(c), "%s overlaps something at %s" % [kind, c])
					seen[c] = true
					var ch := String(rows[c.y])[c.x]
					if on_x:
						assert_eq(ch, "X", "%s stands on its X cells" % kind)
					else:
						assert_true(RuinsGen.is_walkable_char(ch), "%s stands on open ground at %s ('%s')" % [kind, c, ch])
		check.call("truck", Vector2i(lvl["truck"]), Vector2i(3, 1), false)
		check.call("stairs", Vector2i(lvl["stairs"]), Vector2i(2, 2), false)
		for b in lvl["buildings"]:
			check.call(String(b["kind"]), Vector2i(b["anchor"]), Vector2i(b["size"]), true)
		for p in lvl["props"]:
			check.call(String(p["kind"]), Vector2i(p["anchor"]), WorldObjectDB.size_of(String(p["kind"])), false)
		for c in lvl["containers"]:
			check.call(String(c["kind"]), Vector2i(c["anchor"]), WorldObjectDB.size_of(String(c["kind"])), false)
		for b in lvl["breakables"]:
			check.call(String(b["kind"]), Vector2i(b["anchor"]), WorldObjectDB.size_of(String(b["kind"])), false)
		for r in lvl["rad"]:
			if String(r["kind"]) == "rad_barrel":
				check.call("rad_barrel", Vector2i(r["anchor"]), Vector2i.ONE, false)


func test_buildings_cover_x_and_keep_their_overhang_clear() -> void:
	for lvl in _levels():
		var rows: Array = lvl["rows"]
		var covered := {}
		for b in lvl["buildings"]:
			var a: Vector2i = b["anchor"]
			var sz: Vector2i = b["size"]
			assert_eq(sz, WorldObjectDB.size_of(String(b["kind"])), "%s footprint matches its data" % b["kind"])
			for dy in sz.y:
				for dx in sz.x:
					covered[a + Vector2i(dx, dy)] = true
			# Nothing else may stand inside the sprite's overhang rows.
			for oy in range(1, RuinsGen.building_overhang(String(b["kind"])) + 1):
				for dx in sz.x:
					var c := a + Vector2i(dx, -oy)
					assert_ne(String(rows[c.y])[c.x], "X", "no building inside %s's overhang" % b["kind"])
		for y in rows.size():
			for x in String(rows[y]).length():
				if String(rows[y])[x] == "X":
					assert_true(covered.has(Vector2i(x, y)), "X cell %d,%d belongs to a building" % [x, y])


func test_everything_reachable_and_enemies_keep_away() -> void:
	for lvl in _levels():
		var entry: Vector2i = lvl["entry"]
		var dist := RuinsGen.distances(lvl, entry)
		for e in lvl["enemies"]:
			var c: Vector2i = e["cell"]
			assert_true(dist.has(c), "%s at %s is reachable" % [e["type"], c])
			if dist.has(c):
				assert_true(int(dist[c]) >= RuinsGen.ENEMY_MIN_STEPS, "%s starts %d steps from the truck" % [e["type"], int(dist[c])])
		for n in lvl["notes"]:
			assert_true(dist.has(Vector2i(n)), "note at %s is reachable" % n)
		for group in ["containers", "breakables"]:
			for o in lvl[group]:
				var a: Vector2i = o["anchor"]
				var sz := WorldObjectDB.size_of(String(o["kind"]))
				var ok := false
				for dy in range(-1, sz.y + 1):
					for dx in range(-1, sz.x + 1):
						var edge := (dx == -1 or dx == sz.x) != (dy == -1 or dy == sz.y)
						if edge and dist.has(a + Vector2i(dx, dy)):
							ok = true
				assert_true(ok, "%s at %s has a reachable side" % [o["kind"], a])


func test_counts_and_kinds_per_depth() -> void:
	var ranges := {1: Vector2i(3, 9), 2: Vector2i(5, 13), 3: Vector2i(7, 16), 4: Vector2i(8, 18)}
	for depth in [1, 2, 3, 4]:
		for s in SEEDS:
			var lvl := RuinsGen.generate(depth, 500 + s)
			var n := (lvl["enemies"] as Array).size()
			var r: Vector2i = ranges[depth]
			assert_true(n >= r.x and n <= r.y + 3, "depth %d has %d enemies" % [depth, n])
			assert_true((lvl["containers"] as Array).size() >= 3, "depth %d has loot to search" % depth)
			assert_true((lvl["buildings"] as Array).size() >= 2, "depth %d has buildings" % depth)
			assert_eq(String(lvl["name"]), RuinsGen.name_for_depth(depth))
			for e in lvl["enemies"]:
				assert_true(EnemyDB.has_enemy(String(e["type"])), "enemy %s exists" % e["type"])
				if depth == 1:
					assert_true(["shambler", "runner"].has(String(e["type"])), "depth 1 is shamblers and runners")
			for group in ["buildings", "props", "containers", "breakables"]:
				for o in lvl[group]:
					assert_true(WorldObjectDB.has_kind(String(o["kind"])), "%s kind %s exists" % [group, o["kind"]])
			for c in lvl["containers"]:
				assert_true(int(c["tier"]) >= 1 and int(c["tier"]) <= 4, "tier in range")
			for d in lvl["decor"]:
				assert_true(["remains", "bones", "pavement_decor", "manhole"].has(String(d["kind"])), "decor kind %s" % d["kind"])


func test_raiders_come_in_groups() -> void:
	for s in SEEDS:
		var lvl := RuinsGen.generate(3, 900 + s)
		var groups := {}
		for e in lvl["enemies"]:
			if String(e["type"]) == "raider":
				assert_true(int(e["group"]) >= 0, "raiders belong to a group")
				groups[int(e["group"])] = int(groups.get(int(e["group"]), 0)) + 1
		for g in groups:
			assert_true(int(groups[g]) >= 1 and int(groups[g]) <= 3, "a raider group of %d" % int(groups[g]))


func test_fast_enough() -> void:
	var t0 := Time.get_ticks_msec()
	for i in 5:
		RuinsGen.generate(4, 4000 + i)
	var ms := Time.get_ticks_msec() - t0
	assert_true(ms < 600, "five of the biggest levels in %d ms" % ms)
