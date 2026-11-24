extends "res://tests/test_case.gd"
## Fishing (docs/FISHING.md): data/fish.json + scripts/fish_db.gd — eligibility, the weighted
## pick (junk, the legendary), bite timing, the reel's physics, and the wiring into items,
## recipes, requests, the market, gifts and the harvest show.

const FishDB := preload("res://scripts/fish_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const RecipeDB := preload("res://scripts/recipe_db.gd")
const QuestDB := preload("res://scripts/quest_db.gd")
const MarketRules := preload("res://scripts/market_rules.gd")
const GiftDB := preload("res://scripts/gift_db.gd")
const FestivalDB := preload("res://scripts/festival_db.gd")
const ShopDB := preload("res://scripts/shop_db.gd")
const Skills := preload("res://scripts/skills.gd")
const TestMapScript := preload("res://scripts/test_map.gd")
const SettlementDB := preload("res://scripts/settlement_db.gd")

const MORNING := 8 * 60.0
const AFTERNOON := 14 * 60.0
const EVENING := 19 * 60.0
const NIGHT := 23 * 60.0


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


## -- Data --

func test_the_thirteen_fish_match_the_spec_and_the_items() -> void:
	FishDB.reload_from_disk()
	var ids := FishDB.ids()
	assert_eq(ids.size(), 13, "thirteen species")
	for id in ids:
		var f := FishDB.fish(id)
		assert_true(ItemDB.has_item(id), "%s is an item" % id)
		assert_eq(ItemDB.item_type(id), "fish", "%s has type fish" % id)
		assert_eq(ItemDB.display_name(id), String(f["name"]), "%s: same name in both files" % id)
		assert_eq(ItemDB.sell_value(id), int(f["value"]), "%s: same value in both files" % id)
		assert_true(ItemDB.is_shippable(id), "%s ships" % id)
		assert_true(GiftDB.is_giftable(id), "%s can be given" % id)
		assert_eq(FestivalDB.show_kind(id), "fish", "%s is shown as a fish" % id)
		var d := int(f["difficulty"])
		assert_true(d >= 1 and d <= 5, "%s difficulty 1-5" % id)
		for w in f["waters"]:
			assert_true(FishDB.WATERS.has(String(w)), "%s lives in real water (%s)" % [id, w])
		for s in f["seasons"]:
			assert_true(FishDB.SEASONS.has(String(s)), "%s: real season" % id)
		for t in f["times"]:
			assert_true(FishDB.TIMES.has(String(t)), "%s: real time band" % id)
	assert_eq(ItemDB.sell_value("old_mayor"), 1500)
	assert_eq(FishDB.difficulty("old_mayor"), 5)
	assert_true(FishDB.is_legendary("old_mayor"))
	for j in FishDB.junk_list():
		assert_true(ItemDB.has_item(String(j["item"])), "junk gives a real item (%s)" % j["item"])


func test_time_bands() -> void:
	assert_eq(FishDB.time_band(6 * 60.0), "morning")
	assert_eq(FishDB.time_band(10 * 60.0 + 59.0), "morning")
	assert_eq(FishDB.time_band(11 * 60.0), "day")
	assert_eq(FishDB.time_band(17 * 60.0), "evening")
	assert_eq(FishDB.time_band(21 * 60.0), "night")
	assert_eq(FishDB.time_band(1 * 60.0), "night", "night runs past midnight to 2 AM")
	assert_eq(FishDB.time_band(3 * 60.0), "", "nothing in the small hours")


## -- Eligibility --

func test_eligibility_by_water_season_time_and_weather() -> void:
	var spring_pond := FishDB.eligible("pond", "spring", MORNING, "clear")
	assert_true(spring_pond.has("mud_minnow") and spring_pond.has("rustgill_carp") and spring_pond.has("shellback_crawdad"))
	assert_false(spring_pond.has("sun_perch"), "sun perch is summer only")
	assert_false(spring_pond.has("silver_dace"), "no dace in the pond")
	assert_false(spring_pond.has("sludge_catfish"), "the catfish wants rain")
	assert_false(spring_pond.has("bog_eel"), "eels come out at evening and night")
	assert_true(FishDB.eligible("pond", "spring", MORNING, "rain").has("sludge_catfish"))
	assert_true(FishDB.eligible("pond", "spring", MORNING, "storm").has("sludge_catfish"), "a storm counts as rain")
	assert_true(FishDB.eligible("pond", "spring", EVENING, "clear").has("bog_eel"))
	assert_true(FishDB.eligible("pond", "summer", AFTERNOON, "clear").has("sun_perch"))
	assert_false(FishDB.eligible("pond", "summer", MORNING, "clear").has("sun_perch"), "sun perch bites in the day")
	assert_true(FishDB.eligible("river", "spring", MORNING, "clear").has("silver_dace"))
	assert_true(FishDB.eligible("creek", "autumn", EVENING, "clear").has("ash_trout"))
	assert_false(FishDB.eligible("creek", "autumn", AFTERNOON, "clear").has("ash_trout"))
	assert_true(FishDB.eligible("river", "winter", AFTERNOON, "snow").has("iron_pike"))
	assert_false(FishDB.eligible("creek", "winter", AFTERNOON, "clear").has("iron_pike"), "pike are river fish")
	assert_true(FishDB.eligible("creek", "winter", AFTERNOON, "clear").has("frostfin"))
	assert_false(FishDB.eligible("creek", "autumn", AFTERNOON, "clear").has("frostfin"))
	assert_true(FishDB.eligible("river", "summer", NIGHT, "clear").has("glowfin"))
	assert_false(FishDB.eligible("river", "summer", EVENING, "clear").has("glowfin"))
	assert_true(FishDB.eligible("pond", "winter", MORNING, "clear").has("two_headed_perch"))
	assert_eq(FishDB.eligible("", "spring", MORNING, "clear").size(), 0, "dead water holds nothing")
	assert_eq(FishDB.eligible("pond", "spring", 3 * 60.0, "clear").filter(func(id): return FishDB.fish(id)["times"].size() > 0).size(), 0,
		"no time-limited fish in the small hours")


func test_every_water_has_fish_every_season() -> void:
	for water in FishDB.WATERS:
		for season in FishDB.SEASONS:
			for minutes in [MORNING, AFTERNOON, EVENING, NIGHT]:
				assert_true(FishDB.eligible(water, season, minutes, "clear").has("mud_minnow"),
					"something always bites in the %s (%s %d)" % [water, season, int(minutes)])


## -- The legendary --

func test_the_old_mayor_bites_only_in_autumn_rain_evenings_at_the_pond() -> void:
	assert_true(FishDB.eligible("pond", "autumn", EVENING, "rain").has("old_mayor"))
	assert_false(FishDB.eligible("pond", "autumn", EVENING, "clear").has("old_mayor"), "not without rain")
	assert_false(FishDB.eligible("pond", "autumn", AFTERNOON, "rain").has("old_mayor"), "not in the day")
	assert_false(FishDB.eligible("pond", "summer", EVENING, "rain").has("old_mayor"), "not in summer")
	assert_false(FishDB.eligible("river", "autumn", EVENING, "rain").has("old_mayor"), "not in the river")
	assert_eq(FishDB.weight(FishDB.fish("old_mayor"), "rain"), 0.0, "never in the weighted pick")


func test_the_old_mayor_takes_about_five_percent_of_eligible_bites_once() -> void:
	var r := _rng(7)
	var n := 4000
	var mayor := 0
	var junk := 0
	for i in n:
		var p := FishDB.pick("pond", "autumn", EVENING, "rain", r, false)
		if String(p.get("kind", "")) == "junk":
			junk += 1
		elif String(p.get("id", "")) == "old_mayor":
			mayor += 1
	var share := float(mayor) / float(n - junk)
	assert_true(share > 0.03 and share < 0.07, "about 5%% of fish bites (%.3f)" % share)
	for i in 2000:
		assert_ne(String(FishDB.pick("pond", "autumn", EVENING, "rain", r, true).get("id", "")), "old_mayor",
			"once caught, never again")
	for i in 2000:
		assert_ne(String(FishDB.pick("pond", "autumn", EVENING, "clear", r, false).get("id", "")), "old_mayor",
			"never outside his conditions")


## -- The weighted pick --

func test_junk_is_about_one_bite_in_ten() -> void:
	var r := _rng(11)
	var junk := 0
	var n := 5000
	for i in n:
		var p := FishDB.pick("river", "spring", MORNING, "clear", r)
		if String(p["kind"]) == "junk":
			junk += 1
			assert_true(ItemDB.has_item(String(p["item"])) and int(p["count"]) >= 1 and String(p["line"]) != "")
	var share := float(junk) / float(n)
	assert_true(share > 0.08 and share < 0.12, "about 10%% junk (%.3f)" % share)


func test_pick_follows_the_weights() -> void:
	var r := _rng(3)
	var counts := {}
	var n := 20000
	for i in n:
		var p := FishDB.pick("pond", "winter", MORNING, "clear", r)
		if String(p["kind"]) == "fish":
			counts[p["id"]] = int(counts.get(p["id"], 0)) + 1
	# Winter pond, a clear morning: minnow 30, frostfin 14, two-headed perch 2.
	var total := 0
	for id in counts:
		total += int(counts[id])
	assert_eq(counts.keys().size(), 3, "only the three that can bite (%s)" % [counts])
	var minnow := float(counts.get("mud_minnow", 0)) / float(total)
	var perch := float(counts.get("two_headed_perch", 0)) / float(total)
	assert_true(absf(minnow - 30.0 / 46.0) < 0.03, "minnows ~65%% (%.3f)" % minnow)
	assert_true(absf(perch - 2.0 / 46.0) < 0.015, "two-headed perch ~4%% (%.3f)" % perch)


func test_rain_doubles_the_eel() -> void:
	var eel := FishDB.fish("bog_eel")
	assert_eq(FishDB.weight(eel, "clear"), 8.0)
	assert_eq(FishDB.weight(eel, "rain"), 16.0)
	assert_eq(FishDB.weight(FishDB.fish("mud_minnow"), "rain"), 30.0, "others unchanged")


func test_pick_is_empty_where_nothing_lives() -> void:
	assert_true(FishDB.pick("", "spring", MORNING, "clear", _rng(1)).is_empty())


func test_request_pool_is_common_in_season_fish() -> void:
	var spring := FishDB.request_pool("spring")
	assert_true(spring.has("mud_minnow") and spring.has("rustgill_carp") and spring.has("silver_dace"))
	for season in FishDB.SEASONS:
		var pool := FishDB.request_pool(season)
		assert_false(pool.is_empty(), "%s has fish to ask for" % season)
		for id in pool:
			assert_false(FishDB.is_legendary(id), "never the Old Mayor")
			assert_false(["two_headed_perch", "iron_pike", "glowfin", "sludge_catfish"].has(id), "never a rare one (%s)" % id)
		assert_eq(QuestDB.pool_items("fish", season), pool, "the board's fish pool is the request pool")
	assert_true(MarketRules.DEMAND_POOLS.has("fish"), "Marta can be short of fish")
	assert_true(MarketRules.demand_pool("summer").has("rustgill_carp"))


## -- Casting and the bite --

func test_cast_distance_by_power() -> void:
	assert_eq(FishDB.cast_cells(0.0), 1)
	assert_eq(FishDB.cast_cells(0.3), 2)
	assert_eq(FishDB.cast_cells(0.6), 3)
	assert_eq(FishDB.cast_cells(1.0), 4)
	assert_eq(FishDB.cast_cells(5.0), 4, "clamped")


func test_bite_timing() -> void:
	var r := _rng(5)
	for i in 500:
		var d := FishDB.bite_delay(r, "clear", AFTERNOON)
		assert_true(d >= 1.5 and d <= 6.0, "1.5-6 s (%.2f)" % d)
	assert_eq(FishDB.bite_multiplier("clear", AFTERNOON), 1.0)
	assert_true(is_equal_approx(FishDB.bite_multiplier("rain", AFTERNOON), 0.7), "rain x0.7")
	assert_true(is_equal_approx(FishDB.bite_multiplier("storm", AFTERNOON), 0.7), "storm counts as rain")
	assert_true(is_equal_approx(FishDB.bite_multiplier("clear", 7 * 60.0), 0.8), "dawn x0.8")
	assert_true(is_equal_approx(FishDB.bite_multiplier("clear", 19 * 60.0), 0.8), "dusk x0.8")
	assert_true(is_equal_approx(FishDB.bite_multiplier("rain", 19 * 60.0), 0.56), "both")
	for i in 500:
		var d := FishDB.bite_delay(r, "rain", 19 * 60.0)
		assert_true(d >= 1.5 * 0.56 - 0.001 and d <= 6.0 * 0.56 + 0.001, "rainy dusk is faster (%.2f)" % d)


func test_nibbles_come_before_the_bite() -> void:
	var r := _rng(9)
	for i in 300:
		var bite := r.randf_range(1.5, 6.0)
		var times := FishDB.nibble_times(r, bite)
		assert_true(times.size() <= 2, "at most two nibbles")
		for t in times:
			assert_true(t > 0.0 and t < bite - 0.5, "a nibble well before the bite")
	assert_eq(FishDB.HOOK_WINDOW, 0.75)


## -- The reel --

func test_sweet_spot_width_by_difficulty_and_foraging() -> void:
	assert_true(is_equal_approx(FishDB.sweet_width(1), 0.35), "35% at difficulty 1")
	assert_true(is_equal_approx(FishDB.sweet_width(5), 0.18), "18% at difficulty 5")
	assert_true(FishDB.sweet_width(2) < FishDB.sweet_width(1) and FishDB.sweet_width(4) > FishDB.sweet_width(5), "narrows with difficulty")
	assert_true(is_equal_approx(FishDB.sweet_width(5, 4), 0.22), "each Foraging level widens it 1%")
	assert_true(is_equal_approx(FishDB.sweet_width(3, 10), FishDB.sweet_width(3) + 0.1))
	var hard := FishDB.reel_params(5)
	var easy := FishDB.reel_params(1)
	assert_true(float(hard["force"]) > float(easy["force"]), "harder fish pull harder")
	assert_true(float(hard["rest_max"]) < float(easy["rest_max"]), "and run more often")


func _fight(diff: int, policy: Callable, seed_value: int, level: int = 0) -> Dictionary:
	var r := _rng(seed_value)
	var params := FishDB.reel_params(diff, level)
	var s := FishDB.reel_start(params, r)
	for i in 60 * 60:
		s = FishDB.reel_step(s, params, bool(policy.call(s, params)), 1.0 / 60.0, r)
		if String(s["result"]) != "":
			return s
	return s


func test_holding_on_snaps_the_line() -> void:
	for d in range(1, 6):
		var s := _fight(d, func(_s, _p): return true, d)
		assert_eq(String(s["result"]), "snap", "difficulty %d: never easing off snaps it" % d)
		assert_eq(float(s["tension"]), 1.0)


func test_never_reeling_lets_it_escape() -> void:
	for d in range(1, 6):
		assert_eq(String(_fight(d, func(_s, _p): return false, d)["result"]), "escape",
			"difficulty %d: slack line, the fish works loose" % d)


func test_a_careful_angler_lands_every_difficulty() -> void:
	var careful := func(s: Dictionary, p: Dictionary) -> bool:
		if String(s["phase"]) != "rest":
			return false  # ease off when it tenses and runs
		var band := FishDB.sweet_spot(p, float(s["t"]))
		return float(s["tension"]) < (band.x + band.y) * 0.5
	for d in range(1, 6):
		var landed := 0
		for k in 20:
			if String(_fight(d, careful, 100 * d + k)["result"]) == "caught":
				landed += 1
		assert_true(landed >= 18, "difficulty %d: %d/20 landed" % [d, landed])


func test_reel_step_rules() -> void:
	var params := FishDB.reel_params(1)
	var r := _rng(1)
	var s := FishDB.reel_start(params, r)
	assert_eq(float(s["catch"]), 0.3, "the catch bar starts at 30%")
	s["timer"] = 100.0  # keep the fish resting
	var held := FishDB.reel_step(s, params, true, 0.1, r)
	assert_true(is_equal_approx(float(held["tension"]), 0.3 + 0.09), "holding reels at 0.9/s")
	var slack := FishDB.reel_step(s, params, false, 0.1, r)
	assert_true(is_equal_approx(float(slack["tension"]), 0.3 - 0.07), "releasing gives 0.7/s")
	# In the sweet spot the bar fills; below 15% it drains; between, it holds.
	var inside := s.duplicate()
	inside["tension"] = 0.55
	var after := FishDB.reel_step(inside, params, true, 0.0, r)
	assert_eq(float(after["catch"]), 0.3)
	after = FishDB.reel_step(inside, params, false, 0.1, r)
	assert_true(float(after["catch"]) > 0.3, "fills in the sweet spot")
	var low := s.duplicate()
	low["tension"] = 0.05
	assert_true(float(FishDB.reel_step(low, params, false, 0.1, r)["catch"]) < 0.3, "drains when slack")
	var mid := s.duplicate()
	mid["tension"] = 0.25
	assert_true(is_equal_approx(float(FishDB.reel_step(mid, params, false, 0.05, r)["catch"]), 0.3), "holds otherwise")
	# A run pushes tension up on its own.
	var running := s.duplicate()
	running["phase"] = "run"
	running["tension"] = 0.5
	assert_true(float(FishDB.reel_step(running, params, false, 0.1, r)["tension"]) > 0.5 - 0.07, "the fish pulls")
	var full := inside.duplicate()
	full["catch"] = 0.999
	assert_eq(String(FishDB.reel_step(full, params, false, 0.1, r)["result"]), "caught")
	var done := FishDB.reel_step(full, params, false, 0.1, r)
	assert_eq(FishDB.reel_step(done, params, true, 1.0, r), done, "a finished fight doesn't move")


func test_runs_cycle_rest_warn_run() -> void:
	var params := FishDB.reel_params(3)
	var r := _rng(4)
	var s := FishDB.reel_start(params, r)
	var seen := {}
	for i in 60 * 20:
		var careful := String(s["phase"]) == "rest" and float(s["tension"]) < 0.55
		s = FishDB.reel_step(s, params, careful, 1.0 / 60.0, r)
		seen[String(s["phase"])] = true
		if String(s["result"]) != "":
			break
	assert_true(seen.has("warn") and seen.has("run"), "the fish tenses, then runs (%s)" % [seen])


## -- Rewards, log and flags --

func test_xp() -> void:
	assert_eq(FishDB.catch_xp("mud_minnow"), 6, "3 + 3 x 1")
	assert_eq(FishDB.catch_xp("old_mayor"), 18, "3 + 3 x 5")
	assert_eq(FishDB.JUNK_XP, 1)


func test_flags_and_log() -> void:
	assert_eq(FishDB.flags_for({}, false), {})
	assert_eq(FishDB.flags_for({"mud_minnow": 1}, false), {"has_fished": true})
	var six := {"mud_minnow": 3, "rustgill_carp": 1, "sun_perch": 1, "silver_dace": 1, "ash_trout": 1, "bog_eel": 1}
	assert_true(FishDB.flags_for(six, false).has("angler"), "six species: angler")
	six.erase("bog_eel")
	assert_false(FishDB.flags_for(six, false).has("angler"), "five isn't")
	assert_true(FishDB.flags_for({"old_mayor": 1}, true).has("caught_old_mayor"))
	var decoded := FishDB.decode_log({"caught": {"mud_minnow": 2, "nonsense": 4, "bog_eel": 0}, "old_mayor": false})
	assert_eq(decoded["caught"], {"mud_minnow": 2}, "unknown ids and zeroes drop out")
	assert_eq(FishDB.decode_log({})["caught"], {}, "an old save: empty log")
	assert_true(bool(FishDB.decode_log({"caught": {"old_mayor": 1}})["old_mayor"]), "the log implies the flag")
	assert_true(FishDB.where_when("sludge_catfish").contains("rain"))
	assert_true(FishDB.where_when("mud_minnow").contains("All year"))


## -- Wiring --

func test_recipes_rod_and_skill() -> void:
	for id in ["grilled_fish", "grilled_fish_carp", "fish_stew", "smoked_eel"]:
		assert_true(RecipeDB.has_recipe(id), "%s recipe" % id)
		assert_eq(RecipeDB.category(id), "Cooking")
	assert_eq(RecipeDB.result_item("grilled_fish_carp"), "grilled_fish", "variants make the same dish")
	assert_true(RecipeDB.ingredients("smoked_eel").has("bog_eel"))
	assert_true(ShopDB.stock_ids("spring").has("fishing_rod"), "Marta sells the rod")
	assert_eq(ShopDB.price("fishing_rod"), 150)
	assert_eq(String(Skills.TOOL_SKILL.get("fishing_rod", "")), "foraging", "Foraging discounts the cast")
	assert_eq(QuestDB.amount_text("rustgill_carp", 3), "3 Rustgill Carp")
	assert_eq(QuestDB.amount_text("ash_trout", 2), "2 Ash Trout")
	assert_eq(QuestDB.amount_text("bog_eel", 2), "2 Bog Eels")


func test_water_kinds_on_the_layouts() -> void:
	assert_eq(TestMapScript.water_kind_of(SettlementDB.layout_for_zone("town", "open_plains")), "pond")
	assert_eq(TestMapScript.water_kind_of(SettlementDB.layout_for_zone("farm", "forest_edge")), "creek")
	for zone in ["farm", "path", "ranch"]:
		assert_eq(TestMapScript.water_kind_of(SettlementDB.layout_for_zone(zone, "riverside")), "river",
			"riverside %s is river" % zone)
	var rtown = SettlementDB.layout_for_zone("town", "riverside")
	assert_eq(rtown.water_kind_at(0, 9), "river", "the riverside town's west edge is river")
	assert_eq(rtown.water_kind_at(28, 13), "pond", "and it has the town pond too")
	assert_eq(rtown.water_kind_at(10, 10), "", "dry land")
	for settlement in ["open_plains", "forest_edge", "riverside"]:
		var town = SettlementDB.layout_for_zone("town", settlement)
		assert_eq(String(town.cell(28, 13)), "W", "%s: the town pond is in every start" % settlement)
	# Every water cell in every settlement zone has a kind.
	for settlement in ["open_plains", "forest_edge", "riverside"]:
		for zone in ["farm", "path", "town", "ranch"]:
			var layout = SettlementDB.layout_for_zone(zone, settlement)
			var kind := TestMapScript.water_kind_of(layout)
			for cell in layout.water_cells():
				if layout.has_method("water_kind_at"):
					assert_true(FishDB.WATERS.has(String(layout.water_kind_at(cell.x, cell.y))), "%s %s %s" % [settlement, zone, cell])
				else:
					assert_true(FishDB.WATERS.has(kind), "%s %s water has a kind" % [settlement, zone])
