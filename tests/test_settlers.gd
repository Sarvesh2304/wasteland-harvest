extends "res://tests/test_case.gd"
## Phase 8 Stage 3 (settler arrivals + accept/reject): scripts/settlers.gd's pure roll rules,
## the day-tick gating (no visitor ever offered above the live population cap or while one is
## already pending — asserted deterministically by injecting a fixed roll value, per this
## codebase's headless-pure-function convention, rather than asserting on true randomness: no
## other system in this codebase rolls chance yet, so this is the first "inject the roll" test),
## the accept/reject state transitions, and the save/load round trip through
## scripts/save_data.gd's encode_settlers/decode_settlers.
##
## Unlike every other file in this suite that drives a real node against fully authored scene
## data, this one instantiates the real Settlers node directly against minimal fake stand-ins
## for Main/Npcs — the exact same "duck-typed fake, no scene file" convention
## tests/test_structures_fencing.gd established for scripts/structures.gd's `_test_map`.

const SettlersScript := preload("res://scripts/settlers.gd")
const BuildingDB := preload("res://scripts/building_db.gd")
const DialogueDB := preload("res://scripts/dialogue_db.gd")
const SaveData := preload("res://scripts/save_data.gd")


## Minimal completed-entry stand-in — same helper shape as tests/test_building_effects.gd's own
## _entry(), just duplicated here since GDScript test files can't share helpers across files.
static func _entry(building_id: String) -> Dictionary:
	return {"building_id": building_id, "kind": building_id, "top_left": Vector2i.ZERO,
		"size": Vector2i.ONE, "placed_day": 1}


## Fake settler NPC node: just enough surface (npc_id) for resolve_visitor()'s identity check
## and despawn_npc()'s bookkeeping — no real npc.gd instantiation needed (that would require a
## real TestMap/AnimatedSprite2D chain this file has no reason to build).
class FakeNpc:
	extends Node
	var npc_id := ""


## Fake Npcs node: implements exactly the duck-typed surface scripts/settlers.gd calls on
## `_main.zones["town"]["npcs"]` (spawn_settler/despawn_npc — the real npcs.gd's Phase 8 Stage 3
## additions). Tracks spawned ids so tests can assert on what settlers.gd actually asked for.
class FakeNpcs:
	extends Node
	var spawned: Array[Node] = []
	var spawn_calls: Array[Dictionary] = []

	func spawn_settler(id: String, home_cell: Vector2i, radius: int) -> Node:
		var npc := FakeNpc.new()
		npc.npc_id = id
		add_child(npc)  # so _free_env's cascade-free below also cleans up every spawned fake NPC
		spawned.append(npc)
		spawn_calls.append({"id": id, "home_cell": home_cell, "radius": radius})
		return npc

	func despawn_npc(npc: Node) -> void:
		spawned.erase(npc)


## Fake Main: implements exactly the duck-typed surface scripts/settlers.gd calls on `_main`
## (zones["town"]["npcs"] and _all_completed_entries()) — settlers.gd's own get_parent()-is-Main
## pattern (see its class doc), bypassed here the same way test_structures_fencing.gd bypasses
## structures.gd's _ready() entirely.
class FakeMain:
	extends Node
	var entries: Array = []
	var town_npcs: FakeNpcs
	var zones: Dictionary = {}

	func _init() -> void:
		town_npcs = FakeNpcs.new()
		add_child(town_npcs)
		zones = {"town": {"npcs": town_npcs}}

	func _all_completed_entries() -> Array:
		return entries


## Fresh Settlers node wired to a fresh fake main, bypassing _ready() entirely (which would
## expect a real DayManager-connected scene) — every test here drives _process_arrival_tick()/
## resolve_visitor()/save_state()/load_state() directly instead.
func _make_settlers(cap_entries: Array = []) -> Dictionary:
	var settlers := SettlersScript.new()
	var fake_main := FakeMain.new()
	fake_main.entries = cap_entries
	settlers._main = fake_main
	return {"settlers": settlers, "main": fake_main}


func _free_env(env: Dictionary) -> void:
	(env["settlers"] as Node).free()
	(env["main"] as Node).free()


## -- Pure roll rules --

func test_should_attempt_roll_true_when_everything_is_clear() -> void:
	assert_true(SettlersScript.should_attempt_roll(5, 5, false, 0, 2))


func test_should_attempt_roll_false_before_the_cooldown_floor() -> void:
	assert_false(SettlersScript.should_attempt_roll(4, 5, false, 0, 2),
		"day 4 is before next_arrival_day 5 — not due yet")


