extends RefCounted
## Performs crafts (Milestone B, 2026-10-07): checks a recipe against the player's skills,
## backpack and Credits, takes the ingredients, and gives the result — or, for a tool upgrade,
## rebuilds the tool in its slot at the next tier. Static; the menu's CRAFT tab calls craft().

const RecipeDB := preload("res://scripts/recipe_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")

const OK := ""
const LOCKED := "locked"
const MISSING := "missing"
const NO_CREDITS := "no_credits"
const NO_TOOL := "no_tool"
const NO_ROOM := "no_room"
const UNKNOWN := "unknown"


## Why crafting `id` would fail right now ("" = it wouldn't).
static func check(id: String, inventory, credits: int, levels: Dictionary) -> String:
	if not RecipeDB.has_recipe(id):
		return UNKNOWN
	if not RecipeDB.is_unlocked(id, levels):
		return LOCKED
	if not RecipeDB.missing(id, counts_of(inventory, RecipeDB.ingredients(id))).is_empty():
		return MISSING
	if credits < RecipeDB.credits_cost(id):
		return NO_CREDITS
	if RecipeDB.is_upgrade(id):
		if upgrade_slot(id, inventory) < 0:
			return NO_TOOL
	elif not inventory.can_add(RecipeDB.result_item(id), RecipeDB.result_count(id)):
		return NO_ROOM
	return OK


## Crafts once. Returns "" on success, else the failure reason (see check()). Spends Credits
## through player.set_credits when the recipe costs any.
static func craft(id: String, player, levels: Dictionary) -> String:
	var inventory = player.inventory
	var reason := check(id, inventory, int(player.credits), levels)
	if reason != OK:
		return reason
	var need := RecipeDB.ingredients(id)
	for item in need:
		inventory.remove_item(item, int(need[item]))
	var cost := RecipeDB.credits_cost(id)
	if cost > 0:
		player.set_credits(int(player.credits) - cost)
	if RecipeDB.is_upgrade(id):
		var index := upgrade_slot(id, inventory)
		var slot: Dictionary = inventory.get_slot(index).duplicate()
		slot["tier"] = int(RecipeDB.get_recipe(id).get("to_tier", 2))
		inventory.set_slot(index, slot)
	else:
		var item_id := RecipeDB.result_item(id)
		var count := RecipeDB.result_count(id)
		inventory.add_item(item_id, count)
		Events.item_gained.emit(item_id, count)
	Events.item_crafted.emit(id, RecipeDB.result_count(id))
	Events.xp_gained.emit("crafting", RecipeDB.xp_reward(id))
	return OK


## The backpack slot holding the tool an upgrade recipe rebuilds (at to_tier - 1), or -1.
static func upgrade_slot(id: String, inventory) -> int:
	var recipe := RecipeDB.get_recipe(id)
	var kind := String(recipe.get("upgrade", ""))
	var from_tier := int(recipe.get("to_tier", 2)) - 1
	for i in inventory.slots.size():
		var slot: Dictionary = inventory.get_slot(i)
		if slot.is_empty():
			continue
		if ItemDB.tool_kind(String(slot.get("item_id", ""))) == kind \
				and int(slot.get("tier", 1)) == from_tier:
			return i
	return -1


## {item: count held} for the given items.
static func counts_of(inventory, items: Dictionary) -> Dictionary:
	var out := {}
	for item in items:
		out[item] = inventory.count_of(item)
	return out


## Short text for a failure reason, for the CRAFT tab's status line.
static func reason_text(reason: String, id: String) -> String:
	match reason:
		LOCKED:
			return "Needs %s" % RecipeDB.unlock_text(id)
		MISSING:
			return "Missing materials"
		NO_CREDITS:
			return "Not enough Credits"
		NO_TOOL:
			return "Bring the tool to upgrade"
		NO_ROOM:
			return "Your pack is full"
	return ""
