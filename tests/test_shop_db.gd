extends "res://tests/test_case.gd"
## Phase 5 Stage 2 town-store pure logic (scripts/shop_db.gd) — catalog membership, price
## lookups sourced from data/items.json's `value` field, and the affordability/deduction math
## scripts/store_ui.gd drives. Same "pure core, headless-testable" split as
## tests/test_dialogue_db.gd / tests/test_build_grid.gd.

const ShopDB := preload("res://scripts/shop_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")


func test_stock_ids_cover_all_4_seeds_both_foods_and_4_breakable_tools() -> void:
	var stock := ShopDB.stock_ids()
	for seed_id in ["seed_mutant_potato", "seed_dustwheat", "seed_ironroot", "seed_sunbloom"]:
		assert_true(seed_id in stock, "%s is stocked" % seed_id)
	for food_id in ["preserved_food", "cooked_meal"]:
		assert_true(food_id in stock, "%s is stocked" % food_id)
	for tool_id in ["hoe", "watering_can", "axe", "pickaxe"]:
		assert_true(tool_id in stock, "%s is stocked" % tool_id)
	assert_false("bag" in stock, "the unbreakable Scavenger's Bag is deliberately not stocked")
	assert_eq(stock.size(), 10, "exactly 10 stocked items this stage")


func test_every_stocked_item_has_a_positive_price_and_a_description() -> void:
	for item_id in ShopDB.stock_ids():
		assert_true(ShopDB.price(item_id) > 0, "%s has a positive Credits price" % item_id)
		assert_ne(String(ItemDB.get_item(item_id).get("description", "")), "",
			"%s has a description for the store UI" % item_id)


func test_price_matches_the_items_json_value_field() -> void:
	assert_eq(ShopDB.price("seed_mutant_potato"), 8)
	assert_eq(ShopDB.price("seed_dustwheat"), 6)
	assert_eq(ShopDB.price("preserved_food"), 15)
	assert_eq(ShopDB.price("cooked_meal"), 22)
	assert_eq(ShopDB.price("hoe"), 24)
	assert_eq(ShopDB.price("watering_can"), 24)
	assert_eq(ShopDB.price("axe"), 28)
	assert_eq(ShopDB.price("pickaxe"), 28)


func test_unstocked_bag_still_has_a_value_field_for_completeness() -> void:
	# Not sold (see the stock-membership test above), but the gap the checklist called out was
	# "all 5 tools have no value field at all" — the bag's is still filled in.
	assert_eq(ShopDB.price("bag"), 20)


func test_can_afford_true_when_credits_cover_price_false_otherwise() -> void:
	assert_true(ShopDB.can_afford(8, "seed_mutant_potato"))
	assert_true(ShopDB.can_afford(100, "pickaxe"))
	assert_false(ShopDB.can_afford(7, "seed_mutant_potato"))
	assert_false(ShopDB.can_afford(0, "cooked_meal"))


func test_can_afford_false_for_unknown_or_unpriced_item() -> void:
	assert_false(ShopDB.can_afford(1000, "not_a_real_item"),
		"an item with no positive price can never be 'afforded', not even treated as free")


func test_attempt_purchase_deducts_exact_price_on_success() -> void:
	var result := ShopDB.attempt_purchase(50, "seed_mutant_potato")
	assert_true(result["ok"])
	assert_eq(result["credits"], 42)


func test_attempt_purchase_refuses_and_leaves_credits_untouched_when_unaffordable() -> void:
	var result := ShopDB.attempt_purchase(2, "axe")
	assert_false(result["ok"])
	assert_eq(result["credits"], 2, "unaffordable purchase never mutates the balance")


func test_attempt_purchase_exact_balance_succeeds_and_reaches_zero() -> void:
	var result := ShopDB.attempt_purchase(8, "seed_mutant_potato")
	assert_true(result["ok"])
	assert_eq(result["credits"], 0, "spending the exact balance is allowed, landing at 0")


func test_attempt_purchase_one_credit_short_is_refused() -> void:
	var result := ShopDB.attempt_purchase(7, "seed_mutant_potato")
	assert_false(result["ok"])
	assert_eq(result["credits"], 7)


func test_attempt_purchase_never_succeeds_for_unknown_item() -> void:
	var result := ShopDB.attempt_purchase(10, "not_a_real_item")
	assert_false(result["ok"], "an unpriced/unknown item can never be bought")
	assert_eq(result["credits"], 10, "balance is untouched")


func test_attempt_purchase_zero_credits_always_refused() -> void:
	var result := ShopDB.attempt_purchase(0, "seed_dustwheat")
	assert_false(result["ok"])
	assert_eq(result["credits"], 0)
