extends SceneTree
## Headless feature smoke for the 2026-07-11 Stardew-style forced-sleep rules (direct playtest
## feedback from Sarvesh — see GDD.md §4 "The night rules" / ROADMAP.md Phase 3's enhancement
## note). Per-mechanism proof, runtime_smoke.gd-style, of the whole night-rules surface in one
## live scene:
##
##   (a) SLEEPY ONSET — crossing midnight awake starts the passive energy drain at exactly
##       SLEEPY_DRAIN_PER_GAME_MINUTE and raises the HUD's "GETTING SLEEPY..." cue (hidden
##       again by morning).
##   (b) 2 AM CUTOFF — reaching 2 AM awake forces a pass-out REGARDLESS of the energy left in
##       the bar (asserted ~90 here), waking at 6:00 AM of the SAME calendar day (the counter
##       already rolled at midnight — the after-midnight skip fix), with the run auto-saved.
##   (c) COFFEE — eaten through the real hotbar-select + use_tool consume path, Scav-Brew
##       Coffee suppresses that night's 2 AM cutoff: the player sails through 2 AM, the charge
##       is spent on surviving to 6 AM, and the NEXT night's 2 AM collapses them as normal
##       (the spec's "a full 24 hours awake still passes out at 2 AM that night"). General
##       food-eating is proven on the same path (Preserved Rations restore exactly 25).
##   (d) SAVE-ON-PASS-OUT — the ORIGINAL zero-energy pass-out now auto-saves too (the spec's
##       "progress saved when the player falls asleep OR passes out"; previously bed-only), and
##       the drain itself can be what zeroes the bar, without double-firing the day transition
##       (exactly one save per collapse).
##   (e) TIME-PAUSED INTERPLAY — 2 AM cannot arrive mid-conversation: a real NPC dialogue holds
##       the clock at 1:58 AM indefinitely (via main.gd's modal-gate poll), and only after the
##       dialogue closes do real frames carry the clock into the cutoff.
##
## Clock-manipulation convention: teleports (direct minutes_into_day writes) position scenes
## and legitimately DON'T count as lived time (DayManager.time_advanced never fires for them);
## all lived time runs through advance_minutes() — 1-minute ticks inside a single synchronous
## block for exact-arithmetic stages, or real _process frames for stage (e).
##
## Run: godot --headless --path . --script res://tools/sleep_smoke.gd
## Uses a test-only save filename, deleted before and after (the standing hygiene rule).

var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var test_map: Node
var npcs: Node
var dialogue_ui: Node
var hud: CanvasLayer
var sleepy_label: Label

var stage := 0
var stage_started_at := 0
var failures: Array[String] = []
## game_saved emissions observed since the last counter reset — stage (d)'s double-fire check.
var _saves_seen := 0
## Day the paused-dialogue stage froze the clock on, checked across real frames in stage (e).
var _paused_day := 0


