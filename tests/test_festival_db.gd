extends "res://tests/test_case.gd"
## The festival rules and data (scripts/festival_db.gd, data/festivals.json; docs/LIVING_SETTLEMENT.md
## §4): the calendar, the four activities' rules, and that the authored data is what the engine
## keys on.

const FestivalDB := preload("res://scripts/festival_db.gd")
const Calendar := preload("res://scripts/calendar.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const AffinityScript := preload("res://scripts/affinity.gd")


func after_each() -> void:
	FestivalDB.reload_from_disk()


func test_one_festival_a_season_on_the_spec_dates() -> void:
	var expect := {"planting_day": ["spring", 14, "seed_hunt"], "scorch_fair": ["summer", 15, "goat_race"],
		"harvest_day": ["autumn", 21, "harvest_show"], "winter_gathering": ["winter", 14, "gift_circle"]}
	assert_eq(FestivalDB.festivals().size(), 4)
	for id in expect:
		var f := FestivalDB.festival(id)
		assert_eq(String(f.get("season", "")), expect[id][0], "%s's season" % id)
		assert_eq(int(f.get("day", 0)), expect[id][1], "%s's day" % id)
		assert_eq(String(f.get("activity", "")), expect[id][2], "%s's activity" % id)
		var day := Calendar.absolute_day(1, String(expect[id][0]), int(expect[id][1]))
		assert_eq(String(FestivalDB.on_day(day).get("id", "")), id, "%s falls on its day" % id)
		assert_true(FestivalDB.on_day(day - 1).is_empty(), "not the day before")
		assert_eq(String(FestivalDB.on_day(day + Calendar.DAYS_PER_YEAR).get("id", "")), id, "%s comes back next year" % id)


func test_next_festival_counts_days() -> void:
	var next := FestivalDB.next_festival(1)
	assert_eq(String(next["id"]), "planting_day")
	assert_eq(int(next["in_days"]), 13)
	var on := FestivalDB.next_festival(Calendar.absolute_day(1, "spring", 14))
	assert_eq(int(on["in_days"]), 0, "today counts")
	var after := FestivalDB.next_festival(Calendar.absolute_day(1, "winter", 15))
	assert_eq(String(after["id"]), "planting_day", "after the winter gathering, next spring")


func test_key_is_per_year() -> void:
	var day := Calendar.absolute_day(1, "autumn", 21)
	assert_ne(FestivalDB.key("harvest_day", day), FestivalDB.key("harvest_day", day + Calendar.DAYS_PER_YEAR))


func test_hunt_tiers() -> void:
	assert_eq(String(FestivalDB.hunt_result(12)["tier"]), "high")
	assert_eq(int(FestivalDB.hunt_result(10)["credits"]), 300)
	assert_eq(int((FestivalDB.hunt_result(10)["items"] as Dictionary).get("seed_glow_melon", 0)), 3)
	assert_eq(String(FestivalDB.hunt_result(9)["tier"]), "mid")
	assert_eq(int(FestivalDB.hunt_result(6)["credits"]), 150)
	assert_eq(String(FestivalDB.hunt_result(5)["tier"]), "low")
	assert_eq(int(FestivalDB.hunt_result(0)["credits"]), 50)


func test_goat_race_odds_are_fair_ish() -> void:
	var goats: Array = FestivalDB.festival("scorch_fair").get("goats", [])
	assert_eq(goats.size(), 4, "four goats")
	var odds: Array = []
	for g in goats:
		odds.append(int(g["odds"]))
	assert_eq(odds, [2, 3, 4, 6], "odds 2, 3, 4 and 6")
	assert_eq(String(goats[0]["name"]), "Dorothy", "Dorothy is the favourite")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var wins := [0, 0, 0, 0]
	var runs := 8000
	for i in runs:
		wins[FestivalDB.race_winner(goats, rng)] += 1
	# Each wins in proportion to 1/odds, so every bet returns the same on average (80% here).
	var total := 1.0 / 2 + 1.0 / 3 + 1.0 / 4 + 1.0 / 6
	for i in 4:
		var expected := (1.0 / float(odds[i])) / total
		assert_true(absf(float(wins[i]) / runs - expected) < 0.03, "goat %d wins about %.2f of races (%.3f)" % [
			i, expected, float(wins[i]) / runs])
	assert_eq(FestivalDB.race_payout(6), 300)


func test_show_kinds_and_entry() -> void:
	assert_eq(FestivalDB.show_kind("glow_melon"), "crop")
	assert_eq(FestivalDB.show_kind("milk"), "animal")
	assert_eq(FestivalDB.show_kind("hoe"), "", "tools can't be shown")
	assert_eq(FestivalDB.show_kind("not_an_item"), "")
	var entry := FestivalDB.show_entry({"glow_melon": 4, "ironroot": 1, "milk": 1, "hoe": 1, "wood": 30})
	var items: Array = entry["items"]
	assert_false(items.has("hoe") or items.has("wood"), "only showable things go on the table")
	assert_eq(items.count("glow_melon"), 1, "each thing once")
	assert_eq(int(entry["kinds"]), 2, "crop and animal")
	var value := 0
	for id in items:
		value += ItemDB.sell_value(String(id))
	assert_eq(int(entry["score"]), int(round(value * 1.2)), "+10% per kind")
	var six := {}
	for id in ["glow_melon", "ironroot", "milk", "egg", "cheese", "pumpkin_soup", "honey"]:
		six[id] = 1
	assert_eq((FestivalDB.show_entry(six)["items"] as Array).size(), FestivalDB.SHOW_ITEMS, "five at most")


func test_show_places_and_rivals_grow() -> void:
	assert_eq(FestivalDB.show_place(5000, 1), 1)
	assert_eq(FestivalDB.show_place(700, 1), 2, "between Marta (900) and Silas (600)")
	assert_eq(FestivalDB.show_place(0, 1), 4)
	assert_true(int(FestivalDB.rival_scores(3)[0][1]) > int(FestivalDB.rival_scores(1)[0][1]), "the tables improve each year")
	assert_eq(FestivalDB.show_place(1000, 3), 2, "a year-one winner isn't enough in year three")


func test_circle_draw_two_different_people() -> void:
	var npcs := ["mayor_harlan", "marta", "scout_kael", "rancher_silas", "brask", "wren", "doc_ama"]
	var rng := RandomNumberGenerator.new()
	for s in 200:
		rng.seed = s
		var draw := FestivalDB.circle_draw(npcs, rng)
		assert_ne(draw["friend"], draw["giver"], "seed %d" % s)
		if draw["friend"] == draw["giver"]:
			return
	assert_true(FestivalDB.circle_draw(["marta"], rng).is_empty(), "nobody to draw")


func test_circle_gifts_are_real_items_for_every_townsperson() -> void:
	var gifts: Dictionary = FestivalDB.festival("winter_gathering").get("gifts", {})
	for id in AffinityScript.NAMED_NPC_IDS:
		if AffinityScript.VISITOR_IDS.has(id):
			continue
		assert_true(gifts.has(id), "%s has a gift to give" % id)
		assert_true(ItemDB.has_item(String(gifts.get(id, ""))), "%s's gift is a real item" % id)


func test_use_data_hook() -> void:
	FestivalDB.use_data([{"id": "x", "season": "spring", "day": 1, "activity": "seed_hunt"}])
	assert_eq(String(FestivalDB.on_day(1).get("id", "")), "x")
	FestivalDB.reload_from_disk()
	assert_eq(FestivalDB.festivals().size(), 4)