func test_should_attempt_roll_false_with_a_pending_visitor() -> void:
	assert_false(SettlersScript.should_attempt_roll(5, 5, true, 0, 2),
		"one visitor at a time, no queue")


func test_should_attempt_roll_false_at_or_above_population_cap() -> void:
	assert_false(SettlersScript.should_attempt_roll(5, 5, false, 2, 2),
		"never offered with nowhere to house them (roster at cap)")
	assert_false(SettlersScript.should_attempt_roll(5, 5, false, 3, 2),
		"roster already over cap (e.g. a Shelter Cabin was lost) still refuses")


func test_should_attempt_roll_false_at_zero_population_cap() -> void:
	assert_false(SettlersScript.should_attempt_roll(5, 5, false, 0, 0),
		"no Shelter Cabin built yet -> cap 0 -> never offered, even with an empty roster")


func test_roll_succeeds_is_a_strict_less_than_comparison() -> void:
	assert_true(SettlersScript.roll_succeeds(0.0, 0.12))
	assert_false(SettlersScript.roll_succeeds(0.12, 0.12), "exactly at the chance boundary fails")
	assert_false(SettlersScript.roll_succeeds(0.99, 0.12))


func test_next_arrival_day_after_applies_the_base_cooldown() -> void:
	assert_eq(SettlersScript.next_arrival_day_after(10, 0), 10 + SettlersScript.BASE_COOLDOWN_DAYS)


func test_next_arrival_day_after_floor_clamps_to_at_least_one_day() -> void:
	# Antenna Tower's reduction can't ever push the cooldown to 0 or negative.
	assert_eq(SettlersScript.next_arrival_day_after(10, SettlersScript.BASE_COOLDOWN_DAYS), 11)
	assert_eq(SettlersScript.next_arrival_day_after(10, 99), 11,
		"an oversized reduction still floor-clamps to a 1-day gap")


## -- _process_arrival_tick() gating (deterministic — fixed roll values, not real randomness) --

func test_arrival_tick_never_spawns_above_the_population_cap() -> void:
	# Zero completed Shelter Cabins -> population_cap() is 0 -> roster.size() (0) >= cap (0) ->
	# the gate refuses regardless of how favorable the injected roll is.
	var env := _make_settlers([])
	var settlers = env["settlers"]
	settlers._process_arrival_tick(1, 0.0)  # roll_value 0.0 would succeed against any chance > 0
	assert_true(settlers.pending_visitor.is_empty(), "no visitor offered with zero population cap")
	assert_eq((env["main"] as FakeMain).town_npcs.spawned.size(), 0, "no NPC was spawned")
	_free_env(env)


func test_arrival_tick_never_spawns_a_second_visitor_while_one_is_pending() -> void:
	var env := _make_settlers([_entry("shelter_tent")])  # population_cap 1
	var settlers = env["settlers"]
	settlers._process_arrival_tick(1, 0.0)  # first roll: guaranteed success
	assert_false(settlers.pending_visitor.is_empty(), "first visitor spawned")
	var first_id := String(settlers.pending_visitor["id"])
	var next_day_after_first: int = settlers.next_arrival_day
	settlers._process_arrival_tick(next_day_after_first, 0.0)  # would succeed again if attempted
	assert_eq(String(settlers.pending_visitor["id"]), first_id,
		"the pending visitor is unchanged — no second visitor stacked on top")
	assert_eq((env["main"] as FakeMain).town_npcs.spawned.size(), 1, "still exactly one spawned NPC")
	_free_env(env)


func test_arrival_tick_respects_the_cooldown_floor() -> void:
	var env := _make_settlers([_entry("shelter_tent")])
	var settlers = env["settlers"]
	settlers.next_arrival_day = 10
	settlers._process_arrival_tick(5, 0.0)  # day 5 < next_arrival_day 10 -> not due yet
	assert_true(settlers.pending_visitor.is_empty(), "no roll attempted before the cooldown floor")
	assert_eq(settlers.next_arrival_day, 10, "next_arrival_day untouched when the roll is skipped")
	_free_env(env)


func test_arrival_tick_advances_cooldown_on_a_failed_roll_too() -> void:
	var env := _make_settlers([_entry("shelter_tent")])
	var settlers = env["settlers"]
	var day_before: int = settlers.next_arrival_day
	settlers._process_arrival_tick(day_before, 0.999)  # guaranteed failure (chance well under 1.0)
	assert_true(settlers.pending_visitor.is_empty(), "a failed roll offers no visitor")
	assert_eq(settlers.next_arrival_day, day_before + SettlersScript.BASE_COOLDOWN_DAYS,
		"the cooldown still advances on an ATTEMPTED roll, success or failure")
	_free_env(env)


