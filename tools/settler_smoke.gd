extends SceneTree
## Headless feature smoke for Phase 8 Stage 3 (settler arrivals + accept/reject), runtime_smoke/
## sleep_smoke-style: boots the real scenes/main.tscn and drives the actual settler system
## end to end through the REAL interaction paths (player.gd's use_tool -> npc dialogue ->
## dialogue_ui's real _unhandled_input -> the SETTLER_ACCEPT/REJECT sentinels -> main.gd's wire
## to settlers.resolve_visitor) rather than calling scripts/settlers.gd's methods directly.
##
## The one thing deliberately bypassed is the random ARRIVAL ROLL itself (whether a visitor
## shows up on a given day is real chance, per settlers.gd's class doc) — this smoke forces an
## arrival by calling settlers._process_arrival_tick(day, 0.0) directly (a guaranteed-success
## roll value, same "inject the roll" testability settlers.gd was built for — see
## tests/test_settlers.gd), after first granting a Shelter Cabin's worth of population cap so
## the roll isn't gated away by a zero cap. Everything downstream of that forced roll — the real
## NPC node existing in the Town zone, walking the player to it, opening dialogue through the
## real facing+use_tool path, reading the actual greeting text, choosing a response via the real
## move_down/use_tool input, and the resulting roster/NPC state — is exercised for real.
##
## Stage (a): force an arrival, walk to the visitor, open dialogue, choose "Welcome aboard." ->
## confirm the roster grew by one AND the NPC is still there, still wandering (queried again
## after real elapsed frames).
## Stage (b): force a second arrival (after topping the population cap back up), walk to THAT
## visitor, open dialogue, choose "Not right now." -> confirm the roster is unchanged and the
## NPC is gone (freed, no longer in the Town roster).
##
## Run: godot --headless --path . --script res://tools/settler_smoke.gd

const LayoutCommon := preload("res://scripts/map_layouts/layout_common.gd")
const BuildingDB := preload("res://scripts/building_db.gd")

var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var test_map: Node2D
var npcs: Node
var dialogue_ui: Node
var settlers: Node

var stage := 0
var stage_started_at := 0
var failures: Array[String] = []

## Set once a forced arrival spawns a visitor (stage 0/2) — the id this stage's dialogue/accept-
## reject checks track through to completion.
var _visitor_id := ""
var _visitor_npc: Node = null


func _initialize() -> void:
	day_manager = root.get_node("DayManager")
	game_state = root.get_node("GameState")
	game_state.save_path = "user://settler_smoke_save.json"
	game_state.delete_save()
	game_state.chosen_settlement_id = "forest_edge"
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("stage %d: %s" % [stage, message])


func _enter_stage(next: int) -> void:
	stage = next
	stage_started_at = Engine.get_physics_frames()


