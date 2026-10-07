extends "res://tests/test_case.gd"
## data/recipes.json + scripts/recipe_db.gd + scripts/crafting.gd.

const RecipeDB := preload("res://scripts/recipe_db.gd")
const Crafting := preload("res://scripts/crafting.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const InventoryScript := preload("res://scripts/inventory.gd")
const Skills := preload("res://scripts/skills.gd")


class FakePlayer:
	var inventory = InventoryScript.new()
	var credits := 0
	func set_credits(v: int) -> void:
		credits = v


func test_every_recipe_points_at_real_items() -> void:
	assert_true(RecipeDB.ids().size() >= 30, "a real recipe book (%d)" % RecipeDB.ids().size())
	for id in RecipeDB.ids():
		assert_true(RecipeDB.CATEGORY_ORDER.has(RecipeDB.category(id)), "%s has a known category" % id)
		if RecipeDB.is_upgrade(id):
			var kind := String(RecipeDB.get_recipe(id)["upgrade"])
			assert_true(ItemDB.has_item(kind) and ItemDB.is_tool_item(kind), "%s upgrades a real tool" % id)
		else:
			assert_true(ItemDB.has_item(RecipeDB.result_item(id)), "%s makes a real item" % id)
		for item in RecipeDB.ingredients(id):
			assert_true(ItemDB.has_item(item), "%s needs a real item (%s)" % [id, item])
		for skill in RecipeDB.unlock(id):
			assert_true(Skills.SKILLS.has(String(skill)), "%s unlocks on a real skill" % id)


func test_every_placeable_and_crafted_item_has_a_recipe() -> void:
	var made := {}
	for id in RecipeDB.ids():
		made[RecipeDB.result_item(id)] = true
	for item_id in ItemDB.all_items():
		if String(ItemDB.get_item(item_id).get("type", "")) == "placeable":
			assert_true(made.has(item_id), "%s can be crafted" % item_id)


func test_display_order_groups_categories() -> void:
	var last := -1
	for id in RecipeDB.ids():
		var c := RecipeDB.CATEGORY_ORDER.find(RecipeDB.category(id))
		assert_true(c >= last, "%s stays in category order" % id)
		last = c


func test_unlocks() -> void:
	assert_true(RecipeDB.is_unlocked("crate_chest", {}), "starter recipes need nothing")
	assert_false(RecipeDB.is_unlocked("scrap_sprinkler", {}), "sprinklers need Farming 2")
	assert_true(RecipeDB.is_unlocked("scrap_sprinkler", {"farming": 2}))
	assert_eq(RecipeDB.unlock_text("scrap_sprinkler"), "Farming 2")


func test_crafting_takes_ingredients_and_gives_the_result() -> void:
	var p := FakePlayer.new()
	assert_eq(Crafting.check("crate_chest", p.inventory, 0, {}), Crafting.MISSING)
	p.inventory.add_item("wood", 35)
	assert_eq(Crafting.craft("crate_chest", p, {}), Crafting.OK)
	assert_eq(p.inventory.count_of("wood"), 5, "30 wood used")
	assert_eq(p.inventory.count_of("crate_chest"), 1, "one chest made")
	p.inventory.add_item("stone", 1)
	assert_eq(Crafting.craft("gravel_path", p, {}), Crafting.OK)
	assert_eq(p.inventory.count_of("gravel_path"), 5, "path recipes make five")


func test_locked_and_credit_checks() -> void:
	var p := FakePlayer.new()
	p.inventory.add_item("scrap_metal", 4)
	p.inventory.add_item("copper_wire", 1)
	assert_eq(Crafting.craft("scrap_sprinkler", p, {}), Crafting.LOCKED)
	assert_eq(p.inventory.count_of("scrap_metal"), 4, "a refused craft takes nothing")
	assert_eq(Crafting.craft("scrap_sprinkler", p, {"farming": 2}), Crafting.OK)


func test_tool_upgrade_rebuilds_the_tool_in_place() -> void:
	var p := FakePlayer.new()
	p.inventory.add_tool("axe", 1)
	p.inventory.add_item("metal_bar", 5)
	assert_eq(Crafting.check("upgrade_axe_2", p.inventory, 100, {}), Crafting.NO_CREDITS)
	p.credits = 300
	assert_eq(Crafting.craft("upgrade_axe_2", p, {}), Crafting.OK)
	assert_eq(int(p.inventory.get_slot(0)["tier"]), 2, "the axe is now tier 2")
	assert_eq(p.credits, 50, "250 Credits spent")
	assert_eq(p.inventory.count_of("metal_bar"), 0)
	assert_eq(Crafting.check("upgrade_axe_2", p.inventory, 999, {}), Crafting.MISSING,
		"no bars left for a second go")
	p.inventory.add_item("metal_bar", 5)
	assert_eq(Crafting.check("upgrade_axe_2", p.inventory, 999, {}), Crafting.NO_TOOL,
		"and no tier-1 axe left to upgrade")
