extends "res://tests/test_case.gd"
## data/items.json (catalogue v2, 2026-10-07) + scripts/item_db.gd.

const ItemDBScript := preload("res://scripts/item_db.gd")
const CropDBScript := preload("res://scripts/crop_db.gd")

const VALID_TYPES := ["seed", "crop", "forage", "resource", "food", "tool", "weapon", "ammo",
	"medicine", "placeable", "equipment", "quest"]


func test_catalogue_is_large_and_well_formed() -> void:
	var items := ItemDBScript.all_items()
	assert_true(items.size() >= 120, "120+ items (ROADMAP Phase 17 target) — got %d" % items.size())
	for item_id in items:
		var item: Dictionary = items[item_id]
		assert_true(VALID_TYPES.has(String(item.get("type", ""))), "%s has a valid type" % item_id)
		assert_true(int(item.get("stack_max", 0)) >= 1, "%s has stack_max" % item_id)
		assert_true(String(item.get("name", "")) != "", "%s has a name" % item_id)
		assert_true(String(item.get("description", "")) != "", "%s has a description" % item_id)
		assert_true(String(item.get("category", "")) != "", "%s has a category" % item_id)
		assert_true(int(item.get("value", -1)) >= 0, "%s has a value" % item_id)


func test_original_items_survive_for_old_saves() -> void:
	for item_id in ["seed_mutant_potato", "seed_dustwheat", "seed_ironroot", "seed_sunbloom",
			"mutant_potato", "dustwheat_grain", "ironroot", "sunbloom", "wood", "stone",
			"scrap_metal", "cloth_scrap", "bottle_caps", "fertilizer", "milk", "mutant_goat_milk",
			"egg", "mutant_egg", "preserved_food", "coffee", "cooked_meal", "hoe", "watering_can",
			"axe", "pickaxe", "bag"]:
		assert_true(ItemDBScript.has_item(item_id), "%s still exists" % item_id)


func test_tools_are_not_stackable_and_have_kinds() -> void:
	for item_id in ItemDBScript.all_items():
		if ItemDBScript.is_tool_item(item_id):
			assert_eq(ItemDBScript.stack_max(item_id), 1, "%s is a single instance" % item_id)
			assert_true(ItemDBScript.tool_kind(item_id) != "", "%s has a tool kind" % item_id)
	assert_eq(ItemDBScript.tool_kind("hoe"), "hoe")
	assert_eq(ItemDBScript.tool_kind("wood"), "", "non-tools have no kind")


func test_seeds_link_to_a_valid_crop() -> void:
	for item_id in ItemDBScript.all_items():
		if not ItemDBScript.is_seed(item_id):
			continue
		var item := ItemDBScript.get_item(item_id)
		if bool(item.get("mixed", false)):
			continue  # wild seeds pick a seasonal crop at planting time
		var crop_id := String(item.get("crop_id", ""))
		assert_true(CropDBScript.has_crop(crop_id), "%s points at a real crop (%s)" % [item_id, crop_id])


func test_consumables_restore_something() -> void:
	for item_id in ItemDBScript.all_items():
		if not ItemDBScript.is_consumable(item_id):
			continue
		var gives := ItemDBScript.energy_restored(item_id) + ItemDBScript.hp_restored(item_id) \
			+ ItemDBScript.rad_removed(item_id)
		assert_true(gives > 0 or ItemDBScript.grants_stay_awake(item_id),
			"%s does something when consumed" % item_id)
	assert_true(ItemDBScript.is_edible("cooked_meal"))
	assert_false(ItemDBScript.is_edible("wood"))
	assert_true(ItemDBScript.is_consumable("medkit"), "medicine is consumable")
	assert_false(ItemDBScript.is_edible("medkit"), "but not food")


func test_coffee_is_the_one_stay_awake_item() -> void:
	for item_id in ItemDBScript.all_items():
		assert_eq(ItemDBScript.grants_stay_awake(item_id), item_id == "coffee",
			"%s stay_awake flag" % item_id)


func test_buy_price_defaults_to_twice_value() -> void:
	assert_eq(ItemDBScript.buy_price("seed_rain_radish"), 12, "explicit buy_price wins")
	var value := ItemDBScript.sell_value("wood")
	assert_eq(ItemDBScript.buy_price("wood"), value * 2, "otherwise twice the sell value")


func test_shippable_rules() -> void:
	assert_true(ItemDBScript.is_shippable("mutant_potato"), "crops ship")
	assert_true(ItemDBScript.is_shippable("wild_greens"), "forage ships")
	assert_true(ItemDBScript.is_shippable("scrap_metal"), "resources ship")
	assert_true(ItemDBScript.is_shippable("berry_jam"), "artisan goods ship")
	assert_false(ItemDBScript.is_shippable("hoe"), "tools don't")
	assert_false(ItemDBScript.is_shippable("machete"), "weapons don't")
	assert_false(ItemDBScript.is_shippable("blueprint"), "quest items don't")
	assert_false(ItemDBScript.is_shippable("bag"), "legacy items don't")
	assert_false(ItemDBScript.is_shippable("not_a_real_item"))


func test_every_item_declares_an_icon_path() -> void:
	for item_id in ItemDBScript.all_items():
		var icon := String(ItemDBScript.get_item(item_id).get("icon", ""))
		assert_eq(icon, "res://art/items/%s.png" % item_id, "%s icon path follows the convention" % item_id)


func test_weapons_have_combat_stats() -> void:
	for item_id in ItemDBScript.all_items():
		if not ItemDBScript.is_weapon(item_id):
			continue
		var item := ItemDBScript.get_item(item_id)
		assert_true(int(item.get("damage", 0)) > 0, "%s deals damage" % item_id)
		assert_true(float(item.get("cooldown", 0.0)) > 0.0, "%s has a cooldown" % item_id)
		if String(item.get("weapon_class", "")) == "ranged":
			assert_true(ItemDBScript.has_item(String(item.get("ammo_item", ""))),
				"%s uses a real ammo item" % item_id)