func _initialize() -> void:
	day_manager = root.get_node("DayManager")
	game_state = root.get_node("GameState")
	game_state.save_path = "user://sleep_smoke_save.json"
	game_state.delete_save()
	game_state.game_saved.connect(func() -> void: _saves_seen += 1)
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


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	match stage:
		0:
			# -- Boot --
			if ticks < 10:
				return false
			player = main.get_node("Player")
			test_map = main.get_node("TestMap")
			npcs = test_map.get_node("Npcs")
			dialogue_ui = main.get_node("DialogueUI")
			hud = main.get_node("HUD")
			sleepy_label = hud.get_node("%SleepyLabel")
			_check(player.energy == player.max_energy, "boots at full energy")
			_check(not player.stay_awake_tonight, "boots with no stay-awake charge")
			_enter_stage(1)
		1:
			# -- (a) Sleepy onset: cross midnight awake, drain + cue appear --
			if ticks < 5:
				return false
			if ticks == 5:
				_check(not sleepy_label.visible, "sleepy cue hidden during the day")
				var day_before: int = day_manager.day
				var energy_before: float = player.energy
				day_manager.minutes_into_day = 1435.0  # 11:55 PM, a teleport (not lived time)
				for i in 70:  # 11:55 PM -> 1:05 AM, lived 1-minute ticks
					day_manager.advance_minutes(1.0)
				_check(day_manager.day == day_before + 1, "midnight rolled the day counter")
				_check(day_manager.clock_text() == "1:05 AM", "clock reads 1:05 AM")
				_check(sleepy_label.visible, "GETTING SLEEPY cue visible past midnight")
				var expected: float = energy_before \
					- day_manager.minutes_into_day * player.SLEEPY_DRAIN_PER_GAME_MINUTE
				_check(absf(player.energy - expected) < 0.0001,
					"drain charged exactly the post-midnight minutes (expected %.4f, got %.4f)"
						% [expected, player.energy])
				_check(player.energy > 85.0, "pre-midnight ticks were free (only ~9.75 drained)")
				_enter_stage(2)
		2:
			# -- (b) The 2 AM cutoff: forced pass-out with ~90 energy in the bar, same-day
			#    6 AM wake, auto-saved --
			if ticks < 5:
				return false
			if ticks == 5:
				_check(not game_state.has_save(), "provably save-free before the forced pass-out")
				var day_before: int = day_manager.day
				var energy_before: float = player.energy
				_check(energy_before > 85.0,
					"energy is nowhere near zero going into 2 AM (%.2f)" % energy_before)
				var guard := 0
				while day_manager.minutes_into_day < 120.0 and guard < 200:
					day_manager.advance_minutes(1.0)
					guard += 1
				_check(day_manager.clock_text() == "6:00 AM",
					"2 AM forced a pass-out and woke the player at 6:00 AM")
				_check(day_manager.day == day_before,
					"woke on the SAME calendar day (midnight already rolled it — no skipped day)")
				_check(player.energy == player.max_energy, "woke rested")
				_check(game_state.has_save(), "the forced pass-out auto-saved")
				_check(not sleepy_label.visible, "sleepy cue cleared on waking")
				_enter_stage(3)
		3:
			# -- (c) Coffee (and general food) through the REAL consume path, then a protected
			#    all-nighter and the unprotected collapse the following night --
			if ticks < 5:
				# Face plain grass at (5,20) (clear of every NPC wander zone — the soak's
				# clearance rule) so use_tool falls through to the hotbar-item dispatch.
				player.global_position = test_map.cell_to_world_center(Vector2i(5, 19))
				player.velocity = Vector2.ZERO
				player.facing = "south"
				return false
			if ticks == 5:
				player.set_energy(50.0)
				# Forest Edge's starting bonus (wood/scrap/stone) fills hotbar slots 6-8; clear
				# two of them so the consumables land somewhere number-key-selectable — eating
				# is a hotbar interaction by design.
				player.inventory.remove_item("scrap_metal", 99)
				player.inventory.remove_item("stone", 99)
				player.inventory.add_item("preserved_food", 1)
				player.inventory.add_item("coffee", 1)
				var food_slot := _hotbar_index_of("preserved_food")
				var coffee_slot := _hotbar_index_of("coffee")
				_check(food_slot >= 0 and coffee_slot >= 0,
					"both consumables landed in hotbar slots")
				# General food first: Preserved Rations restore exactly 25.
				player.inventory.select_hotbar(food_slot)
				player.use_tool()
				_check(player.inventory.count_of("preserved_food") == 0, "rations were consumed")
				_check(player.energy == 75.0,
					"eating restored exactly energy_restored (50 + 25 = 75, got %.2f)" % player.energy)
				_check(not player.stay_awake_tonight, "ordinary food grants no stay-awake charge")
				# Now the coffee: +10 energy AND tonight's 2 AM suppression.
				player.inventory.select_hotbar(coffee_slot)
				player.use_tool()
				_check(player.inventory.count_of("coffee") == 0, "coffee was consumed")
				_check(player.energy == 85.0, "coffee restored its 10 energy (75 + 10 = 85)")
				_check(player.stay_awake_tonight, "coffee armed the stay-awake charge")
				# The protected night: teleport to 11:55 PM, live straight through 2 AM.
				var day_before: int = day_manager.day
				day_manager.minutes_into_day = 1435.0
				for i in 185:  # -> 3:00 AM, straight past the cutoff
					day_manager.advance_minutes(1.0)
				_check(day_manager.day == day_before + 1 \
						and day_manager.clock_text() == "3:00 AM",
					"coffee carried the player past 2 AM (clock %s)" % day_manager.clock_text())
				_check(player.stay_awake_tonight, "charge still live mid-night")
				_check(absf(player.energy - (85.0 - 27.0)) < 0.0001,
					"the drain never stopped — coffee beats the clock, not the fatigue")
				for i in 180:  # -> 6:00 AM, surviving the night
					day_manager.advance_minutes(1.0)
				_check(day_manager.clock_text() == "6:00 AM" \
						and day_manager.day == day_before + 1,
					"reached 6 AM awake, never passed out")
				_check(not player.stay_awake_tonight, "surviving to 6 AM spent the charge")
				_check(not sleepy_label.visible, "sleepy cue down again by morning")
				_check(absf(player.energy - 31.0) < 0.0001,
					"full-night drain totalled 54 (85 - 54 = 31, got %.4f)" % player.energy)
				# The spec's kicker: a full 24 hours awake still collapses at the NEXT 2 AM.
				player.set_energy(80.0)  # top up so the second night can't zero the bar early
				var guard := 0
				while day_manager.day == day_before + 1 and guard < 2000:
					day_manager.advance_minutes(1.0)  # live through the whole next day
					guard += 1
				while day_manager.minutes_into_day < 120.0 and guard < 2400:
					day_manager.advance_minutes(1.0)
					guard += 1
				_check(day_manager.clock_text() == "6:00 AM" \
						and day_manager.day == day_before + 2,
					"the NEXT night's 2 AM collapsed the player as normal (charge was one-night)")
				_check(player.energy == player.max_energy, "woke rested after the collapse")
				_enter_stage(4)
		4:
			# -- (d) Save-on-pass-out for the ORIGINAL zero-energy rule, including the drain
			#    itself zeroing the bar, with exactly ONE day transition + save per collapse --
			if ticks < 5:
				return false
			if ticks == 5:
				# Plain daytime zero-energy pass-out (the Phase 3 rule) must now save.
				day_manager.minutes_into_day = 720.0  # noon teleport
				game_state.delete_save()
				_saves_seen = 0
				var day_before: int = day_manager.day
				player.set_energy(3.0)
				player.set_energy(-50.0)
				_check(day_manager.day == day_before + 1 \
						and day_manager.clock_text() == "6:00 AM",
					"daytime zero-energy pass-out still skips to next morning")
				_check(game_state.has_save(), "the zero-energy pass-out auto-saved")
				_check(_saves_seen == 1, "exactly one save landed (got %d)" % _saves_seen)
				# And the sleepy drain itself zeroing the bar past midnight: one collapse, one
				# save, no double-fired transition from the stale-clock re-read in
				# _on_time_advanced.
				game_state.delete_save()
				_saves_seen = 0
				day_before = day_manager.day
				player.set_energy(4.0)  # zeroes at ~27 minutes past midnight, before 2 AM
				day_manager.minutes_into_day = 1439.0
				for i in 40:
					day_manager.advance_minutes(1.0)
				_check(day_manager.day == day_before + 1,
					"the drain-collapse night cost exactly one calendar day")
				_check(player.energy == player.max_energy, "woke rested from the drain collapse")
				_check(game_state.has_save(), "the drain-triggered pass-out auto-saved")
				_check(_saves_seen == 1,
					"exactly one save — no double-fired transition (got %d)" % _saves_seen)
				_enter_stage(5)
		5:
			# -- (e) Time-paused interplay: 2 AM cannot arrive mid-conversation --
			if ticks < 5:
				var npc: Node = _npc_by_id("scout_kael")
				player.global_position = test_map.cell_to_world_center(
					test_map.world_to_cell(npc.global_position) + Vector2i(0, 1))
				player.velocity = Vector2.ZERO
				player.facing = "north"
				return false
			if ticks == 5:
				day_manager.minutes_into_day = 118.0  # 1:58 AM, two minutes from the cutoff
				_paused_day = day_manager.day
				player.use_tool()
				_check(dialogue_ui.active, "dialogue opened at 1:58 AM")
				return false
			if ticks == 90:  # ~1.4 real s of frames — over 1.4 game-minutes if time were running
				_check(dialogue_ui.active, "still mid-conversation")
				_check(day_manager.time_paused, "the modal gate froze the clock")
				_check(day_manager.minutes_into_day < 119.0,
					"the clock is holding at ~1:58 AM (%.3f) — 2 AM is NOT arriving mid-dialogue"
						% day_manager.minutes_into_day)
				_check(day_manager.day == _paused_day, "no pass-out fired while frozen")
				var guard := 0
				while dialogue_ui.active and guard < 20:
					_drive(dialogue_ui, "use_tool")
					guard += 1
				_check(not dialogue_ui.active, "conversation closed cleanly")
				return false
			if ticks >= 330:  # ~4 real s after the close: the clock lived ~2+ minutes to 2 AM
				# The clock keeps running after the wake-up, so assert the morning band rather
				# than the exact 6:00 text (real frames have already nudged it to ~6:02).
				_check(day_manager.minutes_into_day >= 360.0 \
						and day_manager.minutes_into_day < 420.0 \
						and day_manager.day == _paused_day,
					"once the dialogue closed, real frames carried the clock into the 2 AM "
					+ "cutoff and the 6 AM wake (clock %s, day %d)"
						% [day_manager.clock_text(), day_manager.day])
				_check(player.energy == player.max_energy, "woke rested")
				game_state.delete_save()
				_check(not game_state.has_save(), "test save file cleaned up")
				_finish()
				return true
		_:
			pass
	return false


func _hotbar_index_of(item_id: String) -> int:
	for i in player.inventory.HOTBAR_SIZE:
		if String(player.inventory.get_slot(i).get("item_id", "")) == item_id:
			return i
	return -1


func _npc_by_id(id: String) -> Node:
	for npc in npcs.npcs():
		if String(npc.npc_id) == id:
			return npc
	return null


## Fabricated action event through a node's real _unhandled_input — the established convention
## from tools/runtime_smoke.gd / tools/soak_test.gd.
func _drive(node: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	node._unhandled_input(event)


func _finish() -> void:
	if failures.is_empty():
		print("SLEEP SMOKE: all checks passed (onset drain+cue, 2 AM cutoff+save, coffee night, "
			+ "zero-energy saves, paused-clock interplay).")
		quit(0)
	else:
		for failure in failures:
			print("SLEEP SMOKE FAIL: %s" % failure)
		quit(1)