func test_arrival_tick_success_spawns_a_real_npc_and_registers_dialogue() -> void:
	var env := _make_settlers([_entry("shelter_tent")])
	var settlers = env["settlers"]
	settlers._process_arrival_tick(1, 0.0)
	assert_false(settlers.pending_visitor.is_empty())
	var visitor_id := String(settlers.pending_visitor["id"])
	var fake_npcs: FakeNpcs = (env["main"] as FakeMain).town_npcs
	assert_eq(fake_npcs.spawn_calls.size(), 1)
	assert_eq(String(fake_npcs.spawn_calls[0]["id"]), visitor_id)
	assert_eq(fake_npcs.spawn_calls[0]["home_cell"], settlers.pending_visitor["home_cell"])
	assert_true(DialogueDB.has_dialogue(visitor_id), "a runtime dialogue tree was registered")
	var start_id := DialogueDB.start_node_id(visitor_id)
	var node := DialogueDB.dialogue_node(visitor_id, start_id)
	var choices := DialogueDB.node_choices(node)
	assert_eq(choices.size(), 2, "the greeting is a 2-choice accept/reject branch")
	DialogueDB.unregister_runtime(visitor_id)  # test hygiene: don't leak into other test files
	_free_env(env)


## -- Accept/reject state transitions --

func test_resolve_visitor_accept_grows_the_roster_and_keeps_the_npc() -> void:
	var env := _make_settlers([_entry("shelter_tent")])
	var settlers = env["settlers"]
	settlers._process_arrival_tick(1, 0.0)
	var visitor_id := String(settlers.pending_visitor["id"])
	var npc: Node = (env["main"] as FakeMain).town_npcs.spawned[0]
	settlers.resolve_visitor(npc, true)
	assert_true(settlers.pending_visitor.is_empty(), "pending_visitor clears on a decision")
	assert_eq(settlers.roster.size(), 1, "the roster grew by one")
	assert_eq(String(settlers.roster[0]["id"]), visitor_id)
	assert_eq(settlers.roster[0]["assigned_building"], {}, "unassigned by default (Stage 4's job)")
	assert_true((env["main"] as FakeMain).town_npcs.spawned.has(npc),
		"the NPC is still there and never despawned on acceptance")
	assert_true(DialogueDB.has_dialogue(visitor_id),
		"a permanent flavor dialogue tree replaced the greeting")
	DialogueDB.unregister_runtime(visitor_id)
	_free_env(env)


func test_resolve_visitor_reject_despawns_and_clears() -> void:
	var env := _make_settlers([_entry("shelter_tent")])
	var settlers = env["settlers"]
	settlers._process_arrival_tick(1, 0.0)
	var visitor_id := String(settlers.pending_visitor["id"])
	var npc: Node = (env["main"] as FakeMain).town_npcs.spawned[0]
	settlers.resolve_visitor(npc, false)
	assert_true(settlers.pending_visitor.is_empty(), "pending_visitor clears on a decision")
	assert_eq(settlers.roster.size(), 0, "rejecting never adds to the roster")
	assert_false((env["main"] as FakeMain).town_npcs.spawned.has(npc),
		"the rejected visitor's NPC is gone")
	assert_false(DialogueDB.has_dialogue(visitor_id),
		"the runtime dialogue tree was unregistered, not left dangling")
	_free_env(env)


func test_resolve_visitor_ignores_a_decision_for_a_stale_or_wrong_npc() -> void:
	var env := _make_settlers([_entry("shelter_tent")])
	var settlers = env["settlers"]
	settlers._process_arrival_tick(1, 0.0)
	var real_visitor_id := String(settlers.pending_visitor["id"])
	var impostor := FakeNpc.new()
	impostor.npc_id = "not_the_pending_visitor"
	settlers.resolve_visitor(impostor, true)
	assert_false(settlers.pending_visitor.is_empty(),
		"a decision for the wrong npc id is a defensive no-op — the real pending visitor is untouched")
	assert_eq(settlers.roster.size(), 0)
	impostor.free()
	DialogueDB.unregister_runtime(real_visitor_id)
	_free_env(env)


## -- Save/load round trip (scripts/save_data.gd's encode_settlers/decode_settlers) --

