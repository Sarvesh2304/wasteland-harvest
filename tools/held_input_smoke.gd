extends SceneTree
## Headless regression smoke for the 2026-07-10 playtest bug-fix session: real HELD-key input
## (Input.action_press spanning many physics frames — how a human tap/hold actually reads at
## 60fps, unlike the per-call player.use_tool() the other tools drive) against the four reported
## bug shapes, plus the session's three UX additions. Kept separate from tools/runtime_smoke.gd
## (feature contracts) and tools/soak_test.gd (multi-day integration) per their own split
## rationale: this file's whole job is input-timing regressions, which need held-key stages
## neither of those files' conventions produce.
##
## The four originally-reported symptoms, each reproduced and asserted fixed:
##   (a) A held "use_tool" press facing the BED slept several days at once -> stage 1 holds the
##       key ~20 physics frames and asserts the day advanced EXACTLY once (stage 2 then proves a
##       fresh release+press still sleeps again — once per discrete press, not once ever).
##   (b) Closing a DIALOGUE at its terminal node instantly reopened it -> stage 3 pairs the
##       closing press with the held polled action (the real coupling: one physical press both
##       feeds _unhandled_input and the poll) and asserts the box stays closed while held.
##   (c) The STORE's "Leave" row reopened Marta's conversation -> stage 4, same paired-press
##       shape, asserts neither the store nor the dialogue comes back while the key stays down.
##   (d) The SHIPPING BOX's "Leave" row "reset to the top row" (really: closed and instantly
##       reopened with _index back at 0) -> stage 5, same shape, asserts it stays closed.
##
## The session's UX additions:
##   - Esc (ui_cancel) closes dialogue/store/shipping, the in-game tabbed menu (which owns
##     "toggle_inventory" since 2026-07-12 — see scripts/menu_screen.gd), and the HUD's chest
##     grid (stage 6, through each node's real _unhandled_input).
##   - The chest/storage grid auto-closes when the player walks beyond hud.gd's
##     CHEST_CLOSE_DISTANCE, and NOT when merely shuffling beside the chest (stage 7).
##   - Time pauses while a modal UI is open, resumes on close, and deliberately does NOT pause
##     for build mode; the in-game menu is a true modal, so it DOES pause (stage 8 — before the
##     2026-07-12 menu this slot checked the old passive backpack grid, which didn't).
##
## Run: godot --headless --path . --script res://tools/held_input_smoke.gd
##
## Input-timing note (verified empirically before this session's fix was designed): an
## Input.action_press() issued from this SceneTree script's _physics_process is visible to the
## player's poll in the SAME physics frame (SceneTree scripts run before node callbacks), while
## Input.is_action_just_pressed() only reads true one frame later — one of the two reasons the
## fix uses player.gd's explicit press-edge latch instead of just-pressed (the other, bigger one:
## a real event dispatched to _unhandled_input between physics frames still reads just-pressed on
## the NEXT poll, which would have re-opened every "closed by this press" UI once per tap).
##
## Zone split (the Farm/Path/Town/Ranch scene separation — this file's Stage 3 sweep): world
## refs come from main.zones (the old single TestMap node is gone), the NPC stages warp to the
## TOWN zone first (every town-core NPC lives there now; the farm roster is empty), the
## bed/box/chest stages warp back home, and positioning goes through get_global_cell_center
## since zones sit at sibling world offsets. Warps ride main._bind_zone directly — the literal
## gate-cell walk is runtime_smoke/soak_test/zone_transition_smoke's job, not an input-timing
## concern.

const DialogueDB := preload("res://scripts/dialogue_db.gd")

const CHEST_STAND := Vector2i(16, 5)   # facing north -> chest at (16,4)
const BOX_STAND := Vector2i(17, 5)     # facing north -> shipping box at (17,4)
const BED_STAND := Vector2i(18, 5)     # facing north -> bed at (18,4)

var game_state: Node
var day_manager: Node
var main: Node
var player: CharacterBody2D
var test_map: Node
var structures: Node
var builder: Node2D
var npcs: Node
var dialogue_ui: Node
var store_ui: Node
var shipping_ui: Node
var menu_screen: Node
var hud: CanvasLayer

