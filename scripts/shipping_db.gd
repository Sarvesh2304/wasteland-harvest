extends RefCounted
## Shipping-box pure logic (ROADMAP.md Phase 5 Stage 3: "Shipping box — place harvested crops
## before sleeping; Credits added next morning; tracks sale history"). Static module, same
## convention as shop_db.gd — this is the sell-side counterpart to that file's buy-side math,
## and like it, deliberately adds no new JSON data file: everything the shipping box needs
## (which items are crops, what each is worth) already lives on data/items.json via ItemDB.
##
## ## Scope: crops only
## ROADMAP's checklist line says "place harvested crops" specifically, so is_shippable() gates
## on `type == "crop"` — the player can't accidentally ship away seeds, tools, or the building
## resources they need (a general sell-anything channel is later economy work, Phase 10). The
## sale price per unit is the item's `value` field verbatim, the same field Marta's store
## charges for what SHE sells — one Credits scale across the whole economy.
##
## ## Contents / history shapes (operated on here, owned live by scripts/structures.gd)
## - contents: {item_id: count} — the box's pending, not-yet-sold load. Plain String keys, so
##   it's nearly JSON-ready as-is (see save_data.gd's decode int-normalisation).
## - history entry: {"day": int, "items": {item_id: count}, "total": int} — one entry per
##   morning a non-empty box resolved. `day` is the morning the Credits LANDED (the day_started
##   day), not the evening the crops were loaded; `items` is the itemized breakdown; `total` is
##   the Credits credited. That's everything a future ledger/summary UI could want to display,
##   while staying trivially JSON-serialisable — ROADMAP asks that history be *tracked*, not
##   shown, this stage (a viewing UI would be scope creep into later economy/UI phases).
##
## Not a `class_name` global (see scripts/item_db.gd's header for why) — callers must
## `const ShippingDB := preload("res://scripts/shipping_db.gd")`.

const ItemDB := preload("res://scripts/item_db.gd")


## The ordered roster of shippable item ids: every `type == "crop"` entry in data/items.json,
## in the file's own (insertion) order — scripts/shipping_ui.gd renders exactly these as rows.
## Derived rather than hardcoded so a future crop added to items.json is shippable for free.
static func shippable_ids() -> Array[String]:
	var out: Array[String] = []
	for item_id in ItemDB.all_items():
		if is_shippable(String(item_id)):
			out.append(String(item_id))
	return out


## Crops only — see class doc. Unknown items are not shippable.
static func is_shippable(item_id: String) -> bool:
	return String(ItemDB.get_item(item_id).get("type", "")) == "crop"


## Credits per unit sold: the item's data/items.json `value`, the same field shop_db.gd prices
## purchases from (0 for unknown/unpriced — such an item is also never shippable).
static func unit_value(item_id: String) -> int:
	return int(ItemDB.get_item(item_id).get("value", 0))


## Pure contents mutation (returns a NEW dictionary, input untouched — same discipline as
## inventory.gd's static slot math): adds `count` of a shippable item to the box's pending
## contents. A non-shippable item or non-positive count returns the contents unchanged, so
## callers can't corrupt the box by feeding it a seed/tool id (scripts/structures.gd's
## add_to_shipping_box compares the result to detect the refusal).
static func add_to_contents(contents: Dictionary, item_id: String, count: int) -> Dictionary:
	if count <= 0 or not is_shippable(item_id):
		return contents.duplicate(true)
	var out := contents.duplicate(true)
	out[item_id] = int(out.get(item_id, 0)) + count
	return out


## Total Credits a pending load sells for: sum of count * unit_value per item. Unknown ids
## contribute 0 rather than erroring (belt-and-suspenders — add_to_contents never admits them).
static func sale_total(contents: Dictionary) -> int:
	var total := 0
	for item_id in contents:
		total += int(contents[item_id]) * unit_value(String(item_id))
	return total


## Builds one sale-history entry (see class doc for the shape and field reasoning). The items
## breakdown is deep-duplicated so the live box clearing its contents afterwards can't hollow
## out an already-recorded entry.
static func make_history_entry(day: int, contents: Dictionary) -> Dictionary:
	return {
		"day": day,
		"items": contents.duplicate(true),
		"total": sale_total(contents),
	}
