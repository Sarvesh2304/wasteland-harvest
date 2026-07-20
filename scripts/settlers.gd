extends Node
## Phase 8 Stage 3: settlement-wide settler-arrival system (ROADMAP.md Phase 8 "Settler system").
## One instance lives directly under Main (scenes/main.tscn) — NOT per-zone like structures.gd/
## npcs.gd, since population is a settlement-wide concept, not a per-zone one. get_parent() is
## therefore Main itself (added as a direct child, same ordering guarantee structures.gd/npcs.gd
## document for their own TestMap parent) — used only to reach main._all_completed_entries()
## (Stage 1's helper) for the population cap / arrival modifiers below; nothing here assumes
## which zone a completed building lives in.
##
## population_cap is deliberately never stored as a field: like player.max_energy (Stage 1's
## rule), it's always freshly recomputed from BuildingEffects.recompute_capacity_unlocks() so a
## live Shelter Cabin completion, a reload, or (this stage) a growing roster can never drift from
## the actual count of completed Shelter Cabins.
##
## -- Arrivals --
## Hooked to DayManager.day_started exactly like structures.gd/farm.gd. Per the "no fail state"
## cozy contract (matching Silas's own "won't sell without a barn" precedent, ROADMAP.md Phase
## 8): a visitor is only ever offered when there's a pending_visitor slot free (one at a time, no
## queue) AND the roster has room under the live population cap — never dangled with nowhere to
## house them. The actual roll is a base chance plus Watchtower's arrival_chance_bonus
## (BuildingEffects.settler_arrival_modifiers); a fixed cooldown (shortened by Antenna Tower's
## cooldown_reduction_days, floor-clamped to at least 1 day) governs how often a roll is even
## attempted, advanced only on an ACTUAL roll attempt (never while the gate above skips it
## entirely — waiting for room to open up shouldn't burn the cooldown).
##
## The roll itself is split into small pure static functions (should_attempt_roll/roll_succeeds/
## next_arrival_day_after) fed plain values, and _process_arrival_tick() takes the random roll
## value as a PARAMETER rather than consulting RNG itself, specifically so tests/test_settlers.gd
## can force success/failure deterministically without touching global RNG state.
## _on_day_started() is the only real caller, supplying _rng.randf().
##
## -- Accept/reject --
## Reuses the existing dialogue box wholesale — zero player.gd changes (player.gd's use_tool()
## already resolves any NPC via npcs.npc_at() and emits npc_dialogue_requested regardless of
## what kind of NPC it is). The moment a visitor spawns, a short greeting + 2-choice branch is
## registered at runtime (dialogue_db.gd's new register_runtime, additive/in-memory only) whose
## choices land on the SETTLER_ACCEPT/SETTLER_REJECT sentinels dialogue_ui.gd recognizes exactly
## like OPEN_STORE_SENTINEL — landing on either emits dialogue_ui's new
## settler_decision_requested(npc, accepted), wired by main.gd to resolve_visitor() below.
##
## -- Save shape --
## A new additive top-level "settlers" key (scripts/save_data.gd's encode_settlers/
## decode_settlers) — {next_arrival_day, roster, pending_visitor}. No SAVE_VERSION bump (see
## save_data.gd's class doc: parse_save's exact-match check isn't touched, an old save simply
## decodes this new key as its empty default). load_state() re-spawns every roster member and
## any pending visitor as real NPC nodes in Town and re-registers their runtime dialogue trees —
## NPC state itself is never persisted elsewhere in this codebase (see npc.gd's class doc), but
## the settler ROSTER (who exists, their home cell) is genuine gameplay state that must survive
## a reload, unlike cosmetic wander position.

const BuildingEffects := preload("res://scripts/building_effects.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")
const SaveData := preload("res://scripts/save_data.gd")
const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")

## Base daily chance (before Watchtower's bonus) that a roll — once attempted at all — succeeds.
const BASE_ARRIVAL_CHANCE := 0.12
## Days between roll attempts (before Antenna Tower's reduction), floor-clamped in
## next_arrival_day_after() so it can never reach 0 or negative.
const BASE_COOLDOWN_DAYS := 3
## Same tight, disjoint wander zone every existing town-core NPC uses (layout_common.gd's
## TOWN_NPCS/RANCH_NPCS doc) — SETTLER_HOME_CELLS' spacing was chosen with this same radius.
const SETTLER_WANDER_RADIUS := 1

## Flavor first names for visiting settlers (GDD.md §9 tone: "people who have chosen hope and
## are a little funny about it") — picked at spawn time, purely cosmetic.
const SETTLER_NAMES := [
	"Ellery", "Doss", "Priya", "Fenn", "Roan", "Talia", "Mirek", "Sable",
]