var stage := 0
var stage_started_at := 0
var failures: Array[String] = []
var _day_before := 0
var _minutes_snapshot := 0.0


func _initialize() -> void:
	day_manager = root.get_node("DayManager")
	game_state = root.get_node("GameState")
	game_state.world_spawning_enabled = false
	root.get_node("DayManager").forced_weather = "clear"
	# Bed sleeps auto-save: test-only path, cleared before and after (the same hard hygiene
	# requirement runtime_smoke.gd/soak_test.gd document).
	game_state.save_path = "user://held_input_smoke_save.json"
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


## Watchdog (ported from tools/runtime_smoke.gd/soak_test.gd — sleep_smoke.gd hung for real on
## the zone split's removed TestMap node, a per-frame crash loop spinning silently forever, and
## this file fetched the same stale node). Comfortably above the longest legitimate in-stage
## wait here (115 ticks) so it never fires on a healthy run, but guarantees any future stall
## fails LOUDLY with the exact stuck stage.
const MAX_TICKS_PER_STAGE := 1800
var _watchdog_tripped := false


func _physics_process(_delta: float) -> bool:
	var ticks := int(Engine.get_physics_frames()) - stage_started_at
	if ticks > MAX_TICKS_PER_STAGE and not _watchdog_tripped:
		_watchdog_tripped = true
		push_error("held_input_smoke watchdog: stuck in stage %d for %d ticks" % [stage, ticks])
		_check(false, "TIMED OUT after %d ticks with no stage transition (watchdog)" % ticks)
		_finish()
		return true
	match stage:
		0:
			if ticks < 10:
				return false
			player = main.get_node("Player")
			# Zone split: world refs come from main.zones; boot binds the FARM zone.
			test_map = main.zones["farm"]["map"]
			structures = main.zones["farm"]["structures"]
			npcs = main.zones["farm"]["npcs"]
			builder = main.get_node("Builder")
			dialogue_ui = main.get_node("DialogueUI")
			store_ui = main.get_node("StoreUI")
			shipping_ui = main.get_node("ShippingUI")
			menu_screen = main.get_node("MenuScreen")
			hud = main.get_node("HUD")
			_enter_stage(1)
		1:
			# -- (a) A held press facing the bed sleeps EXACTLY one day --
			if ticks < 5:
				_stand(BED_STAND, "north")
				return false
			if ticks == 5:
				_check(structures.is_bed_at(Vector2i(18, 4)), "bed is at its authored cell")
				_day_before = day_manager.day
				Input.action_press("use_tool")  # held from here through tick 25 (~1/3s hold)
				return false
			if ticks == 15:
				_check(day_manager.day == _day_before + 1,
					"mid-hold: the day advanced exactly once (day %d -> %d)" \
						% [_day_before, day_manager.day])
				return false
			if ticks == 25:
				Input.action_release("use_tool")
				_check(day_manager.day == _day_before + 1,
					"after a ~20-frame hold the day STILL advanced exactly once, not per frame " \
						+ "(day %d -> %d)" % [_day_before, day_manager.day])
				_check(day_manager.clock_text() == "6:00 AM", "woke at 6:00 AM")
				_check(player.energy == player.max_energy, "woke rested")
				_enter_stage(2)
		2:
			# -- Release + fresh press sleeps AGAIN: the latch re-arms per discrete press --
			if ticks == 2:  # >=1 released frame has passed, so the latch re-armed
				_day_before = day_manager.day
				Input.action_press("use_tool")
				return false
			if ticks == 8:
				Input.action_release("use_tool")
				_check(day_manager.day == _day_before + 1,
					"a fresh discrete press sleeps one more day (day %d -> %d)" \
						% [_day_before, day_manager.day])
				_enter_stage(3)
		3:
			# -- (b) Closing a dialogue at its terminal node must NOT reopen it --
			if ticks < 5:
				_warp_to("town")  # zone split: the town-core NPCs live in the Town zone now
				_face_npc("mayor_harlan")
				return false
			if ticks == 5:
				# Open through the real held-key poll (not a direct use_tool call).
				Input.action_press("use_tool")
				return false
			if ticks == 8:
				_check(dialogue_ui.active and dialogue_ui.npc == _npc_by_id("mayor_harlan"),
					"the held key opened Harlan's dialogue via the poll")
				_check(String(dialogue_ui._node_id) == "greet",
					"...on its start node (got '%s')" % dialogue_ui._node_id)
				return false
			if ticks == 18:
				_check(dialogue_ui.active and String(dialogue_ui._node_id) == "greet",
					"holding the key does NOT advance/re-trigger the open dialogue")
				Input.action_release("use_tool")
				return false
			if ticks == 20:
				# Walk the chain (bounded) up to — but not through — the terminal close.
				var guard := 0
				while dialogue_ui.active and not _next_press_closes() and guard < 20:
					_drive(dialogue_ui, "use_tool")
					guard += 1
				_check(guard < 20 and dialogue_ui.active,
					"reached the terminal node with the box still open")
				# THE REPORTED COUPLING: one physical press both closes the dialogue (event to
				# _unhandled_input) AND feeds the held-key poll on the following frames.
				Input.action_press("use_tool")
				_drive(dialogue_ui, "use_tool")
				_check(not dialogue_ui.active, "the paired press closed the conversation")
				return false
			if ticks == 30:
				_check(not dialogue_ui.active,
					"the dialogue STAYED closed across 10 held frames (the reopen bug)")
				_check(not bool(_npc_by_id("mayor_harlan").talking), "the NPC unfroze and stayed unfrozen")
				Input.action_release("use_tool")
				_enter_stage(4)
		4:
			# -- (c) The store's Leave row must not reopen Marta's conversation --
			if ticks < 5:
				_face_npc("marta")  # still town-bound from stage 3
				return false
			if ticks == 5:
				player.use_tool()
				_check(dialogue_ui.active, "Marta's dialogue opened")
				return false
			if ticks == 8:
				# Each burst of presses gets its own frame so the player's physics poll actually
				# RUNS with the UI open in between, exactly like real pacing — a modal that opens
				# and closes entirely between two physics frames is unreachable by real input
				# (every step needs its own press), and compressing them defeated the latch's
				# was-a-modal-open-last-frame tracking in an unrealistic way.
				_drive(dialogue_ui, "use_tool")  # reveal greet
				_drive(dialogue_ui, "use_tool")  # advance greet -> stocktake
				_drive(dialogue_ui, "use_tool")  # reveal the branch prompt
				_drive(dialogue_ui, "use_tool")  # confirm "Let's see what you've got"
				_check(store_ui.active, "the store opened via the dialogue choice")
				return false
			if ticks == 11:
				_drive(store_ui, "move_up")  # row 0 wraps straight up to the Leave row
				_check(store_ui._index == store_ui._row_ids.size() - 1, "on the Leave row")
				Input.action_press("use_tool")
				_drive(store_ui, "use_tool")  # the paired Leave press
				_check(not store_ui.active, "Leave closed the store")
				return false
			if ticks == 21:
				_check(not store_ui.active, "the store stayed closed across the held frames")
				_check(not dialogue_ui.active,
					"...and Marta's conversation did NOT reopen (the reported symptom)")
				Input.action_release("use_tool")
				_enter_stage(5)
		5:
			# -- (d) The shipping box's Leave row must close it, not reset it to the top row --
			if ticks < 5:
				_warp_to("farm")  # home from the store checks: the box is farm-zone content
				_stand(BOX_STAND, "north")
				return false
			if ticks == 5:
				player.use_tool()
				_check(shipping_ui.active, "the loading UI opened")
				return false
			if ticks == 8:  # separate frame per press burst — see stage 4's pacing comment
				for i in shipping_ui._row_ids.size() - 1:
					_drive(shipping_ui, "move_down")
				_check(shipping_ui._index == shipping_ui._row_ids.size() - 1, "on the Leave row")
				Input.action_press("use_tool")
				_drive(shipping_ui, "use_tool")  # the paired Leave press
				_check(not shipping_ui.active, "Leave closed the loading UI")
				return false
			if ticks == 18:
				_check(not shipping_ui.active,
					"the loading UI stayed closed (the old bug reopened it with the top row " \
						+ "highlighted, reading as 'Leave just resets the cursor')")
				Input.action_release("use_tool")
				_enter_stage(6)
		6:
			# -- Esc (ui_cancel) closes every modal surface and both HUD grids --
			if ticks < 5:
				_warp_to("town")  # the dialogue half needs Harlan; the chest half warps home below
				_face_npc("mayor_harlan")
				return false
			if ticks == 5:
				player.use_tool()
				_check(dialogue_ui.active, "dialogue open for the Esc check")
				_drive(dialogue_ui, "ui_cancel")
				_check(not dialogue_ui.active, "Esc closes the dialogue")
				_check(not bool(_npc_by_id("mayor_harlan").talking), "Esc-close unfroze the NPC")
				store_ui.open_store(null)
				_check(store_ui.active, "store open for the Esc check")
				_drive(store_ui, "ui_cancel")
				_check(not store_ui.active, "Esc closes the store")
				shipping_ui.open_box()
				_check(shipping_ui.active, "shipping UI open for the Esc check")
				_drive(shipping_ui, "ui_cancel")
				_check(not shipping_ui.active, "Esc closes the shipping UI")
				# 2026-07-12: "toggle_inventory" opens the tabbed in-game menu now (which hosts
				# the backpack grid as its Inventory tab); Esc must close it per the same
				# back-out convention as the three UIs above.
				_drive(menu_screen, "toggle_inventory")
				_check(menu_screen.active, "Tab opened the in-game menu")
				_drive(menu_screen, "ui_cancel")
				_check(not menu_screen.active, "Esc closes the in-game menu")
				_warp_to("farm")  # the chest is farm-zone content
				_stand(CHEST_STAND, "north")
				player.use_tool()
				_check(hud.get_node("%ChestGrid").visible, "chest grid open for the Esc check")
				_drive(hud, "ui_cancel")
				_check(not hud.get_node("%ChestGrid").visible, "Esc closes the chest grid")
				_enter_stage(7)
		7:
			# -- Chest walk-away auto-close: shuffling nearby holds, walking away closes --
			if ticks < 5:
				_stand(CHEST_STAND, "north")
				return false
			if ticks == 5:
				player.use_tool()
				_check(hud.get_node("%ChestGrid").visible, "chest grid opened")
				# Diagonal-adjacent shuffle (~22.6px of the 48px threshold): must stay open.
				_stand(Vector2i(15, 5), "north")
				return false
			if ticks == 10:
				_check(hud.get_node("%ChestGrid").visible,
					"shuffling beside the chest does NOT close the grid")
				# Walk well past the threshold: (16,9) is 80px from the chest's (16,4) center.
				_stand(Vector2i(16, 9), "north")
				return false
			if ticks == 15:
				_check(not hud.get_node("%ChestGrid").visible,
					"walking beyond CHEST_CLOSE_DISTANCE auto-closed the chest grid")
				_enter_stage(8)
		8:
			# -- Time pauses for modal UIs, resumes on close; build mode and the passive HUD
			#    grids deliberately do NOT pause --
			if ticks == 1:
				_minutes_snapshot = day_manager.minutes_into_day
				return false
			if ticks == 30:
				_check(not day_manager.time_paused, "clock unpaused with nothing open")
				_check(day_manager.minutes_into_day > _minutes_snapshot,
					"time flows with nothing open")
				_warp_to("town")  # Kael is town-zone content since the split
				_face_npc("scout_kael")
				return false
			if ticks == 35:
				player.use_tool()
				_check(dialogue_ui.active, "Kael's dialogue open for the pause check")
				return false
			if ticks == 40:  # a few idle frames so main._process set the pause flag
				_check(day_manager.time_paused, "an open dialogue pauses time")
				_minutes_snapshot = day_manager.minutes_into_day
				return false
			if ticks == 70:
				_check(day_manager.minutes_into_day == _minutes_snapshot,
					"the clock genuinely froze while the dialogue stayed open (%.2f vs %.2f)" \
						% [day_manager.minutes_into_day, _minutes_snapshot])
				_drive(dialogue_ui, "ui_cancel")
				_check(not dialogue_ui.active, "Esc closed the pause-check dialogue")
				return false
			if ticks == 75:
				_check(not day_manager.time_paused, "closing the dialogue unpauses time")
				_minutes_snapshot = day_manager.minutes_into_day
				_drive(builder, "build_toggle")
				_check(builder.active, "build mode engaged for the exemption check")
				return false
			if ticks == 105:
				_check(not day_manager.time_paused, "build mode does NOT pause time (exempt)")
				_check(day_manager.minutes_into_day > _minutes_snapshot,
					"the clock kept running through build mode")
				_drive(builder, "build_toggle")
				_check(not builder.active, "left build mode")
				# 2026-07-12: the in-game menu is a TRUE modal (unlike the passive backpack
				# grid that used to own this key) — opening it must pause time.
				_drive(menu_screen, "toggle_inventory")
				_check(menu_screen.active, "in-game menu opened for the pause check")
				return false
			if ticks == 110:
				_check(day_manager.time_paused, "the in-game menu DOES pause time (modal)")
				_drive(menu_screen, "toggle_inventory")
				_check(not menu_screen.active, "Tab closed the menu again")
				return false
			if ticks == 115:
				_check(not day_manager.time_paused, "closing the menu unpauses time")
				# Final hygiene: the two bed sleeps auto-saved to the test-only path.
				game_state.delete_save()
				_check(not game_state.has_save(), "test save file cleaned up")
				_finish()
				return true
		_:
			pass
	return false