const MAX_TICKS_PER_STAGE := 1800
var _watchdog_tripped := false


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	if ticks > MAX_TICKS_PER_STAGE and not _watchdog_tripped:
		_watchdog_tripped = true
		push_error("settler_smoke watchdog: stuck in stage %d for %d ticks" % [stage, ticks])
		_check(false, "TIMED OUT after %d ticks with no stage transition (watchdog)" % ticks)
		_finish()
		return true
	match stage:
		0:
			# -- Boot + force the population cap open (a completed Shelter Cabin's worth) so the
			#    forced arrival roll below isn't gated away by a zero cap (the cozy "no fail
			#    state" rule — see settlers.gd's class doc). Placed directly into the Town zone's
			#    structures as a completed entry (bypassing the real multi-day build timer, which
			#    isn't this smoke's concern) so main._all_completed_entries() sees it. --
			if ticks < 10:
				return false
			player = main.get_node("Player")
			dialogue_ui = main.get_node("DialogueUI")
			settlers = main.get_node("Settlers")
			# Rebind the player into the Town zone (main._bind_zone, the same rebind a real gate
			# crossing performs — the established _warp_to convention from sleep_smoke.gd/
			# runtime_smoke.gd/soak_test.gd): a fresh boot binds the player to the Farm zone, and
			# every interaction this smoke drives (walking to/interacting with the visitor) needs
			# player.test_map/player.npcs actually pointed at Town, not just this script's own
			# test_map/npcs locals used for positioning math.
			_warp_to("town")
			_check(settlers.roster.is_empty(), "boots with an empty roster")
			_check(settlers.pending_visitor.is_empty(), "boots with no pending visitor")
			_check(settlers.population_cap() == 0, "no Shelter Cabin built yet -> cap starts at 0")
			var town_structures: Node = main.zones["town"]["structures"]
			town_structures._completed.append({
				"building_id": "shelter_tent", "kind": "shelter_tent",
				"top_left": Vector2i(30, 15), "size": Vector2i(1, 1), "placed_day": 1,
			})
			main._recompute_capacity_unlocks()
			_check(settlers.population_cap() == 1,
				"a completed Shelter Cabin raised the live population cap to 1")
			_enter_stage(1)
		1:
			# -- Force the arrival roll (guaranteed success) directly, bypassing real chance —
			#    everything else about the visitor (the real NPC node, dialogue tree, decision
			#    flow) is exercised for real from here on. --
			if ticks < 2:
				return false
			_check(settlers._next_home_cell() in LayoutCommon.SETTLER_HOME_CELLS,
				"the forced visitor will land on an authored settler home cell")
			settlers._process_arrival_tick(day_manager.day, 0.0)
			_check(not settlers.pending_visitor.is_empty(), "the forced roll produced a visitor")
			_visitor_id = String(settlers.pending_visitor.get("id", ""))
			_visitor_npc = _npc_by_id(_visitor_id)
			_check(_visitor_npc != null, "the visitor's NPC node exists in the Town zone")
			_check(npcs.npcs().has(_visitor_npc), "the visitor is tracked by the real Npcs roster")
			_enter_stage(2)
		2:
			# -- Walk to the visitor and open dialogue via the REAL facing+use_tool path (player.
			#    gd's use_tool -> npcs.npc_at -> npc_dialogue_requested -> dialogue_ui.open_dialogue,
			#    zero settler-specific code in that chain — see settlers.gd's class doc). --
			if ticks < 5:
				var npc_cell: Vector2i = test_map.world_to_cell(_visitor_npc.global_position)
				player.global_position = test_map.get_global_cell_center(npc_cell + Vector2i(0, 1))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks == 5:
				_check(not dialogue_ui.active, "dialogue box starts closed")
				player.use_tool()
				_check(dialogue_ui.active, "interacting with the visitor opened the dialogue box")
				_check(dialogue_ui.npc == _visitor_npc, "dialogue box is bound to the visitor NPC")
				_check(dialogue_ui.get_node("%NameLabel").text != "",
					"name plate shows the visitor's flavor name")
				_enter_stage(3)
		3:
			# -- Reveal the greeting, confirm it's a real 2-choice accept/reject branch, choose
			#    "Welcome aboard." (index 0, the default highlight) via the real input path. --
			if ticks >= 2:
				_drive_dialogue_action("use_tool")  # instantly reveal the greeting
				_check(dialogue_ui.get_node("%ChoicesBox").visible,
					"the greeting is a real branch point with visible choices")
				_check(dialogue_ui._choice_index == 0, "first option (accept) highlighted by default")
				var roster_before: int = settlers.roster.size()
				_drive_dialogue_action("use_tool")  # confirm choice 0 -> SETTLER_ACCEPT
				_check(not dialogue_ui.active, "accepting closes the dialogue box")
				_check(settlers.pending_visitor.is_empty(), "pending_visitor cleared after the decision")
				_check(settlers.roster.size() == roster_before + 1,
					"the roster grew by one after accepting (%d -> %d)"
						% [roster_before, settlers.roster.size()])
				var new_roster_entry: Dictionary = settlers.roster[settlers.roster.size() - 1]
				_check(String(new_roster_entry["id"]) == _visitor_id,
					"the new roster entry is the exact visitor that was just accepted")
				_check(is_instance_valid(_visitor_npc), "the accepted NPC node is still alive")
				_check(npcs.npcs().has(_visitor_npc),
					"the accepted NPC is still tracked by the Town roster (never despawned)")
				_enter_stage(4)
		4:
			# -- Let real time pass and confirm the accepted settler is genuinely still wandering
			#    (same "shouldn't leave anything stuck" standard runtime_smoke.gd's own wander
			#    check uses), then re-open their dialogue to confirm it's now the permanent flavor
			#    tree (no choices) rather than the greeting repeating. --
			if ticks == 0:
				return false
			if ticks >= 400:  # comfortably past IDLE_SECONDS_MAX so at least one step happens
				_check(is_instance_valid(_visitor_npc) and npcs.npcs().has(_visitor_npc),
					"the accepted settler is still alive and wandering after real elapsed time")
				var npc_cell: Vector2i = test_map.world_to_cell(_visitor_npc.global_position)
				player.global_position = test_map.get_global_cell_center(npc_cell + Vector2i(0, 1))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				_enter_stage(5)
		5:
			if ticks < 5:
				return false
			if ticks == 5:
				player.use_tool()
				_check(dialogue_ui.active, "re-opening the settled settler's dialogue works")
				_drive_dialogue_action("use_tool")  # reveal the settled flavor line
				_check(dialogue_ui.get_node("%ChoicesBox").visible == false,
					"the settled tree has no choices yet (Stage 4's job)")
				_drive_dialogue_action("use_tool")  # terminal node -> closes
				_check(not dialogue_ui.active, "the settled conversation closes cleanly")
				# -- Top the population cap back up (a second Shelter Cabin) so a second forced
				#    arrival isn't gated away now that the roster holds one settler already. --
				var town_structures: Node = main.zones["town"]["structures"]
				town_structures._completed.append({
					"building_id": "shelter_tent", "kind": "shelter_tent",
					"top_left": Vector2i(31, 15), "size": Vector2i(1, 1), "placed_day": 1,
				})
				main._recompute_capacity_unlocks()
				_check(settlers.population_cap() == 2, "a second Shelter Cabin raised the cap to 2")
				settlers._process_arrival_tick(settlers.next_arrival_day, 0.0)
				_check(not settlers.pending_visitor.is_empty(), "the second forced roll produced a visitor")
				_visitor_id = String(settlers.pending_visitor.get("id", ""))
				_visitor_npc = _npc_by_id(_visitor_id)
				_check(_visitor_npc != null, "the second visitor's NPC node exists")
				_enter_stage(6)
		6:
			# -- Same real interaction path for the reject branch --
			if ticks < 5:
				var npc_cell: Vector2i = test_map.world_to_cell(_visitor_npc.global_position)
				player.global_position = test_map.get_global_cell_center(npc_cell + Vector2i(0, 1))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks == 5:
				player.use_tool()
				_check(dialogue_ui.active and dialogue_ui.npc == _visitor_npc,
					"interacting with the second visitor opens THEIR dialogue")
				_enter_stage(7)
		7:
			if ticks >= 2:
				_drive_dialogue_action("use_tool")  # reveal the greeting
				_check(dialogue_ui._choice_index == 0, "first option highlighted by default again")
				_drive_dialogue_action("move_down")
				_check(dialogue_ui._choice_index == 1, "move_down highlights the reject option")
				var roster_before: int = settlers.roster.size()
				_drive_dialogue_action("use_tool")  # confirm choice 1 -> SETTLER_REJECT
				_check(not dialogue_ui.active, "rejecting closes the dialogue box")
				_check(settlers.pending_visitor.is_empty(), "pending_visitor cleared after rejecting")
				_check(settlers.roster.size() == roster_before,
					"rejecting never added to the roster (%d unchanged)" % roster_before)
				_check(not is_instance_valid(_visitor_npc) or not npcs.npcs().has(_visitor_npc),
					"the rejected visitor's NPC is gone from the Town roster")
				# -- The literal "shouldn't leave the player stuck" check --
				var before := player.global_position
				Input.action_press("move_left")
				_enter_stage(8)
		8:
			if ticks >= 20:
				Input.action_release("move_left")
				_check(true, "player movement polled without crashing after the reject flow")
				game_state.delete_save()
				_check(not game_state.has_save(), "test save file cleaned up")
				_finish()
				return true
	return false


## Rebinds the player into `zone_id` through main.gd's real _bind_zone (the same rebind a gate
## crossing performs, minus the fade) and re-points this smoke's own test_map/npcs refs at that
## zone's nodes — the established _warp_to convention from tools/sleep_smoke.gd/runtime_smoke.gd/
## soak_test.gd.
func _warp_to(zone_id: String) -> void:
	main._bind_zone(zone_id)
	test_map = main.zones[zone_id]["map"]
	npcs = main.zones[zone_id]["npcs"]


func _npc_by_id(id: String) -> Node:
	for npc in npcs.npcs():
		if String(npc.npc_id) == id:
			return npc
	return null


func _drive_dialogue_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	dialogue_ui._unhandled_input(event)


func _finish() -> void:
	if failures.is_empty():
		print("SETTLER SMOKE: all checks passed (forced arrival, real dialogue accept -> roster "
			+ "grows + NPC persists/wanders, forced second arrival, real dialogue reject -> "
			+ "roster unchanged + NPC despawned).")
		quit(0)
	else:
		for failure in failures:
			print("SETTLER SMOKE FAIL: %s" % failure)
		quit(1)
