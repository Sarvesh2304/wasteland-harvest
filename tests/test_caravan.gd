extends "res://tests/test_case.gd"
## scripts/caravan.gd and data/caravan.json (Milestone D, docs/LIVING_SETTLEMENT.md §2): visit days,
## the friendship discount, the seeded stock draw and its gates, and the authored pool.

const CaravanScript := preload("res://scripts/caravan.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const Calendar := preload("res://scripts/calendar.gd")

const POOL := [
	{"item": "coffee", "price": 320, "qty": [1, 2], "weight": 8},
	{"item": "glass", "price": 40, "qty": [3, 8], "weight": 5},
	{"item": "blueprint", "price": 900, "qty": [1, 1], "weight": 3, "min_hearts": 3},
	{"item": "seed_frostroot", "price": 60, "qty": [3, 6], "weight": 3, "season": "winter"},
]


func test_visit_days() -> void:
	var days := ["Wed", "Sat"]
	assert_false(CaravanScript.is_visit_day(1, days, 3), "Monday")
	assert_true(CaravanScript.is_visit_day(3, days, 3), "the first Wednesday")
	assert_true(CaravanScript.is_visit_day(6, days, 3), "Saturday")
	assert_false(CaravanScript.is_visit_day(3, days, 4), "not before his first day")
	assert_true(CaravanScript.is_visit_day(10, days, 3))


func test_friendship_discount() -> void:
	assert_eq(CaravanScript.discount(0), 0.0)
	assert_true(is_equal_approx(CaravanScript.discount(5), 0.1))
	assert_true(is_equal_approx(CaravanScript.discount(10), 0.2))
	assert_true(is_equal_approx(CaravanScript.discount(99), 0.2), "capped at 20%")
	assert_eq(CaravanScript.price_after(320, 0), 320)
	assert_eq(CaravanScript.price_after(320, 10), 256)
	assert_eq(CaravanScript.price_after(1, 10), 1, "never free")


func test_gates_by_hearts_and_season() -> void:
	var names := func(entries: Array) -> Array:
		return entries.map(func(e): return e["item"])
	assert_eq(names.call(CaravanScript.eligible(POOL, "spring", 0)), ["coffee", "glass"])
	assert_eq(names.call(CaravanScript.eligible(POOL, "spring", 3)), ["coffee", "glass", "blueprint"])
	assert_eq(names.call(CaravanScript.eligible(POOL, "winter", 0)), ["coffee", "glass", "seed_frostroot"])


func test_draw_is_seeded_distinct_and_in_range() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var a := CaravanScript.draw_offers(POOL, 3, "winter", 5, rng)
	rng.seed = 9
	assert_eq(CaravanScript.draw_offers(POOL, 3, "winter", 5, rng), a, "same seed, same stall")
	assert_eq(a.size(), 3)
	var seen := {}
	for offer in a:
		assert_false(seen.has(offer["item"]), "no repeats")
		seen[offer["item"]] = true
		assert_true(int(offer["qty"]) >= 1)
	assert_eq(CaravanScript.draw_offers(POOL, 9, "spring", 0, rng).size(), 2, "a thin pool gives what it has")


func test_stock_runs_out() -> void:
	var caravan: Node = CaravanScript.new()
	caravan.offers = [{"item": "coffee", "price": 320, "qty": 1}]
	assert_eq(caravan.stock().size(), 1)
	assert_true(caravan.take("coffee"))
	assert_false(caravan.take("coffee"), "sold out")
	assert_false(caravan.take("glass"), "not on the stall")
	assert_true(caravan.stock().is_empty())
	caravan.free()


func test_days_until_next_and_extra_days() -> void:
	var caravan: Node = CaravanScript.new()
	assert_eq(caravan.days_until_next(3), 0, "Wednesday")
	assert_eq(caravan.days_until_next(4), 2, "Thursday: he's back Saturday")
	assert_eq(caravan.days_until_next(1), 2, "Monday of week one: Wednesday")
	caravan.extra_weekdays = ["Mon", "Thu"]
	assert_eq(caravan.days_until_next(4), 0, "the road is busier once the seeds are shared")
	caravan.free()


func test_a_visit_draws_once_and_survives_a_reload() -> void:
	var caravan: Node = CaravanScript.new()
	caravan.base_seed = 31
	caravan.on_day_started(3, "spring", 0)
	var stall: Array = caravan.offers.duplicate(true)
	assert_eq(stall.size(), int(CaravanScript.config()["offers_per_visit"]))
	caravan.take(String(stall[0]["item"]))
	caravan.on_day_started(3, "spring", 0)
	assert_eq(int(caravan.offers[0]["qty"]), int(stall[0]["qty"]) - 1, "the same morning twice doesn't restock")
	var restored: Node = CaravanScript.new()
	restored.load_state(JSON.parse_string(JSON.stringify(caravan.save_state())))
	assert_eq(restored.offers, caravan.offers)
	restored.on_day_started(3, "spring", 0)
	assert_eq(restored.offers, caravan.offers, "a reload doesn't reroll or restock")
	caravan.free()
	restored.free()


func test_authored_pool_is_real_and_priced_above_what_it_sells_for() -> void:
	var cfg := CaravanScript.config()
	var pool: Array = cfg.get("pool", [])
	assert_true(pool.size() >= 20, "a deep pool (%d)" % pool.size())
	for day_name in cfg["visit_weekdays"]:
		assert_true(Calendar.WEEKDAYS.has(String(day_name)))
	var seen := {}
	for e in pool:
		var item := String(e["item"])
		assert_true(ItemDB.has_item(item), "%s exists" % item)
		assert_false(seen.has(item), "%s is listed once" % item)
		seen[item] = true
		assert_true(int(e["qty"][0]) >= 1 and int(e["qty"][1]) >= int(e["qty"][0]), "%s qty range" % item)
		assert_true(int(e["weight"]) > 0)
	# Buying from Tully and shipping in a +40% week must still lose money.
	for e in pool:
		if not ItemDB.is_shippable(String(e["item"])):
			continue
		assert_true(float(e["price"]) * 0.8 > float(ItemDB.sell_value(String(e["item"]))) * 1.4 * 1.1,
			"%s: no profit even at his best price and Marta's best week" % e["item"])
	assert_true(CaravanScript.eligible(pool, "spring", 0).size() >= int(cfg["offers_per_visit"]),
		"a stranger still sees a full stall")
