extends "res://tests/test_case.gd"
## scripts/expedition.gd's pure rules (Milestone C): the expedition's loot ledger, what a death
## takes back, the district names, and the built-in fallback level being self-consistent (the
## loop must still work if the generator ever returns nothing).

const Expedition := preload("res://scripts/expedition.gd")
const RuinsLayout := preload("res://scripts/map_layouts/ruins_layout.gd")
const WorldObjectDB := preload("res://scripts/world_object_db.gd")
const EnemyDB := preload("res://scripts/enemy_db.gd")


func test_ledger_records_pickups() -> void:
	var book := {}
	Expedition.record(book, "scrap_metal", 3)
	Expedition.record(book, "scrap_metal", 2)
	Expedition.record(book, "bandage", 1)
	Expedition.record(book, "", 5)
	Expedition.record(book, "glass", 0)
	assert_eq(book, {"scrap_metal": 5, "bandage": 1})
	assert_eq(Expedition.ledger_total(book), 6)


func test_death_takes_back_only_what_was_found_and_still_carried() -> void:
	var book := {"scrap_metal": 5, "pistol_ammo": 6, "copper_wire": 2}
	# Fired 4 of the 6 rounds found; brought 10 scrap from home; dropped the wire somewhere.
	var have := {"scrap_metal": 15, "pistol_ammo": 2, "wood": 20}
	var lost := Expedition.penalty(book, have)
	assert_eq(lost, {"scrap_metal": 5, "pistol_ammo": 2}, "home items and spent items untouched")
	assert_eq(Expedition.penalty({}, have), {}, "an empty ledger costs nothing")


func test_district_names_by_depth() -> void:
	assert_eq(Expedition.district_name(1), "Residential Blocks")
	assert_eq(Expedition.district_name(2), "Downtown Ruins")
	assert_eq(Expedition.district_name(3), "Industrial Quarter")
	assert_eq(Expedition.district_name(9), Expedition.DISTRICT_NAMES[-1], "deeper repeats the last")
	assert_eq(Expedition.district_name(0), "Residential Blocks", "clamped")


func test_fallback_level_is_self_consistent() -> void:
	for depth in [1, 2, 4]:
		var lvl := Expedition.fallback_level(depth)
		var layout = RuinsLayout.new(lvl)
		var size: Vector2i = layout.size()
		assert_eq(size, Vector2i(lvl["size"]), "size matches rows (depth %d)" % depth)
		var entry: Vector2i = lvl["entry"]
		assert_false(layout.is_solid(entry.x, entry.y), "the entry is walkable")
		var truck: Vector2i = lvl["truck"]
		assert_eq(entry, truck + Vector2i(1, 1), "the entry is just south of the truck's middle")
		var stairs: Vector2i = lvl["stairs"]
		assert_false(layout.is_solid(stairs.x, stairs.y + 2), "the stairs can be reached from the south")
		for e in lvl["enemies"]:
			var c: Vector2i = e["cell"]
			assert_false(layout.is_solid(c.x, c.y), "enemy %s spawns on open ground" % e["type"])
			assert_true(EnemyDB.has_enemy(String(e["type"])), "enemy type %s exists" % e["type"])
		for group in ["props", "containers", "breakables"]:
			for o in lvl[group]:
				assert_true(WorldObjectDB.has_kind(String(o["kind"])), "%s kind %s exists" % [group, o["kind"]])


func test_generate_always_returns_a_playable_level() -> void:
	for depth in [1, 2, 3]:
		var lvl := Expedition.generate(depth, 1234)
		assert_false((lvl.get("rows", []) as Array).is_empty(), "depth %d has rows" % depth)
		assert_true(lvl.has("entry") and lvl.has("truck") and lvl.has("stairs"), "depth %d has its anchors" % depth)


func test_ruins_layout_edges_are_solid_and_placeholder_is_walled() -> void:
	var layout = RuinsLayout.new()
	var size: Vector2i = layout.size()
	assert_eq(size, Vector2i(20, 12))
	assert_true(layout.is_solid(-1, 3), "off the map is solid")
	assert_true(layout.is_solid(0, 0), "the placeholder is walled in")
	assert_false(layout.is_solid(5, 5), "and open inside")
	assert_eq(layout.zone_exits(), [], "no gate exits: the truck is the way out")
