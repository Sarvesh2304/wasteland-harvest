extends Node
## Tully's caravan (Milestone D 2026-11-10, docs/LIVING_SETTLEMENT.md §2). One instance under
## Main. On his days (data/caravan.json's weekdays) he stands in front of the town's market stall,
## which is drawn stocked, and sells a seeded draw from his pool: limited quantities, and cheaper
## the better he knows you. The rules are static functions so they test without a scene.

signal changed

const PATH := "res://data/caravan.json"
const ItemDB := preload("res://scripts/item_db.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")
const Calendar := preload("res://scripts/calendar.gd")

const NPC_ID := "caravan_trader"
## Where he stands (town zone): the cell in front of the market stall at (5..7, 10).
const STAND_CELL := Vector2i(6, 11)
const STALL_KIND := "market_stall"
const STALL_ART := "props/market_stall"
const STALL_OPEN_ART := "props/market_stall_open"
const DISCOUNT_PER_HEART := 0.02
const MAX_DISCOUNT := 0.2

static var _config: Dictionary = {}
static var _loaded := false

## Today's stock: [{"item", "price", "qty"}] (price before the friendship discount).
var offers: Array = []
var offers_day := -1
var base_seed := 0
## Extra weekdays he comes on and extra stock (the story's "send it down the road" ending).
var extra_weekdays: Array = []
var extra_offers := 0

var _town_npcs: Node = null
var _town_props: Node = null
var _npc: Node = null


## -- Rules --

static func config() -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		_config = parsed if parsed is Dictionary else {}
	return _config


static func is_visit_day(day: int, weekdays: Array, first_day: int) -> bool:
	return day >= first_day and weekdays.has(Calendar.weekday(day))


## The fraction Tully takes off at `hearts` (2% a heart, 20% at ten).
static func discount(hearts: int) -> float:
	return minf(float(maxi(hearts, 0)) * DISCOUNT_PER_HEART, MAX_DISCOUNT)


static func price_after(price: int, hearts: int) -> int:
	return maxi(1, int(round(float(price) * (1.0 - discount(hearts)))))


## The pool entries he'd show in `season` to someone at `hearts`.
static func eligible(pool: Array, season: String, hearts: int) -> Array:
	return pool.filter(func(e): return hearts >= int(e.get("min_hearts", 0)) \
		and (not e.has("season") or String(e["season"]) == season) and ItemDB.has_item(String(e["item"])))


## A weighted draw of `count` different entries from `pool`: [{"item", "price", "qty"}].
static func draw_offers(pool: Array, count: int, season: String, hearts: int, rng: RandomNumberGenerator) -> Array:
	var left := eligible(pool, season, hearts)
	var out: Array = []
	while out.size() < count and not left.is_empty():
		var total := 0
		for e in left:
			total += maxi(int(e.get("weight", 1)), 1)
		var pick := rng.randi_range(0, total - 1)
		for i in left.size():
			pick -= maxi(int(left[i].get("weight", 1)), 1)
			if pick < 0:
				var e: Dictionary = left.pop_at(i)
				var span: Array = e.get("qty", [1, 1])
				out.append({"item": String(e["item"]), "price": int(e["price"]),
					"qty": rng.randi_range(int(span[0]), int(span[span.size() - 1]))})
				break
	return out


## -- Live state --

func setup(town_npcs: Node, town_props: Node) -> void:
	_town_npcs = town_npcs
	_town_props = town_props


func weekdays() -> Array:
	var out: Array = (config().get("visit_weekdays", []) as Array).duplicate()
	for day_name in extra_weekdays:
		if not out.has(day_name):
			out.append(day_name)
	return out


func is_here(day: int) -> bool:
	return is_visit_day(day, weekdays(), int(config().get("first_day", 1)))


## Days until his next visit (0 = today).
func days_until_next(day: int) -> int:
	for ahead in 8:
		if is_here(day + ahead):
			return ahead
	return -1


## The morning (and boot): draws today's stock if he's here and it isn't drawn yet, and puts him
## at the stall or takes him away. `hearts` is the player's hearts with him.
func on_day_started(day: int, season: String, hearts: int) -> void:
	if is_here(day) and offers_day != day:
		var rng := RandomNumberGenerator.new()
		rng.seed = DialogueDB.daily_seed(NPC_ID, day, str(base_seed))
		offers = draw_offers(config().get("pool", []), int(config().get("offers_per_visit", 6)) + extra_offers,
			season, hearts, rng)
		offers_day = day
	_refresh_presence(day)
	changed.emit()


func _refresh_presence(day: int) -> void:
	if _town_npcs == null:
		return
	var here := is_here(day)
	if here and (_npc == null or not is_instance_valid(_npc)):
		_npc = _town_npcs.spawn_settler(NPC_ID, STAND_CELL, 0)
	elif not here and _npc != null and is_instance_valid(_npc):
		_town_npcs.despawn_npc(_npc)
		_npc = null
	if _town_props != null and _town_props.has_method("set_art"):
		_town_props.set_art(STALL_KIND, STALL_OPEN_ART if here else STALL_ART)


func npc() -> Node:
	return _npc if _npc != null and is_instance_valid(_npc) else null


## Today's stock still on the stall.
func stock() -> Array:
	return offers.filter(func(o): return int(o["qty"]) > 0)


## Takes one of `item_id` off the stall (the store screen calls this after the Credits change hands).
func take(item_id: String) -> bool:
	for offer in offers:
		if String(offer["item"]) == item_id and int(offer["qty"]) > 0:
			offer["qty"] = int(offer["qty"]) - 1
			changed.emit()
			return true
	return false


func save_state() -> Dictionary:
	return {"offers": offers, "offers_day": offers_day, "seed": base_seed}


func load_state(data: Dictionary) -> void:
	base_seed = int(data.get("seed", 0))
	offers_day = int(data.get("offers_day", -1))
	offers = []
	for raw in data.get("offers", []):
		if raw is Dictionary and ItemDB.has_item(String(raw.get("item", ""))):
			offers.append({"item": String(raw["item"]), "price": int(raw.get("price", 0)), "qty": int(raw.get("qty", 0))})
