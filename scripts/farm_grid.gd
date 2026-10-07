extends RefCounted
## Pure farming-plot logic: tillability, daily growth, seasons, regrowth and harvest yield. No
## scene/node state lives here — scripts/farm.gd owns the per-cell plot Dictionaries and calls
## into these static functions (the project's pure-rules / stateful-node split).
##
## Not a `class_name` global (see scripts/item_db.gd's header) — callers must
## `const FarmGrid := preload("res://scripts/farm_grid.gd")`.
##
## ## Dual-grid tilling semantics
## The ground is a dual-grid Wang layer: each visual tile samples the four LOGICAL cells meeting
## at its corners. Interaction targets exactly one logical cell; tilling flips that cell's soil
## bit and the painter re-blends the visual tiles around it. Cells are gameplay truth; corners are
## a rendering detail.
##
## ## Plot shape (v2, 2026-10-07)
##   {crop_id, growth, stage, watered, fertilizer, dead}
## - growth: watered days grown so far. stage is DERIVED from growth via the crop's stage_days
##   (kept in the dictionary for display and for older tools/saves that read it).
## - watered: watered today. The morning tick consumes it.
## - fertilizer: 0 none, 1 basic, 2 rich — applied to soil before planting, read at harvest.
## - dead: the crop withered (planted out of season or the season ended). It stays visible as a
##   dry husk until cleared, Stardew-style; it never grows or yields.
## Pre-v2 plots ({crop_id, stage, watered}) are upgraded by normalize_plot().
##
## ## Growth rule (2026-10-07 — replaces the old "unwatered crops die" rule)
## A day without water simply doesn't count: growth pauses, nothing dies. The old literal
## "water daily or they die" reading broke GDD.md §4's cozy contract (no punishing failure states)
## and was the harshest rule in the game. The only way a crop dies is the season turning on it.
## A mature crop needs no more water and waits for harvest indefinitely within its seasons.

const CropDB := preload("res://scripts/crop_db.gd")


static func is_tillable_terrain(cell_char: String) -> bool:
	return cell_char == "." or cell_char == "@"


## A freshly planted plot.
static func new_plot(crop_id: String, fertilizer: int = 0) -> Dictionary:
	return {"crop_id": crop_id, "growth": 0, "stage": 0, "watered": false,
		"fertilizer": fertilizer, "dead": false}


## Upgrades a pre-v2 plot (stage-only) to the v2 shape and re-derives `stage` from `growth`.
static func normalize_plot(plot: Dictionary, crop_def: Dictionary) -> Dictionary:
	if plot.is_empty() or String(plot.get("crop_id", "")) == "":
		return plot
	var out := plot.duplicate()
	if not out.has("growth"):
		out["growth"] = CropDB.growth_at_stage_of(crop_def, int(out.get("stage", 0)))
	out["growth"] = clampi(int(out["growth"]), 0, CropDB.total_days_of(crop_def))
	out["stage"] = CropDB.stage_for_growth_of(crop_def, int(out["growth"]))
	out["watered"] = bool(out.get("watered", false))
	out["fertilizer"] = int(out.get("fertilizer", 0))
	out["dead"] = bool(out.get("dead", false))
	return out


## One morning tick for one plot. `season` is today's season ("" = ignore seasons). Returns the
## plot's new state — never empty for a real crop (crops no longer vanish overnight).
static func advance_plot(plot: Dictionary, crop_def: Dictionary, season: String = "") -> Dictionary:
	if plot.is_empty() or String(plot.get("crop_id", "")) == "":
		return plot
	var next := normalize_plot(plot, crop_def)
	if bool(next["dead"]):
		next["watered"] = false
		return next
	if not CropDB.grows_in_season_of(crop_def, season):
		next["dead"] = true
		next["watered"] = false
		return next
	if not is_mature(next, crop_def) and bool(next["watered"]):
		next["growth"] = int(next["growth"]) + 1
		next["stage"] = CropDB.stage_for_growth_of(crop_def, int(next["growth"]))
	next["watered"] = false
	return next


static func is_mature(plot: Dictionary, crop_def: Dictionary) -> bool:
	if plot.is_empty() or String(plot.get("crop_id", "")) == "" or bool(plot.get("dead", false)):
		return false
	var growth := int(plot.get("growth", CropDB.growth_at_stage_of(crop_def, int(plot.get("stage", 0)))))
	return growth >= CropDB.total_days_of(crop_def)


## Whether watering this plot would do anything (a growing, living, not-yet-watered crop).
static func needs_water(plot: Dictionary, crop_def: Dictionary) -> bool:
	if plot.is_empty() or String(plot.get("crop_id", "")) == "":
		return false
	if bool(plot.get("dead", false)) or bool(plot.get("watered", false)):
		return false
	return not is_mature(plot, crop_def)


## How many items one harvest yields. `count_roll` and `extra_roll` are uniform [0,1) rolls
## supplied by the caller (so this stays deterministic under test). Fertilizer adds a flat
## chance of one more: basic +15%, rich +30%.
static func harvest_count(crop_def: Dictionary, fertilizer: int, count_roll: float,
		extra_roll: float) -> int:
	var lo := maxi(int(crop_def.get("yield_min", crop_def.get("yield_quantity", 1))), 1)
	var hi := maxi(int(crop_def.get("yield_max", lo)), lo)
	var count := lo + int(floor(count_roll * float(hi - lo + 1)))
	count = clampi(count, lo, hi)
	var extra_chance := float(crop_def.get("extra_chance", 0.0)) + 0.15 * float(clampi(fertilizer, 0, 2))
	if extra_roll < extra_chance:
		count += 1
	return count


## Harvest result for a mature plot: {"item_id", "count"} or {} if not harvestable.
## Deterministic default rolls (0.0, 1.0) give exactly yield_min with no extra.
static func harvest_yield(plot: Dictionary, crop_def: Dictionary, count_roll: float = 0.0,
		extra_roll: float = 1.0) -> Dictionary:
	if not is_mature(plot, crop_def):
		return {}
	return {
		"item_id": String(crop_def.get("yield_item", "")),
		"count": harvest_count(crop_def, int(plot.get("fertilizer", 0)), count_roll, extra_roll),
	}


## The plot left behind after a harvest: a regrowing crop drops back regrow_days of growth (it
## keeps its fertilizer); anything else leaves bare tilled soil ({}).
static func after_harvest(plot: Dictionary, crop_def: Dictionary) -> Dictionary:
	var regrow := int(crop_def.get("regrow_days", 0))
	if regrow <= 0:
		return {}
	var next := normalize_plot(plot, crop_def)
	next["growth"] = maxi(CropDB.total_days_of(crop_def) - regrow, 0)
	next["stage"] = CropDB.stage_for_growth_of(crop_def, int(next["growth"]))
	next["watered"] = false
	return next