## {id, name, home_cell, assigned_building}: assigned_building is always {} until Stage 4 wires
## the actual NPC-building assignment mechanic — carried here now purely as forward-compatible
## save shape (see save_data.gd's encode_settler_entry).
var roster: Array[Dictionary] = []
## {} when no visitor is currently waiting on a player decision; otherwise the same
## {id, name, home_cell} shape as a roster entry (minus assigned_building, which only exists
## once accepted).
var pending_visitor: Dictionary = {}
## The earliest day an arrival roll will even be ATTEMPTED (see class doc) — starts at 1 so the
## very first day_started (day 2, the first natural midnight rollover) is already eligible.
var next_arrival_day: int = 1

## Set in _ready() to get_parent() (Main) — see class doc's ordering note.
var _main: Node = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_main = get_parent()
	DayManager.day_started.connect(_on_day_started)


func _on_day_started(day: int) -> void:
	_process_arrival_tick(day, _rng.randf())


## -- Pure roll rules (headlessly testable — tests/test_settlers.gd feeds these fixed values
## rather than asserting on true randomness) --

## Whether an arrival roll should even be ATTEMPTED this day-tick. No fail state (cozy contract):
## never offers a visitor with nowhere to house them, and never stacks a second visitor on top of
## one still awaiting a decision. Distinct from roll_succeeds() below — this is the GATE, not the
## chance itself.
static func should_attempt_roll(day: int, next_arrival_day_value: int, has_pending_visitor: bool,
		roster_size: int, population_cap: int) -> bool:
	if day < next_arrival_day_value:
		return false
	if has_pending_visitor:
		return false
	if roster_size >= population_cap:
		return false
	return true


## Whether a roll of `roll_value` (caller: _rng.randf(), [0.0, 1.0)) succeeds against `chance`.
static func roll_succeeds(roll_value: float, chance: float) -> bool:
	return roll_value < chance


## The next cooldown floor day after an ATTEMPTED roll (success or failure — see class doc),
## shortened by Antenna Tower's cooldown_reduction_days and floor-clamped so the gap is always
## at least 1 day, never 0 or negative.
static func next_arrival_day_after(day: int, cooldown_reduction_days: int) -> int:
	return day + maxi(1, BASE_COOLDOWN_DAYS - cooldown_reduction_days)


## The live population cap, always freshly recomputed (never cached) from every completed
## building across all 4 zones — same "recompute in full" rule as player.max_energy (Stage 1).
func population_cap() -> int:
	var bonuses := BuildingEffects.recompute_capacity_unlocks(_main._all_completed_entries())
	return int(bonuses.get("population_cap", 0))


## The real day-tick entry point (called by _on_day_started with a live RNG roll); split out so
## tests can supply `roll_value` directly instead of touching _rng.
func _process_arrival_tick(day: int, roll_value: float) -> void:
	if not should_attempt_roll(day, next_arrival_day, not pending_visitor.is_empty(),
			roster.size(), population_cap()):
		return
	var modifiers := BuildingEffects.settler_arrival_modifiers(_main._all_completed_entries())
	var chance: float = BASE_ARRIVAL_CHANCE + float(modifiers.get("arrival_chance_bonus", 0.0))
	if roll_succeeds(roll_value, chance):
		_spawn_visitor()
	next_arrival_day = next_arrival_day_after(day, int(modifiers.get("cooldown_reduction_days", 0)))


## -- Visitor spawn / accept / reject --

## The next unused SETTLER_HOME_CELLS slot, skipping cells already claimed by the roster or a
## pending visitor. Falls back to cycling from the start if the fixed pool is ever exhausted
## (population cap growth is bounded by actual Shelter Cabins built, so this is a rare-edge
## fallback, not the common case) rather than crashing on an out-of-range read.
func _next_home_cell() -> Vector2i:
	var used := {}
	for entry in roster:
		used[entry.get("home_cell")] = true
	if not pending_visitor.is_empty():
		used[pending_visitor.get("home_cell")] = true
	for cell in LayoutCommon.SETTLER_HOME_CELLS:
		if not used.has(cell):
			return cell
	return LayoutCommon.SETTLER_HOME_CELLS[roster.size() % LayoutCommon.SETTLER_HOME_CELLS.size()]


## The next unique settler id, derived from the highest existing "settler_N" suffix across the
## roster + any pending visitor rather than a separately serialized counter — keeps the save
## shape to exactly {next_arrival_day, roster, pending_visitor} per the plan, with no extra field
## needed just to keep ids unique after a reload.
func _next_settler_id() -> String:
	var max_seq := 0
	for entry in roster:
		max_seq = maxi(max_seq, _seq_from_id(String(entry.get("id", ""))))
	if not pending_visitor.is_empty():
		max_seq = maxi(max_seq, _seq_from_id(String(pending_visitor.get("id", ""))))
	return "settler_%d" % (max_seq + 1)


