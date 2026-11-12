extends RefCounted
## Festivals (data/festivals.json, Milestone D 2026-11-11 — docs/LIVING_SETTLEMENT.md §4): the
## calendar and the rules of the four activities, as pure static functions. The live state and
## the town dressing are scripts/festivals.gd.

const PATH := "res://data/festivals.json"
const Calendar := preload("res://scripts/calendar.gd")
const ItemDB := preload("res://scripts/item_db.gd")
const QuestDB := preload("res://scripts/quest_db.gd")
const WorldObjectDB := preload("res://scripts/world_object_db.gd")

## -- Seed hunt --
const HUNT_PACKETS := 12
const HUNT_MINUTES := 120.0
const HUNT_HIGH := 10
const HUNT_MID := 6
const HUNT_WREN_FOUND := 8
## -- Goat race --
const RACE_STAKE := 50
const RACES_PER_DAY := 3
## -- Harvest show --
const SHOW_ITEMS := 5
const SHOW_KIND_BONUS := 0.1
## The other tables, year one: [npc, score]. Each year they're a quarter better.
const SHOW_RIVALS := [["marta", 900], ["rancher_silas", 600], ["mayor_harlan", 350]]
const SHOW_YEARLY_GROWTH := 0.25
const SHOW_PRIZES := {1: 1000, 2: 500, 3: 250, 4: 100}
const SHOW_WIN_FRIENDSHIP := 30
const ANIMAL_PRODUCTS: Array[String] = ["milk", "egg", "mutant_egg", "mutant_goat_milk"]
## -- Gift circle --
const CIRCLE_DRAW_DAY := 7

static var _festivals: Array = []
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
	_festivals = parsed["festivals"] if parsed is Dictionary and parsed.get("festivals") is Array else []


static func reload_from_disk() -> void:
	_loaded = false
	_ensure_loaded()


## Test hook: use this list instead of the file (reload_from_disk() undoes it).
static func use_data(list: Array) -> void:
	_loaded = true
	_festivals = list


static func festivals() -> Array:
	_ensure_loaded()
	return _festivals


static func festival(id: String) -> Dictionary:
	for f in festivals():
		if String((f as Dictionary).get("id", "")) == id:
			return f
	return {}


## The festival on absolute `day`, or {}.
static func on_day(day: int) -> Dictionary:
	for f in festivals():
		if Calendar.season(day) == String(f.get("season", "")) and Calendar.day_of_season(day) == int(f.get("day", 0)):
			return f
	return {}


## The next festival on or after `day`: the festival's fields plus "in_days" (0 = today); {} if none.
static func next_festival(day: int) -> Dictionary:
	for ahead in Calendar.DAYS_PER_YEAR + 1:
		var f := on_day(day + ahead)
		if not f.is_empty():
			var out := f.duplicate()
			out["in_days"] = ahead
			return out
	return {}


## "harvest_day:2": this festival, this year (what's been done at it is remembered per year).
static func key(id: String, day: int) -> String:
	return "%s:%d" % [id, Calendar.year(day)]


## -- Seed hunt --

## What `found` packets win: {"tier": "high"/"mid"/"low", "credits", "items": {id: n}}.
static func hunt_result(found: int) -> Dictionary:
	if found >= HUNT_HIGH:
		return {"tier": "high", "credits": 300, "items": {"seed_glow_melon": 3}}
	if found >= HUNT_MID:
		return {"tier": "mid", "credits": 150, "items": {}}
	return {"tier": "low", "credits": 50, "items": {}}


## -- Goat race --

## The winner's index among `goats` ([{"name", "odds"}]): the shorter the odds, the likelier.
## Each goat wins in proportion to 1/odds, so every bet returns the same 80% on average.
static func race_winner(goats: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for goat in goats:
		total += 1.0 / maxf(float(goat.get("odds", 2)), 1.0)
	var pick := rng.randf() * total
	for i in goats.size():
		pick -= 1.0 / maxf(float(goats[i].get("odds", 2)), 1.0)
		if pick <= 0.0:
			return i
	return goats.size() - 1


static func race_payout(odds: int) -> int:
	return RACE_STAKE * odds


## -- Harvest show --

## Which kind of entry `item_id` is at the show ("" = can't be shown).
static func show_kind(item_id: String) -> String:
	if not ItemDB.has_item(item_id):
		return ""
	if ItemDB.item_type(item_id) == "crop":
		return "crop"
	if ANIMAL_PRODUCTS.has(item_id):
		return "animal"
	if (QuestDB.POOLS["cooked"] as Array).has(item_id):
		return "cooked"
	if (QuestDB.POOLS["artisan"] as Array).has(item_id) and ItemDB.item_type(item_id) == "food":
		return "artisan"
	if WorldObjectDB.kind_for_forage(item_id) != "":
		return "forage"
	return ""


## The best table `have` ({item: count}) can make: up to five different showable things, most
## valuable first. {"items": [ids], "kinds": n, "score": int}.
static func show_entry(have: Dictionary) -> Dictionary:
	var candidates: Array[String] = []
	for item_id in have:
		if int(have[item_id]) > 0 and show_kind(String(item_id)) != "":
			candidates.append(String(item_id))
	candidates.sort_custom(func(a, b):
		var va := ItemDB.sell_value(a)
		var vb := ItemDB.sell_value(b)
		return va > vb if va != vb else a < b)
	var items := candidates.slice(0, SHOW_ITEMS)
	var kinds := {}
	var value := 0
	for item_id in items:
		kinds[show_kind(item_id)] = true
		value += ItemDB.sell_value(item_id)
	return {"items": items, "kinds": kinds.size(),
		"score": int(round(float(value) * (1.0 + SHOW_KIND_BONUS * float(kinds.size()))))}


static func rival_scores(year: int) -> Array:
	var out: Array = []
	for rival in SHOW_RIVALS:
		out.append([String(rival[0]), int(round(float(rival[1]) * (1.0 + SHOW_YEARLY_GROWTH * float(maxi(year, 1) - 1))))])
	return out


## 1-4: one more than the number of rival tables that beat `score`.
static func show_place(score: int, year: int) -> int:
	var place := 1
	for rival in rival_scores(year):
		if int(rival[1]) > score:
			place += 1
	return place


## -- Gift circle --

## Who the player gives to and who gives to the player: two different people from `npcs`.
static func circle_draw(npcs: Array, rng: RandomNumberGenerator) -> Dictionary:
	if npcs.size() < 2:
		return {}
	var friend := rng.randi_range(0, npcs.size() - 1)
	var giver := rng.randi_range(0, npcs.size() - 2)
	if giver >= friend:
		giver += 1
	return {"friend": String(npcs[friend]), "giver": String(npcs[giver])}
