extends "res://tests/test_case.gd"
## Phase 5 Stage 3 shipping-box pure logic (scripts/shipping_db.gd) — the crop-only shippable
## roster, per-unit valuation from data/items.json's `value` field, contents math, sale totals,
## and history-entry construction — plus the save_data.gd shipping encode/decode round-trip
## through actual JSON text (same "prove it survives real serialisation" standard
## tests/test_save_data.gd set for the other save sections). Same "pure core, headless-testable"
## split as tests/test_shop_db.gd.

const ShippingDB := preload("res://scripts/shipping_db.gd")
const SaveData := preload("res://scripts/save_data.gd")


## -- Roster / shippability --

func test_shippable_ids_are_exactly_the_4_crops() -> void:
	var ids := ShippingDB.shippable_ids()
	assert_eq(ids.size(), 4, "exactly 4 shippable items (the 4 crop-produce entries)")
	for crop_id in ["mutant_potato", "dustwheat_grain", "ironroot", "sunbloom"]:
		assert_true(crop_id in ids, "%s is shippable" % crop_id)


func test_seeds_tools_resources_food_are_not_shippable() -> void:
	# ROADMAP scopes the box to harvested CROPS — the player must not be able to ship away the
	# seeds/tools/materials they need (see shipping_db.gd's class doc).
	for item_id in ["seed_mutant_potato", "seed_sunbloom", "hoe", "bag", "wood", "scrap_metal",
			"bottle_caps", "preserved_food", "cooked_meal"]:
		assert_false(ShippingDB.is_shippable(item_id), "%s is not shippable" % item_id)


func test_unknown_item_is_not_shippable() -> void:
	assert_false(ShippingDB.is_shippable("not_a_real_item"))


func test_unit_value_matches_items_json_value_field() -> void:
	assert_eq(ShippingDB.unit_value("mutant_potato"), 20)
	assert_eq(ShippingDB.unit_value("dustwheat_grain"), 14)
	assert_eq(ShippingDB.unit_value("ironroot"), 26)
	assert_eq(ShippingDB.unit_value("sunbloom"), 30)


## -- Contents math --

func test_add_to_contents_adds_and_accumulates() -> void:
	var contents := ShippingDB.add_to_contents({}, "mutant_potato", 1)
	assert_eq(contents, {"mutant_potato": 1})
	contents = ShippingDB.add_to_contents(contents, "mutant_potato", 2)
	assert_eq(contents, {"mutant_potato": 3}, "same crop accumulates onto one entry")
	contents = ShippingDB.add_to_contents(contents, "sunbloom", 1)
	assert_eq(contents, {"mutant_potato": 3, "sunbloom": 1}, "different crops keep own entries")


func test_add_to_contents_refuses_non_crops_and_bad_counts_unchanged() -> void:
	var before := {"ironroot": 2}
	assert_eq(ShippingDB.add_to_contents(before, "hoe", 1), before, "tools refused")
	assert_eq(ShippingDB.add_to_contents(before, "seed_ironroot", 1), before, "seeds refused")
	assert_eq(ShippingDB.add_to_contents(before, "not_a_real_item", 1), before, "unknown refused")
	assert_eq(ShippingDB.add_to_contents(before, "sunbloom", 0), before, "zero count refused")
	assert_eq(ShippingDB.add_to_contents(before, "sunbloom", -3), before, "negative count refused")


func test_add_to_contents_never_mutates_its_input() -> void:
	var before := {"ironroot": 2}
	var result := ShippingDB.add_to_contents(before, "ironroot", 5)
	assert_eq(before, {"ironroot": 2}, "input dictionary untouched")
	assert_eq(result, {"ironroot": 7})


## -- Sale totals --

func test_sale_total_is_sum_of_count_times_value() -> void:
	# 3 * 20 + 2 * 30 + 1 * 26 = 146
	assert_eq(ShippingDB.sale_total({"mutant_potato": 3, "sunbloom": 2, "ironroot": 1}), 146)


func test_sale_total_single_unit_is_the_items_value() -> void:
	assert_eq(ShippingDB.sale_total({"mutant_potato": 1}), 20)


func test_sale_total_empty_box_is_zero() -> void:
	assert_eq(ShippingDB.sale_total({}), 0)


func test_sale_total_unknown_id_contributes_zero() -> void:
	# Belt-and-suspenders: add_to_contents never admits these, but a hand-edited save shouldn't
	# crash or mint Credits out of garbage.
	assert_eq(ShippingDB.sale_total({"not_a_real_item": 5, "sunbloom": 1}), 30)


## -- History entries --

func test_make_history_entry_shape_and_total() -> void:
	var entry := ShippingDB.make_history_entry(7, {"dustwheat_grain": 4})
	assert_eq(entry["day"], 7)
	assert_eq(entry["items"], {"dustwheat_grain": 4})
	assert_eq(entry["total"], 56, "4 * 14 Cr")


func test_make_history_entry_snapshots_items_not_references() -> void:
	var contents := {"sunbloom": 2}
	var entry := ShippingDB.make_history_entry(3, contents)
	contents.clear()  # the live box clears itself after selling
	assert_eq(entry["items"], {"sunbloom": 2}, "recorded breakdown survives the box clearing")


## -- save_data.gd shipping encode/decode, through real JSON text --

func test_shipping_round_trips_through_actual_json() -> void:
	var history := [
		ShippingDB.make_history_entry(2, {"mutant_potato": 1}),
		ShippingDB.make_history_entry(5, {"ironroot": 3, "sunbloom": 1}),
	]
	var encoded := SaveData.encode_shipping({"dustwheat_grain": 6}, history)
	var reparsed: Dictionary = JSON.parse_string(JSON.stringify(encoded))
	var decoded := SaveData.decode_shipping(reparsed)
	assert_eq(decoded["contents"], {"dustwheat_grain": 6}, "pending contents survive JSON")
	var out_history: Array = decoded["history"]
	assert_eq(out_history.size(), 2)
	assert_eq(out_history[0], {"day": 2, "items": {"mutant_potato": 1}, "total": 20})
	assert_eq(out_history[1], {"day": 5, "items": {"ironroot": 3, "sunbloom": 1}, "total": 108})
	# The decisive int-vs-float check (JSON round-trips ints as floats; decode must re-normalise
	# — see save_data.gd's class doc): identity comparisons above pass for 6.0 == 6, so assert
	# the concrete types too.
	assert_true(decoded["contents"]["dustwheat_grain"] is int, "counts decode as int, not float")
	assert_true(out_history[0]["day"] is int, "day decodes as int")
	assert_true(out_history[0]["total"] is int, "total decodes as int")


func test_decode_shipping_tolerates_missing_or_malformed_sections() -> void:
	var decoded := SaveData.decode_shipping({})
	assert_eq(decoded["contents"], {}, "a pre-Stage-3 save (no shipping key) decodes empty")
	assert_eq(decoded["history"], [], "and an empty history")
	var garbled := SaveData.decode_shipping({"contents": {}, "history": ["what", 3]})
	assert_eq(garbled["history"], [], "non-dictionary history rows are dropped, not crashed on")
