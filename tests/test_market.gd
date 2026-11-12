extends "res://tests/test_case.gd"
## scripts/market_rules.gd and scripts/market.gd (Milestone D, docs/LIVING_SETTLEMENT.md §1): glut,
## recovery, the weekly demand list, quotes, and the save round trip.

const Rules := preload("res://scripts/market_rules.gd")
const MarketScript := preload("res://scripts/market.gd")
const ItemDB := preload("res://scripts/item_db.gd")


func test_glut_is_free_at_first_then_falls_to_minus_forty() -> void:
	assert_eq(Rules.glut_multiplier(0.0), 1.0)
	assert_eq(Rules.glut_multiplier(Rules.FREE_SATURATION), 1.0, "a small farm never notices")
	assert_true(Rules.glut_multiplier(0.5) < 1.0 and Rules.glut_multiplier(0.5) > 0.8)
	assert_true(is_equal_approx(Rules.glut_multiplier(1.0), 0.6), "-40% when flooded")
	assert_true(is_equal_approx(Rules.glut_multiplier(5.0), 0.6), "never below that")


func test_sales_flood_by_value_and_nights_clear() -> void:
	var s := Rules.after_sale(0.0, 10, 60)
	assert_true(is_equal_approx(s, 600.0 / Rules.CAPACITY))
	assert_eq(Rules.after_sale(0.9, 1000, 100), 1.0, "capped")
	assert_true(is_equal_approx(Rules.after_night(0.5), 0.3))
	assert_eq(Rules.after_night(0.1), 0.0)
	var nights := 0
	var level := 1.0
	while level > 0.0:
		level = Rules.after_night(level)
		nights += 1
	assert_eq(nights, 5, "a flooded item is back to normal in five days")


func test_demand_multiplies_on_top() -> void:
	assert_true(is_equal_approx(Rules.price_multiplier(0.0, true), 1.4))
	assert_true(is_equal_approx(Rules.price_multiplier(1.0, true), 0.6 * 1.4), "flooded and wanted")


func test_trend_text() -> void:
	assert_eq(Rules.trend_text(1.0), "")
	assert_eq(Rules.trend_text(1.4), "+40%")
	assert_eq(Rules.trend_text(0.76), "-24%")
	assert_eq(Rules.trend_text(1.004), "", "rounding noise isn't a trend")


func test_demand_pool_follows_the_season_and_is_sellable() -> void:
	var spring := Rules.demand_pool("spring")
	assert_true(spring.has("mutant_potato") and spring.has("berry_jam"))
	assert_false(spring.has("frostroot"), "nothing out of season")
	for item in spring:
		assert_true(ItemDB.is_shippable(item) and ItemDB.sell_value(item) > 0, "%s can be shipped" % item)


func test_pick_demand_is_distinct_and_deterministic() -> void:
	var pool := Rules.demand_pool("summer")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var a := Rules.pick_demand(pool, 3, rng)
	rng.seed = 5
	assert_eq(Rules.pick_demand(pool, 3, rng), a)
	assert_eq(a.size(), 3)
	assert_true(a[0] != a[1] and a[1] != a[2] and a[0] != a[2], "three different things")
	var tiny: Array[String] = ["wood"]
	assert_eq(Rules.pick_demand(tiny, 3, rng), ["wood"], "a small pool gives what it has")


func test_quote_prices_each_item_at_its_own_mood() -> void:
	var value := ItemDB.sell_value("mutant_potato")
	var q := Rules.quote({"mutant_potato": 10, "rain_radish": 2}, {"mutant_potato": 1.0}, ["rain_radish"])
	assert_eq(int(q["lines"]["mutant_potato"]["unit"]), int(round(value * 0.6)))
	assert_eq(int(q["lines"]["rain_radish"]["unit"]), int(round(ItemDB.sell_value("rain_radish") * 1.4)))
	assert_eq(int(q["base"]), value * 10 + ItemDB.sell_value("rain_radish") * 2)
	assert_eq(int(q["total"]), int(round(value * 0.6)) * 10 + int(round(ItemDB.sell_value("rain_radish") * 1.4)) * 2)
	assert_eq(int(Rules.quote({"mutant_potato": 1}, {}, [], 1.1)["total"]), int(round(value * 1.1)), "the shopfront bonus")


func test_a_sale_is_paid_at_the_price_before_it() -> void:
	var market: Node = MarketScript.new()
	market.new_game(1)
	var value := ItemDB.sell_value("glow_melon")
	var units := int(ceil(Rules.CAPACITY / float(value))) + 1
	var first: Dictionary = market.sell({"glow_melon": units})
	assert_eq(int(first["total"]), units * value, "the first big load gets full price")
	assert_true(market.multiplier_for("glow_melon") < 0.65, "and floods the shelf")
	assert_eq(market.flooded(), ["glow_melon"])
	var second: Dictionary = market.sell({"glow_melon": 1})
	assert_true(int(second["total"]) < value, "the next one doesn't")
	for night in 5:
		market.on_day_started(2 + night, "summer")
	assert_eq(market.multiplier_for("glow_melon"), 1.0, "five mornings later it's forgotten")
	assert_true(market.saturation.is_empty(), "and nothing lingers in the save")
	market.free()


func test_demand_waits_for_week_two_then_changes_weekly() -> void:
	var market: Node = MarketScript.new()
	market.new_game(77)
	assert_false(market.on_day_started(7, "spring"), "week one has no list")
	assert_true(market.demand.is_empty())
	assert_true(market.on_day_started(8, "spring"), "posted on the second Monday")
	assert_eq(market.demand.size(), Rules.DEMAND_COUNT)
	var week_two: Array = market.demand.duplicate()
	assert_false(market.on_day_started(9, "spring"), "the same list all week")
	assert_eq(market.demand, week_two)
	assert_true(market.on_day_started(15, "spring"), "a new list next Monday")
	market.free()


func test_save_round_trip_and_same_seed_same_week() -> void:
	var market: Node = MarketScript.new()
	market.new_game(42)
	market.on_day_started(8, "summer")
	market.sell({"dust_corn": 30})
	var restored: Node = MarketScript.new()
	restored.load_state(JSON.parse_string(JSON.stringify(market.save_state())))
	assert_eq(restored.demand, market.demand)
	assert_eq(restored.demand_week, 1)
	assert_true(is_equal_approx(restored.multiplier_for("dust_corn"), market.multiplier_for("dust_corn")))
	market.on_day_started(15, "summer")
	restored.on_day_started(15, "summer")
	assert_eq(restored.demand, market.demand, "the next list is the same after a reload")
	market.free()
	restored.free()
