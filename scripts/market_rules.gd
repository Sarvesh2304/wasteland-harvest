extends RefCounted
## The market's rules (Milestone D 2026-11-10, docs/LIVING_SETTLEMENT.md §1): how shipping a lot of
## one thing floods the price, how it recovers, and the weekly demand list. Pure static functions;
## the live state is scripts/market.gd.

const ItemDB := preload("res://scripts/item_db.gd")
const QuestDB := preload("res://scripts/quest_db.gd")

## Base value's worth of one item that takes its saturation from 0 to 1.
const CAPACITY := 1200.0
## Saturation below this doesn't dent the price at all (a small farm never notices the market).
const FREE_SATURATION := 0.25
## The most a flooded item loses.
const MAX_CUT := 0.4
## Saturation shed each morning.
const NIGHTLY_RECOVERY := 0.2
const DEMAND_BONUS := 0.4
const DEMAND_COUNT := 3
## The first demand list is posted on the second Monday; week one stays simple.
const DEMAND_FROM_DAY := 8
const DAYS_PER_WEEK := 7
const DEMAND_POOLS: Array[String] = ["crop", "forage", "cooked", "artisan"]


## The price multiplier a saturation of `s` gives: 1.0 up to FREE_SATURATION, falling to 0.6 at 1.
static func glut_multiplier(s: float) -> float:
	var over := clampf((s - FREE_SATURATION) / (1.0 - FREE_SATURATION), 0.0, 1.0)
	return 1.0 - MAX_CUT * over


static func after_sale(s: float, units: int, base_value: int) -> float:
	return clampf(s + float(units * base_value) / CAPACITY, 0.0, 1.0)


static func after_night(s: float) -> float:
	var left := s - NIGHTLY_RECOVERY
	return left if left > 0.001 else 0.0  # (1.0 - 5 x 0.2 leaves float dust, not a glut)


static func price_multiplier(s: float, in_demand: bool) -> float:
	return glut_multiplier(s) * (1.0 + DEMAND_BONUS if in_demand else 1.0)


static func week_of(day: int) -> int:
	return (maxi(day, 1) - 1) / DAYS_PER_WEEK


## Everything Marta might be short of in `season`: crops and forage in season, cooked dishes and
## artisan goods (the request pools), in a stable order.
static func demand_pool(season: String) -> Array[String]:
	var out: Array[String] = []
	for pool in DEMAND_POOLS:
		for item in QuestDB.pool_items(pool, season):
			if not out.has(item) and ItemDB.sell_value(item) > 0 and ItemDB.is_shippable(item):
				out.append(item)
	return out


## `count` different items from `pool`, chosen by `rng` (fewer if the pool is small).
static func pick_demand(pool: Array[String], count: int, rng: RandomNumberGenerator) -> Array[String]:
	var left := pool.duplicate()
	var out: Array[String] = []
	while out.size() < count and not left.is_empty():
		out.append(left.pop_at(rng.randi_range(0, left.size() - 1)))
	return out


## What a shipment pays: {"total", "base", "lines": {item: {"count", "unit", "mult"}}}. Each item
## is paid at its saturation before this sale. `extra` multiplies everything (the shopfront bonus).
static func quote(contents: Dictionary, saturation: Dictionary, demand: Array, extra: float = 1.0) -> Dictionary:
	var total := 0
	var base := 0
	var lines := {}
	for item_id in contents:
		var count := int(contents[item_id])
		var value := ItemDB.sell_value(String(item_id))
		var mult := price_multiplier(float(saturation.get(item_id, 0.0)), demand.has(item_id)) * extra
		var unit := int(round(float(value) * mult))
		lines[item_id] = {"count": count, "unit": unit, "mult": mult}
		total += unit * count
		base += value * count
	return {"total": total, "base": base, "lines": lines}


## "+40%", "-12%", or "" when the price is (near enough) normal.
static func trend_text(mult: float) -> String:
	var pct := int(round((mult - 1.0) * 100.0))
	if pct == 0:
		return ""
	return "%s%d%%" % ["+" if pct > 0 else "-", absi(pct)]