## Stands the player on `cell` (in the currently-bound zone's frame), still, facing `facing`.
## get_global_cell_center (not cell_to_world_center) since the zone split: zones sit at
## sibling world offsets, so a local cell center is only world-space by luck at the origin.
func _stand(cell: Vector2i, facing: String) -> void:
	player.global_position = test_map.get_global_cell_center(cell)
	player.velocity = Vector2.ZERO
	player.facing = facing


## Rebinds the player into `zone_id` through main.gd's real _bind_zone (the same rebind a gate
## crossing performs, minus the fade) and re-points this smoke's refs at that zone's nodes —
## the established _warp_to convention from tools/runtime_smoke.gd/soak_test.gd.
func _warp_to(zone_id: String) -> void:
	main._bind_zone(zone_id)
	test_map = main.zones[zone_id]["map"]
	structures = main.zones[zone_id]["structures"]
	npcs = main.zones[zone_id]["npcs"]


## Stands the player one cell south of an NPC's LIVE cell (robust to wander), facing north.
## Marta is approached from the NORTH facing south instead (the same side runtime_smoke.gd
## uses): she stands against her store's south face, so the cell south of her is open ground
## but the approach from above keeps clear of the building footprint on every wander step.
func _face_npc(id: String) -> void:
	var npc: Node = _npc_by_id(id)
	var npc_cell: Vector2i = test_map.world_to_cell(npc.global_position)
	if id == "marta":
		_stand(npc_cell + Vector2i(0, -1), "south")
	else:
		_stand(npc_cell + Vector2i(0, 1), "north")


## True when the dialogue box sits fully revealed on a terminal node — i.e. the NEXT use_tool
## press is the one that closes it (mirrors dialogue_ui._advance()'s own close condition).
func _next_press_closes() -> bool:
	if not dialogue_ui._is_fully_revealed():
		return false
	var next_id: String = DialogueDB.advance_from(
		dialogue_ui._current_node(), dialogue_ui._choice_index)
	return next_id == ""


## Fabricated action event through a node's real _unhandled_input — the established convention
## from tools/runtime_smoke.gd / tools/soak_test.gd.
func _drive(node: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	node._unhandled_input(event)


func _npc_by_id(id: String) -> Node:
	for npc in npcs.npcs():
		if String(npc.npc_id) == id:
			return npc
	return null


func _finish() -> void:
	if failures.is_empty():
		print("HELD INPUT SMOKE: all checks passed (4 reported bugs verified fixed + Esc/walk-away/time-pause).")
		quit(0)
	else:
		for failure in failures:
			print("HELD INPUT SMOKE FAIL: %s" % failure)
		quit(1)
