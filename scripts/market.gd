extends Node
## The market's live state (Milestone D 2026-11-10, docs/LIVING_SETTLEMENT.md §1): each item's
## saturation and this week's demand list. One instance under Main; the rules are
## scripts/market_rules.gd. structures.gd asks sell() what a shipment pays; main.gd calls
## on_day_started() each morning (after the night's shipment has sold).

signal changed

const Rules := preload("res://scripts/market_rules.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")
const ItemDB := preload("res://scripts/item_db.gd")

var saturation: Dictionary = {}
var demand: Array[String] = []
var demand_week := -1
var base_seed := 0
## How many items are in demand each week (the story's "send it down the road" ending raises it).
var demand_count := Rules.DEMAND_COUNT


func new_game(seed_value: int) -> void:
	base_seed = seed_value
	saturation = {}
	demand = []
	demand_week = -1
	changed.emit()


## The multiplier `item_id` sells at right now: glut and demand, times `extra` (the shopfront bonus,
## structures.gd's sale_multiplier).
func multiplier_for(item_id: String, extra: float = 1.0) -> float:
	return Rules.price_multiplier(float(saturation.get(item_id, 0.0)), demand.has(item_id)) * extra


func unit_price(item_id: String, extra: float = 1.0) -> int:
	return int(round(float(ItemDB.sell_value(item_id)) * multiplier_for(item_id, extra)))


func quote(contents: Dictionary, extra: float = 1.0) -> Dictionary:
	return Rules.quote(contents, saturation, demand, extra)


## Sells `contents`: returns the quote it was paid at, then floods the shelf accordingly.
func sell(contents: Dictionary, extra: float = 1.0) -> Dictionary:
	var result := quote(contents, extra)
	for item_id in contents:
		var s := Rules.after_sale(float(saturation.get(item_id, 0.0)), int(contents[item_id]),
			ItemDB.sell_value(String(item_id)))
		if s > 0.0:
			saturation[String(item_id)] = s
	changed.emit()
	return result


## The morning: shelves clear a little, and on a new week (from day 8) a new demand list goes up.
## Returns true when the list changed.
func on_day_started(day: int, season: String) -> bool:
	for item_id in saturation.keys():
		var s := Rules.after_night(float(saturation[item_id]))
		if s <= 0.0:
			saturation.erase(item_id)
		else:
			saturation[item_id] = s
	var posted := false
	var week := Rules.week_of(day)
	if day >= Rules.DEMAND_FROM_DAY and week != demand_week:
		var rng := RandomNumberGenerator.new()
		rng.seed = DialogueDB.daily_seed("market", week, str(base_seed))
		demand = Rules.pick_demand(Rules.demand_pool(season), demand_count, rng)
		demand_week = week
		posted = true
	changed.emit()
	return posted


## The items whose price is noticeably down, worst first (for the board and the journal).
func flooded() -> Array[String]:
	var out: Array[String] = []
	for item_id in saturation:
		if Rules.glut_multiplier(float(saturation[item_id])) < 0.995:
			out.append(String(item_id))
	out.sort_custom(func(a, b): return float(saturation[a]) > float(saturation[b]))
	return out


func save_state() -> Dictionary:
	return {"saturation": saturation, "demand": demand, "demand_week": demand_week, "seed": base_seed}


func load_state(data: Dictionary) -> void:
	saturation = {}
	var raw = data.get("saturation", {})
	if raw is Dictionary:
		for item_id in raw:
			saturation[String(item_id)] = clampf(float(raw[item_id]), 0.0, 1.0)
	demand = []
	for item_id in data.get("demand", []):
		demand.append(String(item_id))
	demand_week = int(data.get("demand_week", -1))
	base_seed = int(data.get("seed", 0))
	changed.emit()
