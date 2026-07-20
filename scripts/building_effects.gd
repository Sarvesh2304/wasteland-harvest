extends RefCounted
## Phase 8 Stage 1: named per-tick bespoke building effects (the "effect" field in
## data/buildings.json), plus the pure capacity-unlock/settler-arrival aggregators every later
## stage's yield/capacity mechanics route through. Same static-loader-adjacent convention as
## building_db.gd, except there's no JSON to load here — this file IS the registry.
##
## Split deliberately: daily_yield (generic item-count grants) and capacity_unlock (one-time
## bonuses) are handled entirely by structures.gd/main.gd without ever consulting this file —
## only a building kind that needs genuinely BESPOKE, mutating day-tick behavior (so far, only
## the Rain Collector) earns an entry in EFFECTS below. Adding a 13th building that just grants
## items or a flat capacity bonus should never require touching this file at all.
##
## Not a `class_name` global (see scripts/item_db.gd's header for why) — callers must
## `const BuildingEffects := preload("res://scripts/building_effects.gd")`. EFFECTS' Callables
## point back at this same script via a verified self-preload-by-path const (Self below) — Godot
## resolves a script's own preload of its own path fine even though the class isn't done
## compiling yet, since the const only needs the Script *resource*, not its finished method table,
## until the Callable is actually invoked.

const BuildingDB := preload("res://scripts/building_db.gd")
const Self := preload("res://scripts/building_effects.gd")

## Named per-tick effect callables, keyed by buildings.json's "effect" field. Called as
## `EFFECTS[key].call(entry, ctx)` from structures.gd's day-tick loop, once per completed entry
## whose building_id's BuildingDB.effect() key has an entry here — effect keys with NO entry
## here (e.g. "watchtower_lookout", "antenna_signal") are deliberately not tick callables at all;
## they're read directly by a later stage's own logic (settler_arrival_modifiers below, in turn
## consumed by Stage 3's arrival roll).
const EFFECTS := {
	"rain_collector_water": Callable(Self, "_tick_rain_collector"),
}

## Up to this many unwatered-but-planted plots get auto-watered per completed Rain Collector,
## per morning (Stage 1 plan's exact number).
const RAIN_COLLECTOR_WATER_LIMIT := 3


## Rain Collector's bespoke morning tick: waters up to RAIN_COLLECTOR_WATER_LIMIT
## unwatered-but-planted plots in ITS OWN ZONE — ctx["farm"] is always the calling
## structures.gd's own zone-sibling Farm node (see structures.gd's _on_day_started), so this is
## automatically zone-scoped without any explicit zone-id plumbing. `entry` (the completed Rain
## Collector's own {building_id, top_left, size, ...}) is unused: the effect is zone-wide, not
## proximity-based, so which cell the collector itself sits on doesn't matter — kept as a
## parameter anyway so every EFFECTS callable shares the same (entry, ctx) signature.
static func _tick_rain_collector(_entry: Dictionary, ctx: Dictionary) -> void:
	var farm: Node = ctx.get("farm")
	if farm == null:
		return
	var targets := select_rain_collector_targets(farm.waterable_cells(), RAIN_COLLECTOR_WATER_LIMIT)
	for cell in targets:
		farm.water(cell)


## Pure selection rule (headlessly testable against a plain Array of cells, no Farm/scene
## needed): the first `limit` entries of `waterable_cells`, in the order given. Deterministic
## rather than random — a rain collector isn't "lucky," it just reaches as many plots as its
## capacity allows, in a stable order, so repeated days/saves behave identically.
static func select_rain_collector_targets(waterable_cells: Array, limit: int) -> Array:
	var out: Array = []
	for cell in waterable_cells:
		if out.size() >= limit:
			break
		out.append(cell)
	return out


## The known capacity-unlock keys, always present (defaulted to 0) in recompute_capacity_unlocks'
## result so callers never need a defensive .get(key, 0) — see main.gd's application of this.
const CAPACITY_KEYS := ["population_cap", "energy_max", "build_energy_discount"]


## Pure: fed a flattened list of completed-entry dicts gathered across all 4 zones (main.gd's
## _all_completed_entries()). Returns summed one-time bonuses; the caller applies them to
## player.max_energy / builder's build-cost discount / (Stage 3's) settler population_cap.
## Recomputed in FULL every time (never incrementally mutated) so live-completion and
## post-load restore can never diverge — the whole point of deriving this from the
## completed-entries list rather than tracking a running total anywhere.
static func recompute_capacity_unlocks(all_completed_entries: Array) -> Dictionary:
	var out := {}
	for key in CAPACITY_KEYS:
		out[key] = 0
	for entry in all_completed_entries:
		var building_id := String(entry.get("building_id", ""))
		var unlock: Dictionary = BuildingDB.capacity_unlock(building_id)
		for key in unlock:
			if not out.has(key):
				out[key] = 0
			out[key] = out[key] + unlock[key]
	return out


## Flat per-building modifiers this stage defines correctly but has no consumer for yet (Stage
## 3's settler-arrival roll is the intended caller): Watchtower ("watchtower_lookout") raises the
## daily arrival chance, Antenna Tower ("antenna_signal") shortens the arrival cooldown — a
## distinct axis (frequency vs. chance) per the Stage 1 plan's building table. Both bonuses are
## flat-per-building (not diminishing); capping/floor-clamping is left to the caller (e.g. Stage
## 3's plan explicitly floor-clamps the resulting cooldown), since that belongs in the roll logic
## that owns "cooldown," not in this pure aggregator.
const WATCHTOWER_ARRIVAL_CHANCE_BONUS := 0.1
const ANTENNA_COOLDOWN_REDUCTION_DAYS := 1

static func settler_arrival_modifiers(all_completed_entries: Array) -> Dictionary:
	var watchtower_count := 0
	var antenna_count := 0
	for entry in all_completed_entries:
		var building_id := String(entry.get("building_id", ""))
		match BuildingDB.effect(building_id):
			"watchtower_lookout":
				watchtower_count += 1
			"antenna_signal":
				antenna_count += 1
	return {
		"arrival_chance_bonus": watchtower_count * WATCHTOWER_ARRIVAL_CHANCE_BONUS,
		"cooldown_reduction_days": antenna_count * ANTENNA_COOLDOWN_REDUCTION_DAYS,
	}
