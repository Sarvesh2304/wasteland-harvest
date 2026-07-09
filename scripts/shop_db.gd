extends RefCounted
## Marta's store catalog (ROADMAP.md Phase 5 Stage 2: "Town store — Marta sells seeds/basic
## tools/food; UI shows name/description/price; currency is Credits"). Static module, same
## convention as item_db.gd/building_db.gd/dialogue_db.gd.
##
## Deliberately no second JSON data file: every field the store UI needs (name, description,
## price) already lives on the matching data/items.json entry via ItemDB — a shop-specific data
## file would just duplicate those fields with no new information, unlike buildings.json/
## dialogue.json which each hold data nothing else has. The only new thing this module owns is
## STOCK_IDS: an ordered, fixed list of which item ids Marta actually sells.
##
## ## Roster (ROADMAP: "Marta sells seeds/basic tools/food")
## - All 4 Phase 3 seeds — the entire seed catalog, so every crop is plantable from day one.
## - Both food items (Preserved Rations, Wasteland Stew) — a quick-energy purchase alternative
##   to cooking/foraging, matching Stardew's general store selling some prepared food too.
## - The 4 tools that actually wear out and can break: hoe, watering_can, axe, pickaxe. Sold as
##   REPLACEMENTS for a broken tool — player.gd's `_give_starting_loadout()` already grants one
##   of each for free at game start, and no repair system exists yet (see player.gd's own
##   comment on durability-zero tools going inert). The Scavenger's Bag is deliberately NOT
##   stocked: its durability_max is 999999 (functionally unbreakable, see items.json) — a
##   "replacement" has no meaning for something that can't break. It still carries a `value` in
##   items.json for schema completeness / future economy systems (shipping box, appraisal), it's
##   just never offered for sale here.
##
## ## Pricing (documented like data/buildings.json's own cost-tuning comment)
## Seed/food prices were already set in items.json's Phase 3 pass (this stage just makes them
## purchasable — see ItemDB.get_item()'s "value" field). Tool prices are new this stage, tuned
## against each tool's durability_max tier: hoe/watering_can share the higher 50-durability tier
## and are priced the same (24 Credits each); axe/pickaxe share the lower 40-durability tier —
## they wear out faster, so each swing "costs" more of the tool's lifetime, and they're priced a
## bit higher (28 Credits each) to reflect that. Both tiers stay within the 1-30 Credits scale
## every other item in items.json already uses.
##
## Not a `class_name` global (see scripts/item_db.gd's header for why) — callers must
## `const ShopDB := preload("res://scripts/shop_db.gd")`.

const ItemDB := preload("res://scripts/item_db.gd")

const STOCK_IDS: Array[String] = [
	"seed_mutant_potato", "seed_dustwheat", "seed_ironroot", "seed_sunbloom",
	"preserved_food", "cooked_meal",
	"hoe", "watering_can", "axe", "pickaxe",
]


## The ordered catalog scripts/store_ui.gd renders as rows.
static func stock_ids() -> Array[String]:
	return STOCK_IDS


## Credits price for item_id, sourced from data/items.json's "value" field (0 for an unknown or
## unpriced item — see attempt_purchase()'s guard, which treats a non-positive price as always
## unaffordable rather than "free").
static func price(item_id: String) -> int:
	return int(ItemDB.get_item(item_id).get("value", 0))


## Pure affordability check (headless-testable, no Node/scene required).
static func can_afford(credits: int, item_id: String) -> bool:
	var cost := price(item_id)
	return cost > 0 and credits >= cost


## Pure credits-deduction math, mirroring player.gd's apply_energy_delta() shape (a Dictionary
## result rather than a raw int, so a caller can't accidentally read a mutated balance out of a
## refused purchase): {"ok": bool, "credits": int}. On refusal ("ok": false — insufficient funds,
## or item_id has no positive price), "credits" is returned UNCHANGED, so a caller can always
## just assign the result's "credits" back without a branch and never risk going negative or
## crediting a purchase that didn't happen.
static func attempt_purchase(credits: int, item_id: String) -> Dictionary:
	var cost := price(item_id)
	if cost <= 0 or credits < cost:
		return {"ok": false, "credits": credits}
	return {"ok": true, "credits": credits - cost}