static func _seq_from_id(id: String) -> int:
	if not id.begins_with("settler_"):
		return 0
	return int(id.trim_prefix("settler_"))


## Spawns a new visiting settler into the Town zone: a real wandering NPC (npcs.spawn_settler)
## plus a short greeting/accept-reject dialogue tree registered at runtime. Town specifically —
## population growth is a town-plaza concept (see class doc) — regardless of which zone's
## buildings actually unlocked the capacity.
func _spawn_visitor() -> void:
	var home_cell := _next_home_cell()
	var visitor_id := _next_settler_id()
	var visitor_name: String = SETTLER_NAMES[_rng.randi_range(0, SETTLER_NAMES.size() - 1)]
	pending_visitor = {"id": visitor_id, "name": visitor_name, "home_cell": home_cell}
	var town_npcs: Node = _main.zones["town"]["npcs"]
	town_npcs.spawn_settler(visitor_id, home_cell, SETTLER_WANDER_RADIUS)
	DialogueDB.register_runtime(visitor_id, _greeting_dialogue(visitor_name))


## Called by main.gd, wired to dialogue_ui.gd's settler_decision_requested signal. Defensive
## no-op if `npc` isn't actually the pending visitor (shouldn't happen in practice — the dialogue
## box can only be showing the greeting tree for the one currently-pending visitor — but the
## check keeps this safe against a stray/duplicate signal).
func resolve_visitor(npc: Node, accepted: bool) -> void:
	if pending_visitor.is_empty() or String(npc.npc_id) != String(pending_visitor.get("id", "")):
		return
	var visitor := pending_visitor
	pending_visitor = {}
	if accepted:
		roster.append({
			"id": visitor["id"], "name": visitor["name"], "home_cell": visitor["home_cell"],
			"assigned_building": {},
		})
		DialogueDB.unregister_runtime(String(visitor["id"]))
		DialogueDB.register_runtime(String(visitor["id"]), _settled_dialogue(String(visitor["name"])))
	else:
		# A player choice, never a punishment (cozy contract) — the visitor simply moves on.
		var town_npcs: Node = _main.zones["town"]["npcs"]
		town_npcs.despawn_npc(npc)
		DialogueDB.unregister_runtime(String(visitor["id"]))


## The visiting settler's greeting + accept/reject branch, registered at runtime the moment a
## visitor spawns (data/dialogue.json's exact node shape — see dialogue_db.gd's class doc).
func _greeting_dialogue(display_name: String) -> Dictionary:
	return {
		"name": display_name,
		"start": "greet",
		"nodes": {
			"greet": {
				"text": "Didn't mean to startle you. Word travels — you've got a settlement " \
					+ "worth joining, and I could use a roof that isn't made of sky. Room for one more?",
				"choices": [
					{"text": "Welcome aboard.", "next": "SETTLER_ACCEPT"},
					{"text": "Not right now.", "next": "SETTLER_REJECT"},
				],
			},
		},
	}


## A small permanent flavor tree for an accepted settler — no choices needed yet (Stage 4 adds
## the real building-assignment branch); just enough so talking to them isn't a dead no-op.
func _settled_dialogue(display_name: String) -> Dictionary:
	return {
		"name": display_name,
		"start": "settled",
		"nodes": {
			"settled": {
				"text": "Still can't believe my luck, finding this place. Put me to work " \
					+ "whenever there's something worth doing.",
			},
		},
	}


## -- Save/load (scripts/save_data.gd's encode_settlers/decode_settlers) --

func save_state() -> Dictionary:
	return SaveData.encode_settlers(next_arrival_day, roster, pending_visitor)


## Restores roster/pending-visitor state and re-spawns each as a real NPC node in Town, re-
## registering their runtime dialogue trees — mirrors structures.gd's load_state() re-deriving
## its own runtime side effects (block_cells) rather than trusting anything cached across a
## reload. Called by main.gd's _apply_save, itself followed by _recompute_capacity_unlocks() so
## the population cap this roster is checked against is never stale.
func load_state(data: Dictionary) -> void:
	var decoded := SaveData.decode_settlers(data)
	next_arrival_day = int(decoded["next_arrival_day"])
	roster = decoded["roster"]
	pending_visitor = decoded["pending_visitor"]
	var town_npcs: Node = _main.zones["town"]["npcs"]
	for entry in roster:
		town_npcs.spawn_settler(String(entry["id"]), entry["home_cell"], SETTLER_WANDER_RADIUS)
		DialogueDB.register_runtime(String(entry["id"]), _settled_dialogue(String(entry.get("name", ""))))
	if not pending_visitor.is_empty():
		town_npcs.spawn_settler(String(pending_visitor["id"]), pending_visitor["home_cell"],
			SETTLER_WANDER_RADIUS)
		DialogueDB.register_runtime(String(pending_visitor["id"]),
			_greeting_dialogue(String(pending_visitor.get("name", ""))))
