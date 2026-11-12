extends "res://tests/test_case.gd"
## The trading post's sale rules (scripts/structures.gd statics; Milestone D,
## docs/LIVING_SETTLEMENT.md §3): markup levels, daily throughput, shelf order, what sells.

const Structures := preload("res://scripts/structures.gd")
const ItemDB := preload("res://scripts/item_db.gd")


func _slots(pairs: Array) -> Array:
	var out: Array = []
	for pair in pairs:
		out.append({"item_id": pair[0], "count": pair[1]})
	return out


func test_units_by_markup_and_clerk() -> void:
	assert_eq(Structures.post_units(0, false), 12)
	assert_eq(Structures.post_units(1, false), 6)
	assert_eq(Structures.post_units(2, false), 3)
	assert_eq(Structures.post_units(0, true), 18)
	assert_eq(Structures.post_units(1, true), 9)
	assert_eq(Structures.post_units(2, true), 4)
	assert_eq(Structures.post_summary(0, false), "Fair: +15%, sells up to 12 a day")
	assert_eq(Structures.post_summary(2, true), "Steep: +60%, sells up to 4 a day")


func test_sells_in_shelf_order_up_to_the_day_s_trade() -> void:
	var value := ItemDB.sell_value("mutant_potato")
	var result := Structures.post_sale(_slots([["mutant_potato", 5], ["", 0], ["glow_melon", 20]]), 1, false)
	assert_eq(result["sold"], {"mutant_potato": 5, "glow_melon": 1}, "six units at Bold, first shelf first")
	assert_eq(int(result["total"]), 5 * int(round(value * 1.35)) + int(round(ItemDB.sell_value("glow_melon") * 1.35)))


func test_only_shippable_things_sell() -> void:
	var result := Structures.post_sale(_slots([["hoe", 1], ["seed_rain_radish", 9], ["rain_radish", 2]]), 0, false)
	assert_eq(result["sold"], {"rain_radish": 2}, "tools and seeds sit on the shelf")
	assert_eq(Structures.post_sale([], 0, false), {"sold": {}, "total": 0})


func test_every_markup_beats_the_shipping_box_and_steep_earns_most_per_unit() -> void:
	var value := ItemDB.sell_value("glow_melon")
	var last := value
	for level in 3:
		var one := int(Structures.post_sale(_slots([["glow_melon", 1]]), level, false)["total"])
		assert_true(one > last, "level %d pays more per unit" % level)
		last = one


func test_fair_moves_the_most_value_in_a_day() -> void:
	# A full shelf: the low markup earns more per day, the high one more per item. A real choice.
	var shelf := _slots([["glow_melon", 99]])
	var fair := int(Structures.post_sale(shelf, 0, false)["total"])
	var steep := int(Structures.post_sale(shelf, 2, false)["total"])
	assert_true(fair > steep, "Fair turns over more (%d vs %d)" % [fair, steep])
