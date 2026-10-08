extends "res://tests/test_case.gd"
## scripts/loot_db.gd + data/loot_tables.json: every table the game rolls exists, every item is
## real, rolls are deterministic and within their ranges, tiers fall back, and deeper loot is
## worth more.

const LootDB := preload("res://scripts/loot_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const EnemyDB := preload("res://scripts/enemy_db.gd")

const CONTAINERS: Array[String] = ["locker", "fridge", "supply_crate", "filing_cabinet", "dumpster", "car_trunk"]


func test_every_rolled_table_exists() -> void:
	for id in CONTAINERS:
		assert_true(LootDB.has_table(id), "container table %s" % id)
	for id in EnemyDB.ids():
		var table := String(EnemyDB.get_enemy(id).get("loot", ""))
		assert_true(LootDB.has_table(table), "enemy %s rolls a real table (%s)" % [id, table])


func test_every_item_is_real_and_ranges_sane() -> void:
	for id in LootDB.table_ids():
		for tier in [1, 2, 3, 4]:
			for e in LootDB.entries_for(id, tier):
				assert_true(ItemDB.has_item(String(e["item"])), "%s: %s exists" % [id, e["item"]])
				assert_true(int(e["weight"]) > 0, "%s: %s has weight" % [id, e["item"]])
				assert_true(int(e["min"]) >= 1 and int(e["max"]) >= int(e["min"]), "%s: %s count range" % [id, e["item"]])


func test_rolls_deterministic_merged_and_in_range() -> void:
	var rng := RandomNumberGenerator.new()
	for id in LootDB.table_ids():
		for tier in [1, 3]:
			rng.seed = 7
			var a := LootDB.roll(id, tier, rng)
			rng.seed = 7
			assert_eq(a, LootDB.roll(id, tier, rng), "%s tier %d is deterministic" % [id, tier])
			var seen := {}
			for drop in a:
				assert_false(seen.has(drop["item_id"]), "%s merges repeats" % id)
				seen[drop["item_id"]] = true
				assert_true(int(drop["count"]) >= 1, "%s count positive" % id)
	assert_eq(LootDB.roll("nope", 1, rng), [], "unknown table rolls nothing")


func test_tier_fallback_and_gating() -> void:
	assert_eq(LootDB.rolls_for("supply_crate", 1), Vector2i(2, 3))
	assert_eq(LootDB.rolls_for("filing_cabinet", 2), Vector2i(1, 2), "tier 2 falls back to tier 1's rolls")
	assert_eq(LootDB.rolls_for("filing_cabinet", 4), Vector2i(2, 3), "tier 4 uses tier 3's")
	var relic_t1 := LootDB.entries_for("supply_crate", 1).any(func(e): return e["item"] == "prewar_relic")
	var relic_t3 := LootDB.entries_for("supply_crate", 3).any(func(e): return e["item"] == "prewar_relic")
	assert_false(relic_t1, "no relics in the outskirts")
	assert_true(relic_t3, "relics turn up deeper in")


func test_deeper_is_richer() -> void:
	for id in CONTAINERS:
		var last := -1.0
		for tier in [1, 2, 3, 4]:
			var ev := LootDB.expected_value(id, tier)
			assert_true(ev >= last, "%s tier %d (%.1f Cr) is worth at least tier %d" % [id, tier, ev, tier - 1])
			last = ev
	assert_true(LootDB.expected_value("supply_crate", 1) > LootDB.expected_value("dumpster", 1),
		"supply crates beat dumpsters")


func test_ammo_is_scarce() -> void:
	# Finished rounds are a small share of what a depth-1 run turns up; components are commoner.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var ammo := 0
	var components := 0
	for i in 400:
		for id in CONTAINERS:
			for drop in LootDB.roll(id, 1, rng):
				var item := String(drop["item_id"])
				if ["pistol_ammo", "rifle_ammo", "shotgun_shells"].has(item):
					ammo += int(drop["count"])
				elif ["brass_casing", "gunpowder", "lead_scrap"].has(item):
					components += int(drop["count"])
	assert_true(components > ammo, "components (%d) outnumber finished rounds (%d)" % [components, ammo])
