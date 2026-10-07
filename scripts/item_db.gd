extends RefCounted
## Loader for data/items.json (item catalogue v2, 2026-10-07 — see the file's _comment for the
## field schema).
##
## Deliberately NOT a `class_name` global: this codebase's convention is `const X := preload(...)`
## in every file that needs it, because `class_name` globals only resolve once Godot's global
## script class cache is rebuilt (normally by opening the editor GUI). Any script that calls
## ItemDB must `const ItemDB := preload("res://scripts/item_db.gd")` first.
##
## Static, cached on first access. Every consumer (Inventory, HUD, player dispatch, shops,
## shipping, crafting) goes through this rather than touching the JSON directly.

const PATH := "res://data/items.json"

## Types the shipping box accepts (anything sellable that isn't a tool/weapon/gear/quest item).
const SHIPPABLE_TYPES: Array[String] = ["crop", "forage", "food", "resource", "medicine", "ammo",
	"placeable"]
## Farming tool kinds the player's tool dispatch understands.
const TOOL_KINDS: Array[String] = ["hoe", "watering_can", "axe", "pickaxe", "scythe", "fishing_rod"]
## Tool upgrade tiers 1..MAX_TOOL_TIER (Rusty, Patched, Reinforced, Pre-War).
const MAX_TOOL_TIER := 4
const TOOL_TIER_NAMES: Array[String] = ["", "Rusty", "Patched", "Reinforced", "Pre-War"]

static var _items: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var text := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(text)
	_items = parsed if parsed is Dictionary else {}
	_items.erase("_comment")


static func get_item(item_id: String) -> Dictionary:
	_ensure_loaded()
	return _items.get(item_id, {})


static func has_item(item_id: String) -> bool:
	_ensure_loaded()
	return _items.has(item_id)


static func all_items() -> Dictionary:
	_ensure_loaded()
	return _items


static func display_name(item_id: String) -> String:
	return String(get_item(item_id).get("name", item_id))


static func item_type(item_id: String) -> String:
	return String(get_item(item_id).get("type", ""))


static func category(item_id: String) -> String:
	return String(get_item(item_id).get("category", ""))


static func description(item_id: String) -> String:
	return String(get_item(item_id).get("description", ""))


static func stack_max(item_id: String) -> int:
	return int(get_item(item_id).get("stack_max", 1))


## Watering-can capacity by upgrade tier (Rusty 1 ... Pre-War 4).
const CAN_CAPACITY: Array[int] = [40, 55, 70, 100]


static func can_capacity(tier: int) -> int:
	return CAN_CAPACITY[clampi(tier, 1, CAN_CAPACITY.size()) - 1]


static func is_tool_item(item_id: String) -> bool:
	return item_type(item_id) == "tool"


## The farming-tool kind ("hoe", "axe", ...) of a tool item, or "" for non-tools. Pre-v2 data
## without tool_kind falls back to the item id itself (the old ids WERE the kinds).
static func tool_kind(item_id: String) -> String:
	if not is_tool_item(item_id):
		return ""
	return String(get_item(item_id).get("tool_kind", item_id))


static func is_seed(item_id: String) -> bool:
	return item_type(item_id) == "seed"


static func is_weapon(item_id: String) -> bool:
	return item_type(item_id) == "weapon"


static func is_placeable(item_id: String) -> bool:
	return item_type(item_id) == "placeable"


static func is_fertilizer(item_id: String) -> bool:
	return int(get_item(item_id).get("fertilizer_level", 0)) > 0


static func fertilizer_level(item_id: String) -> int:
	return int(get_item(item_id).get("fertilizer_level", 0))


static func is_edible(item_id: String) -> bool:
	return item_type(item_id) == "food"


## Anything the player can consume from the hotbar: food and medicine.
static func is_consumable(item_id: String) -> bool:
	var t := item_type(item_id)
	return t == "food" or t == "medicine"


static func energy_restored(item_id: String) -> int:
	return int(get_item(item_id).get("energy_restored", 0))


static func hp_restored(item_id: String) -> int:
	return int(get_item(item_id).get("hp_restored", 0))


static func rad_removed(item_id: String) -> int:
	return int(get_item(item_id).get("rad_removed", 0))


static func grants_stay_awake(item_id: String) -> bool:
	return bool(get_item(item_id).get("stay_awake", false))


static func durability_max(item_id: String) -> int:
	return int(get_item(item_id).get("durability_max", 0))


## Sell price per unit (what the shipping box pays).
static func sell_value(item_id: String) -> int:
	return int(get_item(item_id).get("value", 0))


## Store price per unit: buy_price when the catalogue sets one, else twice the sell value.
static func buy_price(item_id: String) -> int:
	var item := get_item(item_id)
	if item.has("buy_price"):
		return int(item["buy_price"])
	return int(item.get("value", 0)) * 2


static func is_shippable(item_id: String) -> bool:
	var item := get_item(item_id)
	if item.is_empty() or bool(item.get("legacy", false)):
		return false
	return SHIPPABLE_TYPES.has(String(item.get("type", ""))) and int(item.get("value", 0)) > 0


static func is_legacy(item_id: String) -> bool:
	return bool(get_item(item_id).get("legacy", false))


## Icon path for an item, with tool tiers > 1 using the <id>_t<N>.png variant when present.
static func icon_path(item_id: String, tier: int = 1) -> String:
	var base := String(get_item(item_id).get("icon", ""))
	if base == "" or tier <= 1:
		return base
	var tiered := base.get_basename() + "_t%d.png" % tier
	return tiered if ResourceLoader.exists(tiered) else base


static func tier_name(tier: int) -> String:
	return TOOL_TIER_NAMES[clampi(tier, 1, MAX_TOOL_TIER)]


static func reload_from_disk() -> void:
	_loaded = false
	_ensure_loaded()
