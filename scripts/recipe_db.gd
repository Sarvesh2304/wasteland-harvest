extends RefCounted
## Crafting recipes (data/recipes.json, Milestone B 2026-10-07). Static module, same shape as
## item_db.gd: lazy JSON load, pure queries. scripts/crafting.gd performs crafts; the menu's
## CRAFT tab lists them.

const PATH := "res://data/recipes.json"
## Display order of the categories on the CRAFT tab.
const CATEGORY_ORDER: Array[String] = ["Farming", "Machines", "Storage", "Paths", "Light & Decor",
	"Supplies", "Cooking", "Upgrades"]
const DEFAULT_XP := 4

static var _recipes: Dictionary = {}
static var _loaded := false
static var _sorted: Array[String] = []


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary and parsed.get("recipes") is Dictionary:
		_recipes = parsed["recipes"]
	_sorted.clear()
	for id in _recipes:
		_sorted.append(String(id))
	_sorted.sort_custom(func(a: String, b: String) -> bool:
		var ca := CATEGORY_ORDER.find(category(a))
		var cb := CATEGORY_ORDER.find(category(b))
		if ca != cb:
			return ca < cb
		var la := unlock_total(a)
		var lb := unlock_total(b)
		if la != lb:
			return la < lb
		return a < b)


static func all_recipes() -> Dictionary:
	_ensure_loaded()
	return _recipes


## Recipe ids in display order (category, then unlock level, then id).
static func ids() -> Array[String]:
	_ensure_loaded()
	return _sorted


static func has_recipe(id: String) -> bool:
	_ensure_loaded()
	return _recipes.has(id)


static func get_recipe(id: String) -> Dictionary:
	_ensure_loaded()
	return _recipes.get(id, {})


static func category(id: String) -> String:
	return String(get_recipe(id).get("category", "Supplies"))


static func is_upgrade(id: String) -> bool:
	return String(get_recipe(id).get("upgrade", "")) != ""


## The item a craft produces ("" for upgrades, which rebuild a tool in place).
static func result_item(id: String) -> String:
	if is_upgrade(id):
		return ""
	return String(get_recipe(id).get("result", id))


static func result_count(id: String) -> int:
	return maxi(int(get_recipe(id).get("count", 1)), 1)


static func ingredients(id: String) -> Dictionary:
	var raw = get_recipe(id).get("ingredients", {})
	var out := {}
	if raw is Dictionary:
		for item in raw:
			out[String(item)] = int(raw[item])
	return out


static func credits_cost(id: String) -> int:
	return int(get_recipe(id).get("credits", 0))


static func xp_reward(id: String) -> int:
	return int(get_recipe(id).get("xp", DEFAULT_XP))


static func unlock(id: String) -> Dictionary:
	var raw = get_recipe(id).get("unlock", {})
	return raw if raw is Dictionary else {}


static func unlock_total(id: String) -> int:
	var total := 0
	var u := unlock(id)
	for skill in u:
		total += int(u[skill])
	return total


## Whether every skill the recipe names has reached its level. `levels` is {skill: level}.
static func is_unlocked(id: String, levels: Dictionary) -> bool:
	var u := unlock(id)
	for skill in u:
		if int(levels.get(skill, 0)) < int(u[skill]):
			return false
	return true


## Human text for what unlocks a locked recipe, e.g. "Farming 3".
static func unlock_text(id: String) -> String:
	var parts: Array[String] = []
	var u := unlock(id)
	for skill in u:
		parts.append("%s %d" % [String(skill).capitalize(), int(u[skill])])
	return ", ".join(parts)


## Ingredients still missing given backpack counts: {item: shortfall}.
static func missing(id: String, have: Dictionary) -> Dictionary:
	var out := {}
	var need := ingredients(id)
	for item in need:
		var short := int(need[item]) - int(have.get(item, 0))
		if short > 0:
			out[item] = short
	return out