func test_save_state_matches_saveData_encode_settlers() -> void:
	var env := _make_settlers([_entry("shelter_tent"), _entry("shelter_tent")])  # cap 2
	var settlers = env["settlers"]
	settlers._process_arrival_tick(1, 0.0)  # spawns visitor #1
	var first_npc: Node = (env["main"] as FakeMain).town_npcs.spawned[0]
	settlers.resolve_visitor(first_npc, true)  # roster gains 1
	settlers._process_arrival_tick(settlers.next_arrival_day, 0.0)  # spawns visitor #2 (pending)
	var saved: Dictionary = settlers.save_state()
	var expected := SaveData.encode_settlers(
		settlers.next_arrival_day, settlers.roster, settlers.pending_visitor)
	assert_eq(saved, expected)
	assert_eq(saved["roster"].size(), 1)
	assert_false((saved["pending_visitor"] as Dictionary).is_empty())
	for entry in settlers.roster:
		DialogueDB.unregister_runtime(String(entry["id"]))
	if not settlers.pending_visitor.is_empty():
		DialogueDB.unregister_runtime(String(settlers.pending_visitor["id"]))
	_free_env(env)


func test_load_state_restores_roster_and_pending_visitor_as_real_npcs() -> void:
	var saved := SaveData.encode_settlers(7, [
		{"id": "settler_1", "name": "Ellery", "home_cell": Vector2i(13, 7), "assigned_building": {}},
	], {"id": "settler_2", "name": "Doss", "home_cell": Vector2i(21, 7)})
	var env := _make_settlers([])
	var settlers = env["settlers"]
	settlers.load_state(saved)
	assert_eq(settlers.next_arrival_day, 7)
	assert_eq(settlers.roster.size(), 1)
	assert_eq(settlers.roster[0]["id"], "settler_1")
	assert_eq(settlers.roster[0]["home_cell"], Vector2i(13, 7))
	assert_eq(settlers.pending_visitor["id"], "settler_2")
	var fake_npcs: FakeNpcs = (env["main"] as FakeMain).town_npcs
	assert_eq(fake_npcs.spawned.size(), 2, "both the roster member and the pending visitor spawned")
	var spawned_ids := {}
	for npc in fake_npcs.spawned:
		spawned_ids[String(npc.npc_id)] = true
	assert_true(spawned_ids.has("settler_1"))
	assert_true(spawned_ids.has("settler_2"))
	assert_true(DialogueDB.has_dialogue("settler_1"), "roster member's dialogue tree re-registered")
	assert_true(DialogueDB.has_dialogue("settler_2"), "pending visitor's greeting tree re-registered")
	# The pending visitor's tree must still be the 2-choice greeting (not the settled flavor line).
	var pending_node := DialogueDB.dialogue_node("settler_2", DialogueDB.start_node_id("settler_2"))
	assert_eq(DialogueDB.node_choices(pending_node).size(), 2)
	# The roster member's tree must be the settled flavor line (no choices).
	var roster_node := DialogueDB.dialogue_node("settler_1", DialogueDB.start_node_id("settler_1"))
	assert_true(DialogueDB.node_choices(roster_node).is_empty())
	DialogueDB.unregister_runtime("settler_1")
	DialogueDB.unregister_runtime("settler_2")
	_free_env(env)


func test_load_state_with_empty_data_leaves_a_fresh_roster() -> void:
	var env := _make_settlers([])
	var settlers = env["settlers"]
	settlers.load_state({})
	assert_eq(settlers.next_arrival_day, 1, "an old save with no 'settlers' key defaults cleanly")
	assert_true(settlers.roster.is_empty())
	assert_true(settlers.pending_visitor.is_empty())
	assert_eq((env["main"] as FakeMain).town_npcs.spawned.size(), 0, "nothing spawned for an empty roster")
	_free_env(env)


## -- Settler id sequencing (settlers.gd's _next_settler_id / _seq_from_id) --

func test_next_settler_id_starts_at_one() -> void:
	var env := _make_settlers([_entry("shelter_tent")])
	var settlers = env["settlers"]
	settlers._process_arrival_tick(1, 0.0)
	assert_eq(String(settlers.pending_visitor["id"]), "settler_1")
	DialogueDB.unregister_runtime(String(settlers.pending_visitor["id"]))
	_free_env(env)


func test_next_settler_id_continues_after_a_restored_roster() -> void:
	var saved := SaveData.encode_settlers(3, [
		{"id": "settler_4", "name": "Roan", "home_cell": Vector2i(5, 6), "assigned_building": {}},
	], {})
	var env := _make_settlers([_entry("shelter_tent"), _entry("shelter_tent")])  # cap 2
	var settlers = env["settlers"]
	settlers.load_state(saved)
	settlers._process_arrival_tick(3, 0.0)  # cap allows one more (roster 1 < cap 2)
	assert_eq(String(settlers.pending_visitor["id"]), "settler_5",
		"the next id continues from the highest restored suffix, not from scratch")
	DialogueDB.unregister_runtime("settler_4")
	DialogueDB.unregister_runtime(String(settlers.pending_visitor["id"]))
	_free_env(env)
