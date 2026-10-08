extends RefCounted
## Marta's store catalogue (v2, 2026-10-07). Static module; prices come from data/items.json via
## ItemDB.buy_price (buy_price when set, else twice the sell value).
##
## Stock is SEASONAL, Stardew-style: the seeds on the shelf are the ones that grow this season
## (data/crops.json's `seasons`), plus a year-round set of staples. Scav-Brew Coffee stays off
## the shelf on purpose (GDD.md §4: stay-awake items are rare — it comes from caravans). Farming
## tools are no longer sold: they never break any more, and upgrades are the mechanic's job.

const ItemDB := preload("res://scripts/item_db.gd")
const CropDB := preload("res://scripts/crop_db.gd")

## Sold every day of the year, after the seasonal seeds. Milestone C adds expedition kit: a
## slingshot (stones are free ammo), crossbow bolts, and pistol rounds at a price that makes
## every shot count (GDD.md §5's ammo economy).
const STAPLES: Array[String] = [
	"fertilizer", "preserved_food", "purified_water", "bandage", "cooked_meal",
	"slingshot", "crossbow_bolt", "pistol_ammo",
]


## Today's shelf. `season` "" (or unknown) falls back to every seed — used by older callers and
## tests that predate seasons.
static func stock_ids(season: String = "") -> Array[String]:
	var out: Array[String] = []
	var crop_ids: Array = CropDB.crops_for_season(season) if season != "" else CropDB.all_crops().keys()
	if crop_ids.is_empty():
		crop_ids = CropDB.all_crops().keys()
	for crop_id in crop_ids:
		var seed_id := String(CropDB.get_crop(String(crop_id)).get("seed_item", ""))
		if seed_id != "" and ItemDB.has_item(seed_id) and not out.has(seed_id):
			out.append(seed_id)
	for staple in STAPLES:
		if ItemDB.has_item(staple):
			out.append(staple)
	return out


static func price(item_id: String) -> int:
	return ItemDB.buy_price(item_id)


static func can_afford(credits: int, item_id: String) -> bool:
	var cost := price(item_id)
	return cost > 0 and credits >= cost


static func attempt_purchase(credits: int, item_id: String) -> Dictionary:
	var cost := price(item_id)
	if cost <= 0 or credits < cost:
		return {"ok": false, "credits": credits}
	return {"ok": true, "credits": credits - cost}
