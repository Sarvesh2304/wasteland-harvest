extends "res://tests/test_case.gd"
## Phase 5 Stage 2 town-store pure logic (scripts/shop_db.gd) — catalog membership, price
## lookups sourced from data/items.json's `value` field, and the affordability/deduction math
## scripts/store_ui.gd drives. Same "pure core, headless-testable" split as
## tests/test_dialogue_db.gd / tests/test_build_grid.gd.

const ShopDB := preload("res://scripts/shop_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")


func test_stock_is_seasonal_seeds_plus_staples() -> void:
	var spring := ShopDB.stock_ids("spring")
	for seed_id in ["seed_rain_radish", "seed_mutant_potato", "seed_ironroot"]:
		assert_true(seed_id in spring, "%s is on the spring shelf" % seed_id)
	assert_false("seed_sunbloom" in spring, "summer seeds wait for summer")
	var summer := ShopDB.stock_ids("summer")
	assert_true("seed_sunbloom" in summer, "sunbloom is on the summer shelf")
	assert_false("seed_rain_radish" in summer, "spring seeds are gone in summer")
	for staple in ShopDB.STAPLES:
		assert_true(staple in spring and staple in summer, "%s is stocked year-round" % staple)
	for refused in ["coffee", "bag", "hoe"]:
		assert_false(refused in spring, "%s is not on Marta's shelf" % refused)


func test_unseasoned_stock_lists_every_seed() -> void:
	var all := ShopDB.stock_ids()
	for seed_id in ["seed_mutant_potato", "seed_dustwheat", "seed_ironroot", "seed_sunbloom",
			"seed_ember_pumpkin", "seed_frostroot"]:
		assert_true(seed_id in all, "%s listed when no season is given" % seed_id)


func test_every_stocked_item_has_a_positive_price_and_a_description() -> void:
	for item_id in ShopDB.stock_ids():
		assert_true(ShopDB.price(item_id) > 0, "%s has a positive Credits price" % item_id)
		assert_ne(String(ItemDB.get_item(item_id).get("description", "")), "",
			"%s has a description for the store UI" % item_id)


func test_price_is_the_items_buy_price() -> void:
	for item_id in ["seed_mutant_potato", "seed_dustwheat", "preserved_food", "cooked_meal", "bandage"]:
		assert_eq(ShopDB.price(item_id), ItemDB.buy_price(item_id), "%s price" % item_id)
	assert_eq(ShopDB.price("seed_mutant_potato"), 25)


func test_can_afford_true_when_credits_cover_price_false_otherwise() -> void:
	assert_true(ShopDB.can_afford(25, "seed_mutant_potato"))
	assert_true(ShopDB.can_afford(100, "pickaxe"))
	assert_false(ShopDB.can_afford(24, "seed_mutant_potato"))
	assert_false(ShopDB.can_afford(0, "cooked_meal"))


func test_can_afford_false_for_unknown_or_unpriced_item() -> void:
	assert_false(ShopDB.can_afford(1000, "not_a_real_item"),
		"an item with no positive price can never be 'afforded', not even treated as free")


func test_attempt_purchase_deducts_exact_price_on_success() -> void:
	var result := ShopDB.attempt_purchase(50, "seed_mutant_potato")
	assert_true(result["ok"])
	assert_eq(result["credits"], 25)


func test_attempt_purchase_refuses_and_leaves_credits_untouched_when_unaffordable() -> void:
	var result := ShopDB.attempt_purchase(2, "axe")
	assert_false(result["ok"])
	assert_eq(result["credits"], 2, "unaffordable purchase never mutates the balance")


func test_attempt_purchase_exact_balance_succeeds_and_reaches_zero() -> void:
	var result := ShopDB.attempt_purchase(25, "seed_mutant_potato")
	assert_true(result["ok"])
	assert_eq(result["credits"], 0, "spending the exact balance is allowed, landing at 0")


func test_attempt_purchase_one_credit_short_is_refused() -> void:
	var result := ShopDB.attempt_purchase(24, "seed_mutant_potato")
	assert_false(result["ok"])
	assert_eq(result["credits"], 24)


func test_attempt_purchase_never_succeeds_for_unknown_item() -> void:
	var result := ShopDB.attempt_purchase(10, "not_a_real_item")
	assert_false(result["ok"], "an unpriced/unknown item can never be bought")
	assert_eq(result["credits"], 10, "balance is untouched")


func test_attempt_purchase_zero_credits_always_refused() -> void:
	var result := ShopDB.attempt_purchase(0, "seed_dustwheat")
	assert_false(result["ok"])
	assert_eq(result["credits"], 0)
